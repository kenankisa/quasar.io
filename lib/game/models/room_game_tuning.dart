import '../components/bot_player.dart';
import '../config/bot_difficulty.dart';
import '../config/match_pacing.dart';
import '../config/room_config.dart';
import '../room_type.dart';

/// Admin-tunable per-room game balance (world, pace, events, radiation, bots).
class RoomGameTuning {
  const RoomGameTuning({
    required this.worldSize,
    required this.victoryRadius,
    required this.playerStartRadius,
    required this.foodGrowthMultiplier,
    required this.gravityMultiplier,
    required this.cosmicEventsEnabled,
    required this.asteroidCount,
    required this.meteoriteCount,
    required this.planetCount,
    required this.quasarFragmentCount,
    required this.asteroidTier6Count,
    required this.asteroidTier7Count,
    required this.asteroidTier8Count,
    required this.mineCount,
    required this.targetMinutesMin,
    required this.targetMinutesMax,
    required this.earlyGameDurationSeconds,
    required this.earlyGamePlayerGrowthMultiplier,
    required this.respawnDelayMultiplier,
    required this.supernovaIntervalSeconds,
    required this.supernovaFirstDelaySeconds,
    required this.meteorShowerInitialCooldown,
    required this.eventGrowthCapPerBurst,
    required this.supernovaPlanetCount,
    required this.radiationRadius,
    required this.radiationIdleSeconds,
    required this.lateGameRadiationRadius,
    required this.lateGameRadiationIdleSeconds,
    required this.lateGameRadiationShrinkPerSecond,
    required this.huntPriority,
    required this.botStartRadiusMin,
    required this.botStartRadiusMax,
    required this.decisionIntervalMin,
    required this.decisionIntervalMax,
    required this.preySizeRatio,
    required this.threatSizeRatio,
    required this.preySearchMultiplier,
    required this.foodSearchMultiplier,
    required this.eventAwareness,
    required this.mineAvoidance,
    required this.interceptPrey,
    required this.minHuntRadius,
    required this.playerTargetBias,
    required this.personalityCoward,
    required this.personalityAggressive,
    required this.personalityOpportunist,
  });

  final double worldSize;
  final double victoryRadius;
  final double playerStartRadius;
  final double foodGrowthMultiplier;
  final double gravityMultiplier;
  final bool cosmicEventsEnabled;

  final int asteroidCount;
  final int meteoriteCount;
  final int planetCount;
  final int quasarFragmentCount;
  final int asteroidTier6Count;
  final int asteroidTier7Count;
  final int asteroidTier8Count;
  final int mineCount;

  final double targetMinutesMin;
  final double targetMinutesMax;
  final double earlyGameDurationSeconds;
  final double earlyGamePlayerGrowthMultiplier;
  final double respawnDelayMultiplier;

  final double supernovaIntervalSeconds;
  final double supernovaFirstDelaySeconds;
  final double meteorShowerInitialCooldown;
  final double eventGrowthCapPerBurst;
  final int supernovaPlanetCount;

  final double radiationRadius;
  final double radiationIdleSeconds;
  final double lateGameRadiationRadius;
  final double lateGameRadiationIdleSeconds;
  final double lateGameRadiationShrinkPerSecond;

  final double huntPriority;
  final double botStartRadiusMin;
  final double botStartRadiusMax;
  final double decisionIntervalMin;
  final double decisionIntervalMax;
  final double preySizeRatio;
  final double threatSizeRatio;
  final double preySearchMultiplier;
  final double foodSearchMultiplier;
  final double eventAwareness;
  final double mineAvoidance;
  final bool interceptPrey;
  final double minHuntRadius;
  final double playerTargetBias;
  final int personalityCoward;
  final int personalityAggressive;
  final int personalityOpportunist;

  factory RoomGameTuning.defaultsFor(RoomType type) {
    final room = RoomConfig.presetFor(type);
    final pacing = MatchPacing.presetFor(type);
    final bot = BotDifficulty.presetFor(type);
    return RoomGameTuning(
      worldSize: room.worldSize,
      victoryRadius: type == RoomType.unique ? 550 : 500,
      playerStartRadius: 25,
      foodGrowthMultiplier: room.foodGrowthMultiplier,
      gravityMultiplier: room.gravityMultiplier,
      cosmicEventsEnabled: room.cosmicEventsEnabled,
      asteroidCount: room.asteroidCount,
      meteoriteCount: room.meteoriteCount,
      planetCount: room.planetCount,
      quasarFragmentCount: room.quasarFragmentCount,
      asteroidTier6Count: room.asteroidTier6Count,
      asteroidTier7Count: room.asteroidTier7Count,
      asteroidTier8Count: room.asteroidTier8Count,
      mineCount: room.mineCount,
      targetMinutesMin: pacing.targetMinutesMin,
      targetMinutesMax: pacing.targetMinutesMax,
      earlyGameDurationSeconds: pacing.earlyGameDurationSeconds,
      earlyGamePlayerGrowthMultiplier: pacing.earlyGamePlayerGrowthMultiplier,
      respawnDelayMultiplier: pacing.respawnDelayMultiplier,
      supernovaIntervalSeconds: pacing.supernovaIntervalSeconds,
      supernovaFirstDelaySeconds: pacing.supernovaFirstDelaySeconds,
      meteorShowerInitialCooldown: pacing.meteorShowerInitialCooldown,
      eventGrowthCapPerBurst: pacing.eventGrowthCapPerBurst,
      supernovaPlanetCount: pacing.supernovaPlanetCount,
      radiationRadius: pacing.radiationRadius,
      radiationIdleSeconds: pacing.radiationIdleSeconds,
      lateGameRadiationRadius: pacing.lateGameRadiationRadius,
      lateGameRadiationIdleSeconds: pacing.lateGameRadiationIdleSeconds,
      lateGameRadiationShrinkPerSecond: pacing.lateGameRadiationShrinkPerSecond,
      huntPriority: bot.huntPriority,
      botStartRadiusMin: bot.startRadiusMin,
      botStartRadiusMax: bot.startRadiusMax,
      decisionIntervalMin: bot.decisionIntervalMin,
      decisionIntervalMax: bot.decisionIntervalMax,
      preySizeRatio: bot.preySizeRatio,
      threatSizeRatio: bot.threatSizeRatio,
      preySearchMultiplier: bot.preySearchMultiplier,
      foodSearchMultiplier: bot.foodSearchMultiplier,
      eventAwareness: bot.eventAwareness,
      mineAvoidance: bot.mineAvoidance,
      interceptPrey: bot.interceptPrey,
      minHuntRadius: bot.minHuntRadius,
      playerTargetBias: bot.playerTargetBias,
      personalityCoward: bot.personalityWeights[BotPersonality.coward] ?? 30,
      personalityAggressive:
          bot.personalityWeights[BotPersonality.aggressive] ?? 35,
      personalityOpportunist:
          bot.personalityWeights[BotPersonality.opportunist] ?? 35,
    );
  }

  RoomConfig toRoomConfig(RoomType type) {
    return RoomConfig(
      worldSize: worldSize,
      asteroidCount: asteroidCount,
      meteoriteCount: meteoriteCount,
      planetCount: planetCount,
      quasarFragmentCount: quasarFragmentCount,
      mineCount: mineCount,
      gravityMultiplier: gravityMultiplier,
      foodGrowthMultiplier: foodGrowthMultiplier,
      asteroidTier6Count: asteroidTier6Count,
      asteroidTier7Count: asteroidTier7Count,
      asteroidTier8Count: asteroidTier8Count,
      cosmicEventsEnabled: cosmicEventsEnabled,
    );
  }

  MatchPacing toMatchPacing(RoomType type) {
    var minM = targetMinutesMin;
    var maxM = targetMinutesMax;
    if (maxM < minM) {
      final t = minM;
      minM = maxM;
      maxM = t;
    }
    return MatchPacing(
      targetMinutesMin: minM,
      targetMinutesMax: maxM,
      supernovaIntervalSeconds: supernovaIntervalSeconds,
      supernovaFirstDelaySeconds: supernovaFirstDelaySeconds,
      eventGrowthCapPerBurst: eventGrowthCapPerBurst,
      supernovaPlanetCount: supernovaPlanetCount,
      earlyGameDurationSeconds: earlyGameDurationSeconds,
      earlyGamePlayerGrowthMultiplier: earlyGamePlayerGrowthMultiplier,
      respawnDelayMultiplier: respawnDelayMultiplier,
      meteorShowerInitialCooldown: meteorShowerInitialCooldown,
      radiationRadius: radiationRadius,
      radiationIdleSeconds: radiationIdleSeconds,
      lateGameRadiationRadius: lateGameRadiationRadius,
      lateGameRadiationIdleSeconds: lateGameRadiationIdleSeconds,
      lateGameRadiationShrinkPerSecond: lateGameRadiationShrinkPerSecond,
    );
  }

  BotDifficulty toBotDifficulty(RoomType type) {
    var minD = decisionIntervalMin;
    var maxD = decisionIntervalMax;
    if (maxD < minD) {
      final t = minD;
      minD = maxD;
      maxD = t;
    }
    var minR = botStartRadiusMin;
    var maxR = botStartRadiusMax;
    if (maxR < minR) {
      final t = minR;
      minR = maxR;
      maxR = t;
    }

    final coward = personalityCoward.clamp(0, 100);
    final aggressive = personalityAggressive.clamp(0, 100);
    final opportunist = personalityOpportunist.clamp(0, 100);
    final total = coward + aggressive + opportunist;

    return BotDifficulty.presetFor(type).copyWith(
      huntPriority: huntPriority,
      startRadiusMin: minR,
      startRadiusMax: maxR,
      decisionIntervalMin: minD,
      decisionIntervalMax: maxD,
      preySizeRatio: preySizeRatio,
      threatSizeRatio: threatSizeRatio,
      preySearchMultiplier: preySearchMultiplier,
      foodSearchMultiplier: foodSearchMultiplier,
      eventAwareness: eventAwareness,
      mineAvoidance: mineAvoidance,
      interceptPrey: interceptPrey,
      minHuntRadius: minHuntRadius,
      playerTargetBias: playerTargetBias,
      personalityWeights: {
        BotPersonality.coward: total == 0 ? 1 : coward,
        BotPersonality.aggressive: total == 0 ? 1 : aggressive,
        BotPersonality.opportunist: total == 0 ? 1 : opportunist,
      },
    );
  }

  /// Overwrite only bot / AI fields from a [BotDifficulty] profile.
  RoomGameTuning withBotDifficulty(BotDifficulty bot) {
    return copyWith(
      huntPriority: bot.huntPriority,
      botStartRadiusMin: bot.startRadiusMin,
      botStartRadiusMax: bot.startRadiusMax,
      decisionIntervalMin: bot.decisionIntervalMin,
      decisionIntervalMax: bot.decisionIntervalMax,
      preySizeRatio: bot.preySizeRatio,
      threatSizeRatio: bot.threatSizeRatio,
      preySearchMultiplier: bot.preySearchMultiplier,
      foodSearchMultiplier: bot.foodSearchMultiplier,
      eventAwareness: bot.eventAwareness,
      mineAvoidance: bot.mineAvoidance,
      interceptPrey: bot.interceptPrey,
      minHuntRadius: bot.minHuntRadius,
      playerTargetBias: bot.playerTargetBias,
      personalityCoward: bot.personalityWeights[BotPersonality.coward] ?? 30,
      personalityAggressive:
          bot.personalityWeights[BotPersonality.aggressive] ?? 35,
      personalityOpportunist:
          bot.personalityWeights[BotPersonality.opportunist] ?? 35,
    );
  }

  RoomGameTuning copyWith({
    double? worldSize,
    double? victoryRadius,
    double? playerStartRadius,
    double? foodGrowthMultiplier,
    double? gravityMultiplier,
    bool? cosmicEventsEnabled,
    int? asteroidCount,
    int? meteoriteCount,
    int? planetCount,
    int? quasarFragmentCount,
    int? asteroidTier6Count,
    int? asteroidTier7Count,
    int? asteroidTier8Count,
    int? mineCount,
    double? targetMinutesMin,
    double? targetMinutesMax,
    double? earlyGameDurationSeconds,
    double? earlyGamePlayerGrowthMultiplier,
    double? respawnDelayMultiplier,
    double? supernovaIntervalSeconds,
    double? supernovaFirstDelaySeconds,
    double? meteorShowerInitialCooldown,
    double? eventGrowthCapPerBurst,
    int? supernovaPlanetCount,
    double? radiationRadius,
    double? radiationIdleSeconds,
    double? lateGameRadiationRadius,
    double? lateGameRadiationIdleSeconds,
    double? lateGameRadiationShrinkPerSecond,
    double? huntPriority,
    double? botStartRadiusMin,
    double? botStartRadiusMax,
    double? decisionIntervalMin,
    double? decisionIntervalMax,
    double? preySizeRatio,
    double? threatSizeRatio,
    double? preySearchMultiplier,
    double? foodSearchMultiplier,
    double? eventAwareness,
    double? mineAvoidance,
    bool? interceptPrey,
    double? minHuntRadius,
    double? playerTargetBias,
    int? personalityCoward,
    int? personalityAggressive,
    int? personalityOpportunist,
  }) {
    return RoomGameTuning(
      worldSize: worldSize ?? this.worldSize,
      victoryRadius: victoryRadius ?? this.victoryRadius,
      playerStartRadius: playerStartRadius ?? this.playerStartRadius,
      foodGrowthMultiplier: foodGrowthMultiplier ?? this.foodGrowthMultiplier,
      gravityMultiplier: gravityMultiplier ?? this.gravityMultiplier,
      cosmicEventsEnabled: cosmicEventsEnabled ?? this.cosmicEventsEnabled,
      asteroidCount: asteroidCount ?? this.asteroidCount,
      meteoriteCount: meteoriteCount ?? this.meteoriteCount,
      planetCount: planetCount ?? this.planetCount,
      quasarFragmentCount: quasarFragmentCount ?? this.quasarFragmentCount,
      asteroidTier6Count: asteroidTier6Count ?? this.asteroidTier6Count,
      asteroidTier7Count: asteroidTier7Count ?? this.asteroidTier7Count,
      asteroidTier8Count: asteroidTier8Count ?? this.asteroidTier8Count,
      mineCount: mineCount ?? this.mineCount,
      targetMinutesMin: targetMinutesMin ?? this.targetMinutesMin,
      targetMinutesMax: targetMinutesMax ?? this.targetMinutesMax,
      earlyGameDurationSeconds:
          earlyGameDurationSeconds ?? this.earlyGameDurationSeconds,
      earlyGamePlayerGrowthMultiplier: earlyGamePlayerGrowthMultiplier ??
          this.earlyGamePlayerGrowthMultiplier,
      respawnDelayMultiplier:
          respawnDelayMultiplier ?? this.respawnDelayMultiplier,
      supernovaIntervalSeconds:
          supernovaIntervalSeconds ?? this.supernovaIntervalSeconds,
      supernovaFirstDelaySeconds:
          supernovaFirstDelaySeconds ?? this.supernovaFirstDelaySeconds,
      meteorShowerInitialCooldown:
          meteorShowerInitialCooldown ?? this.meteorShowerInitialCooldown,
      eventGrowthCapPerBurst:
          eventGrowthCapPerBurst ?? this.eventGrowthCapPerBurst,
      supernovaPlanetCount: supernovaPlanetCount ?? this.supernovaPlanetCount,
      radiationRadius: radiationRadius ?? this.radiationRadius,
      radiationIdleSeconds: radiationIdleSeconds ?? this.radiationIdleSeconds,
      lateGameRadiationRadius:
          lateGameRadiationRadius ?? this.lateGameRadiationRadius,
      lateGameRadiationIdleSeconds:
          lateGameRadiationIdleSeconds ?? this.lateGameRadiationIdleSeconds,
      lateGameRadiationShrinkPerSecond: lateGameRadiationShrinkPerSecond ??
          this.lateGameRadiationShrinkPerSecond,
      huntPriority: huntPriority ?? this.huntPriority,
      botStartRadiusMin: botStartRadiusMin ?? this.botStartRadiusMin,
      botStartRadiusMax: botStartRadiusMax ?? this.botStartRadiusMax,
      decisionIntervalMin: decisionIntervalMin ?? this.decisionIntervalMin,
      decisionIntervalMax: decisionIntervalMax ?? this.decisionIntervalMax,
      preySizeRatio: preySizeRatio ?? this.preySizeRatio,
      threatSizeRatio: threatSizeRatio ?? this.threatSizeRatio,
      preySearchMultiplier: preySearchMultiplier ?? this.preySearchMultiplier,
      foodSearchMultiplier: foodSearchMultiplier ?? this.foodSearchMultiplier,
      eventAwareness: eventAwareness ?? this.eventAwareness,
      mineAvoidance: mineAvoidance ?? this.mineAvoidance,
      interceptPrey: interceptPrey ?? this.interceptPrey,
      minHuntRadius: minHuntRadius ?? this.minHuntRadius,
      playerTargetBias: playerTargetBias ?? this.playerTargetBias,
      personalityCoward: personalityCoward ?? this.personalityCoward,
      personalityAggressive:
          personalityAggressive ?? this.personalityAggressive,
      personalityOpportunist:
          personalityOpportunist ?? this.personalityOpportunist,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'worldSize': worldSize,
        'victoryRadius': victoryRadius,
        'playerStartRadius': playerStartRadius,
        'foodGrowthMultiplier': foodGrowthMultiplier,
        'gravityMultiplier': gravityMultiplier,
        'cosmicEventsEnabled': cosmicEventsEnabled,
        'asteroidCount': asteroidCount,
        'meteoriteCount': meteoriteCount,
        'planetCount': planetCount,
        'quasarFragmentCount': quasarFragmentCount,
        'asteroidTier6Count': asteroidTier6Count,
        'asteroidTier7Count': asteroidTier7Count,
        'asteroidTier8Count': asteroidTier8Count,
        'mineCount': mineCount,
        'targetMinutesMin': targetMinutesMin,
        'targetMinutesMax': targetMinutesMax,
        'earlyGameDurationSeconds': earlyGameDurationSeconds,
        'earlyGamePlayerGrowthMultiplier': earlyGamePlayerGrowthMultiplier,
        'respawnDelayMultiplier': respawnDelayMultiplier,
        'supernovaIntervalSeconds': supernovaIntervalSeconds,
        'supernovaFirstDelaySeconds': supernovaFirstDelaySeconds,
        'meteorShowerInitialCooldown': meteorShowerInitialCooldown,
        'eventGrowthCapPerBurst': eventGrowthCapPerBurst,
        'supernovaPlanetCount': supernovaPlanetCount,
        'radiationRadius': radiationRadius,
        'radiationIdleSeconds': radiationIdleSeconds,
        'lateGameRadiationRadius': lateGameRadiationRadius,
        'lateGameRadiationIdleSeconds': lateGameRadiationIdleSeconds,
        'lateGameRadiationShrinkPerSecond': lateGameRadiationShrinkPerSecond,
        'huntPriority': huntPriority,
        'botStartRadiusMin': botStartRadiusMin,
        'botStartRadiusMax': botStartRadiusMax,
        'decisionIntervalMin': decisionIntervalMin,
        'decisionIntervalMax': decisionIntervalMax,
        'preySizeRatio': preySizeRatio,
        'threatSizeRatio': threatSizeRatio,
        'preySearchMultiplier': preySearchMultiplier,
        'foodSearchMultiplier': foodSearchMultiplier,
        'eventAwareness': eventAwareness,
        'mineAvoidance': mineAvoidance,
        'interceptPrey': interceptPrey,
        'minHuntRadius': minHuntRadius,
        'playerTargetBias': playerTargetBias,
        'personalityCoward': personalityCoward,
        'personalityAggressive': personalityAggressive,
        'personalityOpportunist': personalityOpportunist,
      };

  factory RoomGameTuning.fromJson(
    RoomType type,
    Map<String, dynamic> json,
  ) {
    final d = RoomGameTuning.defaultsFor(type);
    double dbl(String key, double fallback) {
      final v = json[key];
      if (v is num) return v.toDouble();
      return fallback;
    }

    int integer(String key, int fallback) {
      final v = json[key];
      if (v is num) return v.round();
      return fallback;
    }

    bool flag(String key, bool fallback) {
      final v = json[key];
      if (v is bool) return v;
      return fallback;
    }

    var minR = dbl('botStartRadiusMin', d.botStartRadiusMin);
    var maxR = dbl('botStartRadiusMax', d.botStartRadiusMax);
    if (maxR < minR) {
      final t = minR;
      minR = maxR;
      maxR = t;
    }

    var minD = dbl('decisionIntervalMin', d.decisionIntervalMin);
    var maxD = dbl('decisionIntervalMax', d.decisionIntervalMax);
    if (maxD < minD) {
      final t = minD;
      minD = maxD;
      maxD = t;
    }

    var minM = dbl('targetMinutesMin', d.targetMinutesMin);
    var maxM = dbl('targetMinutesMax', d.targetMinutesMax);
    if (maxM < minM) {
      final t = minM;
      minM = maxM;
      maxM = t;
    }

    return RoomGameTuning(
      worldSize: dbl('worldSize', d.worldSize).clamp(2000, 20000),
      victoryRadius: dbl('victoryRadius', d.victoryRadius).clamp(100, 2000),
      playerStartRadius:
          dbl('playerStartRadius', d.playerStartRadius).clamp(10, 80),
      foodGrowthMultiplier:
          dbl('foodGrowthMultiplier', d.foodGrowthMultiplier).clamp(0.1, 2.0),
      gravityMultiplier:
          dbl('gravityMultiplier', d.gravityMultiplier).clamp(0.2, 3.0),
      cosmicEventsEnabled: flag('cosmicEventsEnabled', d.cosmicEventsEnabled),
      asteroidCount: integer('asteroidCount', d.asteroidCount).clamp(0, 2000),
      meteoriteCount:
          integer('meteoriteCount', d.meteoriteCount).clamp(0, 2000),
      planetCount: integer('planetCount', d.planetCount).clamp(0, 2000),
      quasarFragmentCount:
          integer('quasarFragmentCount', d.quasarFragmentCount).clamp(0, 2000),
      asteroidTier6Count:
          integer('asteroidTier6Count', d.asteroidTier6Count).clamp(0, 2000),
      asteroidTier7Count:
          integer('asteroidTier7Count', d.asteroidTier7Count).clamp(0, 2000),
      asteroidTier8Count:
          integer('asteroidTier8Count', d.asteroidTier8Count).clamp(0, 2000),
      mineCount: integer('mineCount', d.mineCount).clamp(0, 50),
      targetMinutesMin: minM.clamp(0.5, 30),
      targetMinutesMax: maxM.clamp(0.5, 30),
      earlyGameDurationSeconds:
          dbl('earlyGameDurationSeconds', d.earlyGameDurationSeconds)
              .clamp(0, 300),
      earlyGamePlayerGrowthMultiplier: dbl(
        'earlyGamePlayerGrowthMultiplier',
        d.earlyGamePlayerGrowthMultiplier,
      ).clamp(0.5, 3.0),
      respawnDelayMultiplier:
          dbl('respawnDelayMultiplier', d.respawnDelayMultiplier)
              .clamp(0.3, 3.0),
      supernovaIntervalSeconds:
          dbl('supernovaIntervalSeconds', d.supernovaIntervalSeconds)
              .clamp(0, 600),
      supernovaFirstDelaySeconds:
          dbl('supernovaFirstDelaySeconds', d.supernovaFirstDelaySeconds)
              .clamp(0, 600),
      meteorShowerInitialCooldown:
          dbl('meteorShowerInitialCooldown', d.meteorShowerInitialCooldown)
              .clamp(0, 600),
      eventGrowthCapPerBurst:
          dbl('eventGrowthCapPerBurst', d.eventGrowthCapPerBurst).clamp(0, 200),
      supernovaPlanetCount:
          integer('supernovaPlanetCount', d.supernovaPlanetCount).clamp(0, 100),
      radiationRadius:
          dbl('radiationRadius', d.radiationRadius).clamp(40, 500),
      radiationIdleSeconds:
          dbl('radiationIdleSeconds', d.radiationIdleSeconds).clamp(2, 60),
      lateGameRadiationRadius:
          dbl('lateGameRadiationRadius', d.lateGameRadiationRadius)
              .clamp(100, 800),
      lateGameRadiationIdleSeconds: dbl(
        'lateGameRadiationIdleSeconds',
        d.lateGameRadiationIdleSeconds,
      ).clamp(2, 60),
      lateGameRadiationShrinkPerSecond: dbl(
        'lateGameRadiationShrinkPerSecond',
        d.lateGameRadiationShrinkPerSecond,
      ).clamp(0.2, 8),
      huntPriority: dbl('huntPriority', d.huntPriority).clamp(0.0, 1.0),
      botStartRadiusMin: minR.clamp(10, 80),
      botStartRadiusMax: maxR.clamp(10, 80),
      decisionIntervalMin: minD.clamp(0.05, 2.0),
      decisionIntervalMax: maxD.clamp(0.05, 2.0),
      preySizeRatio: dbl('preySizeRatio', d.preySizeRatio).clamp(0.5, 1.0),
      threatSizeRatio:
          dbl('threatSizeRatio', d.threatSizeRatio).clamp(0.8, 1.5),
      preySearchMultiplier:
          dbl('preySearchMultiplier', d.preySearchMultiplier).clamp(1, 20),
      foodSearchMultiplier:
          dbl('foodSearchMultiplier', d.foodSearchMultiplier).clamp(1, 30),
      eventAwareness: dbl('eventAwareness', d.eventAwareness).clamp(0.0, 1.0),
      mineAvoidance: dbl('mineAvoidance', d.mineAvoidance).clamp(0.0, 1.0),
      interceptPrey: flag('interceptPrey', d.interceptPrey),
      minHuntRadius: dbl('minHuntRadius', d.minHuntRadius).clamp(10, 120),
      playerTargetBias:
          dbl('playerTargetBias', d.playerTargetBias).clamp(0.5, 4.0),
      personalityCoward:
          integer('personalityCoward', d.personalityCoward).clamp(0, 100),
      personalityAggressive: integer(
        'personalityAggressive',
        d.personalityAggressive,
      ).clamp(0, 100),
      personalityOpportunist: integer(
        'personalityOpportunist',
        d.personalityOpportunist,
      ).clamp(0, 100),
    );
  }
}
