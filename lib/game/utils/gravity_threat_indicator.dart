import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'black_hole_renderer.dart';
import 'gravity_scaling.dart';
import 'hole_swallow_visual.dart';

/// Compact danger / prey rings around black holes (drawn at hole center).
class GravityThreatIndicator {
  GravityThreatIndicator._();

  /// Readable pull-warning radius (subset of physics influence for UI clarity).
  static double threatPullRadius({
    required double sourceRadius,
    required double playerRadius,
  }) {
    final capture = GravityScaling.holeCaptureDistance(
      largerRadius: sourceRadius,
      smallerRadius: playerRadius,
    );
    final visualReach = BlackHoleRenderer.visualExtentRadius(sourceRadius);
    return math.max(capture * 1.55, math.max(visualReach * 2.0, sourceRadius * 2.6));
  }

  /// Larger hole threatening the local player.
  static void paintThreat({
    required Canvas canvas,
    required double sourceRadius,
    required double playerRadius,
    required double distanceToPlayer,
    required double pulse,
  }) {
    HoleSwallowVisual.paintThreatRing(
      canvas: canvas,
      sourceRadius: sourceRadius,
      playerRadius: playerRadius,
      distance: distanceToPlayer,
      pulse: pulse,
    );
  }

  /// Smaller prey when the local player can absorb them.
  static void paintPrey({
    required Canvas canvas,
    required double sourceRadius,
    required double playerRadius,
    required double distanceToPlayer,
    required double pulse,
  }) {
    HoleSwallowVisual.paintPreyRing(
      canvas: canvas,
      preyRadius: sourceRadius,
      predatorRadius: playerRadius,
      distance: distanceToPlayer,
      pulse: pulse,
    );
  }
}
