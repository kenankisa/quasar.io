import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../game/models/admin_stats.dart';
import '../../game/room_type.dart';
import 'admin_theme.dart';
import 'admin_universes_panel.dart' show accentForRoom, roomTitle;

class AdminLiveUniverseSummary extends StatelessWidget {
  const AdminLiveUniverseSummary({super.key, required this.stats});

  final AdminStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AdminPanelCard(
      title: lang.t('admin_universes_section'),
      child: Column(
        children: [
          for (final type in RoomType.values
              .where((t) => t != RoomType.hardcore)) ...[
            if (type != RoomType.simple) const SizedBox(height: 8),
            _LiveUniverseRow(
              type: type,
              tier: stats.tiers[type] ?? AdminUniverseTierStats.empty(type),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveUniverseRow extends StatelessWidget {
  const _LiveUniverseRow({
    required this.type,
    required this.tier,
  });

  final RoomType type;
  final AdminUniverseTierStats tier;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final accent = accentForRoom(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        color: AdminTheme.surface.withValues(alpha: 0.55),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              roomTitle(lang, type),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          _MiniCount(
            icon: Icons.person_rounded,
            value: '${tier.players}',
            color: accent,
          ),
          if (type.allowsBots) ...[
            const SizedBox(width: 8),
            _MiniCount(
              icon: Icons.smart_toy_outlined,
              value: '${tier.bots}',
              color: const Color(0xFFFF00AA),
            ),
          ] else ...[
            const SizedBox(width: 8),
            Text(
              lang.t('admin_tune_players_only'),
              style: TextStyle(
                color: accent.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(width: 8),
          _MiniCount(
            icon: Icons.public_rounded,
            value: '${tier.activeUniverses}',
            color: AdminTheme.accentSoft,
          ),
        ],
      ),
    );
  }
}

class AdminOverviewGrid extends StatelessWidget {
  const AdminOverviewGrid({super.key, required this.stats});

  final AdminStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final tiles = [
          AdminMetricTile(
            label: lang.t('admin_total_players'),
            value: '${stats.totalPlayers}',
            accent: AdminTheme.accent,
            icon: Icons.person_rounded,
          ),
          AdminMetricTile(
            label: lang.t('admin_total_bots'),
            value: '${stats.totalBots}',
            accent: const Color(0xFFFF00AA),
            icon: Icons.smart_toy_outlined,
          ),
          AdminMetricTile(
            label: lang.t('admin_total_universes'),
            value: '${stats.totalActiveUniverses}',
            accent: AdminTheme.accentSoft,
            icon: Icons.public_rounded,
          ),
          AdminMetricTile(
            label: lang.t('admin_active_sessions'),
            value: '${stats.activeSessions}',
            accent: AdminTheme.warning,
            icon: Icons.login_rounded,
          ),
        ];

        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: 10),
                Expanded(child: tiles[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: tiles[2]),
                const SizedBox(width: 10),
                Expanded(child: tiles[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.75)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class AdminPlayerStatsCard extends StatelessWidget {
  const AdminPlayerStatsCard({super.key, required this.stats});

  final AdminStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AdminPanelCard(
      accentColor: AdminTheme.accent,
      title: lang.t('admin_page_players_title'),
      child: Column(
        children: [
          _MetricRow(
            label: lang.t('admin_registered_players'),
            value: '${stats.registeredPlayers}',
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: lang.t('admin_total_games_won'),
            value: '${stats.totalGamesWon}',
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: lang.t('admin_live_entities'),
            value: '${stats.totalPlayers + stats.totalBots}',
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: lang.t('admin_bot_share'),
            value: _botShare(stats),
          ),
        ],
      ),
    );
  }

  String _botShare(AdminStatsSnapshot stats) {
    final total = stats.totalPlayers + stats.totalBots;
    if (total <= 0) return '0%';
    final pct = ((stats.totalBots / total) * 100).round();
    return '$pct%';
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AdminTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class AdminTopWinnersCard extends StatelessWidget {
  const AdminTopWinnersCard({super.key, required this.winners});

  final List<AdminTopWinner> winners;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AdminPanelCard(
      accentColor: AdminTheme.warning,
      title: lang.t('admin_top_winners'),
      child: winners.isEmpty
          ? Text(
              lang.t('admin_no_players_yet'),
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 12,
              ),
            )
          : Column(
              children: winners.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final winner = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: AdminTheme.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          winner.username,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${winner.gamesWon} ★',
                        style: const TextStyle(
                          color: AdminTheme.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '◆ ${winner.diamonds}',
                        style: const TextStyle(
                          color: AdminTheme.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
