import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/cosmic_particle_presets.dart';
import '../utils/gravity_scaling.dart';
import '../utils/viewport_cull.dart';

/// Compact tidal-disruption flash when matter crosses the photon-ring shell.
///
/// Canvas: photon-ring flash + redshift void.
/// Flame particles: infalling debris shards + ring shimmer.
class HoleSwallowBurstEffect extends PositionComponent {
  HoleSwallowBurstEffect({
    required Vector2 position,
    required this.predatorRadius,
    required this.preyRadius,
    required this.infallAngle,
    this.accent = const Color(0xFFFFAA44),
    this.duration = 0.30,
  })  : _photonR = predatorRadius *
            GravityScaling.schwarzschildFraction *
            GravityScaling.shadowBoundaryRatio,
        super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(
            math.max(preyRadius * 2.4, predatorRadius * 0.55),
          ),
        );

  final double predatorRadius;
  final double preyRadius;
  final double infallAngle;
  final Color accent;
  final double duration;

  final double _photonR;
  double _elapsed = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final seed = (position.x.round() * 73856093) ^
        (position.y.round() * 19349663) ^
        preyRadius.round();

    add(
      ParticleSystemComponent(
        angle: infallAngle,
        anchor: Anchor.center,
        particle: CosmicParticlePresets.swallowDebris(
          preyRadius: preyRadius,
          accent: accent,
          duration: duration,
          seed: seed,
        ),
      ),
    );

    add(
      ParticleSystemComponent(
        angle: infallAngle,
        anchor: Anchor.center,
        particle: CosmicParticlePresets.swallowRingShimmer(
          photonR: _photonR,
          accent: accent,
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
    if (game != null &&
        ViewportCull.isFarFromView(
          game,
          position,
          margin: math.max(size.x, predatorRadius * 2),
        )) {
      return;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final game = findGame() as OrbitGame?;
    if (game != null &&
        ViewportCull.isOffScreen(game, position, size.x * 0.6)) {
      return;
    }
    super.render(canvas);
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final center = size / 2;
    final fade = math.pow(1 - t, 1.55).toDouble();
    final ease = 1 - math.pow(1 - t, 2.6).toDouble();
    final alpha = fade * 0.58;

    if (alpha < 0.03) return;

    canvas.save();
    canvas.translate(center.x, center.y);
    canvas.rotate(infallAngle);

    // Photon-ring scale — flash anchored to shadow boundary (EHT), not prey size.
    final ringW = _photonR * (0.42 + ease * 0.12) * (1 - t * 0.5);
    final ringH = _photonR * (0.16 + ease * 0.06) * (1 - t * 0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: ringW, height: ringH),
      Paint()
        ..shader = RadialGradient(
          colors: [
            CosmicParticlePresets.redshiftColor(
              t: t * 0.35,
              accent: accent,
              alpha: alpha * 0.7,
            ),
            CosmicParticlePresets.redshiftColor(
              t: t * 0.65,
              accent: accent,
              alpha: alpha * 0.45,
            ),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(
          Rect.fromCenter(center: Offset.zero, width: ringW, height: ringH),
        ),
    );

    // Infall tail behind the stream (matter dragged toward the horizon).
    if (t < 0.62) {
      final smearLen = _photonR * (0.28 + ease * 0.38);
      final smearW = _photonR * 0.045 * (1 - t * 0.85);
      canvas.drawLine(
        Offset(-smearLen * 0.2, 0),
        Offset(-smearLen, 0),
        Paint()
          ..strokeWidth = smearW
          ..strokeCap = StrokeCap.round
          ..color = CosmicParticlePresets.redshiftColor(
            t: 0.25 + t * 0.55,
            accent: accent,
            alpha: alpha * 0.32 * (1 - t),
          ),
      );
    }

    // Late-stage redshift dimming — absorbed matter fades to infrared then void.
    if (t > 0.42) {
      final voidT = ((t - 0.42) / 0.58).clamp(0.0, 1.0);
      final voidR = lerpDouble(_photonR * 0.18, _photonR * 0.55, ease)! * voidT;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_photonR * 0.06 * ease, 0),
          width: voidR * 1.6,
          height: voidR * 0.55,
        ),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF220600).withValues(alpha: alpha * 0.35 * voidT),
              const Color(0xFF000000).withValues(alpha: alpha * 0.5 * voidT),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: Offset(_photonR * 0.06 * ease, 0),
              width: voidR * 1.6,
              height: voidR * 0.55,
            ),
          ),
      );
    }

    canvas.restore();
  }
}
