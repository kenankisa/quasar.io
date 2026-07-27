/// Hardcore-only arena package knobs (stored inside [RoomGameTuning] JSON).
class HardcoreArenaTuning {
  const HardcoreArenaTuning({
    required this.spawnProtectionSeconds,
    required this.victoryMinAlive,
    required this.victoryStableSeconds,
    required this.victoryMinPvpMassFraction,
    required this.lateFoodSoftcapRadius,
    required this.lateFoodSoftcapMultiplier,
    required this.lowPopRadiusCap,
    required this.foodPopMult1,
    required this.foodPopMult2,
    required this.foodPopMult34,
    required this.foodPopMult5,
    required this.foodPopMult6Plus,
  });

  final double spawnProtectionSeconds;
  final int victoryMinAlive;
  final double victoryStableSeconds;
  final double victoryMinPvpMassFraction;
  final double lateFoodSoftcapRadius;
  final double lateFoodSoftcapMultiplier;

  /// Hard radius ceiling while alive &lt; [victoryMinAlive] (anti 600-camp).
  final double lowPopRadiusCap;

  final double foodPopMult1;
  final double foodPopMult2;
  final double foodPopMult34;
  final double foodPopMult5;
  final double foodPopMult6Plus;

  /// Package defaults (Hardcore arena v2).
  static const defaults = HardcoreArenaTuning(
    spawnProtectionSeconds: 12,
    victoryMinAlive: 6,
    victoryStableSeconds: 20,
    victoryMinPvpMassFraction: 0.35,
    lateFoodSoftcapRadius: 450,
    lateFoodSoftcapMultiplier: 0.5,
    lowPopRadiusCap: 450,
    foodPopMult1: 0.15,
    foodPopMult2: 0.35,
    foodPopMult34: 0.55,
    foodPopMult5: 0.75,
    foodPopMult6Plus: 1.0,
  );

  double foodGrowthMultiplierForAlive(int alive) {
    if (alive <= 1) return foodPopMult1;
    if (alive == 2) return foodPopMult2;
    if (alive <= 4) return foodPopMult34;
    if (alive == 5) return foodPopMult5;
    return foodPopMult6Plus;
  }

  bool isVictoryClaimReady({
    required int aliveCount,
    required double arenaActiveSeconds,
    required double pvpMassFraction,
  }) {
    // Arena Test / load-test only — not checked for live player victory.
    return aliveCount >= victoryMinAlive &&
        arenaActiveSeconds >= victoryStableSeconds &&
        pvpMassFraction >= victoryMinPvpMassFraction;
  }

  HardcoreArenaTuning copyWith({
    double? spawnProtectionSeconds,
    int? victoryMinAlive,
    double? victoryStableSeconds,
    double? victoryMinPvpMassFraction,
    double? lateFoodSoftcapRadius,
    double? lateFoodSoftcapMultiplier,
    double? lowPopRadiusCap,
    double? foodPopMult1,
    double? foodPopMult2,
    double? foodPopMult34,
    double? foodPopMult5,
    double? foodPopMult6Plus,
  }) {
    return HardcoreArenaTuning(
      spawnProtectionSeconds:
          spawnProtectionSeconds ?? this.spawnProtectionSeconds,
      victoryMinAlive: victoryMinAlive ?? this.victoryMinAlive,
      victoryStableSeconds: victoryStableSeconds ?? this.victoryStableSeconds,
      victoryMinPvpMassFraction:
          victoryMinPvpMassFraction ?? this.victoryMinPvpMassFraction,
      lateFoodSoftcapRadius:
          lateFoodSoftcapRadius ?? this.lateFoodSoftcapRadius,
      lateFoodSoftcapMultiplier:
          lateFoodSoftcapMultiplier ?? this.lateFoodSoftcapMultiplier,
      lowPopRadiusCap: lowPopRadiusCap ?? this.lowPopRadiusCap,
      foodPopMult1: foodPopMult1 ?? this.foodPopMult1,
      foodPopMult2: foodPopMult2 ?? this.foodPopMult2,
      foodPopMult34: foodPopMult34 ?? this.foodPopMult34,
      foodPopMult5: foodPopMult5 ?? this.foodPopMult5,
      foodPopMult6Plus: foodPopMult6Plus ?? this.foodPopMult6Plus,
    );
  }

  Map<String, dynamic> toJson() => {
        'spawnProtectionSeconds': spawnProtectionSeconds,
        'victoryMinAlive': victoryMinAlive,
        'victoryStableSeconds': victoryStableSeconds,
        'victoryMinPvpMassFraction': victoryMinPvpMassFraction,
        'lateFoodSoftcapRadius': lateFoodSoftcapRadius,
        'lateFoodSoftcapMultiplier': lateFoodSoftcapMultiplier,
        'lowPopRadiusCap': lowPopRadiusCap,
        'foodPopMult1': foodPopMult1,
        'foodPopMult2': foodPopMult2,
        'foodPopMult34': foodPopMult34,
        'foodPopMult5': foodPopMult5,
        'foodPopMult6Plus': foodPopMult6Plus,
      };

  factory HardcoreArenaTuning.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return defaults;

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

    final lateFood = dbl('lateFoodSoftcapRadius', defaults.lateFoodSoftcapRadius)
        .clamp(100.0, 700.0);

    return HardcoreArenaTuning(
      spawnProtectionSeconds:
          dbl('spawnProtectionSeconds', defaults.spawnProtectionSeconds)
              .clamp(3, 30),
      victoryMinAlive:
          integer('victoryMinAlive', defaults.victoryMinAlive).clamp(2, 20),
      victoryStableSeconds:
          dbl('victoryStableSeconds', defaults.victoryStableSeconds)
              .clamp(0, 120),
      victoryMinPvpMassFraction: dbl(
        'victoryMinPvpMassFraction',
        defaults.victoryMinPvpMassFraction,
      ).clamp(0, 1),
      lateFoodSoftcapRadius: lateFood,
      lateFoodSoftcapMultiplier: dbl(
        'lateFoodSoftcapMultiplier',
        defaults.lateFoodSoftcapMultiplier,
      ).clamp(0.1, 1),
      // Legacy saves: fall back to late-food softcap radius.
      lowPopRadiusCap: dbl('lowPopRadiusCap', lateFood).clamp(100, 700),
      foodPopMult1: dbl('foodPopMult1', defaults.foodPopMult1).clamp(0, 1.5),
      foodPopMult2: dbl('foodPopMult2', defaults.foodPopMult2).clamp(0, 1.5),
      foodPopMult34:
          dbl('foodPopMult34', defaults.foodPopMult34).clamp(0, 1.5),
      foodPopMult5: dbl('foodPopMult5', defaults.foodPopMult5).clamp(0, 1.5),
      foodPopMult6Plus:
          dbl('foodPopMult6Plus', defaults.foodPopMult6Plus).clamp(0, 1.5),
    );
  }

  bool sameAs(HardcoreArenaTuning other) {
    return spawnProtectionSeconds == other.spawnProtectionSeconds &&
        victoryMinAlive == other.victoryMinAlive &&
        victoryStableSeconds == other.victoryStableSeconds &&
        victoryMinPvpMassFraction == other.victoryMinPvpMassFraction &&
        lateFoodSoftcapRadius == other.lateFoodSoftcapRadius &&
        lateFoodSoftcapMultiplier == other.lateFoodSoftcapMultiplier &&
        lowPopRadiusCap == other.lowPopRadiusCap &&
        foodPopMult1 == other.foodPopMult1 &&
        foodPopMult2 == other.foodPopMult2 &&
        foodPopMult34 == other.foodPopMult34 &&
        foodPopMult5 == other.foodPopMult5 &&
        foodPopMult6Plus == other.foodPopMult6Plus;
  }
}
