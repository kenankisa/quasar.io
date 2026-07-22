import '../room_type.dart';

/// Room-scoped knobs that shape average match length and moment-to-moment tempo.
///
/// Target averages:
/// - Simple: ~1.5–2.5 min onboarding
/// - Normal: 4–6 min (~5 min)
/// - Elite: 5–7 min (~6 min)
/// - Unique: 7–9 min (~8 min)
class MatchPacing {
  const MatchPacing({
    required this.targetMinutesMin,
    required this.targetMinutesMax,
    required this.supernovaIntervalSeconds,
    required this.supernovaFirstDelaySeconds,
    required this.eventGrowthCapPerBurst,
    required this.supernovaPlanetCount,
    required this.earlyGameDurationSeconds,
    required this.earlyGamePlayerGrowthMultiplier,
    required this.respawnDelayMultiplier,
    required this.meteorShowerInitialCooldown,
    required this.radiationRadius,
    required this.radiationIdleSeconds,
    required this.lateGameRadiationRadius,
    required this.lateGameRadiationIdleSeconds,
    required this.lateGameRadiationShrinkPerSecond,
  });

  final double targetMinutesMin;
  final double targetMinutesMax;

  /// Seconds between supernova warnings (0 = events disabled for room).
  final double supernovaIntervalSeconds;

  /// Delay before the first supernova warning (< [supernovaIntervalSeconds] = earlier first blast).
  final double supernovaFirstDelaySeconds;

  /// Max radius gain per hole from one supernova burst.
  final double eventGrowthCapPerBurst;

  final int supernovaPlanetCount;

  /// First ~60–90s: faster growth for the human player only.
  final double earlyGameDurationSeconds;
  final double earlyGamePlayerGrowthMultiplier;

  /// Multiplier on collectible respawn delay (< 1 = faster food return).
  final double respawnDelayMultiplier;

  /// Delay before the first meteor shower (keeps early farming calm).
  final double meteorShowerInitialCooldown;

  /// Anti-camp radiation starts at this radius.
  final double radiationRadius;

  /// Idle seconds before radiation at [radiationRadius]..[lateGameRadiationRadius).
  final double radiationIdleSeconds;

  /// Tighter endgame pressure once near universe victory.
  final double lateGameRadiationRadius;
  final double lateGameRadiationIdleSeconds;
  final double lateGameRadiationShrinkPerSecond;

  /// Soft snowball brake for food / PvE growth (not PvP merges).
  /// Starts ramping down after this fraction of [lateGameRadiationRadius].
  static const lateGrowthSoftcapStartFraction = 0.72;

  /// Floor multiplier once fully into the softcap band.
  static const lateGrowthSoftcapMinMultiplier = 0.58;

  /// Scales positive food growth for a hole at [holeRadius].
  double lateGrowthMultiplier(double holeRadius) {
    final start = lateGameRadiationRadius * lateGrowthSoftcapStartFraction;
    if (holeRadius < start) return 1.0;
    final span = (lateGameRadiationRadius - start).clamp(40.0, 220.0);
    final t = ((holeRadius - start) / span).clamp(0.0, 1.0);
    return 1.0 -
        t * (1.0 - lateGrowthSoftcapMinMultiplier);
  }

  static final Map<RoomType, MatchPacing> _overrides = {};

  static MatchPacing presetFor(RoomType type) => switch (type) {
        RoomType.simple => const MatchPacing(
            targetMinutesMin: 1.5,
            targetMinutesMax: 2.5,
            supernovaIntervalSeconds: 0,
            supernovaFirstDelaySeconds: 0,
            eventGrowthCapPerBurst: 0,
            supernovaPlanetCount: 0,
            earlyGameDurationSeconds: 50,
            earlyGamePlayerGrowthMultiplier: 1.15,
            respawnDelayMultiplier: 1.0,
            meteorShowerInitialCooldown: 0,
            radiationRadius: 140,
            radiationIdleSeconds: 16,
            lateGameRadiationRadius: 380,
            lateGameRadiationIdleSeconds: 11,
            lateGameRadiationShrinkPerSecond: 1.4,
          ),
        RoomType.normal => const MatchPacing(
            targetMinutesMin: 4,
            targetMinutesMax: 6,
            supernovaIntervalSeconds: 95,
            supernovaFirstDelaySeconds: 75,
            eventGrowthCapPerBurst: 48,
            supernovaPlanetCount: 22,
            earlyGameDurationSeconds: 55,
            earlyGamePlayerGrowthMultiplier: 1.12,
            respawnDelayMultiplier: 0.95,
            meteorShowerInitialCooldown: 90,
            radiationRadius: 150,
            radiationIdleSeconds: 15,
            lateGameRadiationRadius: 400,
            lateGameRadiationIdleSeconds: 12,
            lateGameRadiationShrinkPerSecond: 1.6,
          ),
        RoomType.elite => const MatchPacing(
            targetMinutesMin: 5,
            targetMinutesMax: 7,
            supernovaIntervalSeconds: 85,
            supernovaFirstDelaySeconds: 65,
            eventGrowthCapPerBurst: 45,
            supernovaPlanetCount: 20,
            earlyGameDurationSeconds: 50,
            earlyGamePlayerGrowthMultiplier: 1.08,
            respawnDelayMultiplier: 1.0,
            meteorShowerInitialCooldown: 42,
            radiationRadius: 155,
            radiationIdleSeconds: 14,
            lateGameRadiationRadius: 410,
            lateGameRadiationIdleSeconds: 11,
            lateGameRadiationShrinkPerSecond: 1.75,
          ),
        RoomType.unique => const MatchPacing(
            targetMinutesMin: 7,
            targetMinutesMax: 9,
            supernovaIntervalSeconds: 80,
            supernovaFirstDelaySeconds: 60,
            eventGrowthCapPerBurst: 40,
            supernovaPlanetCount: 18,
            earlyGameDurationSeconds: 45,
            earlyGamePlayerGrowthMultiplier: 1.0,
            respawnDelayMultiplier: 1.1,
            meteorShowerInitialCooldown: 50,
            radiationRadius: 165,
            radiationIdleSeconds: 10,
            lateGameRadiationRadius: 420,
            lateGameRadiationIdleSeconds: 8,
            lateGameRadiationShrinkPerSecond: 2.25,
          ),
      };

  static void applyOverrides(Map<RoomType, MatchPacing> values) {
    _overrides
      ..clear()
      ..addAll(values);
  }

  static void clearOverrides() => _overrides.clear();

  static MatchPacing forRoom(RoomType type) =>
      _overrides[type] ?? presetFor(type);
}
