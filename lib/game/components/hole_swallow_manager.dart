import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/hole_swallow_visual.dart';

/// Single update pass computing per-entity proximity state (warning rings,
/// tidal stretch, hunt glow) for hole-vs-hole encounters.
///
/// Bridge / merger visuals are owned by [GravityPhysicsManager]'s staged
/// binary-merger sequence — this manager only feeds the renderers.
class HoleSwallowManager extends Component with HasGameReference<OrbitGame> {
  HoleSwallowManager() : super(priority: 4);

  static const _rebuildHz = 20.0;

  List<SwallowPair> _pairs = const [];
  Map<int, SwallowEntityState> _states = const {};
  double _rebuildAccum = 0;

  SwallowEntityState stateFor(Vector2 position, double radius) {
    return _states[swallowEntityKey(position, radius)] ?? SwallowEntityState.none;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rebuildAccum += dt;
    if (_rebuildAccum < 1 / _rebuildHz) return;
    _rebuildAccum = 0;
    _rebuild();
  }

  void _rebuild() {
    final holes = <({
      Vector2 position,
      double radius,
      Color accent,
      bool isLocal,
    })>[];

    for (final entry in game.holeIndex.entries) {
      holes.add((
        position: entry.position,
        radius: entry.radius,
        accent: entry.accent,
        isLocal: entry.isLocalPlayer,
      ));
    }

    _pairs = HoleSwallowVisual.rankPairs(holes);
    _states = HoleSwallowVisual.statesFromPairs(_pairs);
  }
}
