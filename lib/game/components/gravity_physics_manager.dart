import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../services/haptic_service.dart';
import '../orbit_game.dart';
import '../utils/canvas_effects.dart';
import '../utils/gravity_scaling.dart';
import '../utils/viewport_cull.dart';
import '../utils/world_bounds.dart';
import 'binary_merger_effect.dart';
import 'black_hole_partner.dart';
import 'bot_player.dart';
import 'enemy_player.dart';
import 'explosion_effect.dart';
import 'gravitational_wave_ripple_effect.dart';
import 'hole_swallow_burst_effect.dart';
import 'player.dart';

/// Black-hole gravity plus the staged binary-merger sequence.
///
/// Every hole-vs-hole encounter follows the four stages of the reference
/// infographic — the old instant-swallow and boost-contest events are gone:
///
/// 1. **Gravitational Inspiral** — the pair orbits the shared barycenter and
///    slowly draws closer (escapable).
/// 2. **Tidal Deformation & Mass Transfer** — a binary accretion bridge forms
///    and mass flows from the smaller hole to the larger (still escapable).
/// 3. **The Dance & Massive Gravitational Waves** — point of no return: both
///    holes spiral around the barycenter while spacetime ripples radiate.
/// 4. **Merger & Ringdown** — event horizons merge into a single hole; final
///    gravitational-wave burst, relativistic jets, combined quasar activated.
///
/// The simulation never pauses — the rest of the arena keeps playing.
class GravityPhysicsManager extends Component with HasGameReference<OrbitGame> {
  /// Stage onsets in multiples of the combined radius (rA + rB).
  static const inspiralOnsetRadii = 4.5;
  static const tidalOnsetRadii = 2.6;
  static const danceOnsetRadii = 1.4;

  /// Escaping a stage requires drifting this factor past its onset.
  static const stageEscapeHysteresis = 1.25;

  static const ringdownBannerDuration = 3.0;

  final List<_MergerPairState> _pairs = [];
  double _ringdownTimer = 0;

  /// True while the local player is locked in the dance or just merged.
  bool get isMergerActive =>
      _ringdownTimer > 0 ||
      _pairs.any((p) =>
          p.stage == _MergerStage.dance && p.involves(game.player));

  String? get mergerBannerKey {
    if (_ringdownTimer > 0) return 'merge_stage_ringdown';
    _MergerPairState? local;
    for (final pair in _pairs) {
      if (!pair.involves(game.player)) continue;
      if (local == null || pair.stage.index > local.stage.index) local = pair;
    }
    return switch (local?.stage) {
      _MergerStage.dance => 'merge_stage_dance',
      _MergerStage.tidal => 'merge_stage_tidal',
      _ => null,
    };
  }

  /// During the dance both partners lose steering — point of no return.
  bool isInspiralLocked(BlackHolePartner hole) => _pairs.any(
        (p) => p.stage == _MergerStage.dance && p.involves(hole),
      );

  bool isInInspiral(BlackHolePartner hole) =>
      _pairs.any((p) => p.involves(hole));

  @override
  void update(double dt) {
    super.update(dt);
    if (_ringdownTimer > 0) {
      _ringdownTimer = math.max(0, _ringdownTimer - dt);
    }
    _applyGravity(_activeHoles(), dt);
  }

  /// Merger-sequence pass — runs after player/bot movement so the staged
  /// motion is not undone by steering integration.
  void tickInspirals(double dt) {
    final holes = _activeHoles();
    final byPartner = <BlackHolePartner, _HoleRef>{
      for (final hole in holes) hole.partner: hole,
    };

    _validatePairs(byPartner, dt);
    _formNewPairs(holes, byPartner);
    _syncPairVisuals(byPartner);
  }

  List<_HoleRef> _activeHoles() {
    final holes = <_HoleRef>[];
    if (!game.player.isEliminated) {
      holes.add(_HoleRef(game.player, game.player));
    }
    for (final bot in game.botPopulation.bots) {
      if (!bot.isEliminated) {
        holes.add(_HoleRef(bot, bot));
      }
    }
    for (final enemy in game.enemyPlayers) {
      if (!enemy.isEliminated) {
        holes.add(_HoleRef(enemy, enemy));
      }
    }
    return holes;
  }

  // ---------------------------------------------------------------------
  // Mutual Newtonian gravity (unchanged physics; M ∝ r³).
  // ---------------------------------------------------------------------

  void _applyGravity(List<_HoleRef> holes, double dt) {
    for (var i = 0; i < holes.length; i++) {
      for (var j = i + 1; j < holes.length; j++) {
        _applyPairGravity(holes[i], holes[j], dt);
      }
    }
  }

  void _applyPairGravity(_HoleRef a, _HoleRef b, double dt) {
    final distance = a.position.distanceTo(b.position);
    if (distance < 1) return;

    void pull(_HoleRef target, _HoleRef source) {
      final influence = GravityScaling.holeToHolePullInfluenceRadius(
        sourceRadius: source.radius,
        targetRadius: target.radius,
      );
      if (distance > influence) return;
      if (target.partner.isImmuneToGravityFrom(source.radius)) return;
      if (isInspiralLocked(target.partner)) return;

      final pull = GravityScaling.displacement(
        sourceRadius: source.radius,
        distance: distance,
        dt: dt,
        bonusMultiplier: GravityScaling.holeToHolePullMultiplier,
      );
      if (pull <= 0) return;

      final dir = (source.position - target.position).normalized();
      target.velocity.addScaled(dir, pull);
    }

    pull(a, b);
    pull(b, a);
  }

  // ---------------------------------------------------------------------
  // Pair lifecycle.
  // ---------------------------------------------------------------------

  bool _canMergePair(BlackHolePartner a, BlackHolePartner b) {
    if (a.isSpawnProtected || b.isSpawnProtected) return false;
    if (a.isImmuneToGravityFrom(b.holeRadius)) return false;
    if (b.isImmuneToGravityFrom(a.holeRadius)) return false;
    // Multiplayer: remotes only merge with local player — except host-side
    // bot↔enemy / bot↔bot so shared bots stay authoritative on one client.
    if (a is BotPlayer && b is BotPlayer) return game.isBotHost;
    final botEnemyPair = (a is EnemyPlayer && b is BotPlayer) ||
        (b is EnemyPlayer && a is BotPlayer);
    if (botEnemyPair) return game.isBotHost;
    if (a is EnemyPlayer && b is! Player) return false;
    if (b is EnemyPlayer && a is! Player) return false;
    return true;
  }

  /// Event-horizon contact: photon-ring shell of the larger hole plus a
  /// fraction of the smaller hole's horizon (works for equal sizes too).
  double _captureDistance(double radiusA, double radiusB) {
    final rMax = math.max(radiusA, radiusB);
    final rMin = math.min(radiusA, radiusB);
    const shadow =
        GravityScaling.schwarzschildFraction * GravityScaling.shadowBoundaryRatio;
    return rMax * shadow + rMin * GravityScaling.schwarzschildFraction * 0.42;
  }

  void _validatePairs(Map<BlackHolePartner, _HoleRef> byPartner, double dt) {
    for (final pair in _pairs.toList()) {
      final refA = byPartner[pair.a];
      final refB = byPartner[pair.b];
      if (refA == null || refB == null || !_canMergePair(pair.a, pair.b)) {
        _dropPair(pair);
        continue;
      }

      final distance = refA.position.distanceTo(refB.position);
      final combined = refA.radius + refB.radius;

      // Escape checks — only stages 1 and 2 can be broken out of.
      if (pair.stage == _MergerStage.inspiral &&
          distance > combined * inspiralOnsetRadii * stageEscapeHysteresis) {
        _dropPair(pair);
        continue;
      }
      if (pair.stage == _MergerStage.tidal &&
          distance > combined * tidalOnsetRadii * stageEscapeHysteresis) {
        pair.enterStage(_MergerStage.inspiral);
      }

      // Stage advancement.
      if (pair.stage == _MergerStage.inspiral &&
          distance <= combined * tidalOnsetRadii) {
        pair.enterStage(_MergerStage.tidal);
        if (pair.involves(game.player)) {
          HapticService.instance.lightImpact();
        }
      }
      if (pair.stage == _MergerStage.tidal &&
          distance <= combined * danceOnsetRadii) {
        pair.enterStage(_MergerStage.dance);
        if (pair.involves(game.player)) {
          HapticService.instance.mergerVibration();
        }
      }

      pair.stageTime += dt;

      switch (pair.stage) {
        case _MergerStage.inspiral:
          _tickInspiralStage(pair, refA, refB, distance, dt);
        case _MergerStage.tidal:
          _tickTidalStage(pair, refA, refB, distance, dt);
        case _MergerStage.dance:
          if (_tickDanceStage(pair, refA, refB, distance, dt)) {
            continue; // Pair merged and was removed.
          }
      }
    }
  }

  void _formNewPairs(
    List<_HoleRef> holes,
    Map<BlackHolePartner, _HoleRef> byPartner,
  ) {
    final busy = <BlackHolePartner>{};
    for (final pair in _pairs) {
      busy.add(pair.a);
      busy.add(pair.b);
    }

    final candidates =
        <({_HoleRef a, _HoleRef b, double distance})>[];
    for (var i = 0; i < holes.length; i++) {
      for (var j = i + 1; j < holes.length; j++) {
        final a = holes[i];
        final b = holes[j];
        if (busy.contains(a.partner) || busy.contains(b.partner)) continue;
        if (!_canMergePair(a.partner, b.partner)) continue;

        final distance = a.position.distanceTo(b.position);
        if (distance > (a.radius + b.radius) * inspiralOnsetRadii) continue;
        candidates.add((a: a, b: b, distance: distance));
      }
    }

    candidates.sort((x, y) => x.distance.compareTo(y.distance));
    for (final c in candidates) {
      if (busy.contains(c.a.partner) || busy.contains(c.b.partner)) continue;
      busy.add(c.a.partner);
      busy.add(c.b.partner);
      _pairs.add(_MergerPairState(a: c.a.partner, b: c.b.partner));
    }
  }

  void _dropPair(_MergerPairState pair) {
    pair.effect?.removeFromParent();
    pair.effect = null;
    _pairs.remove(pair);
  }

  // ---------------------------------------------------------------------
  // Stage 1 — Gravitational Inspiral (the approach).
  // ---------------------------------------------------------------------

  void _tickInspiralStage(
    _MergerPairState pair,
    _HoleRef refA,
    _HoleRef refB,
    double distance,
    double dt,
  ) {
    if (distance < 1) return;
    final combined = refA.radius + refB.radius;
    final t = (1 - distance / (combined * inspiralOnsetRadii)).clamp(0.0, 1.0);

    // Gentle tangential swirl so the pair visibly orbits while approaching.
    _applyBarycentricSwirl(refA, refB, distance, swirl: 26 * t * dt, radial: 0);
  }

  // ---------------------------------------------------------------------
  // Stage 2 — Tidal Deformation & Mass Transfer.
  // ---------------------------------------------------------------------

  void _tickTidalStage(
    _MergerPairState pair,
    _HoleRef refA,
    _HoleRef refB,
    double distance,
    double dt,
  ) {
    if (distance < 1) return;
    final combined = refA.radius + refB.radius;
    final span = combined * (tidalOnsetRadii - danceOnsetRadii);
    final t = span <= 0
        ? 1.0
        : (1 - (distance - combined * danceOnsetRadii) / span).clamp(0.0, 1.0);

    // Escapable radial assist + stronger swirl (quadratic ramp like the old
    // unlocked inspiral, so boosting away still works).
    _applyBarycentricSwirl(
      refA,
      refB,
      distance,
      swirl: (40 + 55 * t) * dt,
      radial: 90 * t * t * dt,
    );

    _transferMass(refA, refB, rate: 0.045 * (0.4 + t * 0.6), dt: dt);
  }

  // ---------------------------------------------------------------------
  // Stage 3 — The Dance & massive gravitational waves. Returns true when the
  // pair merged (Stage 4) and was removed.
  // ---------------------------------------------------------------------

  bool _tickDanceStage(
    _MergerPairState pair,
    _HoleRef refA,
    _HoleRef refB,
    double distance,
    double dt,
  ) {
    final capture = _captureDistance(refA.radius, refB.radius);
    if (distance <= capture) {
      _resolveMerger(pair, refA, refB);
      return true;
    }

    final combined = refA.radius + refB.radius;
    final massA = GravityScaling.massFromRadius(refA.radius);
    final massB = GravityScaling.massFromRadius(refB.radius);
    final total = massA + massB;
    final barycenter =
        (refA.position * massA + refB.position * massB) / total;

    // Kepler-flavoured tightening: angular speed and infall both grow as the
    // dance progresses and the separation shrinks.
    final omega = 2.2 + pair.stageTime * 2.0;
    final closeSpeed =
        math.max(combined * (0.42 + pair.stageTime * 0.45), 60.0);
    final newDistance = math.max(capture * 0.94, distance - closeSpeed * dt);

    void place(_HoleRef ref) {
      final offset = ref.position - barycenter;
      final len = offset.length;
      if (len < 0.01) return;

      final angle = math.atan2(offset.y, offset.x) + omega * dt;
      final newLen = len * (newDistance / distance);
      final next = barycenter +
          Vector2(math.cos(angle), math.sin(angle)) * newLen;

      // Tangential velocity for renderers / network sync.
      ref.velocity.setFrom((next - ref.position) / math.max(dt, 1e-4));
      ref.component.position.setFrom(next);
      WorldBounds.clampHoleCenter(
        ref.component.position,
        radius: ref.radius,
        worldSize: game.worldSize,
      );
    }

    place(refA);
    place(refB);

    _transferMass(refA, refB, rate: 0.10, dt: dt);

    // Ripples in spacetime — kept tight around the pair so the arena
    // doesn't flood with rings (short reach, sparse emission).
    pair.rippleTimer -= dt;
    if (pair.rippleTimer <= 0) {
      pair.rippleTimer = 0.6;
      if (!_pairOffScreen(refA, refB)) {
        game.world.add(
          GravitationalWaveRippleEffect(
            position: barycenter.clone(),
            maxRadius: combined * 1.7,
            duration: 0.9,
            ringCount: 2,
            intensity: (0.4 + pair.stageTime * 0.2).clamp(0.0, 0.8),
          ),
        );
      }
    }

    if (pair.involves(game.player)) {
      game.triggerExtendedScreenShake(
        duration: 0.25,
        intensity: 6 + math.min(pair.stageTime * 6, 14),
      );
    }

    return false;
  }

  // ---------------------------------------------------------------------
  // Stage 4 — Merger & Ringdown (one quasar).
  // ---------------------------------------------------------------------

  void _resolveMerger(_MergerPairState pair, _HoleRef refA, _HoleRef refB) {
    final winner = refA.radius >= refB.radius ? refA : refB;
    final loser = winner == refA ? refB : refA;
    final mid = (winner.position + loser.position) / 2;
    final onScreen = !_pairOffScreen(refA, refB);
    final involvesLocal = pair.involves(game.player);

    final absorbedMass = loser.radius * 0.55;
    winner.partner.growBy(absorbedMass);
    winner.partner.recordAbsorb();

    _spawnSwallowBurst(winner, loser);

    // Final gravitational-wave burst — stays near the remnant instead of
    // sweeping the whole map (less clutter, easier on the eyes).
    final viewportHalf = ViewportCull.viewportHalfExtent(game);
    final burstRadius = CanvasEffects.capMergerShockwaveRadius(
      requested: math.min(
        (winner.radius + loser.radius) * 3.8,
        viewportHalf * 0.9,
      ),
      viewportHalfExtent: viewportHalf,
    );
    game.world.add(
      GravitationalWaveRippleEffect(
        position: mid.clone(),
        maxRadius: burstRadius,
        duration: 1.4,
        ringCount: 2,
        intensity: 1.0,
      ),
    );
    game.world.add(
      ExplosionEffect(
        position: mid.clone(),
        maxRadius: math.max(winner.radius, loser.radius) * 3.0,
        duration: 0.9,
      ),
    );

    // Combined quasar activated — relativistic jets fire from the remnant.
    game.triggerQuasarActivation(winner.partner, absorbedMass);

    if (involvesLocal || onScreen) {
      HapticService.instance.heavyImpact();
      game.triggerExtendedScreenShake(duration: 1.2, intensity: 30);
      _ringdownTimer = ringdownBannerDuration;
    }

    final winnerIsLocalPlayer = winner.component is Player;
    final winnerIsHostBot =
        winner.component is BotPlayer && game.isBotHost;
    if (winnerIsLocalPlayer || winnerIsHostBot) {
      final predatorId = winnerIsLocalPlayer
          ? game.playerId
          : (winner.component as BotPlayer).networkId;
      final preyId = switch (loser.component) {
        Player _ => game.playerId,
        EnemyPlayer e => e.networkId,
        BotPlayer b => b.networkId,
        _ => '',
      };
      game.announceAbsorbVictory(
        predatorId: predatorId,
        predatorName: winner.partner.displayName,
        preyId: preyId,
        preyName: loser.partner.displayName,
      );
    }

    if (loser.component is Player) {
      final player = loser.component as Player;
      final radiusAtDeath = player.radius;
      player.isEliminated = true;
      player.velocity.setZero();
      game.botPopulation.onRealPlayerEliminated();
      game.onLocalPlayerEliminated(radiusAtDeath);
      HapticService.instance.heavyImpact();
    } else if (loser.component is BotPlayer) {
      game.botPopulation.removeBot(loser.component as BotPlayer);
    } else if (loser.component is EnemyPlayer) {
      // Always despawn; lagging poses are ignored via absorbed-id tombstone.
      game.onRemotePlayerEliminated(loser.component as EnemyPlayer);
    }

    _dropPair(pair);
  }

  // ---------------------------------------------------------------------
  // Shared helpers.
  // ---------------------------------------------------------------------

  /// Adds tangential (swirl) and inward (radial) velocity around the pair's
  /// barycenter — lighter holes are deflected more (momentum conservation).
  void _applyBarycentricSwirl(
    _HoleRef refA,
    _HoleRef refB,
    double distance, {
    required double swirl,
    required double radial,
  }) {
    final massA = GravityScaling.massFromRadius(refA.radius);
    final massB = GravityScaling.massFromRadius(refB.radius);
    final total = massA + massB;
    final dir = (refB.position - refA.position) / distance;
    final tangent = Vector2(-dir.y, dir.x);

    // Each hole's response scales with the companion's mass share.
    final shareA = massB / total;
    final shareB = massA / total;

    refA.velocity.addScaled(tangent, swirl * shareA * 2);
    refB.velocity.addScaled(tangent, -swirl * shareB * 2);
    if (radial > 0) {
      refA.velocity.addScaled(dir, radial * shareA * 2);
      refB.velocity.addScaled(dir, -radial * shareB * 2);
    }
  }

  /// Continuous mass transfer from the smaller hole to the larger one
  /// (65% efficiency, matching the swallow reward of the final merge).
  void _transferMass(
    _HoleRef refA,
    _HoleRef refB, {
    required double rate,
    required double dt,
  }) {
    final larger = refA.radius >= refB.radius ? refA : refB;
    final smaller = larger == refA ? refB : refA;
    if (smaller.radius <= 12) return;

    final drained = math.min(smaller.radius * rate * dt, smaller.radius - 12);
    if (drained <= 0) return;
    smaller.partner.growBy(-drained);
    larger.partner.growBy(drained * 0.55);
  }

  bool _pairOffScreen(_HoleRef refA, _HoleRef refB) =>
      ViewportCull.isOffScreen(game, refA.position, refA.radius * 3) &&
      ViewportCull.isOffScreen(game, refB.position, refB.radius * 3);

  void _syncPairVisuals(Map<BlackHolePartner, _HoleRef> byPartner) {
    for (final pair in _pairs) {
      final refA = byPartner[pair.a];
      final refB = byPartner[pair.b];
      if (refA == null || refB == null) continue;

      if (_pairOffScreen(refA, refB)) {
        pair.effect?.removeFromParent();
        pair.effect = null;
        continue;
      }

      var effect = pair.effect;
      if (effect == null || effect.parent == null) {
        effect = BinaryMergerEffect();
        game.world.add(effect);
        pair.effect = effect;
      }

      final distance = refA.position.distanceTo(refB.position);
      final combined = refA.radius + refB.radius;
      final larger = refA.radius >= refB.radius ? refA : refB;
      final smaller = larger == refA ? refB : refA;

      effect.updateState(
        posA: larger.position,
        posB: smaller.position,
        radiusA: larger.radius,
        radiusB: smaller.radius,
        accentA: _accentFor(larger, fallback: const Color(0xFFFFAA44)),
        accentB: _accentFor(smaller, fallback: const Color(0xFF55AAFF)),
        stage: pair.stage.index + 1,
        intensity: _stageIntensity(pair.stage, distance, combined),
      );
    }
  }

  double _stageIntensity(_MergerStage stage, double distance, double combined) {
    double ramp(double outer, double inner) {
      final span = combined * (outer - inner);
      if (span <= 0) return 1;
      return (1 - (distance - combined * inner) / span).clamp(0.0, 1.0);
    }

    return switch (stage) {
      _MergerStage.inspiral =>
        0.15 + 0.35 * ramp(inspiralOnsetRadii, tidalOnsetRadii),
      _MergerStage.tidal => 0.4 + 0.4 * ramp(tidalOnsetRadii, danceOnsetRadii),
      _MergerStage.dance => 0.75 + 0.25 * ramp(danceOnsetRadii, 0.7),
    };
  }

  Color _accentFor(_HoleRef ref, {required Color fallback}) {
    final component = ref.component;
    if (component is BotPlayer) return component.accentColor;
    if (component is EnemyPlayer) return const Color(0xFF5599EE);
    return fallback;
  }

  void _spawnSwallowBurst(_HoleRef winner, _HoleRef loser) {
    final burstPos = GravityScaling.photonRingEntryPoint(
      predatorPosition: winner.position,
      preyPosition: loser.position,
      predatorRadius: winner.radius,
    );
    final infallAngle = math.atan2(
      winner.position.y - loser.position.y,
      winner.position.x - loser.position.x,
    );

    Color accent = const Color(0xFFFFAA44);
    if (winner.component is BotPlayer) {
      accent = (winner.component as BotPlayer).accentColor;
    } else if (loser.component is BotPlayer) {
      accent = (loser.component as BotPlayer).accentColor;
    }

    game.world.add(
      HoleSwallowBurstEffect(
        position: burstPos,
        predatorRadius: winner.radius,
        preyRadius: loser.radius,
        infallAngle: infallAngle,
        accent: accent,
      ),
    );
  }

  @override
  void onRemove() {
    for (final pair in _pairs) {
      pair.effect?.removeFromParent();
    }
    _pairs.clear();
    super.onRemove();
  }
}

enum _MergerStage { inspiral, tidal, dance }

class _MergerPairState {
  _MergerPairState({required this.a, required this.b});

  final BlackHolePartner a;
  final BlackHolePartner b;
  _MergerStage stage = _MergerStage.inspiral;
  double stageTime = 0;
  double rippleTimer = 0;
  BinaryMergerEffect? effect;

  bool involves(BlackHolePartner hole) => hole == a || hole == b;

  void enterStage(_MergerStage next) {
    if (stage == next) return;
    stage = next;
    stageTime = 0;
    rippleTimer = 0;
  }
}

class _HoleRef {
  _HoleRef(this.partner, this.component);

  final BlackHolePartner partner;
  final PositionComponent component;

  Vector2 get position => partner.position;
  Vector2 get velocity => partner.velocity;
  double get radius => partner.holeRadius;
}
