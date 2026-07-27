import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Vacuum star field — spectral distribution, magnitude power-law, no twinkle.
abstract final class ScientificStarField {
  ScientificStarField._();

  /// Blackbody-ish palette weighted by stellar abundance (M/K common, O rare).
  static const spectralColors = <(Color, double)>[
    (Color(0xFFFFC9A0), 0.24),
    (Color(0xFFFFDDBB), 0.18),
    (Color(0xFFFFF1DC), 0.16),
    (Color(0xFFFFFFFF), 0.14),
    (Color(0xFFF2F6FF), 0.11),
    (Color(0xFFDFE9FF), 0.08),
    (Color(0xFFC4D8FF), 0.06),
    (Color(0xFFA9C5FF), 0.03),
  ];

  static Color sampleSpectralColor(double roll, {double hotBias = 0}) {
    if (hotBias > 0 && roll < hotBias * 0.55) {
      final idx = 5 + (roll * 3).floor().clamp(0, 2);
      return spectralColors[idx].$1;
    }
    var r = roll;
    for (final (color, weight) in spectralColors) {
      r -= weight;
      if (r <= 0) return color;
    }
    return Colors.white;
  }

  static List<ScientificStar> buildTinyField({
    required int seed,
    required int count,
  }) {
    final rng = math.Random(seed);
    return List.generate(count, (i) {
      final h1 = rng.nextDouble();
      final h2 = rng.nextDouble();
      final h3 = rng.nextDouble();
      return ScientificStar(
        x: h1,
        y: h2,
        radius: 0.38 + h3 * 0.38,
        alpha: 0.32 + h3 * 0.28,
        color: Colors.white,
      );
    });
  }

  static List<ScientificStar> buildField({
    required int seed,
    required int count,
  }) {
    final rng = math.Random(seed);
    return List.generate(count, (i) {
      final h1 = rng.nextDouble();
      final h2 = rng.nextDouble();
      final h3 = rng.nextDouble();

      // Power-law magnitude: mostly faint field stars, few bright.
      final magnitude = math.pow(h1, 2.8).toDouble();
      final radius = 0.28 + magnitude * 1.35;
      final alpha = 0.12 + magnitude * 0.72;
      final hotBias = magnitude > 0.82 ? 0.35 : 0.0;

      return ScientificStar(
        x: h2,
        y: h3,
        radius: radius,
        alpha: alpha.clamp(0.08, 0.92),
        color: sampleSpectralColor(rng.nextDouble(), hotBias: hotBias),
        diffractionSpikes: magnitude > 0.88 && rng.nextDouble() > 0.35,
      );
    });
  }

  static void paint(
    Canvas canvas,
    Size size, {
    required List<ScientificStar> stars,
    double brightness = 1,
    double sizeScale = 1,
  }) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final star in stars) {
      final x = star.x * size.width;
      final y = star.y * size.height;
      final alpha = (star.alpha * brightness).clamp(0.0, 1.0);
      final center = Offset(x, y);
      final radius = star.radius * sizeScale;

      paint.color = star.color.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);

      if (star.diffractionSpikes && radius > 0.9) {
        _paintDiffractionSpikes(canvas, center, radius, star.color, alpha);
      }
    }
  }

  static void _paintDiffractionSpikes(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final spikePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.35;
    final len = radius * 4.2;
    final spikeAlpha = alpha * 0.22;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final dx = math.cos(angle) * len;
      final dy = math.sin(angle) * len;
      spikePaint.shader = ui.Gradient.linear(
        center,
        center + Offset(dx, dy),
        [
          color.withValues(alpha: spikeAlpha),
          color.withValues(alpha: spikeAlpha * 0.35),
          Colors.transparent,
        ],
        const [0.0, 0.45, 1.0],
      );
      canvas.drawLine(center, center + Offset(dx, dy), spikePaint);
    }
  }
}

class ScientificStar {
  const ScientificStar({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.color,
    this.diffractionSpikes = false,
  });

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final Color color;
  final bool diffractionSpikes;
}
