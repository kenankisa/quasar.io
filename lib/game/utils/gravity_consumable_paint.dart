import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'canvas_effects.dart';
import 'gravity_scaling.dart';
import 'tidal_deform_state.dart';

/// Consumable tidal paint / spaghettification helpers.
class GravityConsumablePaint {
  GravityConsumablePaint._();

  static const _streakColors = [
    Color(0xFFFFE8CC),
    Color(0xFFFFAA66),
    Color(0xFFFF6633),
  ];

  /// Normalized tidal stress for consumables (Roche-based, physics / spin).
  static double consumableTidalIntensity({
    required double sourceRadius,
    required double entityRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) {
    return GravityScaling.consumableTidalIntensity(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
  }

  /// Tidal stress for spaghettification VFX only (shorter range when holes grow).
  static double consumableTidalVisualIntensity({
    required double sourceRadius,
    required double entityRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) {
    return GravityScaling.consumableTidalVisualIntensity(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
  }

  static final _smoothedTidalAxes = <int, double>{};

  // Per-frame budget for planet→hole mass-transfer streams (Stage 2-3 VFX).
  // animationPhase (matchElapsed) is identical for every entity in a frame,
  // so it doubles as a cheap frame stamp without extra game coupling.
  static double _streamFrameStamp = -1;
  static int _streamsThisFrame = 0;

  static bool _acquireStreamBudget(double frameStamp) {
    if (frameStamp != _streamFrameStamp) {
      _streamFrameStamp = frameStamp;
      _streamsThisFrame = 0;
    }
    final cap = CanvasEffects.mobileLiteMode ? 3 : 6;
    if (_streamsThisFrame >= cap) return false;
    _streamsThisFrame++;
    return true;
  }

  /// Self-spin retention under tidal stress (0 = fully locked to the infall axis).
  static double tidalSpinRetain(double intensity) {
    if (intensity <= 0) return 1.0;
    return math.pow(1.0 - intensity.clamp(0.0, 1.0), 2.5).toDouble();
  }

  /// Whether tidal locking should freeze self-rotation accumulation.
  static bool shouldFreezeSpin(double intensity) =>
      intensity >= GravityScaling.consumableTidalOnsetIntensity;

  /// Screen radius (px) below which tidal VFX are skipped (default case).
  static const consumableTidalMinScreenPx = 3.5;

  /// Streak / fragment LOD: no tail below this on-screen radius.
  static const consumableStreakLodMinScreenPx = 4.0;

  /// Streak / fragment LOD: full tail at and above this on-screen radius.
  static const consumableStreakLodFullScreenPx = 9.0;

  /// World radius → on-screen radius in logical pixels (Flame viewfinder zoom).
  static double consumableScreenRadiusPx(double worldRadius, double cameraZoom) {
    if (cameraZoom <= 0 || worldRadius <= 0) return 0;
    return worldRadius * cameraZoom;
  }

  /// Minimum on-screen radius before drawing any tidal VFX.
  ///
  /// Stronger tidal stress keeps spaghettification on small collectibles so
  /// every food type behaves consistently near a hole.
  static double consumableTidalMinScreenForIntensity(double tidalIntensity) {
    if (tidalIntensity >= 0.75) return 2.0;
    if (tidalIntensity >= 0.55) return 2.8;
    if (tidalIntensity >= 0.45) return 3.0;
    return consumableTidalMinScreenPx;
  }

  /// Scales infall streak + debris (0 = no tail, 1 = full tail).
  ///
  /// Body stretch always follows physics; this only gates the long noodle tail.
  /// High tidal intensity guarantees a visible tail on small on-screen dots.
  static double consumableStreakLodFromScreen(
    double entityScreenRadiusPx, {
    double tidalIntensity = 0,
  }) {
    var lod = 0.0;
    if (entityScreenRadiusPx > consumableStreakLodMinScreenPx) {
      if (entityScreenRadiusPx >= consumableStreakLodFullScreenPx) {
        lod = 1.0;
      } else {
        lod = (entityScreenRadiusPx - consumableStreakLodMinScreenPx) /
            (consumableStreakLodFullScreenPx - consumableStreakLodMinScreenPx);
      }
    }

    if (tidalIntensity >= 0.65) lod = math.max(lod, 0.35);
    if (tidalIntensity >= 0.8) lod = math.max(lod, 0.55);

    return lod.clamp(0.0, 1.0);
  }

  /// Exponential decay applied to stored spin while tidally locked.
  static double decayLockedSpin(double spin, double dt) =>
      spin * math.pow(0.86, dt * 60);

  static void clearTidalAxis(int axisKey) => _smoothedTidalAxes.remove(axisKey);

  /// Smooth tidal-axis tracking — avoids jitter when the predator moves.
  static double smoothedTidalAngle({
    required int axisKey,
    required double targetAngle,
    required double intensity,
  }) {
    final prev = _smoothedTidalAxes[axisKey];
    if (prev == null) {
      _smoothedTidalAxes[axisKey] = targetAngle;
      return targetAngle;
    }

    var delta = targetAngle - prev;
    while (delta > math.pi) {
      delta -= math.pi * 2;
    }
    while (delta < -math.pi) {
      delta += math.pi * 2;
    }

    // Stronger lock at higher tidal stress.
    final blend = (0.06 + intensity * 0.42).clamp(0.06, 0.55);
    final smoothed = prev + delta * blend;
    _smoothedTidalAxes[axisKey] = smoothed;
    return smoothed;
  }

  /// Compute tidal deformation for a consumable pulled toward a black hole.
  static TidalDeformState? tidalDeformForConsumable({
    required Vector2 entityWorldPosition,
    required Vector2 sourceWorldPosition,
    required double sourceRadius,
    required double entityRadius,
    double roomMultiplier = 1.0,
  }) {
    final delta = sourceWorldPosition - entityWorldPosition;
    final distance = delta.length;
    final intensity = consumableTidalVisualIntensity(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
    if (intensity < GravityScaling.consumableTidalVisualOnsetIntensity) {
      return null;
    }

    // Spaghettification: Δa ∝ 1/r³ → stretch grows sharply inside Roche radius.
    final tidal = intensity * intensity * (0.5 + intensity * 0.65);
    final stretch = 1.0 + tidal * 1.35;
    final transverseScale = 1.0 / math.sqrt(stretch);

    // Mass shedding into the radial infall stream (tidal stripping).
    final visualScale = (1.0 - intensity * 0.52).clamp(0.12, 1.0);

    // Fragmentation past Roche; full disintegration near photon sphere.
    final fragmentLevel = ((intensity - 0.55) / 0.55).clamp(0.0, 1.0);
    final disintegrationLevel = ((intensity - 0.95) / 0.4).clamp(0.0, 1.0);

    return TidalDeformState(
      intensity: intensity.clamp(0.0, 1.0),
      angle: math.atan2(delta.y, delta.x),
      stretch: stretch,
      transverseScale: transverseScale,
      visualScale: visualScale,
      fragmentLevel: fragmentLevel,
      disintegrationLevel: disintegrationLevel,
    );
  }

  /// Paint a consumable body with scientifically-inspired tidal deformation.
  ///
  /// The body stretches toward the hole, compresses perpendicular to the tidal
  /// axis, sheds visual mass, and fragments along the infall stream.
  static void paintConsumableWithTides({
    required Canvas canvas,
    required Vector2 entityWorldPosition,
    required Vector2 sourceWorldPosition,
    required double sourceRadius,
    required double entityRadius,
    required Color accent,
    required Color bodyColor,
    double roomMultiplier = 1.0,
    double spinAngle = 0,
    int? tidalAxisKey,
    double cameraZoom = 1.0,
    double animationPhase = 0,
    required void Function(Canvas canvas, double visualRadius) paintBody,
  }) {
    final axisKey = tidalAxisKey;
    final tidal = tidalDeformForConsumable(
      entityWorldPosition: entityWorldPosition,
      sourceWorldPosition: sourceWorldPosition,
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      roomMultiplier: roomMultiplier,
    );

    if (tidal == null) {
      if (axisKey != null) clearTidalAxis(axisKey);
      canvas.save();
      canvas.rotate(spinAngle);
      paintBody(canvas, entityRadius);
      canvas.restore();
      return;
    }

    final screenR = consumableScreenRadiusPx(entityRadius, cameraZoom);
    final minScreenPx = consumableTidalMinScreenForIntensity(tidal.intensity);
    if (screenR < minScreenPx) {
      if (axisKey != null) clearTidalAxis(axisKey);
      canvas.save();
      canvas.rotate(spinAngle);
      paintBody(canvas, entityRadius);
      canvas.restore();
      return;
    }

    final streakLod = consumableStreakLodFromScreen(
      screenR,
      tidalIntensity: tidal.intensity,
    );
    final visualRadius = entityRadius * tidal.visualScale;
    final axis = axisKey == null
        ? tidal.angle
        : smoothedTidalAngle(
            axisKey: axisKey,
            targetAngle: tidal.angle,
            intensity: tidal.intensity,
          );
    final spinRetain = tidalSpinRetain(tidal.intensity);

    // Stage 2-3 (reference art): Roche-lobe overflow feeding a luminous
    // mass-transfer stream that bridges the body to the hole's photon ring.
    final distanceToHole = (sourceWorldPosition - entityWorldPosition).length;
    final holePhotonR = sourceRadius *
        GravityScaling.schwarzschildFraction *
        GravityScaling.shadowBoundaryRatio;
    final streamStrength = ((tidal.intensity - 0.42) / 0.58).clamp(0.0, 1.0);
    final drawStream = streamStrength > 0.02 &&
        streakLod > 0.25 &&
        _acquireStreamBudget(animationPhase);

    canvas.save();
    canvas.rotate(axis);

    // Stream is painted in the rotated (unscaled) frame so its geometry
    // matches true world distance to the predator hole.
    if (drawStream) {
      _drawMassTransferStream(
        canvas: canvas,
        entityRadius: visualRadius,
        tidal: tidal,
        distanceToHole: distanceToHole,
        holePhotonR: holePhotonR,
        bodyColor: bodyColor,
        strength: streamStrength,
        lod: streakLod,
        animationPhase: animationPhase,
      );
    }

    canvas.save();
    canvas.scale(tidal.stretch, tidal.transverseScale);

    // Tidal locking — self-spin fades as the body aligns with the infall axis.
    canvas.rotate(spinAngle * spinRetain);

    paintBody(canvas, visualRadius);

    if (drawStream) {
      _drawRocheOverflowFace(
        canvas: canvas,
        entityRadius: visualRadius,
        strength: streamStrength,
        bodyColor: bodyColor,
        lod: streakLod,
      );
    }

    // Once matter transfers forward into the stream, the trailing tail thins.
    final trailingLod = streakLod * (1.0 - streamStrength * 0.55);

    if (trailingLod > 0 && tidal.intensity > 0.35) {
      _drawGravitationalRedshift(canvas, visualRadius, tidal, lod: trailingLod);
    }

    if (trailingLod > 0.35 && tidal.fragmentLevel > 0.06) {
      _drawTidalFragments(
        canvas: canvas,
        entityRadius: visualRadius,
        tidal: tidal,
        accent: accent,
        bodyColor: bodyColor,
        lod: trailingLod,
      );
    }

    if (trailingLod > 0) {
      _drawInfallStreak(
        canvas,
        visualRadius,
        tidal,
        accent,
        bodyColor: bodyColor,
        lod: trailingLod,
        animationPhase: animationPhase,
      );
    }
    if (streakLod > 0.2) {
      _drawLeadingHotEdge(canvas, visualRadius, tidal, lod: streakLod);
    }

    canvas.restore();
    canvas.restore();
  }

  /// Roche-lobe overflow — the hole-facing hemisphere peels into a hot,
  /// flame-like cusp (reference Stage 2: Tidal Distortion & Roche Limit).
  ///
  /// Painted in the tidally scaled frame right after the body, so the cusp
  /// inherits the same spaghettification stretch. Two draw calls max.
  static void _drawRocheOverflowFace({
    required Canvas canvas,
    required double entityRadius,
    required double strength,
    required Color bodyColor,
    required double lod,
  }) {
    final r = entityRadius;
    final tipX = r * (1.35 + strength * 0.9);
    final alpha = (0.18 + strength * 0.42) * lod;
    final pop = CanvasEffects.visualPopMultiplier;

    final cusp = Path()
      ..moveTo(r * 0.18, -r * 0.82)
      ..quadraticBezierTo(r * 0.95, -r * 0.5, tipX, 0)
      ..quadraticBezierTo(r * 0.95, r * 0.5, r * 0.18, r * 0.82)
      ..quadraticBezierTo(r * 0.62, 0, r * 0.18, -r * 0.82)
      ..close();

    canvas.drawPath(
      cusp,
      Paint()
        ..shader = LinearGradient(
          colors: [
            bodyColor.withValues(alpha: alpha * 0.4 * pop),
            const Color(0xFFFF7733).withValues(alpha: alpha * 0.85 * pop),
            _streakColors[0].withValues(alpha: alpha * pop),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(r * 0.18, -r, tipX - r * 0.18, r * 2)),
    );

    if (!CanvasEffects.mobileLiteMode && strength > 0.3) {
      // Incandescent rim on the stripped hemisphere.
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * 0.98),
        -math.pi * 0.38,
        math.pi * 0.76,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, r * 0.09)
          ..strokeCap = StrokeCap.round
          ..color = _streakColors[0]
              .withValues(alpha: (alpha * 0.9).clamp(0.0, 0.85)),
      );
    }
  }

  /// Point on the stream's cubic arc: starts at the Roche lobe, sags under
  /// gravity, then hooks tangentially into the disk edge (Stage 3 wrap-in).
  static Offset _streamPoint(
    double t,
    double startX,
    double endX,
    double bend,
    double hook,
  ) {
    final mt = 1 - t;
    final len = endX - startX;
    // Cubic Bézier: P0 Roche lobe, P1 sag, P2 approach, P3 disk-entry with
    // a lateral hook so the stream arrives tangent to the disk rotation.
    final p0 = Offset(startX, 0);
    final p1 = Offset(startX + len * 0.38, bend);
    final p2 = Offset(endX - len * 0.16, bend * 0.55 + hook * 0.4);
    final p3 = Offset(endX, hook);
    return Offset(
      mt * mt * mt * p0.dx +
          3 * mt * mt * t * p1.dx +
          3 * mt * t * t * p2.dx +
          t * t * t * p3.dx,
      mt * mt * mt * p0.dy +
          3 * mt * mt * t * p1.dy +
          3 * mt * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  /// Main accretion stream (reference Stage 3): a gravitationally bent
  /// filament of stripped matter running from the body's Roche lobe to the
  /// predator's photon ring, with clumps flowing along it and an entry
  /// hotspot where it feeds the disk.
  static void _drawMassTransferStream({
    required Canvas canvas,
    required double entityRadius,
    required TidalDeformState tidal,
    required double distanceToHole,
    required double holePhotonR,
    required Color bodyColor,
    required double strength,
    required double lod,
    required double animationPhase,
  }) {
    final startX = entityRadius * (0.55 + tidal.stretch * 0.4);
    final endX = distanceToHole - holePhotonR * 0.82;
    final len = endX - startX;
    if (len < entityRadius * 0.6) return;

    final lite = CanvasEffects.mobileLiteMode;
    final pop = CanvasEffects.visualPopMultiplier;
    // Reference Stage 2-3: wide flame-like fan off the Roche lobe that
    // narrows into a filament and hooks tangentially into the disk edge.
    final baseW = entityRadius * (0.55 + strength * 0.75);
    final tipW = math.max(baseW * 0.1, entityRadius * 0.07);
    final alpha = ((0.16 + strength * 0.55) * lod).clamp(0.0, 0.85);
    final bend = -math.min(len * 0.16, entityRadius * (0.9 + strength * 1.3));
    // Tangential hook at disk entry — stream wraps with the disk rotation.
    final hook = -holePhotonR * (0.5 + strength * 0.4);

    Path ribbon(double w0, double w1) {
      const samples = 12;
      final upper = <Offset>[];
      final lower = <Offset>[];
      for (var s = 0; s <= samples; s++) {
        final t = s / samples;
        final c = _streamPoint(t, startX, endX, bend, hook);
        // Width tapers hole-ward along the curve.
        final w = lerpDouble(w0, w1, math.pow(t, 0.72).toDouble())!;
        upper.add(Offset(c.dx, c.dy - w));
        lower.add(Offset(c.dx, c.dy + w));
      }
      final path = Path()..moveTo(upper.first.dx, upper.first.dy);
      for (final pt in upper.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      for (final pt in lower.reversed) {
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      return path;
    }

    final streamRect = Rect.fromLTWH(startX, bend - baseW, len, baseW * 2 - bend);

    // Outer sheath — planet-colored matter fanning off the Roche lobe,
    // heating through amber to synchrotron white near the photon ring.
    canvas.drawPath(
      ribbon(baseW, tipW * 1.8),
      Paint()
        ..shader = LinearGradient(
          colors: [
            bodyColor.withValues(alpha: alpha * 0.5 * pop),
            const Color(0xFFCC5522).withValues(alpha: alpha * 0.55 * pop),
            const Color(0xFFFF8844).withValues(alpha: alpha * 0.68 * pop),
            _streakColors[0].withValues(alpha: alpha * 0.8 * pop),
          ],
          stops: const [0.0, 0.3, 0.62, 1.0],
        ).createShader(streamRect)
        ..maskFilter = CanvasEffects.blur(baseW * 0.32),
    );

    // Hot core filament — brightest at the disk-entry end.
    canvas.drawPath(
      ribbon(baseW * 0.32, tipW * 0.55),
      Paint()
        ..shader = LinearGradient(
          colors: [
            _streakColors[1].withValues(alpha: alpha * 0.55 * pop),
            _streakColors[0].withValues(alpha: alpha * 0.9 * pop),
            Colors.white.withValues(alpha: alpha * pop),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(streamRect),
    );

    // Matter clumps flowing along the stream toward the hole.
    final clumps = lite ? 3 : 5;
    for (var i = 0; i < clumps; i++) {
      final t = ((animationPhase * (0.5 + i * 0.13) + i * 0.29) % 1.0);
      final p = _streamPoint(t, startX, endX, bend, hook);
      final clumpR =
          entityRadius * (0.22 - t * 0.12) * (0.6 + strength * 0.6);
      if (clumpR < 0.6) continue;
      canvas.drawOval(
        Rect.fromCenter(
          center: p,
          width: clumpR * 2.6,
          height: clumpR * 1.3,
        ),
        Paint()
          ..color = Color.lerp(bodyColor, _streakColors[0], t * 0.85)!
              .withValues(alpha: alpha * (0.5 + t * 0.4)),
      );
    }

    // Disk-entry hotspot — stream slams into the accretion flow.
    final entry = _streamPoint(1.0, startX, endX, bend, hook);
    final entryR = (tipW * 2.4 + entityRadius * 0.32) * (0.7 + strength * 0.5);
    canvas.drawCircle(
      entry,
      entryR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: alpha * 0.9),
            const Color(0xFFFFCC66).withValues(alpha: alpha * 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: entry, radius: entryR))
        ..blendMode = BlendMode.plus,
    );
  }

  static void _drawInfallStreak(
    Canvas canvas,
    double entityRadius,
    TidalDeformState tidal,
    Color accent, {
    required Color bodyColor,
    double lod = 1.0,
    double animationPhase = 0,
  }) {
    final pop = CanvasEffects.visualPopMultiplier;
    final lodScale = lod * lod;
    final trailLen =
        entityRadius * (2.0 + tidal.intensity * 9.5) * lodScale;
    final baseWidth =
        entityRadius * (0.28 + tidal.intensity * 0.48) * math.sqrt(lodScale);
    final startX = -entityRadius * (0.42 + tidal.fragmentLevel * 0.32);
    final endX = startX - trailLen;
    final helix =
        math.sin(animationPhase * 8.5 + tidal.intensity * 4.2) *
        baseWidth *
        0.18 *
        lodScale;
    final lite = CanvasEffects.mobileLiteMode;

    // Outer volumetric sheath — soft, wide.
    _drawTidalStreamRibbon(
      canvas: canvas,
      startX: startX,
      endX: endX,
      baseWidth: baseWidth * 1.55,
      tipWidth: baseWidth * 0.08,
      colors: [
        accent.withValues(alpha: 0.02 * pop),
        bodyColor.withValues(alpha: (0.08 + tidal.intensity * 0.1) * pop),
        const Color(0xFFFF8844).withValues(alpha: (0.14 + tidal.intensity * 0.16) * pop),
        _streakColors[2].withValues(alpha: (0.22 + tidal.intensity * 0.2) * pop),
      ],
      blurSigma: baseWidth * 0.42,
    );

    // Mid stream — warm infall channel with flowing brightness pulses.
    final segments = lite ? 5 : 8;
    for (var i = 0; i < segments; i++) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      final pulse =
          0.72 + 0.28 * math.sin(animationPhase * 9.5 - t0 * 14.0 + tidal.intensity * 2.4);
      final segStart = lerpDouble(startX, endX, t0)!;
      final segEnd = lerpDouble(startX, endX, t1)!;
      final segWidth = lerpDouble(baseWidth * 0.95, baseWidth * 0.12, t0)! * pulse;
      final alpha = (0.18 + tidal.intensity * 0.42) * (1 - t0 * 0.35) * lod * pop;

      final segPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(bodyColor, accent, 0.25)!.withValues(alpha: alpha * 0.35),
            _streakColors[1].withValues(alpha: alpha * 0.85),
            _streakColors[0].withValues(alpha: alpha),
          ],
        ).createShader(
          Rect.fromLTWH(segEnd, -segWidth, segStart - segEnd, segWidth * 2),
        )
        ..strokeWidth = segWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = CanvasEffects.blur(segWidth * 0.22);

      canvas.drawLine(Offset(segStart, helix * t0), Offset(segEnd, helix * t1), segPaint);

      if (!CanvasEffects.blurEnabled) {
        canvas.drawLine(
          Offset(segStart, 0),
          Offset(segEnd, 0),
          Paint()
            ..shader = segPaint.shader
            ..strokeWidth = segWidth * 1.65
            ..strokeCap = StrokeCap.round
            ..color = _streakColors[1].withValues(alpha: alpha * 0.28),
        );
      }
    }

    // Hot inner core — narrow bright filament.
    _drawTidalStreamRibbon(
      canvas: canvas,
      startX: startX + entityRadius * 0.05,
      endX: endX,
      baseWidth: baseWidth * 0.38,
      tipWidth: baseWidth * 0.03,
      colors: [
        Colors.white.withValues(alpha: 0.08 + tidal.intensity * 0.12),
        _streakColors[0].withValues(alpha: 0.55 + tidal.intensity * 0.35),
        _streakColors[2].withValues(alpha: 0.35 + tidal.intensity * 0.25),
        Colors.transparent,
      ],
      blurSigma: baseWidth * 0.12,
    );

    if (!lite && tidal.intensity > 0.45) {
      // Secondary parallel streamlines — volumetric spaghetti strands.
      for (final offset in [-1.0, 1.0]) {
        final perp = baseWidth * 0.22 * offset * tidal.fragmentLevel;
        final wobble =
            math.sin(animationPhase * 7.0 + offset * 1.7) * baseWidth * 0.06;
        canvas.drawLine(
          Offset(startX, perp + wobble),
          Offset(endX, perp * 0.35 + wobble * 0.4),
          Paint()
            ..shader = LinearGradient(
              colors: [
                accent.withValues(alpha: 0.04),
                _streakColors[1].withValues(alpha: 0.2 + tidal.intensity * 0.22),
                _streakColors[0].withValues(alpha: 0.35 * tidal.intensity),
              ],
            ).createShader(
              Rect.fromLTWH(endX, perp - baseWidth, trailLen, baseWidth * 2),
            )
            ..strokeWidth = baseWidth * 0.14
            ..strokeCap = StrokeCap.round
            ..maskFilter = CanvasEffects.blur(baseWidth * 0.18),
        );
      }
    }
  }

  /// Tapered infall ribbon along the tidal axis (wider at body, pinches at tip).
  static void _drawTidalStreamRibbon({
    required Canvas canvas,
    required double startX,
    required double endX,
    required double baseWidth,
    required double tipWidth,
    required List<Color> colors,
    double blurSigma = 0,
  }) {
    final path = Path()
      ..moveTo(startX, -baseWidth * 0.5)
      ..quadraticBezierTo(
        startX - (startX - endX) * 0.42,
        -tipWidth * 0.35,
        endX,
        0,
      )
      ..quadraticBezierTo(
        startX - (startX - endX) * 0.42,
        tipWidth * 0.35,
        startX,
        baseWidth * 0.5,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: colors,
          stops: List.generate(
            colors.length,
            (i) => i / (colors.length - 1),
          ),
        ).createShader(
          Rect.fromLTWH(endX, -baseWidth, startX - endX, baseWidth * 2),
        )
        ..maskFilter = CanvasEffects.blur(blurSigma),
    );

    if (!CanvasEffects.blurEnabled && blurSigma > 0) {
      canvas.save();
      canvas.scale(1.0, 1.35);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: colors
                .map((c) => c.withValues(alpha: c.a * 0.35))
                .toList(),
            stops: List.generate(
              colors.length,
              (i) => i / (colors.length - 1),
            ),
          ).createShader(
            Rect.fromLTWH(endX, -baseWidth * 1.35, startX - endX, baseWidth * 2.7),
          ),
      );
      canvas.restore();
    }
  }

  /// Trailing edge dims and redshifts as photons climb out of the gravity well.
  static void _drawGravitationalRedshift(
    Canvas canvas,
    double entityRadius,
    TidalDeformState tidal, {
    double lod = 1.0,
  }) {
    final strength = ((tidal.intensity - 0.35) / 0.65).clamp(0.0, 1.0) * lod;
    if (strength <= 0) return;

    final tailLen = entityRadius * (1.2 + tidal.stretch * 0.5) * lod;
    canvas.drawRect(
      Rect.fromLTWH(
        -entityRadius * tidal.stretch * 0.95 - tailLen,
        -entityRadius * 1.1,
        tailLen + entityRadius * 0.3,
        entityRadius * 2.2,
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF000000).withValues(alpha: 0.55 * strength),
            const Color(0xFF330800).withValues(alpha: 0.35 * strength),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromLTWH(
            -entityRadius * tidal.stretch - tailLen,
            -entityRadius,
            tailLen,
            entityRadius * 2,
          ),
        ),
    );
  }

  static void _drawLeadingHotEdge(
    Canvas canvas,
    double entityRadius,
    TidalDeformState tidal, {
    double lod = 1.0,
  }) {
    final leading = entityRadius * (0.5 + tidal.stretch * 0.08);
    final glowR = entityRadius * (0.18 + tidal.intensity * 0.16);
    final pop = CanvasEffects.visualPopMultiplier;
    final center = Offset(leading, 0);

    CanvasEffects.drawSoftGlowCircle(
      canvas,
      center,
      glowR * 1.6,
      _streakColors[0],
      intensity: (0.35 + tidal.intensity * 0.35) * lod * pop,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: glowR * 2.2,
        height: glowR * 1.35,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: (0.55 + tidal.intensity * 0.35) * lod * pop),
            _streakColors[0].withValues(alpha: (0.45 + tidal.intensity * 0.4) * lod * pop),
            const Color(0xFFFF6633).withValues(alpha: (0.22 + tidal.intensity * 0.28) * lod * pop),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowR * 1.2)),
    );
  }

  /// Debris chunks shed along the tidal axis (Roche breakup — no spiral scatter).
  static void _drawTidalFragments({
    required Canvas canvas,
    required double entityRadius,
    required TidalDeformState tidal,
    required Color accent,
    required Color bodyColor,
    double lod = 1.0,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final chunkCount = lite
        ? (2 + (tidal.fragmentLevel * 3).round())
        : (3 + (tidal.fragmentLevel * 5).round()).clamp(3, 8);

    for (var i = 0; i < chunkCount; i++) {
      final t = (i + 1) / (chunkCount + 1);
      final along = -entityRadius * (0.55 + t * (3.0 + tidal.fragmentLevel * 3.2));
      // Small perpendicular scatter from tidal shear (deterministic, not sinusoidal).
      final perp = entityRadius * 0.12 * (t - 0.5) * tidal.fragmentLevel;
      final chunkR = entityRadius *
          (0.05 + (1 - t) * 0.11) *
          (1.0 - tidal.disintegrationLevel * 0.6);

      if (chunkR < 0.35) continue;

      final alpha = (0.32 + tidal.fragmentLevel * 0.48) * (1 - t * 0.4) * lod;
      canvas.save();
      canvas.translate(along, perp);
      canvas.scale(1.0 + tidal.fragmentLevel * 0.8, 1.0 - tidal.fragmentLevel * 0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: chunkR * 2.4,
          height: chunkR * 1.35,
        ),
        Paint()
          ..color = Color.lerp(bodyColor, accent, t * 0.35)!
              .withValues(alpha: alpha),
      );
      canvas.restore();

      if (!lite && tidal.disintegrationLevel > 0.25 && i.isEven) {
        canvas.drawCircle(
          Offset(along - chunkR * 0.55, perp * 0.35),
          chunkR * 0.4,
          Paint()
            ..color = _streakColors[1]
                .withValues(alpha: alpha * 0.65 * tidal.disintegrationLevel),
        );
      }
    }

    // Hot debris at disintegration — asymmetric scatter, not a ring.
    if (tidal.disintegrationLevel > 0.18) {
      final sparkCount = lite ? 2 : 3;
      for (var i = 0; i < sparkCount; i++) {
        final t = (i + 0.5) / sparkCount;
        final along = -entityRadius * (2.8 + t * 2.2 + tidal.disintegrationLevel);
        final perp = entityRadius * 0.14 * (t - 0.5) * tidal.disintegrationLevel;
        final sparkW = entityRadius * 0.05 * (1 - t * 0.3);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(along, perp),
            width: sparkW * 2.2,
            height: sparkW * 0.75,
          ),
          Paint()
            ..color = Color.lerp(
              _streakColors[2],
              Colors.white,
              tidal.disintegrationLevel * 0.5,
            )!.withValues(alpha: 0.32 + tidal.disintegrationLevel * 0.38),
        );
      }
    }
  }

}
