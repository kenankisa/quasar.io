import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import 'admin_theme.dart';

enum AdminNavSection {
  live,
  hardcore,
  analytics,
  messages,
  universes,
  idle,
  ranks,
  economy,
  players,
  gameTrial,
  loadTest;

  String get labelKey => switch (this) {
        AdminNavSection.live => 'admin_nav_live',
        AdminNavSection.hardcore => 'admin_nav_hardcore',
        AdminNavSection.analytics => 'admin_nav_analytics',
        AdminNavSection.messages => 'admin_nav_messages',
        AdminNavSection.universes => 'admin_nav_universes',
        AdminNavSection.idle => 'admin_nav_idle',
        AdminNavSection.ranks => 'admin_nav_ranks',
        AdminNavSection.economy => 'admin_nav_economy',
        AdminNavSection.players => 'admin_nav_players',
        AdminNavSection.gameTrial => 'admin_nav_game_trial',
        AdminNavSection.loadTest => 'admin_nav_load_test',
      };

  String get titleKey => switch (this) {
        AdminNavSection.live => 'admin_page_live_title',
        AdminNavSection.hardcore => 'admin_page_hardcore_title',
        AdminNavSection.analytics => 'admin_page_analytics_title',
        AdminNavSection.messages => 'admin_page_messages_title',
        AdminNavSection.universes => 'admin_page_universes_title',
        AdminNavSection.idle => 'admin_page_idle_title',
        AdminNavSection.ranks => 'admin_page_ranks_title',
        AdminNavSection.economy => 'admin_page_economy_title',
        AdminNavSection.players => 'admin_page_players_title',
        AdminNavSection.gameTrial => 'admin_page_game_trial_title',
        AdminNavSection.loadTest => 'admin_page_load_test_title',
      };

  String get descKey => switch (this) {
        AdminNavSection.live => 'admin_page_live_desc',
        AdminNavSection.hardcore => 'admin_page_hardcore_desc',
        AdminNavSection.analytics => 'admin_page_analytics_desc',
        AdminNavSection.messages => 'admin_page_messages_desc',
        AdminNavSection.universes => 'admin_page_universes_desc',
        AdminNavSection.idle => 'admin_page_idle_desc',
        AdminNavSection.ranks => 'admin_page_ranks_desc',
        AdminNavSection.economy => 'admin_page_economy_desc',
        AdminNavSection.players => 'admin_page_players_desc',
        AdminNavSection.gameTrial => 'admin_page_game_trial_desc',
        AdminNavSection.loadTest => 'admin_page_load_test_desc',
      };

  IconData get icon => switch (this) {
        AdminNavSection.live => Icons.sensors_rounded,
        AdminNavSection.hardcore => Icons.whatshot_rounded,
        AdminNavSection.analytics => Icons.insights_rounded,
        AdminNavSection.messages => Icons.mail_outline_rounded,
        AdminNavSection.universes => Icons.public_rounded,
        AdminNavSection.idle => Icons.timer_off_rounded,
        AdminNavSection.ranks => Icons.military_tech_rounded,
        AdminNavSection.economy => Icons.diamond_rounded,
        AdminNavSection.players => Icons.groups_rounded,
        AdminNavSection.gameTrial => Icons.sports_esports_rounded,
        AdminNavSection.loadTest => Icons.science_rounded,
      };
}

enum AdminNavGroup {
  operations,
  balance,
  tools;

  String get labelKey => switch (this) {
        AdminNavGroup.operations => 'admin_nav_group_operations',
        AdminNavGroup.balance => 'admin_nav_group_balance',
        AdminNavGroup.tools => 'admin_nav_group_tools',
      };

  List<AdminNavSection> get sections => switch (this) {
        AdminNavGroup.operations => const [
            AdminNavSection.live,
            AdminNavSection.hardcore,
            AdminNavSection.analytics,
            AdminNavSection.messages,
          ],
        AdminNavGroup.balance => const [
            AdminNavSection.universes,
            AdminNavSection.idle,
            AdminNavSection.ranks,
            AdminNavSection.economy,
          ],
        AdminNavGroup.tools => const [
            AdminNavSection.players,
            AdminNavSection.gameTrial,
            AdminNavSection.loadTest,
          ],
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
            color: AdminTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            color: AdminTheme.textSecondary,
            fontSize: 13.5,
            height: 1.4,
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
    this.hardcorePlayers = 0,
    this.unreadMessages = 0,
    this.compact = false,
  });

  final AdminNavSection selected;
  final ValueChanged<AdminNavSection> onSelected;
  final int livePlayers;
  final int activeSessions;
  final int hardcorePlayers;
  final int unreadMessages;
  final bool compact;

  String? _badgeFor(AdminNavSection section) {
    if (section == AdminNavSection.live && livePlayers > 0) {
      return '$livePlayers';
    }
    if (section == AdminNavSection.hardcore && hardcorePlayers > 0) {
      return '$hardcorePlayers';
    }
    if (section == AdminNavSection.messages && unreadMessages > 0) {
      return '$unreadMessages';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Container(
      width: compact ? 84 : AdminTheme.sideNavWidth,
      margin: const EdgeInsets.fromLTRB(12, 0, 0, 12),
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 16, compact ? 10 : 14, 14),
      decoration: AdminTheme.panel(fill: AdminTheme.surface.withValues(alpha: 0.96)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Text(
              lang.t('admin_title'),
              style: const TextStyle(
                color: AdminTheme.accent,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lang.t('admin_menu'),
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 18),
          ],
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final group in AdminNavGroup.values) ...[
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Text(
                        lang.t(group.labelKey).toUpperCase(),
                        style: const TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  for (final section in group.sections) ...[
                    _SideNavItem(
                      section: section,
                      selected: selected == section,
                      badge: _badgeFor(section),
                      compact: compact,
                      onTap: () => onSelected(section),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (!compact) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (!compact)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
                border: Border.all(
                  color: AdminTheme.accentSoft.withValues(alpha: 0.28),
                ),
                color: AdminTheme.accentSoft.withValues(alpha: 0.06),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('admin_active_sessions'),
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$activeSessions',
                    style: const TextStyle(
                      color: AdminTheme.accentSoft,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      height: 1,
                    ),
                  ),
                ],
              ),
            )
          else
            Tooltip(
              message: lang.t('admin_active_sessions'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
                  color: AdminTheme.accentSoft.withValues(alpha: 0.08),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        size: 16, color: AdminTheme.accentSoft),
                    const SizedBox(height: 4),
                    Text(
                      '$activeSessions',
                      style: const TextStyle(
                        color: AdminTheme.accentSoft,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
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
    required this.compact,
    this.badge,
  });

  final AdminNavSection section;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final accent = AdminTheme.accent;
    final label = lang.t(section.labelKey);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 12,
        vertical: compact ? 12 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.5) : Colors.transparent,
        ),
        color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
      ),
      child: compact
          ? Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      section.icon,
                      size: 20,
                      color: selected
                          ? accent
                          : AdminTheme.textSecondary,
                    ),
                    if (badge != null)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: _Badge(text: badge!),
                      ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Icon(
                  section.icon,
                  size: 18,
                  color: selected ? accent : AdminTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? accent : AdminTheme.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (badge != null) _Badge(text: badge!),
              ],
            ),
    );

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: compact ? label : '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
          child: content,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AdminTheme.accent.withValues(alpha: 0.18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AdminTheme.accent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Mobile drawer — replaces the cramped bottom navigation.
class AdminNavDrawer extends StatelessWidget {
  const AdminNavDrawer({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.livePlayers,
    required this.activeSessions,
    this.hardcorePlayers = 0,
    this.unreadMessages = 0,
    this.email = '',
  });

  final AdminNavSection selected;
  final ValueChanged<AdminNavSection> onSelected;
  final int livePlayers;
  final int activeSessions;
  final int hardcorePlayers;
  final int unreadMessages;
  final String email;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Drawer(
      backgroundColor: AdminTheme.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AdminTheme.accentSoft.withValues(alpha: 0.5),
                      ),
                      color: AdminTheme.accentSoft.withValues(alpha: 0.1),
                    ),
                    child: Text(
                      lang.t('admin_badge'),
                      style: const TextStyle(
                        color: AdminTheme.accentSoft,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.t('admin_title'),
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  for (final group in AdminNavGroup.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: Text(
                        lang.t(group.labelKey).toUpperCase(),
                        style: const TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    for (final section in group.sections)
                      _DrawerItem(
                        section: section,
                        selected: selected == section,
                        badge: section == AdminNavSection.live &&
                                livePlayers > 0
                            ? '$livePlayers'
                            : section == AdminNavSection.hardcore &&
                                    hardcorePlayers > 0
                                ? '$hardcorePlayers'
                                : section == AdminNavSection.messages &&
                                        unreadMessages > 0
                                    ? '$unreadMessages'
                                    : null,
                        onTap: () {
                          onSelected(section);
                          Navigator.of(context).maybePop();
                        },
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: AdminTheme.panel(
                  borderColor: AdminTheme.accentSoft.withValues(alpha: 0.28),
                  fill: AdminTheme.accentSoft.withValues(alpha: 0.06),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        size: 18, color: AdminTheme.accentSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.t('admin_active_sessions'),
                        style: const TextStyle(
                          color: AdminTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '$activeSessions',
                      style: const TextStyle(
                        color: AdminTheme.accentSoft,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
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
    final lang = context.lang;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
              color: selected
                  ? AdminTheme.accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? AdminTheme.accent.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 20,
                  color: selected
                      ? AdminTheme.accent
                      : AdminTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.t(section.labelKey),
                    style: TextStyle(
                      color: selected
                          ? AdminTheme.accent
                          : AdminTheme.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badge != null) _Badge(text: badge!),
              ],
            ),
          ),
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
    this.showMenuButton = false,
    this.onMenu,
  });

  final String email;
  final bool signingOut;
  final AdminNavSection section;
  final VoidCallback onRefresh;
  final VoidCallback onLobby;
  final VoidCallback onSignOut;
  final bool showMenuButton;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              tooltip: lang.t('admin_menu'),
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded, color: AdminTheme.accent),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AdminTheme.accentSoft.withValues(alpha: 0.5),
              ),
              color: AdminTheme.accentSoft.withValues(alpha: 0.1),
            ),
            child: Text(
              lang.t('admin_badge'),
              style: const TextStyle(
                color: AdminTheme.accentSoft,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(section.icon, size: 16, color: AdminTheme.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t(section.labelKey),
                  style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: lang.t('admin_refresh'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AdminTheme.accent),
          ),
          TextButton(
            onPressed: onLobby,
            child: Text(
              lang.t('admin_enter_lobby'),
              style: const TextStyle(
                color: AdminTheme.accent,
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
