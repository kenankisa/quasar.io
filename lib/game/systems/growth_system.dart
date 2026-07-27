import '../components/black_hole_partner.dart';
import '../components/bot_player.dart';
import '../config/first_match_tuning.dart';
import '../config/match_pacing.dart';

/// Single pipeline for food / PvE growth — one place for all room multipliers.
class GrowthSystem {
  const GrowthSystem({
    required this.foodGrowthMultiplier,
    required this.pacing,
    required this.matchElapsed,
    required this.isBotOnlyRoom,
  });

  final double foodGrowthMultiplier;
  final MatchPacing pacing;
  final double matchElapsed;
  final bool isBotOnlyRoom;

  /// Scales a raw growth amount for [consumer] without applying it.
  double scaledAmount(
    double base,
    BlackHolePartner consumer, {
    bool applyEarlyGameBonus = false,
    BotPlayer? bot,
  }) {
    var amount = base * foodGrowthMultiplier;
    if (applyEarlyGameBonus &&
        matchElapsed <= pacing.earlyGameDurationSeconds) {
      amount *= pacing.earlyGamePlayerGrowthMultiplier;
    }
    amount *= pacing.lateGrowthMultiplier(consumer.holeRadius);
    if (bot != null && isBotOnlyRoom) {
      amount *= bot.isPreyBot
          ? FirstMatchTuning.simpleRoomPreyGrowthMultiplier
          : FirstMatchTuning.simpleRoomBotGrowthMultiplier;
    }
    return amount;
  }

  /// Applies scaled growth to [consumer], optionally splitting with a link partner.
  void apply(
    double base,
    BlackHolePartner consumer, {
    bool isPlayer = false,
    BotPlayer? bot,
    BlackHolePartner? linkPartner,
    bool isLinked = false,
  }) {
    if (isPlayer && linkPartner != null && isLinked) {
      final scaled = scaledAmount(base, consumer, applyEarlyGameBonus: true);
      final half = scaled / 2;
      consumer.growBy(half);
      linkPartner.growBy(half);
      consumer.recordAbsorb();
      linkPartner.recordAbsorb();
      return;
    }

    final scaled = scaledAmount(
      base,
      consumer,
      applyEarlyGameBonus: isPlayer,
      bot: bot,
    );
    consumer.growBy(scaled);
    consumer.recordAbsorb();
  }
}
