import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/cosmic_particle_presets.dart';
import 'player.dart';
import 'timed_particle_burst.dart';

/// Spawns short Flame particle bursts while the local player hunts prey.
///
/// Attached to [Player] — does not modify black-hole core rendering.
class SwallowHuntParticleAura extends Component with HasGameReference<OrbitGame> {
  SwallowHuntParticleAura() : super(priority: 3);

  double _spawnTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);

    final host = parent;
    if (host is! Player || host.isEliminated) return;

    final state = game.holeSwallowManager.stateFor(host.position, host.radius);
    if (!state.isHunting) {
      _spawnTimer = 0;
      return;
    }

    _spawnTimer -= dt;
    final interval = CanvasEffects.mobileLiteMode
        ? 0.12 - state.huntCharge * 0.035
        : 0.08 - state.huntCharge * 0.03;
    if (_spawnTimer > 0) return;
    _spawnTimer = interval.clamp(0.05, 0.16);

    final maxBursts = CanvasEffects.isNativeMobile ? 5 : 10;
    var active = 0;
    for (final child in host.children) {
      if (child is TimedParticleBurst) active++;
    }
    if (active >= maxBursts) return;

    host.add(
      TimedParticleBurst(
        particle: CosmicParticlePresets.huntInfallSparks(
          holeRadius: host.radius,
          charge: state.huntCharge,
          accent: const Color(0xFFFFAA44),
        ),
        lifespan: CanvasEffects.isNativeMobile ? 0.32 : 0.38,
      ),
    );
  }
}
