import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/room_type.dart';
import '../utils/app_navigator.dart';
import 'app_idle_config_service.dart';
import 'auth_service.dart';
import 'device_id_service.dart';
import 'room_matchmaking_service.dart';

class PlayerAlreadyActiveException implements Exception {
  const PlayerAlreadyActiveException();

  @override
  String toString() => 'player_already_active';
}

class PlayerSessionStatus {
  const PlayerSessionStatus({
    required this.active,
    required this.ownDevice,
    this.roomType,
  });

  final bool active;
  final bool ownDevice;
  final String? roomType;

  bool get blockedOnOtherDevice => active && !ownDevice;

  factory PlayerSessionStatus.fromJson(Map<String, dynamic> json) {
    return PlayerSessionStatus(
      active: json['active'] == true,
      ownDevice: json['own_device'] == true,
      roomType: json['room_type'] as String?,
    );
  }
}

/// Maç içi AFK kütle eritme / yutulma ve sonuç ekranı çıkış kancaları.
class MatchIdleHooks {
  const MatchIdleHooks({
    required this.massProvider,
    required this.onMassDrain,
    required this.onAfkEliminated,
    required this.isResultScreen,
    required this.onResultIdleLeave,
  });

  final double Function() massProvider;
  final void Function(double amount) onMassDrain;
  final Future<void> Function() onAfkEliminated;

  /// Zafer veya oda kapanışı sonucu ekranı — kütle erimesi yok, lobiye dönüş.
  final bool Function() isResultScreen;

  /// Sonuç ekranında idle süresi dolunca (oturum kapatmadan) lobiye dön.
  final Future<void> Function() onResultIdleLeave;
}

/// Giriş yapmış oyuncunun aktif oturumu.
///
/// Lobi / maç dışı: hareketsizlik → uyarı geri sayımı → oturum kapanır.
/// Maç (oynanırken): hareketsizlik → uyarı + kütle erimesi → yutulma + oturum kapanır.
/// Maç sonucu (zafer / oda kapandı): 10 sn idle → 10 sn lobiye dönüş geri sayımı.
/// Yönetici panelindeyken AFK askıya alınır; lobi/maçta admin de oyuncu gibidir.
class PlayerSessionService extends ChangeNotifier {
  PlayerSessionService._();
  static final PlayerSessionService instance = PlayerSessionService._();

  static const _heartbeatInterval = Duration(seconds: 20);
  static const _idleTickInterval = Duration(seconds: 1);

  /// Sonuç ekranı: uyarı sonrası lobiye dönüş geri sayımı.
  static const resultExitCountdown = Duration(seconds: 10);

  Timer? _heartbeatTimer;
  Timer? _idleTickTimer;
  bool _claimed = false;
  bool _starting = false;
  bool _expiring = false;
  bool _inMatch = false;
  /// Admin paneli açıkken true — AFK tick/expire çalışmaz.
  bool _idleSuppressed = false;
  /// Reklam vb. kısa süreli pause (oturumu kapatmaz).
  int _matchIdlePauseDepth = 0;

  DateTime _lastActivityAt = DateTime.now();
  DateTime? _warningDeadline;
  bool _matchAfkActive = false;
  DateTime? _matchWarningDeadline;
  bool _matchDrainActive = false;
  double _matchDrainAccumulator = 0;
  bool _matchResultExitActive = false;
  DateTime? _matchResultExitDeadline;

  MatchIdleHooks? _matchHooks;

  /// Lobi uyarısı aktifken kalan saniye. Yoksa null.
  int? get warningSecondsRemaining {
    if (_inMatch || _matchAfkActive || _matchResultExitActive) return null;
    final deadline = _warningDeadline;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now()).inSeconds;
    final maxSec =
        AppIdleConfigService.instance.config.lobbyWarningCountdownSeconds;
    return left.clamp(0, maxSec);
  }

  /// Maç AFK: erime öncesi geri sayım saniyesi. Erime başladıysa null.
  int? get matchWarningSecondsRemaining {
    if (!_matchAfkActive || _matchDrainActive || _matchResultExitActive) {
      return null;
    }
    final deadline = _matchWarningDeadline;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now()).inSeconds;
    final maxSec =
        AppIdleConfigService.instance.config.matchWarningCountdownSeconds;
    return left.clamp(0, maxSec);
  }

  /// Sonuç ekranı: lobiye dönüş geri sayımı.
  int? get matchResultExitSecondsRemaining {
    if (!_matchResultExitActive) return null;
    final deadline = _matchResultExitDeadline;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now()).inSeconds;
    return left.clamp(0, resultExitCountdown.inSeconds);
  }

  bool get isWarningActive =>
      (!_inMatch && _warningDeadline != null) ||
      _matchAfkActive ||
      _matchResultExitActive;

  bool get isMatchAfkActive => _matchAfkActive;

  bool get isMatchAfkDraining => _matchDrainActive;

  bool get isMatchResultExitActive => _matchResultExitActive;

  bool get isInMatch => _inMatch;

  bool get hasClaimedSession => _claimed;

  SupabaseClient get _client => AuthService.instance.client;

  void attachMatchIdleHooks(MatchIdleHooks hooks) {
    _matchHooks = hooks;
    // Maç gerçekten hazır olunca sayaç sıfırlanır (wormhole / yükleme AFK sayılmaz).
    _clearMatchAfk(notify: false);
    _clearMatchResultExit(notify: false);
    _forceNoteActivity();
  }

  void detachMatchIdleHooks() {
    _matchHooks = null;
    _clearMatchAfk(notify: false);
    _clearMatchResultExit(notify: false);
  }

  void _forceNoteActivity() {
    _lastActivityAt = DateTime.now();
    _warningDeadline = null;
    _matchAfkActive = false;
    _matchWarningDeadline = null;
    _matchDrainActive = false;
    _matchDrainAccumulator = 0;
    _matchResultExitActive = false;
    _matchResultExitDeadline = null;
  }

  /// Yönetici paneli açıkken AFK'yi durdurur; kapanınca yeniden başlar.
  void setIdleSuppressed(bool suppressed) {
    if (_idleSuppressed == suppressed) return;
    _idleSuppressed = suppressed;
    if (suppressed) {
      _stopIdleWatch();
      _clearWarning(notify: false);
      _clearMatchAfk(notify: false);
      _clearMatchResultExit(notify: false);
      notifyListeners();
      return;
    }
    if (_claimed) {
      _forceNoteActivity();
      _startIdleWatch();
      notifyListeners();
    }
  }

  /// Rewarded reklam gibi kısa akışlarda maç idle sayacını durdurur.
  void setMatchIdlePaused(bool paused) {
    if (paused) {
      _matchIdlePauseDepth++;
      return;
    }
    if (_matchIdlePauseDepth > 0) {
      _matchIdlePauseDepth--;
    }
    if (_matchIdlePauseDepth == 0) {
      _forceNoteActivity();
      notifyListeners();
    }
  }

  void _applyIdleWatchForCurrentUser() {
    if (_idleSuppressed) {
      _stopIdleWatch();
      _clearWarning(notify: false);
      _clearMatchAfk(notify: false);
      _clearMatchResultExit(notify: false);
      return;
    }
    _forceNoteActivity();
    _startIdleWatch();
  }

  Future<PlayerSessionStatus> checkStatus() async {
    final deviceId = await DeviceIdService.instance.getDeviceId();
    final response = await _client.rpc(
      'check_player_session',
      params: {'p_device_id': deviceId},
    );

    if (response == null) {
      return const PlayerSessionStatus(active: false, ownDevice: false);
    }

    return PlayerSessionStatus.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  /// Oturum açıldıktan hemen sonra JWT henüz RPC'ye yansımamış olabilir — kısa retry.
  Future<PlayerSessionStatus> checkStatusAfterAuth({
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 150 * attempt));
      }
      try {
        return await checkStatus();
      } on PostgrestException catch (e) {
        lastError = e;
        if (!_isTransientAuthError(e) || attempt == maxAttempts - 1) {
          rethrow;
        }
      }
    }
    throw lastError ?? StateError('checkStatusAfterAuth failed');
  }

  bool _isTransientAuthError(PostgrestException error) {
    return error.message.toLowerCase().contains('not authenticated');
  }

  /// Uygulama girişi sonrası oturumu açar (lobi / admin / maç ortak).
  Future<void> ensureAppSession() async {
    if (_starting) return;
    if (!AuthService.instance.isSignedIn) return;

    // Zaten claim'liyse eski AFK deadline ile hemen atılmayı önle.
    if (_claimed) {
      _inMatch = _matchHooks != null;
      _applyIdleWatchForCurrentUser();
      _startHeartbeat();
      notifyListeners();
      return;
    }

    _starting = true;
    try {
      final status = await checkStatusAfterAuth();
      if (status.blockedOnOtherDevice) {
        await AuthService.instance.signOut();
        return;
      }

      await _claim(roomType: null);
      _inMatch = false;
      _startHeartbeat();
      _applyIdleWatchForCurrentUser();
      notifyListeners();
    } on PlayerAlreadyActiveException {
      await AuthService.instance.signOut();
    } catch (e, stackTrace) {
      debugPrint('ensureAppSession failed: $e\n$stackTrace');
    } finally {
      _starting = false;
    }
  }

  Future<void> setInGame(RoomType roomType) async {
    await _claim(roomType: roomType);
    if (!_claimed) return;
    // Maç AFK sayacı yalnızca GameScreen kancası bağlanınca işler.
    _inMatch = true;
    _clearWarning(notify: false);
    _clearMatchAfk(notify: false);
    _clearMatchResultExit(notify: false);
    _forceNoteActivity();
    _startHeartbeat();
    _applyIdleWatchForCurrentUser();
    notifyListeners();
  }

  Future<void> setInLobby() async {
    if (!_claimed) return;
    _inMatch = false;
    _matchHooks = null;
    _clearMatchAfk(notify: false);
    _clearMatchResultExit(notify: false);
    _clearWarning(notify: false);
    await _claim(roomType: null);
    _forceNoteActivity();
    notifyListeners();
  }

  Future<void> _claim({RoomType? roomType}) async {
    final deviceId = await DeviceIdService.instance.getDeviceId();
    try {
      await _client.rpc(
        'claim_player_session',
        params: {
          'p_device_id': deviceId,
          'p_room_type': roomType?.name,
        },
      );
      _claimed = true;
    } on PostgrestException catch (e) {
      if (_isAlreadyActiveError(e)) {
        throw const PlayerAlreadyActiveException();
      }
      rethrow;
    }
  }

  /// Geriye dönük: maça girerken oda tipiyle claim.
  Future<void> claim(RoomType roomType) => setInGame(roomType);

  Future<void> release() async {
    _stopHeartbeat();
    _stopIdleWatch();
    _clearWarning(notify: false);
    _clearMatchAfk(notify: false);
    _clearMatchResultExit(notify: false);
    _inMatch = false;
    _matchHooks = null;
    _matchIdlePauseDepth = 0;
    _forceNoteActivity();

    if (!_claimed) {
      notifyListeners();
      return;
    }

    final deviceId = await DeviceIdService.instance.getDeviceId();
    try {
      await _client.rpc(
        'release_player_session',
        params: {'p_device_id': deviceId},
      );
    } on PostgrestException catch (e) {
      debugPrint('release_player_session: ${e.message}');
    } finally {
      _claimed = false;
      notifyListeners();
    }
  }

  /// Kullanıcı etkileşimi — boşta kalma süresini sıfırlar.
  void noteActivity() {
    if (!_claimed || _idleSuppressed) return;

    final hadWarning = _warningDeadline != null ||
        _matchAfkActive ||
        _matchResultExitActive;
    _forceNoteActivity();
    if (hadWarning) notifyListeners();
  }

  void startHeartbeat() => _startHeartbeat();

  void stopHeartbeat() => _stopHeartbeat();

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(_sendHeartbeat()),
    );
    unawaited(_sendHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _startIdleWatch() {
    if (_idleSuppressed) {
      _stopIdleWatch();
      _clearWarning(notify: false);
      _clearMatchAfk(notify: false);
      _clearMatchResultExit(notify: false);
      return;
    }
    _idleTickTimer?.cancel();
    _idleTickTimer = Timer.periodic(_idleTickInterval, (_) => _onIdleTick());
  }

  void _stopIdleWatch() {
    _idleTickTimer?.cancel();
    _idleTickTimer = null;
  }

  void _onIdleTick() {
    if (!_claimed || _expiring || _idleSuppressed) return;

    final config = AppIdleConfigService.instance.config;
    final now = DateTime.now();

    // Maç yüklenirken (wormhole) AFK işleme — kanca yoksa sayaç da işlemesin.
    if (_inMatch) {
      if (_matchHooks == null) return;
      if (_matchIdlePauseDepth > 0) return;
      _onMatchIdleTick(now, config.matchIdleBeforeWarning);
      return;
    }

    if (_warningDeadline != null) {
      final left = _warningDeadline!.difference(now).inSeconds;
      if (left <= 0) {
        unawaited(_expireDueToIdle());
        return;
      }
      notifyListeners();
      return;
    }

    final idleFor = now.difference(_lastActivityAt);
    if (idleFor >= config.lobbyIdleBeforeWarning) {
      _warningDeadline = now.add(config.lobbyWarningCountdown);
      notifyListeners();
    }
  }

  void _onMatchIdleTick(DateTime now, Duration idleBeforeWarning) {
    final hooks = _matchHooks;
    if (hooks == null) return;

    // Zafer / oda kapandı: kütle erimesi yok — lobiye dönüş geri sayımı.
    if (hooks.isResultScreen()) {
      if (_matchAfkActive || _matchDrainActive) {
        _clearMatchAfk(notify: false);
      }
      _onMatchResultIdleTick(now, idleBeforeWarning);
      return;
    }

    if (_matchResultExitActive) {
      _clearMatchResultExit(notify: false);
    }

    if (!_matchAfkActive) {
      final idleFor = now.difference(_lastActivityAt);
      if (idleFor < idleBeforeWarning) return;
      // 10 sn idle → kısa geri sayımlı uyarı, sonra kütle erimesi.
      _matchAfkActive = true;
      _matchDrainActive = false;
      _matchDrainAccumulator = 0;
      _matchWarningDeadline = now.add(
        AppIdleConfigService.instance.config.matchWarningCountdown,
      );
      notifyListeners();
      return;
    }

    // Uyarı geri sayımı bitene kadar kütle düşmez.
    if (!_matchDrainActive) {
      final deadline = _matchWarningDeadline;
      if (deadline != null) {
        final left = deadline.difference(now).inSeconds;
        if (left > 0) {
          notifyListeners();
          return;
        }
      }
      _matchWarningDeadline = null;
      _matchDrainActive = true;
      notifyListeners();
    }

    final config = AppIdleConfigService.instance.config;
    final mass = hooks.massProvider();
    final threshold = config.matchKickMassThreshold.toDouble();

    // Uyarı bitti; kütle zaten eşikteyse hemen yutulmuş say.
    if (mass <= threshold) {
      unawaited(_expireDueToMatchAfk());
      return;
    }

    final drain = config.matchMassDrainPerSecond.toDouble();
    _matchDrainAccumulator += drain;
    final steps = _matchDrainAccumulator.floor();
    if (steps > 0) {
      _matchDrainAccumulator -= steps;
      hooks.onMassDrain(steps.toDouble());
    }

    if (hooks.massProvider() <= threshold) {
      unawaited(_expireDueToMatchAfk());
      return;
    }
    notifyListeners();
  }

  void _onMatchResultIdleTick(DateTime now, Duration idleBeforeWarning) {
    if (!_matchResultExitActive) {
      final idleFor = now.difference(_lastActivityAt);
      if (idleFor < idleBeforeWarning) return;
      _matchResultExitActive = true;
      _matchResultExitDeadline = now.add(resultExitCountdown);
      notifyListeners();
      return;
    }

    final deadline = _matchResultExitDeadline;
    if (deadline == null) return;
    final left = deadline.difference(now).inSeconds;
    if (left <= 0) {
      unawaited(_leaveDueToResultIdle());
      return;
    }
    notifyListeners();
  }

  void _clearWarning({required bool notify}) {
    if (_warningDeadline == null) return;
    _warningDeadline = null;
    if (notify) notifyListeners();
  }

  void _clearMatchAfk({required bool notify}) {
    if (!_matchAfkActive &&
        _matchDrainAccumulator == 0 &&
        _matchWarningDeadline == null &&
        !_matchDrainActive) {
      return;
    }
    _matchAfkActive = false;
    _matchWarningDeadline = null;
    _matchDrainActive = false;
    _matchDrainAccumulator = 0;
    if (notify) notifyListeners();
  }

  void _clearMatchResultExit({required bool notify}) {
    if (!_matchResultExitActive && _matchResultExitDeadline == null) return;
    _matchResultExitActive = false;
    _matchResultExitDeadline = null;
    if (notify) notifyListeners();
  }

  /// Sonuç ekranı idle: oturumu kapatmadan lobiye dön.
  Future<void> _leaveDueToResultIdle() async {
    if (_expiring || _idleSuppressed) return;
    _expiring = true;
    _clearMatchResultExit(notify: true);

    try {
      final hooks = _matchHooks;
      if (hooks != null) {
        try {
          await hooks.onResultIdleLeave();
        } catch (e, stackTrace) {
          debugPrint('match result idle leave: $e\n$stackTrace');
        }
      }
    } finally {
      _expiring = false;
    }
  }

  Future<void> _expireDueToMatchAfk() async {
    if (_expiring || _idleSuppressed) return;
    _expiring = true;
    _clearMatchAfk(notify: true);
    _clearMatchResultExit(notify: false);

    try {
      final hooks = _matchHooks;
      if (hooks != null) {
        try {
          await hooks.onAfkEliminated();
        } catch (e, stackTrace) {
          debugPrint('match AFK eliminate: $e\n$stackTrace');
        }
      }
      await release();
      await AuthService.instance.signOut();
      WidgetsBinding.instance.addPostFrameCallback((_) => popAppToRoot());
    } catch (e, stackTrace) {
      debugPrint('match AFK expire failed: $e\n$stackTrace');
      WidgetsBinding.instance.addPostFrameCallback((_) => popAppToRoot());
    } finally {
      _expiring = false;
    }
  }

  Future<void> _expireDueToIdle() async {
    if (_expiring || _idleSuppressed) return;
    _expiring = true;
    _clearWarning(notify: true);
    _clearMatchAfk(notify: false);
    _clearMatchResultExit(notify: false);

    try {
      try {
        await RoomMatchmakingService.instance.leaveActiveRoom();
      } catch (e, stackTrace) {
        debugPrint('idle leaveActiveRoom: $e\n$stackTrace');
      }
      await release();
      await AuthService.instance.signOut();
      // AuthGate LoginScreen'e geçtikten sonra maç/diyalog stack'ini temizle.
      WidgetsBinding.instance.addPostFrameCallback((_) => popAppToRoot());
    } catch (e, stackTrace) {
      debugPrint('idle expire failed: $e\n$stackTrace');
      WidgetsBinding.instance.addPostFrameCallback((_) => popAppToRoot());
    } finally {
      _expiring = false;
    }
  }

  Future<void> _sendHeartbeat() async {
    if (!_claimed) return;

    final deviceId = await DeviceIdService.instance.getDeviceId();
    try {
      await _client.rpc(
        'heartbeat_player_session',
        params: {'p_device_id': deviceId},
      );
    } on PostgrestException catch (e) {
      debugPrint('heartbeat_player_session: ${e.message}');
      if (e.message.toLowerCase().contains('session_not_found')) {
        _claimed = false;
        _stopHeartbeat();
        _stopIdleWatch();
        _clearWarning(notify: true);
        _clearMatchAfk(notify: true);
        _clearMatchResultExit(notify: true);
      }
    }
  }

  bool _isAlreadyActiveError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('player_already_active');
  }
}
