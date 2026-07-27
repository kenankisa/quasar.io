import 'dart:async';

import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../game/config/first_match_tuning.dart';
import '../../game/config/lobby_next_goal.dart';
import '../../game/config/room_matchmaking.dart';
import '../../game/config/room_visual_theme.dart';
import '../../game/config/universe_palette.dart';
import '../../game/models/room_lobby_stats.dart';
import '../../game/room_type.dart';
import '../../services/admin_access.dart';
import '../../services/app_economy_config_service.dart';
import '../../services/lang_service.dart';
import '../../services/lobby_room_stats_service.dart';
import '../../utils/hardcore_cooldown.dart';
import '../../utils/responsive_layout.dart';
import '../universe_info_sheet.dart';
import 'lobby_universe_cards.dart';

/// Compact play-focused universe list for the redesigned lobby.
class LobbyCompactRoomList extends StatelessWidget {
  const LobbyCompactRoomList({
    super.key,
    required this.diamonds,
    required this.gamesWon,
    required this.tutorialCompleted,
    required this.portalAnimation,
    required this.onRoomSelected,
    this.trophyWinsSimple = 0,
    this.trophyWinsNormal = 0,
    this.trophyWinsElite = 0,
    this.trophyWinsUnique = 0,
    this.hardcoreCooldownUntil,
    this.hardcoreCooldownBypassed = false,
  });

  final int diamonds;
  final int gamesWon;
  final bool tutorialCompleted;
  final Animation<double> portalAnimation;
  final ValueChanged<RoomType> onRoomSelected;
  final int trophyWinsSimple;
  final int trophyWinsNormal;
  final int trophyWinsElite;
  final int trophyWinsUnique;
  final DateTime? hardcoreCooldownUntil;
  final bool hardcoreCooldownBypassed;

  int get _totalTrophies =>
      trophyWinsSimple +
      trophyWinsNormal +
      trophyWinsElite +
      trophyWinsUnique;

  int _trophiesFor(RoomType type) => switch (type) {
        RoomType.simple => trophyWinsSimple,
        RoomType.normal => trophyWinsNormal,
        RoomType.elite => trophyWinsElite,
        RoomType.unique => trophyWinsUnique,
        RoomType.hardcore => 0,
      };

  bool _isLocked(RoomType type) {
    return !RoomTypeLobby.isLobbyAccessible(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
      diamonds: diamonds,
      universeTrophies: _totalTrophies,
      isAdmin: AdminAccess.isCurrentUserAdmin,
    );
  }

  String? _lockKey(RoomType type) {
    return RoomTypeLobby.lobbyLockKey(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
      diamonds: diamonds,
      universeTrophies: _totalTrophies,
      isAdmin: AdminAccess.isCurrentUserAdmin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppEconomyConfigService.instance,
        LobbyRoomStatsService.instance,
      ]),
      builder: (context, _) {
        final goal = LobbyNextGoal.resolve(
          tutorialCompleted: tutorialCompleted,
          gamesWon: gamesWon,
          diamonds: diamonds,
          universeTrophies: _totalTrophies,
        );

        final r = ResponsiveLayout.of(context);
        final horizontal = r.isCompact ? 12.0 : 16.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 24),
          children: [
            if (goal != null)
              _GoalBanner(
                goal: goal,
                onTrainingTap: goal.kind == LobbyNextGoalKind.training
                    ? () => onRoomSelected(RoomType.simple)
                    : null,
              ),
            const SizedBox(height: 10),
            _DockRoomRow(
              locked: _isLocked(RoomType.simple),
              lockKey: _lockKey(RoomType.simple),
              stats: LobbyRoomStatsService.instance.statsFor(RoomType.simple),
              trophiesLit: _trophiesFor(RoomType.simple),
              portalAnimation: portalAnimation,
              recommended: !_isLocked(RoomType.simple) &&
                  FirstMatchTuning.shouldRecommendSimpleRoom(
                    tutorialCompleted: tutorialCompleted,
                    gamesWon: gamesWon,
                  ),
              onPlay: _isLocked(RoomType.simple)
                  ? null
                  : () => onRoomSelected(RoomType.simple),
              onInfo: () => showUniverseInfoSheet(context, RoomType.simple),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: r.h(168),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SectorRoomRow(
                      roomType: RoomType.normal,
                      sectorCode: 'SEC-07',
                      locked: _isLocked(RoomType.normal),
                      lockKey: _lockKey(RoomType.normal),
                      stats: LobbyRoomStatsService.instance.statsFor(
                        RoomType.normal,
                      ),
                      trophiesLit: _trophiesFor(RoomType.normal),
                      portalAnimation: portalAnimation,
                      onPlay: _isLocked(RoomType.normal)
                          ? null
                          : () => onRoomSelected(RoomType.normal),
                      onInfo: () =>
                          showUniverseInfoSheet(context, RoomType.normal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SectorRoomRow(
                      roomType: RoomType.elite,
                      sectorCode: 'SEC-12',
                      locked: _isLocked(RoomType.elite),
                      lockKey: _lockKey(RoomType.elite),
                      stats: LobbyRoomStatsService.instance.statsFor(
                        RoomType.elite,
                      ),
                      trophiesLit: _trophiesFor(RoomType.elite),
                      portalAnimation: portalAnimation,
                      onPlay: _isLocked(RoomType.elite)
                          ? null
                          : () => onRoomSelected(RoomType.elite),
                      onInfo: () =>
                          showUniverseInfoSheet(context, RoomType.elite),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AnomalyRoomRow(
              locked: _isLocked(RoomType.unique),
              lockKey: _lockKey(RoomType.unique),
              stats: LobbyRoomStatsService.instance.statsFor(RoomType.unique),
              trophiesLit: _trophiesFor(RoomType.unique),
              portalAnimation: portalAnimation,
              onPlay: _isLocked(RoomType.unique)
                  ? null
                  : () => onRoomSelected(RoomType.unique),
              onInfo: () => showUniverseInfoSheet(context, RoomType.unique),
            ),
            const LobbySingularityBreachDivider(),
            _HardcoreCompactRow(
              totalTrophies: _totalTrophies,
              locked: _isLocked(RoomType.hardcore),
              lockKey: _lockKey(RoomType.hardcore),
              stats: LobbyRoomStatsService.instance.statsFor(RoomType.hardcore),
              portalAnimation: portalAnimation,
              hardcoreCooldownUntil: hardcoreCooldownUntil,
              hardcoreCooldownBypassed: hardcoreCooldownBypassed,
              onPlay: _isLocked(RoomType.hardcore)
                  ? null
                  : () => onRoomSelected(RoomType.hardcore),
              onInfo: () => showUniverseInfoSheet(context, RoomType.hardcore),
            ),
          ],
        );
      },
    );
  }
}

class _GoalBanner extends StatelessWidget {
  const _GoalBanner({
    required this.goal,
    this.onTrainingTap,
  });

  final LobbyNextGoal goal;
  final VoidCallback? onTrainingTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final theme = RoomVisualTheme.forRoom(goal.targetRoom);
    final accent = theme.accent;
    final backdrop = UniversePalette.backdropColors(goal.targetRoom);
    final roomTitle = lang.t(LobbyNextGoal.titleKeyFor(goal.targetRoom));

    final body = switch (goal.kind) {
      LobbyNextGoalKind.training => lang
          .t('lobby_next_goal_training')
          .replaceAll('{room}', roomTitle),
      LobbyNextGoalKind.diamonds => lang
          .t('lobby_next_goal_diamonds')
          .replaceAll('{count}', '${goal.deficit}')
          .replaceAll('{room}', roomTitle),
      LobbyNextGoalKind.trophies => lang
          .t('lobby_next_goal_trophies')
          .replaceAll('{remaining}', '${goal.deficit}')
          .replaceAll('{room}', roomTitle),
    };

    final tappable = onTrainingTap != null;
    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(11)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backdrop[0].withValues(alpha: 0.85),
            backdrop[2],
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.35),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              _iconFor(goal),
              color: accent,
              size: r.sp(17),
            ),
          ),
          SizedBox(width: r.w(10)),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: r.sp(13),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          if (tappable)
            LobbyPlayChip(accent: accent, label: lang.t('lobby_play')),
        ],
      ),
    );

    if (!tappable) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTrainingTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }

  IconData _iconFor(LobbyNextGoal goal) => switch (goal.kind) {
        LobbyNextGoalKind.training => Icons.school_outlined,
        LobbyNextGoalKind.diamonds => Icons.diamond_outlined,
        LobbyNextGoalKind.trophies => Icons.emoji_events_outlined,
      };
}

class _DockRoomRow extends StatelessWidget {
  const _DockRoomRow({
    required this.locked,
    this.lockKey,
    required this.stats,
    required this.trophiesLit,
    required this.portalAnimation,
    required this.recommended,
    required this.onPlay,
    required this.onInfo,
  });

  final bool locked;
  final String? lockKey;
  final RoomLobbyStats stats;
  final int trophiesLit;
  final Animation<double> portalAnimation;
  final bool recommended;
  final VoidCallback? onPlay;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return LobbyDockUniverseCard(
      roomType: RoomType.simple,
      title: lang.t('room_simple_title'),
      locked: locked,
      portalAnimation: portalAnimation,
      playerLabel: _playerLabel(stats, RoomType.simple),
      trophyLit: trophiesLit,
      trophySlots: RoomType.simple.trophySlotCount,
      playLabel: lang.t('lobby_play'),
      recommended: recommended,
      lockText: _lockLabel(lang, lockKey, RoomType.simple),
      onInfo: onInfo,
      onPlay: onPlay,
    );
  }
}

class _SectorRoomRow extends StatelessWidget {
  const _SectorRoomRow({
    required this.roomType,
    required this.sectorCode,
    required this.locked,
    this.lockKey,
    required this.stats,
    required this.trophiesLit,
    required this.portalAnimation,
    required this.onPlay,
    required this.onInfo,
  });

  final RoomType roomType;
  final String sectorCode;
  final bool locked;
  final String? lockKey;
  final RoomLobbyStats stats;
  final int trophiesLit;
  final Animation<double> portalAnimation;
  final VoidCallback? onPlay;
  final VoidCallback onInfo;

  String get _titleKey => switch (roomType) {
        RoomType.normal => 'room_normal_title',
        RoomType.elite => 'room_elite_title',
        _ => 'room_normal_title',
      };

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return LobbySectorUniverseCard(
      roomType: roomType,
      title: lang.t(_titleKey),
      sectorCode: sectorCode,
      locked: locked,
      portalAnimation: portalAnimation,
      playerLabel: _playerLabel(stats, roomType),
      trophyLit: trophiesLit,
      trophySlots: roomType.trophySlotCount,
      playLabel: lang.t('lobby_play'),
      lockText: _lockLabel(lang, lockKey, roomType),
      onInfo: onInfo,
      onPlay: onPlay,
    );
  }
}

class _AnomalyRoomRow extends StatelessWidget {
  const _AnomalyRoomRow({
    required this.locked,
    this.lockKey,
    required this.stats,
    required this.trophiesLit,
    required this.portalAnimation,
    required this.onPlay,
    required this.onInfo,
  });

  final bool locked;
  final String? lockKey;
  final RoomLobbyStats stats;
  final int trophiesLit;
  final Animation<double> portalAnimation;
  final VoidCallback? onPlay;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return LobbyAnomalyUniverseCard(
      roomType: RoomType.unique,
      title: lang.t('room_unique_title'),
      locked: locked,
      portalAnimation: portalAnimation,
      playerLabel: _playerLabel(stats, RoomType.unique),
      trophyLit: trophiesLit,
      trophySlots: RoomType.unique.trophySlotCount,
      playLabel: lang.t('lobby_play'),
      lockText: _lockLabel(lang, lockKey, RoomType.unique),
      onInfo: onInfo,
      onPlay: onPlay,
    );
  }
}

String _playerLabel(RoomLobbyStats stats, RoomType type) {
  final isTraining = type == RoomType.simple;
  final players = type == RoomType.hardcore && stats.hardcoreSeatOccupancy != null
      ? stats.hardcoreSeatOccupancy!
      : (stats.players ?? 0);
  if (isTraining) return '$players';
  final capacity = type == RoomType.hardcore && stats.hardcoreMaxSeats != null
      ? stats.hardcoreMaxSeats!
      : RoomMatchmaking.playerCapacityForUniverses(
          stats.activeUniverses,
          type: type,
        );
  return '$players/$capacity';
}

String? _lockLabel(LanguageService lang, String? lockKey, RoomType type) {
  if (lockKey == 'lobby_first_login_lock') {
    return lang.t('lobby_first_login_lock');
  }
  final required = type.requiredDiamonds;
  if (required > 0 && lockKey != null) {
    return '${lang.t('room_entry_cost_prefix').replaceAll('{count}', '$required')}${lang.t('room_entry_cost_suffix')}';
  }
  return null;
}

class _HardcoreCompactRow extends StatefulWidget {
  const _HardcoreCompactRow({
    required this.totalTrophies,
    required this.locked,
    this.lockKey,
    required this.stats,
    required this.portalAnimation,
    this.hardcoreCooldownUntil,
    this.hardcoreCooldownBypassed = false,
    required this.onPlay,
    required this.onInfo,
  });

  final int totalTrophies;
  final bool locked;
  final String? lockKey;
  final RoomLobbyStats stats;
  final Animation<double> portalAnimation;
  final DateTime? hardcoreCooldownUntil;
  final bool hardcoreCooldownBypassed;
  final VoidCallback? onPlay;
  final VoidCallback onInfo;

  @override
  State<_HardcoreCompactRow> createState() => _HardcoreCompactRowState();
}

class _HardcoreCompactRowState extends State<_HardcoreCompactRow> {
  Timer? _cooldownTick;

  @override
  void initState() {
    super.initState();
    _syncCooldownTimer();
  }

  @override
  void didUpdateWidget(covariant _HardcoreCompactRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hardcoreCooldownUntil != widget.hardcoreCooldownUntil ||
        oldWidget.hardcoreCooldownBypassed !=
            widget.hardcoreCooldownBypassed) {
      _syncCooldownTimer();
    }
  }

  @override
  void dispose() {
    _cooldownTick?.cancel();
    super.dispose();
  }

  void _syncCooldownTimer() {
    _cooldownTick?.cancel();
    if (_cooldownRemaining() != null) {
      _cooldownTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_cooldownRemaining() == null) {
          _cooldownTick?.cancel();
          _cooldownTick = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final cap = RoomTypeLobby.hardcoreTrophyRequirement;
    final earned = widget.totalTrophies.clamp(0, cap);
    final cooldown = _cooldownRemaining();
    final muted = widget.locked || cooldown != null;
    final players = widget.stats.hardcoreSeatOccupancy ?? 0;
    final capacity = widget.stats.hardcoreMaxSeats ?? 8;

    String? sub;
    if (widget.lockKey == 'lobby_first_login_lock') {
      sub = lang.t('lobby_first_login_lock');
    } else if (widget.locked) {
      sub = lang
          .t('room_hardcore_lock')
          .replaceAll('{earned}', '$earned')
          .replaceAll('{cap}', '$cap');
    } else if (cooldown != null) {
      sub = hardcoreLobbyCooldownLabel(lang, cooldown);
    }

    return LobbySingularityUniverseCard(
      title: lang.t('room_hardcore_title'),
      locked: muted,
      portalAnimation: widget.portalAnimation,
      playerLabel: '$players/$capacity',
      trophyLit: earned,
      trophySlots: cap,
      playLabel: lang.t('lobby_play'),
      subtitle: sub,
      onInfo: widget.onInfo,
      onPlay: muted ? null : widget.onPlay,
    );
  }

  Duration? _cooldownRemaining() {
    if (widget.hardcoreCooldownBypassed) return null;
    final until = widget.hardcoreCooldownUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? null : left;
  }
}
