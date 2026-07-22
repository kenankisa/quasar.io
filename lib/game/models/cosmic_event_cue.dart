import 'package:flame/components.dart';

/// One scheduled room-wide cosmic event (shared across all players).
enum CosmicEventKind { supernova, meteorShower }

class CosmicEventCue {
  const CosmicEventCue({
    required this.serial,
    required this.kind,
    required this.warnAt,
    required this.startAt,
    required this.endAt,
    required this.center,
    required this.regionRadius,
    required this.spawnSeed,
  });

  final int serial;
  final CosmicEventKind kind;

  /// Match-seconds when the warning banner begins.
  final double warnAt;

  /// Match-seconds when the event detonates / shower starts.
  final double startAt;

  /// Match-seconds when the event fully ends (supernova: = startAt).
  final double endAt;

  final Vector2 center;
  final double regionRadius;
  final int spawnSeed;

  bool isActiveAt(double elapsed) =>
      elapsed >= warnAt && elapsed < endAt + 0.05;

  bool isWarningAt(double elapsed) =>
      elapsed >= warnAt && elapsed < startAt;

  bool isRunningAt(double elapsed) =>
      elapsed >= startAt && elapsed < endAt;
}
