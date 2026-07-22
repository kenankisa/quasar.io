import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/models/live_announcement.dart';
import 'admin_access.dart';
import 'auth_service.dart';

/// Global canlı admin duyuruları — Realtime + late-join SELECT.
class LiveAnnouncementService extends ChangeNotifier {
  LiveAnnouncementService._();
  static final LiveAnnouncementService instance = LiveAnnouncementService._();

  static const maxBodyLength = 160;
  static const adminCooldown = Duration(seconds: 30);

  final Queue<LiveAnnouncement> _queue = Queue<LiveAnnouncement>();
  final Set<String> _seenIds = {};

  LiveAnnouncement? _current;
  Timer? _dismissTimer;
  RealtimeChannel? _channel;
  bool _attached = false;
  bool _posting = false;
  String? _error;
  DateTime? _lastPostAt;

  LiveAnnouncement? get current => _current;
  bool get posting => _posting;
  String? get error => _error;
  bool get hasVisible => _current != null && !_current!.isExpired;

  Duration? get cooldownRemaining {
    final last = _lastPostAt;
    if (last == null) return null;
    final left = adminCooldown - DateTime.now().difference(last);
    return left.isNegative ? null : left;
  }

  Future<void> attach() async {
    if (_attached) return;
    if (AuthService.instance.currentUser == null) return;
    _attached = true;
    await _fetchActive();
    _subscribe();
  }

  Future<void> detach() async {
    _attached = false;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _current = null;
    _queue.clear();
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
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _current = null;
    notifyListeners();
    _showNext();
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
      _lastPostAt = DateTime.now();
      final map = _asMap(response);
      if (map.isNotEmpty) {
        final ann = LiveAnnouncement.fromJson(map);
        _enqueue(ann);
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('LiveAnnouncementService post: $e\n$stackTrace');
      final msg = e.toString();
      if (msg.contains('live_announce_cooldown')) {
        _error = 'live_announce_cooldown';
        _lastPostAt = DateTime.now();
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
    try {
      final rows = await AuthService.instance.client
          .from('app_live_announcements')
          .select('id, body, created_at, expires_at')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: true)
          .limit(8);
      for (final row in rows) {
        _enqueue(LiveAnnouncement.fromJson(Map<String, dynamic>.from(row)));
      }
    } catch (e, stackTrace) {
      debugPrint('LiveAnnouncementService fetchActive: $e\n$stackTrace');
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
    channel.subscribe();
  }

  void _enqueue(LiveAnnouncement ann) {
    if (ann.id.isEmpty || ann.body.isEmpty) return;
    if (ann.isExpired) return;
    if (_seenIds.contains(ann.id)) return;
    _seenIds.add(ann.id);
    // Bellekte çok birikmesin.
    if (_seenIds.length > 40) {
      final drop = _seenIds.take(20).toList();
      _seenIds.removeAll(drop);
    }
    if (_current?.id == ann.id) return;
    if (_queue.any((e) => e.id == ann.id)) return;
    _queue.addLast(ann);
    if (_current == null) {
      _showNext();
    } else {
      notifyListeners();
    }
  }

  void _showNext() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    while (_queue.isNotEmpty && _queue.first.isExpired) {
      _queue.removeFirst();
    }
    if (_queue.isEmpty) {
      if (_current != null) {
        _current = null;
        notifyListeners();
      }
      return;
    }

    _current = _queue.removeFirst();
    final remaining = _current!.remaining;
    if (remaining <= Duration.zero) {
      _current = null;
      _showNext();
      return;
    }
    _dismissTimer = Timer(remaining, dismissCurrent);
    notifyListeners();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
