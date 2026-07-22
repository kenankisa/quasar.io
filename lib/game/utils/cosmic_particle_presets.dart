import 'dart:math' as math;

import 'package:flame/extensions.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import 'canvas_effects.dart';

/// Flame [Particle] factories for swallow / explosion VFX.
///
/// Karadelik çekirdeğine dokunmaz — sadece kısa ömürlü parçacık patlamaları.
abstract final class CosmicParticlePresets {
  CosmicParticlePresets._();

  /// Hot → warm → infrared as matter redshifts toward the horizon.
  static Color redshiftColor({
    required double t,
    required Color accent,
    required double alpha,
  }) {
    const infrared = Color(0xFF1A0400);
    const deepVoid = Color(0xFF080200);
    final hot = Color.lerp(Colors.white, accent, 0.28)!;
    final warm = Color.lerp(accent, const Color(0xFFFF4400), 0.55)!;

    final color = t < 0.38
        ? Color.lerp(hot, warm, t / 0.38)!
        : Color.lerp(
            warm,
            Color.lerp(
              infrared,
              deepVoid,
              ((t - 0.38) / 0.62).clamp(0.0, 1.0),
            )!,
            ((t - 0.38) / 0.62).clamp(0.0, 1.0),
          )!;

    return color.withValues(alpha: alpha * (1.0 - t * 0.42));
  }

  /// Tidal debris streaming inward along +X (rotate parent by [infallAngle]).
  static Particle swallowDebris({
    required double preyRadius,
    required Color accent,
    required double duration,
    int? seed,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 8 : 14;
    final rng = math.Random(seed ?? preyRadius.round() * 9973);

    return Particle.generate(
      count: count,
      lifespan: duration,
      generator: (i) {
        final lateral = (rng.nextDouble() - 0.5) * preyRadius * 0.38;
        final startDist = preyRadius * (0.12 + rng.nextDouble() * 0.42);
        final inwardSpeed = preyRadius * (1.4 + rng.nextDouble() * 2.2);
        final size = preyRadius * (0.028 + rng.nextDouble() * 0.038);
        final lag = 0.04 + rng.nextDouble() * 0.08;

        return ComputedParticle(
          lifespan: duration,
          renderer: (canvas, particle) {
            final t = Curves.easeIn.transform(particle.progress);
            final along = startDist + inwardSpeed * t - preyRadius * lag * (1 - t);
            final perp = lateral * t * 0.65;
            final stretch = size * (1.6 + t * 0.9);
            final height = size * (0.75 - particle.progress * 0.3);
            final alpha = (1 - particle.progress) * 0.72;

            canvas.save();
            canvas.translate(along, perp);
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: stretch,
                height: height,
              ),
              Paint()
                ..color = redshiftColor(
                  t: particle.progress + lag,
                  accent: accent,
                  alpha: alpha,
                ),
            );
            canvas.restore();
          },
        );
      },
    );
  }

  /// Radial supernova / merger burst.
  static Particle explosionBurst({
    required double maxRadius,
    required double duration,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 18 : 32;
    final rng = math.Random(maxRadius.round() * 7919);

    return Particle.generate(
      count: count,
      lifespan: duration * 0.92,
      generator: (i) {
        final angle = rng.nextDouble() * math.pi * 2;
        final speed = maxRadius * (2.2 + rng.nextDouble() * 2.8);
        final vx = math.cos(angle) * speed;
        final vy = math.sin(angle) * speed;
        final size = 1.2 + rng.nextDouble() * (lite ? 2.8 : 4.2);
        final hot = i % 3 == 0;
        final color = hot
            ? const Color(0xFFFFEE88)
            : (i.isEven ? const Color(0xFFFF6600) : const Color(0xFFFF3300));

        Particle particle = CircleParticle(
          radius: size,
          paint: Paint()..color = color,
        )
            .accelerated(
              speed: Vector2(vx, vy),
              acceleration: Vector2(-vx * 1.8, -vy * 1.8),
            )
            .scaling(to: 0, curve: Curves.easeOutCubic);

        if (CanvasEffects.blurEnabled && hot) {
          particle = PaintParticle(
            child: particle,
            paint: Paint()..blendMode = BlendMode.plus,
            bounds: Rect.fromCircle(center: Offset.zero, radius: size * 3),
          );
        }

        return particle;
      },
    );
  }

  /// Short inward sparks while a hole is actively hunting prey.
  static Particle huntInfallSparks({
    required double holeRadius,
    required double charge,
    required Color accent,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 4 : 7;
    final duration = lite ? 0.28 : 0.36;
    final rng = math.Random((holeRadius * charge * 1000).round());
    final spawnR = holeRadius * 0.72;

    return Particle.generate(
      count: count,
      lifespan: duration,
      generator: (i) {
        final angle = rng.nextDouble() * math.pi * 2;
        final start = Vector2(
          math.cos(angle) * spawnR,
          math.sin(angle) * spawnR * 0.28,
        );
        final inward = Vector2(-math.cos(angle), -math.sin(angle) * 0.28)
          ..scale(holeRadius * (2.5 + rng.nextDouble() * 1.5));
        final accel = inward.clone()..scale(2.8);
        final size = holeRadius * (0.018 + rng.nextDouble() * 0.022);

        return CircleParticle(
          radius: size,
          paint: Paint()
            ..color = Color.lerp(accent, Colors.white, 0.35)!,
        )
            .translated(start)
            .accelerated(
              speed: inward,
              acceleration: accel,
            )
            .scaling(to: 0, curve: Curves.easeIn);
      },
    );
  }

  /// Hot matter filament streaming along a hole-to-hole tidal bridge (+X axis).
  static Particle swallowBridgeFilament({
    required double bridgeLength,
    required double streamWidth,
    required Color preyAccent,
    required Color predatorAccent,
    required double intensity,
    required int seed,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 10 : 18;
    final rng = math.Random(seed);
    final lifespan = (0.42 + intensity * 0.35).clamp(0.35, 0.85);

    return Particle.generate(
      count: count,
      lifespan: lifespan,
      generator: (i) {
        final phase = i / count;
        final lateral = (rng.nextDouble() - 0.5) * streamWidth;
        final lane = (rng.nextDouble() - 0.5) * streamWidth * 0.35;
        final size = streamWidth * (0.06 + rng.nextDouble() * 0.09);
        final lag = phase * 0.55 + rng.nextDouble() * 0.12;
        final hot = rng.nextDouble() < 0.28 + intensity * 0.22;

        return ComputedParticle(
          lifespan: lifespan,
          renderer: (canvas, particle) {
            final t = Curves.easeIn.transform(particle.progress);
            final along =
                -bridgeLength * 0.48 + (bridgeLength * (lag + t * (1 - lag * 0.7)));
            final lens =
                math.sin(t * math.pi) * streamWidth * 0.08 * (1 + intensity * 0.5);
            final perp = lateral * (1 - t * 0.35) + lane * t + lens;
            final stretch = size * (1.4 + t * 2.6);
            final height = size * (0.65 - particle.progress * 0.25);
            final alpha = (1 - particle.progress) * (0.55 + intensity * 0.35);

            canvas.save();
            canvas.translate(along, perp);
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: stretch,
                height: height,
              ),
              Paint()
                ..color = hot
                    ? Color.lerp(
                        Colors.white,
                        predatorAccent,
                        0.18 + t * 0.25,
                      )!.withValues(alpha: alpha)
                    : redshiftColor(
                        t: particle.progress * 0.85,
                        accent: Color.lerp(preyAccent, predatorAccent, t)!,
                        alpha: alpha,
                      ),
            );
            canvas.restore();
          },
        );
      },
    );
  }

  /// Stripped debris wisps peeling off the prey hole during inspiral.
  static Particle swallowBridgeStripping({
    required double preyRadius,
    required Color preyAccent,
    required double intensity,
    required int seed,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 4 : 7;
    final rng = math.Random(seed ^ 0x9e3779b9);
    final lifespan = 0.38 + intensity * 0.22;

    return Particle.generate(
      count: count,
      lifespan: lifespan,
      generator: (i) {
        final angle = (rng.nextDouble() - 0.5) * 0.9;
        final startR = preyRadius * (0.35 + rng.nextDouble() * 0.25);
        final drift = preyRadius * (0.6 + rng.nextDouble() * 1.1);
        final size = preyRadius * (0.025 + rng.nextDouble() * 0.035);

        return ComputedParticle(
          lifespan: lifespan,
          renderer: (canvas, particle) {
            final t = Curves.easeOut.transform(particle.progress);
            final along = startR + drift * t;
            final perp = math.sin(angle) * preyRadius * 0.22 * t;
            final alpha = (1 - particle.progress) * 0.62 * intensity;

            canvas.save();
            canvas.translate(-along, perp);
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: size * (1.5 + t * 1.8),
                height: size * (0.7 - t * 0.2),
              ),
              Paint()
                ..color = preyAccent.withValues(alpha: alpha),
            );
            canvas.restore();
          },
        );
      },
    );
  }

  /// One polar beam of a "Quasar Activation" relativistic jet (Stage 4).
  ///
  /// [direction] is +1 (south pole) or -1 (north pole) — perpendicular to the
  /// accretion disk plane, matching the reference art's twin vertical jets.
  static Particle relativisticJetBeam({
    required double length,
    required double width,
    required Color coreColor,
    required double direction,
    required double duration,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 10 : 18;
    final rng = math.Random((length * 97 + direction * 13).round());

    return Particle.generate(
      count: count,
      lifespan: duration,
      generator: (i) {
        final lateral = (rng.nextDouble() - 0.5) * width;
        final speed = length * (1.3 + rng.nextDouble() * 1.5);
        final size = width * (0.06 + rng.nextDouble() * 0.1);
        final delay = rng.nextDouble() * 0.3;

        return ComputedParticle(
          lifespan: duration,
          renderer: (canvas, particle) {
            final span = (1 - delay).clamp(0.05, 1.0);
            final tt = ((particle.progress - delay) / span).clamp(0.0, 1.0);
            if (particle.progress < delay) return;

            final t = Curves.easeOut.transform(tt);
            final along = direction * speed * t;
            final perp = lateral * (1 - t * 0.45);
            final alpha = (1 - tt) * 0.9;
            final r = math.max(0.4, size * (1.7 - t * 1.2));

            canvas.drawCircle(
              Offset(perp, along),
              r,
              Paint()
                ..color = Color.lerp(Colors.white, coreColor, 0.35 + t * 0.4)!
                    .withValues(alpha: alpha)
                ..blendMode = BlendMode.plus,
            );
          },
        );
      },
    );
  }

  /// Expanding photon-ring shimmer for swallow capture flash.
  static Particle swallowRingShimmer({
    required double photonR,
    required Color accent,
    required double duration,
  }) {
    final lite = CanvasEffects.mobileLiteMode;
    final count = lite ? 6 : 10;
    final rng = math.Random(photonR.round());

    return Particle.generate(
      count: count,
      lifespan: duration * 0.85,
      generator: (i) {
        final angle = (i / count) * math.pi * 2 + rng.nextDouble() * 0.4;
        final ringR = photonR * (0.92 + rng.nextDouble() * 0.12);
        final pos = Vector2(
          math.cos(angle) * ringR,
          math.sin(angle) * ringR * 0.26,
        );
        final size = photonR * (0.025 + rng.nextDouble() * 0.035);

        return CircleParticle(
          radius: size,
          paint: Paint()..color = accent,
        )
            .translated(pos)
            .moving(
              to: pos * 0.35,
              curve: Curves.easeIn,
            )
            .scaling(to: 0, curve: Curves.easeInCubic);
      },
    );
  }
}
