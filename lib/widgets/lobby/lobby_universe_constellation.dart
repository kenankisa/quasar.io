import 'dart:async';

import 'package:flutter/material.dart';
import '../../utils/lang_scope.dart';

import '../../utils/diamond_ui.dart';
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
import '../wormhole_portal.dart';
import 'lobby_constellation_metrics.dart';
import 'lobby_universe_cards.dart';
import 'lobby_universe_portal.dart';

/// Scattered wormhole constellation — fixed field, responsive anchors.
class LobbyUniverseConstellation extends StatefulWidget {
  const LobbyUniverseConstellation({
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
  final Future<void> Function(RoomType type, WormholePortalFocal? focal)
      onRoomSelected;
  final int trophyWinsSimple;
  final int trophyWinsNormal;
  final int trophyWinsElite;
  final int trophyWinsUnique;
  final DateTime? hardcoreCooldownUntil;
  final bool hardcoreCooldownBypassed;

  @override
  State<LobbyUniverseConstellation> createState() =>
      _LobbyUniverseConstellationState();
}

class _LobbyUniverseConstellationState extends State<LobbyUniverseConstellation> {
  Timer? _cooldownTick;

  @override
  void initState() {
    super.initState();
    _syncCooldownTimer();
  }

  @override
  void didUpdateWidget(covariant LobbyUniverseConstellation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hardcoreCooldownUntil != widget.hardcoreCooldownUntil ||
        oldWidget.hardcoreCooldownBypassed != widget.hardcoreCooldownBypassed) {
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
    if (_hardcoreCooldownRemaining() != null) {
      _cooldownTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_hardcoreCooldownRemaining() == null) {
          _cooldownTick?.cancel();
          _cooldownTick = null;
        }
      });
    }
  }

  int get _totalTrophies =>
      widget.trophyWinsSimple +
      widget.trophyWinsNormal +
      widget.trophyWinsElite +
      widget.trophyWinsUnique;

  int _trophiesFor(RoomType type) => switch (type) {
        RoomType.simple => widget.trophyWinsSimple,
        RoomType.normal => widget.trophyWinsNormal,
        RoomType.elite => widget.trophyWinsElite,
        RoomType.unique => widget.trophyWinsUnique,
        RoomType.hardcore => 0,
      };

  bool _isLocked(RoomType type) {
    return !RoomTypeLobby.isLobbyAccessible(
      type,
      tutorialCompleted: widget.tutorialCompleted,
      gamesWon: widget.gamesWon,
      diamonds: widget.diamonds,
      universeTrophies: _totalTrophies,
      isAdmin: AdminAccess.isCurrentUserAdmin,
    );
  }

  String? _lockKey(RoomType type) {
    return RoomTypeLobby.lobbyLockKey(
      type,
      tutorialCompleted: widget.tutorialCompleted,
      gamesWon: widget.gamesWon,
      diamonds: widget.diamonds,
      universeTrophies: _totalTrophies,
      isAdmin: AdminAccess.isCurrentUserAdmin,
    );
  }

  Duration? _hardcoreCooldownRemaining() {
    if (widget.hardcoreCooldownBypassed) return null;
    final until = widget.hardcoreCooldownUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? null : left;
  }

  LobbyNextGoal? _resolveGoal() {
    return LobbyNextGoal.resolve(
      tutorialCompleted: widget.tutorialCompleted,
      gamesWon: widget.gamesWon,
      diamonds: widget.diamonds,
      universeTrophies: _totalTrophies,
    );
  }

  Future<void> _handlePortalEnter(
    BuildContext context,
    RoomType type,
    WormholePortalFocal focal,
  ) async {
    final lang = context.lang;
    final locked = _isLocked(type);
    final lockKey = _lockKey(type);

    if (type == RoomType.hardcore) {
      final cooldown = _hardcoreCooldownRemaining();
      if (!locked && cooldown != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hardcoreLobbyCooldownLabel(lang, cooldown)),
          ),
        );
        return;
      }
    }

    if (locked) {
      final message = _lockMessage(lang, type, lockKey);
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }

    await widget.onRoomSelected(type, focal);
  }

  String? _lockMessage(LanguageService lang, RoomType type, String? lockKey) {
    if (lockKey == 'lobby_first_login_lock') {
      return lang.t('lobby_first_login_lock');
    }
    if (type == RoomType.hardcore && lockKey == 'room_hardcore_lock') {
      final cap = RoomTypeLobby.hardcoreTrophyRequirement;
      final earned = _totalTrophies.clamp(0, cap);
      return lang
          .t('room_hardcore_lock')
          .replaceAll('{earned}', '$earned')
          .replaceAll('{cap}', '$cap');
    }
    final required = type.requiredDiamonds;
    if (required > 0 && lockKey != null) {
      return '${lang.t('room_entry_cost_prefix').replaceAll('{count}', '$required')}${lang.t('room_entry_cost_suffix')}';
    }
    return null;
  }

  String? _portalSubtitle(LanguageService lang, RoomType type) {
    final lockKey = _lockKey(type);
    if (type == RoomType.hardcore) {
      if (lockKey == 'lobby_first_login_lock') {
        return lang.t('lobby_first_login_lock');
      }
      if (_isLocked(type)) {
        final cap = RoomTypeLobby.hardcoreTrophyRequirement;
        final earned = _totalTrophies.clamp(0, cap);
        return lang
            .t('room_hardcore_lock')
            .replaceAll('{earned}', '$earned')
            .replaceAll('{cap}', '$cap');
      }
      final cooldown = _hardcoreCooldownRemaining();
      if (cooldown != null) {
        return hardcoreLobbyCooldownLabel(lang, cooldown);
      }
    }
    return _lockLabel(lang, lockKey, type);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppEconomyConfigService.instance,
        LobbyRoomStatsService.instance,
      ]),
      builder: (context, _) {
        final lang = context.lang;
        final r = ResponsiveLayout.of(context);
        final goal = _resolveGoal();
        final recommendSimple = !_isLocked(RoomType.simple) &&
            FirstMatchTuning.shouldRecommendSimpleRoom(
              tutorialCompleted: widget.tutorialCompleted,
              gamesWon: widget.gamesWon,
            );

        return LayoutBuilder(
          builder: (context, constraints) {
            final area = Size(constraints.maxWidth, constraints.maxHeight);
            final slots = LobbyConstellationMetrics.resolve(
              area: area,
              responsive: r,
            );

            return SizedBox(
              width: area.width,
              height: area.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final slot in slots)
                  _positionedPortal(
                    context: context,
                    lang: lang,
                    slot: slot,
                    stats: LobbyRoomStatsService.instance.statsFor(
                      slot.anchor.roomType,
                    ),
                    recommendSimple: recommendSimple,
                  ),
                if (goal != null)
                  Positioned(
                    top: r.h(6),
                    left: r.w(10),
                    right: r.w(10),
                    child: _ConstellationGoalChip(
                      goal: goal,
                      onTrainingTap: goal.kind == LobbyNextGoalKind.training
                          ? () => widget.onRoomSelected(RoomType.simple, null)
                          : null,
                    ),
                  ),
              ],
            ),
            );
          },
        );
      },
    );
  }

  Widget _positionedPortal({
    required BuildContext context,
    required LanguageService lang,
    required ResolvedPortalSlot slot,
    required RoomLobbyStats stats,
    required bool recommendSimple,
  }) {
    final type = slot.anchor.roomType;
    final locked = _isLocked(type);
    final hardcoreCooldown = type == RoomType.hardcore
        ? _hardcoreCooldownRemaining()
        : null;
    final hardcoreMuted = type == RoomType.hardcore &&
        (locked || hardcoreCooldown != null);

    final titleKey = LobbyNextGoal.titleKeyFor(type);
    final trophySlots = type == RoomType.hardcore
        ? RoomTypeLobby.hardcoreTrophyRequirement
        : type.trophySlotCount;
    final trophyLit = type == RoomType.hardcore
        ? _totalTrophies.clamp(0, RoomTypeLobby.hardcoreTrophyRequirement)
        : _trophiesFor(type);

    return Positioned(
      left: slot.center.dx - slot.hitDiameter / 2,
      top: slot.center.dy - slot.hitDiameter / 2,
      child: LobbyUniversePortal(
        roomType: type,
        diameter: slot.portalDiameter,
        hitDiameter: slot.hitDiameter,
        labelMaxWidth: slot.labelMaxWidth,
        title: lang.t(titleKey),
        playerLabel: _playerLabel(stats, type),
        portalAnimation: widget.portalAnimation,
        locked: hardcoreMuted || locked,
        recommended: type == RoomType.simple && recommendSimple,
        subtitle: _portalSubtitle(lang, type),
        trophyLit: trophyLit,
        trophySlots: trophySlots,
        depthOpacity: slot.depthOpacity,
        onEnter: (focal) => _handlePortalEnter(context, type, focal),
        onInfo: () => showUniverseInfoSheet(context, type),
      ),
    );
  }
}

class _ConstellationGoalChip extends StatelessWidget {
  const _ConstellationGoalChip({
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

    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(8)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: backdrop[2].withValues(alpha: 0.88),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _iconFor(goal),
            color: accent,
            size: r.sp(16),
          ),
          SizedBox(width: r.w(8)),
          Expanded(
            child: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: r.sp(11.5),
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          if (onTrainingTap != null) ...[
            SizedBox(width: r.w(6)),
            LobbyPlayChip(
              accent: accent,
              label: lang.t('lobby_play'),
              compact: true,
            ),
          ],
        ],
      ),
    );

    if (onTrainingTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTrainingTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }

  IconData _iconFor(LobbyNextGoal goal) => switch (goal.kind) {
        LobbyNextGoalKind.training => Icons.school_outlined,
        LobbyNextGoalKind.diamonds => kDiamondIcon,
        LobbyNextGoalKind.trophies => Icons.emoji_events_outlined,
      };
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
