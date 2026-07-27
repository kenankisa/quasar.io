/// Elmas ekonomisi — ödüller, cezalar, eşikler, sandık, günlük cap (admin JSON).
class AppEconomyConfig {
  const AppEconomyConfig({
    required this.rewardSimple1,
    required this.rewardSimple2,
    required this.rewardSimple3,
    required this.rewardNormal1,
    required this.rewardNormal2,
    required this.rewardNormal3,
    required this.rewardElite1,
    required this.rewardElite2,
    required this.rewardElite3,
    required this.rewardUnique1,
    required this.rewardUnique2,
    required this.rewardUnique3,
    required this.rewardHardcore1,
    required this.rewardHardcoreKill,
    required this.hardcoreArenaMinAlive,
    required this.penaltySimple,
    required this.penaltyNormal,
    required this.penaltyElite,
    required this.penaltyUnique,
    required this.penaltyHardcore,
    required this.unlockNormal,
    required this.unlockElite,
    required this.unlockUnique,
    required this.dailyMatchDiamondCap,
    required this.chestAmount1,
    required this.chestAmount2,
    required this.chestAmount3,
    required this.rewardClaimsPerDay,
    required this.trainingClaimsPerDay,
    required this.adDoublesPerDay,
  });

  final int rewardSimple1;
  final int rewardSimple2;
  final int rewardSimple3;
  final int rewardNormal1;
  final int rewardNormal2;
  final int rewardNormal3;
  final int rewardElite1;
  final int rewardElite2;
  final int rewardElite3;
  final int rewardUnique1;
  final int rewardUnique2;
  final int rewardUnique3;

  /// Hardcore size-600 victory diamonds (no podium 2/3).
  final int rewardHardcore1;

  /// Hardcore kill while arena active (≥6 alive).
  final int rewardHardcoreKill;

  /// Alive count threshold for active-arena kill reward (server + client).
  final int hardcoreArenaMinAlive;

  /// Absolute loss on elimination (stored as positive; applied as negative).
  final int penaltySimple;
  final int penaltyNormal;
  final int penaltyElite;
  final int penaltyUnique;
  final int penaltyHardcore;

  final int unlockNormal;
  final int unlockElite;
  final int unlockUnique;

  final int dailyMatchDiamondCap;
  final int chestAmount1;
  final int chestAmount2;
  final int chestAmount3;

  final int rewardClaimsPerDay;
  final int trainingClaimsPerDay;
  final int adDoublesPerDay;

  /// Defaults match Hardcore v2 package (victory 40 / kill 4·2 / elim −10).
  static const defaults = AppEconomyConfig(
    rewardSimple1: 3,
    rewardSimple2: 2,
    rewardSimple3: 1,
    rewardNormal1: 5,
    rewardNormal2: 3,
    rewardNormal3: 2,
    rewardElite1: 10,
    rewardElite2: 6,
    rewardElite3: 4,
    rewardUnique1: 15,
    rewardUnique2: 10,
    rewardUnique3: 5,
    rewardHardcore1: 40,
    rewardHardcoreKill: 4,
    hardcoreArenaMinAlive: 6,
    penaltySimple: 0,
    penaltyNormal: 2,
    penaltyElite: 3,
    penaltyUnique: 4,
    penaltyHardcore: 10,
    unlockNormal: 25,
    unlockElite: 100,
    unlockUnique: 200,
    dailyMatchDiamondCap: 120,
    chestAmount1: 5,
    chestAmount2: 10,
    chestAmount3: 15,
    rewardClaimsPerDay: 25,
    trainingClaimsPerDay: 8,
    adDoublesPerDay: 3,
  );

  int placementReward(String roomType, int placement) {
    if (placement < 1 || placement > 3) return 0;
    final room = roomType.toLowerCase();
    return switch (room) {
      'simple' => switch (placement) {
          1 => rewardSimple1,
          2 => rewardSimple2,
          _ => rewardSimple3,
        },
      'elite' => switch (placement) {
          1 => rewardElite1,
          2 => rewardElite2,
          _ => rewardElite3,
        },
      'unique' => switch (placement) {
          1 => rewardUnique1,
          2 => rewardUnique2,
          _ => rewardUnique3,
        },
      // Hardcore: only size-600 victory; no podium 2/3.
      'hardcore' => placement == 1 ? rewardHardcore1 : 0,
      _ => switch (placement) {
          1 => rewardNormal1,
          2 => rewardNormal2,
          _ => rewardNormal3,
        },
    };
  }

  int eliminationPenalty(String roomType) => switch (roomType.toLowerCase()) {
        'simple' => penaltySimple,
        'elite' => penaltyElite,
        'unique' => penaltyUnique,
        'hardcore' => penaltyHardcore,
        _ => penaltyNormal,
      };

  int unlockFor(String roomType) => switch (roomType.toLowerCase()) {
        'simple' => 0,
        'hardcore' => 0, // trophy-gated, not diamond-gated
        'elite' => unlockElite,
        'unique' => unlockUnique,
        _ => unlockNormal,
      };

  List<int> get chestAmounts => [chestAmount1, chestAmount2, chestAmount3];

  AppEconomyConfig copyWith({
    int? rewardSimple1,
    int? rewardSimple2,
    int? rewardSimple3,
    int? rewardNormal1,
    int? rewardNormal2,
    int? rewardNormal3,
    int? rewardElite1,
    int? rewardElite2,
    int? rewardElite3,
    int? rewardUnique1,
    int? rewardUnique2,
    int? rewardUnique3,
    int? rewardHardcore1,
    int? rewardHardcoreKill,
    int? hardcoreArenaMinAlive,
    int? penaltySimple,
    int? penaltyNormal,
    int? penaltyElite,
    int? penaltyUnique,
    int? penaltyHardcore,
    int? unlockNormal,
    int? unlockElite,
    int? unlockUnique,
    int? dailyMatchDiamondCap,
    int? chestAmount1,
    int? chestAmount2,
    int? chestAmount3,
    int? rewardClaimsPerDay,
    int? trainingClaimsPerDay,
    int? adDoublesPerDay,
  }) {
    return AppEconomyConfig(
      rewardSimple1: rewardSimple1 ?? this.rewardSimple1,
      rewardSimple2: rewardSimple2 ?? this.rewardSimple2,
      rewardSimple3: rewardSimple3 ?? this.rewardSimple3,
      rewardNormal1: rewardNormal1 ?? this.rewardNormal1,
      rewardNormal2: rewardNormal2 ?? this.rewardNormal2,
      rewardNormal3: rewardNormal3 ?? this.rewardNormal3,
      rewardElite1: rewardElite1 ?? this.rewardElite1,
      rewardElite2: rewardElite2 ?? this.rewardElite2,
      rewardElite3: rewardElite3 ?? this.rewardElite3,
      rewardUnique1: rewardUnique1 ?? this.rewardUnique1,
      rewardUnique2: rewardUnique2 ?? this.rewardUnique2,
      rewardUnique3: rewardUnique3 ?? this.rewardUnique3,
      rewardHardcore1: rewardHardcore1 ?? this.rewardHardcore1,
      rewardHardcoreKill: rewardHardcoreKill ?? this.rewardHardcoreKill,
      hardcoreArenaMinAlive:
          hardcoreArenaMinAlive ?? this.hardcoreArenaMinAlive,
      penaltySimple: penaltySimple ?? this.penaltySimple,
      penaltyNormal: penaltyNormal ?? this.penaltyNormal,
      penaltyElite: penaltyElite ?? this.penaltyElite,
      penaltyUnique: penaltyUnique ?? this.penaltyUnique,
      penaltyHardcore: penaltyHardcore ?? this.penaltyHardcore,
      unlockNormal: unlockNormal ?? this.unlockNormal,
      unlockElite: unlockElite ?? this.unlockElite,
      unlockUnique: unlockUnique ?? this.unlockUnique,
      dailyMatchDiamondCap:
          dailyMatchDiamondCap ?? this.dailyMatchDiamondCap,
      chestAmount1: chestAmount1 ?? this.chestAmount1,
      chestAmount2: chestAmount2 ?? this.chestAmount2,
      chestAmount3: chestAmount3 ?? this.chestAmount3,
      rewardClaimsPerDay: rewardClaimsPerDay ?? this.rewardClaimsPerDay,
      trainingClaimsPerDay:
          trainingClaimsPerDay ?? this.trainingClaimsPerDay,
      adDoublesPerDay: adDoublesPerDay ?? this.adDoublesPerDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'rewardSimple1': rewardSimple1,
        'rewardSimple2': rewardSimple2,
        'rewardSimple3': rewardSimple3,
        'rewardNormal1': rewardNormal1,
        'rewardNormal2': rewardNormal2,
        'rewardNormal3': rewardNormal3,
        'rewardElite1': rewardElite1,
        'rewardElite2': rewardElite2,
        'rewardElite3': rewardElite3,
        'rewardUnique1': rewardUnique1,
        'rewardUnique2': rewardUnique2,
        'rewardUnique3': rewardUnique3,
        'rewardHardcore1': rewardHardcore1,
        'rewardHardcoreKill': rewardHardcoreKill,
        'hardcoreArenaMinAlive': hardcoreArenaMinAlive,
        'penaltySimple': penaltySimple,
        'penaltyNormal': penaltyNormal,
        'penaltyElite': penaltyElite,
        'penaltyUnique': penaltyUnique,
        'penaltyHardcore': penaltyHardcore,
        'unlockNormal': unlockNormal,
        'unlockElite': unlockElite,
        'unlockUnique': unlockUnique,
        'dailyMatchDiamondCap': dailyMatchDiamondCap,
        'chestAmount1': chestAmount1,
        'chestAmount2': chestAmount2,
        'chestAmount3': chestAmount3,
        'rewardClaimsPerDay': rewardClaimsPerDay,
        'trainingClaimsPerDay': trainingClaimsPerDay,
        'adDoublesPerDay': adDoublesPerDay,
      };

  factory AppEconomyConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return defaults;

    int readInt(String key, int fallback, {int min = 0, int max = 99999}) {
      final raw = json[key];
      final value = raw is num
          ? raw.round()
          : int.tryParse(raw?.toString() ?? '') ?? fallback;
      return value.clamp(min, max);
    }

    var chest1 = readInt('chestAmount1', defaults.chestAmount1, min: 1, max: 500);
    var chest2 = readInt('chestAmount2', defaults.chestAmount2, min: 1, max: 500);
    var chest3 = readInt('chestAmount3', defaults.chestAmount3, min: 1, max: 500);
    if (chest2 < chest1) chest2 = chest1;
    if (chest3 < chest2) chest3 = chest2;

    var unlockN = readInt('unlockNormal', defaults.unlockNormal, max: 5000);
    var unlockE = readInt('unlockElite', defaults.unlockElite, max: 5000);
    var unlockU = readInt('unlockUnique', defaults.unlockUnique, max: 5000);
    if (unlockE < unlockN) unlockE = unlockN;
    if (unlockU < unlockE) unlockU = unlockE;

    return AppEconomyConfig(
      rewardSimple1: readInt('rewardSimple1', defaults.rewardSimple1, max: 100),
      rewardSimple2: readInt('rewardSimple2', defaults.rewardSimple2, max: 100),
      rewardSimple3: readInt('rewardSimple3', defaults.rewardSimple3, max: 100),
      rewardNormal1: readInt('rewardNormal1', defaults.rewardNormal1, max: 100),
      rewardNormal2: readInt('rewardNormal2', defaults.rewardNormal2, max: 100),
      rewardNormal3: readInt('rewardNormal3', defaults.rewardNormal3, max: 100),
      rewardElite1: readInt('rewardElite1', defaults.rewardElite1, max: 100),
      rewardElite2: readInt('rewardElite2', defaults.rewardElite2, max: 100),
      rewardElite3: readInt('rewardElite3', defaults.rewardElite3, max: 100),
      rewardUnique1: readInt('rewardUnique1', defaults.rewardUnique1, max: 100),
      rewardUnique2: readInt('rewardUnique2', defaults.rewardUnique2, max: 100),
      rewardUnique3: readInt('rewardUnique3', defaults.rewardUnique3, max: 100),
      rewardHardcore1:
          readInt('rewardHardcore1', defaults.rewardHardcore1, max: 200),
      rewardHardcoreKill:
          readInt('rewardHardcoreKill', defaults.rewardHardcoreKill, max: 50),
      hardcoreArenaMinAlive: readInt(
        'hardcoreArenaMinAlive',
        defaults.hardcoreArenaMinAlive,
        min: 2,
        max: 20,
      ),
      penaltySimple: readInt('penaltySimple', defaults.penaltySimple, max: 50),
      penaltyNormal: readInt('penaltyNormal', defaults.penaltyNormal, max: 50),
      penaltyElite: readInt('penaltyElite', defaults.penaltyElite, max: 50),
      penaltyUnique: readInt('penaltyUnique', defaults.penaltyUnique, max: 50),
      penaltyHardcore:
          readInt('penaltyHardcore', defaults.penaltyHardcore, max: 100),
      unlockNormal: unlockN,
      unlockElite: unlockE,
      unlockUnique: unlockU,
      dailyMatchDiamondCap: readInt(
        'dailyMatchDiamondCap',
        defaults.dailyMatchDiamondCap,
        min: 1,
        max: 5000,
      ),
      chestAmount1: chest1,
      chestAmount2: chest2,
      chestAmount3: chest3,
      rewardClaimsPerDay: readInt(
        'rewardClaimsPerDay',
        defaults.rewardClaimsPerDay,
        min: 1,
        max: 200,
      ),
      trainingClaimsPerDay: readInt(
        'trainingClaimsPerDay',
        defaults.trainingClaimsPerDay,
        min: 1,
        max: 100,
      ),
      adDoublesPerDay: readInt(
        'adDoublesPerDay',
        defaults.adDoublesPerDay,
        min: 0,
        max: 50,
      ),
    );
  }

  bool sameAs(AppEconomyConfig other) {
    return rewardSimple1 == other.rewardSimple1 &&
        rewardSimple2 == other.rewardSimple2 &&
        rewardSimple3 == other.rewardSimple3 &&
        rewardNormal1 == other.rewardNormal1 &&
        rewardNormal2 == other.rewardNormal2 &&
        rewardNormal3 == other.rewardNormal3 &&
        rewardElite1 == other.rewardElite1 &&
        rewardElite2 == other.rewardElite2 &&
        rewardElite3 == other.rewardElite3 &&
        rewardUnique1 == other.rewardUnique1 &&
        rewardUnique2 == other.rewardUnique2 &&
        rewardUnique3 == other.rewardUnique3 &&
        rewardHardcore1 == other.rewardHardcore1 &&
        rewardHardcoreKill == other.rewardHardcoreKill &&
        hardcoreArenaMinAlive == other.hardcoreArenaMinAlive &&
        penaltySimple == other.penaltySimple &&
        penaltyNormal == other.penaltyNormal &&
        penaltyElite == other.penaltyElite &&
        penaltyUnique == other.penaltyUnique &&
        penaltyHardcore == other.penaltyHardcore &&
        unlockNormal == other.unlockNormal &&
        unlockElite == other.unlockElite &&
        unlockUnique == other.unlockUnique &&
        dailyMatchDiamondCap == other.dailyMatchDiamondCap &&
        chestAmount1 == other.chestAmount1 &&
        chestAmount2 == other.chestAmount2 &&
        chestAmount3 == other.chestAmount3 &&
        rewardClaimsPerDay == other.rewardClaimsPerDay &&
        trainingClaimsPerDay == other.trainingClaimsPerDay &&
        adDoublesPerDay == other.adDoublesPerDay;
  }
}
