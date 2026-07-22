// Lobby skill-tree definitions and runtime ability loadout resolution.
// SP model: floor(peakDiamonds / 20) earned; diamonds are not spent.
// Soft power: each node max 10; per-axis gains stay roughly in the 12–25% band.

enum SkillBranch {
  boost,
  teleport,
  shield,
  shockwave,
}

enum SkillNodeId {
  boostSpeed('boost_speed', SkillBranch.boost),
  boostDuration('boost_duration', SkillBranch.boost),
  boostCharge('boost_charge', SkillBranch.boost),
  teleportCooldown('teleport_cooldown', SkillBranch.teleport),
  teleportShield('teleport_shield', SkillBranch.teleport),
  shieldCooldown('shield_cooldown', SkillBranch.shield),
  shieldDuration('shield_duration', SkillBranch.shield),
  shockwaveCooldown('shockwave_cooldown', SkillBranch.shockwave),
  shockwaveRange('shockwave_range', SkillBranch.shockwave),
  shockwavePower('shockwave_power', SkillBranch.shockwave);

  const SkillNodeId(this.key, this.branch);

  final String key;
  final SkillBranch branch;

  static SkillNodeId? tryParse(String raw) {
    for (final id in SkillNodeId.values) {
      if (id.key == raw) return id;
    }
    return null;
  }
}

class SkillNodeDef {
  const SkillNodeDef({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.formatValue,
  });

  final SkillNodeId id;
  final String titleKey;
  final String descKey;

  /// Formats the resolved numeric value for UI (level → display string).
  final String Function(int level) formatValue;
}

/// Resolved combat stats after applying skill levels to base values.
class AbilityLoadout {
  const AbilityLoadout({
    required this.boostSpeedMultiplier,
    required this.boostChargeDuration,
    required this.boostActiveDuration,
    required this.teleportCooldown,
    required this.teleportBriefShield,
    required this.abilityShieldCooldown,
    required this.abilityShieldDuration,
    required this.shockwaveCooldown,
    required this.shockwaveRangeMult,
    required this.shockwaveHoleImpulse,
    required this.shockwaveMatterImpulse,
  });

  static const diamondsPerSp = 20;
  static const maxLevel = 10;

  static const baseBoostSpeedMultiplier = 2.0;
  static const baseBoostChargeDuration = 10.0;
  static const baseBoostActiveDuration = 5.0;
  static const baseTeleportCooldown = 60.0;
  static const baseTeleportBriefShield = 1.0;
  static const baseAbilityShieldCooldown = 50.0;
  static const baseAbilityShieldDuration = 4.0;
  static const baseShockwaveCooldown = 35.0;
  static const baseShockwaveRangeMult = 1.0;
  static const baseShockwaveHoleImpulse = 340.0;
  static const baseShockwaveMatterImpulse = 420.0;

  /// +1.5% speed mult / level → 2.00 … 2.30
  static const boostSpeedPerLevel = 0.03;

  /// +0.12s active / level → 5.00 … 6.20
  static const boostDurationPerLevel = 0.12;

  /// −0.22s charge / level → 10.00 … 7.80
  static const boostChargePerLevel = 0.22;

  /// −1.2s CD / level → 60 … 48
  static const teleportCooldownPerLevel = 1.2;

  /// +0.08s brief shield / level → 1.00 … 1.80
  static const teleportShieldPerLevel = 0.08;

  /// −1.0s CD / level → 50 … 40
  static const shieldCooldownPerLevel = 1.0;

  /// +0.15s duration / level → 4.00 … 5.50
  static const shieldDurationPerLevel = 0.15;

  /// −0.8s CD / level → 35 … 27
  static const shockwaveCooldownPerLevel = 0.8;

  /// +2.5% range / level → 1.00 … 1.25
  static const shockwaveRangePerLevel = 0.025;

  /// +2% impulse / level → ×1.00 … ×1.20
  static const shockwavePowerPerLevel = 0.02;

  final double boostSpeedMultiplier;
  final double boostChargeDuration;
  final double boostActiveDuration;
  final double teleportCooldown;
  final double teleportBriefShield;
  final double abilityShieldCooldown;
  final double abilityShieldDuration;
  final double shockwaveCooldown;
  final double shockwaveRangeMult;
  final double shockwaveHoleImpulse;
  final double shockwaveMatterImpulse;

  static const base = AbilityLoadout(
    boostSpeedMultiplier: baseBoostSpeedMultiplier,
    boostChargeDuration: baseBoostChargeDuration,
    boostActiveDuration: baseBoostActiveDuration,
    teleportCooldown: baseTeleportCooldown,
    teleportBriefShield: baseTeleportBriefShield,
    abilityShieldCooldown: baseAbilityShieldCooldown,
    abilityShieldDuration: baseAbilityShieldDuration,
    shockwaveCooldown: baseShockwaveCooldown,
    shockwaveRangeMult: baseShockwaveRangeMult,
    shockwaveHoleImpulse: baseShockwaveHoleImpulse,
    shockwaveMatterImpulse: baseShockwaveMatterImpulse,
  );

  static int clampLevel(int level) => level.clamp(0, maxLevel);

  static int levelOf(Map<String, int> levels, SkillNodeId id) =>
      clampLevel(levels[id.key] ?? 0);

  static int spentSp(Map<String, int> levels) {
    var sum = 0;
    for (final entry in levels.entries) {
      if (SkillNodeId.tryParse(entry.key) == null) continue;
      sum += clampLevel(entry.value);
    }
    return sum;
  }

  static int earnedSp(int peakDiamonds) =>
      (peakDiamonds.clamp(0, 1 << 30)) ~/ diamondsPerSp;

  static int availableSp({
    required int peakDiamonds,
    required Map<String, int> levels,
  }) =>
      (earnedSp(peakDiamonds) - spentSp(levels)).clamp(0, 1 << 30);

  static int diamondsToNextSp(int peakDiamonds) {
    final next = (earnedSp(peakDiamonds) + 1) * diamondsPerSp;
    return (next - peakDiamonds).clamp(0, diamondsPerSp);
  }

  factory AbilityLoadout.fromLevels(Map<String, int> levels) {
    final boostSpeed = levelOf(levels, SkillNodeId.boostSpeed);
    final boostDuration = levelOf(levels, SkillNodeId.boostDuration);
    final boostCharge = levelOf(levels, SkillNodeId.boostCharge);
    final teleportCd = levelOf(levels, SkillNodeId.teleportCooldown);
    final teleportShield = levelOf(levels, SkillNodeId.teleportShield);
    final shieldCd = levelOf(levels, SkillNodeId.shieldCooldown);
    final shieldDuration = levelOf(levels, SkillNodeId.shieldDuration);
    final shockCd = levelOf(levels, SkillNodeId.shockwaveCooldown);
    final shockRange = levelOf(levels, SkillNodeId.shockwaveRange);
    final shockPower = levelOf(levels, SkillNodeId.shockwavePower);

    final powerMult = 1.0 + shockPower * shockwavePowerPerLevel;

    return AbilityLoadout(
      boostSpeedMultiplier:
          baseBoostSpeedMultiplier + boostSpeed * boostSpeedPerLevel,
      boostChargeDuration:
          baseBoostChargeDuration - boostCharge * boostChargePerLevel,
      boostActiveDuration:
          baseBoostActiveDuration + boostDuration * boostDurationPerLevel,
      teleportCooldown:
          baseTeleportCooldown - teleportCd * teleportCooldownPerLevel,
      teleportBriefShield:
          baseTeleportBriefShield + teleportShield * teleportShieldPerLevel,
      abilityShieldCooldown:
          baseAbilityShieldCooldown - shieldCd * shieldCooldownPerLevel,
      abilityShieldDuration:
          baseAbilityShieldDuration + shieldDuration * shieldDurationPerLevel,
      shockwaveCooldown:
          baseShockwaveCooldown - shockCd * shockwaveCooldownPerLevel,
      shockwaveRangeMult:
          baseShockwaveRangeMult + shockRange * shockwaveRangePerLevel,
      shockwaveHoleImpulse: baseShockwaveHoleImpulse * powerMult,
      shockwaveMatterImpulse: baseShockwaveMatterImpulse * powerMult,
    );
  }

  static String _fmtSec(double v) => '${v.toStringAsFixed(v >= 10 ? 0 : 1)}s';
  static String _fmtMult(double v) => '${v.toStringAsFixed(2)}×';
  static String _fmtPct(double v) => '+${(v * 100).round()}%';

  static final nodes = <SkillNodeDef>[
    SkillNodeDef(
      id: SkillNodeId.boostSpeed,
      titleKey: 'skill_node_boost_speed',
      descKey: 'skill_node_boost_speed_desc',
      formatValue: (lvl) => _fmtMult(
            baseBoostSpeedMultiplier + clampLevel(lvl) * boostSpeedPerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.boostDuration,
      titleKey: 'skill_node_boost_duration',
      descKey: 'skill_node_boost_duration_desc',
      formatValue: (lvl) => _fmtSec(
            baseBoostActiveDuration + clampLevel(lvl) * boostDurationPerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.boostCharge,
      titleKey: 'skill_node_boost_charge',
      descKey: 'skill_node_boost_charge_desc',
      formatValue: (lvl) => _fmtSec(
            baseBoostChargeDuration - clampLevel(lvl) * boostChargePerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.teleportCooldown,
      titleKey: 'skill_node_teleport_cd',
      descKey: 'skill_node_teleport_cd_desc',
      formatValue: (lvl) => _fmtSec(
            baseTeleportCooldown - clampLevel(lvl) * teleportCooldownPerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.teleportShield,
      titleKey: 'skill_node_teleport_shield',
      descKey: 'skill_node_teleport_shield_desc',
      formatValue: (lvl) => _fmtSec(
            baseTeleportBriefShield + clampLevel(lvl) * teleportShieldPerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.shieldCooldown,
      titleKey: 'skill_node_shield_cd',
      descKey: 'skill_node_shield_cd_desc',
      formatValue: (lvl) => _fmtSec(
            baseAbilityShieldCooldown - clampLevel(lvl) * shieldCooldownPerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.shieldDuration,
      titleKey: 'skill_node_shield_duration',
      descKey: 'skill_node_shield_duration_desc',
      formatValue: (lvl) => _fmtSec(
            baseAbilityShieldDuration +
                clampLevel(lvl) * shieldDurationPerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.shockwaveCooldown,
      titleKey: 'skill_node_shockwave_cd',
      descKey: 'skill_node_shockwave_cd_desc',
      formatValue: (lvl) => _fmtSec(
            baseShockwaveCooldown - clampLevel(lvl) * shockwaveCooldownPerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.shockwaveRange,
      titleKey: 'skill_node_shockwave_range',
      descKey: 'skill_node_shockwave_range_desc',
      formatValue: (lvl) => _fmtPct(
            clampLevel(lvl) * shockwaveRangePerLevel,
          ),
    ),
    SkillNodeDef(
      id: SkillNodeId.shockwavePower,
      titleKey: 'skill_node_shockwave_power',
      descKey: 'skill_node_shockwave_power_desc',
      formatValue: (lvl) => _fmtPct(
            clampLevel(lvl) * shockwavePowerPerLevel,
          ),
    ),
  ];

  static List<SkillNodeDef> nodesFor(SkillBranch branch) =>
      nodes.where((n) => n.id.branch == branch).toList(growable: false);
}
