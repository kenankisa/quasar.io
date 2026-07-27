import '../../services/room_tuning_service.dart';
import '../models/room_game_tuning.dart';
import '../room_type.dart';
import '../systems/growth_system.dart';
import 'bot_difficulty.dart';
import 'match_pacing.dart';
import 'room_config.dart';

/// Per-room match knobs loaded once — avoids scattered `forRoom` lookups.
class MatchRules {
  const MatchRules({
    required this.room,
    required this.pacing,
    required this.bots,
    required this.tuning,
  });

  final RoomConfig room;
  final MatchPacing pacing;
  final BotDifficulty bots;
  final RoomGameTuning tuning;

  factory MatchRules.forRoom(RoomType type) => MatchRules(
        room: RoomConfig.forRoom(type),
        pacing: MatchPacing.forRoom(type),
        bots: BotDifficulty.forRoom(type),
        tuning: RoomTuningService.instance.tuningFor(type),
      );

  GrowthSystem growthContext({
    required double matchElapsed,
    required bool isBotOnlyRoom,
  }) =>
      GrowthSystem(
        foodGrowthMultiplier: room.foodGrowthMultiplier,
        pacing: pacing,
        matchElapsed: matchElapsed,
        isBotOnlyRoom: isBotOnlyRoom,
      );
}
