import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'black_hole_partner.dart';

import '../../utils/player_name.dart';

import '../../services/settings_service.dart';
import '../config/match_pacing.dart';
import '../config/skill_tree_config.dart';
import '../orbit_game.dart';
import '../utils/black_hole_avatar_loader.dart';
import '../utils/black_hole_name_label.dart';
import '../utils/black_hole_renderer.dart';
import '../utils/entity_status_mixins.dart';
import '../utils/gravity_scaling.dart';
import '../utils/gravity_visual.dart';
import '../utils/hole_swallow_visual.dart';
import '../utils/world_bounds.dart';
import 'swallow_hunt_particle_aura.dart';

class Player extends PositionComponent
    with EntityShieldMixin, EntitySpawnProtectionMixin, QuasarActivationMixin
    implements BlackHolePartner {
  Player({
    required this.activeSkin,
    this.avatarUrl,
    String displayName = 'You',
    super.position,
    this.radius = 25,
    this.abilityLoadout = AbilityLoadout.base,
  })  : displayName = clampPlayerName(displayName),
        teleportCooldownRemaining = abilityLoadout.teleportCooldown,
        abilityShieldCooldownRemaining = abilityLoadout.abilityShieldCooldown,
        shockwaveCooldownRemaining = abilityLoadout.shockwaveCooldown,
        super(
          anchor: Anchor.center,
          size: Vector2.all(BlackHoleRenderer.componentBoxSize(radius)),
        );

  final String activeSkin;
  final String? avatarUrl;

  @override
  final String displayName;

  double radius;

  @override
  final Vector2 velocity = Vector2.zero();

  @override
  bool isBoosting = false;
  bool isRadiating = false;
  @override
  bool isEliminated = false;

  double diskRotation = 0;
  ui.Image? avatarImage;
  double secondsSinceLastAbsorb = 0;
  double _radiationPulse = 0;
  double _avatarRetryTimer = 0;

  @override
  double get holeRadius => radius;

  static const _acceleration = 14.0;
  static const _friction = 4.0;
  static const baseMaxSpeed = 320.0;
  static const baseRadius = 25.0;
  /// Base constants for bots / defaults. Local player uses [abilityLoadout].
  static const boostSpeedMultiplier =
      AbilityLoadout.baseBoostSpeedMultiplier;
  static const boostChargeDuration = AbilityLoadout.baseBoostChargeDuration;
  static const boostActiveDuration = AbilityLoadout.baseBoostActiveDuration;
  static const spawnProtectionDuration = 3.0;
  static const movementFriction = _friction;
  static const teleportCooldown = AbilityLoadout.baseTeleportCooldown;
  static const teleportBriefShield = AbilityLoadout.baseTeleportBriefShield;
  static const abilityShieldCooldown =
      AbilityLoadout.baseAbilityShieldCooldown;
  static const abilityShieldDuration =
      AbilityLoadout.baseAbilityShieldDuration;
  static const shockwaveCooldown = AbilityLoadout.baseShockwaveCooldown;

  final AbilityLoadout abilityLoadout;

  /// Boost energy 0–1. Charges in loadout charge duration; tap at full for
  /// loadout active duration of speed without mass loss.
  double boostEnergy = 0;
  double _boostActiveRemaining = 0;

  /// Start passive (full cooldown); timers drain only after match play begins.
  double teleportCooldownRemaining;
  double abilityShieldCooldownRemaining;
  double shockwaveCooldownRemaining;

  bool get isBoostReady => _boostActiveRemaining <= 0 && boostEnergy >= 1.0;
  bool get isBoostActive => _boostActiveRemaining > 0;

  bool get isTeleportReady => teleportCooldownRemaining <= 0;
  bool get isAbilityShieldReady => abilityShieldCooldownRemaining <= 0;
  bool get isShockwaveReady => shockwaveCooldownRemaining <= 0;

  double get teleportCharge => _cooldownCharge(
        teleportCooldownRemaining,
        abilityLoadout.teleportCooldown,
      );
  double get abilityShieldCharge => _cooldownCharge(
        abilityShieldCooldownRemaining,
        abilityLoadout.abilityShieldCooldown,
      );
  double get shockwaveCharge => _cooldownCharge(
        shockwaveCooldownRemaining,
        abilityLoadout.shockwaveCooldown,
      );

  static double _cooldownCharge(double remaining, double total) {
    if (remaining <= 0 || total <= 0) return 1.0;
    return (1.0 - remaining / total).clamp(0.0, 1.0);
  }

  static double maxSpeedForRadius(double radius) =>
      baseMaxSpeed *
      math.pow(baseRadius / radius, 0.35).clamp(0.45, 1.0);

  static double boostMaxSpeedForRadius(double radius) =>
      maxSpeedForRadius(radius) * AbilityLoadout.baseBoostSpeedMultiplier;

  Future<void> _reloadAvatar() async {
    final image = await BlackHoleAvatarLoader.load(avatarUrl);
    if (image != null) {
      avatarImage = image;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _reloadAvatar();
    add(SwallowHuntParticleAura());
  }

  double get maxSpeed => maxSpeedForRadius(radius);

  double get effectiveMaxSpeed =>
      maxSpeed * (isBoosting ? abilityLoadout.boostSpeedMultiplier : 1.0);

  @override
  bool isImmuneToGravityFrom(double otherRadius) =>
      isSpawnProtected || (isShieldActive && otherRadius > radius);

  @override
  void recordAbsorb() {
    secondsSinceLastAbsorb = 0;
    isRadiating = false;
  }

  void resetBoostEnergy() {
    boostEnergy = 0;
    _boostActiveRemaining = 0;
    isBoosting = false;
  }

  /// Arms all active abilities on full cooldown (not ready until timers drain).
  void armAbilityCooldowns() {
    teleportCooldownRemaining = abilityLoadout.teleportCooldown;
    abilityShieldCooldownRemaining = abilityLoadout.abilityShieldCooldown;
    shockwaveCooldownRemaining = abilityLoadout.shockwaveCooldown;
  }

  /// Instantly ready — used on revive.
  void resetAbilityCooldowns() {
    teleportCooldownRemaining = 0;
    abilityShieldCooldownRemaining = 0;
    shockwaveCooldownRemaining = 0;
  }

  void tickBoostEnergy(double dt) {
    if (isEliminated) return;

    if (_boostActiveRemaining > 0) {
      _boostActiveRemaining -= dt;
      boostEnergy = (_boostActiveRemaining / abilityLoadout.boostActiveDuration)
          .clamp(0.0, 1.0);
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
      boostEnergy = math.min(
        1.0,
        boostEnergy + dt / abilityLoadout.boostChargeDuration,
      );
    }
  }

  void tickAbilityCooldowns(double dt) {
    if (isEliminated) return;
    if (teleportCooldownRemaining > 0) {
      teleportCooldownRemaining =
          math.max(0.0, teleportCooldownRemaining - dt);
    }
    if (abilityShieldCooldownRemaining > 0) {
      abilityShieldCooldownRemaining =
          math.max(0.0, abilityShieldCooldownRemaining - dt);
    }
    if (shockwaveCooldownRemaining > 0) {
      shockwaveCooldownRemaining =
          math.max(0.0, shockwaveCooldownRemaining - dt);
    }
  }

  bool tryActivateBoost() {
    if (isEliminated || !isBoostReady) return false;
    _boostActiveRemaining = abilityLoadout.boostActiveDuration;
    boostEnergy = 1.0;
    isBoosting = true;
    return true;
  }

  bool beginTeleportCooldown() {
    if (isEliminated || !isTeleportReady) return false;
    teleportCooldownRemaining = abilityLoadout.teleportCooldown;
    return true;
  }

  bool beginAbilityShieldCooldown() {
    if (isEliminated || !isAbilityShieldReady) return false;
    abilityShieldCooldownRemaining = abilityLoadout.abilityShieldCooldown;
    return true;
  }

  bool beginShockwaveCooldown() {
    if (isEliminated || !isShockwaveReady) return false;
    shockwaveCooldownRemaining = abilityLoadout.shockwaveCooldown;
    return true;
  }

  void tickStatus(double dt) {
    secondsSinceLastAbsorb += dt;

    if (avatarImage == null &&
        avatarUrl != null &&
        avatarUrl!.isNotEmpty) {
      _avatarRetryTimer += dt;
      if (_avatarRetryTimer >= 2.0) {
        _avatarRetryTimer = 0;
        unawaited(_reloadAvatar());
      }
    }

    if (isShieldActive) {
      tickShield(dt);
    }
    tickQuasarFlash(dt);

    final game = findGame() as OrbitGame?;
    if (game != null) {
      final pacing = MatchPacing.forRoom(game.roomType);
      final radiationStart = pacing.radiationRadius;
      final idleSeconds = radius >= pacing.lateGameRadiationRadius
          ? pacing.lateGameRadiationIdleSeconds
          : pacing.radiationIdleSeconds;
      if (radius >= radiationStart && secondsSinceLastAbsorb >= idleSeconds) {
        isRadiating = true;
      } else if (radius < radiationStart) {
        isRadiating = false;
      }
    } else if (radius >= 150 && secondsSinceLastAbsorb >= 15) {
      isRadiating = true;
    }

    if (isRadiating) {
      _radiationPulse += dt * 4;
    }
  }

  void applyDrag(Vector2 worldDelta) {
    velocity.addScaled(worldDelta, _acceleration);
    final cap = effectiveMaxSpeed;
    if (velocity.length > cap) {
      velocity.scale(cap / velocity.length);
    }
  }

  void updatePhysics(double dt) {
    if (isEliminated) return;

    position.addScaled(velocity, dt);
    final damping = 1 / (1 + movementFriction * dt);
    velocity.scale(damping);

    diskRotation +=
        dt *
        1.6 *
        math.sqrt(GravityScaling.massFromRadius(radius)).clamp(0.85, 2.35);

    final game = findGame() as OrbitGame?;
    if (game == null) return;

    final beforeX = position.x;
    final beforeY = position.y;
    WorldBounds.clampHoleCenter(
      position,
      radius: radius,
      worldSize: game.worldSize,
    );
    if (position.x != beforeX) velocity.x = 0;
    if (position.y != beforeY) velocity.y = 0;
  }

  void setRadius(double value) {
    final game = findGame() as OrbitGame?;
    final cap = game?.universeVictoryRadius ?? 500.0;
    if (value >= cap) {
      radius = value;
      size = Vector2.all(BlackHoleRenderer.componentBoxSize(radius));
      game?.checkVictoryAfterGrowth();
      return;
    }
    radius = value.clamp(8.0, cap);
    size = Vector2.all(BlackHoleRenderer.componentBoxSize(radius));
  }

  @override
  void growBy(double amount) {
    setRadius(radius + amount);
  }

  @override
  void render(Canvas canvas) {
    if (isEliminated) return;
    super.render(canvas);
    final center = size / 2;

    canvas.save();
    canvas.translate(center.x, center.y);

    final game = findGame() as OrbitGame?;
    final showPortraits = SettingsService.instance.showProfilePictures;

    final swallow = game != null && game.isReady
        ? game.holeSwallowManager.stateFor(position, radius)
        : SwallowEntityState.none;
    HoleSwallowVisual.paintPreyDistortion(
      canvas: canvas,
      gameRadius: radius,
      state: swallow,
    );

    final detail = BlackHoleRenderer.detailForRadius(radius, isLocal: true);
    final influx = game != null && game.isReady
        ? game.spawnManager.influxIntensityAt(position, radius)
        : 0.0;
    BlackHoleRenderer.paint(
      canvas: canvas,
      radius: radius,
      diskRotation: diskRotation,
      skin: activeSkin,
      isBoosting: isBoosting,
      isRadiating: isRadiating,
      radiationPulse: _radiationPulse,
      showShieldRing: isShieldActive || isSpawnProtected,
      shieldPhase: isSpawnProtected
          ? spawnProtectionRemaining
          : shieldTimeRemaining,
      highDetail: detail.highDetail,
      compact: detail.compact,
      isLocal: true,
      gravityIntensity: GravityVisual.holeVisualIntensity(radius),
      swallowCharge: HoleSwallowVisual.photonRingBoost(swallow),
      influxFlux: influx,
      quasarActivation: quasarFlash,
      shaderKey: this,
    );

    HoleSwallowVisual.paintPreyFragmentation(
      canvas: canvas,
      gameRadius: radius,
      state: swallow,
      accent: const Color(0xFFFFAA66),
    );

    if (swallow.isPrey && swallow.predatorRadius > radius) {
      HoleSwallowVisual.paintPreyRing(
        canvas: canvas,
        preyRadius: radius,
        predatorRadius: swallow.predatorRadius,
        distance: swallow.predatorOffset.distance,
        pulse: diskRotation,
      );
    }

    if (BlackHoleNameLabel.shouldShow(isLocal: true) ||
        showPortraits) {
      final game = findGame() as OrbitGame?;
      BlackHoleNameLabel.paint(
        canvas: canvas,
        radius: radius,
        name: BlackHoleNameLabel.shouldShow(isLocal: true) ? displayName : '',
        zoom: game?.camera.viewfinder.zoom ?? 1.0,
        isLocal: true,
        rankPoints: game?.playerRankPoints,
        portrait: showPortraits ? avatarImage : null,
        showPortraitFallback: showPortraits && avatarImage == null,
      );
    }

    final orbit = findGame() as OrbitGame?;
    if (orbit != null) {
      final speech = orbit.speechBubbleTextFor(orbit.playerId);
      if (speech != null && speech.isNotEmpty) {
        BlackHoleNameLabel.paintSpeechBubble(
          canvas: canvas,
          radius: radius,
          text: speech,
          zoom: orbit.camera.viewfinder.zoom,
          isLocal: true,
        );
      }
    }

    canvas.restore();
  }
}
