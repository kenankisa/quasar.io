import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/viewport_cull.dart';

/// Expanding shockwave ring used by supernova detonations.
class ShockwaveEffect extends PositionComponent {
  ShockwaveEffect({
    required Vector2 position,
    this.maxRadius = 600,
    this.duration = 1.4,
    this.onRadiusReached,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(maxRadius * 2.4),
        );

  final double maxRadius;
  final double duration;
  final void Function(double currentRadius)? onRadiusReached;

  double _elapsed = 0;
  double _lastReportedRadius = 0;

  double get progress => (_elapsed / duration).clamp(0.0, 1.0);
  double get currentRadius => maxRadius * progress;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (onRadiusReached != null) {
      final r = currentRadius;
      if (r - _lastReportedRadius >= 40) {
        _lastReportedRadius = r;
        onRadiusReached!(r);
      }
    }

    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final game = findGame() as OrbitGame?;
    // Gameplay radius callbacks still run in update; skip GPU when off-screen.
    if (game != null &&
        ViewportCull.isOffScreen(game, position, currentRadius + 60)) {
      return;
    }
    super.render(canvas);
    final t = progress;
    final center = size / 2;
    final radius = maxRadius * t;
    final alpha = (1 - t * 0.85) * 0.95;

    canvas.save();
    canvas.translate(center.x, center.y);

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * (1 - t * 0.5)
        ..color = const Color(0xFFFF2200).withValues(alpha: alpha * 0.7)
        ..maskFilter = CanvasEffects.blur(6),
    );

    canvas.drawCircle(
      Offset.zero,
      radius * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFFFFEEAA).withValues(alpha: alpha * 0.5)
        ..maskFilter = CanvasEffects.blur(3),
    );

    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + t * 2;
      final inner = radius * 0.75;
      final outer = radius * (0.95 + (i % 2) * 0.08);
      canvas.drawLine(
        Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        Paint()
          ..color = const Color(0xFFFF6600).withValues(alpha: alpha * 0.4)
          ..strokeWidth = 3,
      );
    }

    canvas.restore();
  }
}
