import 'package:flutter/material.dart';

import '../config/app_version.dart';
import '../game/models/match_speech.dart';
import '../services/audio_service.dart';
import '../services/lang_service.dart';
import '../services/settings_service.dart';
import 'cosmic_dialog.dart';
import 'version_notes_dialog.dart';

/// Unified settings hub: language, audio, display, match, about.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return CosmicDialog.show(
      context: context,
      barrierLabel: 'Settings',
      child: const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _settings = SettingsService.instance;
  final _lang = LanguageService.instance;

  static const _accent = Color(0xFF00F0FF);
  static const _card = Color(0xFF12161F);

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
    _lang.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    _lang.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setMusic(bool enabled) async {
    await _settings.setMusicEnabled(enabled);
    if (enabled) {
      await AudioService.instance.playAmbient();
    } else {
      await AudioService.instance.pauseAmbient();
    }
  }

  String _presetLabel(MatchReactionPreset preset) {
    final text = _lang.t(preset.labelKey);
    return text == preset.labelKey ? preset.fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    return CosmicDialogPanel(
      icon: Icons.tune_rounded,
      title: _lang.t('settings_title'),
      maxWidth: 440,
      children: [
        _SectionCard(
          icon: Icons.language_rounded,
          title: _lang.t('settings_language_section'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in LanguageService.supportedLanguages)
                _LanguageChip(
                  code: code,
                  label: LanguageService.languageLabels[code] ?? code,
                  selected: _lang.currentLanguage == code,
                  onTap: () => _lang.setLanguage(code),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.volume_up_rounded,
          title: _lang.t('settings_audio_section'),
          child: Column(
            children: [
              _SwitchRow(
                title: _lang.t('settings_music'),
                subtitle: _lang.t('settings_music_desc'),
                value: _settings.musicEnabled,
                onChanged: _setMusic,
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _settings.musicEnabled ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !_settings.musicEnabled,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.volume_down_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _accent,
                              inactiveTrackColor:
                                  _accent.withValues(alpha: 0.18),
                              thumbColor: _accent,
                              overlayColor: _accent.withValues(alpha: 0.12),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _settings.musicVolume,
                              onChanged: _settings.setMusicVolume,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${(_settings.musicVolume * 100).round()}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const _SectionDivider(),
              _SwitchRow(
                title: _lang.t('settings_haptics'),
                subtitle: _lang.t('settings_haptics_desc'),
                value: _settings.hapticsEnabled,
                onChanged: _settings.setHapticsEnabled,
              ),
              if (!AudioService.instance.assetReady) ...[
                const SizedBox(height: 8),
                Text(
                  _lang.t('settings_audio_missing'),
                  style: TextStyle(
                    color: const Color(0xFFFF8844).withValues(alpha: 0.95),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.visibility_rounded,
          title: _lang.t('settings_display_section'),
          child: Column(
            children: [
              _SwitchRow(
                title: _lang.t('settings_show_own_name'),
                subtitle: _lang.t('settings_show_own_name_desc'),
                value: _settings.showOwnName,
                onChanged: _settings.setShowOwnName,
              ),
              const _SectionDivider(),
              _SwitchRow(
                title: _lang.t('settings_show_other_names'),
                subtitle: _lang.t('settings_show_other_names_desc'),
                value: _settings.showOtherNames,
                onChanged: _settings.setShowOtherNames,
              ),
              const _SectionDivider(),
              _SwitchRow(
                title: _lang.t('settings_show_profile_pictures'),
                subtitle: _lang.t('settings_show_profile_pictures_desc'),
                value: _settings.showProfilePictures,
                onChanged: _settings.setShowProfilePictures,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.sports_esports_rounded,
          title: _lang.t('settings_match_section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SwitchRow(
                title: _lang.t('settings_show_kill_feed'),
                subtitle: _lang.t('settings_show_kill_feed_desc'),
                value: _settings.showKillFeed,
                onChanged: _settings.setShowKillFeed,
              ),
              const _SectionDivider(),
              Text(
                _lang.t('settings_absorb_bubble'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _lang.t('settings_absorb_bubble_desc'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in kAbsorbBubbleChoices)
                    _AbsorbChoiceChip(
                      label: _presetLabel(preset),
                      selected:
                          _settings.absorbBubblePresetId == preset.id,
                      onTap: () =>
                          _settings.setAbsorbBubblePresetId(preset.id),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _lang.t('version_current').replaceAll('{version}', AppVersion.display),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              VersionNotesDialog.show(context);
            },
            icon: Icon(
              Icons.new_releases_outlined,
              size: 17,
              color: _accent.withValues(alpha: 0.9),
            ),
            label: Text(
              _lang.t('version_notes_title'),
              style: TextStyle(
                color: _accent.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _SettingsDialogState._card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: _SettingsDialogState._accent),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          activeTrackColor:
              _SettingsDialogState._accent.withValues(alpha: 0.45),
          activeThumbColor: _SettingsDialogState._accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _SettingsDialogState._accent.withValues(alpha: 0.18)
          : const Color(0xFF0A0E16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _SettingsDialogState._accent
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? _SettingsDialogState._accent
                  : Colors.white.withValues(alpha: 0.78),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _AbsorbChoiceChip extends StatelessWidget {
  const _AbsorbChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0x33FFC14D)
          : const Color(0xFF0A0E16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFC14D)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFFFE6A8)
                  : Colors.white.withValues(alpha: 0.78),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
