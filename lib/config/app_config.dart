import 'package:flutter/foundation.dart';

/// Supabase / Google / AdMob yapılandırması.
///
/// Hassas değerler kaynak kodda tutulmaz — build zamanında verilir:
/// `flutter run --dart-define-from-file=dart_defines.dev.json`
///
/// Şablon: [dart_defines.dev.json.example]
/// `dart_defines*.json` gitignore'dadır; gerçek anahtarları asla commit etmeyin.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Android için Google Cloud Console'daki Web Client ID.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Zorunlu tanımlar dolu mu? (main başlangıç kontrolü)
  static bool get hasRequiredConfig =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      googleWebClientId.isNotEmpty;

  /// Geçici test: yeni oturumlarda kullanılacak başlangıç elması.
  static const int devStartingDiamonds = 500;

  static const bool _devUnlockAllRoomsDefine = bool.fromEnvironment(
    'DEV_UNLOCK_ALL_ROOMS',
    defaultValue: false,
  );

  /// Lobby UI kilidi — yalnızca debug + dart-define ile.
  /// Release/profile'da asla açılmaz (sunucu join eşiği zaten zorunlu).
  static bool get devUnlockAllRooms =>
      kDebugMode && _devUnlockAllRoomsDefine;

  /// AdMob app IDs — native manifest/plist also need these for store builds.
  /// Android: dart_defines / ANDROID_ADMOB_APP_ID env (see android/app/build.gradle.kts).
  /// iOS: ios/Flutter/*.xcconfig ADMOB_APP_ID.
  static const String androidAdMobAppId = String.fromEnvironment(
    'ANDROID_ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713',
  );
  static const String iosAdMobAppId = String.fromEnvironment(
    'IOS_ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~1458002511',
  );

  /// AdMob test rewarded ad unit IDs (revive — reserved for later).
  static const String androidRewardedReviveAdUnitId = String.fromEnvironment(
    'ANDROID_REWARDED_REVIVE_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String iosRewardedReviveAdUnitId = String.fromEnvironment(
    'IOS_REWARDED_REVIVE_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  /// Rewarded 2× match reward. Defaults to the same test units as revive.
  static const String androidRewardedDoubleAdUnitId = String.fromEnvironment(
    'ANDROID_REWARDED_DOUBLE_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String iosRewardedDoubleAdUnitId = String.fromEnvironment(
    'IOS_REWARDED_DOUBLE_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  /// True when runtime still points at Google's sample AdMob IDs.
  static bool get isUsingTestAdMobIds =>
      androidAdMobAppId.contains('3940256099942544') ||
      iosAdMobAppId.contains('3940256099942544') ||
      androidRewardedDoubleAdUnitId.contains('3940256099942544') ||
      iosRewardedDoubleAdUnitId.contains('3940256099942544');

  /// Web OAuth redirect origin allowlist (exact match).
  /// Empty → fall back to [Uri.base.origin] only for localhost / 127.0.0.1.
  static const String oauthRedirectOrigin = String.fromEnvironment(
    'OAUTH_REDIRECT_ORIGIN',
  );

  /// Safe web OAuth redirect. Prefer exact [oauthRedirectOrigin] allowlist.
  static String? webOAuthRedirectTo(Uri pageUri) {
    final origin = pageUri.origin;
    final allowed = oauthRedirectOrigin.trim();
    if (allowed.isNotEmpty) {
      // Always use configured origin so a malicious page host cannot redirect.
      return allowed;
    }
    final host = pageUri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') {
      return origin;
    }
    // Production web builds should set OAUTH_REDIRECT_ORIGIN.
    return origin;
  }
}
