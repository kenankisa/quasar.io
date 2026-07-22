import '../components/player.dart';
import '../room_type.dart';
import 'bot_difficulty.dart';

/// Onboarding knobs for new players — training fills to 20 entities (1 + bots).
class FirstMatchTuning {
  const FirstMatchTuning._();

  static const hintDurationSeconds = 30.0;
  static const starterClusterCount = 5;

  static bool isFirstMatch({
    required bool tutorialCompleted,
    int gamesWon = 0,
  }) =>
      !tutorialCompleted && gamesWon == 0;

  /// Yutulma / erken çıkış cezası — lobi kartlarıyla aynı (Normal −1, Elit −2, Eşsiz −3).
  static int eliminationPenalty({
    required RoomType roomType,
    required int gamesWon,
  }) {
    // gamesWon reserved for future onboarding knobs; penalty is per room type.
    return roomType.eliminationDiamondPenalty;
  }

  static double spawnProtectionDuration({
    required RoomType roomType,
    required bool isFirstMatch,
  }) {
    if (isFirstMatch) return 6.0;
    if (roomType == RoomType.simple) return 5.0;
    return Player.spawnProtectionDuration;
  }

  static bool shouldSpawnStarterCluster({
    required RoomType roomType,
    required bool isFirstMatch,
  }) =>
      roomType == RoomType.simple || isFirstMatch;

  static bool shouldShowHints(bool isFirstMatch) => isFirstMatch;

  static bool shouldRecommendSimpleRoom({
    required bool tutorialCompleted,
    int gamesWon = 0,
  }) =>
      isFirstMatch(tutorialCompleted: tutorialCompleted, gamesWon: gamesWon);

  /// Basit oda herkes için bot-only başlangıç/tutorial odasıdır.
  static bool isBotOnlyRoom(RoomType roomType) => roomType == RoomType.simple;

  /// Basit odada yutulabilir kolay av bot sayısı (geri kalanlar normal).
  static const simpleRoomPreyBotCount = 4;

  /// Basit odada normal botların yiyecek büyüme çarpanı (hafif yavaşlatma).
  static const simpleRoomBotGrowthMultiplier = 0.9;

  /// Kolay av botların yiyecek büyüme çarpanı.
  static const simpleRoomPreyGrowthMultiplier = 0.5;

  /// Basit odada kolay av botların maksimum yarıçapı — oyuncu yakalayabilsin.
  static const simpleRoomPreyRadiusCap = 55.0;

  static BotDifficulty adjustBotDifficulty(
    BotDifficulty base, {
    required RoomType roomType,
    required bool isFirstMatch,
  }) {
    if (!isFirstMatch) return base;
    return BotDifficulty(
      decisionIntervalMin: base.decisionIntervalMin * 1.08,
      decisionIntervalMax: base.decisionIntervalMax * 1.08,
      preySizeRatio: base.preySizeRatio,
      threatSizeRatio: base.threatSizeRatio,
      preySearchMultiplier: base.preySearchMultiplier,
      foodSearchMultiplier: base.foodSearchMultiplier,
      huntPriority: base.huntPriority * 0.85,
      eventAwareness: base.eventAwareness,
      mineAvoidance: base.mineAvoidance,
      startRadiusMin: base.startRadiusMin,
      startRadiusMax: base.startRadiusMax,
      personalityWeights: base.personalityWeights,
      interceptPrey: base.interceptPrey,
      minHuntRadius: base.minHuntRadius * 1.1,
      playerTargetBias: base.playerTargetBias * 0.7,
    );
  }
}
