import 'package:flame/components.dart';

/// Shared contract for player and bot black holes in tactical systems.
abstract class BlackHolePartner {
  Vector2 get position;
  double get holeRadius;
  String get displayName;
  Vector2 get velocity;
  bool get isBoosting;
  bool get isEliminated;

  void growBy(double amount);
  void recordAbsorb();

  /// Brief invulnerability after joining a room (local player only).
  bool get isSpawnProtected => false;

  bool isImmuneToGravityFrom(double otherRadius) => isSpawnProtected;
}
