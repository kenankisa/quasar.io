/// Human-readable countdown for lobby cooldowns and lock messages.
String formatCooldownRemaining(Duration duration) {
  final totalSec = duration.inSeconds.clamp(0, 99 * 3600 + 59 * 60 + 59);
  final hours = totalSec ~/ 3600;
  final mins = (totalSec % 3600) ~/ 60;
  final secs = totalSec % 60;
  if (hours > 0) {
    return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  if (mins > 0) {
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
  return '${secs}s';
}

/// Formats elapsed seconds as `m:ss`, or `h:mm:ss` when ≥ 1 hour.
String formatMatchTime(double seconds) {
  final totalSec = seconds.clamp(0, 99 * 3600 + 59 * 60 + 59).floor();
  final hours = totalSec ~/ 3600;
  final mins = (totalSec % 3600) ~/ 60;
  final secs = totalSec % 60;
  if (hours > 0) {
    return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '$mins:${secs.toString().padLeft(2, '0')}';
}
