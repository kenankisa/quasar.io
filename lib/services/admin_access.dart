import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Sunucu tarafı admin claim (`app_metadata.role` / `admin_users`).
/// UI yalnızca [refreshAdminStatus] sonrası sunucu onayıyla açılır (L2).
class AdminAccess extends ChangeNotifier {
  AdminAccess._();
  static final AdminAccess instance = AdminAccess._();

  /// `true` = sunucu onayladı, `false` = değil, `null` = henüz sorulmadı.
  bool? _serverConfirmed;

  /// Panel / gizli giriş — yalnızca sunucu doğrulaması sonrası.
  static bool get isCurrentUserAdmin => instance._serverConfirmed == true;

  /// JWT'de role claim var mı? (hızlı ipucu; UI için yeterli değil)
  static bool get hasAdminRoleClaim =>
      _hasAdminRoleClaim(AuthService.instance.currentUser);

  static bool _hasAdminRoleClaim(User? user) {
    if (user == null) return false;
    final role = user.appMetadata['role'];
    return role is String && role.toLowerCase() == 'admin';
  }

  static bool _asBool(dynamic value) {
    if (value == true) return true;
    if (value == false || value == null) return false;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  /// Sunucudan `is_current_user_admin` doğrula; gerekirse oturumu yenile.
  ///
  /// [forceRefreshSession] true ise önce token yenilenir. Başarısız refresh
  /// oturumu silebileceği için yük testi gibi hassas yollarda kullanma.
  static Future<bool> refreshAdminStatus({
    bool forceRefreshSession = false,
  }) =>
      instance._refresh(forceRefreshSession: forceRefreshSession);

  Future<bool> _refresh({bool forceRefreshSession = false}) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _serverConfirmed = false;
      notifyListeners();
      return false;
    }

    final session = AuthService.instance.client.auth.currentSession;
    final shouldRefresh =
        forceRefreshSession || (session?.isExpired ?? false);

    if (shouldRefresh && session?.refreshToken != null) {
      try {
        await AuthService.instance.client.auth.refreshSession();
      } catch (e) {
        // GoTrue başarısız refresh'te oturumu silebilir; RPC hâlâ eski
        // access token ile çalışabilir. Burada admin durumunu düşürme.
        debugPrint('AdminAccess.refreshSession skipped: $e');
        if (AuthService.instance.currentUser == null) {
          _serverConfirmed = false;
          notifyListeners();
          return false;
        }
      }
    }

    try {
      final response =
          await AuthService.instance.client.rpc('is_current_user_admin');
      final isAdmin = _asBool(response);
      _serverConfirmed = isAdmin;

      // Claim eksikse bir kez daha dene — hata admin onayını bozmasın.
      if (isAdmin &&
          !_hasAdminRoleClaim(AuthService.instance.currentUser)) {
        try {
          await AuthService.instance.client.auth.refreshSession();
        } catch (e) {
          debugPrint('AdminAccess.claim refresh skipped: $e');
        }
      }

      notifyListeners();
      return isAdmin;
    } catch (e, stackTrace) {
      debugPrint('AdminAccess.refreshAdminStatus: $e\n$stackTrace');
      // RPC başarısızsa admin UI açma — sunucu onayı şart.
      _serverConfirmed = false;
      notifyListeners();
      return false;
    }
  }

  static void clearCache() {
    instance._serverConfirmed = null;
    instance.notifyListeners();
  }
}
