import 'dart:math' as math;

import 'package:flame/components.dart';

import 'gravity_scaling.dart';

/// Velocity-based Newtonian infall with conserved angular momentum (spiral orbits)
/// and tidal dissipation near the Roche limit.
///
/// Replaces direct position snapping so consumables arc into black holes
/// instead of sliding linearly — physically a ∝ GM/r² with L = m·v_t·r.
abstract final class GravityMotion {
  GravityMotion._();

  /// Radial acceleration toward [sourcePosition] (world units · s⁻²).
  static double radialAcceleration({
    required double sourceRadius,
    required double distance,
    double roomMultiplier = 1.0,
    double bonusMultiplier = 1.0,
  }) {
    final accel = GravityScaling.accelerationToward(
      sourceRadius: sourceRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
    if (accel <= 0) return 0;
    return accel * bonusMultiplier;
  }

  /// Max influence radius for culling — consumables use capped reach.
  static double influenceRadius({
    required double sourceRadius,
    double roomMultiplier = 1.0,
    bool capForConsumables = true,
  }) =>
      GravityScaling.influenceRadius(
        sourceRadius,
        roomMultiplier: roomMultiplier,
        capForConsumables: capForConsumables,
      );

  /// Accelerates [velocity] toward a point mass. Returns true if force applied.
  static bool accelerateToward({
    required Vector2 entityPosition,
    required Vector2 entityVelocity,
    required Vector2 sourcePosition,
    required double sourceRadius,
    required double entityRadius,
    required double dt,
    double roomMultiplier = 1.0,
    double bonusMultiplier = 1.0,
    bool capInfluence = true,
    bool enableOrbitalInfall = true,
  }) {
    final delta = sourcePosition - entityPosition;
    final distance = delta.length;
    if (distance < 0.5 || dt <= 0) return false;

    final reach = influenceRadius(
      sourceRadius: sourceRadius,
      roomMultiplier: roomMultiplier,
      capForConsumables: capInfluence,
    );
    if (distance > reach) return false;

    final radial = delta / distance;
    final accel = radialAcceleration(
      sourceRadius: sourceRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
      bonusMultiplier: bonusMultiplier,
    );
    if (accel <= 0) return false;

    // Newtonian radial infall: Δv_r = a·dt
    entityVelocity.addScaled(radial, accel * dt);

    if (enableOrbitalInfall) {
      _applyOrbitalDynamics(
        entityVelocity: entityVelocity,
        radial: radial,
        distance: distance,
        sourceRadius: sourceRadius,
        entityRadius: entityRadius,
        accel: accel,
        dt: dt,
        roomMultiplier: roomMultiplier,
      );
    }

    _clampSpeed(
      entityVelocity: entityVelocity,
      accel: accel,
      distance: distance,
      sourceRadius: sourceRadius,
    );

    return true;
  }

  /// Frame-dragging + angular-momentum spiral: tangential boost, tidal drag inward.
  static void _applyOrbitalDynamics({
    required Vector2 entityVelocity,
    required Vector2 radial,
    required double distance,
    required double sourceRadius,
    required double entityRadius,
    required double accel,
    required double dt,
    required double roomMultiplier,
  }) {
    final tangential = Vector2(-radial.y, radial.x);
    final vTan = entityVelocity.dot(tangential);

    // Specific angular momentum h = v_t · r — grows as r shrinks (Keplerian).
    final massRatio = GravityScaling.massFromRadius(sourceRadius);
    final keplerBoost = math.sqrt(massRatio).clamp(0.6, 14.0);
    final orbitStrength =
        (accel * dt * 0.42 * keplerBoost / math.sqrt(distance + sourceRadius * 0.5))
            .clamp(0.0, accel * dt * 1.8);

    // Bias toward existing prograde motion; seed CCW orbit when nearly radial.
    final prograde = vTan.abs() > 0.8 ? (vTan >= 0 ? 1.0 : -1.0) : 1.0;
    entityVelocity.addScaled(tangential, prograde * orbitStrength);

    // Tidal dissipation — orbital energy radiated as infall (spaghettification).
    final tidal = GravityScaling.consumableTidalIntensity(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
    if (tidal > 0.28) {
      final damp = (tidal * tidal * dt * 3.2).clamp(0.0, 0.72);
      entityVelocity.sub(tangential * (vTan * damp));

      // Radial plunge intensifies inside Roche band (Δa ∝ 1/r³).
      final plunge = tidal * accel * dt * 0.55;
      entityVelocity.addScaled(radial, plunge);
    }
  }

  static void _clampSpeed({
    required Vector2 entityVelocity,
    required double accel,
    required double distance,
    required double sourceRadius,
  }) {
    // Prevent tunneling through the photon sphere while keeping infall dramatic.
    final horizon = sourceRadius * GravityScaling.schwarzschildFraction;
    final proximity = (1 - distance / (horizon * 8 + sourceRadius * 2)).clamp(0.0, 1.0);
    final maxSpeed = accel * (2.8 + proximity * 2.4) + 95 + sourceRadius * 0.35;
    final speed = entityVelocity.length;
    if (speed > maxSpeed) {
      entityVelocity.scale(maxSpeed / speed);
    }
  }
}
