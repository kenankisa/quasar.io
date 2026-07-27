import 'dart:math' as math;

import '../../services/room_tuning_service.dart';
import '../models/hardcore_arena_tuning.dart';
import '../room_type.dart';

/// Hardcore universe — players-only arena rules.
///
/// Compile-time defaults mirror the v2 package. Live admin values come from
/// [RoomTuningService] → [HardcoreArenaTuning] (and economy/idle services).
class HardcoreRules {
  const HardcoreRules._();

  /// Default seat cap when live tuning is unavailable.
  static const int maxPlayers = 20;
  /// Admin may join beyond [liveMaxPlayers] and does not consume a seat.
  static const bool adminExemptFromSeatCap = true;

  /// Live seat cap from admin room tuning (0–100).
  static int get liveMaxPlayers {
    try {
      return RoomTuningService.instance
          .tuningFor(RoomType.hardcore)
          .maxPlayers
          .clamp(0, 100);
    } catch (_) {
      return maxPlayers;
    }
  }
  static const double playerStartRadius = 25;
  static const double victoryRadius = 600;
  static const double spawnProtectionSeconds = 12;

  /// Kill reward when arena is active ([killActiveArenaMinAlive]+ alive).
  static const int killRewardDiamonds = 4;
  static const int killActiveArenaMinAlive = 6;
  static const int eliminationPenaltyDiamonds = 15;
  static const int victoryRewardDiamonds = 40;
  static const int victoryHardcorePoints = 1;

  /// Active arena: win or elim while 6+ alive.
  static const Duration entryCooldown = Duration(hours: 1);

  /// Passive arena (&lt; min-alive): elim re-entry wait.
  static const Duration passiveElimCooldown = Duration(minutes: 5);

  /// Live victory is **size-only** (≥ [victoryRadius]). No PvP-mass or stability timer.
  /// [victoryMinAlive] gates the low-pop softcap (~450) and kill-reward tier only.
  static const int victoryMinAlive = 6;

  /// Arena Test / load-test sim only — not used for live Hardcore victory.
  static const double victoryStableSeconds = 20;

  /// Arena Test / load-test sim only — not used for live Hardcore victory.
  static const double victoryMinPvpMassFraction = 0.35;

  /// Extra food softcap near endgame (on top of MatchPacing late growth).
  static const double lateFoodSoftcapRadius = 450;
  static const double lateFoodSoftcapMultiplier = 0.5;

  /// While arena is inactive (&lt; [victoryMinAlive] alive), radius cannot exceed
  /// this — blocks camping at 600 waiting for the 6th player.
  /// Live + Arena Test share the same knob via [HardcoreArenaTuning].
  static double get liveLowPopRadiusCap => arena.lowPopRadiusCap;

  /// Match AFK: softer early/mid, tighter near victory (overrides global idle config).
  static const double afkLateGameRadius = 450;
  static const int matchIdleBeforeWarningSeconds = 15;
  static const int matchIdleBeforeWarningLateSeconds = 10;
  static const int matchWarningCountdownSeconds = 3;
  static const int matchMassDrainPerSecond = 7;
  static const int matchMassDrainLatePerSecond = 10;

  /// Live Hardcore arena knobs from admin room tuning (falls back to defaults).
  static HardcoreArenaTuning get arena {
    try {
      return RoomTuningService.instance
          .tuningFor(RoomType.hardcore)
          .hardcoreArena;
    } catch (_) {
      return HardcoreArenaTuning.defaults;
    }
  }

  static double get liveSpawnProtectionSeconds =>
      arena.spawnProtectionSeconds;

  static int get liveVictoryMinAlive => arena.victoryMinAlive;

  static double get liveVictoryStableSeconds => arena.victoryStableSeconds;

  static double get liveVictoryMinPvpMassFraction =>
      arena.victoryMinPvpMassFraction;

  static double get liveLateFoodSoftcapRadius => arena.lateFoodSoftcapRadius;

  static double get liveLateFoodSoftcapMultiplier =>
      arena.lateFoodSoftcapMultiplier;

  /// Population → food growth multiplier (PvP merges ignore this).
  static double foodGrowthMultiplierForAlive(int alive) =>
      arena.foodGrowthMultiplierForAlive(alive);

  static bool isVictoryClaimReady({
    required int aliveCount,
    required double arenaActiveSeconds,
    required double pvpMassFraction,
  }) {
    // Arena Test / sim harness only — live Hardcore wins at size ≥ victoryRadius.
    return arena.isVictoryClaimReady(
      aliveCount: aliveCount,
      arenaActiveSeconds: arenaActiveSeconds,
      pvpMassFraction: pvpMassFraction,
    );
  }
}

/// Deterministic low-pop overflow drain — same inputs → same radius on every client.
class HardcoreLowPopDrain {
  const HardcoreLowPopDrain._();

  static const double minDrainPerSecond = 40;
  static const double excessDrainFactor = 2.5;
  static const double simulationStepSeconds = 1 / 120;

  /// One integration step (used when server phase time is unavailable).
  static double drainStep(double radius, double softCap, double dt) {
    if (radius <= softCap || dt <= 0) return radius;
    final excess = radius - softCap;
    final drain = math.max(minDrainPerSecond, excess * excessDrainFactor) * dt;
    return math.max(softCap, radius - drain);
  }

  /// Integrate overflow drain from [anchorRadius] over [elapsedSeconds].
  static double radiusAfterElapsed(
    double anchorRadius,
    double elapsedSeconds,
    double softCap,
  ) {
    if (anchorRadius <= softCap || elapsedSeconds <= 0) return anchorRadius;
    var r = anchorRadius;
    var t = 0.0;
    while (t < elapsedSeconds && r > softCap) {
      final step = math.min(simulationStepSeconds, elapsedSeconds - t);
      r = drainStep(r, softCap, step);
      t += step;
    }
    return r;
  }

  static double clampGrowth(double radius, double softCap) =>
      radius > softCap ? softCap : radius;
}

/// Arena / live Hardcore: DB member count injected so softcap / victory
/// population does not rely only on lossy realtime peer sightings.
class HardcoreArenaAliveHint {
  HardcoreArenaAliveHint._();

  static int? _memberCount;
  static int? _stickyMembers;
  static int? _queueCount;
  static int? _seatCap;
  static int? _simTarget;
  static DateTime? _updatedAt;

  static const _freshFor = Duration(seconds: 12);

  static void setMembers(int count) {
    _memberCount = count.clamp(0, 500);
    _stickyMembers = _memberCount;
    _updatedAt = DateTime.now();
  }

  /// Arena Test harness: seats + outside queue + spawn target.
  static void setTestArenaOps({
    required int members,
    required int queue,
    required int seatCap,
    required int simTarget,
  }) {
    _memberCount = members.clamp(0, 500);
    _stickyMembers = _memberCount;
    _queueCount = queue.clamp(0, 500);
    _seatCap = seatCap.clamp(1, 100);
    _simTarget = simTarget.clamp(0, 500);
    _updatedAt = DateTime.now();
  }

  /// Back-compat alias used by Arena Test harness.
  static void setTestArenaMembers(int count) => setMembers(count);

  static void clear() {
    _memberCount = null;
    _stickyMembers = null;
    _queueCount = null;
    _seatCap = null;
    _simTarget = null;
    _updatedAt = null;
  }

  /// Fresh DB/harness count, or null if stale / unset.
  static int? get freshMembers {
    final at = _updatedAt;
    final n = _memberCount;
    if (at == null || n == null) return null;
    if (DateTime.now().difference(at) > _freshFor) return null;
    return n;
  }

  /// Softcap population hint: prefer fresh DB count, else last known (avoids 450 lock
  /// when realtime peer sightings are incomplete under load).
  static int? get populationHint => freshMembers ?? _stickyMembers;

  /// Back-compat alias.
  static int? get freshTestArenaMembers => freshMembers;

  /// Arena Test: pause auto-PvP while filling seats or while queue is active.
  /// Does NOT block growth past 450 or size-600 victory (live rules).
  static bool get shouldHoldSeatsForQueueTest {
    final at = _updatedAt;
    if (at == null) return false;
    if (DateTime.now().difference(at) > _freshFor) return false;
    final members = _memberCount ?? 0;
    final queue = _queueCount ?? 0;
    final cap = _seatCap ?? HardcoreRules.maxPlayers;
    final target = _simTarget ?? 0;
    if (queue > 0) return true;
    if (members < cap) return true;
    if (target > cap) return true;
    return false;
  }
}
