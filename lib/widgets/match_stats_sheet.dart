import 'package:flutter/material.dart';

import '../game/models/match_stats.dart';
import '../services/player_session_service.dart';
import '../utils/lang_scope.dart';
import 'match_stats_panel.dart';

/// Opens the full post-match statistics view (growth chart, kills, abilities).
class MatchStatsSheet {
  MatchStatsSheet._();

  static Future<void> show(
    BuildContext context, {
    required MatchStatsSnapshot stats,
    Color accent = const Color(0xFF00F0FF),
  }) {
    PlayerSessionService.instance.noteActivity();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => _MatchStatsDialog(stats: stats, accent: accent),
    );
  }
}

class _MatchStatsDialog extends StatelessWidget {
  const _MatchStatsDialog({
    required this.stats,
    required this.accent,
  });

  final MatchStatsSnapshot stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: const Color(0xFF08081A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.insights_outlined, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.t('match_stats_title'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    tooltip: lang.t('match_stats_close'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: MatchStatsPanel(
                  stats: stats,
                  expanded: true,
                  showHeader: false,
                  showDeaths: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary action on match result screens — opens [MatchStatsSheet].
class MatchResultStatsButton extends StatelessWidget {
  const MatchResultStatsButton({
    super.key,
    required this.stats,
    this.accent = const Color(0xFF00F0FF),
  });

  final MatchStatsSnapshot stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => MatchStatsSheet.show(
          context,
          stats: stats,
          accent: accent,
        ),
        icon: Icon(Icons.bar_chart_rounded, size: 20, color: accent),
        label: Text(lang.t('match_stats_open')),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
