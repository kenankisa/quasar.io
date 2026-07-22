import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// allowlist'ine göre süzülür (broadcast spoof azaltma).
class RealtimeRoomService {
  RealtimeRoomService._();
  static final RealtimeRoomService instance = RealtimeRoomService._();

  static const broadcastMinInterval = 1 / 12;
  static const _memberRefreshInterval = Duration(seconds: 4);

  RealtimeChannel? _channel;
  String? _localPlayerId;
  String? _roomInstanceId;
  Future<void>? _leaveInFlight;
  Timer? _memberRefreshTimer;
  final Set<String> _allowedPlayerIds = {};

  PlayerStateCallback? onPlayerState;
  BotSnapshotCallback? onBotSnapshot;
  PlayerIdCallback? onPlayerLeft;
  MatchSpeechCallback? onMatchSpeech;
  MatchEndCallback? onRemoteVictory;

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
            final map = Map<String, dynamic>.from(payload);
            final state = PlayerSyncState.fromMap(map);
            if (state.id == _localPlayerId) return;
            if (!_isAllowedMember(state.id)) return;
            onPlayerState?.call(state);
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
            if (!_isAllowedMember(id)) return;
            onPlayerLeft?.call(id);
          },
        )
        .onBroadcast(
          event: 'universe_victory',
          callback: (payload) {
            final winnerId = payload['id'] as String? ?? '';
            final winnerName = payload['name'] as String? ?? 'Champion';
            final elapsed = _readElapsedSeconds(payload);
            final isBot = payload['is_bot'] == true;
            final winnerRankPoints = payload['rank_points'] as int? ??
                payload['diamonds'] as int?;
            if (winnerId == _localPlayerId) return;
            if (!_isAllowedMatchEndId(winnerId, isBot: isBot)) return;
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
            final winnerId = payload['id'] as String? ?? '';
            final winnerName = payload['name'] as String? ?? 'Champion';
            final elapsed = _readElapsedSeconds(payload);
            final isBot = payload['is_bot'] == true;
            final winnerRankPoints = payload['rank_points'] as int? ??
                payload['diamonds'] as int?;
            if (winnerId == _localPlayerId) return;
            if (!_isAllowedMatchEndId(winnerId, isBot: isBot)) return;
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
    bool isBot = false,
    int? rankPoints,
  }) {
    return {
      'id': playerId,
      'name': playerName,
      'elapsed': elapsedSeconds,
      if (isBot) 'is_bot': true,
      if (!isBot && rankPoints != null) 'rank_points': rankPoints,
    };
  }

  void broadcastVictory({
    required String playerId,
    required String playerName,
    required double elapsedSeconds,
    int? rankPoints,
  }) {
    final uid = _authUidOrNull();
    if (uid == null || playerId != uid) return;
    final payload = _matchEndPayload(
      playerId: playerId,
      playerName: playerName,
      elapsedSeconds: elapsedSeconds,
      rankPoints: rankPoints,
    );
    _channel?.sendBroadcastMessage(
      event: 'universe_victory',
      payload: payload,
    );
    // Oda kapanır: tüm oyuncular maçı bitirir.
    _channel?.sendBroadcastMessage(
      event: 'room_closed',
      payload: payload,
    );
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
    _channel?.sendBroadcastMessage(
      event: 'room_closed',
      payload: _matchEndPayload(
        playerId: playerId,
        playerName: playerName,
        elapsedSeconds: elapsedSeconds,
        isBot: isBot,
      ),
    );
  }

  static double _readElapsedSeconds(Map<String, dynamic> payload) {
    final raw = payload['elapsed'];
    if (raw is num) return raw.toDouble();
    return 0;
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
    if (_channel == null) {
      _allowedPlayerIds.clear();
      _roomInstanceId = null;
      _localPlayerId = null;
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

  bool _isAllowedMatchEndId(String id, {required bool isBot}) {
    if (isBot || id.startsWith('bot:')) return true;
    if (id == 'system:abandoned') return true;
    return _isAllowedMember(id);
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
      _allowedPlayerIds
        ..clear()
        ..add(local)
        ..addAll(ids);
    } catch (e, st) {
      debugPrint('RealtimeRoomService member refresh: $e\n$st');
    }
  }
}
