import '../models/app_idle_config.dart';
import '../room_type.dart';

/// Resolved match AFK timing for the current room and player size.
class MatchAfkTempo {
  const MatchAfkTempo({
    required this.idleBeforeWarning,
    required this.warningCountdown,
    required this.warningCountdownSeconds,
    required this.massDrainPerSecond,
    required this.kickMassThreshold,
  });

  final Duration idleBeforeWarning;
  final Duration warningCountdown;
  final int warningCountdownSeconds;
  final int massDrainPerSecond;
  final int kickMassThreshold;

  static MatchAfkTempo resolve({
    required AppIdleConfig config,
    required RoomType roomType,
    required double mass,
  }) {
    if (roomType == RoomType.hardcore) {
      final lateGame = mass >= config.hardcoreAfkLateGameRadius;
      return MatchAfkTempo(
        idleBeforeWarning: Duration(
          seconds: lateGame
              ? config.hardcoreMatchIdleBeforeWarningLateSeconds
              : config.hardcoreMatchIdleBeforeWarningSeconds,
        ),
        warningCountdown: Duration(
          seconds: config.hardcoreMatchWarningCountdownSeconds,
        ),
        warningCountdownSeconds: config.hardcoreMatchWarningCountdownSeconds,
        massDrainPerSecond: lateGame
            ? config.hardcoreMatchMassDrainLatePerSecond
            : config.hardcoreMatchMassDrainPerSecond,
        kickMassThreshold: config.matchKickMassThreshold,
      );
    }

    return MatchAfkTempo(
      idleBeforeWarning: config.matchIdleBeforeWarning,
      warningCountdown: config.matchWarningCountdown,
      warningCountdownSeconds: config.matchWarningCountdownSeconds,
      massDrainPerSecond: config.matchMassDrainPerSecond,
      kickMassThreshold: config.matchKickMassThreshold,
    );
  }
}
