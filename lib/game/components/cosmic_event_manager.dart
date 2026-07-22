import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../services/haptic_service.dart';
import '../../services/lang_service.dart';
import '../config/match_pacing.dart';
import '../models/cosmic_event_cue.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../utils/canvas_effects.dart';
import '../utils/cosmic_event_planner.dart';
import '../utils/world_positions.dart';
import 'black_hole_partner.dart';
import 'explosion_effect.dart';
import 'meteor.dart';
import 'meteor_dust.dart';
import 'planet.dart';
import 'shockwave_effect.dart';

enum CosmicEventType { none, supernovaWarning, meteorWarning, meteorShower }

/// Schedules and runs room-wide cinematic events: supernova bursts and meteor showers.
///
/// Multiplayer rooms use a server seed + shared match clock so every player
/// sees the same warnings, centers, and detonations.
class CosmicEventManager extends Component with HasGameReference<OrbitGame> {
  static const supernovaWarningDuration = CosmicEventCueDurations.supernovaWarning;
  static const meteorWarningDuration = CosmicEventCueDurations.meteorWarning;
  static const meteorShowerDuration = CosmicEventCueDurations.meteorShower;
  static const meteorLargeRadiusThreshold = 70.0;

  /// Perf budgets — showers used to spawn dust per frame per meteor, piling up
  /// thousands of live components and stalling web/mobile frames.
  static const maxActiveMeteors = 60;
  static const dustTrailInterval = 0.07;
  static const sharedMeteorSlotSeconds = 0.05;

  static int get maxLiveDust => CanvasEffects.mobileLiteMode ? 90 : 180;

  final _rng = math.Random();

  CosmicEventPlanner? _planner;
  int _lastDetonatedSerial = -1;
  int _lastMeteorSlot = -1;
  CosmicEventCue? _activeCue;

  double _supernovaTimer = 0;
  double _meteorCooldown = 12;
  double _warningTimer = 0;
  double _meteorWarningTimer = 0;
  double _meteorShowerTimer = 0;
  double _meteorSpawnTimer = 0;
  double _dustTrailTimer = 0;
  double _flashPulse = 0;

  Vector2? _supernovaCenter;
  CosmicEventType _activeEvent = CosmicEventType.none;

  final List<Planet> _eventPlanets = [];
  final List<Meteor> _meteors = [];
  final List<MeteorDust> _meteorDust = [];

  Vector2? _meteorRegionCenter;
  double _meteorRegionRadius = 900;

  final Map<BlackHolePartner, double> _eventGrowthAbsorbedThisBurst = {};

  int _supernovaCount = 0;
  bool _simpleWelcomeTriggered = false;
  bool _simpleWelcomeActive = false;
  double _simpleWelcomeTimer = 25;
  double _simpleWelcomeDisplayTimer = 0;

  CosmicEventType get activeEvent => _activeEvent;
  Vector2? get supernovaCenter => _supernovaCenter;
  double get flashIntensity => _flashPulse.clamp(0.0, 1.0);

  int get supernovaCountdownSeconds {
    if (_activeEvent != CosmicEventType.supernovaWarning) return 0;
    if (_useSharedSchedule && _activeCue != null) {
      return (_activeCue!.startAt - game.sharedMatchElapsed).ceil().clamp(0, 99);
    }
    return (_warningTimer).ceil().clamp(0, 99);
  }

  int get meteorCountdownSeconds {
    if (_activeEvent != CosmicEventType.meteorWarning) return 0;
    if (_useSharedSchedule && _activeCue != null) {
      return (_activeCue!.startAt - game.sharedMatchElapsed).ceil().clamp(0, 99);
    }
    return (_meteorWarningTimer).ceil().clamp(0, 99);
  }

  /// Countdown for whichever pre-event warning is active (0 = none).
  int get warningCountdownSeconds {
    return switch (_activeEvent) {
      CosmicEventType.supernovaWarning => supernovaCountdownSeconds,
      CosmicEventType.meteorWarning => meteorCountdownSeconds,
      _ => 0,
    };
  }

  bool get isWarningActive =>
      _activeEvent == CosmicEventType.supernovaWarning ||
      _activeEvent == CosmicEventType.meteorWarning;

  /// Only 5s pre-warnings for meteor / supernova. No mid-event or merger banners.
  String? get bannerText {
    switch (_activeEvent) {
      case CosmicEventType.supernovaWarning:
        return LanguageService.instance.supernovaWarning(supernovaCountdownSeconds);
      case CosmicEventType.meteorWarning:
        return LanguageService.instance.meteorWarning(meteorCountdownSeconds);
      case CosmicEventType.meteorShower:
      case CosmicEventType.none:
        if (_simpleWelcomeActive) {
          return LanguageService.instance.t('event_cosmic_dust_welcome');
        }
        return null;
    }
  }

  List<Planet> get eventPlanets => List.unmodifiable(_eventPlanets);
  List<MeteorDust> get meteorDust => List.unmodifiable(_meteorDust);

  MatchPacing get _pacing => MatchPacing.forRoom(game.roomType);

  bool get _useSharedSchedule =>
      _planner != null && game.usesSharedCosmicSchedule;

  /// Bind server seed so all clients share one event timeline.
  void bindSharedSchedule({required int seed, required double worldSize}) {
    _planner = CosmicEventPlanner(
      seed: seed,
      pacing: MatchPacing.forRoom(game.roomType),
      worldSize: worldSize,
    );
    _lastDetonatedSerial = -1;
    _lastMeteorSlot = -1;
    _activeCue = null;
    _skipPastSharedEvents(game.sharedMatchElapsed);
  }

  /// Late joiners must not replay detonations / flood meteors from t=0.
  void _skipPastSharedEvents(double elapsed) {
    final planner = _planner;
    if (planner == null) return;
    for (final cue in planner.cues) {
      if (cue.kind == CosmicEventKind.supernova && cue.startAt <= elapsed) {
        _lastDetonatedSerial = cue.serial;
      }
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final initialCooldown = _pacing.meteorShowerInitialCooldown;
    if (initialCooldown > 0) {
      _meteorCooldown = initialCooldown;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateSimpleWelcomeShower(dt);
    _tickSimpleWelcomeBanner(dt);
    if (!game.roomConfig.cosmicEventsEnabled) {
      _cleanupExpiredDust();
      return;
    }

    if (_useSharedSchedule) {
      _updateSharedSchedule(game.sharedMatchElapsed);
    } else {
      _updateSupernovaSchedule(dt);
      _updateMeteorSchedule(dt);
    }

    _updateFlashPulse(dt);
    _updateMeteorSpawning(dt);
    _updateMeteorCollisions();
    _updateDustTrail(dt);
    _cleanupOffscreenMeteors();
    _cleanupExpiredDust();
  }

  void _updateSharedSchedule(double elapsed) {
    final planner = _planner;
    if (planner == null) return;

    final due = planner.latestSupernovaDue(elapsed);
    if (due != null && due.serial > _lastDetonatedSerial) {
      _applySharedSupernovaDetonation(due);
    }

    final cue = planner.cueAt(elapsed);
    if (cue == null) {
      if (_activeEvent == CosmicEventType.meteorShower) {
        _endMeteorShower();
      } else if (_activeEvent != CosmicEventType.none) {
        _activeEvent = CosmicEventType.none;
        _activeCue = null;
      }
      return;
    }

    if (_activeCue?.serial != cue.serial) {
      _activeCue = cue;
      if (cue.kind == CosmicEventKind.meteorShower) {
        _meteorRegionCenter = cue.center.clone();
        _meteorRegionRadius = cue.regionRadius;
        if (cue.isRunningAt(elapsed)) {
          // Mid-shower join: only spawn from the current time slot onward.
          _lastMeteorSlot =
              ((elapsed - cue.startAt) / sharedMeteorSlotSeconds).floor() - 1;
        } else {
          _lastMeteorSlot = -1;
        }
      } else {
        _supernovaCenter = cue.center.clone();
      }
      HapticService.instance.heavyImpact();
    }

    if (cue.kind == CosmicEventKind.supernova) {
      if (cue.isWarningAt(elapsed)) {
        _activeEvent = CosmicEventType.supernovaWarning;
        _supernovaCenter = cue.center.clone();
        final remaining = cue.startAt - elapsed;
        _flashPulse = 0.35 + math.sin(remaining * 12) * 0.25;
      }
      return;
    }

    // Meteor shower cue
    _meteorRegionCenter = cue.center.clone();
    _meteorRegionRadius = cue.regionRadius;
    if (cue.isWarningAt(elapsed)) {
      if (_activeEvent != CosmicEventType.meteorWarning) {
        _activeEvent = CosmicEventType.meteorWarning;
        _flashPulse = 0.6;
      }
      final remaining = cue.startAt - elapsed;
      _flashPulse = 0.22 + math.sin(remaining * 10) * 0.16;
      return;
    }

    if (cue.isRunningAt(elapsed)) {
      if (_activeEvent != CosmicEventType.meteorShower) {
        _activeEvent = CosmicEventType.meteorShower;
        _meteorShowerTimer = cue.endAt - elapsed;
        HapticService.instance.lightImpact();
      }
      _spawnSharedMeteors(elapsed, cue);
    }
  }

  void _applySharedSupernovaDetonation(CosmicEventCue cue) {
    _lastDetonatedSerial = cue.serial;
    _supernovaCenter = cue.center.clone();
    _activeEvent = CosmicEventType.none;
    _supernovaCount++;
    _flashPulse = 1.2;
    _eventGrowthAbsorbedThisBurst.clear();
    final center = cue.center.clone();

    game.triggerScreenShake();
    HapticService.instance.heavyImpact();

    game.world.add(
      ExplosionEffect(
        position: center.clone(),
        maxRadius: 280,
        duration: 0.9,
      ),
    );

    game.world.add(
      ShockwaveEffect(
        position: center.clone(),
        maxRadius: game.worldSize * 0.4,
        duration: 1.6,
        onRadiusReached: (radius) => _applySupernovaShockDamage(center, radius),
      ),
    );

    _launchSupernovaPlanets(center, math.Random(cue.spawnSeed));
  }

  void _spawnSharedMeteors(double elapsed, CosmicEventCue cue) {
    final center = cue.center;
    final showerElapsed = elapsed - cue.startAt;
    if (showerElapsed < 0) return;

    final targetSlot = (showerElapsed / sharedMeteorSlotSeconds).floor();
    while (_lastMeteorSlot < targetSlot && _meteors.length < maxActiveMeteors) {
      _lastMeteorSlot++;
      final slotRng = math.Random(cue.spawnSeed ^ (_lastMeteorSlot * 2654435761));
      final spawnX =
          center.x + (slotRng.nextDouble() - 0.5) * cue.regionRadius * 2;
      final spawnY = center.y - cue.regionRadius * 0.85;
      final fallAngle = math.pi / 2 + (slotRng.nextDouble() - 0.5) * 0.35;
      final speed = 520 + slotRng.nextDouble() * 280;

      final meteor = Meteor(
        position: Vector2(spawnX, spawnY),
        velocity: Vector2(math.cos(fallAngle), math.sin(fallAngle)) * speed,
        collisionRadius: 8 + slotRng.nextDouble() * 6,
      );
      game.world.add(meteor);
      _meteors.add(meteor);
    }
  }

  void _updateSimpleWelcomeShower(double dt) {
    if (game.roomType != RoomType.simple || _simpleWelcomeTriggered) return;

    _simpleWelcomeTimer -= dt;
    if (_simpleWelcomeTimer > 0) return;

    _simpleWelcomeTriggered = true;
    _simpleWelcomeActive = true;
    _simpleWelcomeDisplayTimer = 6;
    _spawnSimpleWelcomeDust(game.player.position);
    HapticService.instance.lightImpact();
  }

  void _spawnSimpleWelcomeDust(Vector2 center) {
    for (var i = 0; i < 18; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final offset = Vector2(math.cos(angle), math.sin(angle)) *
          (40 + _rng.nextDouble() * 260);
      final dust = MeteorDust(
        position: center + offset,
        growthValue: 1.2 + _rng.nextDouble() * 2.4,
      );
      game.world.add(dust);
      _meteorDust.add(dust);
    }
  }

  void _tickSimpleWelcomeBanner(double dt) {
    if (!_simpleWelcomeActive) return;
    _simpleWelcomeDisplayTimer -= dt;
    if (_simpleWelcomeDisplayTimer <= 0) {
      _simpleWelcomeActive = false;
    }
  }

  void _updateSupernovaSchedule(double dt) {
    if (_activeEvent == CosmicEventType.supernovaWarning) {
      _warningTimer -= dt;
      _flashPulse = 0.35 + math.sin(_warningTimer * 12) * 0.25;
      if (_warningTimer <= 0) {
        _detonateSupernova();
      }
      return;
    }

    if (_activeEvent != CosmicEventType.none) return;

    final interval = _pacing.supernovaIntervalSeconds;
    if (interval <= 0) return;

    _supernovaTimer += dt;
    final threshold = _supernovaCount == 0
        ? (_pacing.supernovaFirstDelaySeconds > 0
            ? _pacing.supernovaFirstDelaySeconds
            : interval)
        : interval;
    if (_supernovaTimer >= threshold) {
      _beginSupernovaWarning();
    }
  }

  void _updateMeteorSchedule(double dt) {
    if (_activeEvent == CosmicEventType.meteorShower) {
      _meteorShowerTimer -= dt;
      if (_meteorShowerTimer <= 0) {
        _endMeteorShower();
      }
      return;
    }

    if (_activeEvent == CosmicEventType.meteorWarning) {
      _meteorWarningTimer -= dt;
      _flashPulse = 0.22 + math.sin(_meteorWarningTimer * 10) * 0.16;
      if (_meteorWarningTimer <= 0) {
        _startMeteorShower();
      }
      return;
    }

    if (_activeEvent == CosmicEventType.supernovaWarning) return;

    _meteorCooldown -= dt;
    if (_meteorCooldown <= 0) {
      _beginMeteorWarning();
    }
  }

  void _beginSupernovaWarning() {
    _supernovaTimer = 0;
    _activeEvent = CosmicEventType.supernovaWarning;
    _warningTimer = supernovaWarningDuration;
    final isEarlySupernova =
        _supernovaCount == 0 || game.matchElapsed < 120;
    _supernovaCenter = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 400,
      avoid: isEarlySupernova ? const [] : [game.player.position],
      minSeparation: isEarlySupernova ? 220 : 500,
    );
    _flashPulse = 1;
    HapticService.instance.heavyImpact();
  }

  void _detonateSupernova() {
    _activeEvent = CosmicEventType.none;
    _supernovaCount++;
    _flashPulse = 1.2;
    _eventGrowthAbsorbedThisBurst.clear();
    final center = _supernovaCenter ?? game.player.position.clone();

    game.triggerScreenShake();
    HapticService.instance.heavyImpact();

    game.world.add(
      ExplosionEffect(
        position: center.clone(),
        maxRadius: 280,
        duration: 0.9,
      ),
    );

    game.world.add(
      ShockwaveEffect(
        position: center.clone(),
        maxRadius: game.worldSize * 0.4,
        duration: 1.6,
        onRadiusReached: (radius) => _applySupernovaShockDamage(center, radius),
      ),
    );

    _launchSupernovaPlanets(center, _rng);
  }

  void _applySupernovaShockDamage(Vector2 center, double shockRadius) {
    _damageBlackHoleAtCenter(game.player, center, shockRadius);
    for (final bot in game.botPopulation.bots) {
      _damageBlackHoleAtCenter(bot, center, shockRadius);
    }
  }

  void _damageBlackHoleAtCenter(
    BlackHolePartner hole,
    Vector2 center,
    double shockRadius,
  ) {
    if (hole.isSpawnProtected) return;

    final distance = hole.position.distanceTo(center);
    if (distance > shockRadius + hole.holeRadius) return;

    final proximity = 1 - (distance / (shockRadius + hole.holeRadius)).clamp(0.0, 1.0);
    if (proximity < 0.15) return;

    final loss = hole.holeRadius * (0.10 + proximity * 0.26);
    hole.growBy(-loss);
  }

  void _launchSupernovaPlanets(Vector2 center, math.Random rng) {
    final planetCount = _pacing.supernovaPlanetCount;
    for (var i = 0; i < planetCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 200 + rng.nextDouble() * 320;
      final collisionRadius = 20 + rng.nextDouble() * 12;
      // Between meteorite (3) and elite planet (4) — burst total ~140–250 on map.
      final growthValue = 4 + rng.nextDouble() * 5;
      final spawnOffset = Vector2(
        math.cos(angle) * (18 + rng.nextDouble() * 55),
        math.sin(angle) * (18 + rng.nextDouble() * 55),
      );

      final planet = Planet(
        position: center + spawnOffset,
        colorIndex: i,
        collisionRadius: collisionRadius,
        growthValue: growthValue,
        velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
        isEventReward: true,
      );

      game.world.add(planet);
      _eventPlanets.add(planet);
    }
  }

  /// 5 saniyelik ön uyarı — yağmur bölgesi burada seçilir ki oyuncu hazırlanabilsin.
  void _beginMeteorWarning() {
    _activeEvent = CosmicEventType.meteorWarning;
    _meteorWarningTimer = meteorWarningDuration;
    _meteorRegionCenter = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 300,
      avoid: [game.player.position],
      minSeparation: 200,
    );
    _meteorRegionRadius = 700 + _rng.nextDouble() * 500;
    _flashPulse = 0.6;
    HapticService.instance.heavyImpact();
  }

  void _startMeteorShower() {
    _activeEvent = CosmicEventType.meteorShower;
    _meteorShowerTimer = meteorShowerDuration;
    _meteorSpawnTimer = 0;
    _meteorCooldown = meteorShowerDuration + 25 + _rng.nextDouble() * 20;
    HapticService.instance.lightImpact();
  }

  void _endMeteorShower() {
    _activeEvent = CosmicEventType.none;
    _activeCue = null;
    for (final meteor in List<Meteor>.from(_meteors)) {
      meteor.deactivate();
    }
    _meteors.clear();
  }

  void _updateMeteorSpawning(double dt) {
    if (_useSharedSchedule) return;
    if (_activeEvent != CosmicEventType.meteorShower) return;
    final center = _meteorRegionCenter;
    if (center == null) return;

    _meteorSpawnTimer -= dt;
    if (_meteorSpawnTimer > 0) return;
    _meteorSpawnTimer = 0.04 + _rng.nextDouble() * 0.06;

    if (_meteors.length >= maxActiveMeteors) return;

    final spawnX = center.x + (_rng.nextDouble() - 0.5) * _meteorRegionRadius * 2;
    final spawnY = center.y - _meteorRegionRadius * 0.85;
    final fallAngle = math.pi / 2 + (_rng.nextDouble() - 0.5) * 0.35;
    final speed = 520 + _rng.nextDouble() * 280;

    final meteor = Meteor(
      position: Vector2(spawnX, spawnY),
      velocity: Vector2(math.cos(fallAngle), math.sin(fallAngle)) * speed,
      collisionRadius: 8 + _rng.nextDouble() * 6,
    );

    game.world.add(meteor);
    _meteors.add(meteor);
  }

  void _updateMeteorCollisions() {
    for (final meteor in List<Meteor>.from(_meteors)) {
      if (!meteor.active) continue;

      _checkMeteorVsBlackHole(meteor, game.player);
      for (final bot in game.botPopulation.bots) {
        _checkMeteorVsBlackHole(meteor, bot);
      }
    }
  }

  /// Time-based trail budget: one dust per [dustTrailInterval] from a random
  /// meteor, capped globally — instead of a 35% roll per meteor per frame.
  void _updateDustTrail(double dt) {
    if (_meteors.isEmpty) return;

    _dustTrailTimer -= dt;
    if (_dustTrailTimer > 0) return;
    _dustTrailTimer = dustTrailInterval;

    if (_meteorDust.length >= maxLiveDust) return;

    final meteor = _meteors[_rng.nextInt(_meteors.length)];
    if (!meteor.active) return;

    final dust = MeteorDust(
      position: meteor.position.clone()
        ..add(Vector2(
          (_rng.nextDouble() - 0.5) * 20,
          (_rng.nextDouble() - 0.5) * 20,
        )),
      growthValue: 0.6 + _rng.nextDouble() * 1.2,
    );
    game.world.add(dust);
    _meteorDust.add(dust);
  }

  void _checkMeteorVsBlackHole(Meteor meteor, BlackHolePartner hole) {
    if (!meteor.active) return;
    if (hole.isSpawnProtected) return;

    final distance = meteor.position.distanceTo(hole.position);
    if (distance > hole.holeRadius + meteor.collisionRadius) return;

    if (hole.holeRadius >= meteorLargeRadiusThreshold) {
      final damage = hole.holeRadius * 0.06 + 3;
      hole.growBy(-damage);
      HapticService.instance.heavyImpact();
    }

    _spawnMeteorImpactDust(meteor.position);
    meteor.deactivate();
    _meteors.remove(meteor);

    game.world.add(
      ExplosionEffect(
        position: meteor.position.clone(),
        maxRadius: meteor.collisionRadius * 3,
        duration: 0.35,
      ),
    );
  }

  void _spawnMeteorImpactDust(Vector2 position) {
    for (var i = 0; i < 3 + _rng.nextInt(3); i++) {
      if (_meteorDust.length >= maxLiveDust) return;
      final angle = _rng.nextDouble() * math.pi * 2;
      final offset = Vector2(math.cos(angle), math.sin(angle)) * (12 + _rng.nextDouble() * 30);
      final dust = MeteorDust(
        position: position + offset,
        growthValue: 1 + _rng.nextDouble() * 2,
      );
      game.world.add(dust);
      _meteorDust.add(dust);
    }
  }

  void _cleanupOffscreenMeteors() {
    final bound = game.worldSize + 200;
    for (final meteor in List<Meteor>.from(_meteors)) {
      if (!meteor.active) {
        _meteors.remove(meteor);
        continue;
      }
      if (meteor.position.x < -200 ||
          meteor.position.y < -200 ||
          meteor.position.x > bound ||
          meteor.position.y > bound) {
        meteor.deactivate();
        _meteors.remove(meteor);
      }
    }
  }

  void _cleanupExpiredDust() {
    _meteorDust.removeWhere((dust) => !dust.active || !dust.isMounted);
  }

  void _updateFlashPulse(double dt) {
    if (_flashPulse <= 0) return;
    _flashPulse = math.max(0, _flashPulse - dt * 1.8);
  }

  void absorbEventPlanet(Planet planet) {
    absorbEventPlanetFor(planet, game.player);
  }

  void absorbEventPlanetFor(Planet planet, BlackHolePartner consumer) {
    if (!planet.active || !_eventPlanets.contains(planet)) return;
    final growth = _grantEventGrowth(consumer, planet.growthValue);
    planet.deactivate();
    _eventPlanets.remove(planet);
    if (growth <= 0) return;

    if (consumer == game.player) {
      game.spawnManager.distributeGrowth(growth);
    } else {
      final paced = growth *
          game.roomConfig.foodGrowthMultiplier *
          _pacing.lateGrowthMultiplier(consumer.holeRadius);
      consumer.growBy(paced);
      consumer.recordAbsorb();
    }
    HapticService.instance.lightImpact();
  }

  /// Soft cap so one hole cannot snowball from 80 → 500 in a single burst.
  double _grantEventGrowth(BlackHolePartner consumer, double requested) {
    final cap = _pacing.eventGrowthCapPerBurst;
    if (cap <= 0) return 0;

    final absorbed = _eventGrowthAbsorbedThisBurst[consumer] ?? 0;
    final remaining = cap - absorbed;
    if (remaining <= 0) return 0;

    final granted = math.min(requested, remaining);
    _eventGrowthAbsorbedThisBurst[consumer] = absorbed + granted;
    return granted;
  }

  void absorbMeteorDust(MeteorDust dust) {
    absorbMeteorDustFor(dust, game.player);
  }

  void absorbMeteorDustFor(MeteorDust dust, BlackHolePartner consumer) {
    if (!dust.active || !_meteorDust.contains(dust)) return;
    dust.deactivate();
    _meteorDust.remove(dust);
    if (consumer == game.player) {
      game.spawnManager.distributeGrowth(dust.growthValue);
    } else {
      final paced = dust.growthValue *
          game.roomConfig.foodGrowthMultiplier *
          _pacing.lateGrowthMultiplier(consumer.holeRadius);
      consumer.growBy(paced);
      consumer.recordAbsorb();
    }
    HapticService.instance.lightImpact();
  }
}
