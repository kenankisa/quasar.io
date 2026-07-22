import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/room_visual_theme.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../utils/canvas_effects.dart';
import '../utils/viewport_cull.dart';

class CosmicMine extends PositionComponent {
  CosmicMine({required Vector2 position})
    : super(
        position: position,
        anchor: Anchor.center,
        size: Vector2.all(collisionRadius * 2.8),
      );

  static const collisionRadius = 55.0;
  static const triggerRadius = 50.0;

  bool active = true;
  double _pulse = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 2.4;
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
    final theme = RoomVisualTheme.forRoom(game?.roomType ?? RoomType.elite);
    final pulse = 0.85 + math.sin(_pulse) * 0.15;
    final coreHot = Color.lerp(const Color(0xFFFF4400), theme.accent, 0.18)!;
    final coreCool = Color.lerp(const Color(0xFFAA0000), theme.secondaryAccent, 0.12)!;

    canvas.save();
    canvas.translate(center.x, center.y);

    final outerGlow = Paint()
      ..color = coreHot.withValues(alpha: 0.25 * pulse)
      ..maskFilter = CanvasEffects.blur(collisionRadius * 0.5);

    canvas.drawCircle(Offset.zero, collisionRadius * 1.4 * pulse, outerGlow);

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFEE88).withValues(alpha: 0.95),
          coreHot,
          coreCool,
          const Color(0xFF330000),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: collisionRadius));

    canvas.drawCircle(Offset.zero, collisionRadius * pulse, corePaint);

    for (var i = 0; i < 8; i++) {
      final angle = _pulse * 0.6 + (i / 8) * math.pi * 2;
      final flareR = collisionRadius * (0.9 + math.sin(_pulse + i) * 0.1);
      canvas.drawCircle(
        Offset(math.cos(angle) * flareR * 0.7, math.sin(angle) * flareR * 0.7),
        collisionRadius * 0.08,
        Paint()
          ..color = Color.lerp(const Color(0xFFFFAA00), theme.accent, 0.25)!
              .withValues(alpha: 0.7 * pulse)
          ..maskFilter = CanvasEffects.blur(4),
      );
    }

    canvas.restore();
  }
}
