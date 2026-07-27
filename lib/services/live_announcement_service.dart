import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/models/live_announcement.dart';
import 'admin_access.dart';
import 'auth_service.dart';
import 'server_clock_service.dart';

/// Global canlı duyurular — Realtime + sunucu saatli poll (late-join).
/// Aynı anda en fazla [maxVisible] balon; fazlası sıraya alınır (ekran dolmasın).
class LiveAnnouncementService extends ChangeNotifier {
  LiveAnnouncementService._();
  static final LiveAnnouncementService instance = LiveAnnouncementService._();

  static const maxBodyLength = 160;
  static const adminCooldown = Duration(seconds: 30);
  static const _pollInterval = Duration(seconds: 2);
  /// Üst üste görünen maksimum balon.
  static const maxVisible = 2;
  /// Bekleyen (görünmeyen) kuyruk tavanı.
  static const maxPending = 8;

  final List<LiveAnnouncement> _active = [];
  final List<LiveAnnouncement> _pending = [];
  final Map<String, Timer> _expiryTimers = {};
  final Set<String> _seenIds = {};

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  bool _attached = false;
  bool _posting = false;
  bool _fetchInFlight = false;
  String? _error;
  DateTime? _lastPostAt;

  /// Süresi dolmamış, şu an ekranda olan duyurular (en fazla [maxVisible]).
  List<LiveAnnouncement> get visible {
    final list = _active.where((a) => !a.isExpired).toList(growable: false);
    return UnmodifiableListView(list);
  }

  /// Geriye dönük: ilk görünür duyuru.
  LiveAnnouncement? get current {
    for (final a in _active) {
      if (!a.isExpired) return a;
    }
    return null;
  }

  bool get posting => _posting;
  String? get error => _error;
  bool get hasVisible => visible.isNotEmpty;

  int get _visibleCount => _active.where((a) => !a.isExpired).length;

  Duration? get cooldownRemaining {
    final last = _lastPostAt;
    if (last == null) return null;
    final left =
        adminCooldown - ServerClockService.instance.nowUtc.difference(last);
    return left.isNegative ? null : left;
  }

  Future<void> attach() async {
    if (_attached) return;
    if (AuthService.instance.currentUser == null) return;
    _attached = true;
    // Önce sunucu saatini kilitle — aksi halde skew ile duyuru “expired” görünür.
    await ServerClockService.instance.sync();
    await _fetchActive();
    _subscribe();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_attached) return;
      unawaited(_fetchActive());
    });
  }

  Future<void> detach() async {
    _attached = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final t in _expiryTimers.values) {
      t.cancel();
    }
    _expiryTimers.clear();
    _active.clear();
    _pending.clear();
    _seenIds.clear();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await AuthService.instance.client.removeChannel(channel);
      } catch (e, st) {
        debugPrint('LiveAnnouncementService detach: $e\n$st');
      }
    }
    notifyListeners();
  }

  void dismissCurrent() {
    final first = current;
    if (first == null) return;
    _removeById(first.id);
  }

  /// Admin: sunucuya canlı duyuru yazar (cooldown sunucu + istemci).
  Future<bool> post(String body) async {
    if (!AdminAccess.isCurrentUserAdmin || _posting) return false;
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      _error = 'live_announce_empty';
      notifyListeners();
      return false;
    }
    final cooldown = cooldownRemaining;
    if (cooldown != null) {
      _error = 'live_announce_cooldown';
      notifyListeners();
      return false;
    }

    _posting = true;
    _error = null;
    notifyListeners();
    try {
      final response = await AuthService.instance.client.rpc(
        'admin_post_live_announcement',
        params: {'p_body': trimmed},
      );
      _lastPostAt = ServerClockService.instance.nowUtc;
      final map = _asMap(response);
      if (map.isNotEmpty) {
        final ann = LiveAnnouncement.fromJson(map);
        _enqueue(ann);
      }
      // Diğer istemciler Realtime/poll ile alır; yine de taze çek.
      unawaited(_fetchActive());
      return true;
    } catch (e, stackTrace) {
      debugPrint('LiveAnnouncementService post: $e\n$stackTrace');
      final msg = e.toString();
      if (msg.contains('live_announce_cooldown')) {
        _error = 'live_announce_cooldown';
        _lastPostAt = ServerClockService.instance.nowUtc;
      } else if (msg.contains('empty_body')) {
        _error = 'live_announce_empty';
      } else {
        _error = 'live_announce_err';
      }
      return false;
    } finally {
      _posting = false;
      notifyListeners();
    }
  }

  Future<void> _fetchActive() async {
    if (_fetchInFlight || !_attached) return;
    _fetchInFlight = true;
    try {
      final cutoff = ServerClockService.instance.nowUtc.toIso8601String();
      final rows = await AuthService.instance.client
          .from('app_live_announcements')
          .select('id, body, created_at, expires_at')
          .gt('expires_at', cutoff)
          .order('created_at', ascending: true)
          .limit(12);
      for (final row in rows) {
        _enqueue(LiveAnnouncement.fromJson(Map<String, dynamic>.from(row)));
      }
      // Süresi dolanları temizle (sunucu saatine göre).
      final expiredIds =
          _active.where((a) => a.isExpired).map((a) => a.id).toList();
      for (final id in expiredIds) {
        _removeById(id);
      }
      _pending.removeWhere((a) => a.isExpired);
      _promotePending();
    } catch (e, stackTrace) {
      debugPrint('LiveAnnouncementService fetchActive: $e\n$stackTrace');
    } finally {
      _fetchInFlight = false;
    }
  }

  void _subscribe() {
    if (_channel != null) return;
    final channel = AuthService.instance.client
        .channel('app_live_announcements_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_live_announcements',
          callback: (payload) {
            final map = payload.newRecord;
            if (map.isEmpty) return;
            _enqueue(LiveAnnouncement.fromJson(Map<String, dynamic>.from(map)));
          },
        );
    _channel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(_fetchActive());
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('LiveAnnouncementService realtime: $status $error');
        // Poll yedek olarak çalışmaya devam eder.
      }
    });
  }

  void _enqueue(LiveAnnouncement ann) {
    if (ann.id.isEmpty || ann.body.isEmpty) return;
    if (ann.isExpired) return;
    if (_seenIds.contains(ann.id)) return;
    _seenIds.add(ann.id);
    if (_seenIds.length > 80) {
      final drop = _seenIds.take(40).toList();
      _seenIds.removeAll(drop);
    }
    if (_active.any((e) => e.id == ann.id)) return;
    if (_pending.any((e) => e.id == ann.id)) return;

    if (_visibleCount < maxVisible) {
      _addActive(ann);
    } else {
      _pending.add(ann);
      _trimPending();
    }
    notifyListeners();
  }

  void _addActive(LiveAnnouncement ann) {
    _active.add(ann);
    final remaining = ann.remaining;
    if (remaining > Duration.zero) {
      _expiryTimers[ann.id]?.cancel();
      _expiryTimers[ann.id] = Timer(remaining, () => _removeById(ann.id));
    }
  }

  void _trimPending() {
    // Hardcore fetih selinde eski HC'leri at; admin mesajlarını koru.
    while (_pending.length > maxPending) {
      final hcIdx = _pending.indexWhere((a) => a.isHardcoreWin);
      if (hcIdx >= 0) {
        _pending.removeAt(hcIdx);
      } else {
        _pending.removeAt(0);
      }
    }
  }

  void _promotePending() {
    var changed = false;
    while (_visibleCount < maxVisible && _pending.isNotEmpty) {
      final next = _pending.removeAt(0);
      if (next.isExpired) continue;
      _addActive(next);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _removeById(String id) {
    _expiryTimers.remove(id)?.cancel();
    final beforeActive = _active.length;
    final beforePending = _pending.length;
    _active.removeWhere((a) => a.id == id);
    _pending.removeWhere((a) => a.id == id);
    if (_active.length != beforeActive || _pending.length != beforePending) {
      _promotePending();
      notifyListeners();
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
