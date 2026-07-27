import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../utils/responsive_layout.dart';

/// Overflow menu for lobby discovery links and account actions.
class LobbyMenuSheet {
  LobbyMenuSheet._();

  static Future<void> show(
    BuildContext context, {
    required int freeSkillPoints,
    required bool showAdminPanel,
    required bool signingOut,
    required VoidCallback onHowToPlay,
    required VoidCallback onSkills,
    required VoidCallback onVersionNotes,
    required VoidCallback? onAdminPanel,
    required VoidCallback onSignOut,
  }) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF0A0A1A).withValues(alpha: 0.98),
              border: Border.all(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang.t('lobby_menu_more'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: r.sp(16),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                _MenuTile(
                  icon: Icons.radar_rounded,
                  label: lang.t('lobby_how_to_play'),
                  accent: const Color(0xFF00F0FF),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onHowToPlay();
                  },
                ),
                _MenuTile(
                  icon: Icons.auto_awesome_rounded,
                  label: lang.t('lobby_skill_tree'),
                  accent: const Color(0xFFFF2D95),
                  badge: freeSkillPoints > 0 ? '$freeSkillPoints' : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onSkills();
                  },
                ),
                _MenuTile(
                  icon: Icons.satellite_alt_rounded,
                  label: lang.t('lobby_version_notes'),
                  subtitle: lang.t('lobby_version_notes_hint'),
                  accent: const Color(0xFF9B6BFF),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onVersionNotes();
                  },
                ),
                if (showAdminPanel && onAdminPanel != null)
                  _MenuTile(
                    icon: Icons.space_dashboard_outlined,
                    label: lang.t('admin_open_panel'),
                    accent: const Color(0xFF22FFAA),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onAdminPanel();
                    },
                  ),
                _MenuTile(
                  icon: Icons.logout_rounded,
                  label: lang.t('sign_out'),
                  accent: const Color(0xFFFF6688),
                  loading: signingOut,
                  onTap: signingOut
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          onSignOut();
                        },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accent;
  final String? badge;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: r.sp(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: r.sp(11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent.withValues(alpha: 0.8),
                  ),
                )
              else if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: accent,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Color(0xFF0A0512),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
