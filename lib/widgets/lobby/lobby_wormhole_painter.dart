import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Photoreal traversable wormhole — volumetric nebula throat, soft Einstein annulus.
class LobbyWormholePainter extends CustomPainter {
  LobbyWormholePainter({
    required this.accent,
    required this.secondary,
    required this.locked,
    this.bloom,
    this.richness = 1,
    this.ringCount = 4,
    this.time = 0,
    this.approach = 0,
    this.viewerAngle,
    this.hardcore = false,
  });

  final Color accent;
  final Color secondary;
  final bool locked;
  final Color? bloom;
  final int richness;
  final int ringCount;
  final double time;
  final double approach;
  final double? viewerAngle;
  final bool hardcore;

  /// Integer revolutions per animation loop — t=0 and t=1 must match visually.
  static int loopCycles(double prox) {
    if (prox < 0.1) return 1;
    if (prox < 0.55) return 2;
    return 3;
  }

  /// Seamless phase: harmonic full turns per loop (harmonic must be int).
  static double loopAngle(double time, int cycles, int harmonic, [double offset = 0]) {
    final turns = time * cycles * harmonic;
    final wrapped = turns - turns.floorToDouble();
    return wrapped * math.pi * 2 + offset;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    final alpha = locked ? 0.32 : 1.0;
    final prox = approach.clamp(0.0, 1.0);
    final cycles = loopCycles(prox);
    final depthReveal = 1.0 + prox * 0.55 + richness * 0.06;
    final palette = _resolvePalette();

    _paintAmbientHalo(canvas, center, radius, palette, alpha, prox);
    _paintBackgroundStarField(canvas, center, radius, alpha, time, cycles);

    canvas.save();
    _clipSphere(canvas, center, radius * 0.995);
    _paintThroatDepth(
      canvas,
      center,
      radius,
      palette,
      alpha,
      time,
      cycles,
      prox,
      depthReveal,
    );
    _paintVolumetricNebula(
      canvas,
      center,
      radius,
      palette,
      alpha,
      time,
      cycles,
      prox,
      depthReveal,
    );
    _paintDistantCore(canvas, center, radius, palette, alpha, prox, depthReveal);
    _paintInteriorStarDust(
      canvas,
      center,
      radius,
      alpha,
      time,
      cycles,
      depthReveal,
    );
    canvas.restore();

    _paintSphereAtmosphere(canvas, center, radius, palette, alpha);
    _paintPhotonSphereShadow(canvas, center, radius, palette, alpha, prox, time, cycles);
    _paintEinsteinAnnulus(canvas, center, radius, palette, alpha, prox, time, cycles);
    _paintRimCaustics(canvas, center, radius, palette, alpha, time, cycles, prox);
    _paintLensedRingStars(canvas, center, radius, alpha, time, cycles, prox);

    if (prox > 0.04) {
      _paintGravitationalInflow(canvas, center, radius, palette, alpha, prox);
      _paintApproachLensing(canvas, center, radius, palette, alpha, prox);
    }
    if (locked) {
      _paintLockVeil(canvas, center, radius, alpha);
    }
  }

  _WormholePalette _resolvePalette() {
    if (hardcore) {
      return const _WormholePalette(
        deep: Color(0xFF0A0302),
        nebulaCool: Color(0xFF8A2818),
        nebulaWarm: Color(0xFFE85A20),
        nebulaCore: Color(0xFFFFC890),
        ringHot: Color(0xFFFFE4C8),
        ringCool: Color(0xFFFF7040),
      );
    }
    final bloomColor = bloom ?? accent;
    return _WormholePalette(
      deep: Color.lerp(const Color(0xFF02040C), accent, 0.12)!,
      nebulaCool: Color.lerp(const Color(0xFF1A4A8C), accent, 0.28)!,
      nebulaWarm: Color.lerp(const Color(0xFFB85A28), secondary, 0.22)!,
      nebulaCore: Color.lerp(const Color(0xFF6A8CB8), bloomColor, 0.18)!,
      ringHot: Color.lerp(const Color(0xFFFFF8F0), accent, 0.08)!,
      ringCool: Color.lerp(const Color(0xFF90C8F0), secondary, 0.15)!,
    );
  }

  double _hash(int i) {
    final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return x - x.floor();
  }

  void _clipSphere(Canvas canvas, Offset center, double radius) {
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _paintAmbientHalo(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double prox,
  ) {
    canvas.drawCircle(
      center,
      radius * (1.18 + prox * 0.06),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            palette.nebulaCool.withValues(alpha: 0.04 * alpha),
            palette.nebulaWarm.withValues(alpha: 0.03 * alpha),
            Colors.transparent,
          ],
          stops: const [0.55, 0.78, 0.9, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2)),
    );
  }

  void _paintBackgroundStarField(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
    double time,
    int cycles,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 64; i++) {
      final h1 = _hash(i);
      final h2 = _hash(i + 97);
      final h3 = _hash(i + 211);
      final a = h1 * math.pi * 2 + loopAngle(time, cycles, 1);
      final dist = radius * (0.92 + h2 * 0.45);
      final p = center + Offset(math.cos(a), math.sin(a)) * dist;
      final mag = 0.25 + h3 * 0.55;
      final bright = 0.08 + h3 * 0.22;
      paint.color = Color.lerp(
        const Color(0xFFB8C8E0),
        Colors.white,
        h3,
      )!.withValues(alpha: bright * alpha * (dist > radius * 1.05 ? 0.7 : 1));
      canvas.drawCircle(p, mag, paint);
      if (h3 > 0.72) {
        paint.color = Colors.white.withValues(alpha: bright * 0.15 * alpha);
        canvas.drawCircle(p, mag * 2.8, paint);
      }
    }
  }

  void _paintThroatDepth(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double time,
    int cycles,
    double prox,
    double depthReveal,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.nebulaCore.withValues(alpha: 0.14 * alpha * depthReveal),
            palette.deep.withValues(alpha: alpha),
            const Color(0xFF010308).withValues(alpha: alpha),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Receding tunnel shells — integer harmonics keep the loop seam invisible.
    final depthPull = prox * 0.14;
    for (var layer = 8; layer >= 0; layer--) {
      final t = layer / 8;
      final shellR = radius * (0.22 + t * 0.78) * (1 - depthPull * t);
      final harmonic = 1 + layer % 3;
      final rot = loopAngle(time, cycles, harmonic, layer * 0.4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rot);
      canvas.scale(1.0, 0.88 + t * 0.06);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: shellR * 2,
          height: shellR * 1.7,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              palette.nebulaCool.withValues(
                alpha: (0.05 + t * 0.04) * alpha * depthReveal,
              ),
              palette.nebulaWarm.withValues(
                alpha: (0.02 + t * 0.025) * alpha * depthReveal,
              ),
              Colors.transparent,
            ],
            stops: const [0.5, 0.78, 0.88, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: shellR)),
      );
      canvas.restore();
    }

    // Receding tunnel rings — readable depth structure, spins with the throat.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      final ringR = radius * (0.3 + t * 0.5) * (1 - depthPull * t * 0.45);
      final harmonic = 2 + i;
      final rot = loopAngle(time, cycles, harmonic, i * 0.85);
      ringPaint
        ..strokeWidth = 0.7 + t * 0.5
        ..color = Color.lerp(palette.nebulaWarm, palette.nebulaCore, t)!
            .withValues(alpha: (0.08 + t * 0.06 + prox * 0.08) * alpha * depthReveal);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rot);
      canvas.scale(1.0, 0.72 + t * 0.08);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: ringR * 2,
          height: ringR * 1.45,
        ),
        ringPaint,
      );
      canvas.restore();
    }
  }

  void _paintVolumetricNebula(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double time,
    int cycles,
    double prox,
    double depthReveal,
  ) {
    final blobCount = 14 + richness * 4;
    for (var i = 0; i < blobCount; i++) {
      final h1 = _hash(i * 3);
      final h2 = _hash(i * 3 + 1);
      final h3 = _hash(i * 3 + 2);
      final depth = 0.15 + h1 * 0.75;
      final harmonic = 1 + i % 4;
      final angle = h2 * math.pi * 2 + loopAngle(time, cycles, harmonic, i * 0.7);
      final dist = radius * depth * (0.92 + prox * 0.08);
      final blobCenter = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final blobR = radius * (0.14 + h3 * 0.28) * (1.1 - depth * 0.35);

      final color = switch (i % 3) {
        0 => palette.nebulaCool,
        1 => palette.nebulaWarm,
        _ => palette.nebulaCore,
      };
      final strength =
          (0.12 + h3 * 0.18) * (1 - depth * 0.28) * alpha * depthReveal;

      canvas.drawCircle(
        blobCenter,
        blobR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: strength * 1.2),
              color.withValues(alpha: strength * 0.45),
              color.withValues(alpha: strength * 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.28, 0.58, 1.0],
          ).createShader(Rect.fromCircle(center: blobCenter, radius: blobR)),
      );
    }
  }

  void _paintDistantCore(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double prox,
    double depthReveal,
  ) {
    final coreR = radius * (0.36 + prox * 0.06);
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.nebulaCore.withValues(alpha: 0.34 * alpha * depthReveal),
            palette.nebulaWarm.withValues(alpha: 0.22 * alpha * depthReveal),
            palette.nebulaCool.withValues(alpha: 0.1 * alpha * depthReveal),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );
    canvas.drawCircle(
      center,
      coreR * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.28 * alpha * depthReveal),
            palette.nebulaWarm.withValues(alpha: 0.14 * alpha * depthReveal),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: coreR * 0.45)),
    );
    canvas.drawCircle(
      center,
      coreR * 0.14,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22 * alpha * depthReveal),
            palette.nebulaCore.withValues(alpha: 0.1 * alpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: coreR * 0.18)),
    );
  }

  void _paintInteriorStarDust(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
    double time,
    int cycles,
    double depthReveal,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    final starCount = 48 + richness * 8;
    for (var i = 0; i < starCount; i++) {
      final h1 = _hash(i + 400);
      final h2 = _hash(i + 500);
      final h3 = _hash(i + 600);
      final depth = h1;
      final harmonic = 1 + i % 3;
      final a = h2 * math.pi * 2 + loopAngle(time, cycles, harmonic);
      final dist = radius * depth * 0.9;
      final p = center + Offset(math.cos(a), math.sin(a)) * dist;
      paint.color = Colors.white.withValues(
        alpha: (0.07 + h3 * 0.24) * alpha * depthReveal,
      );
      canvas.drawCircle(p, 0.35 + h3 * 0.55, paint);
      if (h3 > 0.72) {
        paint.color = Color.lerp(
          const Color(0xFFB8D0F0),
          Colors.white,
          h3,
        )!.withValues(
          alpha: (0.05 + h3 * 0.1) * alpha * depthReveal,
        );
        canvas.drawCircle(p, 0.9 + h3 * 0.6, paint);
      }
    }
  }

  void _paintSphereAtmosphere(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
  ) {
    // Limb darkening — keep the center open so throat depth stays readable.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.08, 0.12),
          radius: 1.0,
          colors: [
            Colors.transparent,
            Colors.transparent,
            palette.deep.withValues(alpha: 0.05 * alpha),
            palette.deep.withValues(alpha: 0.16 * alpha),
            Colors.black.withValues(alpha: 0.42 * alpha),
            Colors.black.withValues(alpha: 0.68 * alpha),
          ],
          stops: const [0.0, 0.64, 0.8, 0.88, 0.94, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Subtle forward-scattered rim haze just outside silhouette.
    canvas.drawCircle(
      center,
      radius * 1.012,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            palette.nebulaCool.withValues(alpha: 0.04 * alpha),
            palette.ringCool.withValues(alpha: 0.07 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.90, 0.94, 0.97, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.02)),
    );
  }

  void _paintPhotonSphereShadow(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double prox,
    double time,
    int cycles,
  ) {
    final ringR = radius * (0.905 + prox * 0.008);

    // Razor-thin dark band — photon sphere just inside the Einstein ring.
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.42 * alpha),
            Colors.black.withValues(alpha: 0.72 * alpha),
            Colors.black.withValues(alpha: 0.55 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.855, 0.885, 0.905, 0.918, 0.94],
        ).createShader(Rect.fromCircle(center: center, radius: ringR)),
    );

    // Angular irregularity — gravity well is not perfectly symmetric.
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 24; i++) {
      final h = _hash(i + 1200);
      final h2 = _hash(i + 1300);
      final a = i * (math.pi * 2 / 24) +
          loopAngle(time, cycles, 1, (h - 0.5) * 0.25);
      final rimJitter = radius * (0.898 + h2 * 0.018);
      final p = center + Offset(math.cos(a), math.sin(a)) * rimJitter;
      final blobR = radius * (0.018 + h * 0.028);

      paint.color = Colors.black.withValues(alpha: (0.12 + h * 0.18) * alpha);
      canvas.drawCircle(p, blobR, paint);
    }
  }

  void _paintRimCaustics(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double time,
    int cycles,
    double prox,
  ) {
    final ringR = radius * 0.94;

    for (var i = 0; i < 18; i++) {
      final h = _hash(i + 1500);
      final h2 = _hash(i + 1600);
      final a = i * (math.pi * 2 / 18) + loopAngle(time, cycles, 2, h * 0.4);
      final radial = ringR + (h2 - 0.5) * radius * 0.035;
      final p = center + Offset(math.cos(a), math.sin(a)) * radial;
      final streakLen = radius * (0.04 + h * 0.07);
      final streakW = radius * (0.006 + h2 * 0.01);

      final streakEnd = p + Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * streakLen;
      final streakPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = streakW
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            palette.ringHot.withValues(alpha: (0.08 + h * 0.14 + prox * 0.1) * alpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromPoints(p, streakEnd));

      canvas.drawLine(p, streakEnd, streakPaint);
    }
  }

  void _paintEinsteinAnnulus(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double prox,
    double time,
    int cycles,
  ) {
    final ringR = radius * (0.932 + prox * 0.006);
    final limbAngle = viewerAngle ?? 0.0;
    final limbOffset = Offset(
      math.cos(limbAngle) * radius * prox * 0.04,
      math.sin(limbAngle) * radius * prox * 0.04,
    );
    final ringCenter = center + limbOffset;

    // Outer chromatic spill — warm light diffracts wider (faint).
    canvas.drawCircle(
      ringCenter,
      ringR * 1.055,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            palette.nebulaWarm.withValues(alpha: 0.028 * alpha),
            palette.nebulaWarm.withValues(alpha: 0.045 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.90, 0.94, 0.97, 1.0],
        ).createShader(
          Rect.fromCircle(center: ringCenter, radius: ringR * 1.055),
        ),
    );

    // Inner chromatic spill — cool channel sits tighter.
    canvas.drawCircle(
      ringCenter,
      ringR * 1.018,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            palette.ringCool.withValues(alpha: 0.04 * alpha),
            palette.ringCool.withValues(alpha: 0.07 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.88, 0.92, 0.95, 1.0],
        ).createShader(
          Rect.fromCircle(center: ringCenter, radius: ringR * 1.018),
        ),
    );

    // Primary photon ring — razor-thin Einstein annulus, not a UI stroke.
    canvas.drawCircle(
      ringCenter,
      ringR * 1.032,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            palette.ringCool.withValues(alpha: 0.035 * alpha),
            palette.ringCool.withValues(alpha: 0.08 * alpha),
            palette.ringHot.withValues(alpha: (0.14 + prox * 0.12) * alpha),
            palette.ringHot.withValues(alpha: (0.22 + prox * 0.16) * alpha),
            Colors.white.withValues(alpha: (0.28 + prox * 0.18) * alpha),
            palette.ringHot.withValues(alpha: (0.18 + prox * 0.12) * alpha),
            palette.nebulaWarm.withValues(alpha: 0.05 * alpha),
            palette.ringCool.withValues(alpha: 0.025 * alpha),
            Colors.transparent,
          ],
          stops: const [
            0.0, 0.86, 0.912, 0.922, 0.928, 0.932, 0.936, 0.940, 0.946, 0.958, 1.0,
          ],
        ).createShader(
          Rect.fromCircle(center: ringCenter, radius: ringR * 1.032),
        ),
    );

    // Second-order diffraction — barely visible echo.
    canvas.drawCircle(
      ringCenter,
      ringR * 1.065,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
            palette.ringHot.withValues(alpha: 0.018 * alpha),
            palette.ringCool.withValues(alpha: 0.025 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.92, 0.95, 0.965, 1.0],
        ).createShader(
          Rect.fromCircle(center: ringCenter, radius: ringR * 1.065),
        ),
    );

    // Lensed star accumulation on the ring — asymmetric under approach.
    final spotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 16; i++) {
      final h = _hash(i + 1700);
      final h2 = _hash(i + 1800);
      final a = i * (math.pi * 2 / 16) +
          loopAngle(time, cycles, 1, (h - 0.5) * 0.28);
      final approachSide = math.cos(a - limbAngle);
      final asymBoost = approachSide * prox * 0.35;
      final radial = ringR * (0.992 + h2 * 0.022 + asymBoost * 0.012);
      final p = ringCenter + Offset(math.cos(a), math.sin(a)) * radial;
      final spotR = radius * (0.012 + h * 0.022) * (1 + prox * 0.25);
      final spotAlpha =
          (0.12 + h * 0.22 + prox * 0.18 + asymBoost * 0.15) * alpha;

      spotPaint.shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: spotAlpha.clamp(0.0, 0.55)),
          palette.ringHot.withValues(alpha: spotAlpha * 0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: p, radius: spotR));

      canvas.drawCircle(p, spotR, spotPaint);
    }

    // Limb brightening — approaching mass lights the near tangent of the photon sphere.
    if (prox > 0.03) {
      final brightCenter = ringCenter +
          Offset(
            math.cos(limbAngle) * radius * 0.05,
            math.sin(limbAngle) * radius * 0.05,
          );
      canvas.drawCircle(
        brightCenter,
        ringR * 1.028,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              palette.ringHot.withValues(alpha: prox * 0.14 * alpha),
              Colors.white.withValues(alpha: prox * 0.1 * alpha),
              Colors.transparent,
            ],
            stops: const [0.86, 0.925, 0.938, 0.96],
          ).createShader(
            Rect.fromCircle(center: brightCenter, radius: ringR * 1.028),
          ),
      );
    }
  }

  void _paintLensedRingStars(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
    double time,
    int cycles,
    double prox,
  ) {
    final ringR = radius * 0.932;
    final limbAngle = viewerAngle ?? 0.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 36; i++) {
      final h = _hash(i + 800);
      final h2 = _hash(i + 900);
      final a = i * (math.pi * 2 / 36) +
          loopAngle(time, cycles, 1, (h - 0.5) * 0.15);
      final approachSide = math.cos(a - limbAngle);
      final radialJitter = (h2 - 0.5) * radius * 0.014;
      final tidalShift = approachSide * prox * radius * 0.012;
      final p = center +
          Offset(math.cos(a), math.sin(a)) * (ringR + radialJitter + tidalShift);
      final mag = 0.25 + h * 0.65;

      paint.color = Color.lerp(
        const Color(0xFFD0E0F8),
        Colors.white,
        h,
      )!.withValues(
        alpha: (0.14 + h * 0.38 + prox * 0.22 + approachSide * prox * 0.12) *
            alpha,
      );
      canvas.drawCircle(p, mag, paint);

      if (h > 0.6 && prox > 0.08) {
        // Streak toward ring under tidal stress.
        final streakLen = radius * prox * (0.04 + h * 0.06);
        final streakEnd = p +
            Offset(math.cos(a + math.pi), math.sin(a + math.pi)) * streakLen;
        paint.shader = LinearGradient(
          colors: [
            paint.color,
            Colors.transparent,
          ],
        ).createShader(Rect.fromPoints(p, streakEnd));
        paint.strokeWidth = 0.4 + h * 0.5;
        paint.style = PaintingStyle.stroke;
        paint.strokeCap = StrokeCap.round;
        canvas.drawLine(p, streakEnd, paint);
        paint.style = PaintingStyle.fill;
        paint.shader = null;
      } else if (h > 0.55) {
        paint.color = Colors.white.withValues(alpha: (0.04 + h * 0.08) * alpha);
        canvas.drawCircle(p, mag * 2.4, paint);
      }
    }
  }

  void _paintGravitationalInflow(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double prox,
  ) {
    final limbAngle = viewerAngle ?? 0.0;
    final inflowDir = Offset(math.cos(limbAngle), math.sin(limbAngle));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 14; i++) {
      final h = _hash(i + 2000);
      final h2 = _hash(i + 2100);
      final lateral = (h - 0.5) * radius * 0.55;
      final perp = Offset(-inflowDir.dy, inflowDir.dx);
      final startDist = radius * (1.05 + h2 * 0.35);
      final start = center +
          inflowDir * startDist +
          perp * lateral;
      final endDist = radius * (0.78 + h * 0.12);
      final end = center + inflowDir * endDist + perp * lateral * 0.35;
      final streakAlpha = (0.06 + h * 0.14 + prox * 0.2) * alpha;

      paint.strokeWidth = 0.35 + h * 0.7;
      paint.shader = LinearGradient(
        colors: [
          palette.ringCool.withValues(alpha: streakAlpha * 0.4),
          palette.ringHot.withValues(alpha: streakAlpha),
          Colors.white.withValues(alpha: streakAlpha * 0.7),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromPoints(start, end));

      canvas.drawLine(start, end, paint);
    }

    // Accretion shimmer — disk brightens on the side facing the approaching mass.
    final shimmerCenter = center +
        Offset(
          math.cos(limbAngle) * radius * 0.08 * prox,
          math.sin(limbAngle) * radius * 0.08 * prox,
        );
    canvas.drawCircle(
      shimmerCenter,
      radius * (0.88 + prox * 0.04),
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.nebulaWarm.withValues(alpha: prox * 0.08 * alpha),
            palette.ringHot.withValues(alpha: prox * 0.05 * alpha),
            Colors.transparent,
          ],
          stops: const [0.7, 0.88, 1.0],
        ).createShader(
          Rect.fromCircle(center: shimmerCenter, radius: radius * 0.92),
        ),
    );
  }

  void _paintApproachLensing(
    Canvas canvas,
    Offset center,
    double radius,
    _WormholePalette palette,
    double alpha,
    double prox,
  ) {
    final limbAngle = viewerAngle ?? 0.0;
    final limbOffset = Offset(
      math.cos(limbAngle) * radius * 0.07 * prox,
      math.sin(limbAngle) * radius * 0.07 * prox,
    );

    // Einstein ring intensifies as external mass enters the lens field.
    canvas.drawCircle(
      center + limbOffset,
      radius * (0.935 + prox * 0.015),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            palette.ringCool.withValues(alpha: prox * 0.06 * alpha),
            Colors.white.withValues(alpha: prox * 0.08 * alpha),
            Colors.transparent,
          ],
          stops: const [0.88, 0.925, 0.938, 0.96],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Throat brightens — spacetime compression ahead of the infalling object.
    canvas.drawCircle(
      center,
      radius * (0.22 + prox * 0.06),
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.nebulaCore.withValues(alpha: prox * 0.18 * alpha),
            palette.nebulaWarm.withValues(alpha: prox * 0.08 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.32)),
    );

    // Weak-field distortion halo outside the photon sphere.
    canvas.drawCircle(
      center,
      radius * (1.02 + prox * 0.03),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            palette.ringCool.withValues(alpha: prox * 0.04 * alpha),
            Colors.transparent,
          ],
          stops: const [0.88, 0.94, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.06)),
    );
  }

  void _paintLockVeil(Canvas canvas, Offset center, double radius, double alpha) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.52 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant LobbyWormholePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary ||
        oldDelegate.locked != locked ||
        oldDelegate.bloom != bloom ||
        oldDelegate.richness != richness ||
        oldDelegate.ringCount != ringCount ||
        oldDelegate.time != time ||
        oldDelegate.approach != approach ||
        oldDelegate.viewerAngle != viewerAngle ||
        oldDelegate.hardcore != hardcore;
  }
}

class _WormholePalette {
  const _WormholePalette({
    required this.deep,
    required this.nebulaCool,
    required this.nebulaWarm,
    required this.nebulaCore,
    required this.ringHot,
    required this.ringCool,
  });

  final Color deep;
  final Color nebulaCool;
  final Color nebulaWarm;
  final Color nebulaCore;
  final Color ringHot;
  final Color ringCool;
}
