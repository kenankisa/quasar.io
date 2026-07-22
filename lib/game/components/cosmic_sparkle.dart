import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/viewport_cull.dart';

class CosmicSparkle extends PositionComponent {
  CosmicSparkle({
    required Vector2 position,
    this.lifetime = 1.6,
  }) : _drift = Vector2(
          (math.Random().nextDouble() - 0.5) * 40,
          (math.Random().nextDouble() - 0.5) * 40,
        ),
       super(
         position: position,
         anchor: Anchor.center,
         size: Vector2.all(8),
       );

  final double lifetime;
  final Vector2 _drift;

  double _elapsed = 0;
  final _hueShift = math.Random().nextDouble();

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
      return;
    }
    final game = findGame() as OrbitGame?;
    if (game != null && ViewportCull.isFarFromView(game, position, margin: 80)) {
      return;
    }
    position.addScaled(_drift, dt);
  }

  @override
  void render(Canvas canvas) {
    final game = findGame() as OrbitGame?;
    if (game != null && ViewportCull.isOffScreen(game, position, 24)) {
      return;
    }
    super.render(canvas);
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final alpha = (1 - t) * 0.9;
    final center = size / 2;
    final hue = (240 + _hueShift * 80 + _elapsed * 120) % 360;
    final color = HSVColor.fromAHSV(1, hue, 0.7, 1).toColor();

    CanvasEffects.drawSoftGlowCircle(
      canvas,
      Offset(center.x, center.y),
      4.5 * (1 - t * 0.5),
      color,
      intensity: alpha * 0.7,
    );

    canvas.drawCircle(
      Offset(center.x, center.y),
      2.0 * (1 - t * 0.5),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }
}
