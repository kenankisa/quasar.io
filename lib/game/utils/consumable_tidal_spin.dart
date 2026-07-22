import 'package:flame/components.dart';

import '../orbit_game.dart';
import 'gravity_visual.dart';

/// Updates consumable spin while black-hole tidal fields are nearby.
double advanceConsumableTidalSpin({
  required double currentSpin,
  required OrbitGame? game,
  required Vector2 position,
  required double entityRadius,
  required double dt,
  required double baseSpinRate,
}) {
  if (game != null) {
    final dominant = GravityVisual.dominantSource(
      position,
      game.activeGravitySources(),
      roomMultiplier: game.roomConfig.gravityMultiplier,
    );
    if (dominant != null) {
      final intensity = GravityVisual.consumableTidalIntensity(
        sourceRadius: dominant.radius,
        entityRadius: entityRadius,
        distance: position.distanceTo(dominant.position),
        roomMultiplier: game.roomConfig.gravityMultiplier,
      );
      if (GravityVisual.shouldFreezeSpin(intensity)) {
        return GravityVisual.decayLockedSpin(currentSpin, dt);
      }
      return currentSpin +
          dt * baseSpinRate * GravityVisual.tidalSpinRetain(intensity);
    }
  }

  return currentSpin + dt * baseSpinRate;
}
