import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/room_matchmaking.dart';
import '../game/models/room_lobby_stats.dart';
import '../game/room_type.dart';
import 'auth_service.dart';
import 'training_presence_service.dart';

/// Lobi evren kartları için sunucudan anlık oda istatistikleri.
class LobbyRoomStatsService extends ChangeNotifier {
  LobbyRoomStatsService._();
  static final LobbyRoomStatsService instance = LobbyRoomStatsService._();

  static const _staleAfter = Duration(minutes: 3);
  static const _pollInterval = Duration(seconds: 8);

  final Map<RoomType, RoomLobbyStats> _stats = {
    RoomType.simple: const RoomLobbyStats.empty(),
    RoomType.normal: const RoomLobbyStats.empty(),
    RoomType.elite: const RoomLobbyStats.empty(),
    RoomType.unique: const RoomLobbyStats.empty(),
    RoomType.hardcore: const RoomLobbyStats.empty(),
  };

  RealtimeChannel? _channel;
  RealtimeChannel? _trainingChannel;
  Timer? _pollTimer;
  int _refCount = 0;
  bool _refreshInFlight = false;

  /// Hardcore seat count must match on consecutive RPC reads before UI updates
  /// (avoids flicker between `real_player_count` aggregate and seat occupancy).
  int? _hardcoreSeatsCandidate;
  int _hardcoreSeatsCandidateHits = 0;
  static const _hardcoreSeatsStablePolls = 2;

  RoomLobbyStats statsFor(RoomType type) =>
      _stats[type] ?? const RoomLobbyStats.empty();

  void attach() {
    _refCount++;
    if (_refCount == 1) {
      unawaited(_start());
    }
  }

  void detach() {
    if (_refCount == 0) return;
    _refCount--;
    if (_refCount == 0) {
      _stop();
    }
  }

  /// Stop lobby polling while the app is backgrounded (heat / radio).
  void pauseForBackground() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resume polling when returning to the lobby foreground.
  void resumeFromBackground() {
    if (_refCount <= 0 || _pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _start() async {
    await _refresh();
    _subscribe();
    _subscribeTrainingPresence();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  void _stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_channel != null) {
      AuthService.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    if (_trainingChannel != null) {
      AuthService.instance.client.removeChannel(_trainingChannel!);
      _trainingChannel = null;
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = AuthService.instance.client
        .channel('lobby-room-stats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_room_instances',
          callback: (_) => unawaited(_refresh()),
        )
        .subscribe();
  }

  void _subscribeTrainingPresence() {
    _trainingChannel?.unsubscribe();
    _trainingChannel =
        AuthService.instance.client.channel(TrainingPresenceService.channelName);

    void syncTrainingStats() {
      final channel = _trainingChannel;
      if (channel == null) return;

      final players = countTrainingPresence(channel);
      final next = RoomLobbyStats(
        activeUniverses: players,
        players: players,
        bots: players * RoomMatchmaking.trainingBotsPerSession,
      );

      if (_stats[RoomType.simple] != next) {
        _stats[RoomType.simple] = next;
        notifyListeners();
      }
    }

    _trainingChannel!
        .onPresenceSync((_) => syncTrainingStats())
        .onPresenceJoin((_) => syncTrainingStats())
        .onPresenceLeave((_) => syncTrainingStats())
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            syncTrainingStats();
          }
        });
  }

  Future<void> _refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;

    try {
      final rows = await AuthService.instance.client
          .from('game_room_instances')
          .select(
            'room_type, real_player_count, leader_radius, status, '
            'updated_at, created_at, is_load_test',
          );

      final aggregates = <RoomType, _RoomAggregate>{
        for (final type in RoomType.values)
          if (type != RoomType.simple && type != RoomType.hardcore)
            type: _RoomAggregate(),
      };

      final staleBefore = DateTime.now().toUtc().subtract(_staleAfter);

      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (row['is_load_test'] == true) continue;

        final roomType = _parseRoomType(row['room_type'] as String?);
        if (roomType == null) continue;

        final aggregate = aggregates[roomType];
        if (aggregate == null) continue;
        if (!_isActiveInstance(row, staleBefore)) continue;

        final players = (row['real_player_count'] as num?)?.toInt() ?? 0;
        aggregate.universes++;
        aggregate.players += players;
        aggregate.bots +=
            RoomMatchmaking.botCountFor(players, roomType: roomType);
      }

      var changed = false;
      for (final entry in aggregates.entries) {
        final next = RoomLobbyStats(
          activeUniverses: entry.value.universes,
          players: entry.value.players,
          bots: entry.value.bots,
        );
        if (_stats[entry.key] != next) {
          _stats[entry.key] = next;
          changed = true;
        }
      }

      if (changed) notifyListeners();

      await _refreshHardcoreLobbyStatus();
    } catch (e, stackTrace) {
      debugPrint('LobbyRoomStatsService refresh failed: $e\n$stackTrace');
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _refreshHardcoreLobbyStatus() async {
    try {
      final response =
          await AuthService.instance.client.rpc('get_hardcore_lobby_status');
      if (response == null) return;
      final map = Map<String, dynamic>.from(response as Map);
      final seats = (map['seat_occupancy'] as num?)?.toInt() ?? 0;
      final maxSeats = (map['max_players'] as num?)?.toInt() ?? 20;
      final queue = (map['queue_count'] as num?)?.toInt() ?? 0;

      final prev = _stats[RoomType.hardcore] ?? const RoomLobbyStats.empty();
      final isInitial = prev.hardcoreSeatOccupancy == null;

      if (seats == _hardcoreSeatsCandidate) {
        _hardcoreSeatsCandidateHits++;
      } else {
        _hardcoreSeatsCandidate = seats;
        _hardcoreSeatsCandidateHits = 1;
      }

      final seatsStable =
          isInitial || _hardcoreSeatsCandidateHits >= _hardcoreSeatsStablePolls;
      final metaChanged = prev.hardcoreMaxSeats != maxSeats ||
          prev.hardcoreQueueCount != queue;

      if (!seatsStable && !metaChanged) return;

      final displaySeats = seatsStable
          ? seats
          : (prev.hardcoreSeatOccupancy ?? seats);

      final next = RoomLobbyStats(
        activeUniverses: math.max(1, prev.activeUniverses),
        players: displaySeats,
        bots: 0,
        hardcoreSeatOccupancy: displaySeats,
        hardcoreMaxSeats: maxSeats,
        hardcoreQueueCount: queue,
      );
      if (_stats[RoomType.hardcore] != next) {
        _stats[RoomType.hardcore] = next;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint(
        'LobbyRoomStatsService hardcore status failed: $e\n$stackTrace',
      );
    }
  }

  bool _isActiveInstance(Map<String, dynamic> row, DateTime staleBefore) {
    if (row['status'] != 'open') return false;

    final players = (row['real_player_count'] as num?)?.toInt() ?? 0;
    if (players <= 0) return false;

    final roomType = _parseRoomType(row['room_type'] as String?);
    final leaderRadius = (row['leader_radius'] as num?)?.toInt() ?? 0;
    // Hardcore always-open: softcap (~450) must never hide the universe.
    if (RoomMatchmaking.appliesLeaderJoinLock(
          roomType ?? RoomType.normal,
        ) &&
        leaderRadius >= RoomMatchmaking.leaderRadiusJoinThreshold) {
      return false;
    }

    final updatedRaw = row['updated_at'] ?? row['created_at'];
    if (updatedRaw == null) return false;

    final updatedAt = DateTime.parse(updatedRaw as String).toUtc();
    return !updatedAt.isBefore(staleBefore);
  }

  RoomType? _parseRoomType(String? value) {
    if (value == null) return null;
    for (final type in RoomType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

class _RoomAggregate {
  int universes = 0;
  int players = 0;
  int bots = 0;
}
