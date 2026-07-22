import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'canvas_effects.dart';
import 'gravity_scaling.dart';

/// Black-hole visual FX: streamlines, swallow proximity, prey fragments.
class GravityHoleFx {
  GravityHoleFx._();

  static const _preyHot = Color(0xFFFFE8CC);

  /// Curved infall streamlines spiraling into the event horizon (on-hole VFX).
  static void drawInfallStreamlines({
    required Canvas canvas,
    required double diskR,
    required double coreR,
    required List<Color> hot,
    required double spin,
    required double intensity,
  }) {
    if (intensity < 0.12) return;

    final lite = CanvasEffects.mobileLiteMode;
    if (lite && intensity < 0.35) return;

    final streams = lite ? 4 : 6;
    final baseAngle = -spin * 0.18;

    for (var i = 0; i < streams; i++) {
      final t = i / streams;
      final startAngle = baseAngle + t * math.pi * 2;
      final startR = diskR * (1.28 + 0.22 * math.sin(t * math.pi * 4));
      final endR = coreR * 1.22;

      final path = Path();
      final segments = lite ? 8 : 12;
      for (var s = 0; s <= segments; s++) {
        final u = s / segments;
        final spiral = startAngle + u * 1.35 * math.pi;
        final r = lerpDouble(startR, endR, u * u)!;
        final wobble = math.sin(spin * 2.2 + u * 9.0) * coreR * 0.04 * intensity;
        final pt = Offset(
          math.cos(spiral) * r + wobble,
          math.sin(spiral) * r * 0.28 + wobble * 0.35,
        );
        if (s == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }

      final alpha = (0.14 + intensity * 0.32) * (1 - t * 0.3);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.7, coreR * 0.032) * (0.85 + intensity * 0.25)
          ..strokeCap = StrokeCap.round
          ..color = hot[i.isEven ? 0 : 1].withValues(alpha: alpha),
      );
    }
  }

  static double holeVisualIntensity(double gameRadius) {
    final rs = (gameRadius * 0.34).clamp(12.0, 118.0);
    return (rs / 65).clamp(0.55, 1.85);
  }

  static double swallowProximity({
    required double largerRadius,
    required double smallerRadius,
    required double distance,
  }) {
    final capture = GravityScaling.holeCaptureDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    final approach = GravityScaling.holeSwallowPhysicsApproachDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    if (capture <= 0 || approach <= capture || distance >= approach) return 0;
    if (distance <= capture) return 1.0;
    return (1 - (distance - capture) / (approach - capture)).clamp(0.0, 1.0);
  }

  /// Warning + danger visual proximity (0 = at warning edge, 1 = capture).
  ///
  /// Outer band shows rings only; bridge / spaghettification use [swallowProximity].
  static double swallowVisualProximity({
    required double largerRadius,
    required double smallerRadius,
    required double distance,
  }) {
    final capture = GravityScaling.holeCaptureDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    final approach = GravityScaling.holeSwallowApproachDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    final warning = GravityScaling.holeSwallowWarningDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    final warnMax = GravityScaling.holeSwallowWarningMaxProximity;

    if (capture <= 0 || warning <= capture || distance >= warning) return 0;
    if (distance <= capture) return 1.0;

    if (distance > approach) {
      final span = warning - approach;
      if (span <= 0) return 0;
      final t = 1 - (distance - approach) / span;
      return (t * warnMax).clamp(0.0, warnMax);
    }

    final inner = swallowProximity(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
      distance: distance,
    );
    return warnMax + inner * (1.0 - warnMax);
  }

  /// Spaghettification on a prey hole — radial stretch toward the predator.
  static void applyHoleTidalStretch({
    required Canvas canvas,
    required Offset predatorOffset,
    required double proximity,
  }) {
    if (proximity < GravityScaling.holeSwallowProximityOnset) return;
    final angle = math.atan2(predatorOffset.dy, predatorOffset.dx);
    final tidal = proximity * proximity * (0.62 + proximity * 0.55);
    final stretch = 1.0 + tidal * 1.2;
    final shrink = (1.0 - proximity * 0.38).clamp(0.38, 1.0);
    canvas.rotate(angle);
    canvas.scale(stretch * shrink, (1.0 / math.sqrt(stretch)) * shrink);
    canvas.rotate(-angle);
  }

  /// Mass stripped from a prey hole along the tidal axis during inspiral.
  static void drawPreyHoleFragments({
    required Canvas canvas,
    required double gameRadius,
    required Offset predatorOffset,
    required double proximity,
    required Color accent,
  }) {
    final fragmentLevel = ((proximity - 0.35) / 0.65).clamp(0.0, 1.0);
    if (fragmentLevel < 0.06) return;

    final angle = math.atan2(predatorOffset.dy, predatorOffset.dx);
    final disintegration = ((proximity - 0.70) / 0.30).clamp(0.0, 1.0);
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 3 : (4 + (fragmentLevel * 4).round()).clamp(4, 7);

    canvas.save();
    canvas.rotate(angle);

    for (var i = 0; i < count; i++) {
      final t = (i + 1) / (count + 1);
      final along = -gameRadius * (0.65 + t * (2.8 + fragmentLevel * 2.6));
      final perp = gameRadius * 0.1 * (t - 0.5) * fragmentLevel;
      final chunkR =
          gameRadius * (0.035 + (1 - t) * 0.07) * (1 - disintegration * 0.55);
      if (chunkR < 0.45) continue;

      canvas.drawCircle(
        Offset(along, perp),
        chunkR,
        Paint()
          ..color = accent.withValues(alpha: 0.22 + fragmentLevel * 0.42),
      );
    }

    // Radial infall streak toward predator photon ring.
    if (fragmentLevel > 0.15) {
      final trailLen = gameRadius * (2.0 + proximity * 4.5);
      final trailW = gameRadius * (0.08 + proximity * 0.12);
      canvas.drawLine(
        Offset(-gameRadius * 0.5, 0),
        Offset(-gameRadius * 0.5 - trailLen, 0),
        Paint()
          ..strokeWidth = trailW
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              accent.withValues(alpha: 0.08),
              const Color(0xFFFFAA66).withValues(alpha: 0.35 + proximity * 0.35),
              Colors.white.withValues(alpha: 0.55 * proximity),
            ],
          ).createShader(Rect.fromLTWH(-gameRadius * 0.5 - trailLen, -trailW, trailLen, trailW * 2))
          ..maskFilter = CanvasEffects.blur(trailW * 0.35),
      );
    }

    if (disintegration > 0.22) {
      final sparks = lite ? 2 : 3;
      for (var i = 0; i < sparks; i++) {
        final along = -gameRadius * (2.6 + i * 0.55);
        final perp = gameRadius * 0.08 * (i - 1) * disintegration;
        final w = gameRadius * 0.028;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(along, perp),
            width: w * 2.0,
            height: w * 0.7,
          ),
          Paint()
            ..color = _preyHot
                .withValues(alpha: 0.28 + disintegration * 0.35),
        );
      }
    }

    canvas.restore();
  }

  static ({Vector2 position, double radius})? dominantSource(
    Vector2 worldPos,
    List<({Vector2 position, double radius})> sources, {
    double roomMultiplier = 1.0,
  }) {
    ({Vector2 position, double radius})? best;
    var bestAccel = 0.0;
    for (final source in sources) {
      final distance = worldPos.distanceTo(source.position);
      final influence = GravityScaling.consumableInfluenceRadius(
        source.radius,
        roomMultiplier: roomMultiplier,
      );
      if (distance > influence) continue;
      final accel = GravityScaling.accelerationToward(
        sourceRadius: source.radius,
        distance: distance,
        roomMultiplier: roomMultiplier,
      );
      if (accel > bestAccel) {
        bestAccel = accel;
        best = source;
      }
    }
    return best;
  }
}
