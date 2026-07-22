import 'package:flutter/material.dart';

import '../../game/models/admin_stats.dart';
import '../../game/room_type.dart';
import '../../services/lang_service.dart';

class AdminLiveUniverseSummary extends StatelessWidget {
  const AdminLiveUniverseSummary({super.key, required this.stats});

  final AdminStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lang.t('admin_universes_section'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final type in RoomType.values) ...[
          _LiveUniverseRow(
            type: type,
            tier: stats.tiers[type] ?? AdminUniverseTierStats.empty(type),
          ),
          const SizedBox(height: 8),
        ],
      ],
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
    final lang = LanguageService.instance;
    final accent = _accentForRoom(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        color: const Color(0xFF0A0A1A).withValues(alpha: 0.78),
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
              _roomTitle(lang, type),
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
          const SizedBox(width: 8),
          _MiniCount(
            icon: Icons.smart_toy_outlined,
            value: '${tier.bots}',
            color: const Color(0xFFFF00AA),
          ),
          const SizedBox(width: 8),
          _MiniCount(
            icon: Icons.public_rounded,
            value: '${tier.activeUniverses}',
            color: const Color(0xFF22FFAA),
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
    final lang = LanguageService.instance;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final tiles = [
          _StatTile(
            label: lang.t('admin_total_players'),
            value: '${stats.totalPlayers}',
            accent: const Color(0xFF00F0FF),
          ),
          _StatTile(
            label: lang.t('admin_total_bots'),
            value: '${stats.totalBots}',
            accent: const Color(0xFFFF00AA),
          ),
          _StatTile(
            label: lang.t('admin_total_universes'),
            value: '${stats.totalActiveUniverses}',
            accent: const Color(0xFF22FFAA),
          ),
          _StatTile(
            label: lang.t('admin_active_sessions'),
            value: '${stats.activeSessions}',
            accent: const Color(0xFFFFC857),
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            const Color(0xFF0A0A1A).withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

Color _accentForRoom(RoomType type) => switch (type) {
      RoomType.simple => const Color(0xFF7AD7FF),
      RoomType.normal => const Color(0xFF00F0FF),
      RoomType.elite => const Color(0xFFFFC857),
      RoomType.unique => const Color(0xFFFF00AA),
    };

String _roomTitle(LanguageService lang, RoomType type) {
  final title = lang.t(type.instanceTitleKey).replaceAll('{number}', '').trim();
  return title.isEmpty ? type.name : title;
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
    final lang = LanguageService.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
        ),
        color: const Color(0xFF0A0A1A).withValues(alpha: 0.78),
      ),
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
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
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
    final lang = LanguageService.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: 0.28),
        ),
        color: const Color(0xFF0A0A1A).withValues(alpha: 0.78),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('admin_top_winners'),
            style: const TextStyle(
              color: Color(0xFFFFC857),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          if (winners.isEmpty)
            Text(
              lang.t('admin_no_players_yet'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            )
          else
            ...winners.asMap().entries.map((entry) {
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
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${winner.gamesWon} ★',
                      style: const TextStyle(
                        color: Color(0xFFFFC857),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '◆ ${winner.diamonds}',
                      style: const TextStyle(
                        color: Color(0xFF00F0FF),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.red.withValues(alpha: 0.15),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}
