import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/viewport_cull.dart';

class ShieldPowerUp extends PositionComponent {
  ShieldPowerUp({required Vector2 position})
    : super(
        position: position,
        anchor: Anchor.center,
        size: Vector2.all(collisionRadius * 2.6),
      );

  static const collisionRadius = 28.0;

  bool active = true;
  double _pulse = 0;
  double _orbit = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 3.2;
    _orbit += dt * 1.4;
  }

  void deactivate() {
    active = false;
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    final game = findGame() as OrbitGame?;
    if (game != null &&
        ViewportCull.isOffScreen(
          game,
          position,
          collisionRadius * 2.5,
        )) {
      return;
    }
    super.render(canvas);
    final center = size / 2;
    final pulse = 0.88 + math.sin(_pulse) * 0.12;

    canvas.save();
    canvas.translate(center.x, center.y);

    final glowPaint = Paint()
      ..color = const Color(0xFF00B4FF).withValues(alpha: 0.3 * pulse)
      ..maskFilter = CanvasEffects.blur(collisionRadius * 0.6);
    canvas.drawCircle(Offset.zero, collisionRadius * 1.5 * pulse, glowPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.9 * pulse)
      ..maskFilter = CanvasEffects.blur(4);
    canvas.drawCircle(Offset.zero, collisionRadius * pulse, ringPaint);

    _drawShieldIcon(canvas, pulse);

    canvas.restore();
  }

  void _drawShieldIcon(Canvas canvas, double pulse) {
    final path = Path();
    final r = collisionRadius * 0.55 * pulse;
    path.moveTo(0, -r);
    path.quadraticBezierTo(r * 1.1, -r * 0.35, r * 0.85, r * 0.55);
    path.quadraticBezierTo(0, r * 1.05, -r * 0.85, r * 0.55);
    path.quadraticBezierTo(-r * 1.1, -r * 0.35, 0, -r);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF66EEFF).withValues(alpha: 0.95),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00B4FF).withValues(alpha: 0.25)
        ..maskFilter = CanvasEffects.blur(3),
    );

    for (var i = 0; i < 3; i++) {
      final angle = _orbit + (i / 3) * math.pi * 2;
      canvas.drawCircle(
        Offset(math.cos(angle) * r * 1.35, math.sin(angle) * r * 1.35),
        2.5,
        Paint()
          ..color = const Color(0xFF00F0FF).withValues(alpha: 0.8)
          ..maskFilter = CanvasEffects.blur(2),
      );
    }
  }
}
