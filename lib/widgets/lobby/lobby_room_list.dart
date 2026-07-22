import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/config/first_match_tuning.dart';
import '../../game/config/room_matchmaking.dart';
import '../../game/config/room_visual_theme.dart';
import '../../game/config/universe_palette.dart';
import '../../game/models/room_lobby_stats.dart';
import '../../game/room_type.dart';
import '../../services/lang_service.dart';
import '../../services/lobby_room_stats_service.dart';
import '../wormhole_portal.dart';

const _lobbyRooms = [
  LobbyRoomData(type: RoomType.simple, titleKey: 'room_simple_title'),
  LobbyRoomData(type: RoomType.normal, titleKey: 'room_normal_title'),
  LobbyRoomData(type: RoomType.elite, titleKey: 'room_elite_title'),
  LobbyRoomData(type: RoomType.unique, titleKey: 'room_unique_title'),
];

class LobbyRoomList extends StatelessWidget {
  const LobbyRoomList({
    super.key,
    required this.diamonds,
    required this.gamesWon,
    required this.tutorialCompleted,
    required this.portalAnimation,
    required this.onRoomSelected,
  });

  final int diamonds;
  final int gamesWon;
  final bool tutorialCompleted;
  final Animation<double> portalAnimation;
  final ValueChanged<RoomType> onRoomSelected;

  static const _rooms = _lobbyRooms;

  bool _isLocked(RoomType type) {
    return !RoomTypeLobby.isLobbyAccessible(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
      diamonds: diamonds,
    );
  }

  String? _lockKey(RoomType type) {
    return RoomTypeLobby.lobbyLockKey(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
      diamonds: diamonds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      itemCount: _rooms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final room = _rooms[index];
        final locked = _isLocked(room.type);
        final lockKey = _lockKey(room.type);
        return LobbyRoomCard(
          room: room,
          locked: locked,
          lockKey: lockKey,
          stats: LobbyRoomStatsService.instance.statsFor(room.type),
          recommended: !locked &&
              FirstMatchTuning.shouldRecommendSimpleRoom(
                tutorialCompleted: tutorialCompleted,
                gamesWon: gamesWon,
              ) &&
              room.type == RoomType.simple,
          portalAnimation: portalAnimation,
          onTap: locked ? null : () => onRoomSelected(room.type),
        );
      },
    );
  }
}

class LobbyRoomData {
  const LobbyRoomData({
    required this.type,
    required this.titleKey,
  });

  final RoomType type;
  final String titleKey;

  RoomVisualTheme get theme => RoomVisualTheme.forRoom(type);
  Color get accent => theme.accent;
  Color get secondary => theme.secondaryAccent;
  List<Color> get backdrop => UniversePalette.backdropColors(type);
  Color get washA => UniversePalette.washA(type);
  Color get washB => UniversePalette.washB(type);
}

class LobbyRoomCard extends StatelessWidget {
  const LobbyRoomCard({
    super.key,
    required this.room,
    required this.locked,
    this.lockKey,
    required this.stats,
    required this.recommended,
    required this.portalAnimation,
    required this.onTap,
  });

  final LobbyRoomData room;
  final bool locked;
  final String? lockKey;
  final RoomLobbyStats stats;
  final bool recommended;
  final Animation<double> portalAnimation;
  final VoidCallback? onTap;

  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final requiredDiamonds = room.type.requiredDiamonds;
    final isFirstLoginLock = lockKey == 'lobby_first_login_lock';
    final requirementPrefix = isFirstLoginLock
        ? lang.t('lobby_first_login_lock')
        : lang
            .t('room_entry_cost_prefix')
            .replaceAll('{count}', '$requiredDiamonds');
    final requirementSuffix =
        isFirstLoginLock ? '' : lang.t('room_entry_cost_suffix');
    final showDiamond = !isFirstLoginLock && requiredDiamonds > 0;

    // Soft static edge light — avoids rebuilding the whole card every tick.
    final glow = locked ? 0.0 : 0.2;

    return IgnorePointer(
      ignoring: locked,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: locked ? 0.72 : 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: room.accent.withValues(alpha: locked ? 0.22 : 0.42),
                  width: 1,
                ),
                boxShadow: locked
                    ? null
                    : [
                        BoxShadow(
                          color: room.accent.withValues(alpha: glow),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WormholeGateBadge(
                        roomType: room.type,
                        spin: portalAnimation,
                        locked: locked,
                        width: 118,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      room.backdrop[0].withValues(
                                        alpha: locked ? 0.55 : 0.92,
                                      ),
                                      room.backdrop[1],
                                      room.backdrop[2],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -28,
                              top: -36,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      room.washA.withValues(
                                        alpha: locked ? 0.1 : 0.28,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                14,
                                14,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lang.t(room.titleKey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: locked
                                                    ? Colors.white
                                                        .withValues(alpha: 0.55)
                                                    : Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                                height: 1.15,
                                              ),
                                            ),
                                            if (recommended) ...[
                                              const SizedBox(height: 6),
                                              LobbyRecommendedChip(
                                                accent: room.accent,
                                                label: lang.t(
                                                  'lobby_recommended_room',
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      LobbyPlayersPulse(
                                        stats: stats,
                                        accent: room.accent,
                                        locked: locked,
                                        isTraining:
                                            room.type == RoomType.simple,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LobbyRoomPresenceStrip(
                                    stats: stats,
                                    accent: room.accent,
                                    locked: locked,
                                    isTraining: room.type == RoomType.simple,
                                  ),
                                  const SizedBox(height: 12),
                                  if (locked)
                                    LobbyRoomLockBar(
                                      prefix: requirementPrefix,
                                      suffix: requirementSuffix,
                                      accent: room.accent,
                                      showDiamondIcon: showDiamond,
                                    )
                                  else
                                    LobbyRoomActionBar(
                                      roomType: room.type,
                                      accent: room.accent,
                                      playLabel: lang.t('lobby_play'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LobbyRecommendedChip extends StatelessWidget {
  const LobbyRecommendedChip({
    super.key,
    required this.accent,
    required this.label,
  });

  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class LobbyPlayersPulse extends StatelessWidget {
  const LobbyPlayersPulse({
    super.key,
    required this.stats,
    required this.accent,
    required this.locked,
    required this.isTraining,
  });

  final RoomLobbyStats stats;
  final Color accent;
  final bool locked;
  final bool isTraining;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final players = stats.players ?? 0;
    final capacity = isTraining
        ? math.max(players, 1)
        : RoomMatchmaking.playerCapacityForUniverses(stats.activeUniverses);
    final value = isTraining ? '$players' : '$players/$capacity';
    final opacity = locked ? 0.45 : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: locked ? 0.06 : 0.12),
        border: Border.all(
          color: accent.withValues(alpha: locked ? 0.18 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_rounded,
                size: 14,
                color: accent.withValues(alpha: opacity),
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: opacity),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            lang.t('lobby_stat_players_short').toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity * 0.5),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class LobbyRoomPresenceStrip extends StatelessWidget {
  const LobbyRoomPresenceStrip({
    super.key,
    required this.stats,
    required this.accent,
    required this.locked,
    required this.isTraining,
  });

  final RoomLobbyStats stats;
  final Color accent;
  final bool locked;
  final bool isTraining;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final opacity = locked ? 0.4 : 0.85;
    final lowPop = !locked &&
        !isTraining &&
        stats.activeUniverses > 0 &&
        (stats.players ?? 0) < 3;

    Widget chip({
      required IconData icon,
      required String value,
      required String label,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent.withValues(alpha: opacity * 0.9)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity * 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            chip(
              icon: Icons.hub_outlined,
              value: '${stats.activeUniverses}',
              label: lang.t('lobby_stat_universes_short'),
            ),
            chip(
              icon: Icons.smart_toy_outlined,
              value: '${stats.bots}',
              label: lang.t('lobby_stat_bots_short'),
            ),
          ],
        ),
        if (lowPop) ...[
          const SizedBox(height: 6),
          Text(
            lang.t('lobby_low_population_hint'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFFFC266).withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class LobbyRoomActionBar extends StatelessWidget {
  const LobbyRoomActionBar({
    super.key,
    required this.roomType,
    required this.accent,
    required this.playLabel,
  });

  final RoomType roomType;
  final Color accent;
  final String playLabel;

  static const _rewardColor = Color(0xFF3DFF9A);
  static const _penaltyColor = Color(0xFFFF5A6A);
  static const _mutedColor = Color(0xFF8A93A8);
  static const _diamondColor = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final required = roomType.requiredDiamonds;
    final r1 = roomType.diamondRewardForPlacement(1);
    final r2 = roomType.diamondRewardForPlacement(2);
    final r3 = roomType.diamondRewardForPlacement(3);
    final penalty = roomType.eliminationDiamondPenalty;

    InlineSpan diamond({double size = 11}) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(Icons.diamond_outlined, size: size, color: _diamondColor),
        ),
      );
    }

    final entryStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.72),
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final muted = TextStyle(
      color: _mutedColor,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final reward = TextStyle(
      color: _rewardColor,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final penaltyStyle = TextStyle(
      color: _penaltyColor,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

    final List<InlineSpan> meta = [];
    if (required <= 0) {
      meta.add(TextSpan(text: lang.t('room_entry_free'), style: entryStyle));
    } else {
      meta.addAll([
        TextSpan(text: '$required', style: entryStyle),
        diamond(size: 12),
      ]);
    }
    meta.addAll([
      TextSpan(text: '  ·  ', style: muted),
      TextSpan(text: '+$r1', style: reward),
      TextSpan(text: '/+$r2', style: reward),
      TextSpan(text: '/+$r3', style: reward),
      diamond(),
      TextSpan(text: '  ·  ', style: muted),
      if (penalty > 0) ...[
        TextSpan(text: '−$penalty', style: penaltyStyle),
        diamond(),
      ] else
        TextSpan(
          text: lang.t('room_elimination_none'),
          style: reward,
        ),
    ]);

    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: meta),
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.95),
                Color.lerp(accent, Colors.white, 0.12)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playLabel.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF05050C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Color(0xFF05050C),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LobbyRoomLockBar extends StatelessWidget {
  const LobbyRoomLockBar({
    super.key,
    required this.prefix,
    required this.suffix,
    required this.accent,
    required this.showDiamondIcon,
  });

  final String prefix;
  final String suffix;
  final Color accent;
  final bool showDiamondIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: accent.withValues(alpha: 0.9),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: accent.withValues(alpha: 0.95),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                children: [
                  TextSpan(text: prefix),
                  if (showDiamondIcon)
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.diamond_outlined,
                          size: 14,
                          color: Color(0xFF00F0FF),
                        ),
                      ),
                    ),
                  if (suffix.isNotEmpty) TextSpan(text: suffix),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
