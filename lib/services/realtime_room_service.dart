import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/hardcore_rules.dart';
import '../game/models/bot_sync_state.dart';
import '../game/models/match_speech.dart';
import '../game/models/player_sync_state.dart';
import '../game/room_type.dart';
import 'auth_service.dart';
import 'room_matchmaking_service.dart';

typedef PlayerStateCallback = void Function(PlayerSyncState state);
typedef BotSnapshotCallback = void Function(BotSnapshot snapshot);
typedef PlayerIdCallback = void Function(String playerId);
typedef MatchSpeechCallback = void Function(MatchSpeechEvent event);

/// Hardcore arena phase flip (&lt; min-alive ↔ active).
typedef HardcoreArenaPhaseCallback = void Function({
  required bool active,
  String? phaseAtUtc,
  String? anchorPlayerId,
  double? anchorRadius,
});

/// Fired for remote victory and room-closed broadcasts (same payload shape).
typedef MatchEndCallback = void Function(
  String winnerId,
  String winnerName,
  double elapsedSeconds,
  bool isBot, {
  int? winnerRankPoints,
});

/// Supabase Realtime Broadcast bridge for in-room player sync.
///
/// Outbound kimlikler [auth.uid] ile zorlanır; inbound olaylar oda üyesi
/// allowlist + `sender_id` ile süzülür (broadcast spoof azaltma).
class RealtimeRoomService {
  RealtimeRoomService._();
  static final RealtimeRoomService instance = RealtimeRoomService._();

  static const broadcastMinInterval = 1 / 12;
  static const _memberRefreshInterval = Duration(seconds: 4);

  RealtimeChannel? _channel;
  String? _localPlayerId;
  String? _roomInstanceId;
  RoomType? _roomType;
  Future<void>? _leaveInFlight;
  Timer? _memberRefreshTimer;
  final Set<String> _allowedPlayerIds = {};

  PlayerStateCallback? onPlayerState;
  BotSnapshotCallback? onBotSnapshot;
  PlayerIdCallback? onPlayerLeft;
  MatchSpeechCallback? onMatchSpeech;
  MatchEndCallback? onRemoteVictory;

  /// Hardcore arena test / sim elim broadcast (`hc_elim`).
  /// [preyId] was absorbed; peers must despawn immediately.
  PlayerIdCallback? onHardcoreElim;

  /// Hardcore: arena dropped below / reached min-alive — sync low-pop drain.
  HardcoreArenaPhaseCallback? onHardcoreArenaPhase;

  /// Bir oyuncu bitirdiğinde tüm oda kapanır — her istemciye yayınlanır.
  MatchEndCallback? onRoomClosed;

  SupabaseClient get _client => AuthService.instance.client;

  bool get isJoined => _channel != null;

  Future<void> joinRoom({
    required RoomType roomType,
    required String playerId,
    String? roomInstanceId,
  }) async {
    await leaveRoom();

    final authId = AuthService.instance.currentUser?.id;
    if (authId == null || authId.isEmpty) {
      throw StateError('RealtimeRoomService.joinRoom: not authenticated');
    }
    // Kimlik spoof: kanal oyuncu id'si oturum uid'si olmalı.
    if (playerId != authId) {
      throw StateError('RealtimeRoomService.joinRoom: playerId must be auth uid');
    }

    _localPlayerId = authId;
    _roomInstanceId = roomInstanceId;
    _roomType = roomType;
    _allowedPlayerIds
      ..clear()
      ..add(authId);

    if (roomInstanceId != null) {
      await _refreshAllowedMembers();
    }

    final channelName = roomInstanceId != null
        ? 'quasar_room_${roomType.name}_$roomInstanceId'
        : 'quasar_room_${roomType.name}';

    _channel = _client
        .channel(channelName)
        .onBroadcast(
          event: 'player_state',
          callback: (payload) {
            try {
              final map = Map<String, dynamic>.from(payload);
              final state = PlayerSyncState.fromMap(map);
              if (state.id == _localPlayerId) return;
              if (!_isAllowedMember(state.id)) return;
              onPlayerState?.call(state);
            } catch (_) {
              // Malformed peer pose (null id etc.) — ignore.
            }
          },
        )
        .onBroadcast(
          event: 'bot_snapshot',
          callback: (payload) {
            final map = Map<String, dynamic>.from(payload);
            final snapshot = BotSnapshot.fromMap(map);
            if (snapshot.hostId.isEmpty) return;
            if (snapshot.hostId == _localPlayerId) return;
            if (!_isAllowedMember(snapshot.hostId)) return;
            onBotSnapshot?.call(snapshot);
          },
        )
        .onBroadcast(
          event: 'player_left',
          callback: (payload) {
            final id = payload['id'] as String?;
            if (id == null || id == _localPlayerId) return;
            // Do not require allowlist: leavers often drop from members first,
            // and peers must still despawn their hole.
            _allowedPlayerIds.remove(id);
            onPlayerLeft?.call(id);
          },
        )
        .onBroadcast(
          event: 'hc_elim',
          callback: (payload) {
            final preyId = payload['prey_id'] as String?;
            if (preyId == null || preyId.isEmpty) return;
            _allowedPlayerIds.remove(preyId);
            onHardcoreElim?.call(preyId);
          },
        )
        .onBroadcast(
          event: 'hc_arena_phase',
          callback: (payload) {
            if (_roomType != RoomType.hardcore) return;
            final map = Map<String, dynamic>.from(payload);
            final active = map['active'] == true;
            final phaseAt = map['phase_at'] as String?;
            if (!active && (phaseAt == null || phaseAt.isEmpty)) return;
            final anchorId = map['anchor_player_id'] as String?;
            final anchorRadius = (map['anchor_radius'] as num?)?.toDouble();
            onHardcoreArenaPhase?.call(
              active: active,
              phaseAtUtc: phaseAt,
              anchorPlayerId:
                  anchorId != null && anchorId.isNotEmpty ? anchorId : null,
              anchorRadius: anchorRadius,
            );
          },
        )
        .onBroadcast(
          event: 'universe_victory',
          callback: (payload) {
            final map = Map<String, dynamic>.from(payload);
            final winnerId = map['id'] as String? ?? '';
            final winnerName = map['name'] as String? ?? 'Champion';
            final elapsed = _readElapsedSeconds(map);
            final isBot = map['is_bot'] == true;
            final senderId = _readSenderId(map);
            final winnerRankPoints = map['rank_points'] as int? ??
                map['diamonds'] as int?;
            if (winnerId == _localPlayerId) return;
            // Hardcore: winner leaves membership in the same tick — still
            // despawn their hole if they authenticated their own claim.
            if (_roomType == RoomType.hardcore &&
                senderId == winnerId &&
                winnerId.isNotEmpty) {
              _allowedPlayerIds.remove(winnerId);
              onRemoteVictory?.call(
                winnerId,
                winnerName,
                elapsed,
                isBot,
                winnerRankPoints: winnerRankPoints,
              );
              return;
            }
            if (!_isAllowedMatchEnd(
              winnerId: winnerId,
              isBot: isBot,
              senderId: senderId,
            )) {
              return;
            }
            onRemoteVictory?.call(
              winnerId,
              winnerName,
              elapsed,
              isBot,
              winnerRankPoints: winnerRankPoints,
            );
          },
        )
        .onBroadcast(
          event: 'room_closed',
          callback: (payload) {
            final map = Map<String, dynamic>.from(payload);
            final winnerId = map['id'] as String? ?? '';
            final winnerName = map['name'] as String? ?? 'Champion';
            final elapsed = _readElapsedSeconds(map);
            final isBot = map['is_bot'] == true;
            final senderId = _readSenderId(map);
            final winnerRankPoints = map['rank_points'] as int? ??
                map['diamonds'] as int?;
            if (winnerId == _localPlayerId) return;
            if (!_isAllowedMatchEnd(
              winnerId: winnerId,
              isBot: isBot,
              senderId: senderId,
            )) {
              return;
            }
            onRoomClosed?.call(
              winnerId,
              winnerName,
              elapsed,
              isBot,
              winnerRankPoints: winnerRankPoints,
            );
          },
        )
        .onBroadcast(
          event: 'match_speech',
          callback: (payload) {
            final map = Map<String, dynamic>.from(payload);
            final event = MatchSpeechEvent.fromMap(map);
            if (event.playerId.isEmpty || event.text.isEmpty) return;
            if (event.playerId == _localPlayerId) return;
            if (!_isAllowedMember(event.playerId)) return;
            onMatchSpeech?.call(event);
          },
        );

    _channel!.subscribe();
    _startMemberRefresh();
  }

  void broadcastMatchSpeech(MatchSpeechEvent event) {
    final uid = _authUidOrNull();
    if (uid == null || event.text.isEmpty) return;
    if (event.playerId != uid) return;
    _channel?.sendBroadcastMessage(
      event: 'match_speech',
      payload: event.toMap(),
    );
  }

  /// Hardcore: prey must leave the map on every client (incl. arena-test sims).
  void broadcastHardcoreElim({required String preyId}) {
    final uid = _authUidOrNull();
    if (uid == null || preyId.isEmpty || preyId == uid) return;
    _channel?.sendBroadcastMessage(
      event: 'hc_elim',
      payload: {
        'predator_id': uid,
        'prey_id': preyId,
      },
    );
  }

  /// Hardcore: min-alive phase flip — peers align low-pop drain to server UTC.
  void broadcastHardcoreArenaPhase({
    required bool active,
    String? phaseAtUtc,
    String? anchorPlayerId,
    double? anchorRadius,
  }) {
    if (_roomType != RoomType.hardcore) return;
    final uid = _authUidOrNull();
    if (uid == null) return;
    final payload = <String, dynamic>{
      'active': active,
      'sender_id': uid,
    };
    if (!active) {
      payload['phase_at'] = phaseAtUtc ?? DateTime.now().toUtc().toIso8601String();
      if (anchorPlayerId != null &&
          anchorPlayerId.isNotEmpty &&
          anchorRadius != null &&
          anchorRadius > 0) {
        payload['anchor_player_id'] = anchorPlayerId;
        payload['anchor_radius'] = anchorRadius;
      }
    }
    _channel?.sendBroadcastMessage(
      event: 'hc_arena_phase',
      payload: payload,
    );
  }

  void broadcastState(PlayerSyncState state) {
    final uid = _authUidOrNull();
    if (uid == null || state.id != uid) return;
    _channel?.sendBroadcastMessage(
      event: 'player_state',
      payload: state.toMap(),
    );
  }

  void broadcastBotSnapshot(BotSnapshot snapshot) {
    final uid = _authUidOrNull();
    if (uid == null || snapshot.hostId != uid) return;
    _channel?.sendBroadcastMessage(
      event: 'bot_snapshot',
      payload: snapshot.toMap(),
    );
  }

  Map<String, dynamic> _matchEndPayload({
    required String playerId,
    required String playerName,
    required double elapsedSeconds,
    required String senderId,
    bool isBot = false,
    int? rankPoints,
  }) {
    return {
      'id': playerId,
      'name': playerName,
      'elapsed': elapsedSeconds,
      'sender_id': senderId,
      if (isBot) 'is_bot': true,
      if (!isBot && rankPoints != null) 'rank_points': rankPoints,
    };
  }

  void broadcastVictory({
    required String playerId,
    required String playerName,
    required double elapsedSeconds,
    int? rankPoints,
    bool closeRoom = true,
  }) {
    final uid = _authUidOrNull();
    if (uid == null || playerId != uid) return;
    final payload = _matchEndPayload(
      playerId: playerId,
      playerName: playerName,
      elapsedSeconds: elapsedSeconds,
      senderId: uid,
      rankPoints: rankPoints,
    );
    _channel?.sendBroadcastMessage(
      event: 'universe_victory',
      payload: payload,
    );
    // Hardcore stays open — only the winner leaves; peers keep playing.
    if (closeRoom) {
      _channel?.sendBroadcastMessage(
        event: 'room_closed',
        payload: payload,
      );
    }
  }

  void broadcastRoomClosed({
    required String playerId,
    required String playerName,
    required double elapsedSeconds,
    bool isBot = false,
  }) {
    final uid = _authUidOrNull();
    if (uid == null) return;
    // Kendi uid / bot:… / system:abandoned — başka oyuncunun uid'si yasak.
    final allowedId = playerId == uid ||
        playerId == 'system:abandoned' ||
        playerId.startsWith('bot:');
    if (!allowedId) return;
    if (!isBot && playerId != uid) return;
    if (isBot &&
        playerId != 'system:abandoned' &&
        !playerId.startsWith('bot:')) {
      return;
    }
    _channel?.sendBroadcastMessage(
      event: 'room_closed',
      payload: _matchEndPayload(
        playerId: playerId,
        playerName: playerName,
        elapsedSeconds: elapsedSeconds,
        senderId: uid,
        isBot: isBot,
      ),
    );
  }

  static double _readElapsedSeconds(Map<String, dynamic> payload) {
    final raw = payload['elapsed'];
    if (raw is num) return raw.toDouble();
    return 0;
  }

  static String? _readSenderId(Map<String, dynamic> payload) {
    final raw = payload['sender_id'];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  void broadcastLeave() {
    final id = _localPlayerId;
    final uid = _authUidOrNull();
    if (id == null || uid == null || id != uid) return;
    _channel?.sendBroadcastMessage(
      event: 'player_left',
      payload: {'id': id},
    );
  }

  Future<void> leaveRoom() async {
    _stopMemberRefresh();
    if (_roomType == RoomType.hardcore) {
      HardcoreArenaAliveHint.clear();
    }
    if (_channel == null) {
      _allowedPlayerIds.clear();
      _roomInstanceId = null;
      _localPlayerId = null;
      _roomType = null;
      return;
    }
    if (_leaveInFlight != null) {
      await _leaveInFlight;
      return;
    }

    final channel = _channel!;
    _leaveInFlight = _leaveChannel(channel);
    try {
      await _leaveInFlight;
    } finally {
      _leaveInFlight = null;
    }
  }

  Future<void> _leaveChannel(RealtimeChannel channel) async {
    if (_channel != channel) return;
    broadcastLeave();
    await _client.removeChannel(channel);
    if (_channel == channel) {
      _channel = null;
      _localPlayerId = null;
      _roomInstanceId = null;
      _roomType = null;
      _allowedPlayerIds.clear();
    }
  }

  String? _authUidOrNull() => AuthService.instance.currentUser?.id;

  bool _isAllowedMember(String id) {
    if (id.isEmpty || id.startsWith('bot:')) return false;
    if (_roomInstanceId == null) {
      // Eğitim / instance'sız kanal: yalnızca kendi oturum kimliği yayınlar.
      return id == _localPlayerId;
    }
    return _allowedPlayerIds.contains(id);
  }

  /// Match-end spoof koruması: gönderen oda üyesi olmalı.
  ///
  /// - İnsan zaferi / kapanış: `sender_id == winnerId` ve üye.
  /// - Bot / abandoned: yalnızca `bot:…` / `system:abandoned` + `is_bot`,
  ///   ve gönderen üye (üye olmayanların `is_bot: true` ile kapatması engellenir).
  bool _isAllowedMatchEnd({
    required String winnerId,
    required bool isBot,
    required String? senderId,
  }) {
    if (senderId == null || !_isAllowedMember(senderId)) return false;

    final isSynthetic =
        winnerId == 'system:abandoned' || winnerId.startsWith('bot:');
    if (isSynthetic) {
      return isBot;
    }

    // İnsan kazanan: is_bot bayrağı kabul edilmez; yalnızca kendi zaferini duyurabilir.
    if (isBot) return false;
    if (!_isAllowedMember(winnerId)) return false;
    return senderId == winnerId;
  }

  void _startMemberRefresh() {
    _stopMemberRefresh();
    if (_roomInstanceId == null) return;
    _memberRefreshTimer = Timer.periodic(
      _memberRefreshInterval,
      (_) => unawaited(_refreshAllowedMembers()),
    );
  }

  void _stopMemberRefresh() {
    _memberRefreshTimer?.cancel();
    _memberRefreshTimer = null;
  }

  Future<void> _refreshAllowedMembers() async {
    final roomId = _roomInstanceId;
    final local = _localPlayerId;
    if (roomId == null || local == null) return;
    try {
      final ids =
          await RoomMatchmakingService.instance.listActiveMemberIds(roomId);
      if (_roomInstanceId != roomId) return;
      final previous = Set<String>.from(_allowedPlayerIds);
      _allowedPlayerIds
        ..clear()
        ..add(local)
        ..addAll(ids);
      // Hardcore softcap / arena-active: DB headcount beats lossy peer sightings.
      if (_roomType == RoomType.hardcore) {
        HardcoreArenaAliveHint.setMembers(_allowedPlayerIds.length);
      }
      // Seat released (elim / leave) → purge ghost holes even if player_left
      // or absorb broadcast was missed.
      for (final id in previous) {
        if (id == local) continue;
        if (_allowedPlayerIds.contains(id)) continue;
        onPlayerLeft?.call(id);
      }
    } catch (e, st) {
      debugPrint('RealtimeRoomService member refresh: $e\n$st');
    }
  }
}
