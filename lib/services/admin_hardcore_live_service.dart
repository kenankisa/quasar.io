import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/models/admin_hardcore_live.dart';
import 'admin_access.dart';
import 'auth_service.dart';

/// Live Hardcore arena / queue / diamond flow for the admin panel.
class AdminHardcoreLiveService extends ChangeNotifier {
  AdminHardcoreLiveService._();
  static final AdminHardcoreLiveService instance = AdminHardcoreLiveService._();

  static const _pollInterval = Duration(seconds: 2);
  static const _realtimeDebounce = Duration(milliseconds: 800);

  AdminHardcoreLiveSnapshot _snapshot = AdminHardcoreLiveSnapshot.empty();
  AdminHardcoreLiveSnapshot get snapshot => _snapshot;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Timer? _pollTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _roomsChannel;
  RealtimeChannel? _queueChannel;
  int _refCount = 0;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;

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
    _subscribe();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refresh()));
  }

  void _stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final client = AuthService.instance.client;
    if (_roomsChannel != null) {
      client.removeChannel(_roomsChannel!);
      _roomsChannel = null;
    }
    if (_queueChannel != null) {
      client.removeChannel(_queueChannel!);
      _queueChannel = null;
    }
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_realtimeDebounce, () {
      unawaited(_refresh());
    });
  }

  void _subscribe() {
    final client = AuthService.instance.client;
    _roomsChannel?.unsubscribe();
    _roomsChannel = client
        .channel('admin-hardcore-rooms')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_room_instances',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_room_members',
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();

    _queueChannel?.unsubscribe();
    _queueChannel = client
        .channel('admin-hardcore-queue')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hardcore_queue',
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;

    final firstLoad = _snapshot.roomId == null &&
        _snapshot.fetchedAt.millisecondsSinceEpoch == 0;
    if (firstLoad) {
      _loading = true;
      notifyListeners();
    }

    try {
      // Free ghost seats so softcap camping cannot permanently fill the 20-cap.
      try {
        await AuthService.instance.client
            .rpc('admin_hardcore_live_purge_inactive');
      } catch (_) {}
      final response =
          await AuthService.instance.client.rpc('get_admin_hardcore_live_ops');
      final map = Map<String, dynamic>.from(response as Map);
      _snapshot = AdminHardcoreLiveSnapshot.fromJson(map);
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('AdminHardcoreLiveService refresh failed: $e\n$stackTrace');
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
}
