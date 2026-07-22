import 'package:flutter/material.dart';

import '../game/models/admin_analytics.dart';
import '../game/room_type.dart';
import '../services/admin_analytics_service.dart';
import '../services/lang_service.dart';

/// Yönetim paneli — geçmiş istatistikler bölümü.
class AdminAnalyticsPanel extends StatelessWidget {
  const AdminAnalyticsPanel({
    super.key,
    this.showHeader = false,
  });

  /// Sayfa başlığı dışarıdaysa false bırakın.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final service = AdminAnalyticsService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.snapshot;
        final loading = service.loading;
        final error = service.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) ...[
              Text(
                lang.t('admin_analytics_section'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.t('admin_analytics_subtitle'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _WindowChips(
              selected: service.window,
              onSelected: (w) => service.setWindow(w),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF4466).withValues(alpha: 0.45),
                  ),
                  color: const Color(0xFFFF4466).withValues(alpha: 0.08),
                ),
                child: Text(
                  lang.t('admin_analytics_migration_hint'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (loading && snap.totalLogins == 0 && snap.matchesPlayed == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF00F0FF),
                    ),
                  ),
                ),
              )
            else ...[
              _OverviewGrid(snap: snap),
              const SizedBox(height: 14),
              _PlayTimeCard(snap: snap),
              const SizedBox(height: 14),
              _DiamondsCard(snap: snap),
              const SizedBox(height: 14),
              Text(
                lang.t('admin_analytics_by_universe'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final type in RoomType.values) ...[
                _UniverseAnalyticsCard(
                  analytics: snap.byUniverse[type] ??
                      AdminUniverseAnalytics.empty(type),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _WindowChips extends StatelessWidget {
  const _WindowChips({
    required this.selected,
    required this.onSelected,
  });

  final AdminAnalyticsWindow selected;
  final ValueChanged<AdminAnalyticsWindow> onSelected;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final window in AdminAnalyticsWindow.values)
          ChoiceChip(
            label: Text(lang.t(window.labelKey)),
            selected: selected == window,
            onSelected: (_) => onSelected(window),
            selectedColor: const Color(0xFF00F0FF).withValues(alpha: 0.22),
            backgroundColor: const Color(0xFF0A0A1A),
            side: BorderSide(
              color: selected == window
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            labelStyle: TextStyle(
              color: selected == window
                  ? const Color(0xFF00F0FF)
                  : Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.snap});

  final AdminAnalyticsSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final tiles = [
      _MiniStat(
        label: lang.t('admin_analytics_unique_logins'),
        value: '${snap.uniqueLogins}',
        accent: const Color(0xFF00F0FF),
      ),
      _MiniStat(
        label: lang.t('admin_analytics_total_logins'),
        value: '${snap.totalLogins}',
        accent: const Color(0xFF22FFAA),
      ),
      _MiniStat(
        label: lang.t('admin_analytics_unique_played'),
        value: '${snap.uniquePlayersPlayed}',
        accent: const Color(0xFFFFC857),
      ),
      _MiniStat(
        label: lang.t('admin_analytics_matches'),
        value: '${snap.matchesPlayed}',
        accent: const Color(0xFFFF00AA),
      ),
      _MiniStat(
        label: lang.t('admin_analytics_wins'),
        value: '${snap.matchesWon}',
        accent: const Color(0xFF88AAFF),
      ),
      _MiniStat(
        label: lang.t('admin_analytics_registered'),
        value: '${snap.registeredPlayers}',
        accent: const Color(0xFFAA88FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        if (wide) {
          return Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 3; i < 6; i++) ...[
                    if (i > 3) const SizedBox(width: 8),
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            for (var row = 0; row < 3; row++) ...[
              if (row > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: tiles[row * 2]),
                  const SizedBox(width: 8),
                  Expanded(child: tiles[row * 2 + 1]),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PlayTimeCard extends StatelessWidget {
  const _PlayTimeCard({required this.snap});

  final AdminAnalyticsSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return _PanelCard(
      accent: const Color(0xFF00F0FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('admin_analytics_playtime_title'),
            style: const TextStyle(
              color: Color(0xFF00F0FF),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _KvRow(
            label: lang.t('admin_analytics_total_playtime'),
            value: _formatDuration(snap.totalPlaySeconds),
          ),
          _KvRow(
            label: lang.t('admin_analytics_avg_per_match'),
            value: _formatDuration(snap.avgPlaySecondsPerMatch.round()),
          ),
          _KvRow(
            label: lang.t('admin_analytics_avg_per_player'),
            value: _formatDuration(snap.avgPlaySecondsPerPlayer.round()),
          ),
        ],
      ),
    );
  }
}

class _DiamondsCard extends StatelessWidget {
  const _DiamondsCard({required this.snap});

  final AdminAnalyticsSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return _PanelCard(
      accent: const Color(0xFFFFC857),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('admin_analytics_diamonds_title'),
            style: const TextStyle(
              color: Color(0xFFFFC857),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _KvRow(
            label: lang.t('admin_analytics_diamonds_held'),
            value: '${snap.diamondsHeld}',
            valueColor: const Color(0xFFFFC857),
          ),
          _KvRow(
            label: lang.t('admin_analytics_diamonds_earned'),
            value: '+${snap.diamondsEarned}',
            valueColor: const Color(0xFF22FFAA),
          ),
          _KvRow(
            label: lang.t('admin_analytics_diamonds_lost'),
            value: '-${snap.diamondsLost}',
            valueColor: const Color(0xFFFF6688),
          ),
          _KvRow(
            label: lang.t('admin_analytics_diamonds_net'),
            value: snap.netDiamonds >= 0
                ? '+${snap.netDiamonds}'
                : '${snap.netDiamonds}',
            valueColor: snap.netDiamonds >= 0
                ? const Color(0xFF22FFAA)
                : const Color(0xFFFF6688),
          ),
        ],
      ),
    );
  }
}

class _UniverseAnalyticsCard extends StatelessWidget {
  const _UniverseAnalyticsCard({required this.analytics});

  final AdminUniverseAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final accent = _accentFor(analytics.roomType);
    final title = lang.t(_titleKey(analytics.roomType));

    return _PanelCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                _formatDuration(analytics.playSeconds),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _ChipStat(
                label: lang.t('admin_analytics_uni_players'),
                value: '${analytics.uniquePlayers}',
              ),
              _ChipStat(
                label: lang.t('admin_analytics_uni_matches'),
                value: '${analytics.matches}',
              ),
              _ChipStat(
                label: lang.t('admin_analytics_uni_wins'),
                value: '${analytics.wins}',
              ),
              _ChipStat(
                label: lang.t('admin_analytics_uni_elim'),
                value: '${analytics.eliminations}',
              ),
              _ChipStat(
                label: lang.t('admin_analytics_uni_avg'),
                value: _formatDuration(analytics.avgMatchSeconds.round()),
              ),
              _ChipStat(
                label: lang.t('admin_analytics_uni_diamonds'),
                value: analytics.netDiamonds >= 0
                    ? '+${analytics.netDiamonds}'
                    : '${analytics.netDiamonds}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _accentFor(RoomType type) => switch (type) {
        RoomType.simple => const Color(0xFF00FF88),
        RoomType.normal => const Color(0xFF00F0FF),
        RoomType.elite => const Color(0xFFFF00AA),
        RoomType.unique => const Color(0xFFFFC857),
      };

  static String _titleKey(RoomType type) => switch (type) {
        RoomType.simple => 'room_simple_title',
        RoomType.normal => 'room_normal_title',
        RoomType.elite => 'room_elite_title',
        RoomType.unique => 'room_unique_title',
      };
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.1),
            const Color(0xFF0A0A1A).withValues(alpha: 0.92),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.12),
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
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  const _ChipStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int totalSeconds) {
  final seconds = totalSeconds.clamp(0, 1 << 30);
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remSec = seconds % 60;
  if (minutes < 60) {
    return remSec == 0 ? '${minutes}m' : '${minutes}m ${remSec}s';
  }
  final hours = minutes ~/ 60;
  final remMin = minutes % 60;
  if (hours < 48) {
    return remMin == 0 ? '${hours}h' : '${hours}h ${remMin}m';
  }
  final days = hours ~/ 24;
  final remHours = hours % 24;
  return remHours == 0 ? '${days}d' : '${days}d ${remHours}h';
}
