/// Per-match telemetry collected on the local client for the end-of-match summary.
class GrowthSample {
  const GrowthSample({required this.elapsedSeconds, required this.radius});

  final double elapsedSeconds;
  final double radius;
}

class MatchStatsSnapshot {
  const MatchStatsSnapshot({
    required this.growthSamples,
    required this.kills,
    required this.playerKills,
    required this.botKills,
    required this.particlesAbsorbed,
    required this.deaths,
    required this.boostUses,
    required this.teleportUses,
    required this.shieldUses,
    required this.shockwaveUses,
    required this.peakRadius,
    required this.matchElapsed,
    required this.victoryRadius,
  });

  final List<GrowthSample> growthSamples;
  final int kills;
  final int playerKills;
  final int botKills;
  final int particlesAbsorbed;
  final int deaths;
  final int boostUses;
  final int teleportUses;
  final int shieldUses;
  final int shockwaveUses;
  final double peakRadius;
  final double matchElapsed;
  final double victoryRadius;

  int get totalAbilityUses =>
      boostUses + teleportUses + shieldUses + shockwaveUses;
}

class MatchStatsTracker {
  final List<GrowthSample> _growthSamples = [];
  int playerKills = 0;
  int botKills = 0;
  int particlesAbsorbed = 0;
  int deaths = 0;
  int boostUses = 0;
  int teleportUses = 0;
  int shieldUses = 0;
  int shockwaveUses = 0;

  double _sampleTimer = 0;

  static const sampleIntervalSeconds = 2.0;

  int get kills => playerKills + botKills;

  void reset() {
    _growthSamples.clear();
    playerKills = 0;
    botKills = 0;
    particlesAbsorbed = 0;
    deaths = 0;
    boostUses = 0;
    teleportUses = 0;
    shieldUses = 0;
    shockwaveUses = 0;
    _sampleTimer = 0;
  }

  void recordPlayerKill() => playerKills++;

  void recordBotKill() => botKills++;

  void recordParticle() => particlesAbsorbed++;

  void recordDeath() => deaths++;

  void recordBoost() => boostUses++;

  void recordTeleport() => teleportUses++;

  void recordShield() => shieldUses++;

  void recordShockwave() => shockwaveUses++;

  void tickSampling({
    required double dt,
    required double elapsedSeconds,
    required double radius,
    required bool active,
  }) {
    if (!active) return;

    if (_growthSamples.isEmpty) {
      _growthSamples.add(
        GrowthSample(elapsedSeconds: elapsedSeconds, radius: radius),
      );
      _sampleTimer = 0;
      return;
    }

    _sampleTimer += dt;
    if (_sampleTimer < sampleIntervalSeconds) return;
    _sampleTimer = 0;
    _appendSample(elapsedSeconds, radius);
  }

  void _appendSample(double elapsedSeconds, double radius) {
    final last = _growthSamples.last;
    if ((last.elapsedSeconds - elapsedSeconds).abs() < 0.05 &&
        (last.radius - radius).abs() < 0.5) {
      return;
    }
    _growthSamples.add(
      GrowthSample(elapsedSeconds: elapsedSeconds, radius: radius),
    );
  }

  MatchStatsSnapshot buildSnapshot({
    required double peakRadius,
    required double matchElapsed,
    required double victoryRadius,
  }) {
    final samples = List<GrowthSample>.from(_growthSamples);
    if (samples.isEmpty) {
      samples.add(GrowthSample(elapsedSeconds: 0, radius: peakRadius));
    } else {
      final last = samples.last;
      if ((last.elapsedSeconds - matchElapsed).abs() > 0.05 ||
          (last.radius - peakRadius).abs() > 0.5) {
        samples.add(
          GrowthSample(elapsedSeconds: matchElapsed, radius: peakRadius),
        );
      }
    }

    return MatchStatsSnapshot(
      growthSamples: samples,
      kills: kills,
      playerKills: playerKills,
      botKills: botKills,
      particlesAbsorbed: particlesAbsorbed,
      deaths: deaths,
      boostUses: boostUses,
      teleportUses: teleportUses,
      shieldUses: shieldUses,
      shockwaveUses: shockwaveUses,
      peakRadius: peakRadius,
      matchElapsed: matchElapsed,
      victoryRadius: victoryRadius,
    );
  }
}
