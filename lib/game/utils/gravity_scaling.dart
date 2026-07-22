import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/player.dart';

/// Newtonian gravity for black holes and consumables.
///
/// Real black holes attract matter with **a = GM / r²** (inverse-square law).
/// Mass is modeled as proportional to volume: M ∝ radius³.
/// A softening term avoids infinite force at the event horizon (Plummer sphere).
class GravityScaling {
  GravityScaling._();

  /// Gameplay-tuned gravitational constant (world units · s⁻² · mass⁻¹).
  static const gravitationalConstant = 35000.0;

  /// Mass scales with black-hole volume: M ∝ (r / r₀)³.
  static const massExponent = 3.0;

  /// Softening length as a fraction of source radius (prevents r → 0 singularity).
  static const softeningFraction = 0.40;

  /// Extra pull between black holes (food uses 1.0).
  static const holeToHolePullMultiplier = 1.2;

  /// Hole-to-hole gravity never reaches beyond this multiple of the swallow band.
  static const holeToHoleInfluenceBandMargin = 0.95;

  /// Below this prey/predator radius ratio, Roche distance blows up — cap physics pull.
  static const holeSwallowPhysicsTinyPreyRatio = 0.22;

  /// Max physics reach for predator-on-tiny-prey (multiples of predator radius).
  static const holeSwallowPhysicsMaxPredatorRadii = 5.0;

  /// Weak mutual tug when two holes are similar size (cannot swallow).
  static const holeToHoleSimilarSizeInfluenceFactor = 0.32;

  /// Accelerations below this are skipped for performance.
  static const minAcceleration = 1.2;

  /// Food/tidal queries cap here — uncapped r≈500 reach spans the whole map
  /// and stalls web frames near endgame zoom-out.
  static const consumableInfluenceRadiusCap = 1280.0;

  /// Normalized mass from visual radius (Schwarzschild-radius proxy).
  static double massFromRadius(double radius) =>
      math.pow(radius / Player.baseRadius, massExponent).toDouble();

  /// Squared effective distance: r² + ε² (Plummer softening).
  static double softenedDistanceSquared(double distance, double sourceRadius) {
    final epsilon = sourceRadius * softeningFraction;
    return distance * distance + epsilon * epsilon;
  }

  /// Newtonian acceleration magnitude toward a point mass: **a = GM / r²**.
  ///
  /// [roomMultiplier] scales food pull per room config without changing physics shape.
  static double accelerationToward({
    required double sourceRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) {
    if (distance < 0.5 || sourceRadius < 1) return 0;

    final mass = massFromRadius(sourceRadius);
    final r2 = softenedDistanceSquared(distance, sourceRadius);
    final accel =
        gravitationalConstant * mass * roomMultiplier / r2;

    if (accel < minAcceleration) return 0;
    return accel;
  }

  /// Distance where acceleration drops below [minAcceleration] (culling range).
  static double influenceRadius(
    double sourceRadius, {
    double roomMultiplier = 1.0,
    bool capForConsumables = false,
  }) {
    if (sourceRadius < 1) return 0;

    final mass = massFromRadius(sourceRadius);
    final epsilon = sourceRadius * softeningFraction;
    final threshold = minAcceleration / (gravitationalConstant * roomMultiplier);
    final inner = mass / threshold - epsilon * epsilon;
    if (inner <= 0) return sourceRadius * 2;
    final reach = math.sqrt(inner);
    if (!capForConsumables) return reach;
    return math.min(reach, consumableInfluenceRadiusCap);
  }

  /// Culling radius for food pull + tidal VFX near huge holes.
  static double consumableInfluenceRadius(
    double sourceRadius, {
    double roomMultiplier = 1.0,
  }) =>
      influenceRadius(
        sourceRadius,
        roomMultiplier: roomMultiplier,
        capForConsumables: true,
      );

  /// Schwarzschild proxy from gameplay radius (matches [BlackHoleRenderer]).
  static const schwarzschildFraction = 0.34;

  /// EHT shadow / photon-ring boundary: (3√3/2) r_s.
  static const shadowBoundaryRatio = 2.598;

  /// Normalized Roche intensity where visible spaghettification begins.
  ///
  /// 0.40 ≈ 1.36× Roche distance — noticeable tidal stretch, not breakup yet.
  /// (0.04 was ~2.9× Roche, far too early for physics or readability.)
  static const consumableTidalOnsetIntensity = 0.40;

  /// Visual spaghettification uses a capped Roche reference so huge holes do
  /// not stretch food across the entire map.
  static const consumableTidalVisualSourceRadiusCap = 2.35;

  /// Visual onset — tighter than physics pull feedback.
  static const consumableTidalVisualOnsetIntensity = 0.58;

  /// Hard outer stop for spaghettification VFX (hole + prey size).
  static const consumableTidalVisualMaxDistanceSourceRadii = 2.65;
  static const consumableTidalVisualMaxDistanceEntityRadii = 2.5;

  /// Swallow VFX band ends this factor past Roche disruption (hole vs hole).
  static const holeSwallowApproachRocheFactor = 1.05;

  /// Outer warning ring — farther than physics pull ([holeToHoleInfluenceBandMargin]).
  static const holeSwallowWarningBandFactor = 1.30;

  /// Visual proximity at the physics approach boundary (warning → danger handoff).
  static const holeSwallowWarningMaxProximity = 0.18;

  /// Minimum visual proximity before warning rings render.
  static const holeSwallowWarningProximityOnset = 0.04;

  /// Minimum normalized swallow proximity before danger-zone VFX (bridge, tidal).
  static const holeSwallowProximityOnset = 0.12;

  /// Normalized proximity before inspiral physics begins (well inside Roche band).
  ///
  /// VFX can warn earlier at [holeSwallowProximityOnset]; gameplay pull starts here.
  static const holeInspiralOnsetProximity = 0.32;

  /// Normalized proximity where prey can no longer steer away (point of no return).
  static const holeInspiralLockProximity = 0.45;

  /// Base inspiral infall speed at full proximity (world units · s⁻¹).
  static const holeInspiralBaseSpeed = 220.0;

  /// Inspiral speed scales as (M_pred / M_prey)^(1/2) — capped for huge ratios.
  static const holeInspiralMaxMassRatioScale = 12.0;

  /// Physics-only swallow band — capped for tiny prey (Roche M∝r³ blow-up).
  ///
  /// Visual warning still uses [holeSwallowApproachDistance] so small players
  /// see danger rings before gameplay pull begins.
  static double holeSwallowPhysicsApproachDistance({
    required double largerRadius,
    required double smallerRadius,
  }) {
    final full = holeSwallowApproachDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    if (full <= 0) return 0;

    final preyRatio = smallerRadius / largerRadius;
    if (preyRatio >= holeSwallowPhysicsTinyPreyRatio) return full;

    final capture = holeCaptureDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    final ratioT = (preyRatio / holeSwallowPhysicsTinyPreyRatio).clamp(0.12, 1.0);
    final preyAware = largerRadius *
        holeSwallowPhysicsMaxPredatorRadii *
        math.pow(ratioT, 0.38);
    final floor = capture > 0 ? capture * 1.25 : largerRadius * 1.8;
    final cap = largerRadius * holeSwallowPhysicsMaxPredatorRadii;
    return math.min(full, preyAware.clamp(floor, cap));
  }

  /// Reach of [sourceRadius] pulling [targetRadius] — asymmetric per direction.
  static double holeToHolePullInfluenceRadius({
    required double sourceRadius,
    required double targetRadius,
  }) {
    if (sourceRadius < 1) return 0;

    if (sourceRadius > targetRadius * 1.04) {
      final band = holeSwallowPhysicsApproachDistance(
        largerRadius: sourceRadius,
        smallerRadius: targetRadius,
      );
      if (band > 0) {
        return math.min(
          influenceRadius(sourceRadius),
          band * holeToHoleInfluenceBandMargin,
        );
      }
    }

    if (sourceRadius >= targetRadius * 0.96) {
      return influenceRadius(sourceRadius) * holeToHoleSimilarSizeInfluenceFactor;
    }

    return influenceRadius(sourceRadius);
  }

  /// Symmetric pair reach — max of both pull directions (tests / diagnostics).
  static double holeToHoleInfluenceRadius({
    required double holeRadiusA,
    required double holeRadiusB,
  }) {
    return math.max(
      holeToHolePullInfluenceRadius(
        sourceRadius: holeRadiusA,
        targetRadius: holeRadiusB,
      ),
      holeToHolePullInfluenceRadius(
        sourceRadius: holeRadiusB,
        targetRadius: holeRadiusA,
      ),
    );
  }

  /// Inspiral infall speed from mass ratio and normalized swallow proximity.
  static double holeInspiralSpeed({
    required double predatorRadius,
    required double preyRadius,
    required double proximity,
    required bool locked,
  }) {
    if (proximity <= 0 || predatorRadius <= preyRadius) return 0;

    final massRatio =
        math.pow(predatorRadius / preyRadius, massExponent).toDouble();
    final scale = math.sqrt(massRatio).clamp(1.0, holeInspiralMaxMassRatioScale);

    if (!locked) {
      if (proximity < holeInspiralOnsetProximity) return 0;
      final span = holeInspiralLockProximity - holeInspiralOnsetProximity;
      if (span <= 0) return 0;
      final t = ((proximity - holeInspiralOnsetProximity) / span).clamp(0.0, 1.0);
      // Quadratic ramp — gentle assist, escapable with boost.
      return holeInspiralBaseSpeed * scale * t * t * 0.28;
    }

    final ramp = 0.55 + proximity * 0.45;
    return holeInspiralBaseSpeed * scale * ramp;
  }

  /// Distance below which a smaller hole is swallowed by a larger one.
  ///
  /// The prey crosses the predator's photon-ring shell (shadow boundary) and its
  /// own event horizon enters that region — consistent with EHT critical-curve
  /// capture, not arbitrary gameplay-radius overlap.
  static double holeCaptureDistance({
    required double largerRadius,
    required double smallerRadius,
  }) {
    if (largerRadius <= smallerRadius) return 0;

    final largeShadow =
        largerRadius * schwarzschildFraction * shadowBoundaryRatio;
    final smallHorizon = smallerRadius * schwarzschildFraction;
    return largeShadow + smallHorizon * 0.42;
  }

  /// Distance at which tidal stretch / swallow VFX begin (before capture).
  ///
  /// Uses the larger of capture-margin and Roche disruption distance so VFX
  /// ramps where spaghettification would physically begin.
  static double holeSwallowApproachDistance({
    required double largerRadius,
    required double smallerRadius,
  }) {
    final capture = holeCaptureDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    if (capture <= 0) return 0;
    final roche = rocheDisruptionDistance(
      sourceRadius: largerRadius,
      entityRadius: smallerRadius,
    );
    return math.max(capture * 1.15, roche * holeSwallowApproachRocheFactor);
  }

  /// Distance at which prey warning rings appear (before physics pull).
  static double holeSwallowWarningDistance({
    required double largerRadius,
    required double smallerRadius,
  }) {
    final approach = holeSwallowApproachDistance(
      largerRadius: largerRadius,
      smallerRadius: smallerRadius,
    );
    if (approach <= 0) return 0;
    return approach * holeSwallowWarningBandFactor;
  }

  /// Roche / tidal disruption radius for equal-density bodies (M ∝ r³).
  ///
  /// d_Roche ≈ R_bh · (2 M_bh / M_body)^(1/3) → R_bh · (2 (R_bh/R_body)³)^(1/3)
  static double rocheDisruptionDistance({
    required double sourceRadius,
    required double entityRadius,
  }) {
    if (sourceRadius < 1 || entityRadius < 0.5) return 0;
    final massRatio = math.pow(sourceRadius / entityRadius, 3).toDouble();
    return sourceRadius * math.pow(2.0 * massRatio, 1 / 3.0);
  }

  /// Tidal acceleration difference across a body: Δa ≈ 2 G M R_body / r³.
  static double tidalAcceleration({
    required double sourceRadius,
    required double entityRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) {
    if (distance < 0.5 || sourceRadius < 1 || entityRadius < 0.5) return 0;
    final mass = massFromRadius(sourceRadius);
    final r3 = distance * distance * distance;
    return 2 *
        gravitationalConstant *
        mass *
        roomMultiplier *
        entityRadius /
        r3;
  }

  /// Normalized tidal stress (0 = far, 1 ≈ Roche limit, >1 inside disruption).
  static double consumableTidalIntensity({
    required double sourceRadius,
    required double entityRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) {
    final roche = rocheDisruptionDistance(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
    );
    if (roche <= 0) return 0;

    final tidal = tidalAcceleration(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
    final tidalAtRoche = tidalAcceleration(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: roche,
      roomMultiplier: roomMultiplier,
    );
    if (tidalAtRoche <= 0) return 0;
    return (tidal / tidalAtRoche).clamp(0.0, 1.35);
  }

  /// Capped Roche distance used only for consumable spaghettification VFX.
  static double consumableTidalVisualReferenceRoche({
    required double sourceRadius,
    required double entityRadius,
  }) {
    final physics = rocheDisruptionDistance(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
    );
    if (physics <= 0) return 0;
    final cap = sourceRadius * consumableTidalVisualSourceRadiusCap;
    return math.min(physics, cap);
  }

  /// Tidal stress for **visual** spaghettification — shorter range than physics.
  static double consumableTidalVisualIntensity({
    required double sourceRadius,
    required double entityRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) {
    if (distance < 0.5 || sourceRadius < 1 || entityRadius < 0.5) return 0;

    final maxDist = sourceRadius * consumableTidalVisualMaxDistanceSourceRadii +
        entityRadius * consumableTidalVisualMaxDistanceEntityRadii;
    if (distance > maxDist) return 0;

    final roche = consumableTidalVisualReferenceRoche(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
    );
    if (roche <= 0) return 0;

    final tidal = tidalAcceleration(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
    final tidalAtRoche = tidalAcceleration(
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      distance: roche,
      roomMultiplier: roomMultiplier,
    );
    if (tidalAtRoche <= 0) return 0;
    return (tidal / tidalAtRoche).clamp(0.0, 1.35);
  }

  /// World position on the photon ring where infalling matter crosses the shadow.
  static Vector2 photonRingEntryPoint({
    required Vector2 predatorPosition,
    required Vector2 preyPosition,
    required double predatorRadius,
  }) {
    final delta = preyPosition - predatorPosition;
    final distance = delta.length;
    if (distance < 0.001) return predatorPosition.clone();

    final dir = delta / distance;
    final photonR =
        predatorRadius * schwarzschildFraction * shadowBoundaryRatio;
    return predatorPosition + dir * photonR * 0.92;
  }

  /// Velocity / position delta from gravitational acceleration over [dt].
  static double displacement({
    required double sourceRadius,
    required double distance,
    required double dt,
    double roomMultiplier = 1.0,
    double bonusMultiplier = 1.0,
  }) {
    final accel = accelerationToward(
      sourceRadius: sourceRadius,
      distance: distance,
      roomMultiplier: roomMultiplier,
    );
    if (accel <= 0) return 0;
    return accel * bonusMultiplier * dt;
  }
}
