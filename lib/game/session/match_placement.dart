/// Placement after someone else wins (human or bot).
///
/// Winner is always #1. Local placement is `2 + count of larger alive holes`
/// excluding the winner. Returns null when the local player is already out.
abstract final class MatchPlacement {
  MatchPlacement._();

  static int? localAfterWinner({
    required bool localEliminated,
    required double localRadius,
    required String winnerId,
    required String winnerName,
    required bool winnerIsBot,
    required Iterable<CompetitorStandings> bots,
    required Iterable<CompetitorStandings> enemies,
  }) {
    if (localEliminated) return null;

    var aheadOfUs = 0;
    for (final bot in bots) {
      if (bot.eliminated) continue;
      if (winnerIsBot && _isWinningBot(bot, winnerId, winnerName)) continue;
      if (bot.radius > localRadius) aheadOfUs++;
    }
    for (final enemy in enemies) {
      if (enemy.eliminated) continue;
      if (!winnerIsBot && enemy.networkId == winnerId) continue;
      if (enemy.radius > localRadius) aheadOfUs++;
    }
    return 2 + aheadOfUs;
  }

  static bool _isWinningBot(
    CompetitorStandings bot,
    String winnerId,
    String winnerName,
  ) {
    if (bot.networkId == winnerId) return true;
    if (bot.displayName == winnerName) return true;
    // Host broadcasts closed rooms as `bot:<displayName>`.
    if (winnerId == 'bot:${bot.displayName}') return true;
    return false;
  }
}

/// Minimal standings snapshot for placement (avoids coupling to Flame types).
class CompetitorStandings {
  const CompetitorStandings({
    required this.networkId,
    required this.displayName,
    required this.radius,
    required this.eliminated,
  });

  final String networkId;
  final String displayName;
  final double radius;
  final bool eliminated;
}
