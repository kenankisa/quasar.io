import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import 'admin_theme.dart';

/// Clarifies Live Ops vs Arena Test vs Game Trial vs Load Test admin tools.
enum AdminToolRole {
  liveOps,
  arenaTest,
  gameTrial,
  loadTest,
}

class AdminToolsRoleLegend extends StatelessWidget {
  const AdminToolsRoleLegend({
    super.key,
    this.highlight,
    this.compact = false,
  });

  /// When set, shows only this role (compact banner). Otherwise full legend.
  final AdminToolRole? highlight;
  final bool compact;

  static const _roles = [
    AdminToolRole.liveOps,
    AdminToolRole.arenaTest,
    AdminToolRole.gameTrial,
    AdminToolRole.loadTest,
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final roles = highlight != null ? [highlight!] : _roles;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AdminTheme.surface.withValues(alpha: 0.65),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact || highlight == null) ...[
            Text(
              lang.t('admin_tools_roles_title'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 8 : 10),
          ],
          for (var i = 0; i < roles.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 6 : 8),
            _RoleRow(role: roles[i], emphasized: highlight == roles[i]),
          ],
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, this.emphasized = false});

  final AdminToolRole role;
  final bool emphasized;

  static const _accent = Color(0xFF00F0FF);

  (String, String, IconData) _keys(AdminToolRole role) => switch (role) {
        AdminToolRole.liveOps => (
            'admin_tools_role_live_title',
            'admin_tools_role_live_body',
            Icons.sensors_rounded,
          ),
        AdminToolRole.arenaTest => (
            'admin_tools_role_arena_test_title',
            'admin_tools_role_arena_test_body',
            Icons.science_outlined,
          ),
        AdminToolRole.gameTrial => (
            'admin_tools_role_game_trial_title',
            'admin_tools_role_game_trial_body',
            Icons.groups_outlined,
          ),
        AdminToolRole.loadTest => (
            'admin_tools_role_load_test_title',
            'admin_tools_role_load_test_body',
            Icons.speed_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final (titleKey, bodyKey, icon) = _keys(role);
    final accent = emphasized ? _accent : Colors.white.withValues(alpha: 0.55);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t(titleKey),
                style: TextStyle(
                  color: emphasized
                      ? _accent
                      : Colors.white.withValues(alpha: 0.88),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                lang.t(bodyKey),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
