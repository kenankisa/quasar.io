import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/app_rank_config_service.dart';
import '../services/lang_service.dart';

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'How to Play',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const HowToPlayDialog();
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

  String _rankSystemDesc(LanguageService lang) {
    final cfg = AppRankConfigService.instance.config;
    return lang
        .t('how_to_play_ranks_desc')
        .replaceAll('{normal}', '${cfg.winPointsNormal}')
        .replaceAll('{elite}', '${cfg.winPointsElite}')
        .replaceAll('{unique}', '${cfg.winPointsUnique}')
        .replaceAll('{stellar}', '${cfg.minPointsStellar}')
        .replaceAll('{nova}', '${cfg.minPointsNova}')
        .replaceAll('{quasar}', '${cfg.minPointsQuasar}')
        .replaceAll('{singularity}', '${cfg.minPointsSingularity}');
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final size = MediaQuery.sizeOf(context);

    final sections = [
      _HowToSection(
        icon: Icons.touch_app,
        titleKey: 'how_to_play_move_title',
        descKey: 'how_to_play_move_desc',
        color: const Color(0xFF00F0FF),
      ),
      _HowToSection(
        icon: Icons.all_inclusive,
        titleKey: 'how_to_play_absorb_title',
        descKey: 'how_to_play_absorb_desc',
        color: const Color(0xFFFF00AA),
      ),
      _HowToSection(
        icon: Icons.rocket_launch,
        titleKey: 'how_to_play_boost_title',
        descKey: 'how_to_play_boost_desc',
        color: const Color(0xFFFF6600),
      ),
      _HowToSection(
        icon: Icons.link,
        titleKey: 'how_to_play_link_title',
        descKey: 'how_to_play_link_desc',
        color: const Color(0xFF7B2FFF),
      ),
      _HowToSection(
        icon: Icons.shield_outlined,
        titleKey: 'how_to_play_shield_title',
        descKey: 'how_to_play_shield_desc',
        color: const Color(0xFF44FF88),
      ),
      _HowToSection(
        icon: Icons.emoji_events,
        titleKey: 'how_to_play_victory_title',
        descKey: 'how_to_play_victory_desc',
        color: const Color(0xFFFFAA00),
      ),
      _HowToSection(
        icon: Icons.military_tech_outlined,
        titleKey: 'how_to_play_ranks_title',
        descKey: 'how_to_play_ranks_desc',
        color: const Color(0xFFFFD54F),
        descriptionOverride: _rankSystemDesc(lang),
      ),
      _HowToSection(
        icon: Icons.diamond_outlined,
        titleKey: 'how_to_play_currencies_title',
        descKey: 'how_to_play_currencies_desc',
        color: const Color(0xFF00F0FF),
      ),
      _HowToSection(
        icon: Icons.bolt,
        titleKey: 'how_to_play_events_title',
        descKey: 'how_to_play_events_desc',
        color: const Color(0xFFFF0044),
      ),
    ];

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
              color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
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
                          Icons.help_outline,
                          color: Color(0xFF00F0FF),
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lang.t('how_to_play_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: sections.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return _HowToCard(
                          icon: section.icon,
                          title: lang.t(section.titleKey),
                          description: section.descriptionOverride ??
                              lang.t(section.descKey),
                          accentColor: section.color,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00F0FF),
                          foregroundColor: const Color(0xFF0A0A1A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(lang.t('how_to_play_close')),
                      ),
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

class _HowToSection {
  const _HowToSection({
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.color,
    this.descriptionOverride,
  });

  final IconData icon;
  final String titleKey;
  final String descKey;
  final Color color;
  final String? descriptionOverride;
}

class _HowToCard extends StatelessWidget {
  const _HowToCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.1),
            const Color(0xFF0A0A1A).withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.45,
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
