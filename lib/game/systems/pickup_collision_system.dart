import 'package:flame/components.dart';

import '../components/asteroid.dart';
import '../components/black_hole_partner.dart';
import '../components/cosmic_event_manager.dart';
import '../components/cosmic_mine.dart';
import '../components/cosmic_spawn_manager.dart';
import '../components/meteor_dust.dart';
import '../components/planet.dart';
import '../components/quasar_fragment.dart';
import '../components/shield_powerup.dart';

/// Shared food / mine / shield pickup checks for local player and bots.
///
/// Spawn-manager collectibles use a per-frame spatial index for broad-phase
/// culling; event rewards stay linear (low count).
abstract final class PickupCollisionSystem {
  PickupCollisionSystem._();

  static const overlapFactor = 0.85;
  static const mineOverlapFactor = 0.75;
  static const dustCollisionRadius = 6.0;

  static bool overlaps(
    Vector2 aPos,
    double aRadius,
    Vector2 bPos,
    double bRadius, {
    double factor = overlapFactor,
  }) {
    return aPos.distanceTo(bPos) < aRadius + bRadius * factor;
  }

  static void collectFor({
    required BlackHolePartner consumer,
    required CosmicSpawnManager spawn,
    required CosmicEventManager events,
  }) {
    if (consumer.isEliminated) return;

    final pos = consumer.position;
    final r = consumer.holeRadius;

    spawn.forEachPickupNear(pos, r, (ref) {
      switch (ref.kind) {
        case SpawnPickupKind.mine:
          final mine = ref.entity as CosmicMine;
          if (!mine.active) return;
          if (consumer.isSpawnProtected) return;
          if (r <= CosmicMine.triggerRadius) return;
          if (overlaps(
            pos,
            r,
            mine.position,
            CosmicMine.collisionRadius,
            factor: mineOverlapFactor,
          )) {
            spawn.triggerMineExplosionFor(mine, consumer);
          }
        case SpawnPickupKind.asteroid:
          final asteroid = ref.entity as Asteroid;
          if (!asteroid.active) return;
          if (overlaps(pos, r, asteroid.position, asteroid.collisionRadius)) {
            spawn.absorbAsteroidFor(asteroid, consumer);
          }
        case SpawnPickupKind.planet:
          final planet = ref.entity as Planet;
          if (!planet.active) return;
          if (overlaps(pos, r, planet.position, planet.collisionRadius)) {
            spawn.absorbPlanetFor(planet, consumer);
          }
        case SpawnPickupKind.quasarFragment:
          final fragment = ref.entity as QuasarFragment;
          if (!fragment.active) return;
          if (overlaps(pos, r, fragment.position, fragment.collisionRadius)) {
            spawn.absorbQuasarFragmentFor(fragment, consumer);
          }
        case SpawnPickupKind.shield:
          final shield = ref.entity as ShieldPowerUp;
          if (!shield.active) return;
          if (overlaps(
            pos,
            r,
            shield.position,
            ShieldPowerUp.collisionRadius,
            factor: 1,
          )) {
            spawn.collectShieldFor(shield, consumer);
          }
      }
    });

    for (final planet in List<Planet>.from(events.eventPlanets)) {
      if (!planet.active) continue;
      if (overlaps(pos, r, planet.position, planet.collisionRadius)) {
        events.absorbEventPlanetFor(planet, consumer);
      }
    }

    for (final dust in List<MeteorDust>.from(events.meteorDust)) {
      if (!dust.active) continue;
      if (overlaps(pos, r, dust.position, dustCollisionRadius, factor: 1)) {
        events.absorbMeteorDustFor(dust, consumer);
      }
    }
  }
}
