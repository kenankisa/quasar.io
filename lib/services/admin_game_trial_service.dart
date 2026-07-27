import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/room_config.dart';
import '../game/room_type.dart';
import '../utils/safe_debug.dart';
import 'admin_access.dart';
import 'admin_hardcore_live_service.dart';
import 'admin_stats_service.dart';
import 'auth_service.dart';
import 'load_test_sim_player.dart';

class GameTrialRankingRow {
  const GameTrialRankingRow({
    required this.userId,
    required this.username,
    required this.hardcorePoints,
    required this.gamesWon,
    required this.diamonds,
    required this.trophies,
    required this.inHardcore,
    required this.queued,
    this.inRoom = false,
    this.currentRadius,
  });

  final String userId;
  final String username;
  final int hardcorePoints;
  final int gamesWon;
  final int diamonds;
  final int trophies;
  final bool inHardcore;
  final bool queued;
  final bool inRoom;
  final int? currentRadius;

  factory GameTrialRankingRow.fromJson(Map<String, dynamic> json) {
    return GameTrialRankingRow(
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '—',
      hardcorePoints: (json['hardcore_points'] as num?)?.toInt() ?? 0,
      gamesWon: (json['games_won'] as num?)?.toInt() ?? 0,
      diamonds: (json['diamonds'] as num?)?.toInt() ?? 0,
      trophies: (json['trophies'] as num?)?.toInt() ?? 0,
      inHardcore: json['in_hardcore'] == true,
      queued: json['queued'] == true,
      inRoom: json['in_room'] == true,
      currentRadius: (json['current_radius'] as num?)?.toInt(),
    );
  }
}

class AdminGameTrialResetResult {
  const AdminGameTrialResetResult({
    required this.stoppedClients,
    required this.deletedUsers,
    required this.membersCleared,
    required this.queueCleared,
  });

  final int stoppedClients;
  final int deletedUsers;
  final int membersCleared;
  final int queueCleared;
}

class AdminGameTrialAddResult {
  const AdminGameTrialAddResult({
    required this.requested,
    required this.started,
    required this.failed,
    required this.activePlayers,
  });

  final int requested;
  final int started;
  final int failed;
  final int activePlayers;
}

/// Canlı oyuna sim oyuncu sokar — amaç Hardcore puanı biriktirmek.
///
/// Load test / Arena Test'ten farklı: gerçek Hardcore singleton + gerçek
/// `hardcore_points`. Admin durdurana kadar devam eder; ara sıra +N eklenebilir.
class AdminGameTrialService extends ChangeNotifier {
  AdminGameTrialService._();
  static final AdminGameTrialService instance = AdminGameTrialService._();

  static const maxPlayers = 500;
  static const spawnPresets = [1, 5, 10, 50, 100];

  SupabaseClient get _adminClient => AuthService.instance.client;

  final List<LoadTestSimPlayer> _players = [];
  final List<String> _eventLog = [];
  List<GameTrialRankingRow> _rankings = const [];

  List<String> get eventLog => List.unmodifiable(_eventLog);
  List<GameTrialRankingRow> get rankings => _rankings;

  int get activeCount => _players.where((p) => p.isAlive).length;
  int get queuedCount => _players.where((p) => p.isQueued).length;
  /// Live Hardcore seats only (training / Normal cups grind excluded).
  int get inArenaCount => _players
      .where(
        (p) =>
            p.isSeated &&
            p.roomType == RoomType.hardcore,
      )
      .length;
  int get sessionWins =>
      _players.fold<int>(0, (sum, p) => sum + p.hardcoreWins);

  /// Live sim radii keyed by user id (fresher than DB poll).
  Map<String, double> get liveRadii {
    final map = <String, double>{};
    for (final p in _players) {
      final id = p.userId;
      if (id == null || !p.isAlive || p.isQueued || !p.isSeated) continue;
      map[id] = p.radius;
    }
    return map;
  }

  bool get isRunning => activeCount > 0 || _busy;

  bool _busy = false;
  bool get busy => _busy;

  bool _stopping = false;
  bool get isStopping => _stopping;

  bool _resetting = false;
  bool get isResetting => _resetting;

  String? _error;
  String? get error => _error;

  bool _migrationMissing = false;
  bool get migrationMissing => _migrationMissing;

  Timer? _rankingsTimer;
  Timer? _liveUiTimer;
  Session? _adminSessionSnapshot;

  String? get liveHardcoreRoomId {
    for (final p in _players) {
      final id = p.roomInstanceId;
      if (id != null && id.isNotEmpty && !p.isQueued) return id;
    }
    return AdminHardcoreLiveService.instance.snapshot.roomId;
  }

  void _pushEvent(String message) {
    final stamp = DateTime.now().toLocal();
    final h = stamp.hour.toString().padLeft(2, '0');
    final m = stamp.minute.toString().padLeft(2, '0');
    final s = stamp.second.toString().padLeft(2, '0');
    _eventLog.insert(0, '[$h:$m:$s] $message');
    if (_eventLog.length > 80) {
      _eventLog.removeRange(80, _eventLog.length);
    }
    _notifySafe();
  }

  void _notifySafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    await Future.wait([
      AdminStatsService.instance.refresh(),
      AdminHardcoreLiveService.instance.refresh(),
      refreshRankings(),
    ]);
    _notifySafe();
  }

  Future<void> refreshRankings() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    final ids = _players
        .map((p) => p.userId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      _rankings = const [];
      _notifySafe();
      return;
    }
    try {
      final response = await _adminClient.rpc(
        'get_admin_game_trial_rankings',
        params: {'p_user_ids': ids},
      );
      final map = Map<String, dynamic>.from(response as Map);
      final raw = (map['rankings'] as List?) ?? const [];
      _rankings = raw
          .whereType<Map>()
          .map((e) => GameTrialRankingRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      _migrationMissing = false;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('get_admin_game_trial_rankings') ||
          msg.contains('could not find the function') ||
          msg.contains('pgrst202')) {
        _migrationMissing = true;
      }
      // Fallback: local session wins only.
      _rankings = _players
          .where((p) => p.userId != null)
          .map(
            (p) => GameTrialRankingRow(
              userId: p.userId!,
              username: p.displayName ?? 'Sim',
              hardcorePoints: p.hardcoreWins,
              gamesWon: p.hardcoreWins,
              diamonds: 0,
              trophies: 0,
              inHardcore: p.isAlive && !p.isQueued,
              queued: p.isQueued,
              inRoom: p.isSeated,
              currentRadius: p.isSeated ? p.radius.round() : null,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) {
          final hc = b.hardcorePoints.compareTo(a.hardcorePoints);
          if (hc != 0) return hc;
          return b.trophies.compareTo(a.trophies);
        });
    }
    _notifySafe();
  }

  void _ensureRankingsPoll() {
    _rankingsTimer?.cancel();
    if (activeCount <= 0) return;
    _rankingsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(refreshRankings());
    });
    _ensureLiveUiPoll();
  }

  void _ensureLiveUiPoll() {
    _liveUiTimer?.cancel();
    if (activeCount <= 0) return;
    _liveUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (activeCount <= 0) {
        _liveUiTimer?.cancel();
        _liveUiTimer = null;
        return;
      }
      _notifySafe();
    });
  }

  /// Add [count] new grinders without stopping existing ones.
  Future<AdminGameTrialAddResult?> addPlayers(int count) async {
    if (_busy || _stopping) return null;

    final room = (maxPlayers - activeCount).clamp(0, maxPlayers);
    final target = count.clamp(1, room);
    if (target <= 0) {
      _error = 'admin_game_trial_cap';
      _notifySafe();
      return null;
    }

    _busy = true;
    _error = null;
    _lastDetail = null;
    _notifySafe();

    var started = 0;
    var failed = 0;

    try {
      final isAdmin = await AdminAccess.refreshAdminStatus();
      if (!isAdmin) {
        _error = 'admin_game_trial_forbidden';
        return null;
      }

      _adminSessionSnapshot = _adminClient.auth.currentSession;
      final adminSession = _adminSessionSnapshot;
      AuthService.instance.pinCurrentSession();
      final worldSize = RoomConfig.forRoom(RoomType.hardcore).worldSize;
      final nextIndex = _players.isEmpty
          ? 1
          : (_players.map((p) => p.index).reduce((a, b) => a > b ? a : b) + 1);

      final mintedList = <LoadTestSimCredentials>[];
      for (var i = 0; i < target; i++) {
        final index = nextIndex + i;
        try {
          await _restoreAdminSession(adminSession);
          mintedList.add(await _mintCredentials(index));
        } catch (e, st) {
          safeDebugPrint('GameTrial mint #$index failed: $e\n$st');
          _error = _humanizeError(e);
          if (mintedList.isEmpty) return null;
          break;
        }
      }

      for (var i = 0; i < mintedList.length; i++) {
        final index = nextIndex + i;
        final player = LoadTestSimPlayer(
          index: index,
          roomType: RoomType.hardcore,
          worldSize: worldSize,
          mode: SimDeploymentMode.gameTrial,
          onArenaEvent: _pushEvent,
        );
        try {
          await player.start(minted: mintedList[i]);
          _players.add(player);
          started++;
          _pushEvent(
            '${player.displayName ?? 'Sim$index'} '
            'online — will play training → cups → Hardcore',
          );
          _notifySafe();
        } catch (e, st) {
          safeDebugPrint('GameTrial sim #$index failed: $e\n$st');
          failed++;
          player.error = e.toString();
          await player.stop();
          _error = _humanizeError(e);
          if (started == 0 && i == 0) break;
        } finally {
          await _restoreAdminSession(adminSession);
          await AuthService.instance.restorePinnedSession();
        }

        final gapMs = started >= 80
            ? 2500
            : started >= 20
                ? 1500
                : 900;
        await Future<void>.delayed(Duration(milliseconds: gapMs));
      }

      if (started <= 0) {
        _error ??= 'admin_game_trial_start_failed';
        return null;
      }

      _ensureRankingsPoll();
      unawaited(refreshRankings());
      unawaited(AdminHardcoreLiveService.instance.refresh());
      unawaited(AdminStatsService.instance.refresh());

      return AdminGameTrialAddResult(
        requested: target,
        started: started,
        failed: failed,
        activePlayers: activeCount,
      );
    } finally {
      // Keep pin while any trial clients are live — their BroadcastChannel
      // events would otherwise steal / wipe the admin session.
      if (activeCount <= 0) {
        AuthService.instance.unpinSession();
      }
      _busy = false;
      _notifySafe();
    }
  }

  Future<int?> stopAll() async {
    if (_busy && !_stopping) return null;
    _stopping = true;
    _busy = true;
    _error = null;
    _notifySafe();

    final n = _players.length;
    try {
      _rankingsTimer?.cancel();
      _rankingsTimer = null;
      _liveUiTimer?.cancel();
      _liveUiTimer = null;
      await Future.wait(
        _players.map((p) => p.stop()),
        eagerError: false,
      );
      _players.clear();
      _rankings = const [];
      _pushEvent('Stopped $n trial clients');

      try {
        await _adminClient.rpc('admin_cleanup_simulated_players');
      } catch (e) {
        debugPrint('admin_cleanup_simulated_players: $e');
      }

      await _restoreAdminSession(_adminSessionSnapshot);
      await AuthService.instance.restorePinnedSession();
      AuthService.instance.unpinSession();
      unawaited(AdminHardcoreLiveService.instance.refresh());
      unawaited(AdminStatsService.instance.refresh());
      return n;
    } catch (e, st) {
      debugPrint('game trial stop failed: $e\n$st');
      _error = 'admin_game_trial_stop_failed';
      return null;
    } finally {
      _stopping = false;
      _busy = false;
      _notifySafe();
    }
  }

  /// Stop all clients + wipe every game-trial sim (rooms, queue, profile, auth).
  Future<AdminGameTrialResetResult?> resetAll() async {
    if (_busy && !_stopping) return null;
    _stopping = true;
    _resetting = true;
    _busy = true;
    _error = null;
    _lastDetail = null;
    _notifySafe();

    final n = _players.length;
    try {
      _rankingsTimer?.cancel();
      _rankingsTimer = null;
      _liveUiTimer?.cancel();
      _liveUiTimer = null;
      await Future.wait(
        _players.map((p) => p.stop()),
        eagerError: false,
      );
      _players.clear();
      _rankings = const [];
      _eventLog.clear();

      var deleted = 0;
      var membersCleared = 0;
      var queueCleared = 0;

      try {
        await _restoreAdminSession(_adminSessionSnapshot);
        final response = await _adminClient.rpc('admin_reset_game_trial');
        final map = Map<String, dynamic>.from(response as Map);
        if (map['ok'] == false) {
          _migrationMissing = false;
          _error = 'admin_game_trial_reset_failed';
          _lastDetail = (map['error'] as String?) ?? map.toString();
          _pushEvent('Reset failed: ${_lastDetail ?? 'unknown'}');
          return null;
        }
        deleted = (map['deleted'] as num?)?.toInt() ?? 0;
        membersCleared = (map['members_cleared'] as num?)?.toInt() ?? 0;
        queueCleared = (map['queue_cleared'] as num?)?.toInt() ?? 0;
      } on PostgrestException catch (e) {
        if (_looksLikeMissingRpc(e) ||
            e.message.toLowerCase().contains('admin_reset_game_trial')) {
          _migrationMissing = false;
          _error = 'admin_game_trial_reset_migration_hint';
          // Fallback: generic sim cleanup so Stop-like wipe still happens.
          try {
            await _adminClient.rpc('admin_cleanup_simulated_players');
          } catch (_) {}
          return null;
        }
        _error = 'admin_game_trial_reset_failed';
        _lastDetail = _redact(e.toString());
        return null;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('admin_reset_game_trial') ||
            msg.contains('could not find the function') ||
            msg.contains('pgrst202')) {
          _migrationMissing = false;
          _error = 'admin_game_trial_reset_migration_hint';
          try {
            await _adminClient.rpc('admin_cleanup_simulated_players');
          } catch (_) {}
          return null;
        }
        _error = 'admin_game_trial_reset_failed';
        _lastDetail = _redact(e.toString());
        return null;
      }

      _pushEvent(
        'Reset: stopped $n clients, deleted $deleted sims, '
        'left $membersCleared seats, cleared $queueCleared queue',
      );

      await _restoreAdminSession(_adminSessionSnapshot);
      await AuthService.instance.restorePinnedSession();
      AuthService.instance.unpinSession();
      unawaited(AdminHardcoreLiveService.instance.refresh());
      unawaited(AdminStatsService.instance.refresh());

      return AdminGameTrialResetResult(
        stoppedClients: n,
        deletedUsers: deleted,
        membersCleared: membersCleared,
        queueCleared: queueCleared,
      );
    } catch (e, st) {
      debugPrint('game trial reset failed: $e\n$st');
      _error = 'admin_game_trial_reset_failed';
      return null;
    } finally {
      _resetting = false;
      _stopping = false;
      _busy = false;
      _notifySafe();
    }
  }

  Future<void> _restoreAdminSession(Session? snapshot) async {
    if (snapshot == null) return;
    final current = _adminClient.auth.currentSession;
    final currentId = current?.user.id;
    final expectId = snapshot.user.id;
    if (currentId != null && currentId == expectId) return;
    try {
      await _adminClient.auth.recoverSession(jsonEncode(snapshot.toJson()));
    } catch (e) {
      safeDebugPrint('GameTrial: restore admin session failed: $e');
    }
  }

  Future<LoadTestSimCredentials> _mintCredentials(int index) async {
    try {
      final response = await _adminClient.rpc(
        'admin_mint_sim_player',
        params: {
          'p_index': index,
          'p_display_name': 'Gt${index.toString().padLeft(3, '0')}',
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      final err = map['error'] as String?;
      if (err != null && err.isNotEmpty) {
        throw StateError('mint failed: $err');
      }
      final email = map['email'] as String?;
      final userId = map['user_id'] as String?;
      if (email == null || userId == null) {
        throw StateError('mint failed: missing credentials');
      }

      try {
        await _adminClient.rpc(
          'admin_mark_game_trial_player',
          params: {'p_user_id': userId},
        );
      } catch (e) {
        _migrationMissing = true;
        throw StateError(
          'admin_mark_game_trial_player missing — '
          'run migration_game_trial_real_rules.sql ($e)',
        );
      }

      var password = map['password'] as String?;
      if (password == null || password.isEmpty) {
        final secretResponse = await _adminClient.rpc(
          'admin_claim_sim_mint_secret',
          params: {'p_user_id': userId},
        );
        final secretMap = Map<String, dynamic>.from(secretResponse as Map);
        password = secretMap['password'] as String?;
      }
      if (password == null || password.isEmpty) {
        throw StateError('mint failed: missing one-time secret');
      }

      return LoadTestSimCredentials(
        email: email,
        password: password,
        userId: userId,
        username: map['username'] as String?,
      );
    } on PostgrestException catch (e) {
      if (_looksLikeMissingRpc(e)) {
        _migrationMissing = true;
        throw StateError(
          'admin_mint_sim_player missing — run migration_load_test_sim_mint.sql',
        );
      }
      rethrow;
    }
  }

  bool _looksLikeMissingRpc(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('could not find the function') ||
        msg.contains('admin_mint_sim_player') ||
        msg.contains('schema cache') ||
        e.code == 'PGRST202';
  }

  String? _lastDetail;
  String? get lastErrorDetail => _lastDetail;

  String _humanizeError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    _lastDetail = _redact(raw);
    if (lower.contains('admin_reset_game_trial') ||
        lower.contains('migration_game_trial_reset')) {
      _migrationMissing = true;
      return 'admin_game_trial_reset_migration_hint';
    }
    if (lower.contains('prepare_game_trial') ||
        lower.contains('admin_mark_game_trial') ||
        lower.contains('sim_prepare_live_hardcore') ||
        lower.contains('migration_game_trial')) {
      _migrationMissing = true;
      return 'admin_game_trial_migration_hint';
    }
    if (lower.contains('admin_mint_sim_player') ||
        lower.contains('migration_load_test_sim_mint')) {
      _migrationMissing = true;
      return 'admin_load_test_sim_mint_hint';
    }
    if (lower.contains('forbidden')) return 'admin_game_trial_forbidden';
    if (lower.contains('over_request_rate_limit') ||
        lower.contains('429')) {
      return 'admin_load_test_auth_rate_limit';
    }
    if (lower.contains('training_stuck')) {
      return 'admin_game_trial_training_stuck';
    }
    return 'admin_game_trial_start_failed';
  }

  static String _redact(String msg) {
    return msg
        .replaceAll(RegExp(r'SimLt_[A-Za-z0-9_]+'), 'SimLt_***')
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          'eyJ***.***.***',
        );
  }

  @override
  void dispose() {
    _rankingsTimer?.cancel();
    _liveUiTimer?.cancel();
    unawaited(stopAll());
    super.dispose();
  }
}
