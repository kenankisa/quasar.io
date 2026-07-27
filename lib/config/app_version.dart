/// Uygulama sürüm bilgisi — pubspec.yaml ile senkron tutun.
class AppVersion {
  AppVersion._();

  static const String current = '2.3.0';
  static const int buildNumber = 13;

  static String get display => 'v$current';
}
