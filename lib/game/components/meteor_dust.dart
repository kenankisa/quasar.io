import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/viewport_cull.dart';

/// Mass dust left behind by meteors — collectible by small black holes.
class MeteorDust extends PositionComponent with HasGameReference<OrbitGame> {
  MeteorDust({
    required Vector2 position,
    this.growthValue = 1.0,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(10),
        );

  final double growthValue;

  bool active = true;
  double _elapsed = 0;
  static const lifetime = 8.0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      deactivate();
    }
  }

  void deactivate() {
    active = false;
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    if (ViewportCull.isOffScreen(game, position, 30)) return;
    super.render(canvas);
    final t = (_elapsed / lifetime).clamp(0.0, 1.0);
    final alpha = (1 - t) * 0.85;
    final pulse = 0.85 + math.sin(_elapsed * 8) * 0.15;
    final center = size / 2;

    CanvasEffects.drawSoftGlowCircle(
      canvas,
      Offset(center.x, center.y),
      5.5 * pulse,
      const Color(0xFFFF4466),
      intensity: alpha * 0.55,
    );

    canvas.drawCircle(
      Offset(center.x, center.y),
      2.2 * pulse,
      Paint()..color = const Color(0xFFFFAA88).withValues(alpha: alpha),
    );
  }
}
