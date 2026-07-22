/// Global AFK / idle koruma ayarları (lobi + maç).
class AppIdleConfig {
  const AppIdleConfig({
    required this.lobbyIdleBeforeWarningSeconds,
    required this.lobbyWarningCountdownSeconds,
    required this.matchIdleBeforeWarningSeconds,
    required this.matchWarningCountdownSeconds,
    required this.matchMassDrainPerSecond,
    required this.matchKickMassThreshold,
  });

  final int lobbyIdleBeforeWarningSeconds;
  final int lobbyWarningCountdownSeconds;
  final int matchIdleBeforeWarningSeconds;
  /// Maç AFK uyarısından sonra kütle erimesi başlamadan önceki geri sayım.
  final int matchWarningCountdownSeconds;
  final int matchMassDrainPerSecond;
  final int matchKickMassThreshold;

  static const defaults = AppIdleConfig(
    lobbyIdleBeforeWarningSeconds: 30,
    lobbyWarningCountdownSeconds: 15,
    matchIdleBeforeWarningSeconds: 10,
    matchWarningCountdownSeconds: 3,
    matchMassDrainPerSecond: 20,
    matchKickMassThreshold: 25,
  );

  Duration get lobbyIdleBeforeWarning =>
      Duration(seconds: lobbyIdleBeforeWarningSeconds);

  Duration get lobbyWarningCountdown =>
      Duration(seconds: lobbyWarningCountdownSeconds);

  Duration get matchIdleBeforeWarning =>
      Duration(seconds: matchIdleBeforeWarningSeconds);

  Duration get matchWarningCountdown =>
      Duration(seconds: matchWarningCountdownSeconds);

  AppIdleConfig copyWith({
    int? lobbyIdleBeforeWarningSeconds,
    int? lobbyWarningCountdownSeconds,
    int? matchIdleBeforeWarningSeconds,
    int? matchWarningCountdownSeconds,
    int? matchMassDrainPerSecond,
    int? matchKickMassThreshold,
  }) {
    return AppIdleConfig(
      lobbyIdleBeforeWarningSeconds:
          lobbyIdleBeforeWarningSeconds ?? this.lobbyIdleBeforeWarningSeconds,
      lobbyWarningCountdownSeconds:
          lobbyWarningCountdownSeconds ?? this.lobbyWarningCountdownSeconds,
      matchIdleBeforeWarningSeconds:
          matchIdleBeforeWarningSeconds ?? this.matchIdleBeforeWarningSeconds,
      matchWarningCountdownSeconds:
          matchWarningCountdownSeconds ?? this.matchWarningCountdownSeconds,
      matchMassDrainPerSecond:
          matchMassDrainPerSecond ?? this.matchMassDrainPerSecond,
      matchKickMassThreshold:
          matchKickMassThreshold ?? this.matchKickMassThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'lobbyIdleBeforeWarningSeconds': lobbyIdleBeforeWarningSeconds,
        'lobbyWarningCountdownSeconds': lobbyWarningCountdownSeconds,
        'matchIdleBeforeWarningSeconds': matchIdleBeforeWarningSeconds,
        'matchWarningCountdownSeconds': matchWarningCountdownSeconds,
        'matchMassDrainPerSecond': matchMassDrainPerSecond,
        'matchKickMassThreshold': matchKickMassThreshold,
      };

  factory AppIdleConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return defaults;

    int readInt(String key, int fallback, {int min = 1, int max = 600}) {
      final raw = json[key];
      final value = raw is num
          ? raw.round()
          : int.tryParse(raw?.toString() ?? '') ?? fallback;
      return value.clamp(min, max);
    }

    return AppIdleConfig(
      lobbyIdleBeforeWarningSeconds: readInt(
        'lobbyIdleBeforeWarningSeconds',
        defaults.lobbyIdleBeforeWarningSeconds,
        min: 5,
        max: 300,
      ),
      lobbyWarningCountdownSeconds: readInt(
        'lobbyWarningCountdownSeconds',
        defaults.lobbyWarningCountdownSeconds,
        min: 5,
        max: 120,
      ),
      matchIdleBeforeWarningSeconds: readInt(
        'matchIdleBeforeWarningSeconds',
        defaults.matchIdleBeforeWarningSeconds,
        min: 3,
        max: 120,
      ),
      matchWarningCountdownSeconds: readInt(
        'matchWarningCountdownSeconds',
        defaults.matchWarningCountdownSeconds,
        min: 1,
        max: 30,
      ),
      matchMassDrainPerSecond: readInt(
        'matchMassDrainPerSecond',
        defaults.matchMassDrainPerSecond,
        min: 1,
        max: 100,
      ),
      matchKickMassThreshold: readInt(
        'matchKickMassThreshold',
        defaults.matchKickMassThreshold,
        min: 5,
        max: 200,
      ),
    );
  }

  bool sameAs(AppIdleConfig other) {
    return lobbyIdleBeforeWarningSeconds ==
            other.lobbyIdleBeforeWarningSeconds &&
        lobbyWarningCountdownSeconds == other.lobbyWarningCountdownSeconds &&
        matchIdleBeforeWarningSeconds == other.matchIdleBeforeWarningSeconds &&
        matchWarningCountdownSeconds == other.matchWarningCountdownSeconds &&
        matchMassDrainPerSecond == other.matchMassDrainPerSecond &&
        matchKickMassThreshold == other.matchKickMassThreshold;
  }
}
