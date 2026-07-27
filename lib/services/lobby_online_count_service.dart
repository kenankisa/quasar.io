import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Lobi üst barındaki anlık online (giriş yapmış) oyuncu sayısı.
class LobbyOnlineCountService extends ChangeNotifier {
  LobbyOnlineCountService._();
  static final LobbyOnlineCountService instance = LobbyOnlineCountService._();

  static const _pollInterval = Duration(seconds: 12);

  int? _count;
  int _refCount = 0;
  Timer? _pollTimer;
  bool _refreshInFlight = false;

  /// null = henüz yüklenmedi.
  int? get count => _count;

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

  void pauseForBackground() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void resumeFromBackground() {
    if (_refCount <= 0 || _pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _start() async {
    await _refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  void _stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final response = await AuthService.instance.client
          .rpc('get_lobby_online_player_count');
      final next = response is num ? response.toInt() : null;
      if (next != null && next != _count) {
        _count = next;
        notifyListeners();
      } else if (_count == null && next != null) {
        _count = next;
        notifyListeners();
      } else if (_count == null) {
        _count = 0;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint('LobbyOnlineCountService refresh failed: $e\n$stackTrace');
      if (_count == null) {
        _count = 0;
        notifyListeners();
      }
    } finally {
      _refreshInFlight = false;
    }
  }
}
