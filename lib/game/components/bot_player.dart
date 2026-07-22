import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/bot_difficulty.dart';
import '../config/bot_limits.dart';
import '../config/first_match_tuning.dart';
import '../models/bot_sync_state.dart';
import '../orbit_game.dart';
import '../../services/settings_service.dart';
import 'black_hole_partner.dart';
import 'cosmic_event_manager.dart';
import 'player.dart';
import '../systems/pickup_collision_system.dart';
import '../utils/black_hole_renderer.dart';
import '../utils/competitor_hole_renderer.dart';
import '../utils/entity_status_mixins.dart';
import '../utils/gravity_scaling.dart';
import '../utils/viewport_cull.dart';
import '../utils/world_bounds.dart';

enum BotPersonality { coward, aggressive, opportunist }

class _PreyTarget {
  const _PreyTarget(this.partner, this.score);

  final BlackHolePartner partner;
  final double score;
}

class _FoodTarget {
  const _FoodTarget(this.position, this.score);

  final Vector2 position;
  final double score;
}

/// AI-controlled black hole that follows the same rules as [Player].
///
/// On non-host clients in competitive rooms, [isNetworkDriven] is true and
/// pose comes from [applyNetworkState] instead of local AI.
class BotPlayer extends PositionComponent
    with EntityShieldMixin, EntitySpawnProtectionMixin, QuasarActivationMixin
    implements BlackHolePartner {
  BotPlayer({
    required this.networkId,
    required this.displayName,
    required this.personality,
    required this.difficulty,
    required Vector2 position,
    required this.accentHue,
    this.radius = Player.baseRadius,
    this.skin = 'pulsar',
    this.isPreyBot = false,
    this.isNetworkDriven = false,
  })  : accentColor = colorFromAccentHue(accentHue),
        _targetPosition = position.clone(),
        _targetRadius = radius,
        super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(BlackHoleRenderer.componentBoxSize(radius)),
        );

  static Color colorFromAccentHue(double hue) {
    final variant = (hue / 18).floor() % 3;
    final saturation = 0.72 + variant * 0.08;
    final lightness = 0.52 - variant * 0.06;
    return HSLColor.fromAHSL(1, hue % 360, saturation, lightness).toColor();
  }

  /// Stable id shared across the room (`bot_0`, …).
  final String networkId;

  @override
  String displayName;

  final BotPersonality personality;
  final BotDifficulty difficulty;
  String skin;
  double accentHue;
  Color accentColor;

  /// Basit odada yutulabilir kolay av — küçük kalır, yavaş büyür.
  final bool isPreyBot;

  /// When true, pose is lerped from host snapshots (no local AI).
  bool isNetworkDriven;

  double radius;

  @override
  final Vector2 velocity = Vector2.zero();

  @override
  bool isBoosting = false;

  @override
  bool isEliminated = false;

  @override
  bool get isSpawnProtected => spawnProtectionRemaining > 0;

  double diskRotation = 0;

  /// Boost energy 0–1 — same charge/active cadence as [Player].
  double boostEnergy = 0;
  double _boostActiveRemaining = 0;

  double _decisionTimer = 0;
  Vector2 _moveDir = Vector2(1, 0);
  final _rng = math.Random();
  final Vector2 _targetPosition;
  double _targetRadius;

  static const _steerAcceleration = 14.0;
  static const _networkLerpSpeed = 14.0;

  bool get _isBoostReady =>
      _boostActiveRemaining <= 0 && boostEnergy >= 1.0;

  double get _effectiveMaxSpeed => Player.maxSpeedForRadius(radius) *
      (isBoosting ? Player.boostSpeedMultiplier : 1.0);

  @override
  double get holeRadius => radius;

  @override
  bool isImmuneToGravityFrom(double otherRadius) =>
      isSpawnProtected || (isShieldActive && otherRadius > radius);

  @override
  void growBy(double amount) {
    setRadius(radius + amount);
  }

  void setRadius(double value) {
    final game = findGame() as OrbitGame?;
    var cap = game?.universeVictoryRadius ?? 500.0;
    if (isPreyBot) {
      cap = math.min(cap, FirstMatchTuning.simpleRoomPreyRadiusCap);
    }
    if (!isPreyBot && value >= cap) {
      radius = value;
      size = Vector2.all(BlackHoleRenderer.componentBoxSize(radius));
      game?.checkVictoryAfterGrowth();
      return;
    }
    radius = value.clamp(8.0, cap);
    size = Vector2.all(BlackHoleRenderer.componentBoxSize(radius));
  }

  @override
  void recordAbsorb() {}

  void tickBoostEnergy(double dt) {
    if (isEliminated) return;

    if (_boostActiveRemaining > 0) {
      _boostActiveRemaining -= dt;
      boostEnergy =
          (_boostActiveRemaining / Player.boostActiveDuration).clamp(0.0, 1.0);
      isBoosting = true;
      if (_boostActiveRemaining <= 0) {
        _boostActiveRemaining = 0;
        boostEnergy = 0;
        isBoosting = false;
      }
      return;
    }

    isBoosting = false;
    if (boostEnergy < 1.0) {
      boostEnergy =
          math.min(1.0, boostEnergy + dt / Player.boostChargeDuration);
    }
  }

  bool _tryActivateBoost() {
    if (isEliminated || !_isBoostReady) return false;
    _boostActiveRemaining = Player.boostActiveDuration;
    boostEnergy = 1.0;
    isBoosting = true;
    return true;
  }

  void tickStatus(double dt) {
    if (isShieldActive) {
      tickShield(dt);
    }
    tickQuasarFlash(dt);
  }

  void applyNetworkState(BotSyncState state) {
    _targetPosition.setValues(state.x, state.y);
    _targetRadius = state.radius;
    displayName = state.displayName;
    skin = state.activeSkin;
    if ((state.accentHue - accentHue).abs() > 0.5) {
      accentHue = state.accentHue;
      accentColor = colorFromAccentHue(accentHue);
    }
    isBoosting = state.boost;
    isShieldActive = state.shield;
    if (state.shield) {
      shieldTimeRemaining = math.max(shieldTimeRemaining, 0.35);
    }
  }

  void _tickNetworkDriven(double dt, OrbitGame game) {
    tickQuasarFlash(dt);
    final t = 1 - math.exp(-dt * _networkLerpSpeed);
    position.lerp(_targetPosition, t);
    setRadius(radius + (_targetRadius - radius) * t);
    WorldBounds.clampHoleCenter(
      position,
      radius: radius,
      worldSize: game.worldSize,
    );
    final massSpin =
        math.sqrt(GravityScaling.massFromRadius(radius)).clamp(0.85, 2.35);
    diskRotation += dt * (isBoosting ? 2.4 : 1.4) * massSpin;
  }

  void updateBot(double dt, OrbitGame game) {
    if (isEliminated) return;

    if (isNetworkDriven) {
      _tickNetworkDriven(dt, game);
      return;
    }

    tickSpawnProtection(dt);
    tickBoostEnergy(dt);
    tickStatus(dt);

    // Far from the camera: coast on the last steer dir — skip prey/food scans.
    // Movement + pickups still run so off-screen growth stays fair.
    final farFromView = ViewportCull.isFarFromView(
      game,
      position,
      margin: math.max(ViewportCull.updateMargin, radius * 6),
    );

    _decisionTimer -= dt;
    if (_decisionTimer <= 0) {
      final intervalScale = isPreyBot ? 1.28 : 1.0;
      var interval = intervalScale *
          (difficulty.decisionIntervalMin +
              _rng.nextDouble() *
                  (difficulty.decisionIntervalMax -
                      difficulty.decisionIntervalMin));
      if (farFromView) {
        // Rare coarse rethink so long-distance bots don't all fly forever.
        interval *= 3.4;
        _decisionTimer = interval;
        if (_rng.nextDouble() < 0.35) {
          final angle = _rng.nextDouble() * math.pi * 2;
          _moveDir = Vector2(math.cos(angle), math.sin(angle));
        }
      } else {
        _decisionTimer = interval;
        final chosen = _chooseDirection(game);
        // Higher hunt priority → commit to new aim faster (player-like).
        final blend = (0.56 +
                _rng.nextDouble() * 0.26 +
                difficulty.huntPriority * 0.1)
            .clamp(0.45, 0.92);
        _moveDir = Vector2(
          _moveDir.x * (1 - blend) + chosen.x * blend,
          _moveDir.y * (1 - blend) + chosen.y * blend,
        ).normalized();
      }
    }

    if (!farFromView) {
      _updateBoostIntent(game);
    }

    if (!game.gravityPhysics.isInspiralLocked(this)) {
      final pullStrength = farFromView
          ? (isPreyBot ? 0.62 : 0.78)
          : (isPreyBot ? 0.58 : 0.72) +
              _rng.nextDouble() * (isPreyBot ? 0.18 : 0.28);
      final steerDelta = _moveDir * (_effectiveMaxSpeed * pullStrength);
      velocity.addScaled(steerDelta, _steerAcceleration);
      final cap = _effectiveMaxSpeed;
      if (velocity.length > cap) {
        velocity.scale(cap / velocity.length);
      }
    }

    position.addScaled(velocity, dt);
    velocity.scale(1 / (1 + Player.movementFriction * dt));
    if (!farFromView) {
      diskRotation +=
          dt *
          1.6 *
          math.sqrt(GravityScaling.massFromRadius(radius)).clamp(0.85, 2.35);
    }

    final beforeX = position.x;
    final beforeY = position.y;
    WorldBounds.clampHoleCenter(
      position,
      radius: radius,
      worldSize: game.worldSize,
    );
    if (position.x != beforeX) velocity.x = 0;
    if (position.y != beforeY) velocity.y = 0;

    _collectNearbyPickups(game);
  }

  Vector2 _chooseDirection(OrbitGame game) {
    final eventDir = _eventStrategyDirection(game);
    if (eventDir != null) return eventDir;

    final threats = _nearbyThreats(game);
    if (threats.isNotEmpty) {
      final fleeBase = personality == BotPersonality.coward ? 1.0 : 0.68;
      var fleeWeight = fleeBase * (1 - difficulty.huntPriority * 0.28);
      if (isPreyBot && threats.any((t) => identical(t, game.player))) {
        fleeWeight *= 0.42;
      }
      var flee = Vector2.zero();
      for (final threat in threats.take(3)) {
        final away = position - threat.position;
        final dist = away.length;
        if (dist < 1) continue;
        flee.addScaled(away, (1 / dist) * fleeWeight);
      }
      if (flee.length2 > 0.01) return _applyAimJitter(flee.normalized());
    }

    final winDir = _victoryPushDirection(game);
    if (winDir != null) return _applyAimJitter(winDir);

    final mineDir = _mineStrategyDirection(game);
    if (mineDir != null) return _applyAimJitter(mineDir);

    final prey = _bestPrey(game);
    // Players commit to kills during shield windows and in the endgame race.
    var hesitation = _humanHesitationChance();
    if (isShieldActive) hesitation *= 0.35;
    if (radius >= game.universeVictoryRadius * 0.5) hesitation *= 0.5;
    if (prey != null && _rng.nextDouble() >= hesitation) {
      return _applyAimJitter(_huntDirection(prey.partner));
    }

    if (!isShieldActive) {
      final shield = _nearestShield(game);
      if (shield != null) {
        final threatened = _nearbyThreats(game).isNotEmpty;
        if (threatened && _rng.nextDouble() < 0.58) {
          return _applyAimJitter((shield - position).normalized());
        }
        if (personality == BotPersonality.coward) {
          return _applyAimJitter((shield - position).normalized());
        }
      }
    }

    if (prey != null && _rng.nextDouble() < _humanHesitationChance() * 0.55) {
      final food = _bestFood(game);
      if (food != null) {
        return _applyAimJitter((food.position - position).normalized());
      }
    }

    final food = _bestFood(game);
    if (food != null) {
      return _applyAimJitter((food.position - position).normalized());
    }

    final angle = _rng.nextDouble() * math.pi * 2;
    return Vector2(math.cos(angle), math.sin(angle));
  }

  double _humanHesitationChance() {
    final base = switch (personality) {
      BotPersonality.coward => 0.30,
      BotPersonality.aggressive => 0.10,
      BotPersonality.opportunist => 0.18,
    };
    // Decisive bots hesitate less — closer to committed human play.
    return (base * (1.12 - difficulty.huntPriority * 0.5)).clamp(0.04, 0.4);
  }

  Vector2 _applyAimJitter(Vector2 direction) {
    if (direction.length2 < 0.0001) return direction;
    final maxJitter = 0.08 + (1 - difficulty.huntPriority) * 0.1;
    if (_rng.nextDouble() > maxJitter) return direction.normalized();

    final angle = (_rng.nextDouble() - 0.5) * 0.5;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Vector2(
      direction.x * cos - direction.y * sin,
      direction.x * sin + direction.y * cos,
    ).normalized();
  }

  Vector2? _eventStrategyDirection(OrbitGame game) {
    if (difficulty.eventAwareness <= 0) return null;

    final events = game.eventManager;
    final awareness = difficulty.eventAwareness;

    if (events.activeEvent == CosmicEventType.supernovaWarning &&
        events.supernovaCenter != null) {
      final center = events.supernovaCenter!;
      final dist = position.distanceTo(center);

      if (radius < 72 ||
          (personality == BotPersonality.coward && dist < game.worldSize * 0.28)) {
        if (dist < game.worldSize * 0.32) {
          return _applyAimJitter((position - center).normalized());
        }
      }

      if (radius >= 52 && _rng.nextDouble() < awareness * 0.82) {
        return _applyAimJitter((center - position).normalized());
      }
    }

    if (events.eventPlanets.isNotEmpty &&
        radius >= difficulty.minHuntRadius * 0.7) {
      Vector2? best;
      var bestScore = 0.0;
      for (final planet in events.eventPlanets) {
        if (!planet.active) continue;
        final dist = position.distanceTo(planet.position);
        final score = planet.growthValue / (dist + 40) * awareness;
        if (score > bestScore) {
          bestScore = score;
          best = planet.position;
        }
      }
      if (best != null && bestScore > 0.02) {
        return _applyAimJitter((best - position).normalized());
      }
    }

    if (events.activeEvent == CosmicEventType.meteorShower) {
      if (personality == BotPersonality.coward && awareness >= 0.45) {
        final dust = _nearestMeteorDust(game);
        if (dust != null && position.distanceTo(dust) < radius * 5) {
          return _applyAimJitter((position - dust).normalized());
        }
      }

      final foodDust = _nearestMeteorDust(game);
      if (foodDust != null &&
          radius >= difficulty.minHuntRadius * 0.65 &&
          _rng.nextDouble() < awareness * 0.7) {
        return _applyAimJitter((foodDust - position).normalized());
      }
    }

    return null;
  }

  /// Win-focused endgame layer: push for universe dominance when close to the
  /// victory radius, and contest whoever is about to close the room.
  Vector2? _victoryPushDirection(OrbitGame game) {
    if (isPreyBot) return null;

    final victoryRadius = game.universeVictoryRadius;
    final myProgress = radius / victoryRadius;

    // Someone else is about to win — react like a player would.
    final leader = _victoryContender(game);
    if (leader != null) {
      final leaderProgress = leader.holeRadius / victoryRadius;
      if (leaderProgress >= 0.7 && !identical(leader, this)) {
        if (radius > leader.holeRadius * 1.02) {
          // We can still eat them: intercept before they close the room.
          return _huntDirection(leader);
        }
        if (position.distanceTo(leader.position) < radius * 7 &&
            radius < leader.holeRadius * 0.9) {
          // Too small to fight — keep farming, but away from the leader.
          final food = _bestFood(game);
          if (food != null) {
            final toFood = (food.position - position).normalized();
            final away = (position - leader.position).normalized();
            return (toFood + away * 0.8).normalized();
          }
          return (position - leader.position).normalized();
        }
      }
    }

    // Own final push: past ~70% of victory size, stop wandering and take the
    // shortest route to the finish (biggest safe meal available).
    if (myProgress >= 0.7) {
      final prey = _bestPrey(game);
      if (prey != null) return _huntDirection(prey.partner);
      final food = _bestFood(game);
      if (food != null) return (food.position - position).normalized();
    }

    return null;
  }

  /// Largest alive hole other than this bot (real players included).
  BlackHolePartner? _victoryContender(OrbitGame game) {
    BlackHolePartner? top;

    void consider(BlackHolePartner hole) {
      if (hole.isEliminated || identical(hole, this)) return;
      if (top == null || hole.holeRadius > top!.holeRadius) {
        top = hole;
      }
    }

    consider(game.player);
    for (final enemy in game.enemyPlayers) {
      consider(enemy);
    }
    for (final bot in game.botPopulation.bots) {
      consider(bot);
    }
    return top;
  }

  Vector2? _mineStrategyDirection(OrbitGame game) {
    final mine = _nearestMine(game);
    if (mine == null) return null;

    if (personality == BotPersonality.opportunist) {
      final orbit = mine +
          Vector2(
            math.cos(_decisionTimer * 3) * 120,
            math.sin(_decisionTimer * 3) * 120,
          );
      return (orbit - position).normalized();
    }

    if (difficulty.mineAvoidance > 0 &&
        personality != BotPersonality.opportunist) {
      final dist = position.distanceTo(mine);
      if (dist < 320 * difficulty.mineAvoidance) {
        return (position - mine).normalized();
      }
    }

    return null;
  }

  Vector2 _huntDirection(BlackHolePartner prey) {
    final preyPos = prey.position;
    if (!difficulty.interceptPrey || prey.velocity.length < 8) {
      return (preyPos - position).normalized();
    }

    final dist = position.distanceTo(preyPos);
    final speed = velocity.length.clamp(60.0, 180.0);
    final leadTime = dist / speed;
    final predicted = preyPos + prey.velocity * leadTime;
    return (predicted - position).normalized();
  }

  bool _updateBoostIntent(OrbitGame game) {
    if (isBoosting || !_isBoostReady) return false;
    return _tryActivateBoostWhenUseful(game);
  }

  bool _tryActivateBoostWhenUseful(OrbitGame game) {
    if (radius <= 15) return false;

    // Escape an incoming supernova blast like a player slamming boost.
    final events = game.eventManager;
    if (events.activeEvent == CosmicEventType.supernovaWarning &&
        events.supernovaCenter != null &&
        difficulty.eventAwareness > 0.3) {
      final dist = position.distanceTo(events.supernovaCenter!);
      if (dist < game.worldSize * 0.2 && radius < 90) {
        return _tryActivateBoost();
      }
    }

    final prey = _bestPrey(game);
    final threats = _nearbyThreats(game);
    final huntScale = 0.9 + difficulty.huntPriority * 0.45;

    // Endgame: sprint to close out the win before someone contests it.
    if (!isPreyBot && radius >= game.universeVictoryRadius * 0.7) {
      if (prey != null &&
          position.distanceTo(prey.partner.position) < radius * 7) {
        return _tryActivateBoost();
      }
    }

    if (!isBoosting && threats.isEmpty && _rng.nextDouble() < 0.2) {
      final food = _bestFood(game);
      if (food != null) {
        final dist = position.distanceTo(food.position);
        if (dist > radius * 2.2 && dist < radius * 6.5) {
          return _tryActivateBoost();
        }
      }
    }

    switch (personality) {
      case BotPersonality.coward:
        if (isPreyBot) return false;
        if (threats.isNotEmpty &&
            position.distanceTo(threats.first.position) < radius * 4) {
          return _tryActivateBoost();
        }
        return false;
      case BotPersonality.aggressive:
        if (prey != null &&
            position.distanceTo(prey.partner.position) <
                radius * 5.8 * huntScale &&
            radius > difficulty.minHuntRadius) {
          return _tryActivateBoost();
        }
        return false;
      case BotPersonality.opportunist:
        if (prey != null &&
            position.distanceTo(prey.partner.position) <
                radius * 4.2 * huntScale &&
            radius > difficulty.minHuntRadius) {
          return _tryActivateBoost();
        }
        return false;
    }
  }

  bool _isRealPlayer(BlackHolePartner hole, OrbitGame game) {
    if (identical(hole, game.player)) return true;
    return game.enemyPlayers.any((enemy) => identical(enemy, hole));
  }

  List<BlackHolePartner> _nearbyThreats(OrbitGame game) {
    final threshold = radius * difficulty.threatSizeRatio;
    final threats = <BlackHolePartner>[];

    if (game.player.holeRadius > threshold && !game.player.isEliminated) {
      threats.add(game.player);
    }
    for (final enemy in game.enemyPlayers) {
      if (!enemy.isEliminated && enemy.holeRadius > threshold) {
        threats.add(enemy);
      }
    }
    for (final bot in game.botPopulation.bots) {
      if (bot == this || bot.isEliminated) continue;
      if (bot.holeRadius > threshold) {
        threats.add(bot);
      }
    }
    threats.sort(
      (a, b) => position
          .distanceTo(a.position)
          .compareTo(position.distanceTo(b.position)),
    );
    return threats;
  }

  _PreyTarget? _bestPrey(OrbitGame game) {
    if (radius < difficulty.minHuntRadius) return null;

    final maxDist = radius * difficulty.preySearchMultiplier;
    final sizeLimit = radius * difficulty.preySizeRatio;
    _PreyTarget? best;

    void consider(BlackHolePartner hole) {
      if (hole.isEliminated || hole.holeRadius >= sizeLimit) return;
      final dist = position.distanceTo(hole.position);
      if (dist > maxDist) return;

      final sizeAdvantage = (radius - hole.holeRadius) / radius;
      var score = sizeAdvantage * difficulty.huntPriority / (1 + dist / radius);

      if (personality == BotPersonality.aggressive) {
        score *= 1.35;
      } else if (personality == BotPersonality.coward) {
        score *= 0.48;
      }

      if (_isRealPlayer(hole, game)) {
        score *= difficulty.playerTargetBias;
        if (hole.holeRadius >= radius * 0.72) {
          score *= 1.0 + difficulty.huntPriority * 0.35;
        }
        final leader = BotLimits.topRealPlayerRadius(game);
        if (leader >= 120) {
          score *= 1.0 + (leader / game.universeVictoryRadius) * 0.55;
        }
      }

      if (best == null || score > best!.score) {
        best = _PreyTarget(hole, score);
      }
    }

    consider(game.player);
    for (final enemy in game.enemyPlayers) {
      if (!enemy.isEliminated) consider(enemy);
    }
    for (final bot in game.botPopulation.bots) {
      if (bot != this) consider(bot);
    }

    if (best == null) return null;

    switch (personality) {
      case BotPersonality.aggressive:
        if (best!.score > 0.028) return best;
      case BotPersonality.opportunist:
        if (best!.score > 0.042 || radius > 58) return best;
      case BotPersonality.coward:
        if (best!.score > 0.1 && radius > 68) return best;
    }
    return null;
  }

  _FoodTarget? _bestFood(OrbitGame game) {
    final maxDist = radius * difficulty.foodSearchMultiplier;
    _FoodTarget? best;

    void consider(Vector2 foodPos, double growthValue) {
      final dist = position.distanceTo(foodPos);
      if (dist > maxDist) return;

      var score = growthValue / (dist + 50);

      if ((game.roomConfig.planetCount > 0 ||
              game.roomConfig.quasarFragmentCount > 0) &&
          growthValue >= 4) {
        score *= 1.35 + difficulty.huntPriority * 0.2;
      }

      if (best == null || score > best!.score) {
        best = _FoodTarget(foodPos, score);
      }
    }

    for (final asteroid in game.spawnManager.asteroids) {
      if (!asteroid.active || asteroid.isFragment) continue;
      consider(asteroid.position, asteroid.growthValue);
    }

    for (final planet in game.spawnManager.planets) {
      if (!planet.active) continue;
      consider(planet.position, planet.growthValue);
    }

    for (final fragment in game.spawnManager.quasarFragments) {
      if (!fragment.active) continue;
      consider(fragment.position, fragment.growthValue);
    }

    for (final planet in game.eventManager.eventPlanets) {
      if (!planet.active) continue;
      consider(
        planet.position,
        planet.growthValue * (1 + difficulty.eventAwareness),
      );
    }

    for (final dust in game.eventManager.meteorDust) {
      if (!dust.active) continue;
      consider(dust.position, dust.growthValue);
    }

    return best;
  }

  Vector2? _nearestShield(OrbitGame game) {
    for (final shield in game.spawnManager.shields) {
      if (!shield.active) continue;
      final dist = position.distanceTo(shield.position);
      if (dist < radius * 8) return shield.position;
    }
    return null;
  }

  Vector2? _nearestMine(OrbitGame game) {
    for (final mine in game.spawnManager.mines) {
      if (!mine.active) continue;
      final dist = position.distanceTo(mine.position);
      if (dist < 280) return mine.position;
    }
    return null;
  }

  Vector2? _nearestMeteorDust(OrbitGame game) {
    Vector2? nearest;
    var nearestDist = double.infinity;
    for (final dust in game.eventManager.meteorDust) {
      if (!dust.active) continue;
      final dist = position.distanceTo(dust.position);
      if (dist < nearestDist) {
        nearest = dust.position;
        nearestDist = dist;
      }
    }
    return nearest;
  }

  void _collectNearbyPickups(OrbitGame game) {
    PickupCollisionSystem.collectFor(
      consumer: this,
      spawn: game.spawnManager,
      events: game.eventManager,
    );
  }

  @override
  void render(Canvas canvas) {
    if (isEliminated) return;
    super.render(canvas);
    final game = findGame() as OrbitGame?;
    final showPortraits = SettingsService.instance.showProfilePictures;
    CompetitorHoleRenderer.paint(
      canvas: canvas,
      componentSize: size,
      game: game,
      position: position,
      radius: radius,
      diskRotation: diskRotation,
      skin: skin,
      accentColor: accentColor,
      isBoosting: isBoosting,
      showShieldRing: isShieldActive || isSpawnProtected,
      shieldPhase: isSpawnProtected
          ? spawnProtectionRemaining
          : shieldTimeRemaining,
      fragmentationAccent: accentColor,
      quasarFlash: quasarFlash,
      shaderKey: this,
      displayName: displayName,
      networkId: networkId,
      isBot: true,
      portraitInitial: showPortraits ? displayName : null,
      portraitColor: accentColor,
    );
  }
}
