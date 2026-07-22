import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../config/first_match_tuning.dart';
import '../config/match_pacing.dart';
import '../config/room_config.dart';
import '../orbit_game.dart';
import '../config/room_visual_theme.dart';
import '../room_type.dart';
import '../utils/canvas_effects.dart';
import '../utils/gravity_motion.dart';
import '../utils/gravity_scaling.dart';
import '../utils/world_positions.dart';
import 'asteroid.dart';
import 'black_hole_partner.dart';
import 'bot_player.dart';
import 'hole_swallow_burst_effect.dart';
import 'quasar_fragment.dart';
import 'cosmic_mine.dart';
import 'explosion_effect.dart';
import 'planet.dart';
import 'shield_powerup.dart';

class CosmicSpawnManager extends Component with HasGameReference<OrbitGame> {
  CosmicSpawnManager({required this.config});

  final RoomConfig config;
  final List<Asteroid> _asteroids = [];
  final List<Planet> _planets = [];
  final List<QuasarFragment> _quasarFragments = [];
  final List<CosmicMine> _mines = [];
  final List<ShieldPowerUp> _shields = [];
  final _rng = math.Random();

  static const respawnDelay = Duration(milliseconds: 1500);
  static const shieldRespawnDelay = Duration(seconds: 45);

  MatchPacing get _pacing => MatchPacing.forRoom(game.roomType);

  Duration get _collectibleRespawnDelay => Duration(
        milliseconds:
            (respawnDelay.inMilliseconds * _pacing.respawnDelayMultiplier)
                .round()
                .clamp(600, respawnDelay.inMilliseconds),
      );

  List<Asteroid> get asteroids => List.unmodifiable(_asteroids);
  List<Planet> get planets => List.unmodifiable(_planets);
  List<QuasarFragment> get quasarFragments => List.unmodifiable(_quasarFragments);
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

    for (var i = 0; i < config.asteroidCount; i++) {
      await _spawnAsteroid(rockType: _randomAsteroidType());
      if (CanvasEffects.mobileLiteMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.asteroidTier6Count; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.largeAsteroid);
      if (CanvasEffects.mobileLiteMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.asteroidTier7Count; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.xlargeAsteroid);
      if (CanvasEffects.mobileLiteMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.asteroidTier8Count; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.giantAsteroid);
      if (CanvasEffects.mobileLiteMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.meteoriteCount; i++) {
      await _spawnAsteroid(rockType: CosmicRockType.meteorite);
      if (CanvasEffects.mobileLiteMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.planetCount; i++) {
      await _spawnPlanet(colorIndex: i);
      if (CanvasEffects.mobileLiteMode && i.isOdd) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < config.quasarFragmentCount; i++) {
      await _spawnQuasarFragment();
      if (CanvasEffects.mobileLiteMode && i.isOdd) {
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
      // Large maps + sparse global food: always seed a pocket near spawn so
      // the first viewport isn't an empty void around the player.
      await spawnNearbyRoomFood(game.player.position);
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

  /// Size 1–2 only (normal rooms).
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

  void absorbAsteroid(Asteroid asteroid) {
    absorbAsteroidFor(asteroid, game.player);
  }

  void absorbAsteroidFor(Asteroid asteroid, BlackHolePartner consumer) {
    if (!asteroid.active) return;
    final index = _asteroids.indexOf(asteroid);
    final rockType = asteroid.rockType;
    final preyPos = asteroid.position.clone();
    final preyRadius = asteroid.collisionRadius;
    asteroid.deactivate();
    _distributeGrowthTo(asteroid.growthValue, consumer);
    _spawnConsumableSwallowBurst(
      consumer: consumer,
      preyPosition: preyPos,
      preyRadius: preyRadius,
      accent: RoomVisualTheme.forRoom(game.roomType).accent,
    );
    HapticService.instance.lightImpact();

    if (index >= 0 && !asteroid.isFragment) {
      _asteroids.removeAt(index);
      _scheduleAsteroidRespawn(rockType);
    }
  }

  void absorbPlanet(Planet planet) {
    absorbPlanetFor(planet, game.player);
  }

  void absorbPlanetFor(Planet planet, BlackHolePartner consumer) {
    if (!planet.active) return;
    final colorIndex = planet.colorIndex;
    final index = _planets.indexOf(planet);
    final preyPos = planet.position.clone();
    final preyRadius = planet.collisionRadius;
    planet.deactivate();
    _distributeGrowthTo(planet.growthValue, consumer);
    _spawnConsumableSwallowBurst(
      consumer: consumer,
      preyPosition: preyPos,
      preyRadius: preyRadius,
      accent: RoomVisualTheme.forRoom(game.roomType).accent,
    );
    HapticService.instance.lightImpact();
    // Full-planet consumption — Stage 4 quasar activation reference beat.
    game.triggerQuasarActivation(consumer, planet.growthValue);

    if (index >= 0) {
      _planets.removeAt(index);
      _schedulePlanetRespawn(colorIndex);
    }
  }

  void absorbQuasarFragment(QuasarFragment fragment) {
    absorbQuasarFragmentFor(fragment, game.player);
  }

  void absorbQuasarFragmentFor(
    QuasarFragment fragment,
    BlackHolePartner consumer,
  ) {
    if (!fragment.active) return;
    final index = _quasarFragments.indexOf(fragment);
    final preyPos = fragment.position.clone();
    final preyRadius = fragment.collisionRadius;
    fragment.deactivate();
    _distributeGrowthTo(fragment.growthValue, consumer);
    _spawnConsumableSwallowBurst(
      consumer: consumer,
      preyPosition: preyPos,
      preyRadius: preyRadius,
      accent: RoomVisualTheme.forRoom(game.roomType).secondaryAccent,
    );
    HapticService.instance.lightImpact();
    game.triggerQuasarActivation(consumer, fragment.growthValue);

    if (index >= 0) {
      _quasarFragments.removeAt(index);
      _scheduleQuasarFragmentRespawn();
    }
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

  void _distributeGrowthTo(double amount, BlackHolePartner consumer) {
    if (consumer == game.player) {
      distributeGrowth(amount);
      return;
    }
    // Same room food pacing as the player so bots don't close matches early.
    final pacing = MatchPacing.forRoom(game.roomType);
    amount *= config.foodGrowthMultiplier;
    amount *= pacing.lateGrowthMultiplier(consumer.holeRadius);
    if (consumer is BotPlayer && game.isBotOnlyRoom) {
      amount *= consumer.isPreyBot
          ? FirstMatchTuning.simpleRoomPreyGrowthMultiplier
          : FirstMatchTuning.simpleRoomBotGrowthMultiplier;
    }
    consumer.growBy(amount);
    consumer.recordAbsorb();
  }

  void distributeGrowth(double amount) {
    final pacing = MatchPacing.forRoom(game.roomType);
    var scaled = amount * config.foodGrowthMultiplier;
    if (game.matchElapsed <= pacing.earlyGameDurationSeconds) {
      scaled *= pacing.earlyGamePlayerGrowthMultiplier;
    }
    scaled *= pacing.lateGrowthMultiplier(game.player.holeRadius);

    final partner = game.tacticalManager.activeLinkPartner;
    if (partner != null && game.tacticalManager.isLinked) {
      final half = scaled / 2;
      game.player.growBy(half);
      partner.growBy(half);
      game.player.recordAbsorb();
      partner.recordAbsorb();
      return;
    }

    game.player.growBy(scaled);
    game.player.recordAbsorb();
  }

  void collectShield(ShieldPowerUp shield) {
    collectShieldFor(shield, game.player);
  }

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

  void triggerMineExplosion(CosmicMine mine) {
    triggerMineExplosionFor(mine, game.player);
  }

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

    for (final asteroid in _asteroids) {
      if (!asteroid.active || asteroid.isFragment) continue;
      if (!_nearAnyGravitySource(
        asteroid.position,
        asteroid.collisionRadius,
        sources,
        roomMultiplier,
      )) {
        continue;
      }
      for (final hole in sources) {
        _pullEntityToward(
          asteroid,
          hole.position,
          hole.radius,
          roomMultiplier,
          dt,
          entityRadius: asteroid.collisionRadius,
          entityVelocity: asteroid.velocity,
        );
      }
      game.tacticalManager.applyLinkedGravityPull(
        asteroid,
        dt,
        roomMultiplier: roomMultiplier,
      );
    }
    for (final planet in _planets) {
      if (!planet.active) continue;
      if (!_nearAnyGravitySource(
        planet.position,
        planet.collisionRadius,
        sources,
        roomMultiplier,
      )) {
        continue;
      }
      for (final hole in sources) {
        _pullEntityToward(
          planet,
          hole.position,
          hole.radius,
          roomMultiplier,
          dt,
          entityRadius: planet.collisionRadius,
          entityVelocity: planet.velocity,
        );
      }
      game.tacticalManager.applyLinkedGravityPull(
        planet,
        dt,
        roomMultiplier: roomMultiplier,
      );
    }
    for (final fragment in _quasarFragments) {
      if (!fragment.active) continue;
      if (!_nearAnyGravitySource(
        fragment.position,
        fragment.collisionRadius,
        sources,
        roomMultiplier,
      )) {
        continue;
      }
      for (final hole in sources) {
        _pullEntityToward(
          fragment,
          hole.position,
          hole.radius,
          roomMultiplier,
          dt,
          entityRadius: fragment.collisionRadius,
          entityVelocity: fragment.velocity,
        );
      }
      game.tacticalManager.applyLinkedGravityPull(
        fragment,
        dt,
        roomMultiplier: roomMultiplier,
      );
    }
  }

  /// Skip the hole×entity pull loops when nothing is in influence range.
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

  void _pullEntityToward(
    PositionComponent entity,
    Vector2 sourcePosition,
    double sourceRadius,
    double roomMultiplier,
    double dt, {
    required double entityRadius,
    required Vector2 entityVelocity,
  }) {
    GravityMotion.accelerateToward(
      entityPosition: entity.position,
      entityVelocity: entityVelocity,
      sourcePosition: sourcePosition,
      sourceRadius: sourceRadius,
      entityRadius: entityRadius,
      dt: dt,
      roomMultiplier: roomMultiplier,
    );
  }

  /// Normalized matter influx toward a hole (0–1) — drives accretion stream VFX.
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
