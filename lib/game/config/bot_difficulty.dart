import '../components/bot_player.dart';
import '../room_type.dart';

/// Admin quick-select ladder for bot aggression / skill (softest → hardest).
enum BotAdminPreset {
  /// Farms heavily, hunts late, slow reactions.
  training,

  /// Mild pressure — forgiving but not idle.
  casual,

  /// Room-tier baseline (recommended competitive feel).
  ranked,

  /// Hungrier and sharper than ranked.
  predator,

  /// Peak lobby pressure — fast, player-focused, ruthless.
  apex,
}

/// AI tuning per room tier — bots share Player movement and growth rules.
class BotDifficulty {
  const BotDifficulty({
    required this.decisionIntervalMin,
    required this.decisionIntervalMax,
    required this.preySizeRatio,
    required this.threatSizeRatio,
    required this.preySearchMultiplier,
    required this.foodSearchMultiplier,
    required this.huntPriority,
    required this.eventAwareness,
    required this.mineAvoidance,
    required this.startRadiusMin,
    required this.startRadiusMax,
    required this.personalityWeights,
    required this.interceptPrey,
    required this.minHuntRadius,
    required this.playerTargetBias,
  });

  /// Seconds between direction re-evaluations (lower = faster reactions).
  final double decisionIntervalMin;
  final double decisionIntervalMax;

  /// Prey must be smaller than `self * preySizeRatio` to be hunted.
  final double preySizeRatio;

  /// Flee from holes larger than `self * threatSizeRatio`.
  final double threatSizeRatio;

  final double preySearchMultiplier;
  final double foodSearchMultiplier;

  /// How strongly bots prioritise hunting over farming (0–1).
  /// Affects flee weight, aim jitter, prey score, hunt boost range, food bias.
  final double huntPriority;

  /// React to supernova / meteor shower events (0–1).
  final double eventAwareness;

  /// Non-opportunist bots steer away from mines (0–1).
  final double mineAvoidance;

  final double startRadiusMin;
  final double startRadiusMax;
  final Map<BotPersonality, int> personalityWeights;
  final bool interceptPrey;

  /// Minimum own radius before bots attempt to hunt prey.
  final double minHuntRadius;

  /// Extra prey-score multiplier when targeting real players.
  final double playerTargetBias;

  /// Training / soft onboarding — forgiving, farms more than it hunts.
  static const relaxed = BotDifficulty(
    decisionIntervalMin: 0.32,
    decisionIntervalMax: 0.58,
    preySizeRatio: 0.84,
    threatSizeRatio: 1.14,
    preySearchMultiplier: 5.8,
    foodSearchMultiplier: 11,
    huntPriority: 0.28,
    eventAwareness: 0.48,
    mineAvoidance: 0.42,
    startRadiusMin: 22,
    startRadiusMax: 26,
    personalityWeights: {
      BotPersonality.coward: 40,
      BotPersonality.aggressive: 28,
      BotPersonality.opportunist: 32,
    },
    interceptPrey: false,
    minHuntRadius: 42,
    playerTargetBias: 1.0,
  );

  /// Normal universe — human-like: farm, fight, flee like a solid player.
  static const standard = BotDifficulty(
    decisionIntervalMin: 0.18,
    decisionIntervalMax: 0.38,
    preySizeRatio: 0.92,
    threatSizeRatio: 1.08,
    preySearchMultiplier: 8.2,
    foodSearchMultiplier: 10.5,
    huntPriority: 0.56,
    eventAwareness: 0.78,
    mineAvoidance: 0.58,
    startRadiusMin: 24,
    startRadiusMax: 26,
    personalityWeights: {
      BotPersonality.coward: 24,
      BotPersonality.aggressive: 38,
      BotPersonality.opportunist: 38,
    },
    interceptPrey: true,
    minHuntRadius: 30,
    playerTargetBias: 1.12,
  );

  /// Elite — sharper reactions, earlier fights, still not “cheat aim”.
  static const elite = BotDifficulty(
    decisionIntervalMin: 0.15,
    decisionIntervalMax: 0.32,
    preySizeRatio: 0.94,
    threatSizeRatio: 1.06,
    preySearchMultiplier: 8.8,
    foodSearchMultiplier: 10,
    huntPriority: 0.66,
    eventAwareness: 0.85,
    mineAvoidance: 0.62,
    startRadiusMin: 24,
    startRadiusMax: 27,
    personalityWeights: {
      BotPersonality.coward: 18,
      BotPersonality.aggressive: 42,
      BotPersonality.opportunist: 40,
    },
    interceptPrey: true,
    minHuntRadius: 26,
    playerTargetBias: 1.22,
  );

  /// Unique — high-skill lobby feel; contests wins, balanced human focus.
  static const unique = BotDifficulty(
    decisionIntervalMin: 0.12,
    decisionIntervalMax: 0.28,
    preySizeRatio: 0.95,
    threatSizeRatio: 1.05,
    preySearchMultiplier: 9.4,
    foodSearchMultiplier: 9.5,
    huntPriority: 0.74,
    eventAwareness: 0.9,
    mineAvoidance: 0.66,
    startRadiusMin: 25,
    startRadiusMax: 28,
    personalityWeights: {
      BotPersonality.coward: 14,
      BotPersonality.aggressive: 46,
      BotPersonality.opportunist: 40,
    },
    interceptPrey: true,
    minHuntRadius: 22,
    playerTargetBias: 1.28,
  );

  /// Profile for an admin difficulty chip, scaled off the room tier baseline.
  static BotDifficulty forAdminPreset(RoomType type, BotAdminPreset preset) {
    final base = presetFor(type);
    return switch (preset) {
      BotAdminPreset.training => base.copyWith(
          decisionIntervalMin:
              (base.decisionIntervalMin * 1.55).clamp(0.14, 1.3),
          decisionIntervalMax:
              (base.decisionIntervalMax * 1.55).clamp(0.18, 1.5),
          preySizeRatio: (base.preySizeRatio - 0.06).clamp(0.55, 0.95),
          threatSizeRatio: (base.threatSizeRatio + 0.06).clamp(1.0, 1.5),
          huntPriority: (base.huntPriority * 0.52).clamp(0.12, 0.85),
          eventAwareness: (base.eventAwareness * 0.72).clamp(0.2, 1.0),
          mineAvoidance: (base.mineAvoidance * 0.85).clamp(0.2, 1.0),
          preySearchMultiplier:
              (base.preySearchMultiplier * 0.72).clamp(2, 12),
          foodSearchMultiplier:
              (base.foodSearchMultiplier * 1.15).clamp(6, 16),
          minHuntRadius: (base.minHuntRadius * 1.45).clamp(18, 110),
          playerTargetBias: (base.playerTargetBias * 0.82).clamp(0.75, 1.8),
          interceptPrey: false,
          personalityWeights: {
            BotPersonality.coward: 48,
            BotPersonality.aggressive: 18,
            BotPersonality.opportunist: 34,
          },
        ),
      BotAdminPreset.casual => base.copyWith(
          decisionIntervalMin:
              (base.decisionIntervalMin * 1.28).clamp(0.12, 1.2),
          decisionIntervalMax:
              (base.decisionIntervalMax * 1.28).clamp(0.15, 1.35),
          preySizeRatio: (base.preySizeRatio - 0.03).clamp(0.58, 0.96),
          threatSizeRatio: (base.threatSizeRatio + 0.03).clamp(0.98, 1.45),
          huntPriority: (base.huntPriority * 0.74).clamp(0.15, 0.9),
          eventAwareness: (base.eventAwareness * 0.88).clamp(0.2, 1.0),
          minHuntRadius: (base.minHuntRadius * 1.18).clamp(16, 100),
          playerTargetBias: (base.playerTargetBias * 0.92).clamp(0.8, 2.0),
          interceptPrey: type == RoomType.unique || type == RoomType.elite,
          personalityWeights: {
            BotPersonality.coward: 38,
            BotPersonality.aggressive: 26,
            BotPersonality.opportunist: 36,
          },
        ),
      BotAdminPreset.ranked => base,
      BotAdminPreset.predator => base.copyWith(
          decisionIntervalMin:
              (base.decisionIntervalMin * 0.88).clamp(0.09, 1.0),
          decisionIntervalMax:
              (base.decisionIntervalMax * 0.88).clamp(0.12, 1.15),
          preySizeRatio: (base.preySizeRatio + 0.015).clamp(0.6, 0.97),
          threatSizeRatio: (base.threatSizeRatio - 0.015).clamp(0.96, 1.35),
          huntPriority: (base.huntPriority + 0.1).clamp(0.2, 1.0),
          eventAwareness: (base.eventAwareness + 0.05).clamp(0.2, 1.0),
          preySearchMultiplier:
              (base.preySearchMultiplier + 0.55).clamp(2, 14),
          foodSearchMultiplier:
              (base.foodSearchMultiplier * 0.95).clamp(5, 14),
          minHuntRadius: (base.minHuntRadius * 0.9).clamp(15, 85),
          playerTargetBias: (base.playerTargetBias + 0.1).clamp(0.8, 2.3),
          interceptPrey: true,
          personalityWeights: {
            BotPersonality.coward: 16,
            BotPersonality.aggressive: 46,
            BotPersonality.opportunist: 38,
          },
        ),
      BotAdminPreset.apex => base.copyWith(
          decisionIntervalMin:
              (base.decisionIntervalMin * 0.72).clamp(0.07, 0.95),
          decisionIntervalMax:
              (base.decisionIntervalMax * 0.72).clamp(0.1, 1.05),
          preySizeRatio: (base.preySizeRatio + 0.03).clamp(0.62, 0.98),
          threatSizeRatio: (base.threatSizeRatio - 0.03).clamp(0.95, 1.3),
          huntPriority: (base.huntPriority + 0.2).clamp(0.25, 1.0),
          eventAwareness: (base.eventAwareness + 0.08).clamp(0.25, 1.0),
          mineAvoidance: (base.mineAvoidance + 0.06).clamp(0.25, 1.0),
          preySearchMultiplier:
              (base.preySearchMultiplier + 1.2).clamp(2, 14),
          foodSearchMultiplier:
              (base.foodSearchMultiplier * 0.88).clamp(5, 13),
          minHuntRadius: (base.minHuntRadius * 0.72).clamp(14, 75),
          playerTargetBias: (base.playerTargetBias + 0.22).clamp(0.85, 2.6),
          interceptPrey: true,
          personalityWeights: {
            BotPersonality.coward: 8,
            BotPersonality.aggressive: 58,
            BotPersonality.opportunist: 34,
          },
        ),
    };
  }

  /// Which admin chip matches [current], or `null` if sliders were customized.
  static BotAdminPreset? matchingAdminPreset(
    RoomType type,
    BotDifficulty current,
  ) {
    for (final preset in BotAdminPreset.values) {
      if (forAdminPreset(type, preset).isSameProfile(current)) return preset;
    }
    return null;
  }

  /// True when key AI fields match within admin-slider rounding tolerance.
  bool isSameProfile(BotDifficulty other) {
    bool near(double a, double b, [double eps = 0.012]) => (a - b).abs() <= eps;
    if (!near(huntPriority, other.huntPriority) ||
        !near(decisionIntervalMin, other.decisionIntervalMin) ||
        !near(decisionIntervalMax, other.decisionIntervalMax) ||
        !near(preySizeRatio, other.preySizeRatio) ||
        !near(threatSizeRatio, other.threatSizeRatio) ||
        !near(preySearchMultiplier, other.preySearchMultiplier, 0.08) ||
        !near(foodSearchMultiplier, other.foodSearchMultiplier, 0.08) ||
        !near(eventAwareness, other.eventAwareness) ||
        !near(mineAvoidance, other.mineAvoidance) ||
        !near(minHuntRadius, other.minHuntRadius, 0.6) ||
        !near(playerTargetBias, other.playerTargetBias) ||
        interceptPrey != other.interceptPrey) {
      return false;
    }
    for (final p in BotPersonality.values) {
      if ((personalityWeights[p] ?? 0) != (other.personalityWeights[p] ?? 0)) {
        return false;
      }
    }
    return true;
  }

  /// Compile-time presets (before admin / remote overrides).
  static BotDifficulty presetFor(RoomType type) => switch (type) {
        RoomType.simple => relaxed,
        RoomType.normal => standard,
        RoomType.elite => elite,
        RoomType.unique => unique,
      };

  static final Map<RoomType, BotDifficulty> _overrides = {};

  static double defaultHuntPriority(RoomType type) =>
      presetFor(type).huntPriority;

  static void applyOverrides(Map<RoomType, BotDifficulty> values) {
    _overrides
      ..clear()
      ..addAll(values);
  }

  static void clearOverrides() => _overrides.clear();

  /// Effective difficulty for a room, including admin overrides.
  static BotDifficulty forRoom(RoomType type) =>
      _overrides[type] ?? presetFor(type);

  BotDifficulty copyWith({
    double? decisionIntervalMin,
    double? decisionIntervalMax,
    double? preySizeRatio,
    double? threatSizeRatio,
    double? preySearchMultiplier,
    double? foodSearchMultiplier,
    double? huntPriority,
    double? eventAwareness,
    double? mineAvoidance,
    double? startRadiusMin,
    double? startRadiusMax,
    Map<BotPersonality, int>? personalityWeights,
    bool? interceptPrey,
    double? minHuntRadius,
    double? playerTargetBias,
  }) {
    return BotDifficulty(
      decisionIntervalMin: decisionIntervalMin ?? this.decisionIntervalMin,
      decisionIntervalMax: decisionIntervalMax ?? this.decisionIntervalMax,
      preySizeRatio: preySizeRatio ?? this.preySizeRatio,
      threatSizeRatio: threatSizeRatio ?? this.threatSizeRatio,
      preySearchMultiplier:
          preySearchMultiplier ?? this.preySearchMultiplier,
      foodSearchMultiplier:
          foodSearchMultiplier ?? this.foodSearchMultiplier,
      huntPriority: huntPriority ?? this.huntPriority,
      eventAwareness: eventAwareness ?? this.eventAwareness,
      mineAvoidance: mineAvoidance ?? this.mineAvoidance,
      startRadiusMin: startRadiusMin ?? this.startRadiusMin,
      startRadiusMax: startRadiusMax ?? this.startRadiusMax,
      personalityWeights: personalityWeights ?? this.personalityWeights,
      interceptPrey: interceptPrey ?? this.interceptPrey,
      minHuntRadius: minHuntRadius ?? this.minHuntRadius,
      playerTargetBias: playerTargetBias ?? this.playerTargetBias,
    );
  }

  BotPersonality pickPersonality(int Function(int max) nextInt) {
    final total = personalityWeights.values.fold(0, (a, b) => a + b);
    var roll = nextInt(total);
    for (final entry in personalityWeights.entries) {
      roll -= entry.value;
      if (roll < 0) return entry.key;
    }
    return BotPersonality.aggressive;
  }
}
