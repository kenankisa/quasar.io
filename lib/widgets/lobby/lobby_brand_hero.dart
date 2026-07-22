import 'package:flutter/material.dart';

import '../../services/lang_service.dart';
import '../../utils/responsive_layout.dart';

class LobbyBrandHero extends StatelessWidget {
  const LobbyBrandHero({
    super.key,
    required this.glowAnimation,
    required this.freeSp,
    required this.onVersionTap,
    required this.onHowToPlayTap,
    required this.onSkillsTap,
    this.onTitleLongPress,
  });

  final Animation<double> glowAnimation;
  final int freeSp;
  final VoidCallback onVersionTap;
  final VoidCallback onHowToPlayTap;
  final VoidCallback onSkillsTap;
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final r = ResponsiveLayout.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.w(20)),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: glowAnimation,
            builder: (context, _) {
              final pulse = 0.45 + glowAnimation.value * 0.55;
              final title = Column(
                children: [
                  Text(
                    lang.t('lobby_brand_eyebrow').toUpperCase(),
                    style: TextStyle(
                      color: const Color(0xFF7B2FFF).withValues(alpha: 0.9),
                      fontSize: r.sp(10),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.2,
                    ),
                  ),
                  SizedBox(height: r.h(8)),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Quasar',
                          style: TextStyle(
                            fontSize: r.sp(40),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            height: 1,
                            color: const Color(0xFF00F0FF),
                            shadows: [
                              Shadow(
                                color: const Color(0xFF00F0FF)
                                    .withValues(alpha: pulse * 0.85),
                                blurRadius: 28,
                              ),
                              Shadow(
                                color: const Color(0xFFFF00AA)
                                    .withValues(alpha: pulse * 0.35),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: '.io',
                          style: TextStyle(
                            fontSize: r.sp(40),
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                            height: 1,
                            color: const Color(0xFFFF2D95),
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFF2D95)
                                    .withValues(alpha: pulse * 0.7),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(10)),
                  Container(
                    width: r.w(72),
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00F0FF).withValues(alpha: 0),
                          Color.lerp(
                            const Color(0xFF00F0FF),
                            const Color(0xFFFF00AA),
                            glowAnimation.value,
                          )!,
                          const Color(0xFFFF00AA).withValues(alpha: 0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF)
                              .withValues(alpha: pulse * 0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.h(12)),
                  Text(
                    lang.t('welcome_cosmic'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: r.sp(14),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.6,
                      height: 1.35,
                    ),
                  ),
                ],
              );

              if (onTitleLongPress == null) return title;
              return GestureDetector(
                onLongPress: onTitleLongPress,
                child: title,
              );
            },
          ),
          SizedBox(height: r.h(18)),
          Container(
            padding: EdgeInsets.all(r.w(6)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: LobbyDiscoveryButton(
                    icon: Icons.radar_rounded,
                    label: lang.t('lobby_how_to_play'),
                    accent: const Color(0xFF00F0FF),
                    onTap: onHowToPlayTap,
                  ),
                ),
                SizedBox(width: r.w(6)),
                Expanded(
                  child: LobbyDiscoveryButton(
                    icon: Icons.auto_awesome_rounded,
                    label: lang.t('lobby_skill_tree'),
                    accent: const Color(0xFFFF2D95),
                    badge: freeSp > 0 ? '$freeSp' : null,
                    onTap: onSkillsTap,
                  ),
                ),
                SizedBox(width: r.w(6)),
                Expanded(
                  child: LobbyDiscoveryButton(
                    icon: Icons.satellite_alt_rounded,
                    label: lang.t('lobby_version_notes'),
                    accent: const Color(0xFF9B6BFF),
                    tooltip: lang.t('lobby_version_notes_hint'),
                    onTap: onVersionTap,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(10)),
          Text(
            lang.t('lobby_choose_universe').toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: r.sp(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
        ],
      ),
    );
  }
}

class LobbyDiscoveryButton extends StatelessWidget {
  const LobbyDiscoveryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.badge,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.14),
                accent.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.w(8),
              vertical: r.h(11),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: accent, size: r.sp(20)),
                    if (badge != null)
                      Positioned(
                        right: -10,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: accent,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: const Color(0xFF0A0512),
                              fontSize: r.sp(9),
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: r.h(6)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
