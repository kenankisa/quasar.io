import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_version.dart';
import '../services/lang_service.dart';

class VersionNotesDialog extends StatefulWidget {
  const VersionNotesDialog({
    super.key,
    this.showDontShowAgain = false,
  });

  /// Lobide otomatik açılışta "bir daha gösterme" kutusu görünür.
  final bool showDontShowAgain;

  static const _hiddenVersionKey = 'quasar_whats_new_hidden_version';
  static bool _autoShownThisSession = false;

  static const _v21ChangeKeys = [
    'v21_change_rank_points',
    'v21_change_training_excluded',
    'v21_change_tutorial_lock',
    'v21_change_leaderboard_wins',
    'v21_change_rank_dialog',
    'v21_change_lobby_chat',
    'v21_change_broadcast',
    'v21_change_live_announce',
    'v21_change_idle',
    'v21_change_menus',
    'v21_change_version_notes',
  ];

  static const _v20ChangeKeys = [
    'v20_change_room_capacity',
    'v20_change_ghost_cleanup',
    'v20_change_seat_free',
    'v20_change_match_rewards',
    'v20_change_cosmic_sync',
    'v20_change_real_matchmaking',
    'v20_change_smarter_bots',
    'v20_change_leaderboard_100',
    'v20_change_unique_theme',
    'v20_change_version_notes',
  ];

  static const _v19ChangeKeys = [
    'v19_change_skill_tree',
    'v19_change_boost_upgrades',
    'v19_change_teleport',
    'v19_change_shield',
    'v19_change_shockwave',
    'v19_change_messages',
    'v19_change_idle_protect',
    'v19_change_economy_security',
    'v19_change_version_notes',
  ];

  static const _v18ChangeKeys = [
    'v18_change_blackhole_shader',
    'v18_change_swallow_visuals',
    'v18_change_merger_rework',
    'v18_change_merger_ripples',
    'v18_change_space_background',
    'v18_change_web_performance',
    'v18_change_meteor_perf',
    'v18_change_mobile_fixes',
    'v18_change_big_hole_clarity',
    'v18_change_match_pacing',
    'v18_change_smarter_bots',
    'v18_change_supernova_events',
    'v18_change_event_warnings',
    'v18_change_leader_threshold',
    'v18_change_empty_close',
    'v18_change_avatar_hud_only',
    'v18_change_rewarded_ads',
    'v18_change_version_notes',
  ];

  static const _v17ChangeKeys = [
    'v17_change_match_rewards',
    'v17_change_diamond_gates',
    'v17_change_profile_hub',
    'v17_change_edit_profile',
    'v17_change_ingame_avatars',
    'v17_change_cosmetic_store',
    'v17_change_global_leaderboard',
    'v17_change_single_session',
    'v17_change_live_lobby_stats',
    'v17_change_onboarding',
    'v17_change_native_splash',
    'v17_change_hud_podium_rewards',
    'v17_change_swallow_vfx',
    'v17_change_victory_form',
    'v17_change_login_form',
    'v17_change_hud_loading',
    'v17_change_version_notes',
  ];

  static const _v16ChangeKeys = [
    'v16_change_server_matchmaking',
    'v16_change_universe_instances',
    'v16_change_leader_radius_split',
    'v16_change_room_lifecycle',
    'v16_change_abandoned_universe',
    'v16_change_black_hole_graphics',
    'v16_change_star_lensing',
    'v16_change_swallow_animations',
    'v16_change_food_spaghettify',
    'v16_change_gravity_physics',
    'v16_change_universe_tiers',
    'v16_change_cosmic_events',
    'v16_change_hole_merger',
    'v16_change_random_spawn',
    'v16_change_revive_spawn',
    'v16_change_prey_bot_spawn',
    'v16_change_spawn_spacing',
    'v16_change_version_notes',
  ];

  static Future<bool> shouldAutoShow() async {
    if (_autoShownThisSession) return false;
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getString(_hiddenVersionKey);
    return hidden != AppVersion.current;
  }

  static Future<void> markHiddenForCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hiddenVersionKey, AppVersion.current);
  }

  /// Manuel açılış (ayarlar / lobi butonu).
  static Future<void> show(BuildContext context) {
    return _present(context, showDontShowAgain: false);
  }

  /// Lobide yeni sürüm karşılaşma ekranı.
  static Future<void> showAutoIfNeeded(BuildContext context) async {
    if (!context.mounted) return;
    if (!await shouldAutoShow()) return;
    if (!context.mounted) return;
    _autoShownThisSession = true;
    await _present(context, showDontShowAgain: true);
  }

  static Future<void> _present(
    BuildContext context, {
    required bool showDontShowAgain,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: !showDontShowAgain,
      barrierLabel: 'Version Notes',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return VersionNotesDialog(showDontShowAgain: showDontShowAgain);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<VersionNotesDialog> createState() => _VersionNotesDialogState();
}

class _VersionNotesDialogState extends State<VersionNotesDialog> {
  bool _dontShowAgain = false;

  Future<void> _close() async {
    if (widget.showDontShowAgain && _dontShowAgain) {
      await VersionNotesDialog.markHiddenForCurrentVersion();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.78,
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF12122A).withValues(alpha: 0.95),
                const Color(0xFF0A0A1A).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF7B2FFF).withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2FFF).withValues(alpha: 0.12),
                blurRadius: 30,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.new_releases_outlined,
                          color: Color(0xFF7B2FFF),
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.t('version_notes_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lang
                                    .t('version_current')
                                    .replaceAll('{version}', AppVersion.display),
                                style: TextStyle(
                                  color: const Color(0xFF7B2FFF)
                                      .withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: _close,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      children: [
                        _VersionHeader(
                          title: lang.t('v21_section_title'),
                          subtitle: lang.t('v21_section_subtitle'),
                        ),
                        const SizedBox(height: 12),
                        ...VersionNotesDialog._v21ChangeKeys.map(
                          (key) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChangeItem(text: lang.t(key)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _VersionHeader(
                          title: lang.t('v20_section_title'),
                          subtitle: lang.t('v20_section_subtitle'),
                          dimmed: true,
                        ),
                        const SizedBox(height: 12),
                        ...VersionNotesDialog._v20ChangeKeys.map(
                          (key) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChangeItem(
                              text: lang.t(key),
                              dimmed: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _VersionHeader(
                          title: lang.t('v19_section_title'),
                          subtitle: lang.t('v19_section_subtitle'),
                          dimmed: true,
                        ),
                        const SizedBox(height: 12),
                        ...VersionNotesDialog._v19ChangeKeys.map(
                          (key) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChangeItem(
                              text: lang.t(key),
                              dimmed: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _VersionHeader(
                          title: lang.t('v18_section_title'),
                          subtitle: lang.t('v18_section_subtitle'),
                          dimmed: true,
                        ),
                        const SizedBox(height: 12),
                        ...VersionNotesDialog._v18ChangeKeys.map(
                          (key) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChangeItem(
                              text: lang.t(key),
                              dimmed: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _VersionHeader(
                          title: lang.t('v17_section_title'),
                          subtitle: lang.t('v17_section_subtitle'),
                          dimmed: true,
                        ),
                        const SizedBox(height: 12),
                        ...VersionNotesDialog._v17ChangeKeys.map(
                          (key) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChangeItem(
                              text: lang.t(key),
                              dimmed: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _VersionHeader(
                          title: lang.t('v16_section_title'),
                          subtitle: lang.t('v16_section_subtitle'),
                          dimmed: true,
                        ),
                        const SizedBox(height: 12),
                        ...VersionNotesDialog._v16ChangeKeys.map(
                          (key) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChangeItem(
                              text: lang.t(key),
                              dimmed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        if (widget.showDontShowAgain) ...[
                          InkWell(
                            onTap: () => setState(
                              () => _dontShowAgain = !_dontShowAgain,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _dontShowAgain,
                                      onChanged: (v) => setState(
                                        () => _dontShowAgain = v ?? false,
                                      ),
                                      activeColor: const Color(0xFF7B2FFF),
                                      checkColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      lang.t('version_notes_dont_show'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.72,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _close,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7B2FFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(lang.t('version_notes_close')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionHeader extends StatelessWidget {
  const _VersionHeader({
    required this.title,
    required this.subtitle,
    this.dimmed = false,
  });

  final String title;
  final String subtitle;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final accent = dimmed
        ? const Color(0xFF7B2FFF).withValues(alpha: 0.55)
        : const Color(0xFF7B2FFF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: dimmed ? 0.1 : 0.18),
            const Color(0xFF0A0A1A).withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: dimmed ? 0.2 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: dimmed ? 0.55 : 0.75),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeItem extends StatelessWidget {
  const _ChangeItem({
    required this.text,
    this.dimmed = false,
  });

  final String text;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline,
            size: 18,
            color: const Color(0xFF00F0FF).withValues(alpha: dimmed ? 0.5 : 0.85),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: dimmed ? 0.55 : 0.82),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
