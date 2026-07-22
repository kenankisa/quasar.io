import '../config/app_config.dart';

/// Avatar URL allowlist — Storage (kullanıcı klasörü) veya bilinen OAuth host'ları.
class AvatarUrl {
  AvatarUrl._();

  static final _googleHost = RegExp(
    r'^https://lh[0-9]\.googleusercontent\.com/',
    caseSensitive: false,
  );

  static final _storageObject = RegExp(
    r'^([0-9a-fA-F-]{36})/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$',
  );

  static bool isAllowed(String? url, {String? userId}) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    // Google Sign-In profil görselleri (ilk kayıt).
    if (_googleHost.hasMatch(trimmed)) return true;

    final base = AppConfig.supabaseUrl.trim();
    if (base.isEmpty) return false;

    final prefix = '$base/storage/v1/object/public/avatars/';
    if (!trimmed.startsWith(prefix)) return false;

    final rest = trimmed.substring(prefix.length);
    final match = _storageObject.firstMatch(rest);
    if (match == null) return false;

    if (userId != null && userId.isNotEmpty) {
      return match.group(1) == userId;
    }
    return true;
  }

  /// Yükleme için güvenli URL; değilse null.
  static String? sanitize(String? url, {String? userId}) {
    return isAllowed(url, userId: userId) ? url!.trim() : null;
  }
}
