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

    for (final mine in List<CosmicMine>.from(spawn.mines)) {
      if (!mine.active) continue;
      if (consumer.isSpawnProtected) continue;
      if (r <= CosmicMine.triggerRadius) continue;
      if (overlaps(
        pos,
        r,
        mine.position,
        CosmicMine.collisionRadius,
        factor: mineOverlapFactor,
      )) {
        spawn.triggerMineExplosionFor(mine, consumer);
      }
    }

    for (final asteroid in List<Asteroid>.from(spawn.asteroids)) {
      if (!asteroid.active) continue;
      if (overlaps(pos, r, asteroid.position, asteroid.collisionRadius)) {
        spawn.absorbAsteroidFor(asteroid, consumer);
      }
    }

    for (final planet in List<Planet>.from(spawn.planets)) {
      if (!planet.active) continue;
      if (overlaps(pos, r, planet.position, planet.collisionRadius)) {
        spawn.absorbPlanetFor(planet, consumer);
      }
    }

    for (final fragment in List<QuasarFragment>.from(spawn.quasarFragments)) {
      if (!fragment.active) continue;
      if (overlaps(pos, r, fragment.position, fragment.collisionRadius)) {
        spawn.absorbQuasarFragmentFor(fragment, consumer);
      }
    }

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

    for (final shield in List<ShieldPowerUp>.from(spawn.shields)) {
      if (!shield.active) continue;
      if (overlaps(pos, r, shield.position, ShieldPowerUp.collisionRadius, factor: 1)) {
        spawn.collectShieldFor(shield, consumer);
      }
    }
  }
}
