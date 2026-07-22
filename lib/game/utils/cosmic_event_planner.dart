import 'dart:math' as math;

import '../config/match_pacing.dart';
import '../models/cosmic_event_cue.dart';
import 'world_positions.dart';

/// Builds a deterministic supernova/meteor timeline from a server seed.
///
/// Every client in the same room with the same [seed] + [pacing] + [worldSize]
/// produces identical cues (same time, same place).
class CosmicEventPlanner {
  CosmicEventPlanner({
    required int seed,
    required MatchPacing pacing,
    required double worldSize,
  }) : _rng = math.Random(seed) {
    _buildSchedule(pacing: pacing, worldSize: worldSize);
  }

  final math.Random _rng;
  final List<CosmicEventCue> cues = [];

  void _buildSchedule({
    required MatchPacing pacing,
    required double worldSize,
  }) {
    cues.clear();
    final interval = pacing.supernovaIntervalSeconds;
    if (interval <= 0) return;

    var nextSupernova = pacing.supernovaFirstDelaySeconds > 0
        ? pacing.supernovaFirstDelaySeconds
        : interval;
    var nextMeteor = pacing.meteorShowerInitialCooldown > 0
        ? pacing.meteorShowerInitialCooldown
        : 45.0;
    var supernovaCount = 0;
    final horizon = pacing.targetMinutesMax * 60 + 180;

    while (cues.length < 48) {
      final pickSupernova = nextSupernova <= nextMeteor;
      if (pickSupernova) {
        if (nextSupernova > horizon) break;
        final warnAt = nextSupernova;
        final startAt = warnAt + CosmicEventCueDurations.supernovaWarning;
        final center = randomWorldPositionWith(
          _rng,
          worldSize: worldSize,
          margin: 400,
          minSeparation: supernovaCount == 0 ? 220 : 500,
        );
        final spawnSeed = _rng.nextInt(1 << 30);
        cues.add(
          CosmicEventCue(
            serial: cues.length,
            kind: CosmicEventKind.supernova,
            warnAt: warnAt,
            startAt: startAt,
            endAt: startAt,
            center: center,
            regionRadius: 0,
            spawnSeed: spawnSeed,
          ),
        );
        supernovaCount++;
        nextSupernova = startAt + interval;
        if (nextMeteor < startAt) {
          nextMeteor = startAt;
        }
      } else {
        if (nextMeteor > horizon) break;
        final warnAt = nextMeteor;
        final startAt = warnAt + CosmicEventCueDurations.meteorWarning;
        final endAt = startAt + CosmicEventCueDurations.meteorShower;
        final center = randomWorldPositionWith(
          _rng,
          worldSize: worldSize,
          margin: 300,
          minSeparation: 200,
        );
        final regionRadius = 700 + _rng.nextDouble() * 500;
        final spawnSeed = _rng.nextInt(1 << 30);
        cues.add(
          CosmicEventCue(
            serial: cues.length,
            kind: CosmicEventKind.meteorShower,
            warnAt: warnAt,
            startAt: startAt,
            endAt: endAt,
            center: center,
            regionRadius: regionRadius,
            spawnSeed: spawnSeed,
          ),
        );
        nextMeteor = endAt + 25 + _rng.nextDouble() * 20;
        if (nextSupernova < endAt) {
          nextSupernova = endAt;
        }
      }
    }
  }

  /// Active cue at [elapsed] match-seconds, if any.
  CosmicEventCue? cueAt(double elapsed) {
    for (final cue in cues) {
      if (cue.isActiveAt(elapsed)) return cue;
    }
    return null;
  }

  /// Latest supernova that should have detonated at or before [elapsed].
  CosmicEventCue? latestSupernovaDue(double elapsed) {
    CosmicEventCue? latest;
    for (final cue in cues) {
      if (cue.kind != CosmicEventKind.supernova) continue;
      if (elapsed + 0.001 < cue.startAt) break;
      latest = cue;
    }
    return latest;
  }
}

abstract final class CosmicEventCueDurations {
  static const supernovaWarning = 5.0;
  static const meteorWarning = 5.0;
  static const meteorShower = 20.0;
}
