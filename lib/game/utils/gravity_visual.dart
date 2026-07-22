import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'gravity_consumable_paint.dart';
import 'gravity_hole_fx.dart';
import 'tidal_deform_state.dart';

export 'tidal_deform_state.dart';

/// Visual helpers for Newtonian gravity: lensing halos, infall streams, spaghettification.
class GravityVisual {
  GravityVisual._();

  /// Normalized tidal stress for consumables (Roche-based, physics / spin).
  static double consumableTidalIntensity({
    required double sourceRadius,
    required double entityRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) =>
      GravityConsumablePaint.consumableTidalIntensity(
        sourceRadius: sourceRadius,
        entityRadius: entityRadius,
        distance: distance,
        roomMultiplier: roomMultiplier,
      );

  /// Tidal stress for spaghettification VFX only (shorter range when holes grow).
  static double consumableTidalVisualIntensity({
    required double sourceRadius,
    required double entityRadius,
    required double distance,
    double roomMultiplier = 1.0,
  }) =>
      GravityConsumablePaint.consumableTidalVisualIntensity(
        sourceRadius: sourceRadius,
        entityRadius: entityRadius,
        distance: distance,
        roomMultiplier: roomMultiplier,
      );

  /// Self-spin retention under tidal stress (0 = fully locked to the infall axis).
  static double tidalSpinRetain(double intensity) =>
      GravityConsumablePaint.tidalSpinRetain(intensity);

  /// Whether tidal locking should freeze self-rotation accumulation.
  static bool shouldFreezeSpin(double intensity) =>
      GravityConsumablePaint.shouldFreezeSpin(intensity);

  /// Screen radius (px) below which tidal VFX are skipped (default case).
  static const consumableTidalMinScreenPx =
      GravityConsumablePaint.consumableTidalMinScreenPx;

  /// Streak / fragment LOD: no tail below this on-screen radius.
  static const consumableStreakLodMinScreenPx =
      GravityConsumablePaint.consumableStreakLodMinScreenPx;

  /// Streak / fragment LOD: full tail at and above this on-screen radius.
  static const consumableStreakLodFullScreenPx =
      GravityConsumablePaint.consumableStreakLodFullScreenPx;

  /// World radius → on-screen radius in logical pixels (Flame viewfinder zoom).
  static double consumableScreenRadiusPx(double worldRadius, double cameraZoom) =>
      GravityConsumablePaint.consumableScreenRadiusPx(worldRadius, cameraZoom);

  /// Minimum on-screen radius before drawing any tidal VFX.
  ///
  /// Stronger tidal stress keeps spaghettification on small collectibles so
  /// every food type behaves consistently near a hole.
  static double consumableTidalMinScreenForIntensity(double tidalIntensity) =>
      GravityConsumablePaint.consumableTidalMinScreenForIntensity(tidalIntensity);

  /// Scales infall streak + debris (0 = no tail, 1 = full tail).
  ///
  /// Body stretch always follows physics; this only gates the long noodle tail.
  /// High tidal intensity guarantees a visible tail on small on-screen dots.
  static double consumableStreakLodFromScreen(
    double entityScreenRadiusPx, {
    double tidalIntensity = 0,
  }) =>
      GravityConsumablePaint.consumableStreakLodFromScreen(
        entityScreenRadiusPx,
        tidalIntensity: tidalIntensity,
      );

  /// Exponential decay applied to stored spin while tidally locked.
  static double decayLockedSpin(double spin, double dt) =>
      GravityConsumablePaint.decayLockedSpin(spin, dt);

  static void clearTidalAxis(int axisKey) =>
      GravityConsumablePaint.clearTidalAxis(axisKey);

  /// Smooth tidal-axis tracking — avoids jitter when the predator moves.
  static double smoothedTidalAngle({
    required int axisKey,
    required double targetAngle,
    required double intensity,
  }) =>
      GravityConsumablePaint.smoothedTidalAngle(
        axisKey: axisKey,
        targetAngle: targetAngle,
        intensity: intensity,
      );

  /// Compute tidal deformation for a consumable pulled toward a black hole.
  static TidalDeformState? tidalDeformForConsumable({
    required Vector2 entityWorldPosition,
    required Vector2 sourceWorldPosition,
    required double sourceRadius,
    required double entityRadius,
    double roomMultiplier = 1.0,
  }) =>
      GravityConsumablePaint.tidalDeformForConsumable(
        entityWorldPosition: entityWorldPosition,
        sourceWorldPosition: sourceWorldPosition,
        sourceRadius: sourceRadius,
        entityRadius: entityRadius,
        roomMultiplier: roomMultiplier,
      );

  /// Paint a consumable body with scientifically-inspired tidal deformation.
  ///
  /// The body stretches toward the hole, compresses perpendicular to the tidal
  /// axis, sheds visual mass, and fragments along the infall stream.
  static void paintConsumableWithTides({
    required Canvas canvas,
    required Vector2 entityWorldPosition,
    required Vector2 sourceWorldPosition,
    required double sourceRadius,
    required double entityRadius,
    required Color accent,
    required Color bodyColor,
    double roomMultiplier = 1.0,
    double spinAngle = 0,
    int? tidalAxisKey,
    double cameraZoom = 1.0,
    double animationPhase = 0,
    required void Function(Canvas canvas, double visualRadius) paintBody,
  }) =>
      GravityConsumablePaint.paintConsumableWithTides(
        canvas: canvas,
        entityWorldPosition: entityWorldPosition,
        sourceWorldPosition: sourceWorldPosition,
        sourceRadius: sourceRadius,
        entityRadius: entityRadius,
        accent: accent,
        bodyColor: bodyColor,
        roomMultiplier: roomMultiplier,
        spinAngle: spinAngle,
        tidalAxisKey: tidalAxisKey,
        cameraZoom: cameraZoom,
        animationPhase: animationPhase,
        paintBody: paintBody,
      );

  /// Curved infall streamlines spiraling into the event horizon (on-hole VFX).
  static void drawInfallStreamlines({
    required Canvas canvas,
    required double diskR,
    required double coreR,
    required List<Color> hot,
    required double spin,
    required double intensity,
  }) =>
      GravityHoleFx.drawInfallStreamlines(
        canvas: canvas,
        diskR: diskR,
        coreR: coreR,
        hot: hot,
        spin: spin,
        intensity: intensity,
      );

  static double holeVisualIntensity(double gameRadius) =>
      GravityHoleFx.holeVisualIntensity(gameRadius);

  static double swallowProximity({
    required double largerRadius,
    required double smallerRadius,
    required double distance,
  }) =>
      GravityHoleFx.swallowProximity(
        largerRadius: largerRadius,
        smallerRadius: smallerRadius,
        distance: distance,
      );

  /// Warning + danger visual proximity (0 = at warning edge, 1 = capture).
  ///
  /// Outer band shows rings only; bridge / spaghettification use [swallowProximity].
  static double swallowVisualProximity({
    required double largerRadius,
    required double smallerRadius,
    required double distance,
  }) =>
      GravityHoleFx.swallowVisualProximity(
        largerRadius: largerRadius,
        smallerRadius: smallerRadius,
        distance: distance,
      );

  /// Spaghettification on a prey hole — radial stretch toward the predator.
  static void applyHoleTidalStretch({
    required Canvas canvas,
    required Offset predatorOffset,
    required double proximity,
  }) =>
      GravityHoleFx.applyHoleTidalStretch(
        canvas: canvas,
        predatorOffset: predatorOffset,
        proximity: proximity,
      );

  /// Mass stripped from a prey hole along the tidal axis during inspiral.
  static void drawPreyHoleFragments({
    required Canvas canvas,
    required double gameRadius,
    required Offset predatorOffset,
    required double proximity,
    required Color accent,
  }) =>
      GravityHoleFx.drawPreyHoleFragments(
        canvas: canvas,
        gameRadius: gameRadius,
        predatorOffset: predatorOffset,
        proximity: proximity,
        accent: accent,
      );

  static ({Vector2 position, double radius})? dominantSource(
    Vector2 worldPos,
    List<({Vector2 position, double radius})> sources, {
    double roomMultiplier = 1.0,
  }) =>
      GravityHoleFx.dominantSource(
        worldPos,
        sources,
        roomMultiplier: roomMultiplier,
      );
}
