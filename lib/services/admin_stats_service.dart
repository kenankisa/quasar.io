import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/bot_difficulty.dart';
import '../game/config/room_matchmaking.dart';
import '../game/models/admin_stats.dart';
import '../game/room_type.dart';
import 'admin_access.dart';
import 'auth_service.dart';
import 'lobby_room_stats_service.dart';
import 'training_presence_service.dart';

/// Admin paneli için canlı oyuncu / bot / evren istatistikleri.
class AdminStatsService extends ChangeNotifier {
  AdminStatsService._();
  static final AdminStatsService instance = AdminStatsService._();

  static const _staleAfter = Duration(minutes: 3);
  /// Realtime varken yedek poll; sık ağ çağrısı için değil.
  static const _pollInterval = Duration(seconds: 30);
  static const _realtimeDebounce = Duration(milliseconds: 1500);
  AdminStatsSnapshot _snapshot = AdminStatsSnapshot.empty();
  AdminStatsSnapshot get snapshot => _snapshot;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Timer? _pollTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _roomsChannel;
  RealtimeChannel? _sessionsChannel;
  RealtimeChannel? _trainingChannel;
  int _refCount = 0;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  int _trainingPlayers = 0;

  void attach() {
    if (!AdminAccess.isCurrentUserAdmin) return;
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

  Future<void> refresh() => _refresh();

  Future<void> _start() async {
    await _refresh();
    _subscribeRooms();
    _subscribeSessions();
    _subscribeTraining();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  void _stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_roomsChannel != null) {
      AuthService.instance.client.removeChannel(_roomsChannel!);
      _roomsChannel = null;
    }
    if (_sessionsChannel != null) {
      AuthService.instance.client.removeChannel(_sessionsChannel!);
      _sessionsChannel = null;
    }
    if (_trainingChannel != null) {
      AuthService.instance.client.removeChannel(_trainingChannel!);
      _trainingChannel = null;
    }
  }

  /// Realtime fırtınasını tek yenilemeye indirger.
  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_realtimeDebounce, () {
      unawaited(_refresh());
    });
  }

  void _subscribeRooms() {
    _roomsChannel?.unsubscribe();
    _roomsChannel = AuthService.instance.client
        .channel('admin-room-stats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_room_instances',
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();
  }

  /// Oyuncu giriş/çıkış (manuel veya idle) anında sayacı güncelle.
  void _subscribeSessions() {
    _sessionsChannel?.unsubscribe();
    _sessionsChannel = AuthService.instance.client
        .channel('admin-active-sessions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_active_sessions',
          callback: (payload) {
            _applyOptimisticSessionDelta(payload);
            _scheduleRefresh();
          },
        )
        .subscribe();
  }

  void _applyOptimisticSessionDelta(PostgresChangePayload payload) {
    final adminId = AuthService.instance.currentUser?.id;
    // Admin kimliği yokken iyimser sayım yapma (yanlış +1 engeli).
    if (adminId == null) return;

    final event = payload.eventType;

    if (event == PostgresChangeEvent.delete) {
      final leftId = payload.oldRecord['user_id'] as String?;
      if (leftId == null || leftId == adminId) return;
      final next = (_snapshot.activeSessions - 1).clamp(0, 1 << 30);
      if (next == _snapshot.activeSessions) return;
      _snapshot = AdminStatsSnapshot(
        tiers: _snapshot.tiers,
        totalPlayers: _snapshot.totalPlayers,
        totalBots: _snapshot.totalBots,
        totalActiveUniverses: _snapshot.totalActiveUniverses,
        registeredPlayers: _snapshot.registeredPlayers,
        totalGamesWon: _snapshot.totalGamesWon,
        activeSessions: next,
        topWinners: _snapshot.topWinners,
        fetchedAt: DateTime.now().toUtc(),
      );
      notifyListeners();
      return;
    }

    if (event == PostgresChangeEvent.insert) {
      final joinedId = payload.newRecord['user_id'] as String?;
      if (joinedId == null || joinedId == adminId) return;
      _snapshot = AdminStatsSnapshot(
        tiers: _snapshot.tiers,
        totalPlayers: _snapshot.totalPlayers,
        totalBots: _snapshot.totalBots,
        totalActiveUniverses: _snapshot.totalActiveUniverses,
        registeredPlayers: _snapshot.registeredPlayers,
        totalGamesWon: _snapshot.totalGamesWon,
        activeSessions: _snapshot.activeSessions + 1,
        topWinners: _snapshot.topWinners,
        fetchedAt: DateTime.now().toUtc(),
      );
      notifyListeners();
    }
  }

  void _subscribeTraining() {
    _trainingChannel?.unsubscribe();
    _trainingChannel =
        AuthService.instance.client.channel(TrainingPresenceService.channelName);

    void sync() {
      final channel = _trainingChannel;
      if (channel == null) return;
      final next = countTrainingPresence(channel);
      if (next != _trainingPlayers) {
        _trainingPlayers = next;
        _scheduleRefresh();
      }
    }

    _trainingChannel!
        .onPresenceSync((_) => sync())
        .onPresenceJoin((_) => sync())
        .onPresenceLeave((_) => sync())
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            sync();
          }
        });
  }

  Future<void> _refresh() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;

    if (_snapshot.totalActiveUniverses == 0 &&
        _snapshot.registeredPlayers == 0) {
      _loading = true;
      notifyListeners();
    }

    try {
      final client = AuthService.instance.client;
      final staleBefore = DateTime.now().toUtc().subtract(_staleAfter);

      final results = await Future.wait<dynamic>([
        client.from('game_room_instances').select(
              'id, room_type, instance_number, real_player_count, '
              'leader_radius, status, updated_at, created_at, is_load_test',
            ),
        client.rpc('get_admin_live_player_stats'),
        _fetchActiveSessionCount(client),
      ]);

      final roomRows = results[0] as List;
      final playerStats = Map<String, dynamic>.from(results[1] as Map);
      final activeSessions = results[2] as int;

      final tiers = <RoomType, _TierBuilder>{
        for (final type in RoomType.values) type: _TierBuilder(type),
      };

      for (final raw in roomRows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final roomType = _parseRoomType(row['room_type'] as String?);
        if (roomType == null || roomType == RoomType.simple) continue;
        if (!_isActiveInstance(row, staleBefore)) continue;

        final players = (row['real_player_count'] as num?)?.toInt() ?? 0;
        final bots = RoomMatchmaking.botCountFor(players);
        final instanceNumber = (row['instance_number'] as num?)?.toInt() ?? 0;
        final leaderRadius = (row['leader_radius'] as num?)?.toInt() ?? 0;

        tiers[roomType]!.addInstance(
          AdminUniverseInstance(
            id: row['id'] as String,
            roomType: roomType,
            instanceNumber: instanceNumber,
            players: players,
            bots: bots,
            leaderRadius: leaderRadius,
            difficultyLabelKey:
                AdminUniverseTierStats.difficultyLabelKeyFor(roomType),
            isLoadTest: row['is_load_test'] == true,
          ),
        );
      }

      // Eğitim evreni: presence + tahmini botlar.
      final trainingPlayers = _trainingPlayers;
      final trainingBots =
          trainingPlayers * RoomMatchmaking.trainingBotsPerSession;
      final simpleTier = tiers[RoomType.simple]!;
      if (trainingPlayers > 0) {
        simpleTier.activeUniverses = trainingPlayers;
        simpleTier.players = trainingPlayers;
        simpleTier.bots = trainingBots;
        for (var i = 0; i < trainingPlayers; i++) {
          simpleTier.instances.add(
            AdminUniverseInstance(
              id: 'training-$i',
              roomType: RoomType.simple,
              instanceNumber: i + 1,
              players: 1,
              bots: RoomMatchmaking.trainingBotsPerSession,
              leaderRadius: 0,
              difficultyLabelKey:
                  AdminUniverseTierStats.difficultyLabelKeyFor(RoomType.simple),
            ),
          );
        }
      }

      // Lobi servisi ile eğitim sayısını da senkron tut (attach edilmişse).
      final lobbySimple = LobbyRoomStatsService.instance.statsFor(RoomType.simple);
      if (trainingPlayers == 0 && (lobbySimple.players ?? 0) > 0) {
        final p = lobbySimple.players ?? 0;
        simpleTier.activeUniverses = lobbySimple.activeUniverses;
        simpleTier.players = p;
        simpleTier.bots = lobbySimple.bots;
      }

      var totalPlayers = 0;
      var totalBots = 0;
      var totalUniverses = 0;
      final builtTiers = <RoomType, AdminUniverseTierStats>{};
      for (final type in RoomType.values) {
        final built = tiers[type]!.build();
        builtTiers[type] = built;
        totalPlayers += built.players;
        totalBots += built.bots;
        totalUniverses += built.activeUniverses;
      }

      final totalGamesWon =
          (playerStats['total_games_won'] as num?)?.toInt() ?? 0;
      final registeredPlayers =
          (playerStats['registered_players'] as num?)?.toInt() ?? 0;
      final winnersRaw = (playerStats['top_winners'] as List?) ?? const [];
      final topWinners = winnersRaw
          .whereType<Map>()
          .map(
            (raw) {
              final row = Map<String, dynamic>.from(raw);
              return AdminTopWinner(
                username: (row['username'] as String?) ?? '—',
                gamesWon: (row['games_won'] as num?)?.toInt() ?? 0,
                diamonds: (row['diamonds'] as num?)?.toInt() ?? 0,
              );
            },
          )
          .toList(growable: false);

      _snapshot = AdminStatsSnapshot(
        tiers: builtTiers,
        totalPlayers: totalPlayers,
        totalBots: totalBots,
        totalActiveUniverses: totalUniverses,
        registeredPlayers: registeredPlayers,
        totalGamesWon: totalGamesWon,
        activeSessions: activeSessions,
        topWinners: topWinners,
        fetchedAt: DateTime.now().toUtc(),
      );
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('AdminStatsService refresh failed: $e\n$stackTrace');
      _error = 'error_generic';
    } finally {
      _loading = false;
      _refreshInFlight = false;
      notifyListeners();
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(_refresh());
      }
    }
  }

  /// Admin oturumu asla sayılmaz — önce hafif RPC, tablo select yedek.
  Future<int> _fetchActiveSessionCount(SupabaseClient client) async {
    try {
      final response = await client.rpc('get_admin_active_session_count');
      if (response is num) return response.toInt();
    } catch (e, stackTrace) {
      debugPrint(
        'AdminStatsService session RPC failed, trying select: $e\n$stackTrace',
      );
    }

    final adminId = AuthService.instance.currentUser?.id;
    try {
      final rows = await client.from('player_active_sessions').select('user_id');
      var count = 0;
      for (final raw in rows as List) {
        final id = Map<String, dynamic>.from(raw as Map)['user_id'] as String?;
        if (id == null || id == adminId) continue;
        count++;
      }
      return count;
    } catch (e, stackTrace) {
      debugPrint(
        'AdminStatsService session count unavailable: $e\n$stackTrace',
      );
      return 0;
    }
  }

  bool _isActiveInstance(Map<String, dynamic> row, DateTime staleBefore) {
    if (row['status'] != 'open') return false;

    final players = (row['real_player_count'] as num?)?.toInt() ?? 0;
    if (players <= 0) return false;

    final leaderRadius = (row['leader_radius'] as num?)?.toInt() ?? 0;
    if (leaderRadius >= RoomMatchmaking.leaderRadiusJoinThreshold) {
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

class _TierBuilder {
  _TierBuilder(this.roomType);

  final RoomType roomType;
  int activeUniverses = 0;
  int players = 0;
  int bots = 0;
  final List<AdminUniverseInstance> instances = [];

  void addInstance(AdminUniverseInstance instance) {
    activeUniverses++;
    players += instance.players;
    bots += instance.bots;
    instances.add(instance);
  }

  AdminUniverseTierStats build() {
    final difficulty = BotDifficulty.forRoom(roomType);
    instances.sort((a, b) => a.instanceNumber.compareTo(b.instanceNumber));
    return AdminUniverseTierStats(
      roomType: roomType,
      difficultyLabelKey:
          AdminUniverseTierStats.difficultyLabelKeyFor(roomType),
      activeUniverses: activeUniverses,
      players: players,
      bots: bots,
      huntPriority: difficulty.huntPriority,
      instances: List.unmodifiable(instances),
    );
  }
}
