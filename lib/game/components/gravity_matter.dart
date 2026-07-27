import 'package:flame/components.dart';

/// Matter pulled toward black holes by [CosmicSpawnManager.applyGravityPull].
abstract interface class GravityMatter {
  bool get active;
  Vector2 get position;
  double get collisionRadius;
  Vector2 get velocity;
}
