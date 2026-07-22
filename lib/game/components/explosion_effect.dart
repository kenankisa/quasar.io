import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/cosmic_particle_presets.dart';
import '../utils/viewport_cull.dart';

/// Supernova / mine / merger burst — soft glow (Canvas) + radial sparks (Flame).
class ExplosionEffect extends PositionComponent {
  ExplosionEffect({
    required Vector2 position,
    this.maxRadius = 120,
    this.duration = 0.55,
  }) : super(
         position: position,
         anchor: Anchor.center,
         size: Vector2.all(maxRadius * 2.4),
       );

  final double maxRadius;
  final double duration;

  double _elapsed = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      ParticleSystemComponent(
        anchor: Anchor.center,
        particle: CosmicParticlePresets.explosionBurst(
          maxRadius: maxRadius,
          duration: duration,
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
      return;
    }
    final game = findGame() as OrbitGame?;
    // Far: advance lifetime only — skip ParticleSystemComponent sim.
    if (game != null &&
        ViewportCull.isFarFromView(game, position, margin: maxRadius + 80)) {
      return;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final game = findGame() as OrbitGame?;
    if (game != null &&
        ViewportCull.isOffScreen(game, position, maxRadius + 40)) {
      return;
    }
    super.render(canvas);
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final center = size / 2;
    final radius = maxRadius * Curves.easeOut.transform(t);
    final alpha = math.pow(1 - t, 1.4).toDouble() * 0.9;

    if (alpha < 0.02) return;

    canvas.save();
    canvas.translate(center.x, center.y);

    // Core fireball — particles handle sparks; this is the ambient glow.
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFFFF4400).withValues(alpha: alpha * 0.45)
        ..maskFilter = CanvasEffects.blur(radius * 0.32),
    );

    canvas.drawCircle(
      Offset.zero,
      radius * 0.55,
      Paint()
        ..color = const Color(0xFFFFEE88).withValues(alpha: alpha * 0.65)
        ..maskFilter = CanvasEffects.blur(10),
    );

    // Expanding shock ring at mid-burst.
    if (t > 0.08 && t < 0.72) {
      final ringT = ((t - 0.08) / 0.64).clamp(0.0, 1.0);
      final ringR = maxRadius * (0.35 + ringT * 0.85);
      final ringAlpha = alpha * (1 - ringT) * 0.55;
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, maxRadius * 0.018)
          ..color = const Color(0xFFFFAA44).withValues(alpha: ringAlpha),
      );
    }

    canvas.restore();
  }
}
