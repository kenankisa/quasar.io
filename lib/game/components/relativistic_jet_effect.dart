import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/cosmic_particle_presets.dart';
import '../utils/viewport_cull.dart';

/// Twin relativistic jets fired perpendicular to the accretion disk plane
/// when a black hole fully swallows significant mass — "Quasar Activation"
/// (reference Stage 4: Total Consumption & Quasar Activation).
class RelativisticJetEffect extends PositionComponent {
  RelativisticJetEffect({
    required Vector2 position,
    required this.holeRadius,
    required this.coreColor,
    this.intensity = 1.0,
    this.duration = 0.9,
  }) : jetLength = holeRadius * (7.0 + intensity.clamp(0.0, 1.0) * 5.0),
       super(
         position: position,
         anchor: Anchor.center,
         size: Vector2.all(holeRadius * 28),
       );

  final double holeRadius;
  final Color coreColor;
  final double intensity;
  final double duration;
  final double jetLength;

  double _elapsed = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final width = holeRadius * (0.32 + intensity.clamp(0.0, 1.0) * 0.22);
    for (final dir in [-1.0, 1.0]) {
      add(
        ParticleSystemComponent(
          anchor: Anchor.center,
          particle: CosmicParticlePresets.relativisticJetBeam(
            length: jetLength,
            width: width,
            coreColor: coreColor,
            direction: dir,
            duration: duration,
          ),
        ),
      );
    }
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
          margin: jetLength + holeRadius * 4,
        )) {
      return;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final game = findGame() as OrbitGame?;
    if (game != null &&
        ViewportCull.isOffScreen(game, position, jetLength + 40)) {
      return;
    }
    super.render(canvas);
    final t = (_elapsed / duration).clamp(0.0, 1.0);
    final fade = (1 - t).clamp(0.0, 1.0);
    if (fade <= 0.01) return;

    final center = size / 2;
    final strength = intensity.clamp(0.0, 1.0);
    final beamWidth = holeRadius * (0.26 + strength * 0.16) * (1 - t * 0.3);
    final beamLen = jetLength * Curves.easeOut.transform((t * 2.6).clamp(0.0, 1.0));

    canvas.save();
    canvas.translate(center.x, center.y);

    final rectUp = Rect.fromLTWH(-beamWidth, -beamLen, beamWidth * 2, beamLen);
    final rectDown = Rect.fromLTWH(-beamWidth, 0, beamWidth * 2, beamLen);

    canvas.drawRect(
      rectUp,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white.withValues(alpha: 0.9 * fade),
            coreColor.withValues(alpha: 0.5 * fade),
            coreColor.withValues(alpha: 0.0),
          ],
        ).createShader(rectUp)
        ..blendMode = BlendMode.plus
        ..maskFilter = CanvasEffects.blur(beamWidth * 0.4),
    );
    canvas.drawRect(
      rectDown,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.9 * fade),
            coreColor.withValues(alpha: 0.5 * fade),
            coreColor.withValues(alpha: 0.0),
          ],
        ).createShader(rectDown)
        ..blendMode = BlendMode.plus
        ..maskFilter = CanvasEffects.blur(beamWidth * 0.4),
    );

    // Bright polar flash where each jet punches through the photon ring.
    canvas.drawCircle(
      Offset.zero,
      holeRadius * (0.5 + strength * 0.35) * fade,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * fade)
        ..blendMode = BlendMode.plus
        ..maskFilter = CanvasEffects.blur(holeRadius * 0.3),
    );

    canvas.restore();
  }
}
