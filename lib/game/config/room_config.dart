import '../room_type.dart';

class RoomConfig {
  /// Shared food-pull gravity strength — same feel in every room type.
  static const standardGravityMultiplier = 1.0;

  const RoomConfig({
    required this.worldSize,
    required this.asteroidCount,
    required this.meteoriteCount,
    required this.planetCount,
    required this.quasarFragmentCount,
    required this.mineCount,
    required this.gravityMultiplier,
    this.foodGrowthMultiplier = 1.0,
    this.asteroidTier6Count = 0,
    this.asteroidTier7Count = 0,
    this.asteroidTier8Count = 0,
    this.cosmicEventsEnabled = true,
  });

  final double worldSize;

  /// Size 1–2 asteroids (normal rooms).
  final int asteroidCount;

  /// Size 3 meteorites / göktaşı (normal + elite).
  final int meteoriteCount;

  /// Size 4 planets (elite + unique).
  final int planetCount;

  /// Size 5 quasar fragments (unique).
  final int quasarFragmentCount;

  /// Size ~3–4.5 asteroids (simple rooms — legacy tier 6–8 slots).
  final int asteroidTier6Count;
  final int asteroidTier7Count;
  final int asteroidTier8Count;

  final int mineCount;
  final double gravityMultiplier;

  /// Multiplier on food growth for every hole (< 1 = slower snowball / longer matches).
  final double foodGrowthMultiplier;
  final bool cosmicEventsEnabled;

  static final Map<RoomType, RoomConfig> _overrides = {};

  static RoomConfig presetFor(RoomType type) => switch (type) {
        RoomType.simple => const RoomConfig(
            worldSize: 7500,
            asteroidCount: 0,
            meteoriteCount: 0,
            planetCount: 0,
            quasarFragmentCount: 0,
            mineCount: 0,
            gravityMultiplier: standardGravityMultiplier,
            foodGrowthMultiplier: 0.62,
            asteroidTier6Count: 130,
            asteroidTier7Count: 98,
            asteroidTier8Count: 65,
            cosmicEventsEnabled: false,
          ),
        RoomType.normal => const RoomConfig(
            worldSize: 8000,
            asteroidCount: 322,
            meteoriteCount: 92,
            planetCount: 0,
            quasarFragmentCount: 0,
            mineCount: 0,
            gravityMultiplier: standardGravityMultiplier,
            foodGrowthMultiplier: 0.65,
          ),
        RoomType.elite => const RoomConfig(
            worldSize: 8500,
            asteroidCount: 0,
            meteoriteCount: 138,
            planetCount: 172,
            quasarFragmentCount: 0,
            mineCount: 4,
            gravityMultiplier: standardGravityMultiplier,
            foodGrowthMultiplier: 0.70,
          ),
        RoomType.unique => const RoomConfig(
            worldSize: 9000,
            asteroidCount: 0,
            meteoriteCount: 0,
            planetCount: 98,
            quasarFragmentCount: 62,
            mineCount: 3,
            gravityMultiplier: standardGravityMultiplier,
            foodGrowthMultiplier: 0.75,
          ),
      };

  static void applyOverrides(Map<RoomType, RoomConfig> values) {
    _overrides
      ..clear()
      ..addAll(values);
  }

  static void clearOverrides() => _overrides.clear();

  static RoomConfig forRoom(RoomType type) =>
      _overrides[type] ?? presetFor(type);
}
