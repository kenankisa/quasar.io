import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/hardcore_rules.dart';
import '../game/config/room_config.dart';
import '../game/models/admin_hardcore_arena_test.dart';
import '../game/room_type.dart';
import '../utils/safe_debug.dart';
import 'admin_access.dart';
import 'auth_service.dart';
import 'load_test_sim_player.dart';

/// Isolated Hardcore Arena Test harness (sim accounts + admin join).
class AdminHardcoreArenaTestService extends ChangeNotifier {
  AdminHardcoreArenaTestService._();
  static final AdminHardcoreArenaTestService instance =
      AdminHardcoreArenaTestService._();

  static const maxPlayers = 200;
  /// Live Hardcore seat cap is separate (usually 20); extras queue outside.
  static const _opsPollInterval = Duration(seconds: 2);
  /// Pause between sim joins. Faster while filling the live seat cap (~20).
  static const _simSpawnGapFill = Duration(milliseconds: 900);
  static const _simSpawnGapOverflow = Duration(milliseconds: 1600);

  SupabaseClient get _adminClient => AuthService.instance.client;

  final List<LoadTestSimPlayer> _players = [];
  AdminHardcoreArenaTestSnapshot _snapshot =
      AdminHardcoreArenaTestSnapshot.empty();
  AdminHardcoreArenaTestSnapshot get snapshot => _snapshot;

  int get activeSimCount => _players.where((p) => p.isAlive).length;
  int get queuedSimCount => _players.where((p) => p.isQueued).length;
  int get inArenaSimCount =>
      _players.where((p) => p.isAlive && !p.isQueued).length;
  int get targetCount => _targetCount;
  int _targetCount = 0;

  /// Snapshot of admin JWT before sim mint/sign-in (restored on stop/reset).
  Session? _adminSessionSnapshot;

  String? get roomInstanceId {
    final fromSnap = _snapshot.roomId;
    if (fromSnap != null && fromSnap.isNotEmpty) return fromSnap;
    for (final p in _players) {
      final id = p.roomInstanceId;
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  bool get isRunning => activeSimCount > 0 || _targetCount > 0;

  bool get loading => false;

  bool _busy = false;
  bool get busy => _busy || _stopping;
  bool get isStopping => _stopping;

  bool _stopping = false;
  bool _cancelReconcile = false;
  bool _reconcileQueued = false;

  /// User ids currently mid-spawn (joined DB before [_players].add).
  /// Must stay in reconcile keep-list or the 2s ops poll kicks them.
  final Set<String> _spawningUserIds = {};

  /// Admin is in the test GameScreen — keep their seat; otherwise reconcile
  /// + explicit release remove them (admin must enter only via "Test arenasına gir").
  bool _adminInArena = false;
  bool get adminInArena => _adminInArena;

  /// Stable admin id while in arena (avoid relying on currentUser during ops).
  String? _adminArenaUserId;

  void setAdminInArena(bool value) {
    if (value) {
      _adminSessionSnapshot ??= _adminClient.auth.currentSession;
      _adminArenaUserId = _adminClient.auth.currentUser?.id ??
          _adminSessionSnapshot?.user.id;
      if (_adminInArena) return;
      _adminInArena = true;
      notifyListeners();
      return;
    }

    if (!_adminInArena && _adminArenaUserId == null) return;
    final ejectId = _adminArenaUserId ??
        _adminSessionSnapshot?.user.id ??
        _adminClient.auth.currentUser?.id;
    _adminInArena = false;
    _adminArenaUserId = null;
    notifyListeners();
    unawaited(() async {
      await _ejectAdminSeat(ejectId);
      await refreshOps();
    }());
  }

  static const _maxEvents = 40;
  final List<String> _eventLog = [];
  List<String> get eventLog => List.unmodifiable(_eventLog);

  String? _error;
  String? get error => _error;

  bool _migrationMissing = false;
  bool get migrationMissing => _migrationMissing;

  Timer? _opsPoll;
  int _failed = 0;
  int get failedPlayers => _failed;

  /// Live sim radii keyed by user id (for panel display).
  Map<String, double> get liveRadii {
    final map = <String, double>{};
    for (final p in _players) {
      final id = p.userId;
      if (id == null || !p.isAlive) continue;
      map[id] = p.radius;
    }
    return map;
  }

  void attach() {
    _opsPoll?.cancel();
    _opsPoll = Timer.periodic(_opsPollInterval, (_) => unawaited(refreshOps()));
    unawaited(refreshOps());
  }

  void detach() {
    _opsPoll?.cancel();
    _opsPoll = null;
  }

  Future<void> refreshOps() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    // While hard-stopping, don't re-fetch stale members into the UI.
    if (_stopping) return;
    _pruneDeadSims();
    try {
      await _restoreAdminSession(_adminSessionSnapshot ??
          _adminClient.auth.currentSession);
      // Never purge mid-spawn — new sims join the room before they are in
      // [_players], and would be kicked as "ghosts".
      if (!_busy) {
        await _reconcileServerMembers();
      }
      if (_stopping) return;
      final response =
          await _adminClient.rpc('get_admin_hardcore_arena_test_ops');
      if (_stopping) return;
      if (response is Map) {
        _snapshot = AdminHardcoreArenaTestSnapshot.fromJson(
          Map<String, dynamic>.from(response),
        );
        _migrationMissing = false;
        // True in-room headcount + queue so sims can hold seats for queue tests.
        final queueN = _snapshot.queueCount > queuedSimCount
            ? _snapshot.queueCount
            : queuedSimCount;
        HardcoreArenaAliveHint.setTestArenaOps(
          members: _snapshot.players.length,
          queue: queueN,
          seatCap: _snapshot.maxPlayers > 0
              ? _snapshot.maxPlayers
              : HardcoreRules.liveMaxPlayers,
          simTarget: _targetCount,
        );
        // Do not clear sticky spawn errors on every poll.
        notifyListeners();
      }
    } on PostgrestException catch (e) {
      if (_looksLikeMissingRpc(e)) {
        _migrationMissing = true;
        _error = 'admin_hc_test_migration_hint';
      } else {
        _error = e.message;
      }
      notifyListeners();
    } catch (e) {
      safeDebugPrint('hardcore arena test ops: $e');
    }
  }

  /// Drop ghost sim seats so occupancy stays ≤20 and new sims can enter.
  /// Admin is kept only while [adminInArena] (explicit "Enter test arena").
  Future<void> _reconcileServerMembers() async {
    final keep = <String>{
      ..._spawningUserIds,
      for (final p in _players)
        if (p.userId != null && p.userId!.isNotEmpty && !p.isQueued)
          p.userId!,
    };
    if (_adminInArena) {
      final adminId = _adminArenaUserId ??
          _adminSessionSnapshot?.user.id ??
          _adminClient.auth.currentUser?.id;
      if (adminId != null && adminId.isNotEmpty) {
        _adminArenaUserId ??= adminId;
        keep.add(adminId);
      }
    } else {
      // Panel-only: never leave admin seated/queued while driving sims.
      await _ejectAdminSeat(
        _adminSessionSnapshot?.user.id ?? _adminClient.auth.currentUser?.id,
      );
    }
    try {
      await _adminClient.rpc(
        'admin_hardcore_test_reconcile_members',
        params: {'p_keep_user_ids': keep.toList(growable: false)},
      );
    } on PostgrestException catch (e) {
      // Older DBs without the migration — ignore; join still works if seats free.
      if (_looksLikeMissingRpc(e) ||
          (e.message.toLowerCase().contains('reconcile'))) {
        return;
      }
      safeDebugPrint('admin_hardcore_test_reconcile_members: ${e.message}');
    } catch (e) {
      safeDebugPrint('admin_hardcore_test_reconcile_members: $e');
    }
  }

  /// Force admin off Arena Test seat/queue unless they pressed Enter.
  Future<void> _ejectAdminSeat(String? adminId) async {
    if (_adminInArena) return;
    if (adminId == null || adminId.isEmpty) return;
    final roomId = roomInstanceId ?? _snapshot.roomId;
    if (roomId == null || roomId.isEmpty) return;
    try {
      await _adminClient.rpc(
        'hardcore_release_member',
        params: {
          'p_room_instance_id': roomId,
          'p_user_id': adminId,
        },
      );
    } catch (e) {
      safeDebugPrint('eject admin arena-test seat: $e');
    }
  }

  void pushEvent(String message) {
    final line =
        '${DateTime.now().toUtc().toIso8601String().substring(11, 19)}  $message';
    _eventLog.insert(0, line);
    while (_eventLog.length > _maxEvents) {
      _eventLog.removeLast();
    }
    notifyListeners();
  }

  void clearEventLog() {
    _eventLog.clear();
    notifyListeners();
  }

  void _pruneDeadSims() {
    final dead = _players.where((p) => !p.isAlive).toList(growable: false);
    if (dead.isEmpty) return;
    _players.removeWhere((p) => !p.isAlive);
    for (final p in dead) {
      final id = p.userId;
      final roomId = p.roomInstanceId ?? _snapshot.roomId;
      if (id == null || roomId == null) continue;
      unawaited(() async {
        try {
          await _adminClient.rpc(
            'hardcore_release_member',
            params: {
              'p_room_instance_id': roomId,
              'p_user_id': id,
            },
          );
        } catch (_) {}
      }());
    }
    notifyListeners();
    if (!_busy && !_stopping && _targetCount > activeSimCount) {
      _reconcileQueued = true;
      unawaited(_drainReconcileQueue());
    }
  }

  void _clearLocalUi({String? keepRoomId}) {
    HardcoreArenaAliveHint.clear();
    _snapshot = AdminHardcoreArenaTestSnapshot(
      roomId: keepRoomId ?? _snapshot.roomId,
      status: 'open',
      leaderRadius: 25,
      realPlayerCount: 0,
      seatOccupancy: 0,
      maxPlayers: _snapshot.maxPlayers,
      players: const [],
      queue: const [],
      queueCount: 0,
      victoryRadius: _snapshot.victoryRadius,
      victoryMinAlive: _snapshot.victoryMinAlive,
      victoryStableSeconds: _snapshot.victoryStableSeconds,
      victoryMinPvpFraction: _snapshot.victoryMinPvpFraction,
      spawnProtectionSeconds: _snapshot.spawnProtectionSeconds,
      lowPopRadiusCap: _snapshot.lowPopRadiusCap,
      lateFoodSoftcapRadius: _snapshot.lateFoodSoftcapRadius,
      lateFoodSoftcapMultiplier: _snapshot.lateFoodSoftcapMultiplier,
      matchGeneration: _snapshot.matchGeneration,
      economyIsolated: true,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  /// Set absolute sim target (0–[maxPlayers]). Seat cap matches live Hardcore
  /// (usually 20); extras wait in the test queue until a seat frees.
  Future<void> setSimCount(int count) async {
    if (_stopping) return;
    final target = count.clamp(0, maxPlayers);
    _targetCount = target;
    notifyListeners();
    if (_busy) {
      _reconcileQueued = true;
      return;
    }
    await _reconcileToTarget();
  }

  Future<void> _drainReconcileQueue() async {
    if (_stopping || _busy || !_reconcileQueued) return;
    _reconcileQueued = false;
    await _reconcileToTarget();
  }

  Future<void> incrementSims() => setSimCount(_targetCount + 1);

  Future<void> decrementSims() => setSimCount(_targetCount - 1);

  Future<void> _reconcileToTarget() async {
    if (_busy || _stopping) return;
    _busy = true;
    _cancelReconcile = false;
    _error = null;
    _adminSessionSnapshot ??= _adminClient.auth.currentSession;
    notifyListeners();

    try {
      final isAdmin = await AdminAccess.refreshAdminStatus();
      if (!isAdmin) {
        _error = 'admin_hc_test_forbidden';
        return;
      }
      if (_cancelReconcile || _stopping) return;

      await _restoreAdminSession(
        _adminSessionSnapshot ?? _adminClient.auth.currentSession,
      );
      await _reconcileServerMembers();
      if (_cancelReconcile || _stopping) return;

      // Trim extras first
      while (!_cancelReconcile &&
          !_stopping &&
          activeSimCount > _targetCount) {
        final victim = _players.lastWhere(
          (p) => p.isAlive,
          orElse: () => _players.last,
        );
        await victim.stop();
        _players.remove(victim);
        notifyListeners();
      }

      if (_cancelReconcile || _stopping) return;

      if (_targetCount <= activeSimCount) {
        await refreshOps();
        return;
      }

      final adminSession =
          _adminSessionSnapshot ?? _adminClient.auth.currentSession;
      final worldSize = RoomConfig.forRoom(RoomType.hardcore).worldSize;
      var consecutiveFails = 0;

      while (!_cancelReconcile &&
          !_stopping &&
          activeSimCount < _targetCount) {
        final index = _nextIndex();
        String? spawningId;
        try {
          await _restoreAdminSession(adminSession);
          final minted = await _mintCredentials(index);
          await _restoreAdminSession(adminSession);
          if (_cancelReconcile || _stopping) break;
          spawningId = minted.userId;
          if (spawningId != null && spawningId.isNotEmpty) {
            _spawningUserIds.add(spawningId);
          }
          final player = LoadTestSimPlayer(
            index: index,
            roomType: RoomType.hardcore,
            worldSize: worldSize,
            onArenaEvent: pushEvent,
          );
          try {
            await player.start(minted: minted);
          } catch (e) {
            // Release seat/session if join succeeded but later start steps failed.
            try {
              await player.stop();
            } catch (_) {}
            rethrow;
          }
          if (_cancelReconcile || _stopping) {
            await player.stop();
            break;
          }
          _players.add(player);
          consecutiveFails = 0;
          if (player.isQueued) {
            pushEvent(
              '${player.displayName ?? 'Sim'} queued '
              '(seats ${_snapshot.seatOccupancy}/${_snapshot.maxPlayers})',
            );
          } else {
            pushEvent('${player.displayName ?? 'Sim'} joined arena');
          }
          notifyListeners();
        } catch (e, st) {
          _failed++;
          consecutiveFails++;
          safeDebugPrint('HC test sim #$index failed: $e\n$st');
          _error = _humanizeError(e);
          if (_looksLikeMissingMint(e)) {
            _migrationMissing = true;
            break;
          }
          pushEvent('Sim#$index failed — retrying… (${_humanizeError(e)})');
          if (consecutiveFails >= 8) {
            pushEvent('Too many spawn failures — paused. Try again shortly.');
            break;
          }
          await Future<void>.delayed(const Duration(seconds: 3));
          continue;
        } finally {
          if (spawningId != null) {
            _spawningUserIds.remove(spawningId);
          }
          await _restoreAdminSession(adminSession);
        }
        if (_cancelReconcile || _stopping) break;
        final seatCap = _snapshot.maxPlayers > 0
            ? _snapshot.maxPlayers
            : HardcoreRules.liveMaxPlayers;
        final gap = inArenaSimCount < seatCap
            ? _simSpawnGapFill
            : _simSpawnGapOverflow;
        await Future<void>.delayed(gap);
      }

      if (!_cancelReconcile && !_stopping) {
        await refreshOps();
      }
    } finally {
      _busy = false;
      notifyListeners();
      if (_reconcileQueued && !_stopping) {
        unawaited(_drainReconcileQueue());
      }
    }
  }

  int _nextIndex() {
    var max = 0;
    for (final p in _players) {
      if (p.index > max) max = p.index;
    }
    return max + 1;
  }

  /// Force-stop every sim, clear queue/members on server, wipe local UI.
  Future<void> stopAll({bool resetServer = true}) async {
    if (_stopping) return;

    _stopping = true;
    _cancelReconcile = true;
    _reconcileQueued = false;
    _targetCount = 0;
    _error = null;
    _adminInArena = false;
    _adminArenaUserId = null;
    _spawningUserIds.clear();
    _eventLog.clear();

    // Instant UI clear — don't wait for network.
    final toStop = List<LoadTestSimPlayer>.from(_players);
    _players.clear();
    _failed = 0;
    _clearLocalUi();
    notifyListeners();

    // Let an in-flight reconcile notice cancel (spawn loop checks flag).
    for (var i = 0; i < 40 && _busy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    try {
      await Future.wait(
        toStop.map((p) async {
          try {
            await p.stop();
          } catch (e) {
            debugPrint('HC test sim stop: $e');
          }
        }),
        eagerError: false,
      );

      // Any late-started sims that reconcile added after our copy.
      final leftovers = List<LoadTestSimPlayer>.from(_players);
      _players.clear();
      await Future.wait(
        leftovers.map((p) async {
          try {
            await p.stop();
          } catch (_) {}
        }),
        eagerError: false,
      );

      if (resetServer) {
        final adminSession =
            _adminSessionSnapshot ?? _adminClient.auth.currentSession;
        await _restoreAdminSession(adminSession);
        try {
          await AdminAccess.refreshAdminStatus();
        } catch (_) {}
        try {
          await _adminClient.rpc('admin_hardcore_arena_test_reset');
        } catch (e) {
          debugPrint('admin_hardcore_arena_test_reset: $e');
          _error = e.toString();
        }
        try {
          await _adminClient.rpc('admin_cleanup_simulated_players');
        } catch (_) {
          // Optional ghost cleanup — ignore if missing.
        }
      }

      _clearLocalUi();
      notifyListeners();

      // Confirm empty from server (stopping flag blocks mid-refresh).
      _stopping = false;
      await refreshOps();
    } finally {
      _stopping = false;
      _cancelReconcile = false;
      _busy = false;
      _targetCount = 0;
      notifyListeners();
    }
  }

  Future<bool> forceSetRadius({
    required String userId,
    required double radius,
  }) async {
    try {
      for (final p in _players) {
        if (p.userId == userId && p.isAlive) {
          p.applyForcedRadius(radius);
        }
      }
      await _restoreAdminSession(
        _adminSessionSnapshot ?? _adminClient.auth.currentSession,
      );
      await _adminClient.rpc(
        'admin_hardcore_test_set_radius',
        params: {
          'p_user_id': userId,
          'p_radius': radius,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> forceAbsorb({
    required String predatorId,
    required String preyId,
  }) async {
    try {
      for (final p in _players) {
        if (p.userId == predatorId && p.isAlive) {
          p.applyForceAbsorb(preyId);
        }
      }
      await _restoreAdminSession(
        _adminSessionSnapshot ?? _adminClient.auth.currentSession,
      );
      await _adminClient.rpc(
        'admin_hardcore_test_force_absorb',
        params: {
          'p_predator_id': predatorId,
          'p_prey_id': preyId,
        },
      );
      unawaited(Future<void>.delayed(const Duration(milliseconds: 400), () async {
        for (final p in _players.where((p) => p.userId == preyId).toList()) {
          await p.stop();
          _players.remove(p);
          if (_targetCount > 0) _targetCount--;
        }
        notifyListeners();
        await refreshOps();
      }));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<LoadTestSimCredentials> _mintCredentials(int index) async {
    try {
      final response = await _adminClient.rpc(
        'admin_mint_sim_player',
        params: {
          'p_index': index,
          'p_display_name': 'HcSim${index.toString().padLeft(3, '0')}',
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
        username: map['username'] as String? ??
            'HcSim${index.toString().padLeft(3, '0')}',
      );
    } on PostgrestException catch (e) {
      if (_looksLikeMissingRpc(e)) {
        throw StateError(
          'admin_mint_sim_player missing — run migration_load_test_sim_mint.sql',
        );
      }
      rethrow;
    }
  }

  /// Keep admin JWT on the shared client. Sims use separate clients — only
  /// recover when signed out or a different user is active. Never rewind a
  /// refreshed access token (that fires auth churn → AuthGate pops to lobby).
  Future<void> _restoreAdminSession(Session? snapshot) async {
    if (snapshot == null) return;
    final current = _adminClient.auth.currentSession;
    final currentId = current?.user.id;
    final expectId = snapshot.user.id;

    if (currentId != null && currentId == expectId) {
      // Same admin — prefer the live (possibly refreshed) session.
      _adminSessionSnapshot = current;
      return;
    }

    try {
      await _adminClient.auth.recoverSession(jsonEncode(snapshot.toJson()));
      _adminSessionSnapshot =
          _adminClient.auth.currentSession ?? snapshot;
    } catch (e) {
      safeDebugPrint('HC test: restore admin session failed: $e');
    }
  }

  bool _looksLikeMissingRpc(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('could not find the function') ||
        msg.contains('schema cache') ||
        e.code == 'PGRST202' ||
        msg.contains('get_admin_hardcore_arena_test_ops') ||
        msg.contains('join_hardcore_test_universe') ||
        msg.contains('hardcore_release_member') ||
        msg.contains('admin_hardcore_test_reconcile_members');
  }

  bool _looksLikeMissingMint(Object e) {
    final lower = e.toString().toLowerCase();
    return lower.contains('admin_mint_sim_player') ||
        lower.contains('join_hardcore_test_universe') ||
        lower.contains('migration_hardcore_arena_test');
  }

  String _humanizeError(Object e) {
    final lower = e.toString().toLowerCase();
    if (_looksLikeMissingMint(e) || lower.contains('pgrst202')) {
      _migrationMissing = true;
      return 'admin_hc_test_migration_hint';
    }
    if (lower.contains('forbidden') || lower.contains('hardcore_test_forbidden')) {
      return 'admin_hc_test_forbidden';
    }
    // Surface the real RPC/client message — generic key hid stack-depth bugs.
    if (e is PostgrestException) {
      final msg = e.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    final raw = e.toString().trim();
    if (raw.isNotEmpty) return raw;
    return 'admin_hc_test_start_failed';
  }

  @override
  void dispose() {
    detach();
    unawaited(stopAll(resetServer: false));
    super.dispose();
  }
}
