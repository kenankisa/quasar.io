import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/models/app_economy_config.dart';
import '../services/app_economy_config_service.dart';

/// Yönetici: elmas ödülleri, yutulma cezaları, eşikler, sandık, günlük limitler.
class AdminEconomySettingsPanel extends StatelessWidget {
  const AdminEconomySettingsPanel({super.key});

  static const _accent = Color(0xFF7CFFB2);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppEconomyConfigService.instance,
      builder: (context, _) {
        final service = AppEconomyConfigService.instance;
        final config = service.config;
        final defaults = AppEconomyConfig.defaults;
        final lang = context.lang;
        final saving = service.saving;
        final dirty = service.hasUnsavedChanges;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.t('admin_economy_intro'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (service.error != null) ...[
              const SizedBox(height: 10),
              Text(
                service.error!,
                style: const TextStyle(color: Color(0xFFFF6688), fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            _SectionTitle(lang.t('admin_economy_rewards_section'), _accent),
            const SizedBox(height: 6),
            Text(
              lang.t('admin_economy_rewards_hint'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _RoomRewardBlock(
              title: lang.t('admin_rank_points_simple'),
              r1: config.rewardSimple1,
              r2: config.rewardSimple2,
              r3: config.rewardSimple3,
              d1: defaults.rewardSimple1,
              d2: defaults.rewardSimple2,
              d3: defaults.rewardSimple3,
              enabled: !saving,
              onR1: (v) => service.updateConfig(
                (c) => c.copyWith(rewardSimple1: v),
              ),
              onR2: (v) => service.updateConfig(
                (c) => c.copyWith(rewardSimple2: v),
              ),
              onR3: (v) => service.updateConfig(
                (c) => c.copyWith(rewardSimple3: v),
              ),
            ),
            _RoomRewardBlock(
              title: lang.t('admin_rank_points_normal'),
              r1: config.rewardNormal1,
              r2: config.rewardNormal2,
              r3: config.rewardNormal3,
              d1: defaults.rewardNormal1,
              d2: defaults.rewardNormal2,
              d3: defaults.rewardNormal3,
              enabled: !saving,
              onR1: (v) => service.updateConfig(
                (c) => c.copyWith(rewardNormal1: v),
              ),
              onR2: (v) => service.updateConfig(
                (c) => c.copyWith(rewardNormal2: v),
              ),
              onR3: (v) => service.updateConfig(
                (c) => c.copyWith(rewardNormal3: v),
              ),
            ),
            _RoomRewardBlock(
              title: lang.t('admin_rank_points_elite'),
              r1: config.rewardElite1,
              r2: config.rewardElite2,
              r3: config.rewardElite3,
              d1: defaults.rewardElite1,
              d2: defaults.rewardElite2,
              d3: defaults.rewardElite3,
              enabled: !saving,
              onR1: (v) =>
                  service.updateConfig((c) => c.copyWith(rewardElite1: v)),
              onR2: (v) =>
                  service.updateConfig((c) => c.copyWith(rewardElite2: v)),
              onR3: (v) =>
                  service.updateConfig((c) => c.copyWith(rewardElite3: v)),
            ),
            _RoomRewardBlock(
              title: lang.t('admin_rank_points_unique'),
              r1: config.rewardUnique1,
              r2: config.rewardUnique2,
              r3: config.rewardUnique3,
              d1: defaults.rewardUnique1,
              d2: defaults.rewardUnique2,
              d3: defaults.rewardUnique3,
              enabled: !saving,
              onR1: (v) =>
                  service.updateConfig((c) => c.copyWith(rewardUnique1: v)),
              onR2: (v) =>
                  service.updateConfig((c) => c.copyWith(rewardUnique2: v)),
              onR3: (v) =>
                  service.updateConfig((c) => c.copyWith(rewardUnique3: v)),
            ),
            const SizedBox(height: 14),
            _SectionTitle(lang.t('admin_economy_hardcore_section'), _accent),
            const SizedBox(height: 6),
            Text(
              lang.t('admin_economy_hardcore_hint'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _EcoSlider(
              label: lang.t('admin_hardcore_reward_victory'),
              value: config.rewardHardcore1.toDouble(),
              min: 0,
              max: 100,
              display: '+${config.rewardHardcore1}',
              defaultLabel: '+${defaults.rewardHardcore1}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(rewardHardcore1: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_hardcore_reward_kill'),
              value: config.rewardHardcoreKill.toDouble(),
              min: 0,
              max: 25,
              display: '+${config.rewardHardcoreKill}',
              defaultLabel: '+${defaults.rewardHardcoreKill}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(rewardHardcoreKill: v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(lang.t('admin_economy_penalty_section'), _accent),
            const SizedBox(height: 8),
            _EcoSlider(
              label: lang.t('admin_rank_points_simple'),
              value: config.penaltySimple.toDouble(),
              min: 0,
              max: 10,
              display: '−${config.penaltySimple}',
              defaultLabel: '−${defaults.penaltySimple}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(penaltySimple: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_rank_points_normal'),
              value: config.penaltyNormal.toDouble(),
              min: 0,
              max: 15,
              display: '−${config.penaltyNormal}',
              defaultLabel: '−${defaults.penaltyNormal}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(penaltyNormal: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_rank_points_elite'),
              value: config.penaltyElite.toDouble(),
              min: 0,
              max: 20,
              display: '−${config.penaltyElite}',
              defaultLabel: '−${defaults.penaltyElite}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(penaltyElite: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_rank_points_unique'),
              value: config.penaltyUnique.toDouble(),
              min: 0,
              max: 25,
              display: '−${config.penaltyUnique}',
              defaultLabel: '−${defaults.penaltyUnique}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(penaltyUnique: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_rank_points_hardcore'),
              value: config.penaltyHardcore.toDouble(),
              min: 0,
              max: 50,
              display: '−${config.penaltyHardcore}',
              defaultLabel: '−${defaults.penaltyHardcore}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(penaltyHardcore: v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(lang.t('admin_economy_unlock_section'), _accent),
            const SizedBox(height: 8),
            _EcoSlider(
              label: lang.t('admin_rank_points_normal'),
              value: config.unlockNormal.toDouble(),
              min: 0,
              max: 500,
              display: '${config.unlockNormal}',
              defaultLabel: '${defaults.unlockNormal}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(unlockNormal: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_rank_points_elite'),
              value: config.unlockElite.toDouble(),
              min: 0,
              max: 1000,
              display: '${config.unlockElite}',
              defaultLabel: '${defaults.unlockElite}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(unlockElite: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_rank_points_unique'),
              value: config.unlockUnique.toDouble(),
              min: 0,
              max: 2000,
              display: '${config.unlockUnique}',
              defaultLabel: '${defaults.unlockUnique}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(unlockUnique: v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(lang.t('admin_economy_chest_section'), _accent),
            const SizedBox(height: 8),
            _EcoSlider(
              label: lang.t('admin_economy_chest_low'),
              value: config.chestAmount1.toDouble(),
              min: 1,
              max: 100,
              display: '${config.chestAmount1}',
              defaultLabel: '${defaults.chestAmount1}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(chestAmount1: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_chest_mid'),
              value: config.chestAmount2.toDouble(),
              min: 1,
              max: 150,
              display: '${config.chestAmount2}',
              defaultLabel: '${defaults.chestAmount2}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(chestAmount2: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_chest_high'),
              value: config.chestAmount3.toDouble(),
              min: 1,
              max: 200,
              display: '${config.chestAmount3}',
              defaultLabel: '${defaults.chestAmount3}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(chestAmount3: v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(lang.t('admin_economy_limits_section'), _accent),
            const SizedBox(height: 8),
            _EcoSlider(
              label: lang.t('admin_economy_daily_cap'),
              value: config.dailyMatchDiamondCap.toDouble(),
              min: 10,
              max: 500,
              display: '${config.dailyMatchDiamondCap}',
              defaultLabel: '${defaults.dailyMatchDiamondCap}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(dailyMatchDiamondCap: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_reward_claims'),
              value: config.rewardClaimsPerDay.toDouble(),
              min: 1,
              max: 100,
              display: '${config.rewardClaimsPerDay}',
              defaultLabel: '${defaults.rewardClaimsPerDay}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(rewardClaimsPerDay: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_training_claims'),
              value: config.trainingClaimsPerDay.toDouble(),
              min: 1,
              max: 50,
              display: '${config.trainingClaimsPerDay}',
              defaultLabel: '${defaults.trainingClaimsPerDay}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(trainingClaimsPerDay: v.round()),
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_ad_doubles'),
              value: config.adDoublesPerDay.toDouble(),
              min: 0,
              max: 20,
              display: '${config.adDoublesPerDay}',
              defaultLabel: '${defaults.adDoublesPerDay}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(adDoublesPerDay: v.round()),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lang.t('admin_economy_start_note'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () =>
                          AppEconomyConfigService.instance.resetToDefaults(),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(lang.t('admin_economy_reset')),
                  style: TextButton.styleFrom(foregroundColor: _accent),
                ),
                const Spacer(),
                if (saving)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.t('admin_tune_saving'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  onPressed: (saving || !dirty)
                      ? null
                      : () => AppEconomyConfigService.instance.save(),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(lang.t('admin_economy_save')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF04140C),
                    disabledBackgroundColor: _accent.withValues(alpha: 0.25),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.45),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RoomRewardBlock extends StatelessWidget {
  const _RoomRewardBlock({
    required this.title,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.d1,
    required this.d2,
    required this.d3,
    required this.enabled,
    required this.onR1,
    required this.onR2,
    required this.onR3,
  });

  final String title;
  final int r1;
  final int r2;
  final int r3;
  final int d1;
  final int d2;
  final int d3;
  final bool enabled;
  final ValueChanged<int> onR1;
  final ValueChanged<int> onR2;
  final ValueChanged<int> onR3;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF7CFFB2),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_place_1'),
              value: r1.toDouble(),
              min: 0,
              max: 40,
              display: '+$r1',
              defaultLabel: '+$d1',
              enabled: enabled,
              onChanged: (v) => onR1(v.round()),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_place_2'),
              value: r2.toDouble(),
              min: 0,
              max: 40,
              display: '+$r2',
              defaultLabel: '+$d2',
              enabled: enabled,
              onChanged: (v) => onR2(v.round()),
            ),
            _EcoSlider(
              label: lang.t('admin_economy_place_3'),
              value: r3.toDouble(),
              min: 0,
              max: 40,
              display: '+$r3',
              defaultLabel: '+$d3',
              enabled: enabled,
              onChanged: (v) => onR3(v.round()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _EcoSlider extends StatelessWidget {
  const _EcoSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.defaultLabel,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final String defaultLabel;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: Color(0xFF7CFFB2),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($defaultLabel)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF7CFFB2),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: const Color(0xFF7CFFB2),
              overlayColor: const Color(0xFF7CFFB2).withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round().clamp(1, 500),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
