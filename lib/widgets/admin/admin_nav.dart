import 'package:flutter/material.dart';

import '../../services/lang_service.dart';

enum AdminNavSection {
  live,
  analytics,
  universes,
  idle,
  ranks,
  players,
  loadTest,
  messages;

  String get labelKey => switch (this) {
        AdminNavSection.live => 'admin_nav_live',
        AdminNavSection.analytics => 'admin_nav_analytics',
        AdminNavSection.universes => 'admin_nav_universes',
        AdminNavSection.idle => 'admin_nav_idle',
        AdminNavSection.ranks => 'admin_nav_ranks',
        AdminNavSection.players => 'admin_nav_players',
        AdminNavSection.loadTest => 'admin_nav_load_test',
        AdminNavSection.messages => 'admin_nav_messages',
      };

  String get titleKey => switch (this) {
        AdminNavSection.live => 'admin_page_live_title',
        AdminNavSection.analytics => 'admin_page_analytics_title',
        AdminNavSection.universes => 'admin_page_universes_title',
        AdminNavSection.idle => 'admin_page_idle_title',
        AdminNavSection.ranks => 'admin_page_ranks_title',
        AdminNavSection.players => 'admin_page_players_title',
        AdminNavSection.loadTest => 'admin_page_load_test_title',
        AdminNavSection.messages => 'admin_page_messages_title',
      };

  String get descKey => switch (this) {
        AdminNavSection.live => 'admin_page_live_desc',
        AdminNavSection.analytics => 'admin_page_analytics_desc',
        AdminNavSection.universes => 'admin_page_universes_desc',
        AdminNavSection.idle => 'admin_page_idle_desc',
        AdminNavSection.ranks => 'admin_page_ranks_desc',
        AdminNavSection.players => 'admin_page_players_desc',
        AdminNavSection.loadTest => 'admin_page_load_test_desc',
        AdminNavSection.messages => 'admin_page_messages_desc',
      };

  IconData get icon => switch (this) {
        AdminNavSection.live => Icons.sensors_rounded,
        AdminNavSection.analytics => Icons.insights_rounded,
        AdminNavSection.universes => Icons.tune_rounded,
        AdminNavSection.idle => Icons.timer_off_rounded,
        AdminNavSection.ranks => Icons.military_tech_rounded,
        AdminNavSection.players => Icons.groups_rounded,
        AdminNavSection.loadTest => Icons.science_rounded,
        AdminNavSection.messages => Icons.mail_outline_rounded,
      };
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00F0FF),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class AdminSideNav extends StatelessWidget {
  const AdminSideNav({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.livePlayers,
    required this.activeSessions,
    this.unreadMessages = 0,
  });

  final AdminNavSection selected;
  final ValueChanged<AdminNavSection> onSelected;
  final int livePlayers;
  final int activeSessions;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Container(
      width: 220,
      margin: const EdgeInsets.fromLTRB(12, 0, 0, 12),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        color: const Color(0xFF0A0A1A).withValues(alpha: 0.88),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('admin_title'),
            style: const TextStyle(
              color: Color(0xFF00F0FF),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.t('admin_menu'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 18),
          for (final section in AdminNavSection.values) ...[
            _SideNavItem(
              section: section,
              selected: selected == section,
              badge: section == AdminNavSection.live && livePlayers > 0
                  ? '$livePlayers'
                  : section == AdminNavSection.live && activeSessions > 0
                      ? '$activeSessions'
                      : section == AdminNavSection.messages &&
                              unreadMessages > 0
                          ? '$unreadMessages'
                          : null,
              onTap: () => onSelected(section),
            ),
            const SizedBox(height: 6),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF22FFAA).withValues(alpha: 0.25),
              ),
              color: const Color(0xFF22FFAA).withValues(alpha: 0.06),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('admin_active_sessions'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeSessions',
                  style: const TextStyle(
                    color: Color(0xFF22FFAA),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
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

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.section,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final AdminNavSection section;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final accent = const Color(0xFF00F0FF);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                section.icon,
                size: 18,
                color: selected
                    ? accent
                    : Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.t(section.labelKey),
                  style: TextStyle(
                    color: selected
                        ? accent
                        : Colors.white.withValues(alpha: 0.72),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: accent.withValues(alpha: 0.18),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.unreadMessages = 0,
  });

  final AdminNavSection selected;
  final ValueChanged<AdminNavSection> onSelected;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        color: const Color(0xFF06060F).withValues(alpha: 0.96),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          for (final section in AdminNavSection.values)
            Expanded(
              child: _BottomNavItem(
                label: lang.t(section.labelKey),
                icon: section.icon,
                selected: selected == section,
                badge: section == AdminNavSection.messages &&
                        unreadMessages > 0
                    ? '$unreadMessages'
                    : null,
                onTap: () => onSelected(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF00F0FF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? accent : Colors.white.withValues(alpha: 0.4),
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4466),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? accent : Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    super.key,
    required this.email,
    required this.signingOut,
    required this.section,
    required this.onRefresh,
    required this.onLobby,
    required this.onSignOut,
  });

  final String email;
  final bool signingOut;
  final AdminNavSection section;
  final VoidCallback onRefresh;
  final VoidCallback onLobby;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF22FFAA).withValues(alpha: 0.55),
              ),
              color: const Color(0xFF22FFAA).withValues(alpha: 0.1),
            ),
            child: Text(
              lang.t('admin_badge'),
              style: const TextStyle(
                color: Color(0xFF22FFAA),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            section.icon,
            size: 16,
            color: const Color(0xFF00F0FF).withValues(alpha: 0.85),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t(section.labelKey),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: lang.t('admin_refresh'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00F0FF)),
          ),
          TextButton(
            onPressed: onLobby,
            child: Text(
              lang.t('admin_enter_lobby'),
              style: const TextStyle(
                color: Color(0xFF00F0FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: lang.t('sign_out'),
            onPressed: signingOut ? null : onSignOut,
            icon: signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : const Icon(Icons.logout_rounded, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
