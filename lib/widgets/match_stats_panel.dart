import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/models/match_stats.dart';
import '../utils/lang_scope.dart';
import '../utils/match_time.dart';

/// Post-match summary: growth curve, kills, and ability usage counts.
class MatchStatsPanel extends StatelessWidget {
  const MatchStatsPanel({
    super.key,
    required this.stats,
    this.expanded = false,
    this.showHeader = true,
    this.showDeaths = false,
  });

  final MatchStatsSnapshot stats;
  final bool expanded;
  final bool showHeader;
  final bool showDeaths;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0A0A1E).withValues(alpha: 0.92),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            Text(
              lang.t('match_stats_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF00F0FF),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: expanded ? 156 : 108,
            child: CustomPaint(
              painter: _GrowthChartPainter(
                samples: stats.growthSamples,
                victoryRadius: stats.victoryRadius,
                elapsedSeconds: stats.matchElapsed,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    lang.t('match_stats_growth'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: lang.t('match_stats_kills'),
                  value: '${stats.kills}',
                  icon: Icons.brightness_7_outlined,
                  accent: const Color(0xFFFF00AA),
                ),
              ),
              if (showDeaths) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: lang.t('match_stats_deaths'),
                    value: '${stats.deaths}',
                    icon: Icons.blur_off_outlined,
                    accent: const Color(0xFFFF6B6B),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: lang.t('match_stats_peak'),
                  value: stats.peakRadius.toStringAsFixed(0),
                  icon: Icons.blur_circular,
                  accent: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: lang.t('match_stats_time'),
                  value: formatMatchTime(stats.matchElapsed),
                  icon: Icons.timer_outlined,
                  accent: const Color(0xFF00F0FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lang.t('match_stats_abilities'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AbilityStat(
                  icon: Icons.bolt_rounded,
                  label: lang.t('skill_branch_boost'),
                  count: stats.boostUses,
                  accent: const Color(0xFFFFD700),
                ),
              ),
              Expanded(
                child: _AbilityStat(
                  icon: Icons.shuffle_rounded,
                  label: lang.t('skill_branch_teleport'),
                  count: stats.teleportUses,
                  accent: const Color(0xFFC084FC),
                ),
              ),
              Expanded(
                child: _AbilityStat(
                  icon: Icons.shield_rounded,
                  label: lang.t('skill_branch_shield'),
                  count: stats.shieldUses,
                  accent: const Color(0xFF7CFFB2),
                ),
              ),
              Expanded(
                child: _AbilityStat(
                  icon: Icons.waves_rounded,
                  label: lang.t('skill_branch_shockwave'),
                  count: stats.shockwaveUses,
                  accent: const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Text(
              lang
                  .t('match_stats_total_abilities')
                  .replaceAll('{count}', '${stats.totalAbilityUses}'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityStat extends StatelessWidget {
  const _AbilityStat({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: accent.withValues(alpha: 0.9)),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  _GrowthChartPainter({
    required this.samples,
    required this.victoryRadius,
    required this.elapsedSeconds,
  });

  final List<GrowthSample> samples;
  final double victoryRadius;
  final double elapsedSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = const EdgeInsets.fromLTRB(28, 14, 8, 18);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    if (chartRect.width <= 0 || chartRect.height <= 0 || samples.isEmpty) {
      return;
    }

    final maxTime =
        math.max(math.max(elapsedSeconds, samples.last.elapsedSeconds), 1.0);
    var maxRadius = victoryRadius;
    for (final sample in samples) {
      maxRadius = math.max(maxRadius, sample.radius);
    }
    maxRadius = math.max(maxRadius, 1.0);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = chartRect.top + chartRect.height * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final victoryY = chartRect.bottom -
        (victoryRadius / maxRadius).clamp(0.0, 1.0) * chartRect.height;
    final victoryPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chartRect.left, victoryY),
      Offset(chartRect.right, victoryY),
      victoryPaint,
    );

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final x = chartRect.left +
          (sample.elapsedSeconds / maxTime).clamp(0.0, 1.0) * chartRect.width;
      final y = chartRect.bottom -
          (sample.radius / maxRadius).clamp(0.0, 1.0) * chartRect.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(chartRect.right, chartRect.bottom)
      ..lineTo(chartRect.left, chartRect.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00F0FF).withValues(alpha: 0.22),
            const Color(0xFF00F0FF).withValues(alpha: 0.02),
          ],
        ).createShader(chartRect),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF00F0FF), Color(0xFFFF00AA)],
        ).createShader(chartRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = samples.last;
    final lastX = chartRect.left +
        (last.elapsedSeconds / maxTime).clamp(0.0, 1.0) * chartRect.width;
    final lastY = chartRect.bottom -
        (last.radius / maxRadius).clamp(0.0, 1.0) * chartRect.height;
    canvas.drawCircle(
      Offset(lastX, lastY),
      3.5,
      Paint()..color = const Color(0xFFFF00AA),
    );

    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.38),
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );
    _paintLabel(
      canvas,
      '0',
      Offset(chartRect.left - 4, chartRect.bottom + 2),
      labelStyle,
      align: TextAlign.right,
    );
    _paintLabel(
      canvas,
      formatMatchTime(maxTime),
      Offset(chartRect.right, chartRect.bottom + 2),
      labelStyle,
      align: TextAlign.left,
    );
    _paintLabel(
      canvas,
      maxRadius.toStringAsFixed(0),
      Offset(chartRect.left - 6, chartRect.top - 2),
      labelStyle,
      align: TextAlign.right,
    );
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required TextAlign align,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 40);
    final dx = align == TextAlign.right ? offset.dx - painter.width : offset.dx;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.victoryRadius != victoryRadius ||
        oldDelegate.elapsedSeconds != elapsedSeconds;
  }
}
