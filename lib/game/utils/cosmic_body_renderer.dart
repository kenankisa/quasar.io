import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'canvas_effects.dart';

/// Deterministic, shader-light procedural bodies for collectibles.
abstract final class CosmicBodyRenderer {
  CosmicBodyRenderer._();

  static int seedFrom(Vector2 position) =>
      Object.hash(position.x.round(), position.y.round());

  /// Irregular rocky asteroid silhouette with directional lighting.
  static void drawAsteroid(
    Canvas canvas,
    double r,
    Color baseColor,
    int seed, {
    int vertexCount = 8,
    double irregularity = 0.24,
  }) {
    if (CanvasEffects.mobileLiteMode) {
      _drawRockyBodyLite(
        canvas,
        r,
        baseColor,
        seed,
        vertexCount: vertexCount.clamp(6, 8),
        irregularity: irregularity * 0.85,
      );
      return;
    }

    final path = _smoothIrregularPath(r, seed, vertexCount, irregularity);
    final bounds = path.getBounds();
    final lit = Color.lerp(baseColor, Colors.white, 0.22)!;
    final mid = baseColor;
    final shadow = Color.lerp(baseColor, Colors.black, 0.5)!;

    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.44, -0.4),
          radius: 1.15,
          colors: [lit, mid, shadow, Color.lerp(shadow, Colors.black, 0.35)!],
          stops: const [0.0, 0.42, 0.78, 1.0],
        ).createShader(bounds),
    );

    // Terminator shadow — cheap directional depth without extra passes on mobile.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(-r * 1.2, r * 0.05, r * 2.4, r * 1.2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            shadow.withValues(alpha: 0.38),
          ],
        ).createShader(Rect.fromLTWH(-r, -r, r * 2, r * 2)),
    );

    // Crater pits — fixed count, cheap ellipses clipped to body.
    final rng = math.Random(seed + 17);
    final craterCount = 2 + (seed % 3);
    for (var i = 0; i < craterCount; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final dist = r * (0.15 + rng.nextDouble() * 0.45);
      final cr = r * (0.08 + rng.nextDouble() * 0.1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(math.cos(a) * dist, math.sin(a) * dist),
          width: cr * 1.6,
          height: cr,
        ),
        Paint()
          ..color = Color.lerp(baseColor, Colors.black, 0.35)!
              .withValues(alpha: 0.55),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(math.cos(a) * dist - cr * 0.12, math.sin(a) * dist - cr * 0.08),
          width: cr * 0.55,
          height: cr * 0.35,
        ),
        Paint()..color = lit.withValues(alpha: 0.18),
      );
    }

    _drawMicroTexture(canvas, r, seed + 53, baseColor, lite: false);
    canvas.restore();

    _drawSpecularHighlight(canvas, r * 0.22, Offset(-r * 0.28, -r * 0.32), 0.55);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Color.lerp(shadow, Colors.black, 0.2)!.withValues(alpha: 0.42),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Color.lerp(baseColor, Colors.white, 0.15)!
            .withValues(alpha: 0.28),
    );
  }

  /// Angular göktaşı with fusion-crust rim and metallic flecks.
  static void drawMeteorite(
    Canvas canvas,
    double r,
    Color base,
    Color highlight,
    Color core,
    int seed,
  ) {
    if (CanvasEffects.mobileLiteMode) {
      final path = _smoothIrregularPath(r, seed, 7, 0.16);
      _drawRockyBodyLite(canvas, r, base, seed, vertexCount: 7, irregularity: 0.16);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..color = core.withValues(alpha: 0.55),
      );
      return;
    }

    final path = _smoothIrregularPath(r, seed, 7, 0.18);
    final bounds = path.getBounds();
    final lit = Color.lerp(highlight, Colors.white, 0.15)!;

    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.05,
          colors: [lit, base, core],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
    );

    // Fusion crust — darkened leading edge (ablation from atmospheric entry).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = core.withValues(alpha: 0.65),
    );

    canvas.save();
    canvas.clipPath(path);
    final rng = math.Random(seed + 31);
    for (var i = 0; i < 4; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final dist = r * rng.nextDouble() * 0.55;
      canvas.drawCircle(
        Offset(math.cos(a) * dist, math.sin(a) * dist),
        r * (0.04 + rng.nextDouble() * 0.05),
        Paint()..color = highlight.withValues(alpha: 0.35 + rng.nextDouble() * 0.25),
      );
    }
    _drawMicroTexture(canvas, r, seed + 71, highlight, lite: true);

    // Ablation gouges from atmospheric entry.
    final gouge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final a = -0.55 + i * 0.35;
      gouge
        ..strokeWidth = r * (0.04 + i * 0.015)
        ..color = core.withValues(alpha: 0.35 + i * 0.12);
      canvas.drawLine(
        Offset(math.cos(a) * r * 0.15, math.sin(a) * r * 0.12),
        Offset(math.cos(a) * r * 0.72, math.sin(a) * r * 0.55),
        gouge,
      );
    }
    canvas.restore();

    _drawSpecularHighlight(canvas, r * 0.18, Offset(-r * 0.24, -r * 0.28), 0.72);
  }

  /// Enhanced planet sphere — same draw-call budget as before.
  static void drawPlanetSphere(
    Canvas canvas,
    double r,
    Color base,
    Color shade,
    Color atmosphere,
    double spin,
    void Function(Canvas canvas, double r) drawSurface,
  ) {
    if (CanvasEffects.mobileLiteMode) {
      _drawLitSphereLite(canvas, r, base, atmosphere: atmosphere);
      return;
    }

    _drawAtmosphericLimb(canvas, r, atmosphere);

    canvas.drawCircle(
      Offset.zero,
      r * 1.06,
      Paint()..color = atmosphere.withValues(alpha: 0.12),
    );

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.42, -0.44),
          radius: 1.18,
          colors: [
            Color.lerp(base, Colors.white, 0.4)!,
            base,
            Color.lerp(base, shade, 0.5)!,
            Color.lerp(shade, Colors.black, 0.6)!,
          ],
          stops: const [0.0, 0.32, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
    canvas.rotate(spin);
    drawSurface(canvas, r);
    canvas.restore();

    _drawNightTerminator(canvas, r, shade);

    canvas.drawCircle(
      Offset.zero,
      r * 0.98,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = atmosphere.withValues(alpha: 0.38),
    );

    _drawSpecularHighlight(canvas, r * 0.16, Offset(-r * 0.3, -r * 0.32), 0.42);
  }

  /// Quasar accretion disk rings with Doppler-bright inner edge.
  static void drawQuasarDisk(
    Canvas canvas,
    double r,
    Color gold,
    Color cyan,
    Color magenta,
  ) {
    if (CanvasEffects.mobileLiteMode) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = magenta.withValues(alpha: 0.7),
      );
      return;
    }

    final outerR = r * 1.68;
    canvas.drawCircle(
      Offset.zero,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..shader = SweepGradient(
          colors: [
            magenta.withValues(alpha: 0.35),
            cyan.withValues(alpha: 0.2),
            magenta.withValues(alpha: 0.45),
            gold.withValues(alpha: 0.3),
            magenta.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: outerR)),
    );

    canvas.drawCircle(
      Offset.zero,
      r * 1.35,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = gold.withValues(alpha: 0.75),
    );

    canvas.drawCircle(
      Offset.zero,
      r * 1.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = cyan.withValues(alpha: 0.6),
    );
  }

  static void drawQuasarCore(
    Canvas canvas,
    double r,
    Color core,
    Color gold,
    Color accent,
    double spin,
  ) {
    canvas.drawCircle(
      Offset.zero,
      r * 0.92,
      Paint()..color = gold.withValues(alpha: 0.16),
    );

    canvas.drawCircle(
      Offset.zero,
      r * 0.56,
      Paint()
        ..shader = RadialGradient(
          colors: [
            core,
            gold,
            accent.withValues(alpha: 0.85),
            accent.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.32, 0.68, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.56)),
    );

    final hx = math.cos(spin) * r * 0.11;
    final hy = math.sin(spin) * r * 0.07;
    canvas.drawCircle(
      Offset(hx, hy),
      r * 0.11,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );
  }

  static Path _smoothIrregularPath(
    double r,
    int seed,
    int vertices,
    double irregularity,
  ) {
    final rng = math.Random(seed);
    final points = <Offset>[];
    for (var i = 0; i < vertices; i++) {
      final angle = (i / vertices) * math.pi * 2;
      final jitter = 1.0 + (rng.nextDouble() - 0.5) * 2 * irregularity;
      points.add(Offset(math.cos(angle) * r * jitter, math.sin(angle) * r * jitter));
    }

    final path = Path();
    final start = Offset(
      (points.last.dx + points.first.dx) * 0.5,
      (points.last.dy + points.first.dy) * 0.5,
    );
    path.moveTo(start.dx, start.dy);

    for (var i = 0; i < vertices; i++) {
      final current = points[i];
      final next = points[(i + 1) % vertices];
      final mid = Offset(
        (current.dx + next.dx) * 0.5,
        (current.dy + next.dy) * 0.5,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  static void _drawRockyBodyLite(
    Canvas canvas,
    double r,
    Color baseColor,
    int seed, {
    int vertexCount = 7,
    double irregularity = 0.2,
  }) {
    final path = _smoothIrregularPath(r, seed, vertexCount, irregularity);
    final bounds = path.getBounds();
    final lit = Color.lerp(baseColor, Colors.white, 0.24)!;
    final shadow = Color.lerp(baseColor, Colors.black, 0.45)!;

    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.38),
          radius: 1.1,
          colors: [lit, baseColor, shadow],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
    );
    _drawSpecularHighlight(canvas, r * 0.18, Offset(-r * 0.26, -r * 0.3), 0.42);
  }

  static void _drawAtmosphericLimb(Canvas canvas, double r, Color atmosphere) {
    canvas.drawCircle(
      Offset.zero,
      r * 1.12,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            atmosphere.withValues(alpha: 0.08),
            atmosphere.withValues(alpha: 0.38),
            atmosphere.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.78, 0.88, 0.94, 0.98, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.12)),
    );
  }

  static void _drawNightTerminator(Canvas canvas, double r, Color shade) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
    canvas.drawRect(
      Rect.fromLTWH(r * 0.05, -r, r, r * 2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Color.lerp(shade, Colors.black, 0.35)!.withValues(alpha: 0.42),
          ],
        ).createShader(Rect.fromLTWH(0, -r, r, r * 2)),
    );
    canvas.restore();
  }

  static void _drawSpecularHighlight(
    Canvas canvas,
    double radius,
    Offset center,
    double alpha,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: alpha),
            Colors.white.withValues(alpha: alpha * 0.35),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  static void _drawMicroTexture(
    Canvas canvas,
    double r,
    int seed,
    Color tint, {
    required bool lite,
  }) {
    final rng = math.Random(seed);
    final count = lite ? 4 : 6 + (seed % 3);
    for (var i = 0; i < count; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final dist = r * rng.nextDouble() * 0.72;
      final dotR = r * (0.018 + rng.nextDouble() * 0.028);
      canvas.drawCircle(
        Offset(math.cos(a) * dist, math.sin(a) * dist),
        dotR,
        Paint()
          ..color = Color.lerp(tint, Colors.white, rng.nextDouble() * 0.35)!
              .withValues(alpha: 0.12 + rng.nextDouble() * 0.18),
      );
    }
  }

  static void _drawLitSphereLite(
    Canvas canvas,
    double r,
    Color base, {
    Color? atmosphere,
  }) {
    final lit = Color.lerp(base, Colors.white, 0.28)!;
    final shadow = Color.lerp(base, Colors.black, 0.42)!;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.05,
          colors: [lit, base, shadow],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    if (atmosphere != null) {
      _drawAtmosphericLimb(canvas, r, atmosphere);
    }
    _drawSpecularHighlight(canvas, r * 0.2, Offset(-r * 0.26, -r * 0.3), 0.38);
  }
}
