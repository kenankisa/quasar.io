import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/viewport_cull.dart';

/// Neon-red meteor falling during a meteor shower event.
class Meteor extends PositionComponent with HasGameReference<OrbitGame> {
  Meteor({
    required Vector2 position,
    required Vector2 velocity,
    this.collisionRadius = 10,
  }) : velocity = velocity.clone(),
       super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(collisionRadius * 3.6),
        );

  final double collisionRadius;
  final Vector2 velocity;

  bool active = true;

  static const _bodyColor = Color(0xFFFF1133);
  static const _coreColor = Color(0xFFFFEEAA);

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    position.addScaled(velocity, dt);
  }

  void deactivate() {
    active = false;
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    // Showers spawn dozens of meteors across the region — only draw visible ones.
    if (ViewportCull.isOffScreen(game, position, size.x)) return;
    super.render(canvas);
    final center = size / 2;

    canvas.save();
    canvas.translate(center.x, center.y);

    final angle = math.atan2(velocity.y, velocity.x);
    canvas.rotate(angle);

    final trailLen = collisionRadius * 4.5;
    canvas.drawLine(
      Offset(-trailLen, 0),
      Offset(collisionRadius * 0.6, 0),
      Paint()
        ..shader = LinearGradient(
          colors: [
            _bodyColor.withValues(alpha: 0),
            _bodyColor.withValues(alpha: 0.85),
            _coreColor.withValues(alpha: 0.95),
          ],
        ).createShader(Rect.fromLTWH(-trailLen, -6, trailLen + 6, 12))
        ..strokeWidth = collisionRadius * 0.9
        ..strokeCap = StrokeCap.round
        ..maskFilter = CanvasEffects.blur(3),
    );

    canvas.drawCircle(
      Offset.zero,
      collisionRadius * 1.2,
      Paint()
        ..color = _bodyColor.withValues(alpha: 0.45)
        ..maskFilter = CanvasEffects.blur(collisionRadius * 0.5),
    );

    canvas.drawCircle(
      Offset.zero,
      collisionRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _coreColor,
            _bodyColor,
            const Color(0xFF880011),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: collisionRadius)),
    );

    canvas.restore();
  }
}
