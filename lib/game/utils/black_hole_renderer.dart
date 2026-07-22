import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'canvas_effects.dart';
import 'gravity_visual.dart';
import 'black_hole_shader_renderer.dart';

/// Black-hole visuals scaled from Schwarzschild radius (r_s).
///
/// Physically inspired by EHT (M87*, Sgr A*) ray-traced models:
/// - gravitational shadow at ~(3√3/2) r_s ≈ 2.6 r_s (critical curve)
/// - photon ring — brightest feature on the shadow boundary
/// - thin accretion disk with relativistic Doppler beaming (no spiral arms)
/// - lensed Einstein arcs above/below the shadow
class BlackHoleRenderer {
  BlackHoleRenderer._();

  // r_s ∝ mass (Schwarzschild). Gameplay radius maps linearly; visual cap for readability.
  static const _rsGameScale = 0.34;
  static const _minSchwarzschildR = 12.0;
  static const _maxSchwarzschildR = 118.0;

  // Astrophysical ratios relative to r_s = 1 (Schwarzschild, EHT-consistent).
  // Shadow / photon-ring apparent radius: (3√3/2) r_s ≈ 2.598 r_s (critical curve).
  static const _shadowBoundaryRatio = 2.598;
  // Reference art: disk spans ~2.6× the shadow radius (6.8 / 2.598 ≈ 2.6).
  static const _accretionDiskRatio = 6.8;
  static const _minDiskToHorizonRatio = 1.35;
  static const _maxDiskR = 310.0;
  static const _lensingExtentRatio = 1.3;

  /// Event horizon (Schwarzschild radius) — the solid black center.
  static double visualCoreRadius(double gameRadius) {
    return (gameRadius * _rsGameScale).clamp(
      _minSchwarzschildR,
      _maxSchwarzschildR,
    );
  }

  /// Accretion disk outer edge — scales with r_s, keeps a readable ring outside the shadow.
  static double visualDiskRadius(double gameRadius) {
    final rs = visualCoreRadius(gameRadius);
    final proportional = rs * _accretionDiskRatio;
    final withMinGap = math.max(proportional, rs * _minDiskToHorizonRatio);
    return withMinGap.clamp(rs * _minDiskToHorizonRatio, _maxDiskR);
  }

  /// Black-hole shadow / photon-ring radius (EHT critical curve).
  static double shadowBoundaryRadius(double gameRadius) {
    return visualCoreRadius(gameRadius) * _shadowBoundaryRatio;
  }

  /// Outermost painted glow (weak-lensing band).
  ///
  /// Must fully contain every shader feature; when the r_s/disk clamps kick in
  /// on big holes the disk band (max(diskR, shadowR·1.45)·1.06) and the lensed
  /// halo (shadowR·1.55) outgrow the plain disk ratio — if the extent doesn't
  /// track them the quad's circular cutoff slices the glow into a hard rim.
  static double visualExtentRadius(double gameRadius) {
    final diskR = visualDiskRadius(gameRadius);
    final shadowR = shadowBoundaryRadius(gameRadius);
    final diskBandOuter = math.max(diskR, shadowR * 1.45) * 1.06;
    final haloOuter = shadowR * 1.55;
    final shaderReach = math.max(diskBandOuter, haloOuter) * 1.06;
    return math.max(diskR * _lensingExtentRatio, shaderReach);
  }

  /// Flame component box that fully contains [paint] (shader rect + Canvas FX).
  static double componentBoxSize(double gameRadius) {
    return math.max(gameRadius * 4.0, visualExtentRadius(gameRadius) * 2.25);
  }

  /// Distance-based LOD — compact for tiny bodies; highDetail refines alpha, not ring count.
  static ({bool highDetail, bool compact}) detailForRadius(
    double radius, {
    bool isLocal = false,
  }) {
    if (isLocal) {
      // Shader on mobile — keep full detail unless extremely zoomed out.
      if (CanvasEffects.isNativeMobile && radius >= 320) {
        return (highDetail: false, compact: false);
      }
      return (highDetail: true, compact: false);
    }
    if (radius < 14) {
      return (highDetail: false, compact: true);
    }
    if (radius >= 48) {
      return (highDetail: true, compact: false);
    }
    return (highDetail: false, compact: false);
  }

  static void paint({
    required Canvas canvas,
    required double radius,
    required double diskRotation,
    required String skin,
    Color? accentColor,
    bool isBoosting = false,
    bool isRadiating = false,
    double radiationPulse = 0,
    bool showShieldRing = false,
    double shieldPhase = 0,
    bool showLinkRing = false,
    bool highDetail = false,
    bool compact = false,
    bool isLocal = false,
    double gravityIntensity = 1.0,
    double swallowCharge = 0,
    double influxFlux = 0,
    double quasarActivation = 0,
    Object? shaderKey,
  }) {
    canvas.save();

    final rs = visualCoreRadius(radius);
    final diskR = visualDiskRadius(radius);
    final palette = plasmaPalette(skin: skin, accentColor: accentColor);
    final hot = palette.hot;
    final cool = palette.cool;
    final spin = diskRotation * (isBoosting ? 1.8 : 1.0);
    final boostMul = isBoosting ? 1.25 : 1.0;
    // Single intensity drives brightness — never adds extra ring layers.
    final intensity = gravityIntensity.clamp(0.55, 1.85);
    final activation = quasarActivation.clamp(0.0, 1.0);

    // Viewport planner may upgrade on-screen competitors to full ray-march.
    final plannedLod =
        shaderKey != null ? BlackHoleShaderRenderer.lodForKey(shaderKey) : -1;
    final effectiveHighDetail =
        highDetail || plannedLod >= 2 || (isLocal && !compact);

    if (compact && plannedLod <= 0) {
      _paintCompact(
        canvas: canvas,
        rs: rs,
        diskR: diskR,
        hot: hot,
        spin: spin,
      );
    } else {
      final lod = plannedLod >= 0
          ? plannedLod
          : BlackHoleShaderRenderer.lodFor(
              isLocal: isLocal,
              compact: compact,
              gameRadius: radius,
              highDetail: effectiveHighDetail,
            );
      final usedShader = BlackHoleShaderRenderer.shouldUse(
            isLocal: isLocal,
            compact: compact && plannedLod <= 0,
            gameRadius: radius,
            key: shaderKey,
          ) &&
          BlackHoleShaderRenderer.paint(
            canvas: canvas,
            gameRadius: radius,
            rs: rs,
            diskR: diskR,
            spin: spin,
            boostMul: boostMul,
            intensity: intensity,
            swallowCharge: swallowCharge,
            hot: hot,
            cool: cool,
            lod: lod,
            time: diskRotation,
            influxFlux: influxFlux,
            isLocal: isLocal,
            key: shaderKey,
          );

      if (!usedShader) {
        _paintFull(
          canvas: canvas,
          rs: rs,
          diskR: diskR,
          hot: hot,
          cool: cool,
          spin: spin,
          boostMul: boostMul,
          highDetail: effectiveHighDetail,
          intensity: intensity,
          swallowCharge: swallowCharge,
          influxFlux: influxFlux,
        );
      }

      if (swallowCharge > 0.05 && !compact) {
        _drawSwallowRimGlow(
          canvas: canvas,
          shadowR: rs * _shadowBoundaryRatio,
          rs: rs,
          hot: hot,
          spin: spin * 0.12,
          swallowCharge: swallowCharge,
          time: diskRotation,
        );
      }

      if (isRadiating) {
        final pulse = 0.85 + math.sin(radiationPulse * 5) * 0.15;
        final shadowR = rs * _shadowBoundaryRatio;
        final radR = shadowR * 1.08 * pulse;
        canvas.drawCircle(
          Offset.zero,
          radR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = hot[0].withValues(alpha: 0.4),
        );
      }
    }

    if (activation > 0.02) {
      _drawQuasarActivationFlare(
        canvas: canvas,
        diskR: diskR,
        rs: rs,
        hot: hot,
        activation: activation,
      );
    }

    if (isBoosting && !compact) {
      _drawBoostHalo(canvas, diskR, hot);
    }

    if (showLinkRing) {
      _drawLinkRing(canvas, diskR);
    }
    if (showShieldRing) {
      _drawShieldRing(canvas, diskR, shieldPhase);
    }

    canvas.restore();
  }

  // Disk inclination — vertical squash of the disk plane (reference art ≈ 1:3).
  static const _diskTilt = 0.34;

  static void _paintCompact({
    required Canvas canvas,
    required double rs,
    required double diskR,
    required List<Color> hot,
    required double spin,
  }) {
    final shadowR = rs * _shadowBoundaryRatio;
    final clipBox = math.max(diskR, shadowR) * 2.2;

    // Back half of the tilted disk — hidden behind the shadow.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-clipBox, -clipBox, clipBox, 0));
    canvas.save();
    canvas.scale(1.0, _diskTilt);
    canvas.drawOval(
      Rect.fromCircle(center: Offset.zero, radius: diskR),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.2, diskR - rs * 1.85)
        ..color = hot[1].withValues(alpha: 0.7),
    );
    canvas.restore();
    canvas.restore();

    // Gravitational shadow — filled void (no hollow center).
    _drawShadowVoid(canvas: canvas, shadowR: shadowR);

    // Photon ring at shadow boundary — thin white-hot rim.
    canvas.drawCircle(
      Offset.zero,
      shadowR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, rs * 0.06)
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9),
            hot[0].withValues(alpha: 0.8),
            hot[0].withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: shadowR)),
    );

    // Front half of the disk — passes in front of the shadow.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-clipBox, 0, clipBox, clipBox));
    canvas.save();
    canvas.scale(1.0, _diskTilt);
    canvas.drawOval(
      Rect.fromCircle(center: Offset.zero, radius: diskR),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.2, diskR - rs * 1.85)
        ..color = hot[0].withValues(alpha: 0.8),
    );
    canvas.restore();
    canvas.restore();

    // Tiny polar jets — keep the quasar silhouette readable when zoomed out.
    _drawPolarJets(
      canvas: canvas,
      rs: rs,
      shadowR: shadowR,
      extent: diskR * 1.5,
      strength: 0.4,
      time: spin,
    );
  }

  static void _paintFull({
    required Canvas canvas,
    required double rs,
    required double diskR,
    required List<Color> hot,
    required List<Color> cool,
    required double spin,
    required double boostMul,
    required bool highDetail,
    required double intensity,
    double swallowCharge = 0,
    double influxFlux = 0,
  }) {
    final detailMul = highDetail ? 1.12 : 1.0;
    final shadowR = rs * _shadowBoundaryRatio;
    final diskSpin = spin * 0.12;
    final clipBox = math.max(diskR, shadowR * 1.8) * 2.2;
    final feed = (swallowCharge + influxFlux).clamp(0.0, 1.0);

    if (influxFlux > 0.08) {
      GravityVisual.drawInfallStreamlines(
        canvas: canvas,
        diskR: diskR,
        coreR: rs,
        hot: hot,
        spin: diskSpin + influxFlux * 0.35,
        intensity: (intensity * 0.55 + influxFlux * 0.85).clamp(0.15, 1.85),
      );
    }

    // 1) Full tilted disk — the shadow will punch out the part behind the hole.
    _drawTiltedDiskHalf(
      canvas: canvas,
      rs: rs,
      diskR: diskR,
      hot: hot,
      spin: diskSpin,
      alphaMul: (0.94 + feed * 0.2) * boostMul * detailMul,
      intensity: intensity,
      highDetail: highDetail,
    );

    // 2) Lensed halo — far-side disk image bent over the top of the shadow
    //    (and a faint echo under it), the reference art's vertical glow.
    _drawLensedHalo(
      canvas: canvas,
      rs: rs,
      shadowR: shadowR,
      hot: hot,
      intensity: intensity * detailMul,
      boostMul: boostMul,
    );

    // 3) Gravitational shadow — pure black void.
    _drawShadowVoid(canvas: canvas, shadowR: shadowR);

    // 4) Photon ring — thin white-hot rim hugging the shadow.
    _drawPhotonRing(
      canvas: canvas,
      shadowR: shadowR,
      rs: rs,
      hot: hot,
      spin: diskSpin,
      intensity: intensity * detailMul,
      boostMul: boostMul,
      swallowCharge: swallowCharge,
    );

    // 5) Front band of the disk — the near side of the annulus passes in
    //    front of the shadow's lower half (redraw clipped to the shadow).
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(-shadowR * 1.05, 0, shadowR * 1.05, clipBox),
    );
    _drawTiltedDiskHalf(
      canvas: canvas,
      rs: rs,
      diskR: diskR,
      hot: hot,
      spin: diskSpin,
      alphaMul: (1.0 + feed * 0.2) * boostMul * detailMul,
      intensity: intensity,
      highDetail: highDetail,
    );
    canvas.restore();

    // 6) Twin relativistic jets — blue-white polar beams (always-on quasar).
    _drawPolarJets(
      canvas: canvas,
      rs: rs,
      shadowR: shadowR,
      extent: diskR * _lensingExtentRatio,
      strength: (0.5 + feed * 0.6 + (boostMul - 1.0) * 0.9)
          .clamp(0.35, 1.25) *
          intensity.clamp(0.6, 1.4),
      time: spin,
    );
  }

  /// One tilted-disk pass: layered ovals + turbulent filament streaks in the
  /// squashed disk frame (call inside a top/bottom clip for front/back split).
  static void _drawTiltedDiskHalf({
    required Canvas canvas,
    required double rs,
    required double diskR,
    required List<Color> hot,
    required double spin,
    required double alphaMul,
    required double intensity,
    required bool highDetail,
  }) {
    // Inner rim hugs the photon ring so the disk stays visible around the
    // shadow (reference art), instead of hiding behind it.
    final innerR = rs * _shadowBoundaryRatio * 0.98;
    final outerR = math.max(diskR, innerR * 1.5);

    canvas.save();
    canvas.scale(1.0, _diskTilt);

    // Radial temperature bands: white-hot inner rim → amber → deep ember.
    final bands = <(double, double, Color, double)>[
      // (rFrac inner→outer, widthFrac, color, alpha)
      (0.0, 0.30, Colors.white, 0.95),
      (0.16, 0.36, hot[0], 0.9),
      (0.42, 0.42, hot[1], 0.72),
      (0.74, 0.4, hot[2], 0.5),
    ];
    final span = outerR - innerR;
    for (final (pos, width, color, a) in bands) {
      final midR = innerR + span * (pos + width * 0.5);
      canvas.drawOval(
        Rect.fromCircle(center: Offset.zero, radius: midR),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = span * width
          ..color = color.withValues(
            alpha: (a * alphaMul * intensity.clamp(0.6, 1.3)).clamp(0.0, 1.0),
          )
          ..maskFilter = CanvasEffects.blurEnabled
              ? ui.MaskFilter.blur(ui.BlurStyle.normal, span * width * 0.34)
              : null,
      );
    }

    // Doppler beaming — approaching side hotter/brighter, receding dimmer.
    // Stroked annulus so the modulation never spills into the inner hole.
    final diskRect = Rect.fromCircle(center: Offset.zero, radius: outerR);
    canvas.drawOval(
      Rect.fromCircle(center: Offset.zero, radius: innerR + span * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = span
        ..shader = SweepGradient(
          transform: GradientRotation(spin * 0.3),
          colors: [
            Colors.white.withValues(alpha: 0.30 * alphaMul),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.30 * alphaMul),
          ],
          stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
        ).createShader(diskRect),
    );

    // Turbulent filaments — trailing plasma streaks orbiting the hole.
    final streaks = highDetail ? 9 : 6;
    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < streaks; i++) {
      final t = i / streaks;
      final r0 = innerR + span * (0.08 + 0.84 * ((i * 0.618) % 1.0));
      final baseA = spin * (1.6 - t * 0.7) + t * math.pi * 2 * 3.7;
      final arcLen = math.pi * (0.5 + 0.4 * ((i * 0.37) % 1.0));
      final heat = 1.0 - (r0 - innerR) / span;
      streakPaint
        ..strokeWidth = math.max(1.2, span * (0.05 + heat * 0.06))
        ..color = Color.lerp(hot[2], Colors.white, heat * heat)!
            .withValues(alpha: (0.4 + heat * 0.35) * alphaMul.clamp(0.0, 1.0));
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r0),
        baseA,
        arcLen,
        false,
        streakPaint,
      );
    }

    canvas.restore();

    // Outer fringes — hot matter flung off the disk edge.
    if (highDetail) {
      canvas.save();
      canvas.scale(1.0, _diskTilt);
      final fringePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final a0 = spin * 0.9 + i * math.pi * 0.5 + 0.4;
        fringePaint
          ..strokeWidth = math.max(1.0, span * 0.035)
          ..color = hot[1].withValues(alpha: 0.30 * alphaMul.clamp(0.0, 1.0));
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: outerR * (1.02 + i * 0.025)),
          a0,
          math.pi * 0.34,
          false,
          fringePaint,
        );
      }
      canvas.restore();
    }
  }

  /// Far-side disk image lensed over/under the shadow — the vertical glow arc
  /// wrapping the black sphere in the reference art (Gargantua-style halo).
  static void _drawLensedHalo({
    required Canvas canvas,
    required double rs,
    required double shadowR,
    required List<Color> hot,
    required double intensity,
    required double boostMul,
  }) {
    final haloInner = shadowR * 1.02;
    final haloOuter = shadowR * 1.55;
    final mul = (0.75 + intensity * 0.45) * boostMul;

    // Top arc — dominant lensed image of the far disk.
    final topRect = Rect.fromCircle(
      center: Offset.zero,
      radius: (haloInner + haloOuter) * 0.5,
    );
    canvas.drawArc(
      topRect,
      math.pi + 0.35,
      math.pi - 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = haloOuter - haloInner
        ..strokeCap = StrokeCap.round
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.5 * mul),
            hot[0].withValues(alpha: 0.55 * mul),
            hot[1].withValues(alpha: 0.30 * mul),
            Colors.transparent,
          ],
          stops: const [0.56, 0.68, 0.82, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: haloOuter))
        ..maskFilter = CanvasEffects.blurEnabled
            ? ui.MaskFilter.blur(ui.BlurStyle.normal, rs * 0.16)
            : null,
    );

    // Bottom arc — fainter mirrored echo.
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: shadowR * 1.14),
      0.5,
      math.pi - 1.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rs * 0.34
        ..strokeCap = StrokeCap.round
        ..color = hot[0].withValues(alpha: 0.28 * mul)
        ..maskFilter = CanvasEffects.blurEnabled
            ? ui.MaskFilter.blur(ui.BlurStyle.normal, rs * 0.12)
            : null,
    );
  }

  /// Twin relativistic jets — vertical blue-white beams from both poles
  /// (reference Stage 4: activated quasar).
  static void _drawPolarJets({
    required Canvas canvas,
    required double rs,
    required double shadowR,
    required double extent,
    required double strength,
    required double time,
  }) {
    final s = strength.clamp(0.0, 1.4);
    if (s < 0.05) return;

    final jetLen = extent * (0.68 + s * 0.22);
    final baseW = math.max(rs * 0.26, 1.8) * (0.8 + s * 0.35);
    const jetBlue = Color(0xFF7FC4FF);
    const jetViolet = Color(0xFFB08CFF);

    for (final dir in const [-1.0, 1.0]) {
      // Beam emerges at the pole — never crosses the event horizon.
      final startY = shadowR * 0.88 * dir;
      final endY = jetLen * dir;
      final rect = Rect.fromLTRB(
        -baseW * 1.9,
        math.min(startY, endY),
        baseW * 1.9,
        math.max(startY, endY),
      );

      // Glow sheath — tapers off quickly along the beam.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: dir < 0 ? Alignment.bottomCenter : Alignment.topCenter,
            end: dir < 0 ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [
              jetBlue.withValues(alpha: 0.30 * s),
              jetViolet.withValues(alpha: 0.10 * s),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 0.9],
          ).createShader(rect)
          ..maskFilter = CanvasEffects.blurEnabled
              ? ui.MaskFilter.blur(ui.BlurStyle.normal, baseW * 0.9)
              : null
          ..blendMode = BlendMode.plus,
      );

      // Bright collimated core with flowing plasma knots.
      final coreRect = Rect.fromLTRB(
        -baseW * 0.55,
        math.min(startY, endY),
        baseW * 0.55,
        math.max(startY, endY),
      );
      canvas.drawRect(
        coreRect,
        Paint()
          ..shader = LinearGradient(
            begin: dir < 0 ? Alignment.bottomCenter : Alignment.topCenter,
            end: dir < 0 ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.85 * s.clamp(0.0, 1.0)),
              jetBlue.withValues(alpha: 0.5 * s),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(coreRect)
          ..blendMode = BlendMode.plus,
      );

      // Plasma knots streaming outward.
      for (var k = 0; k < 3; k++) {
        final phase = ((time * 0.6 + k / 3) % 1.0);
        final y = startY + (endY - startY) * phase;
        final kr = baseW * (0.5 - phase * 0.22);
        if (kr < 0.6) continue;
        canvas.drawCircle(
          Offset(0, y),
          kr,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4 * s * (1 - phase))
            ..blendMode = BlendMode.plus,
        );
      }
    }
  }

  /// EHT gravitational shadow — uniform void inside critical curve, soft rim only.
  static void _drawShadowVoid({
    required Canvas canvas,
    required double shadowR,
  }) {
    canvas.drawCircle(
      Offset.zero,
      shadowR,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0xF0000000),
            Color(0xC0000000),
            Color(0x00000000),
          ],
          stops: const [0.0, 0.72, 0.88, 0.94, 0.98, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: shadowR)),
    );
  }

  /// Stage-4 "Quasar Activation" — disk briefly flares and expands after a
  /// large swallow, matching the reference art's sudden brightening.
  static void _drawQuasarActivationFlare({
    required Canvas canvas,
    required double diskR,
    required double rs,
    required List<Color> hot,
    required double activation,
  }) {
    final flareR = diskR * (1.1 + activation * 0.6);
    canvas.drawCircle(
      Offset.zero,
      flareR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85 * activation),
            hot[0].withValues(alpha: 0.55 * activation),
            hot[1].withValues(alpha: 0.22 * activation),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.68, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: flareR))
        ..blendMode = BlendMode.plus,
    );

    canvas.drawCircle(
      Offset.zero,
      rs * (2.2 + activation * 1.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, rs * 0.1) * activation
        ..color = Colors.white.withValues(alpha: 0.55 * activation)
        ..blendMode = BlendMode.plus,
    );
  }

  /// Bright photon ring on the shadow critical curve — Doppler-asymmetric (EHT).
  static void _drawPhotonRing({
    required Canvas canvas,
    required double shadowR,
    required double rs,
    required List<Color> hot,
    required double spin,
    required double intensity,
    required double boostMul,
    double swallowCharge = 0,
  }) {
    final hunt = swallowCharge.clamp(0.0, 1.0);
    final ringAlpha = (0.48 + intensity * 0.52 + hunt * 0.28).clamp(0.48, 1.0);
    final coreStroke = math.max(1.1, rs * 0.048) * (0.92 + intensity * 0.28 + hunt * 0.18);
    final haloStroke = math.max(2.2, rs * 0.11) * (0.85 + intensity * 0.2);

    canvas.save();
    canvas.rotate(spin);

    // Soft outer halo — wider photon-band glow.
    canvas.drawCircle(
      Offset.zero,
      shadowR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = haloStroke
        ..shader = SweepGradient(
          colors: [
            hot[0].withValues(alpha: ringAlpha * 0.22 * boostMul),
            hot[1].withValues(alpha: ringAlpha * 0.1),
            hot[2].withValues(alpha: ringAlpha * 0.05),
            hot[0].withValues(alpha: ringAlpha * 0.16 * boostMul),
            hot[0].withValues(alpha: ringAlpha * 0.2 * boostMul),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: shadowR)),
    );

    // Sharp core ring — approaching side brightest (relativistic beaming).
    canvas.drawCircle(
      Offset.zero,
      shadowR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = coreStroke
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: ringAlpha * 0.95 * boostMul),
            hot[0].withValues(alpha: ringAlpha * 0.98 * boostMul),
            hot[1].withValues(alpha: ringAlpha * 0.42),
            hot[2].withValues(alpha: ringAlpha * 0.16),
            hot[1].withValues(alpha: ringAlpha * 0.32),
            hot[0].withValues(alpha: ringAlpha * 0.72 * boostMul),
            Color.lerp(
              hot[0],
              const Color(0xFFFFEEAA),
              hunt * 0.75,
            )!.withValues(alpha: ringAlpha * 0.88 * boostMul),
            Colors.white.withValues(alpha: ringAlpha * boostMul),
          ],
          stops: const [0.0, 0.08, 0.3, 0.48, 0.66, 0.8, 0.92, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: shadowR)),
    );

    // Inner rim accent on shadow edge.
    canvas.drawCircle(
      Offset.zero,
      shadowR * 0.975,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = coreStroke * 0.28
        ..color = hot[0].withValues(alpha: ringAlpha * 0.14),
    );
    canvas.restore();
  }

  /// Pulsing coronal glow on the shadow rim during swallow / hunt charge.
  static void _drawSwallowRimGlow({
    required Canvas canvas,
    required double shadowR,
    required double rs,
    required List<Color> hot,
    required double spin,
    required double swallowCharge,
    required double time,
  }) {
    final hunt = swallowCharge.clamp(0.0, 1.0);
    if (hunt < 0.05) return;

    final pulse = 0.52 + 0.48 * math.sin(time * 6.2 + hunt * 3.1);
    final alpha = ((0.2 + hunt * 0.58) * pulse).clamp(0.0, 0.95);
    final rimColor = Color.lerp(hot[0], const Color(0xFFFFEEAA), hunt * 0.68)!;

    canvas.drawCircle(
      Offset.zero,
      shadowR * 0.99,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, rs * 0.085) * (0.85 + hunt * 0.55)
        ..color = rimColor.withValues(alpha: alpha)
        ..maskFilter = CanvasEffects.blurEnabled
            ? ui.MaskFilter.blur(ui.BlurStyle.normal, rs * 0.07)
            : null
        ..blendMode = BlendMode.plus,
    );

    canvas.save();
    canvas.rotate(spin);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: shadowR),
      -0.35,
      0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, rs * 0.065)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: alpha * 0.75 * hunt)
        ..blendMode = BlendMode.plus,
    );
    canvas.restore();

    // Outer swallow halo outside photon band.
    canvas.drawCircle(
      Offset.zero,
      shadowR * 1.12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, rs * 0.05)
        ..color = hot[1].withValues(alpha: alpha * 0.35 * hunt)
        ..blendMode = BlendMode.plus,
    );
  }

  static void _drawBoostHalo(
    Canvas canvas,
    double diskR,
    List<Color> hot,
  ) {
    final r = diskR * 1.08;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = hot[0].withValues(alpha: 0.5),
    );
  }

  /// Distinct disk colors derived from a bot accent hue.
  /// Skin-driven hot/cool palette — passed to the GPU shader as uniform colors.
  static ({List<Color> hot, List<Color> cool}) plasmaPalette({
    required String skin,
    Color? accentColor,
  }) {
    if (accentColor != null) {
      return (
        hot: _paletteFromAccent(accentColor, hot: true),
        cool: _paletteFromAccent(accentColor, hot: false),
      );
    }
    return (hot: _palette(skin, hot: true), cool: _palette(skin, hot: false));
  }

  static List<Color> _paletteFromAccent(Color accent, {required bool hot}) {
    final hsl = HSLColor.fromColor(accent);
    if (hot) {
      return [
        hsl.withLightness(0.88).withSaturation(0.55).toColor(),
        hsl.withLightness(0.58).withSaturation(0.85).toColor(),
        hsl.withLightness(0.32).withSaturation(0.9).toColor(),
      ];
    }
    return [
      hsl.withLightness(0.22).withSaturation(0.45).toColor(),
      hsl.withLightness(0.12).withSaturation(0.4).toColor(),
      hsl.withLightness(0.06).withSaturation(0.35).toColor(),
    ];
  }

  static List<Color> _palette(String skin, {required bool hot}) {
    switch (skin) {
      case 'pulsar':
        return hot
            ? [
                const Color(0xFFAAEEFF),
                const Color(0xFF00CCFF),
                const Color(0xFF0066AA),
              ]
            : [
                const Color(0xFF224466),
                const Color(0xFF112233),
                const Color(0xFF0A1520),
              ];
      case 'supernova':
        return hot
            ? [
                const Color(0xFFFFEEAA),
                const Color(0xFFFF8800),
                const Color(0xFFCC3300),
              ]
            : [
                const Color(0xFF664422),
                const Color(0xFF332211),
                const Color(0xFF1A1008),
              ];
      case 'plasma':
        return hot
            ? [
                const Color(0xFFFFAAFF),
                const Color(0xFFCC44FF),
                const Color(0xFF8800CC),
              ]
            : [
                const Color(0xFF442266),
                const Color(0xFF221133),
                const Color(0xFF110818),
              ];
      case 'nebula':
        return hot
            ? [
                const Color(0xFFEEAAFF),
                const Color(0xFFAA44FF),
                const Color(0xFF6622AA),
              ]
            : [
                const Color(0xFF442266),
                const Color(0xFF221144),
                const Color(0xFF110822),
              ];
      case 'void':
        return hot
            ? [
                const Color(0xFF9988FF),
                const Color(0xFF5533AA),
                const Color(0xFF221144),
              ]
            : [
                const Color(0xFF221133),
                const Color(0xFF110822),
                const Color(0xFF080412),
              ];
      case 'quasar':
        return hot
            ? [
                const Color(0xFFAAFFEE),
                const Color(0xFF00FF88),
                const Color(0xFF008855),
              ]
            : [
                const Color(0xFF224433),
                const Color(0xFF112218),
                const Color(0xFF081008),
              ];
      case 'eclipse':
        return hot
            ? [
                const Color(0xFFFFF4AA),
                const Color(0xFFFFD700),
                const Color(0xFFAA7700),
              ]
            : [
                const Color(0xFF443300),
                const Color(0xFF221800),
                const Color(0xFF110C00),
              ];
      case 'aurora':
        return hot
            ? [
                const Color(0xFFAAFFEE),
                const Color(0xFF44FFCC),
                const Color(0xFF4488FF),
              ]
            : [
                const Color(0xFF224466),
                const Color(0xFF112233),
                const Color(0xFF081018),
              ];
      case 'binary':
        return hot
            ? [
                const Color(0xFFFFCC88),
                const Color(0xFFFF6600),
                const Color(0xFF0088FF),
              ]
            : [
                const Color(0xFF442211),
                const Color(0xFF112244),
                const Color(0xFF0A0810),
              ];
      case 'frost':
        return hot
            ? [
                const Color(0xFFE8F4FF),
                const Color(0xFF88CCFF),
                const Color(0xFF3366AA),
              ]
            : [
                const Color(0xFF1A2838),
                const Color(0xFF0E1520),
                const Color(0xFF080C12),
              ];
      case 'ember':
        return hot
            ? [
                const Color(0xFFFFF0E8),
                const Color(0xFFFF5522),
                const Color(0xFFCC2818),
              ]
            : [
                const Color(0xFF3D1410),
                const Color(0xFF1E0A08),
                const Color(0xFF0A0404),
              ];
      case 'singularity':
        return hot
            ? [
                const Color(0xFFF0F4FF),
                const Color(0xFF98A8C8),
                const Color(0xFF485878),
              ]
            : [
                const Color(0xFF0C0C14),
                const Color(0xFF060608),
                const Color(0xFF030304),
              ];
      case 'celestial':
        return hot
            ? [
                const Color(0xFFFFFAF0),
                const Color(0xFFF0D890),
                const Color(0xFFC8A048),
              ]
            : [
                const Color(0xFF282014),
                const Color(0xFF141008),
                const Color(0xFF0A0806),
              ];
      default:
        return hot
            ? [
                const Color(0xFFFFF4D8),
                const Color(0xFFFFAA33),
                const Color(0xFFFF5500),
              ]
            : [
                const Color(0xFF553300),
                const Color(0xFF2A1800),
                const Color(0xFF140C00),
              ];
    }
  }

  static void _drawShieldRing(Canvas canvas, double diskR, double phase) {
    final pulse = 0.9 + math.sin(phase * 6) * 0.1;
    final shieldR = diskR * 1.38 * pulse;
    canvas.drawCircle(
      Offset.zero,
      shieldR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.75),
    );
  }

  static void _drawLinkRing(Canvas canvas, double diskR) {
    canvas.drawCircle(
      Offset.zero,
      diskR * 1.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFF00AA).withValues(alpha: 0.6),
    );
  }
}
