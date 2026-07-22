import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../utils/canvas_effects.dart';

/// Concentric spacetime ripples radiated by an inspiraling binary
/// (reference Stage 3: "Massive Gravitational Waves — Ripples in Spacetime")
/// and by the final merger burst (Stage 4: "Final Gravitational Wave burst").
class GravitationalWaveRippleEffect extends PositionComponent {
  GravitationalWaveRippleEffect({
    required Vector2 position,
    required this.maxRadius,
    this.duration = 1.4,
    this.ringCount = 3,
    this.intensity = 1.0,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(maxRadius * 2.2),
          priority: -3,
        );

  final double maxRadius;
  final double duration;
  final int ringCount;
  final double intensity;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final center = size / 2;
    final strength = intensity.clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(center.x, center.y);

    for (var i = 0; i < ringCount; i++) {
      // Each ring trails the previous — a wave train, not a single shell.
      final ringT = (t - i * (0.42 / ringCount)).clamp(0.0, 1.0);
      if (ringT <= 0) continue;

      final radius = maxRadius * Curves.easeOutCubic.transform(ringT);
      // Ease-in + ease-out fade so rings bloom and dissolve softly instead
      // of popping in at full contrast (the old "pen stroke" look).
      final envelope =
          Curves.easeOut.transform((1 - ringT).clamp(0.0, 1.0)) *
              Curves.easeIn.transform((ringT * 5).clamp(0.0, 1.0));
      final fade = envelope * (0.26 + strength * 0.3);
      if (fade <= 0.02 || radius < 2) continue;

      final color = Color.lerp(
        const Color(0xFF66E8FF),
        const Color(0xFFB090FF),
        i / (ringCount > 1 ? ringCount - 1 : 1),
      )!;

      // Soft gradient band instead of a hard stroked circle — reads as a
      // travelling wavefront rather than a drawn outline.
      final bandW = radius * (0.16 - ringT * 0.06) + 3.0;
      final inner = ((radius - bandW) / radius).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              color.withValues(alpha: fade * 0.5),
              Colors.white.withValues(alpha: fade * 0.35),
              Colors.transparent,
            ],
            stops: [
              inner,
              (inner + (1 - inner) * 0.55).clamp(0.0, 1.0),
              (inner + (1 - inner) * 0.8).clamp(0.0, 1.0),
              1.0,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius),
          )
          ..blendMode = BlendMode.plus
          ..maskFilter = CanvasEffects.blur(2.5),
      );
    }

    canvas.restore();
  }
}
