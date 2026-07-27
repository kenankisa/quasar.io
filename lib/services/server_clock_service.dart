import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Cihaz saati ile Supabase sunucu saati arasındaki offset.
/// Canlı duyuru süresi ve lobi saati buna bağlıdır.
class ServerClockService extends ChangeNotifier {
  ServerClockService._();
  static final ServerClockService instance = ServerClockService._();

  static const _resyncInterval = Duration(minutes: 2);
  static const _tickInterval = Duration(seconds: 1);

  /// serverUtc ≈ DateTime.now().toUtc() + offset
  Duration _offset = Duration.zero;
  bool _synced = false;
  int _refCount = 0;
  Timer? _resyncTimer;
  Timer? _tickTimer;
  bool _syncInFlight = false;

  bool get isSynced => _synced;

  /// Sunucu UTC anı (offset uygulanmış).
  DateTime get nowUtc => DateTime.now().toUtc().add(_offset);

  /// Sunucu anının yerel dilime çevrilmiş hali (gösterim için).
  DateTime get nowLocal => nowUtc.toLocal();

  /// HH:mm:ss — lobi üst bar (geniş).
  String get displayHms {
    final t = nowLocal;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  /// HH:mm — dar ekran.
  String get displayHm {
    final t = nowLocal;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

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

  Future<void> sync() => _syncOnce();

  Future<void> _start() async {
    await _syncOnce();
    _resyncTimer?.cancel();
    _resyncTimer = Timer.periodic(_resyncInterval, (_) => unawaited(_syncOnce()));
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_tickInterval, (_) {
      if (_refCount > 0) notifyListeners();
    });
  }

  void _stop() {
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<void> _syncOnce() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final t0 = DateTime.now().toUtc();
      final response =
          await AuthService.instance.client.rpc('get_server_now');
      final t1 = DateTime.now().toUtc();
      final server = _parseServerTime(response);
      if (server == null) return;

      // RTT ortası — tek yön gecikmeyi yaklaşık dengeler.
      final mid = t0.add(
        Duration(microseconds: t1.difference(t0).inMicroseconds ~/ 2),
      );
      _offset = server.difference(mid);
      _synced = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('ServerClockService sync failed: $e\n$st');
      // RPC yoksa cihaz saatiyle devam; skew düzelmez ama UI kırılmaz.
      if (!_synced) {
        _offset = Duration.zero;
        notifyListeners();
      }
    } finally {
      _syncInFlight = false;
    }
  }

  static DateTime? _parseServerTime(dynamic raw) {
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }
}
