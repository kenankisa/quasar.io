import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../game/models/admin_hardcore_live.dart';
import '../../game/room_type.dart';
import '../../services/admin_game_trial_service.dart';
import '../../services/admin_hardcore_live_service.dart';
import '../../services/room_tuning_service.dart';
import '../admin_room_tuning_editor.dart';
import 'admin_hardcore_arena_test_section.dart';
import 'admin_player_radius_label.dart';
import 'admin_theme.dart';
import 'admin_tools_role_legend.dart';
import 'admin_universes_panel.dart' show roomTitle;

const _hardcoreAccent = Color(0xFFFF3355);

/// Dedicated Hardcore ops page: live arena tracking + rules/tuning.
class AdminHardcorePanel extends StatefulWidget {
  const AdminHardcorePanel({super.key});

  @override
  State<AdminHardcorePanel> createState() => _AdminHardcorePanelState();
}

class _AdminHardcorePanelState extends State<AdminHardcorePanel> {
  AdminTuningCategory _category = AdminTuningCategory.hardcoreRules;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final live = AdminHardcoreLiveService.instance.snapshot;
    final liveError = AdminHardcoreLiveService.instance.error;
    final loading = AdminHardcoreLiveService.instance.loading;
    final tuning = RoomTuningService.instance.tuningFor(RoomType.hardcore);
    final saving = RoomTuningService.instance.saving;
    final accent = _hardcoreAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminToolsRoleLegend(),
        const SizedBox(height: 14),
        if (liveError != null) ...[
          AdminErrorBanner(message: lang.t(liveError)),
          const SizedBox(height: 12),
        ],
        _LiveOpsHeader(
          snapshot: live,
          loading: loading,
          accent: accent,
        ),
        const SizedBox(height: 14),
        _LiveMetricStrip(snapshot: live, accent: accent),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final gauge = _CapacityGauge(snapshot: live, accent: accent);
            final diamondFlow = _DiamondFlowCard(snapshot: live, accent: accent);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: gauge),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: diamondFlow),
                ],
              );
            }
            return Column(
              children: [
                gauge,
                const SizedBox(height: 12),
                diamondFlow,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final arena = _ArenaPlayersCard(snapshot: live, accent: accent);
            final queue = _QueueCard(snapshot: live, accent: accent);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: arena),
                  const SizedBox(width: 12),
                  Expanded(child: queue),
                ],
              );
            }
            return Column(
              children: [
                arena,
                const SizedBox(height: 12),
                queue,
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        const AdminHardcoreArenaTestSection(),
        const SizedBox(height: 22),
        Text(
          lang.t('admin_hardcore_tuning_section'),
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        if (saving)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _hardcoreAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  lang.t('admin_tune_saving'),
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: AdminTheme.softPanel(accentColor: accent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        roomTitle(lang, RoomType.hardcore),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => RoomTuningService.instance
                              .resetRoomToDefaults(RoomType.hardcore),
                      child: Text(
                        lang.t('admin_room_tuning_reset_one'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _HardcoreCategoryBar(
                  accent: accent,
                  category: _category,
                  onCategory: (c) => setState(() => _category = c),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: AdminRoomTuningEditor(
                  roomType: RoomType.hardcore,
                  accent: accent,
                  category: _category,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  lang
                      .t('admin_hardcore_meta_max')
                      .replaceAll('{n}', '${tuning.maxPlayers}'),
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveOpsHeader extends StatelessWidget {
  const _LiveOpsHeader({
    required this.snapshot,
    required this.loading,
    required this.accent,
  });

  final AdminHardcoreLiveSnapshot snapshot;
  final bool loading;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AdminPanelCard(
      accentColor: accent,
      title: lang.t('admin_hardcore_live_section'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LivePulse(active: snapshot.isOpen && snapshot.seatOccupancy > 0),
          const SizedBox(width: 8),
          Text(
            snapshot.isOpen
                ? lang.t('admin_hardcore_status_live')
                : lang.t('admin_hardcore_status_idle'),
            style: TextStyle(
              color: snapshot.isOpen ? accent : AdminTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          if (loading) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
      child: Text(
        lang.t('admin_hardcore_live_hint'),
        style: const TextStyle(
          color: AdminTheme.textSecondary,
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
    );
  }
}

class _LivePulse extends StatefulWidget {
  const _LivePulse({required this.active});

  final bool active;

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _LivePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.active ? _controller.value : 0.0;
        final glow = 0.35 + 0.45 * (1 - (t - 0.5).abs() * 2);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hardcoreAccent.withValues(alpha: 0.85),
            boxShadow: [
              BoxShadow(
                color: _hardcoreAccent.withValues(alpha: glow),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveMetricStrip extends StatelessWidget {
  const _LiveMetricStrip({
    required this.snapshot,
    required this.accent,
  });

  final AdminHardcoreLiveSnapshot snapshot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final tiles = [
      AdminMetricTile(
        label: lang.t('admin_hardcore_metric_players'),
        value: '${snapshot.seatOccupancy}/${snapshot.maxPlayers}',
        accent: accent,
        icon: Icons.groups_rounded,
      ),
      AdminMetricTile(
        label: lang.t('admin_hardcore_metric_queue'),
        value: '${snapshot.queueCount}',
        accent: AdminTheme.warning,
        icon: Icons.hourglass_top_rounded,
      ),
      AdminMetricTile(
        label: lang.t('admin_hardcore_metric_won_hour'),
        value: '+${snapshot.diamondsWonHour}',
        accent: AdminTheme.accentSoft,
        icon: Icons.trending_up_rounded,
      ),
      AdminMetricTile(
        label: lang.t('admin_hardcore_metric_lost_hour'),
        value: '−${snapshot.diamondsLostHour}',
        accent: accent,
        icon: Icons.trending_down_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
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

class _CapacityGauge extends StatelessWidget {
  const _CapacityGauge({
    required this.snapshot,
    required this.accent,
  });

  final AdminHardcoreLiveSnapshot snapshot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AdminPanelCard(
      accentColor: accent,
      title: lang.t('admin_hardcore_capacity_title'),
      child: SizedBox(
        height: 168,
        child: Row(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _RingGaugePainter(
                  progress: snapshot.fillRatio,
                  accent: accent,
                  track: AdminTheme.surfaceElevated,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${snapshot.seatOccupancy}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '/ ${snapshot.maxPlayers}',
                        style: const TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GaugeStat(
                    label: lang.t('admin_hardcore_metric_raw_count'),
                    value: '${snapshot.realPlayerCount}',
                  ),
                  const SizedBox(height: 10),
                  _GaugeStat(
                    label: lang.t('admin_hardcore_metric_leader'),
                    value: '${snapshot.leaderRadius}',
                  ),
                  const SizedBox(height: 10),
                  _GaugeStat(
                    label: lang.t('admin_hardcore_metric_fill'),
                    value: '${(snapshot.fillRatio * 100).round()}%',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeStat extends StatelessWidget {
  const _GaugeStat({required this.label, required this.value});

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
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AdminTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  _RingGaugePainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        colors: [
          accent.withValues(alpha: 0.35),
          accent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

class _DiamondFlowCard extends StatelessWidget {
  const _DiamondFlowCard({
    required this.snapshot,
    required this.accent,
  });

  final AdminHardcoreLiveSnapshot snapshot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AdminPanelCard(
      accentColor: AdminTheme.accent,
      title: lang.t('admin_hardcore_diamonds_title'),
      child: Column(
        children: [
          _DiamondBar(
            label: lang.t('admin_hardcore_diamonds_won_today'),
            value: snapshot.diamondsWonToday,
            color: AdminTheme.accentSoft,
            positive: true,
          ),
          const SizedBox(height: 10),
          _DiamondBar(
            label: lang.t('admin_hardcore_diamonds_lost_today'),
            value: snapshot.diamondsLostToday,
            color: accent,
            positive: false,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
              color: AdminTheme.surface.withValues(alpha: 0.55),
              border: Border.all(color: AdminTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniDiamondStat(
                    label: lang.t('admin_hardcore_diamonds_won_hour'),
                    value: '+${snapshot.diamondsWonHour}',
                    color: AdminTheme.accentSoft,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: AdminTheme.border,
                ),
                Expanded(
                  child: _MiniDiamondStat(
                    label: lang.t('admin_hardcore_diamonds_lost_hour'),
                    value: '−${snapshot.diamondsLostHour}',
                    color: accent,
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

class _DiamondBar extends StatelessWidget {
  const _DiamondBar({
    required this.label,
    required this.value,
    required this.color,
    required this.positive,
  });

  final String label;
  final int value;
  final Color color;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final maxRef = math.max(value, 1).toDouble();
    final ratio = (value / (maxRef < 50 ? 50 : maxRef)).clamp(0.08, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              positive ? Icons.diamond_rounded : Icons.diamond_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${positive ? '+' : '−'}$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value <= 0 ? 0 : ratio,
            minHeight: 8,
            backgroundColor: AdminTheme.surfaceElevated,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _MiniDiamondStat extends StatelessWidget {
  const _MiniDiamondStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaPlayersCard extends StatelessWidget {
  const _ArenaPlayersCard({
    required this.snapshot,
    required this.accent,
  });

  final AdminHardcoreLiveSnapshot snapshot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final players = snapshot.players;
    final liveRadii = AdminGameTrialService.instance.liveRadii;
    return AdminPanelCard(
      accentColor: accent,
      title: lang
          .t('admin_hardcore_arena_players')
          .replaceAll('{n}', '${players.length}'),
      child: players.isEmpty
          ? Text(
              lang.t('admin_hardcore_arena_empty'),
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 12,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < players.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _PlayerRow(
                    index: i + 1,
                    name: players[i].username,
                    badge: players[i].isAdmin
                        ? lang.t('admin_hardcore_player_admin')
                        : null,
                    radius: liveRadii[players[i].userId]?.toDouble() ??
                        players[i].currentRadius?.toDouble(),
                    accent: accent,
                  ),
                ],
              ],
            ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.snapshot,
    required this.accent,
  });

  final AdminHardcoreLiveSnapshot snapshot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final queue = snapshot.queue;
    return AdminPanelCard(
      accentColor: AdminTheme.warning,
      title: lang
          .t('admin_hardcore_queue_title')
          .replaceAll('{n}', '${snapshot.queueCount}'),
      child: queue.isEmpty
          ? Text(
              lang.t('admin_hardcore_queue_empty'),
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 12,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < queue.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _PlayerRow(
                    index: queue[i].position,
                    name: queue[i].username,
                    accent: AdminTheme.warning,
                    shaped: true,
                  ),
                ],
              ],
            ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.index,
    required this.name,
    required this.accent,
    this.badge,
    this.radius,
    this.shaped = false,
  });

  final int index;
  final String name;
  final Color accent;
  final String? badge;
  final double? radius;
  final bool shaped;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        color: AdminTheme.surface.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: shaped ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: shaped ? null : BorderRadius.circular(7),
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: accent.withValues(alpha: 0.12),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (radius != null && radius! > 0) ...[
            if (badge != null) const SizedBox(width: 8),
            AdminPlayerRadiusLabel(radius: radius!, accent: accent),
          ],
        ],
      ),
    );
  }
}

class _HardcoreCategoryBar extends StatelessWidget {
  const _HardcoreCategoryBar({
    required this.accent,
    required this.category,
    required this.onCategory,
  });

  final Color accent;
  final AdminTuningCategory category;
  final ValueChanged<AdminTuningCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final items = <(AdminTuningCategory, String)>[
      (AdminTuningCategory.hardcoreRules, lang.t('admin_tune_tab_hardcore_rules')),
      (AdminTuningCategory.world, lang.t('admin_tune_tab_world')),
      (AdminTuningCategory.tempo, lang.t('admin_tune_tab_tempo')),
      (AdminTuningCategory.objects, lang.t('admin_tune_tab_objects')),
      (AdminTuningCategory.events, lang.t('admin_tune_tab_events')),
      (AdminTuningCategory.radiation, lang.t('admin_tune_tab_radiation')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onCategory(item.$1),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: category == item.$1
                          ? accent.withValues(alpha: 0.65)
                          : accent.withValues(alpha: 0.18),
                    ),
                    color: category == item.$1
                        ? accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: category == item.$1
                          ? accent
                          : AdminTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
