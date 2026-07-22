import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared neon particle field for lobby / login backgrounds.
class NeonSpaceParticlePainter extends CustomPainter {
  NeonSpaceParticlePainter({
    required this.progress,
    this.particleCount = 40,
    this.seed = 7,
    this.blurSigma = 3,
    this.maxOpacity = 0.5,
    this.driftAmplitude = 0,
    this.drawGlow = false,
  });

  final double progress;
  final int particleCount;
  final int seed;
  final double blurSigma;
  final double maxOpacity;
  final double driftAmplitude;
  final bool drawGlow;

  static const _colors = [
    Color(0xFF00F0FF),
    Color(0xFFFF00AA),
    Color(0xFF7B2FFF),
    Color(0xFF00FF88),
    Color(0xFFFFAA00),
  ];

  late final List<_NeonParticle> _particles = () {
    final random = math.Random(seed);
    return List.generate(particleCount, (i) {
      return _NeonParticle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: random.nextDouble() * (drawGlow ? 2.5 : 1.8) +
            (drawGlow ? 0.5 : 0.4),
        speed: random.nextDouble() * (drawGlow ? 0.3 : 0.2) +
            (drawGlow ? 0.05 : 0.04),
        color: _colors[i % _colors.length],
        phase: random.nextDouble() * math.pi * 2,
      );
    });
  }();

  final _paint = Paint();
  final _glowPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final sinFreq = drawGlow ? 4.0 : 3.0;
    for (final p in _particles) {
      final t = (progress + p.phase / (math.pi * 2)) % 1.0;
      final x = (p.x +
              (driftAmplitude > 0
                  ? math.sin(t * math.pi * 2 + p.phase) * driftAmplitude
                  : 0)) *
          size.width;
      final y = ((p.y + t * p.speed) % 1.0) * size.height;
      final opacity =
          (math.sin(t * math.pi * sinFreq + p.phase) * 0.5 + 0.5) * maxOpacity;

      _paint
        ..color = p.color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
      canvas.drawCircle(Offset(x, y), p.radius, _paint);

      if (drawGlow) {
        _glowPaint
          ..color = p.color.withValues(alpha: opacity * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 3);
        canvas.drawCircle(Offset(x, y), p.radius * 2, _glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NeonSpaceParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _NeonParticle {
  const _NeonParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.color,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final Color color;
  final double phase;
}
