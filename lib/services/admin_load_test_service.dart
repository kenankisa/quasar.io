import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/room_config.dart';
import '../game/room_type.dart';
import 'admin_access.dart';
import 'auth_service.dart';
import 'load_test_sim_player.dart';

class AdminLoadTestStatus {
  const AdminLoadTestStatus({
    required this.activePlayers,
    required this.maxPlayers,
    required this.byRoom,
    this.failedPlayers = 0,
  });

  final int activePlayers;
  final int maxPlayers;
  final int failedPlayers;
  final List<AdminLoadTestRoomBreakdown> byRoom;

  bool get isRunning => activePlayers > 0;

  factory AdminLoadTestStatus.empty() => const AdminLoadTestStatus(
        activePlayers: 0,
        maxPlayers: AdminLoadTestService.defaultMaxPlayers,
        byRoom: [],
      );
}

class AdminLoadTestRoomBreakdown {
  const AdminLoadTestRoomBreakdown({
    required this.roomType,
    required this.players,
    required this.rooms,
  });

  final String roomType;
  final int players;
  final int rooms;
}

/// Sim'lerin bulunduğu oda — paneldan / telefondan katılmak için.
class AdminLoadTestJoinTarget {
  const AdminLoadTestJoinTarget({
    required this.roomType,
    required this.roomInstanceId,
    required this.players,
    this.instanceNumber = 1,
  });

  final RoomType roomType;
  final String roomInstanceId;
  final int players;
  final int instanceNumber;
}

class AdminLoadTestStartResult {
  const AdminLoadTestStartResult({
    required this.started,
    required this.roomTypes,
    required this.roomsUsed,
    required this.activePlayers,
    this.failed = 0,
  });

  final int started;
  final List<String> roomTypes;
  final int roomsUsed;
  final int activePlayers;
  final int failed;

  String get roomTypeSummary => roomTypes.join(', ');
}

/// Gerçek çoklu hesap simülasyonu — her oyuncu ayrı Supabase istemcisi.
class AdminLoadTestService extends ChangeNotifier {
  AdminLoadTestService._();
  static final AdminLoadTestService instance = AdminLoadTestService._();

  /// Tek cihazdan açılabilecek gerçek istemci üst sınırı.
  /// Plan Realtime kotasına bağlı; kendi oturumun da sayılır.
  static const defaultMaxPlayers = 400;

  SupabaseClient get _adminClient => AuthService.instance.client;

  final List<LoadTestSimPlayer> _players = [];
  final List<RoomType> _activeRoomTypes = [];

  AdminLoadTestStatus get status => _buildStatus();

  /// Canlı sim odaları (aynı Realtime kanalına katılmak için).
  List<AdminLoadTestJoinTarget> get joinTargets {
    final counts = <String, int>{};
    final types = <String, RoomType>{};
    final numbers = <String, int>{};
    for (final p in _players.where((p) => p.isAlive)) {
      final id = p.roomInstanceId;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
      types[id] = p.roomType;
      numbers[id] = p.roomInstanceNumber ?? numbers[id] ?? 1;
    }
    final list = counts.entries
        .map(
          (e) => AdminLoadTestJoinTarget(
            roomType: types[e.key]!,
            roomInstanceId: e.key,
            players: e.value,
            instanceNumber: numbers[e.key] ?? 1,
          ),
        )
        .toList();
    list.sort((a, b) => b.players.compareTo(a.players));
    // Panelde 16+ buton şişmesin — en dolu birkaç oda yeterli
    if (list.length > 6) return list.sublist(0, 6);
    return list;
  }

  bool _loading = false;
  bool get loading => _loading;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool _migrationMissing = false;
  bool get migrationMissing => _migrationMissing;

  int _failed = 0;

  AdminLoadTestStatus _buildStatus() {
    final alive = _players.where((p) => p.isAlive).toList(growable: false);
    final grouped = <RoomType, List<LoadTestSimPlayer>>{};
    for (final p in alive) {
      grouped.putIfAbsent(p.roomType, () => []).add(p);
    }

    final byRoom = grouped.entries.map((e) {
      final ids = e.value
          .map((p) => p.roomInstanceId)
          .whereType<String>()
          .toSet();
      return AdminLoadTestRoomBreakdown(
        roomType: e.key.name,
        players: e.value.length,
        rooms: ids.length,
      );
    }).toList(growable: false);

    return AdminLoadTestStatus(
      activePlayers: alive.length,
      maxPlayers: defaultMaxPlayers,
      failedPlayers: _failed,
      byRoom: byRoom,
    );
  }

  Future<void> refresh({bool clearError = false}) async {
    if (_loading) return;
    _loading = true;
    if (clearError) _error = null;
    notifyListeners();

    // Ghost kalıntılarını temizle (eski test modu)
    try {
      await _adminClient.rpc('admin_stop_load_test');
    } catch (_) {
      // Ghost migration yoksa sorun değil
    }

    _loading = false;
    notifyListeners();
  }

  Future<AdminLoadTestStartResult?> start({
    required int count,
    required Iterable<RoomType> roomTypes,
  }) async {
    if (_busy) return null;

    final selected = roomTypes
        .where((r) => r != RoomType.simple)
        .toSet()
        .toList(growable: false);
    if (selected.isEmpty) {
      _error = 'admin_load_test_no_universe';
      notifyListeners();
      return null;
    }

    _busy = true;
    _error = null;
    _failed = 0;
    notifyListeners();

    try {
      // forceRefreshSession=false: başarısız refresh oturumu silip
      // yanlışlıkla "admin yetkisi gerekli" üretir.
      final isAdmin = await AdminAccess.refreshAdminStatus();
      if (!isAdmin) {
        final uid = AuthService.instance.currentUser?.id;
        _error = uid == null
            ? 'admin_load_test_forbidden'
            : 'admin_load_test_forbidden|rpc';
        return null;
      }

      await stop(silent: true);

      // Eski ghost sayaçlarını sıfırla
      try {
        await _adminClient.rpc('admin_stop_load_test');
      } catch (_) {}

      final target = count.clamp(1, defaultMaxPlayers);
      _activeRoomTypes
        ..clear()
        ..addAll(selected);
      final worldSizes = {
        for (final r in selected) r: RoomConfig.forRoom(r).worldSize,
      };
      final adminSession = _adminClient.auth.currentSession;

      // 1) Tüm sim hesaplarını ÖNCE üret — sim sign-in admin JWT'yi
      // bozarsa sonraki mint'ler "admin forbidden" olmasın.
      final mintedList = <LoadTestSimCredentials>[];
      for (var i = 1; i <= target; i++) {
        try {
          await _restoreAdminSession(adminSession);
          mintedList.add(await _mintCredentials(i));
        } catch (e, st) {
          debugPrint('Mint #$i failed: $e\n$st');
          _error = _humanizeStartError(e);
          if (mintedList.isEmpty) {
            _activeRoomTypes.clear();
            notifyListeners();
            return null;
          }
          break;
        }
      }

      // 2) Sonra ayrı istemcileri aç — seçili evrenlere sırayla dağıt
      // Auth rate limit (IP burst ~30–50) + tek cihazda bağlantı doygunluğu.
      var started = 0;
      var rateLimited = false;
      var connectionSaturated = false;
      for (var i = 0; i < mintedList.length; i++) {
        final index = i + 1;
        final roomType = selected[i % selected.length];
        final player = LoadTestSimPlayer(
          index: index,
          roomType: roomType,
          worldSize: worldSizes[roomType]!,
        );
        try {
          await player.start(minted: mintedList[i]);
          _players.add(player);
          started++;
          notifyListeners();
        } catch (e, st) {
          debugPrint('Sim player #$index failed: $e\n$st');
          _failed++;
          player.error = e.toString();
          await player.stop();
          if (_isAuthRateLimitError(e)) {
            rateLimited = true;
            _error = 'admin_load_test_auth_rate_limit|$started';
            debugPrint('Auth rate limit — pausing 45s before next clients…');
            await Future<void>.delayed(const Duration(seconds: 45));
            continue;
          }
          if (_isNetworkSaturationError(e)) {
            connectionSaturated = true;
            // Oynayan sim'ler daha ağır — tek cihaz tavanı genelde daha erken gelir
            _error = 'admin_load_test_connection_ceiling|$started';
            final pauseSec = started >= 200 ? 30 : 15;
            debugPrint(
              'Network saturation at $started live — pausing ${pauseSec}s…',
            );
            await Future<void>.delayed(Duration(seconds: pauseSec));
            continue;
          }
          _error = _humanizeStartError(e);
          if (started == 0) break;
        } finally {
          await _restoreAdminSession(adminSession);
        }
        // Yüksek sayıda canlı istemci varken join/auth için daha geniş aralık
        final gapMs = started >= 280
            ? 5000
            : started >= 200
                ? 3500
                : started >= 80
                    ? 2500
                    : 1500;
        await Future<void>.delayed(Duration(milliseconds: gapMs));
      }

      if (started <= 0) {
        _error ??= 'admin_load_test_start_failed';
        _activeRoomTypes.clear();
        notifyListeners();
        return null;
      }

      if (connectionSaturated && _failed > 0) {
        _error = 'admin_load_test_connection_ceiling|$started';
      } else if (rateLimited && _failed > 0) {
        _error = 'admin_load_test_auth_rate_limit|$started';
      } else if (_failed == 0) {
        _error = null;
      }

      final rooms = _players
          .where((p) => p.roomInstanceId != null)
          .map((p) => p.roomInstanceId!)
          .toSet()
          .length;

      return AdminLoadTestStartResult(
        started: started,
        roomTypes: selected.map((r) => r.name).toList(growable: false),
        roomsUsed: rooms,
        activePlayers: started,
        failed: _failed,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sim istemci girişi ana oturumu ezdiyse admin JWT'yi geri yükle.
  Future<void> _restoreAdminSession(Session? snapshot) async {
    if (snapshot == null) return;
    final current = _adminClient.auth.currentSession;
    if (current?.user.id == snapshot.user.id &&
        current?.accessToken == snapshot.accessToken) {
      return;
    }
    try {
      await _adminClient.auth.recoverSession(jsonEncode(snapshot.toJson()));
      debugPrint(
        'AdminLoadTest: restored admin session '
        '(was ${current?.user.id}, expect ${snapshot.user.id})',
      );
    } catch (e) {
      debugPrint('AdminLoadTest: restore admin session failed: $e');
    }
  }

  Future<LoadTestSimCredentials> _mintCredentials(int index) async {
    try {
      final response = await _adminClient.rpc(
        'admin_mint_sim_player',
        params: {
          'p_index': index,
          'p_display_name': 'Sim${index.toString().padLeft(3, '0')}',
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      final err = map['error'] as String?;
      if (err != null && err.isNotEmpty) {
        final hint = map['hint'] as String?;
        final sqlstate = map['sqlstate'] as String?;
        final parts = <String>['mint failed: $err'];
        if (hint != null && hint.isNotEmpty) parts.add('($hint)');
        if (sqlstate != null && sqlstate.isNotEmpty) {
          parts.add('[sqlstate=$sqlstate]');
        }
        throw StateError(parts.join(' '));
      }
      final email = map['email'] as String?;
      final password = map['password'] as String?;
      if (email == null || password == null) {
        throw StateError('mint failed: missing credentials');
      }
      return LoadTestSimCredentials(
        email: email,
        password: password,
        userId: map['user_id'] as String?,
        username: map['username'] as String?,
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

  bool _looksLikeMissingRpc(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('could not find the function') ||
        msg.contains('admin_mint_sim_player') ||
        msg.contains('schema cache') ||
        e.code == 'PGRST202';
  }

  bool _isAuthRateLimitError(Object e) {
    final lower = e.toString().toLowerCase();
    return lower.contains('over_request_rate_limit') ||
        lower.contains('request rate limit') ||
        lower.contains('statuscode: 429') ||
        lower.contains('status code: 429');
  }

  bool _isNetworkSaturationError(Object e) {
    final lower = e.toString().toLowerCase();
    return lower.contains('failed to fetch') ||
        lower.contains('clientexception') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('socketexception') ||
        lower.contains('network error');
  }

  String _humanizeStartError(Object e) {
    final msg = e.toString();
    final lower = msg.toLowerCase();
    if (_isAuthRateLimitError(e)) {
      return 'admin_load_test_auth_rate_limit';
    }
    if (_isNetworkSaturationError(e)) {
      return 'admin_load_test_connection_ceiling';
    }
    if (lower.contains('admin_mint_sim_player') ||
        lower.contains('migration_load_test_sim_mint') ||
        lower.contains('could not find the function') ||
        lower.contains('pgrst202')) {
      _migrationMissing = true;
      return 'admin_load_test_sim_mint_hint';
    }
    if (lower.contains('prepare_simulated_player')) {
      return 'admin_load_test_sim_migration_hint';
    }
    if (lower.contains('permission denied') ||
        lower.contains('auth.users')) {
      return 'admin_load_test_permission';
    }
    // Önce profile guard — 'forbidden' alt dizgesi admin hatası gibi görünmesin
    if (lower.contains('forbidden_profile_field')) {
      return 'admin_load_test_sim_mint_hint';
    }
    // Tam admin forbidden (forbidden_profile_field değil)
    if (RegExp(r'mint failed:\s*forbidden(\s|\(|$)').hasMatch(lower)) {
      return 'admin_load_test_forbidden|mint';
    }
    if (lower.contains('anonymous') ||
        lower.contains('signups not allowed') ||
        lower.contains('email not confirmed') ||
        lower.contains('auth failed') ||
        lower.contains('invalid login')) {
      return 'admin_load_test_sim_mint_hint';
    }
    if (lower.contains('not authenticated')) {
      return 'admin_load_test_forbidden|session';
    }
    if (lower.contains('first_login_lock') ||
        lower.contains('insufficient_diamonds')) {
      return 'admin_load_test_sim_migration_hint';
    }
    // Ham sunucu mesajını göster (yanlış "admin yetkisi" etiketleme)
    return 'admin_load_test_start_failed|$msg';
  }

  Future<int?> stop({bool silent = false}) async {
    if (_busy && !silent) return null;
    if (!silent) {
      _busy = true;
      _error = null;
      notifyListeners();
    }

    final n = _players.length;
    try {
      // Paralel kapat — hızlı temizlik
      await Future.wait(
        _players.map((p) => p.stop()),
        eagerError: false,
      );
      _players.clear();
      _activeRoomTypes.clear();
      _failed = 0;

      try {
        await _adminClient.rpc('admin_cleanup_simulated_players');
      } catch (e) {
        debugPrint('admin_cleanup_simulated_players: $e');
      }

      try {
        await _adminClient.rpc('admin_stop_load_test');
      } catch (_) {}

      return n;
    } catch (e, st) {
      debugPrint('load test stop failed: $e\n$st');
      if (!silent) _error = 'admin_load_test_stop_failed';
      return null;
    } finally {
      if (!silent) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  /// Geriye dönük API — artık istemci tarafı heartbeat kullanıyor.
  Future<void> heartbeat() async {}

  @override
  void dispose() {
    unawaited(stop(silent: true));
    super.dispose();
  }
}
