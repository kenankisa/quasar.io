import '../models/room_game_tuning.dart';
import '../room_type.dart';
import 'bot_difficulty.dart';

/// Admin quick-select ladder for overall universe difficulty (softest → hardest).
/// Scaled off [RoomGameTuning.defaultsFor] — same idea as [BotAdminPreset].
enum UniverseAdminPreset {
  /// Forgiving tempo, denser food, softer radiation & bots.
  training,

  /// Milder than ranked — still a real match.
  casual,

  /// Compile-time defaults for the room tier (recommended balance).
  ranked,

  /// Tighter food, sharper events/radiation, hungrier bots.
  predator,

  /// Peak pressure across world, tempo, hazards, and bots.
  apex,
}

/// Builds / matches universe-wide difficulty profiles for admin chips.
class UniverseDifficulty {
  const UniverseDifficulty._();

  /// Recommended cross-universe ladder (tutorial soft → unique harsh).
  static const balancedDistribution = <RoomType, UniverseAdminPreset>{
    RoomType.simple: UniverseAdminPreset.training,
    RoomType.normal: UniverseAdminPreset.ranked,
    RoomType.elite: UniverseAdminPreset.predator,
    RoomType.unique: UniverseAdminPreset.apex,
  };

  /// Matching bot ladder for a coherent feel.
  static BotAdminPreset botPresetFor(UniverseAdminPreset preset) =>
      switch (preset) {
        UniverseAdminPreset.training => BotAdminPreset.training,
        UniverseAdminPreset.casual => BotAdminPreset.casual,
        UniverseAdminPreset.ranked => BotAdminPreset.ranked,
        UniverseAdminPreset.predator => BotAdminPreset.predator,
        UniverseAdminPreset.apex => BotAdminPreset.apex,
      };

  /// Full tuning profile for an admin difficulty chip.
  static RoomGameTuning forAdminPreset(
    RoomType type,
    UniverseAdminPreset preset,
  ) {
    final base = RoomGameTuning.defaultsFor(type);
    final withWorld = switch (preset) {
      UniverseAdminPreset.training => _scale(base, const _Scale(
          foodGrowth: 1.14,
          gravity: 0.94,
          earlyDuration: 1.28,
          earlyGrowth: 1.1,
          respawnDelay: 0.82,
          eventInterval: 1.22,
          eventFirstDelay: 1.18,
          meteorCooldown: 1.2,
          eventGrowthCap: 0.82,
          supernovaPlanets: 0.85,
          foodObjects: 1.14,
          mines: 0.45,
          radiationIdle: 1.22,
          lateRadiationIdle: 1.2,
          lateRadiationRadius: 1.04,
          lateShrink: 0.82,
        )),
      UniverseAdminPreset.casual => _scale(base, const _Scale(
          foodGrowth: 1.07,
          gravity: 0.97,
          earlyDuration: 1.12,
          earlyGrowth: 1.05,
          respawnDelay: 0.9,
          eventInterval: 1.1,
          eventFirstDelay: 1.08,
          meteorCooldown: 1.1,
          eventGrowthCap: 0.92,
          supernovaPlanets: 0.92,
          foodObjects: 1.07,
          mines: 0.7,
          radiationIdle: 1.1,
          lateRadiationIdle: 1.08,
          lateRadiationRadius: 1.02,
          lateShrink: 0.9,
        )),
      UniverseAdminPreset.ranked => base,
      UniverseAdminPreset.predator => _scale(base, const _Scale(
          foodGrowth: 0.92,
          gravity: 1.03,
          earlyDuration: 0.88,
          earlyGrowth: 0.94,
          respawnDelay: 1.1,
          eventInterval: 0.9,
          eventFirstDelay: 0.9,
          meteorCooldown: 0.88,
          eventGrowthCap: 1.1,
          supernovaPlanets: 1.08,
          foodObjects: 0.92,
          mines: 1.45,
          radiationIdle: 0.9,
          lateRadiationIdle: 0.88,
          lateRadiationRadius: 0.97,
          lateShrink: 1.12,
        )),
      UniverseAdminPreset.apex => _scale(base, const _Scale(
          foodGrowth: 0.84,
          gravity: 1.06,
          earlyDuration: 0.78,
          earlyGrowth: 0.88,
          respawnDelay: 1.2,
          eventInterval: 0.8,
          eventFirstDelay: 0.8,
          meteorCooldown: 0.78,
          eventGrowthCap: 1.2,
          supernovaPlanets: 1.15,
          foodObjects: 0.85,
          mines: 1.9,
          radiationIdle: 0.8,
          lateRadiationIdle: 0.78,
          lateRadiationRadius: 0.94,
          lateShrink: 1.22,
        )),
    };

    return withWorld.withBotDifficulty(
      BotDifficulty.forAdminPreset(type, botPresetFor(preset)),
    );
  }

  /// Which admin chip matches [current], or `null` if customized.
  static UniverseAdminPreset? matchingAdminPreset(
    RoomType type,
    RoomGameTuning current,
  ) {
    for (final preset in UniverseAdminPreset.values) {
      if (isSameUniverseProfile(
        type,
        forAdminPreset(type, preset),
        current,
      )) {
        return preset;
      }
    }
    return null;
  }

  /// True when universe + bot knobs match within admin-slider tolerance.
  static bool isSameUniverseProfile(
    RoomType type,
    RoomGameTuning a,
    RoomGameTuning b,
  ) {
    bool near(double x, double y, [double eps = 0.02]) => (x - y).abs() <= eps;
    bool nearInt(int x, int y, [int slack = 1]) => (x - y).abs() <= slack;

    if (!near(a.foodGrowthMultiplier, b.foodGrowthMultiplier) ||
        !near(a.gravityMultiplier, b.gravityMultiplier) ||
        !near(a.earlyGameDurationSeconds, b.earlyGameDurationSeconds, 1.5) ||
        !near(
          a.earlyGamePlayerGrowthMultiplier,
          b.earlyGamePlayerGrowthMultiplier,
        ) ||
        !near(a.respawnDelayMultiplier, b.respawnDelayMultiplier) ||
        !near(a.supernovaIntervalSeconds, b.supernovaIntervalSeconds, 1.5) ||
        !near(
          a.supernovaFirstDelaySeconds,
          b.supernovaFirstDelaySeconds,
          1.5,
        ) ||
        !near(
          a.meteorShowerInitialCooldown,
          b.meteorShowerInitialCooldown,
          1.5,
        ) ||
        !near(a.eventGrowthCapPerBurst, b.eventGrowthCapPerBurst, 1.2) ||
        !near(a.radiationIdleSeconds, b.radiationIdleSeconds, 0.4) ||
        !near(a.lateGameRadiationRadius, b.lateGameRadiationRadius, 2.0) ||
        !near(
          a.lateGameRadiationIdleSeconds,
          b.lateGameRadiationIdleSeconds,
          0.4,
        ) ||
        !near(
          a.lateGameRadiationShrinkPerSecond,
          b.lateGameRadiationShrinkPerSecond,
        ) ||
        a.cosmicEventsEnabled != b.cosmicEventsEnabled ||
        !nearInt(a.supernovaPlanetCount, b.supernovaPlanetCount) ||
        !nearInt(a.asteroidCount, b.asteroidCount, 3) ||
        !nearInt(a.meteoriteCount, b.meteoriteCount, 2) ||
        !nearInt(a.planetCount, b.planetCount, 2) ||
        !nearInt(a.quasarFragmentCount, b.quasarFragmentCount, 2) ||
        !nearInt(a.asteroidTier6Count, b.asteroidTier6Count, 3) ||
        !nearInt(a.asteroidTier7Count, b.asteroidTier7Count, 3) ||
        !nearInt(a.asteroidTier8Count, b.asteroidTier8Count, 3) ||
        !nearInt(a.mineCount, b.mineCount) ||
        !near(a.victoryRadius, b.victoryRadius, 0.5) ||
        !near(a.playerStartRadius, b.playerStartRadius, 0.5) ||
        !near(a.worldSize, b.worldSize, 1)) {
      return false;
    }

    return a.toBotDifficulty(type).isSameProfile(b.toBotDifficulty(type));
  }

  static RoomGameTuning _scale(RoomGameTuning base, _Scale s) {
    final eventsOn = base.cosmicEventsEnabled;
    return base.copyWith(
      foodGrowthMultiplier:
          (base.foodGrowthMultiplier * s.foodGrowth).clamp(0.35, 1.35),
      gravityMultiplier:
          (base.gravityMultiplier * s.gravity).clamp(0.7, 1.35),
      earlyGameDurationSeconds:
          (base.earlyGameDurationSeconds * s.earlyDuration).clamp(20, 120),
      earlyGamePlayerGrowthMultiplier:
          (base.earlyGamePlayerGrowthMultiplier * s.earlyGrowth)
              .clamp(1.0, 1.35),
      respawnDelayMultiplier:
          (base.respawnDelayMultiplier * s.respawnDelay).clamp(0.55, 1.6),
      supernovaIntervalSeconds: eventsOn && base.supernovaIntervalSeconds > 0
          ? (base.supernovaIntervalSeconds * s.eventInterval).clamp(35, 180)
          : base.supernovaIntervalSeconds,
      supernovaFirstDelaySeconds:
          eventsOn && base.supernovaFirstDelaySeconds > 0
              ? (base.supernovaFirstDelaySeconds * s.eventFirstDelay)
                  .clamp(20, 150)
              : base.supernovaFirstDelaySeconds,
      meteorShowerInitialCooldown:
          eventsOn && base.meteorShowerInitialCooldown > 0
              ? (base.meteorShowerInitialCooldown * s.meteorCooldown)
                  .clamp(20, 160)
              : base.meteorShowerInitialCooldown,
      eventGrowthCapPerBurst: eventsOn && base.eventGrowthCapPerBurst > 0
          ? (base.eventGrowthCapPerBurst * s.eventGrowthCap).clamp(12, 90)
          : base.eventGrowthCapPerBurst,
      supernovaPlanetCount: eventsOn && base.supernovaPlanetCount > 0
          ? _scaleCount(base.supernovaPlanetCount, s.supernovaPlanets)
          : base.supernovaPlanetCount,
      asteroidCount: _scaleCount(base.asteroidCount, s.foodObjects),
      meteoriteCount: _scaleCount(base.meteoriteCount, s.foodObjects),
      planetCount: _scaleCount(base.planetCount, s.foodObjects),
      quasarFragmentCount:
          _scaleCount(base.quasarFragmentCount, s.foodObjects),
      asteroidTier6Count: _scaleCount(base.asteroidTier6Count, s.foodObjects),
      asteroidTier7Count: _scaleCount(base.asteroidTier7Count, s.foodObjects),
      asteroidTier8Count: _scaleCount(base.asteroidTier8Count, s.foodObjects),
      mineCount: base.mineCount <= 0
          ? 0
          : _scaleCount(base.mineCount, s.mines).clamp(1, 16),
      radiationRadius: base.radiationRadius,
      radiationIdleSeconds:
          (base.radiationIdleSeconds * s.radiationIdle).clamp(6, 28),
      lateGameRadiationRadius:
          (base.lateGameRadiationRadius * s.lateRadiationRadius)
              .clamp(300, 520),
      lateGameRadiationIdleSeconds:
          (base.lateGameRadiationIdleSeconds * s.lateRadiationIdle)
              .clamp(5, 22),
      lateGameRadiationShrinkPerSecond:
          (base.lateGameRadiationShrinkPerSecond * s.lateShrink)
              .clamp(0.8, 3.2),
    );
  }

  static int _scaleCount(int n, double m) {
    if (n <= 0) return 0;
    return (n * m).round().clamp(0, 999);
  }
}

class _Scale {
  const _Scale({
    required this.foodGrowth,
    required this.gravity,
    required this.earlyDuration,
    required this.earlyGrowth,
    required this.respawnDelay,
    required this.eventInterval,
    required this.eventFirstDelay,
    required this.meteorCooldown,
    required this.eventGrowthCap,
    required this.supernovaPlanets,
    required this.foodObjects,
    required this.mines,
    required this.radiationIdle,
    required this.lateRadiationIdle,
    required this.lateRadiationRadius,
    required this.lateShrink,
  });

  final double foodGrowth;
  final double gravity;
  final double earlyDuration;
  final double earlyGrowth;
  final double respawnDelay;
  final double eventInterval;
  final double eventFirstDelay;
  final double meteorCooldown;
  final double eventGrowthCap;
  final double supernovaPlanets;
  final double foodObjects;
  final double mines;
  final double radiationIdle;
  final double lateRadiationIdle;
  final double lateRadiationRadius;
  final double lateShrink;
}
