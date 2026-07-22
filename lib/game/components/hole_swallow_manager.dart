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

  List<SwallowPair> _pairs = const [];
  Map<int, SwallowEntityState> _states = const {};

  SwallowEntityState stateFor(Vector2 position, double radius) {
    return _states[swallowEntityKey(position, radius)] ?? SwallowEntityState.none;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rebuild();
  }

  void _rebuild() {
    final holes = <({
      Vector2 position,
      double radius,
      Color accent,
      bool isLocal,
    })>[];

    if (!game.player.isEliminated) {
      holes.add((
        position: game.player.position,
        radius: game.player.radius,
        accent: const Color(0xFFFFAA44),
        isLocal: true,
      ));
    }
    for (final bot in game.botPopulation.bots) {
      if (bot.isEliminated) continue;
      holes.add((
        position: bot.position,
        radius: bot.radius,
        accent: bot.accentColor,
        isLocal: false,
      ));
    }
    for (final enemy in game.enemyPlayers) {
      if (enemy.isEliminated) continue;
      holes.add((
        position: enemy.position,
        radius: enemy.radius,
        accent: const Color(0xFF5599EE),
        isLocal: false,
      ));
    }

    _pairs = HoleSwallowVisual.rankPairs(holes);
    _states = HoleSwallowVisual.statesFromPairs(_pairs);
  }
}
