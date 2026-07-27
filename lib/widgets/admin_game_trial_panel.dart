import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/game_screen.dart';
import '../game/models/admin_stats.dart';
import '../services/admin_game_trial_service.dart';
import '../services/admin_hardcore_live_service.dart';
import '../services/admin_stats_service.dart';
import '../services/analytics_play_tracker.dart';
import '../services/lang_service.dart';
import '../services/player_session_service.dart';
import '../services/room_matchmaking_service.dart';
import 'admin/admin_theme.dart';
import 'admin/admin_player_radius_label.dart';
import 'admin/admin_tools_role_legend.dart';
import 'admin/admin_universes_panel.dart' show accentForRoom, roomTitle;
import 'lobby_screen.dart';

const _trialAccent = Color(0xFF00E5A8);

/// Yönetim — Oyun Deneme: canlı Hardcore'a sim oyuncu + evren takibi.
class AdminGameTrialPanel extends StatefulWidget {
  const AdminGameTrialPanel({super.key});

  @override
  State<AdminGameTrialPanel> createState() => _AdminGameTrialPanelState();
}

class _AdminGameTrialPanelState extends State<AdminGameTrialPanel> {
  final _service = AdminGameTrialService.instance;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    AdminHardcoreLiveService.instance.attach();
    // Defer refresh — notifyListeners during mount throws setState-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_service.refresh());
    });
  }

  @override
  void dispose() {
    AdminHardcoreLiveService.instance.detach();
    super.dispose();
  }

  Future<void> _add(int count) async {
    final result = await _service.addPlayers(count);
    if (!mounted) return;
    final lang = context.lang;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang
                .t('admin_game_trial_added_ok')
                .replaceAll('{count}', '${result.started}')
                .replaceAll('{active}', '${result.activePlayers}'),
          ),
          backgroundColor: const Color(0xFF0A2A22),
        ),
      );
      return;
    }
    final err = _service.error;
    final detail = _service.lastErrorDetail;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          [
            err == null
                ? lang.t('admin_game_trial_start_failed')
                : lang.t(err),
            if (detail != null && detail.isNotEmpty) detail,
          ].join('\n'),
        ),
        backgroundColor: const Color(0xFF2A1018),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _stop() async {
    final stopped = await _service.stopAll();
    if (!mounted || stopped == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LanguageService.instance
              .t('admin_game_trial_stopped_ok')
              .replaceAll('{count}', '$stopped'),
        ),
        backgroundColor: const Color(0xFF1A1020),
      ),
    );
  }

  Future<void> _reset() async {
    final lang = context.lang;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: Text(
          lang.t('admin_game_trial_reset_confirm_title'),
          style: const TextStyle(
            color: AdminTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          lang.t('admin_game_trial_reset_confirm_body'),
          style: const TextStyle(
            color: AdminTheme.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.t('admin_game_trial_reset_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF5577),
            ),
            child: Text(lang.t('admin_game_trial_reset_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.resetAll();
    if (!mounted) return;
    if (result == null) {
      final err = _service.error;
      final detail = _service.lastErrorDetail;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              err == null
                  ? lang.t('admin_game_trial_reset_failed')
                  : lang.t(err),
              if (detail != null && detail.isNotEmpty) detail,
            ].join('\n'),
          ),
          backgroundColor: const Color(0xFF2A1018),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang
              .t('admin_game_trial_reset_ok')
              .replaceAll('{clients}', '${result.stoppedClients}')
              .replaceAll('{deleted}', '${result.deletedUsers}')
              .replaceAll('{left}', '${result.membersCleared}'),
        ),
        backgroundColor: const Color(0xFF1A1020),
      ),
    );
  }

  Future<void> _joinHardcore() async {
    if (_joining) return;
    setState(() => _joining = true);
    final lang = context.lang;
    try {
      await PlayerSessionService.instance.setInGame(RoomType.hardcore);
      await AnalyticsPlayTracker.instance.begin(RoomType.hardcore);
      final result =
          await RoomMatchmakingService.instance.joinHardcoreUniverse();
      if (!mounted) return;
      if (result is! HardcoreJoined) {
        throw StateError(lang.t('admin_game_trial_join_queued'));
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            roomType: RoomType.hardcore,
            roomInstance: result.instance,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lang.t('admin_game_trial_join_failed')}\n$e'),
          backgroundColor: const Color(0xFF2A1018),
        ),
      );
    } finally {
      await AnalyticsPlayTracker.instance.end(roomType: RoomType.hardcore);
      await PlayerSessionService.instance.setInLobby();
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _joinRoomInstance(
    RoomType type,
    AdminUniverseInstance instance,
  ) async {
    if (type == RoomType.hardcore) {
      await _joinHardcore();
      return;
    }
    if (_joining) return;
    setState(() => _joining = true);
    final lang = context.lang;
    try {
      await PlayerSessionService.instance.setInGame(type);
      await AnalyticsPlayTracker.instance.begin(type);
      final room = await RoomMatchmakingService.instance.joinRoomInstance(
        instance.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            roomType: type,
            roomInstance: room,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lang.t('admin_game_trial_join_failed')}\n$e'),
          backgroundColor: const Color(0xFF2A1018),
        ),
      );
    } finally {
      await AnalyticsPlayTracker.instance.end(roomType: type);
      await PlayerSessionService.instance.setInLobby();
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _openLobby() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LobbyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final busy = _service.busy;
    final active = _service.activeCount;
    final queued = _service.queuedCount;
    final inArena = _service.inArenaCount;
    final wins = _service.sessionWins;
    final hc = AdminHardcoreLiveService.instance.snapshot;
    final stats = AdminStatsService.instance.snapshot;
    final canAdd = !busy && active < AdminGameTrialService.maxPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminToolsRoleLegend(
          highlight: AdminToolRole.gameTrial,
          compact: true,
        ),
        const SizedBox(height: 12),
        if (_service.migrationMissing) ...[
          AdminErrorBanner(
            message: lang.t('admin_game_trial_migration_hint'),
          ),
          const SizedBox(height: 12),
        ],
        if (_service.error != null &&
            _service.error != 'admin_game_trial_migration_hint') ...[
          AdminErrorBanner(message: lang.t(_service.error!)),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AdminTheme.panel(
            borderColor: _trialAccent.withValues(alpha: 0.35),
            fill: _trialAccent.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('admin_game_trial_how_title'),
                style: const TextStyle(
                  color: _trialAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.t('admin_game_trial_how_body'),
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = [
              _Metric(
                label: lang.t('admin_game_trial_active'),
                value: '$active / ${AdminGameTrialService.maxPlayers}',
                color: _trialAccent,
              ),
              _Metric(
                label: lang.t('admin_game_trial_in_arena'),
                value: '$inArena',
                color: const Color(0xFFFF3355),
              ),
              _Metric(
                label: lang.t('admin_game_trial_queued'),
                value: '$queued',
                color: AdminTheme.warning,
              ),
              _Metric(
                label: lang.t('admin_game_trial_session_wins'),
                value: '$wins',
                color: AdminTheme.accentSoft,
              ),
            ];
            if (constraints.maxWidth >= 640) {
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
                Row(children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[1]),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: tiles[2]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[3]),
                ]),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          lang.t('admin_game_trial_spawn_label'),
          style: const TextStyle(
            color: AdminTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in AdminGameTrialService.spawnPresets)
              _ActionChip(
                label: '+$n',
                enabled: canAdd,
                onTap: () => unawaited(_add(n)),
                accent: _trialAccent,
              ),
            _ActionChip(
              label: lang.t('admin_game_trial_stop'),
              enabled: !busy && active > 0,
              onTap: () => unawaited(_stop()),
              accent: const Color(0xFFFF5577),
              filled: true,
            ),
            _ActionChip(
              label: lang.t('admin_game_trial_reset'),
              enabled: !busy,
              onTap: () => unawaited(_reset()),
              accent: const Color(0xFFFFAA33),
              filled: true,
            ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _trialAccent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                lang.t(
                  _service.isResetting
                      ? 'admin_game_trial_resetting'
                      : _service.isStopping
                          ? 'admin_game_trial_stopping'
                          : 'admin_game_trial_spawning',
                ),
                style: const TextStyle(
                  color: AdminTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Text(
          lang.t('admin_game_trial_jump_title'),
          style: const TextStyle(
            color: AdminTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          lang.t('admin_game_trial_jump_hint'),
          style: const TextStyle(
            color: AdminTheme.textMuted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(
              label: lang.t('admin_game_trial_join_hardcore'),
              enabled: !_joining,
              onTap: () => unawaited(_joinHardcore()),
              accent: const Color(0xFFFF3355),
              filled: true,
            ),
            _ActionChip(
              label: lang.t('admin_enter_lobby'),
              enabled: !_joining,
              onTap: () => unawaited(_openLobby()),
              accent: AdminTheme.accent,
            ),
            _ActionChip(
              label: lang
                  .t('admin_game_trial_hc_seats')
                  .replaceAll('{occ}', '${hc.seatOccupancy}')
                  .replaceAll('{max}', '${hc.maxPlayers}')
                  .replaceAll('{q}', '${hc.queueCount}'),
              enabled: false,
              onTap: () {},
              accent: const Color(0xFFFF3355),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _LiveUniversesCard(
          stats: stats,
          joining: _joining,
          onJoinInstance: _joinRoomInstance,
        ),
        const SizedBox(height: 18),
        _RankingsCard(
          rankings: _service.rankings,
          liveRadii: _service.liveRadii,
        ),
        const SizedBox(height: 18),
        _EventsCard(events: _service.eventLog),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        color: AdminTheme.surface.withValues(alpha: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.accent,
    this.filled = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              color: filled
                  ? accent.withValues(alpha: 0.18)
                  : accent.withValues(alpha: 0.06),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveUniversesCard extends StatelessWidget {
  const _LiveUniversesCard({
    required this.stats,
    required this.joining,
    required this.onJoinInstance,
  });

  final AdminStatsSnapshot stats;
  final bool joining;
  final Future<void> Function(RoomType, AdminUniverseInstance) onJoinInstance;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AdminTheme.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('admin_game_trial_universes_title'),
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.t('admin_game_trial_universes_hint'),
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          for (final type in RoomType.values) ...[
            if (type != RoomType.simple) const SizedBox(height: 8),
            _UniverseTierBlock(
              type: type,
              tier: stats.tiers[type] ?? AdminUniverseTierStats.empty(type),
              joining: joining,
              onJoinInstance: onJoinInstance,
            ),
          ],
        ],
      ),
    );
  }
}

class _UniverseTierBlock extends StatelessWidget {
  const _UniverseTierBlock({
    required this.type,
    required this.tier,
    required this.joining,
    required this.onJoinInstance,
  });

  final RoomType type;
  final AdminUniverseTierStats tier;
  final bool joining;
  final Future<void> Function(RoomType, AdminUniverseInstance) onJoinInstance;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final accent = accentForRoom(type);
    final instances = tier.instances
        .where((i) => !i.isLoadTest)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        color: AdminTheme.surface.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
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
              Text(
                '${tier.players}p · ${tier.activeUniverses}u',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (instances.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lang.t('admin_game_trial_no_instances'),
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final inst in instances.take(8))
                  _ActionChip(
                    label: '#${inst.instanceNumber} · ${inst.players}p'
                        '${inst.bots > 0 ? ' · ${inst.bots}b' : ''}',
                    enabled: !joining && type != RoomType.simple,
                    onTap: () => unawaited(onJoinInstance(type, inst)),
                    accent: accent,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingsCard extends StatelessWidget {
  const _RankingsCard({
    required this.rankings,
    required this.liveRadii,
  });

  final List<GameTrialRankingRow> rankings;
  final Map<String, double> liveRadii;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AdminTheme.panel(
        borderColor: const Color(0xFFFF3355).withValues(alpha: 0.28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('admin_game_trial_rankings_title'),
            style: const TextStyle(
              color: Color(0xFFFF5577),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lang.t('admin_game_trial_rankings_hint'),
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          if (rankings.isEmpty)
            Text(
              lang.t('admin_game_trial_rankings_empty'),
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 12,
              ),
            )
          else
            for (var i = 0; i < rankings.take(20).length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _RankRow(
                rank: i + 1,
                row: rankings[i],
                liveRadius: liveRadii[rankings[i].userId],
              ),
            ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.row,
    this.liveRadius,
  });

  final int rank;
  final GameTrialRankingRow row;
  final double? liveRadius;

  @override
  Widget build(BuildContext context) {
    final status = row.queued
        ? 'Q'
        : row.inHardcore
            ? '●'
            : '○';
    final radius = liveRadius ?? row.currentRadius?.toDouble();
    final showRadius = radius != null && radius > 0 && (row.inRoom || row.inHardcore);
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            row.username,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            color: row.inHardcore
                ? _trialAccent
                : row.queued
                    ? AdminTheme.warning
                    : AdminTheme.textMuted,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        if (showRadius) ...[
          const SizedBox(width: 8),
          AdminPlayerRadiusLabel(radius: radius, accent: _trialAccent),
        ],
        const SizedBox(width: 10),
        Text(
          '${row.diamonds}♦ · ${row.trophies}/10 · ${row.hardcorePoints} HC',
          style: const TextStyle(
            color: Color(0xFFFF5577),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AdminTheme.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('admin_game_trial_events'),
            style: const TextStyle(
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Text(
              lang.t('admin_game_trial_events_empty'),
              style: const TextStyle(
                color: AdminTheme.textMuted,
                fontSize: 12,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: events.length.clamp(0, 40),
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  return Text(
                    events[i],
                    style: const TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
