/// Galibiyet puanı çarpanları + rütbe eşikleri (yönetici paneli / uzak JSON).
class AppRankConfig {
  const AppRankConfig({
    required this.winPointsSimple,
    required this.winPointsNormal,
    required this.winPointsElite,
    required this.winPointsUnique,
    required this.minPointsStellar,
    required this.minPointsNova,
    required this.minPointsQuasar,
    required this.minPointsSingularity,
  });

  /// Eğitim evreni 1.’lik puanı (varsayılan 0 = sayılmaz).
  final int winPointsSimple;
  final int winPointsNormal;
  final int winPointsElite;
  final int winPointsUnique;

  /// Nebula her zaman 0. Diğer basamaklar için minimum puan.
  final int minPointsStellar;
  final int minPointsNova;
  final int minPointsQuasar;
  final int minPointsSingularity;

  static const defaults = AppRankConfig(
    winPointsSimple: 0,
    winPointsNormal: 1,
    winPointsElite: 2,
    winPointsUnique: 3,
    minPointsStellar: 8,
    minPointsNova: 25,
    minPointsQuasar: 75,
    minPointsSingularity: 200,
  );

  int winPointsForRoom(String roomType) {
    return switch (roomType.toLowerCase()) {
      'simple' => winPointsSimple,
      'elite' => winPointsElite,
      'unique' => winPointsUnique,
      _ => winPointsNormal,
    };
  }

  /// Highest-first list of (tierId, minPoints).
  List<(String id, int minPoints)> get tierThresholdsDesc => [
        ('singularity', minPointsSingularity),
        ('quasar', minPointsQuasar),
        ('nova', minPointsNova),
        ('stellar', minPointsStellar),
        ('nebula', 0),
      ];

  int minPointsForTier(String tierId) {
    return switch (tierId) {
      'singularity' => minPointsSingularity,
      'quasar' => minPointsQuasar,
      'nova' => minPointsNova,
      'stellar' => minPointsStellar,
      _ => 0,
    };
  }

  AppRankConfig copyWith({
    int? winPointsSimple,
    int? winPointsNormal,
    int? winPointsElite,
    int? winPointsUnique,
    int? minPointsStellar,
    int? minPointsNova,
    int? minPointsQuasar,
    int? minPointsSingularity,
  }) {
    return AppRankConfig(
      winPointsSimple: winPointsSimple ?? this.winPointsSimple,
      winPointsNormal: winPointsNormal ?? this.winPointsNormal,
      winPointsElite: winPointsElite ?? this.winPointsElite,
      winPointsUnique: winPointsUnique ?? this.winPointsUnique,
      minPointsStellar: minPointsStellar ?? this.minPointsStellar,
      minPointsNova: minPointsNova ?? this.minPointsNova,
      minPointsQuasar: minPointsQuasar ?? this.minPointsQuasar,
      minPointsSingularity:
          minPointsSingularity ?? this.minPointsSingularity,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'winPointsSimple': winPointsSimple,
        'winPointsNormal': winPointsNormal,
        'winPointsElite': winPointsElite,
        'winPointsUnique': winPointsUnique,
        'minPointsStellar': minPointsStellar,
        'minPointsNova': minPointsNova,
        'minPointsQuasar': minPointsQuasar,
        'minPointsSingularity': minPointsSingularity,
      };

  factory AppRankConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return defaults;

    int readInt(String key, int fallback, {int min = 0, int max = 99999}) {
      final raw = json[key];
      final value = raw is num
          ? raw.round()
          : int.tryParse(raw?.toString() ?? '') ?? fallback;
      return value.clamp(min, max);
    }

    var stellar = readInt('minPointsStellar', defaults.minPointsStellar);
    var nova = readInt('minPointsNova', defaults.minPointsNova);
    var quasar = readInt('minPointsQuasar', defaults.minPointsQuasar);
    var singularity =
        readInt('minPointsSingularity', defaults.minPointsSingularity);

    // Enforce strictly increasing ladder.
    if (stellar < 1) stellar = 1;
    if (nova <= stellar) nova = stellar + 1;
    if (quasar <= nova) quasar = nova + 1;
    if (singularity <= quasar) singularity = quasar + 1;

    return AppRankConfig(
      winPointsSimple: readInt(
        'winPointsSimple',
        defaults.winPointsSimple,
        max: 50,
      ),
      winPointsNormal: readInt(
        'winPointsNormal',
        defaults.winPointsNormal,
        max: 50,
      ),
      winPointsElite: readInt(
        'winPointsElite',
        defaults.winPointsElite,
        max: 50,
      ),
      winPointsUnique: readInt(
        'winPointsUnique',
        defaults.winPointsUnique,
        max: 50,
      ),
      minPointsStellar: stellar,
      minPointsNova: nova,
      minPointsQuasar: quasar,
      minPointsSingularity: singularity,
    );
  }

  bool sameAs(AppRankConfig other) {
    return winPointsSimple == other.winPointsSimple &&
        winPointsNormal == other.winPointsNormal &&
        winPointsElite == other.winPointsElite &&
        winPointsUnique == other.winPointsUnique &&
        minPointsStellar == other.minPointsStellar &&
        minPointsNova == other.minPointsNova &&
        minPointsQuasar == other.minPointsQuasar &&
        minPointsSingularity == other.minPointsSingularity;
  }
}
