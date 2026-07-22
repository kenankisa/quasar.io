import 'package:flutter/material.dart';

import '../game/models/room_leaderboard.dart';
import '../game/room_type.dart';
import '../services/lang_service.dart';
import '../utils/match_time.dart';
import '../utils/player_rank.dart';
import 'bot_name_badge.dart';
import '../utils/responsive_layout.dart';

/// Tracks the rendered HUD height for overlay positioning.
class GameHudMetrics {
  GameHudMetrics._();

  static final ValueNotifier<double> toolbarHeight = ValueNotifier(96);

  static double totalTopInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + toolbarHeight.value;
}

/// Cosmic top HUD — header + podium row + optional local-player row.
class GameHudOverlay extends StatelessWidget {
  const GameHudOverlay({
    super.key,
    required this.entries,
    required this.roomType,
    this.roomInstanceNumber,
    this.isLoadTestRoom = false,
    this.matchElapsed = 0,
    this.alivePlayerCount = 0,
    this.aliveBotCount = 0,
    this.onBack,
  });

  final List<LeaderboardEntry> entries;
  final RoomType roomType;
  final int? roomInstanceNumber;
  final bool isLoadTestRoom;
  final double matchElapsed;
  final int alivePlayerCount;
  final int aliveBotCount;
  final VoidCallback? onBack;

  static const int topRowCount = 3;

  static const _void = Color(0xFF020208);
  static const _surface = Color(0xFF0A0A1A);
  static const _panel = Color(0xFF12122A);
  static const _cyan = Color(0xFF00F0FF);

  static double totalTopInset(BuildContext context) =>
      GameHudMetrics.totalTopInset(context);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final layout = layoutRoomLeaderboard(entries, maxTop: topRowCount);
    final topRow = layout.top;
    final sideEntry = layout.side;
    final roomAccent = _roomAccent(roomType);

    final hPad = r.w(10);
    final vPad = r.w(6);
    final rowGap = r.w(5);

    return MeasureSize(
      onChange: (size) {
        if ((GameHudMetrics.toolbarHeight.value - size.height).abs() > 0.5) {
          GameHudMetrics.toolbarHeight.value = size.height;
        }
      },
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _panel.withValues(alpha: 0.97),
                _surface.withValues(alpha: 0.96),
                _void.withValues(alpha: 0.92),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border(
              bottom: BorderSide(
                color: _cyan.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: _cyan.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: roomAccent.withValues(alpha: 0.06),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HudHeaderRow(
                    matchElapsed: matchElapsed,
                    roomType: roomType,
                    roomInstanceNumber: roomInstanceNumber,
                    isLoadTestRoom: isLoadTestRoom,
                    alivePlayerCount: alivePlayerCount,
                    aliveBotCount: aliveBotCount,
                    onBack: onBack,
                  ),
                  SizedBox(height: rowGap),
                  _LeaderboardGrid(
                    topRow: topRow,
                    sideEntry: sideEntry,
                    roomType: roomType,
                    rowGap: rowGap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top 3 + optional side slot — all in one row.
class _LeaderboardGrid extends StatelessWidget {
  const _LeaderboardGrid({
    required this.topRow,
    required this.sideEntry,
    required this.roomType,
    required this.rowGap,
  });

  final List<LeaderboardEntry> topRow;
  final LeaderboardEntry? sideEntry;
  final RoomType roomType;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    // Side slot only when needed — keeps three wide columns on small phones.
    final slots = <LeaderboardEntry?>[
      for (var i = 0; i < 3; i++) i < topRow.length ? topRow[i] : null,
      if (sideEntry != null) sideEntry,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < slots.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : rowGap),
              child: slots[i] != null
                  ? _PodiumCard(
                      entry: slots[i]!,
                      roomType: roomType,
                      compact: slots.length > 3,
                    )
                  : _EmptyPodiumSlot(),
            ),
          ),
      ],
    );
  }
}

/// Row 1 — back, title, timer, room (responsive).
class _HudHeaderRow extends StatelessWidget {
  const _HudHeaderRow({
    required this.matchElapsed,
    required this.roomType,
    this.roomInstanceNumber,
    this.isLoadTestRoom = false,
    required this.alivePlayerCount,
    required this.aliveBotCount,
    this.onBack,
  });

  final double matchElapsed;
  final RoomType roomType;
  final int? roomInstanceNumber;
  final bool isLoadTestRoom;
  final int alivePlayerCount;
  final int aliveBotCount;
  final VoidCallback? onBack;

  static const _twoLineBreakpoint = 400.0;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final lang = LanguageService.instance;
    final roomAccent = _roomAccent(roomType);
    final title = lang.t('leaderboard_title');

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoLine =
            constraints.maxWidth < _twoLineBreakpoint || r.isCompact;
        final meta = _HudMetaChips(
          matchElapsed: matchElapsed,
          roomType: roomType,
          roomInstanceNumber: roomInstanceNumber,
          isLoadTestRoom: isLoadTestRoom,
          alivePlayerCount: alivePlayerCount,
          aliveBotCount: aliveBotCount,
          chipGap: r.w(twoLine ? 5 : 6),
        );
        final leading = _HudLeadingSection(
          onBack: onBack,
          roomAccent: roomAccent,
          title: title,
        );

        if (twoLine) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leading,
              SizedBox(height: r.w(4)),
              LayoutBuilder(
                builder: (context, metaConstraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: metaConstraints.maxWidth,
                      ),
                      child: meta,
                    ),
                  );
                },
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              flex: 2,
              fit: FlexFit.loose,
              child: leading,
            ),
            SizedBox(width: r.w(4)),
            Flexible(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: meta,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HudLeadingSection extends StatelessWidget {
  const _HudLeadingSection({
    required this.roomAccent,
    required this.title,
    this.onBack,
  });

  final Color roomAccent;
  final String title;
  final VoidCallback? onBack;

  static const _cyan = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);

    return Row(
      children: [
        if (onBack != null) ...[
          _HudBackButton(onPressed: onBack!),
          SizedBox(width: r.w(2)),
        ],
        Container(
          width: 3,
          height: r.h(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_cyan, roomAccent.withValues(alpha: 0.7)],
            ),
            boxShadow: [
              BoxShadow(
                color: _cyan.withValues(alpha: 0.45),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        SizedBox(width: r.w(6)),
        Icon(
          Icons.leaderboard_rounded,
          size: r.sp(14),
          color: _cyan,
        ),
        SizedBox(width: r.w(5)),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _cyan,
              fontSize: r.sp(10),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              shadows: [
                Shadow(
                  color: _cyan.withValues(alpha: 0.55),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HudMetaChips extends StatelessWidget {
  const _HudMetaChips({
    required this.matchElapsed,
    required this.roomType,
    this.roomInstanceNumber,
    this.isLoadTestRoom = false,
    required this.alivePlayerCount,
    required this.aliveBotCount,
    required this.chipGap,
  });

  final double matchElapsed;
  final RoomType roomType;
  final int? roomInstanceNumber;
  final bool isLoadTestRoom;
  final int alivePlayerCount;
  final int aliveBotCount;
  final double chipGap;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _PopulationChip(
        playerCount: alivePlayerCount,
        botCount: aliveBotCount,
      ),
      _MatchTimerChip(elapsed: matchElapsed),
      _RoomBadge(
        roomType: roomType,
        instanceNumber: roomInstanceNumber,
        isLoadTest: isLoadTestRoom,
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) SizedBox(width: chipGap),
          chips[i],
        ],
      ],
    );
  }
}

class _HudBackButton extends StatelessWidget {
  const _HudBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: r.w(30),
        minHeight: r.w(30),
      ),
      icon: Icon(
        Icons.arrow_back_ios_new,
        color: const Color(0xFF00F0FF),
        size: r.sp(17),
      ),
    );
  }
}

/// Podium card — rank left of name, stats below.
class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.roomType,
    this.compact = false,
  });

  final LeaderboardEntry entry;
  final RoomType roomType;
  final bool compact;

  static const _cyan = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final rank = entry.rank ?? 0;
    final medal = _medalColor(rank);
    final isLocal = entry.isLocal;
    final isFirst = rank == 1;
    final reward = roomType.diamondRewardForPlacement(rank);
    final accent = isLocal ? _cyan : (medal ?? Colors.white);
    final highlight = isLocal || entry.isPinnedLocal;

    final displayName = entry.name;

    final nameStyle = TextStyle(
      color: isLocal
          ? Colors.white
          : Colors.white.withValues(alpha: 0.92),
      fontSize: r.sp(12),
      fontWeight: isLocal || isFirst ? FontWeight.w700 : FontWeight.w600,
      height: 1.15,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: highlight ? 0.2 : (isFirst ? 0.14 : 0.07)),
            const Color(0xFF0A0A1A).withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(
          color: accent.withValues(
            alpha: highlight ? 0.55 : (isFirst ? 0.42 : 0.16),
          ),
          width: highlight || isFirst ? 1.2 : 1,
        ),
        boxShadow: highlight || isFirst
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: highlight ? 0.16 : 0.1),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.w(5),
          vertical: r.w(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RankLabel(
                  rank: rank,
                  isLocal: isLocal,
                  visible: entry.visible,
                ),
                SizedBox(width: r.w(4)),
                Expanded(
                  child: _PodiumNameCell(
                    entry: entry,
                    isLocal: isLocal,
                    displayName: displayName,
                    nameStyle: nameStyle,
                    compact: compact,
                  ),
                ),
              ],
            ),
            SizedBox(height: r.w(4)),
            _StatRow(
              mass: entry.radius,
              reward: reward,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Podium name line — plain flex layout, no FittedBox (avoids HUD layout crashes).
class _PodiumNameCell extends StatelessWidget {
  const _PodiumNameCell({
    required this.entry,
    required this.isLocal,
    required this.displayName,
    required this.nameStyle,
    required this.compact,
  });

  final LeaderboardEntry entry;
  final bool isLocal;
  final String displayName;
  final TextStyle nameStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);

    if (!entry.visible) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_rounded,
            size: r.sp(12),
            color: const Color(0xFF9C27B0).withValues(alpha: 0.8),
          ),
          SizedBox(width: r.w(3)),
          Text(
            '???',
            style: TextStyle(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.8),
              fontSize: r.sp(11),
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    final rankTier = !entry.isBot && entry.rankPoints != null
        ? playerRankForPoints(entry.rankPoints!)
        : null;
    final badgeSize = r.sp(11);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rankTier != null) ...[
          PlayerRankBadge(
            tier: rankTier,
            size: badgeSize,
            compact: true,
          ),
          SizedBox(height: r.h(2)),
        ],
        Text(
          displayName,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
      ],
    );
  }
}

class _RankLabel extends StatelessWidget {
  const _RankLabel({
    required this.rank,
    required this.isLocal,
    required this.visible,
  });

  final int rank;
  final bool isLocal;
  final bool visible;

  static const _cyan = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final medal = _medalColor(rank);
    final color = !visible
        ? Colors.white.withValues(alpha: 0.3)
        : (medal ?? (isLocal ? _cyan : Colors.white.withValues(alpha: 0.75)));

    return Text(
      '#$rank',
      style: TextStyle(
        color: color,
        fontSize: r.sp(13),
        fontWeight: FontWeight.w800,
        height: 1,
        shadows: medal != null && visible
            ? [
                Shadow(
                  color: medal.withValues(alpha: 0.55),
                  blurRadius: 7,
                ),
              ]
            : isLocal && visible
                ? [
                    Shadow(
                      color: _cyan.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : null,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.mass,
    required this.reward,
    required this.accent,
  });

  final double mass;
  final int reward;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);

    final massWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: r.sp(5),
          color: accent.withValues(alpha: 0.7),
        ),
        SizedBox(width: r.w(3)),
        Text(
          mass.toStringAsFixed(0),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: r.sp(10.5),
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    if (reward <= 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [massWidget],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        massWidget,
        SizedBox(width: r.w(4)),
        _DiamondRewardLabel(reward: reward, size: r.sp(10)),
      ],
    );
  }
}

class _EmptyPodiumSlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.015),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: SizedBox(height: r.h(52)),
    );
  }
}

class _PopulationChip extends StatelessWidget {
  const _PopulationChip({
    required this.playerCount,
    required this.botCount,
  });

  final int playerCount;
  final int botCount;

  static const _playerColor = Color(0xFF7CFFCB);
  static const _botColor = Color(0xFFFF8AD8);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final lang = LanguageService.instance;
    final compact = r.isCompact;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(compact ? 5 : 7),
        vertical: r.w(3),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_rounded,
            size: r.sp(12),
            color: _playerColor.withValues(alpha: 0.95),
          ),
          SizedBox(width: r.w(3)),
          Text(
            '$playerCount',
            style: TextStyle(
              color: _playerColor.withValues(alpha: 0.95),
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!compact) ...[
            SizedBox(width: r.w(4)),
            Text(
              lang.t('hud_population_players'),
              style: TextStyle(
                color: _playerColor.withValues(alpha: 0.72),
                fontSize: r.sp(9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(width: r.w(6)),
          Container(
            width: 1,
            height: r.h(12),
            color: Colors.white.withValues(alpha: 0.16),
          ),
          SizedBox(width: r.w(6)),
          Icon(
            Icons.smart_toy_rounded,
            size: r.sp(12),
            color: _botColor.withValues(alpha: 0.95),
          ),
          SizedBox(width: r.w(3)),
          Text(
            '$botCount',
            style: TextStyle(
              color: _botColor.withValues(alpha: 0.95),
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!compact) ...[
            SizedBox(width: r.w(4)),
            Text(
              lang.t('hud_population_bots'),
              style: TextStyle(
                color: _botColor.withValues(alpha: 0.72),
                fontSize: r.sp(9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchTimerChip extends StatelessWidget {
  const _MatchTimerChip({required this.elapsed});

  final double elapsed;

  static const _cyan = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final compact = r.isCompact;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(compact ? 5 : 7),
        vertical: r.w(3),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _cyan.withValues(alpha: 0.08),
        border: Border.all(color: _cyan.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: r.sp(12),
            color: _cyan.withValues(alpha: 0.9),
          ),
          SizedBox(width: r.w(4)),
          Text(
            formatMatchTime(elapsed),
            style: TextStyle(
              color: _cyan.withValues(alpha: 0.95),
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomBadge extends StatelessWidget {
  const _RoomBadge({
    required this.roomType,
    this.instanceNumber,
    this.isLoadTest = false,
  });

  final RoomType roomType;
  final int? instanceNumber;
  final bool isLoadTest;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final lang = LanguageService.instance;
    final accent = _roomAccent(roomType);
    final compact = r.isCompact;
    final label = _roomLabel(
      lang,
      roomType,
      instanceNumber,
      isLoadTest: isLoadTest,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(compact ? 6 : 8),
        vertical: r.w(3),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _roomIcon(roomType),
            size: r.sp(compact ? 12 : 13),
            color: accent.withValues(alpha: 0.95),
          ),
          SizedBox(width: r.w(4)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent.withValues(alpha: 0.95),
              fontSize: r.sp(compact ? 10 : 11),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondRewardLabel extends StatelessWidget {
  const _DiamondRewardLabel({
    required this.reward,
    this.size = 11,
  });

  final int reward;
  final double size;

  static const _color = Color(0xFF3DFF9A);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+$reward',
          style: TextStyle(
            color: _color,
            fontSize: size,
            fontWeight: FontWeight.w800,
            height: 1,
            shadows: [
              Shadow(
                color: _color.withValues(alpha: 0.35),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(width: size * 0.12),
        Icon(
          Icons.diamond_outlined,
          size: size + 1.5,
          color: const Color(0xFF00F0FF).withValues(alpha: 0.95),
        ),
      ],
    );
  }
}

Color? _medalColor(int rank) {
  return switch (rank) {
    1 => const Color(0xFFFFD700),
    2 => const Color(0xFFC0C0C0),
    3 => const Color(0xFFCD7F32),
    _ => null,
  };
}

String _roomLabel(
  LanguageService lang,
  RoomType type,
  int? instanceNumber, {
  bool isLoadTest = false,
}) {
  if (instanceNumber != null && type != RoomType.simple) {
    return type.instanceTitle(
      lang.t,
      number: instanceNumber,
      isLoadTest: isLoadTest,
    );
  }
  return lang.t(_roomTitleKey(type));
}

String _roomTitleKey(RoomType type) {
  switch (type) {
    case RoomType.simple:
      return 'room_simple_title';
    case RoomType.normal:
      return 'room_normal_title';
    case RoomType.elite:
      return 'room_elite_title';
    case RoomType.unique:
      return 'room_unique_title';
  }
}

Color _roomAccent(RoomType type) {
  switch (type) {
    case RoomType.simple:
      return const Color(0xFF00FF88);
    case RoomType.normal:
      return const Color(0xFF00F0FF);
    case RoomType.elite:
      return const Color(0xFFFF00AA);
    case RoomType.unique:
      return const Color(0xFFFF6600);
  }
}

IconData _roomIcon(RoomType type) {
  switch (type) {
    case RoomType.simple:
      return Icons.star_outline;
    case RoomType.normal:
      return Icons.grain;
    case RoomType.elite:
      return Icons.public;
    case RoomType.unique:
      return Icons.bolt;
  }
}
