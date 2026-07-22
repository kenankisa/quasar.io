/// Formats elapsed match seconds as `m:ss` (e.g. `2:05`, `0:42`).
String formatMatchTime(double seconds) {
  final clamped = seconds.clamp(0, 99 * 60 + 59);
  final totalSec = clamped.floor();
  final mins = totalSec ~/ 60;
  final secs = totalSec % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}
