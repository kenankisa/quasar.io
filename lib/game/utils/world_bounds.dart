import 'dart:math' as math;

import 'package:flame/components.dart';

/// Keeps black-hole centers inside the playable arena.
abstract final class WorldBounds {
  /// Clamps [position] so the hole edge can reach the map boundary (0 … worldSize).
  static void clampHoleCenter(
    Vector2 position, {
    required double radius,
    required double worldSize,
  }) {
    final inset = math.min(radius, worldSize / 2);
    position.x = position.x.clamp(inset, worldSize - inset);
    position.y = position.y.clamp(inset, worldSize - inset);
  }
}
