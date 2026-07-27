import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../config/first_match_tuning.dart';
import '../config/room_config.dart';
import '../config/room_visual_theme.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../systems/growth_system.dart';
import '../utils/canvas_effects.dart';
import '../utils/gravity_motion.dart';
import '../utils/gravity_scaling.dart';
import '../utils/world_positions.dart';
import '../utils/world_spatial_index.dart';
import 'asteroid.dart';
import 'black_hole_partner.dart';
import 'bot_player.dart';
import 'gravity_matter.dart';
import 'hole_swallow_burst_effect.dart';
import 'quasar_fragment.dart';
import 'cosmic_mine.dart';
import 'explosion_effect.dart';
import 'planet.dart';
import 'shield_powerup.dart';

/// Tagged reference for spatial pickup queries.
enum SpawnPickupKind { asteroid, planet, quasarFragment, mine, shield }

class SpawnPickupRef {
  const SpawnPickupRef(this.kind, this.entity);

  final SpawnPickupKind kind;
  final Object entity;
}

class CosmicSpawnManager extends Component with HasGameReference<OrbitGame> {
  CosmicSpawnManager({required this.config});

  final RoomConfig config;
  final List<Asteroid> _asteroids = [];
  final List<Planet> _planets = [];
  final List<QuasarFragment> _quasarFragments = [];
  final List<CosmicMine> _mines = [];
  final List<ShieldPowerUp> _shields = [];
  final _rng = math.Random();
  late final WorldSpatialIndex<SpawnPickupRef> _pickupIndex;

  static const respawnDelay = Duration(milliseconds: 1500);
  static const shieldRespawnDelay = Duration(seconds: 45);

  /// Max collectible radius + margin for spatial pickup queries.
  static const _pickupQueryMargin = 120.0;

  GrowthSystem get _growth => game.matchRules.growthContext(
        matchElapsed: game.matchElapsed,
        isBotOnlyRoom: game.isBotOnlyRoom,
        extraFoodMultiplier: game.hardcoreArena.foodGrowthMultiplier(),
      );

  Duration get _collectibleRespawnDelay => Duration(
        milliseconds:
            (respawnDelay.inMilliseconds *
                    game.matchRules.pacing.respawnDelayMultiplier)
                .round()
                .clamp(600, respawnDelay.inMilliseconds),
      );

  List<Asteroid> get asteroids => List.unmodifiable(_asteroids);
  List<Planet> get planets => List.unmodifiable(_planets);
  List<QuasarFragment> get quasarFragments =>
      List.unmodifiable(_quasarFragments);
  List<CosmicMine> get mines => List.unmodifiable(_mines);
  List<ShieldPowerUp> get shields => List.unmodifiable(_shields);

  Iterable<Vector2> get _avoidPositions sync* {
    yield game.player.position;
    for (final asteroid in _asteroids) {
      if (asteroid.active) yield asteroid.position;
    }
    for (final planet in _planets) {
      if (planet.active) yield planet.position;
    }
    for (final fragment in _quasarFragments) {
      if (fragment.active) yield fragment.position;
    }
    for (final mine in _mines) {
      if (mine.active) yield mine.position;
    }
    for (final shield in _shields) {
      if (shield.active) yield shield.position;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _pickupIndex = WorldSpatialIndex(worldSize: game.worldSize);

    for (var i = 0; i < config.asteroidCount; i++) {
      await _spawnAsteroid(rockType: _randomAsteroidType());
      if (CanvasEffects.economyMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.asteroidTier6Count; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.largeAsteroid);
      if (CanvasEffects.economyMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.asteroidTier7Count; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.xlargeAsteroid);
      if (CanvasEffects.economyMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.asteroidTier8Count; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.giantAsteroid);
      if (CanvasEffects.economyMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.meteoriteCount; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.meteorite);
      if (CanvasEffects.economyMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.planetCount; i++) {
      await _spawnPlanet(colorIndex: i);
      if (CanvasEffects.economyMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.quasarFragmentCount; i++) {
      await _spawnQuasarFragment();
      if (CanvasEffects.economyMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.mineCount; i++) {
      await _spawnMine();
    }
    await _spawnShield();
    if (FirstMatchTuning.shouldSpawnStarterCluster(
      roomType: game.roomType,
      isFirstMatch: game.isFirstMatchExperience,
    )) {
      await spawnStarterClusterNear(game.player.position);
    } else if (game.roomType == RoomType.unique ||
        game.roomType == RoomType.elite) {
      await spawnNearbyRoomFood(game.player.position);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rebuildPickupIndex();
  }

  void forEachPickupNear(
    Vector2 center,
    double holeRadius,
    void Function(SpawnPickupRef ref) visit,
  ) {
    _pickupIndex.forEachNear(
      center,
      holeRadius + _pickupQueryMargin,
      (ref, _) => visit(ref),
    );
  }

  /// Food-only spatial query for bot farming AI.
  void forEachFoodNear(
    Vector2 center,
    double searchRadius,
    void Function(Vector2 position, double growthValue) visit,
  ) {
    forEachPickupNear(center, searchRadius, (ref) {
      switch (ref.kind) {
        case SpawnPickupKind.asteroid:
          final asteroid = ref.entity as Asteroid;
          if (!asteroid.active || asteroid.isFragment) return;
          visit(asteroid.position, asteroid.growthValue);
        case SpawnPickupKind.planet:
          final planet = ref.entity as Planet;
          if (!planet.active) return;
          visit(planet.position, planet.growthValue);
        case SpawnPickupKind.quasarFragment:
          final fragment = ref.entity as QuasarFragment;
          if (!fragment.active) return;
          visit(fragment.position, fragment.growthValue);
        case SpawnPickupKind.mine:
        case SpawnPickupKind.shield:
          return;
      }
    });
  }

  void _rebuildPickupIndex() {
    _pickupIndex.clear();
    for (final asteroid in _asteroids) {
      if (!asteroid.active) continue;
      _pickupIndex.insert(
        asteroid.position,
        SpawnPickupRef(SpawnPickupKind.asteroid, asteroid),
      );
    }
    for (final planet in _planets) {
      if (!planet.active) continue;
      _pickupIndex.insert(
        planet.position,
        SpawnPickupRef(SpawnPickupKind.planet, planet),
      );
    }
    for (final fragment in _quasarFragments) {
      if (!fragment.active) continue;
      _pickupIndex.insert(
        fragment.position,
        SpawnPickupRef(SpawnPickupKind.quasarFragment, fragment),
      );
    }
    for (final mine in _mines) {
      if (!mine.active) continue;
      _pickupIndex.insert(
        mine.position,
        SpawnPickupRef(SpawnPickupKind.mine, mine),
      );
    }
    for (final shield in _shields) {
      if (!shield.active) continue;
      _pickupIndex.insert(
        shield.position,
        SpawnPickupRef(SpawnPickupKind.shield, shield),
      );
    }
  }

  /// Dense food pocket so the first minute feels rewarding.
  Future<void> spawnStarterClusterNear(Vector2 center) async {
    const count = FirstMatchTuning.starterClusterCount;
    final useSimpleRocks = game.roomType == RoomType.simple;
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final dist = 180 + _rng.nextDouble() * 220;
      final position = center.clone()
        ..add(Vector2(math.cos(angle), math.sin(angle)) * dist);
      final rockType = useSimpleRocks
          ? switch (_rng.nextInt(3)) {
              0 => CosmicRockType.largeAsteroid,
              1 => CosmicRockType.xlargeAsteroid,
              _ => CosmicRockType.giantAsteroid,
            }
          : _randomAsteroidType();
      final asteroid = Asteroid(position: position, rockType: rockType);
      await game.world.add(asteroid);
      _asteroids.add(asteroid);
    }
  }

  /// Local planets / quasar fragments for elite & unique first viewport.
  Future<void> spawnNearbyRoomFood(Vector2 center) async {
    final unique = game.roomType == RoomType.unique;
    final count = unique ? 10 : 8;
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final dist = 160 + _rng.nextDouble() * 280;
      final position = center.clone()
        ..add(Vector2(math.cos(angle), math.sin(angle)) * dist);

      if (unique && _rng.nextDouble() < 0.42) {
        final fragment = QuasarFragment(position: position);
        await game.world.add(fragment);
        _quasarFragments.add(fragment);
      } else if (game.roomType == RoomType.elite || unique) {
        final planet = Planet(
          position: position,
          colorIndex: _planets.length + i,
        );
        await game.world.add(planet);
        _planets.add(planet);
      } else {
        final asteroid = Asteroid(
          position: position,
          rockType: CosmicRockType.meteorite,
        );
        await game.world.add(asteroid);
        _asteroids.add(asteroid);
      }
    }
  }

  CosmicRockType _randomAsteroidType() {
    return _rng.nextDouble() < 0.62
        ? CosmicRockType.smallAsteroid
        : CosmicRockType.mediumAsteroid;
  }

  Future<void> _spawnAsteroid({
    required CosmicRockType rockType,
    bool track = true,
  }) async {
    final position = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 50,
      avoid: _avoidPositions,
      minSeparation: rockType.isMeteorite || rockType.isSimpleTier ? 90 : 70,
    );
    final asteroid = Asteroid(position: position, rockType: rockType);
    await game.world.add(asteroid);
    if (track) {
      _asteroids.add(asteroid);
    }
  }

  Future<void> _spawnPlanet({required int colorIndex, bool track = true}) async {
    final position = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 60,
      avoid: _avoidPositions,
      minSeparation: 90,
    );
    final planet = Planet(position: position, colorIndex: colorIndex);
    await game.world.add(planet);
    if (track) {
      _planets.add(planet);
    }
  }

  Future<void> _spawnQuasarFragment({bool track = true}) async {
    final position = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 70,
      avoid: _avoidPositions,
      minSeparation: 110,
    );
    final fragment = QuasarFragment(position: position);
    await game.world.add(fragment);
    if (track) {
      _quasarFragments.add(fragment);
    }
  }

  Future<void> _spawnMine() async {
    final position = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 80,
      avoid: _avoidPositions,
      minSeparation: 250,
    );
    final mine = CosmicMine(position: position);
    await game.world.add(mine);
    _mines.add(mine);
  }

  Future<void> _spawnShield() async {
    final position = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 70,
      avoid: _avoidPositions,
      minSeparation: 200,
    );
    final shield = ShieldPowerUp(position: position);
    await game.world.add(shield);
    _shields.add(shield);
  }

  void absorbAsteroid(Asteroid asteroid) =>
      absorbAsteroidFor(asteroid, game.player);

  void absorbAsteroidFor(Asteroid asteroid, BlackHolePartner consumer) {
    _absorbConsumable(
      isActive: () => asteroid.active,
      deactivate: asteroid.deactivate,
      index: _asteroids.indexOf(asteroid),
      onRemoved: (index) {
        final rockType = asteroid.rockType;
        _asteroids.removeAt(index);
        if (!asteroid.isFragment) {
          _scheduleAsteroidRespawn(rockType);
        }
      },
      growthValue: asteroid.growthValue,
      preyPosition: asteroid.position,
      preyRadius: asteroid.collisionRadius,
      accent: RoomVisualTheme.forRoom(game.roomType).accent,
      consumer: consumer,
    );
  }

  void absorbPlanet(Planet planet) => absorbPlanetFor(planet, game.player);

  void absorbPlanetFor(Planet planet, BlackHolePartner consumer) {
    final colorIndex = planet.colorIndex;
    _absorbConsumable(
      isActive: () => planet.active,
      deactivate: planet.deactivate,
      index: _planets.indexOf(planet),
      onRemoved: (index) {
        _planets.removeAt(index);
        _schedulePlanetRespawn(colorIndex);
      },
      growthValue: planet.growthValue,
      preyPosition: planet.position,
      preyRadius: planet.collisionRadius,
      accent: RoomVisualTheme.forRoom(game.roomType).accent,
      consumer: consumer,
      onAfterGrowth: () =>
          game.triggerQuasarActivation(consumer, planet.growthValue),
    );
  }

  void absorbQuasarFragment(QuasarFragment fragment) =>
      absorbQuasarFragmentFor(fragment, game.player);

  void absorbQuasarFragmentFor(
    QuasarFragment fragment,
    BlackHolePartner consumer,
  ) {
    _absorbConsumable(
      isActive: () => fragment.active,
      deactivate: fragment.deactivate,
      index: _quasarFragments.indexOf(fragment),
      onRemoved: (index) {
        _quasarFragments.removeAt(index);
        _scheduleQuasarFragmentRespawn();
      },
      growthValue: fragment.growthValue,
      preyPosition: fragment.position,
      preyRadius: fragment.collisionRadius,
      accent: RoomVisualTheme.forRoom(game.roomType).secondaryAccent,
      consumer: consumer,
      onAfterGrowth: () =>
          game.triggerQuasarActivation(consumer, fragment.growthValue),
    );
  }

  void _absorbConsumable({
    required bool Function() isActive,
    required void Function() deactivate,
    required int index,
    required void Function(int index) onRemoved,
    required double growthValue,
    required Vector2 preyPosition,
    required double preyRadius,
    required Color accent,
    required BlackHolePartner consumer,
    void Function()? onAfterGrowth,
  }) {
    if (!isActive()) return;
    final preyPos = preyPosition.clone();
    deactivate();
    _applyGrowth(growthValue, consumer);
    _spawnConsumableSwallowBurst(
      consumer: consumer,
      preyPosition: preyPos,
      preyRadius: preyRadius,
      accent: accent,
    );
    HapticService.instance.lightImpact();
    onAfterGrowth?.call();

    if (index >= 0) {
      onRemoved(index);
    }
  }

  void _applyGrowth(double amount, BlackHolePartner consumer) {
    final isPlayer = consumer == game.player;
    if (isPlayer) {
      game.matchStats.recordParticle();
    }
    final partner = isPlayer ? game.tacticalManager.activeLinkPartner : null;
    _growth.apply(
      amount,
      consumer,
      isPlayer: isPlayer,
      bot: consumer is BotPlayer ? consumer : null,
      linkPartner: partner,
      isLinked: isPlayer && game.tacticalManager.isLinked,
    );
  }

  /// Applies food growth for any hole (player, bot, or event reward).
  void applyGrowthFor(double amount, BlackHolePartner consumer) {
    _applyGrowth(amount, consumer);
  }

  /// Legacy entry point for event growth — delegates to [GrowthSystem].
  void distributeGrowth(double amount) {
    _applyGrowth(amount, game.player);
  }

  /// Scales growth without applying — used by cosmic events with burst caps.
  double scaledGrowthFor(BlackHolePartner consumer, double base) {
    final isPlayer = consumer == game.player;
    return _growth.scaledAmount(
      base,
      consumer,
      applyEarlyGameBonus: isPlayer,
      bot: consumer is BotPlayer ? consumer : null,
    );
  }

  void _spawnConsumableSwallowBurst({
    required BlackHolePartner consumer,
    required Vector2 preyPosition,
    required double preyRadius,
    required Color accent,
  }) {
    if (consumer.isEliminated) return;

    final burstPos = GravityScaling.photonRingEntryPoint(
      predatorPosition: consumer.position,
      preyPosition: preyPosition,
      predatorRadius: consumer.holeRadius,
    );
    final infallAngle = math.atan2(
      consumer.position.y - preyPosition.y,
      consumer.position.x - preyPosition.x,
    );

    game.world.add(
      HoleSwallowBurstEffect(
        position: burstPos,
        predatorRadius: consumer.holeRadius,
        preyRadius: preyRadius,
        infallAngle: infallAngle,
        accent: accent,
      ),
    );
  }

  void collectShield(ShieldPowerUp shield) => collectShieldFor(shield, game.player);

  void collectShieldFor(ShieldPowerUp shield, BlackHolePartner consumer) {
    if (!shield.active) return;
    final index = _shields.indexOf(shield);
    shield.deactivate();

    if (consumer == game.player) {
      game.player.activateShield();
    } else if (consumer is BotPlayer) {
      consumer.activateShield();
    }

    if (index >= 0) {
      _shields.removeAt(index);
      _scheduleShieldRespawn();
    }
  }

  void triggerMineExplosion(CosmicMine mine) =>
      triggerMineExplosionFor(mine, game.player);

  void triggerMineExplosionFor(CosmicMine mine, BlackHolePartner victim) {
    if (!mine.active) return;
    if (victim.isSpawnProtected) return;

    mine.deactivate();

    final lostMass = victim.holeRadius * 0.3;
    victim.growBy(-lostMass);

    if (victim == game.player) {
      HapticService.instance.heavyImpact();
      game.triggerScreenShake();
    }

    game.world.add(
      ExplosionEffect(
        position: mine.position.clone(),
        maxRadius: CosmicMine.collisionRadius * 2.2,
      ),
    );

    final fragmentCount = 4 + _rng.nextInt(2);
    for (var i = 0; i < fragmentCount; i++) {
      final angle = (i / fragmentCount) * math.pi * 2 + _rng.nextDouble() * 0.4;
      final speed = 180 + _rng.nextDouble() * 120;
      final fragment = Asteroid(
        position: mine.position.clone(),
        collisionRadius: 5,
        growthValue: 1,
        isFragment: true,
        velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
      );
      game.world.add(fragment);
      _asteroids.add(fragment);
    }
  }

  void _scheduleAsteroidRespawn(CosmicRockType rockType) {
    Future.delayed(_collectibleRespawnDelay, () {
      if (!isMounted) return;
      if (rockType.isMeteorite) {
        if (config.meteoriteCount <= 0) return;
        _spawnAsteroid(rockType: CosmicRockType.meteorite);
        return;
      }
      if (rockType.isSimpleTier) {
        final canRespawn = switch (rockType) {
          CosmicRockType.largeAsteroid => config.asteroidTier6Count > 0,
          CosmicRockType.xlargeAsteroid => config.asteroidTier7Count > 0,
          CosmicRockType.giantAsteroid => config.asteroidTier8Count > 0,
          _ => false,
        };
        if (!canRespawn) return;
        _spawnAsteroid(rockType: rockType);
        return;
      }
      if (config.asteroidCount <= 0) return;
      _spawnAsteroid(rockType: _randomAsteroidType());
    });
  }

  void _schedulePlanetRespawn(int colorIndex) {
    Future.delayed(_collectibleRespawnDelay, () {
      if (!isMounted) return;
      if (config.planetCount <= 0) return;
      _spawnPlanet(colorIndex: colorIndex);
    });
  }

  void _scheduleQuasarFragmentRespawn() {
    Future.delayed(_collectibleRespawnDelay, () {
      if (!isMounted) return;
      if (config.quasarFragmentCount <= 0) return;
      _spawnQuasarFragment();
    });
  }

  void _scheduleShieldRespawn() {
    Future.delayed(shieldRespawnDelay, () {
      if (!isMounted) return;
      _spawnShield();
    });
  }

  void applyGravityPull(double dt) {
    if (config.gravityMultiplier <= 0) return;

    final roomMultiplier = config.gravityMultiplier;
    final sources = game.activeGravitySources();
    if (sources.isEmpty) return;

    void pullBatch(Iterable<GravityMatter> items, {bool skipFragments = false}) {
      for (final item in items) {
        if (!item.active) continue;
        if (skipFragments && item is Asteroid && item.isFragment) continue;
        if (!_nearAnyGravitySource(
          item.position,
          item.collisionRadius,
          sources,
          roomMultiplier,
        )) {
          continue;
        }
        for (final hole in sources) {
          GravityMotion.accelerateToward(
            entityPosition: item.position,
            entityVelocity: item.velocity,
            sourcePosition: hole.position,
            sourceRadius: hole.radius,
            entityRadius: item.collisionRadius,
            dt: dt,
            roomMultiplier: roomMultiplier,
          );
        }
        game.tacticalManager.applyLinkedGravityPull(
          item as PositionComponent,
          dt,
          roomMultiplier: roomMultiplier,
        );
      }
    }

    pullBatch(_asteroids, skipFragments: true);
    pullBatch(_planets);
    pullBatch(_quasarFragments);
  }

  bool _nearAnyGravitySource(
    Vector2 position,
    double entityRadius,
    List<({Vector2 position, double radius})> sources,
    double roomMultiplier,
  ) {
    for (final hole in sources) {
      final reach = GravityMotion.influenceRadius(
        sourceRadius: hole.radius,
        roomMultiplier: roomMultiplier,
      );
      if (position.distanceTo(hole.position) <= reach + entityRadius) {
        return true;
      }
    }
    return false;
  }

  double influxIntensityAt(Vector2 holePosition, double holeRadius) {
    if (config.gravityMultiplier <= 0) return 0;

    final roomMultiplier = config.gravityMultiplier;
    final reach = GravityScaling.consumableInfluenceRadius(
      holeRadius,
      roomMultiplier: roomMultiplier,
    );
    if (reach <= 0) return 0;

    var count = 0;
    var peakTidal = 0.0;

    void sample(Vector2 pos, double entityRadius) {
      final distance = pos.distanceTo(holePosition);
      if (distance > reach) return;
      count++;
      final tidal = GravityScaling.consumableTidalIntensity(
        sourceRadius: holeRadius,
        entityRadius: entityRadius,
        distance: distance,
        roomMultiplier: roomMultiplier,
      );
      if (tidal > peakTidal) peakTidal = tidal;
    }

    for (final asteroid in _asteroids) {
      if (!asteroid.active || asteroid.isFragment) continue;
      sample(asteroid.position, asteroid.collisionRadius);
    }
    for (final planet in _planets) {
      if (!planet.active) continue;
      sample(planet.position, planet.collisionRadius);
    }
    for (final fragment in _quasarFragments) {
      if (!fragment.active) continue;
      sample(fragment.position, fragment.collisionRadius);
    }

    if (count == 0) return 0;
    final density = (count / 6.0).clamp(0.0, 1.0);
    return (density * 0.45 + peakTidal * 0.55).clamp(0.0, 1.0);
  }
}
