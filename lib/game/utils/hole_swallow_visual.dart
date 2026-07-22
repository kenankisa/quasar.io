import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'canvas_effects.dart';
import 'gravity_scaling.dart';
import 'gravity_visual.dart';

/// Per-entity swallow state — computed once per frame by [HoleSwallowManager].
class SwallowEntityState {
  const SwallowEntityState({
    this.preyProximity = 0,
    this.preyDangerProximity = 0,
    this.predatorRadius = 0,
    this.predatorOffset = Offset.zero,
    this.huntCharge = 0,
  });

  final double preyProximity;
  final double preyDangerProximity;
  final double predatorRadius;
  final Offset predatorOffset;
  final double huntCharge;

  static const none = SwallowEntityState();

  bool get isPrey =>
      preyProximity > GravityScaling.holeSwallowWarningProximityOnset;
  bool get isInDangerZone =>
      preyDangerProximity > GravityScaling.holeSwallowProximityOnset;
  bool get isHunting => huntCharge > 0.1;
}

/// Active predator–prey pair for world-space bridge rendering.
class SwallowPair {
  const SwallowPair({
    required this.predatorPos,
    required this.preyPos,
    required this.predatorRadius,
    required this.preyRadius,
    required this.predatorAccent,
    required this.preyAccent,
    required this.proximity,
    required this.dangerProximity,
    required this.involvesLocal,
  });

  final Vector2 predatorPos;
  final Vector2 preyPos;
  final double predatorRadius;
  final double preyRadius;
  final Color predatorAccent;
  final Color preyAccent;
  final double proximity;
  final double dangerProximity;
  final bool involvesLocal;
}

int swallowEntityKey(Vector2 pos, double radius) =>
    Object.hash(pos.x.round(), pos.y.round(), radius.round());

/// Budgeted, shader-free swallow VFX (EHT-inspired tidal capture).
abstract final class HoleSwallowVisual {
  HoleSwallowVisual._();

  static int maxBridgeBudget() => CanvasEffects.mobileLiteMode ? 1 : 2;

  /// Build ranked swallow pairs — local player always wins a slot when close.
  static List<SwallowPair> rankPairs(
    List<({
      Vector2 position,
      double radius,
      Color accent,
      bool isLocal,
    })> holes,
  ) {
    final candidates = <({SwallowPair pair, double score})>[];

    for (var i = 0; i < holes.length; i++) {
      for (var j = i + 1; j < holes.length; j++) {
        final a = holes[i];
        final b = holes[j];
        final larger = a.radius >= b.radius ? a : b;
        final smaller = a.radius >= b.radius ? b : a;
        if (larger.radius <= smaller.radius) continue;

        final delta = larger.position - smaller.position;
        final distance = delta.length;
        final dangerProximity = GravityVisual.swallowProximity(
          largerRadius: larger.radius,
          smallerRadius: smaller.radius,
          distance: distance,
        );
        final proximity = GravityVisual.swallowVisualProximity(
          largerRadius: larger.radius,
          smallerRadius: smaller.radius,
          distance: distance,
        );
        if (proximity < GravityScaling.holeSwallowWarningProximityOnset) {
          continue;
        }

        final involvesLocal = a.isLocal || b.isLocal;
        // Bridge only in danger band — warning zone is rings only.
        if (dangerProximity < GravityScaling.holeSwallowProximityOnset) {
          if (!involvesLocal) continue;
        } else if (!involvesLocal && dangerProximity < 0.40) {
          continue;
        }

        final pair = SwallowPair(
          predatorPos: larger.position,
          preyPos: smaller.position,
          predatorRadius: larger.radius,
          preyRadius: smaller.radius,
          predatorAccent: larger.accent,
          preyAccent: smaller.accent,
          proximity: proximity,
          dangerProximity: dangerProximity,
          involvesLocal: involvesLocal,
        );
        final score = proximity + (involvesLocal ? 2.0 : 0.0);
        candidates.add((pair: pair, score: score));
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final budget = maxBridgeBudget();
    return candidates.take(budget).map((c) => c.pair).toList();
  }

  /// Derive per-entity states from active pairs.
  static Map<int, SwallowEntityState> statesFromPairs(List<SwallowPair> pairs) {
    final map = <int, SwallowEntityState>{};

    void mergePrey(Vector2 pos, double r, SwallowPair pair) {
      final key = swallowEntityKey(pos, r);
      final offset = Offset(
        pair.predatorPos.x - pos.x,
        pair.predatorPos.y - pos.y,
      );
      final existing = map[key];
      if (existing == null || pair.proximity > existing.preyProximity) {
        map[key] = SwallowEntityState(
          preyProximity: pair.proximity,
          preyDangerProximity: pair.dangerProximity,
          predatorRadius: pair.predatorRadius,
          predatorOffset: offset,
          huntCharge: existing?.huntCharge ?? 0,
        );
      }
    }

    void mergePredator(Vector2 pos, double r, double charge) {
      final key = swallowEntityKey(pos, r);
      final existing = map[key] ?? SwallowEntityState.none;
      map[key] = SwallowEntityState(
        preyProximity: existing.preyProximity,
        preyDangerProximity: existing.preyDangerProximity,
        predatorRadius: existing.predatorRadius,
        predatorOffset: existing.predatorOffset,
        huntCharge: math.max(existing.huntCharge, charge),
      );
    }

    for (final pair in pairs) {
      mergePrey(pair.preyPos, pair.preyRadius, pair);
      mergePredator(
        pair.predatorPos,
        pair.predatorRadius,
        pair.dangerProximity,
      );
    }
    return map;
  }

  /// Tidal stretch on prey canvas — call before [BlackHoleRenderer.paint].
  static void paintPreyDistortion({
    required Canvas canvas,
    required double gameRadius,
    required SwallowEntityState state,
  }) {
    if (!state.isInDangerZone) return;

    GravityVisual.applyHoleTidalStretch(
      canvas: canvas,
      predatorOffset: state.predatorOffset,
      proximity: state.preyDangerProximity,
    );
  }

  /// Fragment debris along tidal axis — call after [BlackHoleRenderer.paint].
  static void paintPreyFragmentation({
    required Canvas canvas,
    required double gameRadius,
    required SwallowEntityState state,
    required Color accent,
  }) {
    if (!state.isInDangerZone || state.preyDangerProximity < 0.18) return;

    GravityVisual.drawPreyHoleFragments(
      canvas: canvas,
      gameRadius: gameRadius,
      predatorOffset: state.predatorOffset,
      proximity: state.preyDangerProximity,
      accent: accent,
    );
  }

  /// Accretion brightening on predator photon ring (0–1).
  static double photonRingBoost(SwallowEntityState state) {
    if (!state.isHunting) return 0;
    return state.huntCharge.clamp(0.0, 1.0);
  }

  /// Compact threat ring on larger holes (single stroke).
  static void paintThreatRing({
    required Canvas canvas,
    required double sourceRadius,
    required double playerRadius,
    required double distance,
    required double pulse,
  }) {
    if (sourceRadius <= playerRadius) return;

    final warning = GravityScaling.holeSwallowWarningDistance(
      largerRadius: sourceRadius,
      smallerRadius: playerRadius,
    );
    if (warning <= 0 || distance > warning * 1.01) return;

    final proximity = GravityVisual.swallowVisualProximity(
      largerRadius: sourceRadius,
      smallerRadius: playerRadius,
      distance: distance,
    );
    if (proximity < GravityScaling.holeSwallowWarningProximityOnset) return;

    final capture = GravityScaling.holeCaptureDistance(
      largerRadius: sourceRadius,
      smallerRadius: playerRadius,
    );
    final inCapture = distance <= capture * 1.02;
    final photonR = sourceRadius *
        GravityScaling.schwarzschildFraction *
        GravityScaling.shadowBoundaryRatio;
    final pulseMul = 0.88 + math.sin(pulse * 4.5) * 0.12;
    final alpha = (inCapture ? 0.42 + proximity * 0.4 : 0.1 + proximity * 0.22) *
        pulseMul;

    canvas.drawCircle(
      Offset.zero,
      photonR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inCapture ? 2.4 : 1.4
        ..color = Color.lerp(
          const Color(0xFFFF4422),
          const Color(0xFFFFCC66),
          inCapture ? 0.55 : proximity * 0.3,
        )!
            .withValues(alpha: alpha.clamp(0.0, 0.88)),
    );
  }

  /// Prey warning — one tightening ring (no marker dots).
  static void paintPreyRing({
    required Canvas canvas,
    required double preyRadius,
    required double predatorRadius,
    required double distance,
    required double pulse,
  }) {
    final proximity = GravityVisual.swallowVisualProximity(
      largerRadius: predatorRadius,
      smallerRadius: preyRadius,
      distance: distance,
    );
    if (proximity < GravityScaling.holeSwallowWarningProximityOnset) return;

    final capture = GravityScaling.holeCaptureDistance(
      largerRadius: predatorRadius,
      smallerRadius: preyRadius,
    );
    final inCapture = distance <= capture * 1.02;
    final pulseMul = 0.9 + math.sin(pulse * 4.0 + 0.8) * 0.1;
    final ringR = preyRadius * (1.14 - proximity * 0.16);
    final alpha = (inCapture ? 0.38 + proximity * 0.42 : 0.1 + proximity * 0.25) *
        pulseMul;

    canvas.drawCircle(
      Offset.zero,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = inCapture ? 2.2 : 1.3
        ..color = Color.lerp(
          const Color(0xFF55DDAA),
          const Color(0xFFFF7755),
          inCapture ? 0.75 : proximity * 0.45,
        )!
            .withValues(alpha: alpha.clamp(0.0, 0.85)),
    );
  }
}
