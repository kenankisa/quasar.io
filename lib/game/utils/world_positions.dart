import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

import '../orbit_game.dart';
import 'viewport_cull.dart';

final _rng = math.Random();

Vector2 randomWorldPosition({
  required double worldSize,
  double margin = 40,
  Iterable<Vector2> avoid = const [],
  double minSeparation = 60,
}) {
  return randomWorldPositionWith(
    _rng,
    worldSize: worldSize,
    margin: margin,
    avoid: avoid,
    minSeparation: minSeparation,
  );
}

/// Seeded variant so every client in a room picks the same world point.
Vector2 randomWorldPositionWith(
  math.Random rng, {
  required double worldSize,
  double margin = 40,
  Iterable<Vector2> avoid = const [],
  double minSeparation = 60,
}) {
  for (var attempt = 0; attempt < 120; attempt++) {
    final position = Vector2(
      margin + rng.nextDouble() * (worldSize - margin * 2),
      margin + rng.nextDouble() * (worldSize - margin * 2),
    );

    var valid = true;
    for (final other in avoid) {
      if (position.distanceTo(other) < minSeparation) {
        valid = false;
        break;
      }
    }

    if (valid) return position;
  }

  return Vector2(
    margin + rng.nextDouble() * (worldSize - margin * 2),
    margin + rng.nextDouble() * (worldSize - margin * 2),
  );
}

/// Picks a position inside (or just beyond) the player's current view.
Vector2 randomViewportPosition({
  required OrbitGame game,
  double worldMargin = 40,
  double viewportPadding = 120,
  Iterable<Vector2> avoid = const [],
  double minSeparation = 60,
}) {
  final view = ViewportCull.visibleWorldRect(game);
  Rect spawnRect;
  if (view.width > 0 && view.height > 0) {
    spawnRect = view.inflate(viewportPadding);
  } else {
    final center = game.player.position;
    spawnRect = Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: 800,
      height: 800,
    );
  }

  final worldSize = game.worldSize;
  final left = spawnRect.left.clamp(worldMargin, worldSize - worldMargin);
  final right = spawnRect.right.clamp(worldMargin, worldSize - worldMargin);
  final top = spawnRect.top.clamp(worldMargin, worldSize - worldMargin);
  final bottom = spawnRect.bottom.clamp(worldMargin, worldSize - worldMargin);

  for (var attempt = 0; attempt < 80; attempt++) {
    final position = Vector2(
      left + _rng.nextDouble() * (right - left),
      top + _rng.nextDouble() * (bottom - top),
    );

    var valid = true;
    for (final other in avoid) {
      if (position.distanceTo(other) < minSeparation) {
        valid = false;
        break;
      }
    }

    if (valid) return position;
  }

  return randomWorldPosition(
    worldSize: worldSize,
    margin: worldMargin,
    avoid: avoid,
    minSeparation: minSeparation,
  );
}
