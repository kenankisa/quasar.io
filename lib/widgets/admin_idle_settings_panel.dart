import 'package:flutter/material.dart';

import '../game/models/app_idle_config.dart';
import '../services/app_idle_config_service.dart';
import '../services/lang_service.dart';

/// Yönetici: lobi + maç AFK süreleri ve kütle cezası.
class AdminIdleSettingsPanel extends StatelessWidget {
  const AdminIdleSettingsPanel({super.key});

  static const _accent = Color(0xFFFF6688);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppIdleConfigService.instance,
      builder: (context, _) {
        final service = AppIdleConfigService.instance;
        final config = service.config;
        final defaults = AppIdleConfig.defaults;
        final lang = LanguageService.instance;
        final saving = service.saving;
        final dirty = service.hasUnsavedChanges;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.t('admin_idle_intro'),
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
            _SectionTitle(lang.t('admin_idle_lobby_section'), _accent),
            const SizedBox(height: 8),
            _IdleSlider(
              label: lang.t('admin_idle_lobby_before_warning'),
              value: config.lobbyIdleBeforeWarningSeconds.toDouble(),
              min: 5,
              max: 180,
              display: '${config.lobbyIdleBeforeWarningSeconds}s',
              defaultLabel: '${defaults.lobbyIdleBeforeWarningSeconds}s',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(lobbyIdleBeforeWarningSeconds: v.round()),
              ),
            ),
            _IdleSlider(
              label: lang.t('admin_idle_lobby_countdown'),
              value: config.lobbyWarningCountdownSeconds.toDouble(),
              min: 5,
              max: 60,
              display: '${config.lobbyWarningCountdownSeconds}s',
              defaultLabel: '${defaults.lobbyWarningCountdownSeconds}s',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(lobbyWarningCountdownSeconds: v.round()),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(lang.t('admin_idle_match_section'), _accent),
            const SizedBox(height: 8),
            _IdleSlider(
              label: lang.t('admin_idle_match_before_warning'),
              value: config.matchIdleBeforeWarningSeconds.toDouble(),
              min: 3,
              max: 60,
              display: '${config.matchIdleBeforeWarningSeconds}s',
              defaultLabel: '${defaults.matchIdleBeforeWarningSeconds}s',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(matchIdleBeforeWarningSeconds: v.round()),
              ),
            ),
            _IdleSlider(
              label: lang.t('admin_idle_match_countdown'),
              value: config.matchWarningCountdownSeconds.toDouble(),
              min: 1,
              max: 15,
              display: '${config.matchWarningCountdownSeconds}s',
              defaultLabel: '${defaults.matchWarningCountdownSeconds}s',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(matchWarningCountdownSeconds: v.round()),
              ),
            ),
            _IdleSlider(
              label: lang.t('admin_idle_match_mass_drain'),
              value: config.matchMassDrainPerSecond.toDouble(),
              min: 1,
              max: 50,
              display: '-${config.matchMassDrainPerSecond}/s',
              defaultLabel: '-${defaults.matchMassDrainPerSecond}/s',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(matchMassDrainPerSecond: v.round()),
              ),
            ),
            _IdleSlider(
              label: lang.t('admin_idle_match_kick_mass'),
              value: config.matchKickMassThreshold.toDouble(),
              min: 8,
              max: 100,
              display: '${config.matchKickMassThreshold}',
              defaultLabel: '${defaults.matchKickMassThreshold}',
              enabled: !saving,
              onChanged: (v) => service.updateConfig(
                (c) => c.copyWith(matchKickMassThreshold: v.round()),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton.icon(
                  onPressed: saving
                      ? null
                      : () => AppIdleConfigService.instance.resetToDefaults(),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(lang.t('admin_idle_reset')),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                  ),
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
                      : () => AppIdleConfigService.instance.save(),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(lang.t('admin_idle_save')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _accent.withValues(alpha: 0.25),
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
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _IdleSlider extends StatelessWidget {
  const _IdleSlider({
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
    final lang = LanguageService.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: enabled ? 0.72 : 0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                lang
                    .t('admin_tune_default')
                    .replaceAll('{value}', defaultLabel),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AdminIdleSettingsPanel._accent.withValues(alpha: 0.15),
                ),
                child: Text(
                  display,
                  style: const TextStyle(
                    color: AdminIdleSettingsPanel._accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AdminIdleSettingsPanel._accent,
              inactiveTrackColor:
                  AdminIdleSettingsPanel._accent.withValues(alpha: 0.2),
              thumbColor: AdminIdleSettingsPanel._accent,
              overlayColor:
                  AdminIdleSettingsPanel._accent.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
