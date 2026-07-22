import '../components/player.dart';
import '../orbit_game.dart';

/// Growth helpers for lobby filler bots — same ceiling as real players.
class BotLimits {
  BotLimits._();

  static double topRealPlayerRadius(OrbitGame game) {
    var maxR = Player.baseRadius;
    if (!game.player.isEliminated) {
      maxR = game.player.radius;
    }
    for (final enemy in game.enemyPlayers) {
      if (enemy.isEliminated) continue;
      if (enemy.radius > maxR) {
        maxR = enemy.radius;
      }
    }
    return maxR;
  }

  /// Largest alive hole in the room — real players and bots.
  static double topActiveRadius(OrbitGame game) {
    var maxR = topRealPlayerRadius(game);
    for (final bot in game.botPopulation.bots) {
      if (bot.isEliminated) continue;
      if (bot.radius > maxR) {
        maxR = bot.radius;
      }
    }
    return maxR;
  }

  static double radiusCapFor(OrbitGame game) => game.universeVictoryRadius;
}
