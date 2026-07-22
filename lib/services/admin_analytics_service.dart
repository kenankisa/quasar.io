import 'package:flutter/foundation.dart';

import '../game/models/admin_analytics.dart';
import 'admin_access.dart';
import 'auth_service.dart';

/// Yönetim paneli geçmiş istatistikleri (RPC: get_admin_analytics).
class AdminAnalyticsService extends ChangeNotifier {
  AdminAnalyticsService._();
  static final AdminAnalyticsService instance = AdminAnalyticsService._();

  AdminAnalyticsWindow _window = AdminAnalyticsWindow.day1;
  AdminAnalyticsWindow get window => _window;

  AdminAnalyticsSnapshot _snapshot =
      AdminAnalyticsSnapshot.empty(AdminAnalyticsWindow.day1);
  AdminAnalyticsSnapshot get snapshot => _snapshot;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool _refreshInFlight = false;

  Future<void> setWindow(AdminAnalyticsWindow window) async {
    if (_window == window) return;
    _window = window;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    _loading = true;
    notifyListeners();

    try {
      final response = await AuthService.instance.client.rpc(
        'get_admin_analytics',
        params: {'p_window': _window.rpcValue},
      );

      if (response is Map) {
        _snapshot = AdminAnalyticsSnapshot.fromJson(
          Map<String, dynamic>.from(response),
          window: _window,
        );
      } else {
        _snapshot = AdminAnalyticsSnapshot.empty(_window);
      }
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('AdminAnalyticsService refresh failed: $e\n$stackTrace');
      _error = 'error_generic';
    } finally {
      _loading = false;
      _refreshInFlight = false;
      notifyListeners();
    }
  }
}
