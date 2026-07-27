/// Uygulama sürüm bilgisi — pubspec.yaml ile senkron tutun.
class AppVersion {
  AppVersion._();

  static const String current = '2.4.0';
  static const int buildNumber = 14;

  static String get display => 'v$current';
}
