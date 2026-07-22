import 'package:flutter/material.dart';

import '../game/models/app_rank_config.dart';
import '../services/app_rank_config_service.dart';
import '../services/lang_service.dart';
import '../utils/player_rank.dart';
import 'bot_name_badge.dart';

/// Yönetici: galibiyet puanı çarpanları + rütbe eşikleri.
class AdminRankSettingsPanel extends StatelessWidget {
  const AdminRankSettingsPanel({super.key});

  static const _accent = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppRankConfigService.instance,
      builder: (context, _) {
        final service = AppRankConfigService.instance;
        final config = service.config;
        final defaults = AppRankConfig.defaults;
        final lang = LanguageService.instance;
        final saving = service.saving;
        final dirty = service.hasUnsavedChanges;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.t('admin_rank_intro'),
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
            _SectionTitle(lang.t('admin_rank_win_points_section'), _accent),
            const SizedBox(height: 8),
            _RankSlider(
              label: lang.t('admin_rank_points_simple'),
              value: config.winPointsSimple.toDouble(),
              min: 0,
              max: 10,
              display: '${config.winPointsSimple}',
              defaultLabel: '${defaults.winPointsSimple}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(winPointsSimple: v.round()),
              ),
            ),
            _RankSlider(
              label: lang.t('admin_rank_points_normal'),
              value: config.winPointsNormal.toDouble(),
              min: 0,
              max: 10,
              display: '${config.winPointsNormal}',
              defaultLabel: '${defaults.winPointsNormal}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(winPointsNormal: v.round()),
              ),
            ),
            _RankSlider(
              label: lang.t('admin_rank_points_elite'),
              value: config.winPointsElite.toDouble(),
              min: 0,
              max: 15,
              display: '${config.winPointsElite}',
              defaultLabel: '${defaults.winPointsElite}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(winPointsElite: v.round()),
              ),
            ),
            _RankSlider(
              label: lang.t('admin_rank_points_unique'),
              value: config.winPointsUnique.toDouble(),
              min: 0,
              max: 20,
              display: '${config.winPointsUnique}',
              defaultLabel: '${defaults.winPointsUnique}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(winPointsUnique: v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(lang.t('admin_rank_thresholds_section'), _accent),
            const SizedBox(height: 8),
            Text(
              lang.t('admin_rank_nebula_note'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _RankSlider(
              label: lang.t('rank_tier_stellar'),
              value: config.minPointsStellar.toDouble(),
              min: 1,
              max: 100,
              display: '${config.minPointsStellar}+',
              defaultLabel: '${defaults.minPointsStellar}+',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(minPointsStellar: v.round()),
              ),
            ),
            _RankSlider(
              label: lang.t('rank_tier_nova'),
              value: config.minPointsNova.toDouble(),
              min: 2,
              max: 200,
              display: '${config.minPointsNova}+',
              defaultLabel: '${defaults.minPointsNova}+',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(minPointsNova: v.round()),
              ),
            ),
            _RankSlider(
              label: lang.t('rank_tier_quasar'),
              value: config.minPointsQuasar.toDouble(),
              min: 3,
              max: 500,
              display: '${config.minPointsQuasar}+',
              defaultLabel: '${defaults.minPointsQuasar}+',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(minPointsQuasar: v.round()),
              ),
            ),
            _RankSlider(
              label: lang.t('rank_tier_singularity'),
              value: config.minPointsSingularity.toDouble(),
              min: 4,
              max: 1000,
              display: '${config.minPointsSingularity}+',
              defaultLabel: '${defaults.minPointsSingularity}+',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(minPointsSingularity: v.round()),
              ),
            ),
            const SizedBox(height: 12),
            _RankPreview(config: config),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () => AppRankConfigService.instance.resetToDefaults(),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(lang.t('admin_rank_reset')),
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
                      : () => AppRankConfigService.instance.save(),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(lang.t('admin_rank_save')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF1A1200),
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

class _RankPreview extends StatelessWidget {
  const _RankPreview({required this.config});

  final AppRankConfig config;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('admin_rank_preview'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final tier in playerRankTiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  PlayerRankBadge(tier: tier, size: 11, compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tier.localizedName(lang),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  Text(
                    tier.id == 'nebula'
                        ? '0'
                        : '${config.minPointsForTier(tier.id)}+',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.accent);

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: accent,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _RankSlider extends StatelessWidget {
  const _RankSlider({
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
              activeTrackColor: const Color(0xFFFFD54F),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: const Color(0xFFFFE082),
              overlayColor: const Color(0x33FFD54F),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round().clamp(1, 1000),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
