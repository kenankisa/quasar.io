import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/config/hardcore_rules.dart';
import '../game/models/room_leaderboard.dart';
import '../game/room_type.dart';
import '../services/app_economy_config_service.dart';
import '../services/lang_service.dart';
import '../utils/match_time.dart';
import '../utils/diamond_ui.dart';
import '../utils/responsive_layout.dart';

/// Tracks the rendered HUD height for overlay positioning.
class GameHudMetrics {
  GameHudMetrics._();

  static final ValueNotifier<double> toolbarHeight = ValueNotifier(96);

  static double totalTopInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + toolbarHeight.value;
}

/// Match top HUD — meta row + live 6-player standings grid.
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
    this.hardcoreArenaActive = false,
    this.hardcoreVictoryBlockKey,
    this.onBack,
  });

  final List<LeaderboardEntry> entries;
  final RoomType roomType;
  final int? roomInstanceNumber;
  final bool isLoadTestRoom;
  final double matchElapsed;
  final int alivePlayerCount;
  final int aliveBotCount;
  /// Hardcore: ≥6 alive — full growth & top kill rewards.
  final bool hardcoreArenaActive;
  /// Hardcore: lang key when low-pop size cap applies.
  final String? hardcoreVictoryBlockKey;
  final VoidCallback? onBack;

  static const int standingsCount = 6;
  static const int standingsRows = 3;

  static const _panel = Color(0xFF0C0C16);

  static double totalTopInset(BuildContext context) =>
      GameHudMetrics.totalTopInset(context);

  static String _hardcoreTooltip(String key) {
    final lang = LanguageService.instance;
    final econ = AppEconomyConfigService.instance.config;
    return lang
        .t(key)
        .replaceAll('{minAlive}', '${econ.hardcoreArenaMinAlive}')
        .replaceAll('{cap}', '${HardcoreRules.liveLowPopRadiusCap.round()}')
        .replaceAll('{victory}', '${HardcoreRules.victoryRadius.round()}')
        .replaceAll('{kill}', '${econ.rewardHardcoreKill}')
        .replaceAll('{elim}', '${econ.penaltyHardcore}');
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final layout = layoutRoomLeaderboard(entries, maxTop: standingsCount);
    final standings = layout.top;
    final roomAccent = _roomAccent(roomType);

    final hPad = r.w(8);
    final vPad = r.w(5);
    final rowGap = r.w(4);

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
            color: _panel.withValues(alpha: 0.88),
            border: Border(
              bottom: BorderSide(
                color: roomAccent.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
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
                    hardcoreArenaActive: hardcoreArenaActive,
                    hardcoreVictoryBlockKey: hardcoreVictoryBlockKey,
                    onBack: onBack,
                  ),
                  SizedBox(height: rowGap),
                  _StandingsPanel(
                    entries: standings,
                    roomType: roomType,
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

/// 3 rows × 2 columns — ranks 1–3 left, 4–6 right.
class _StandingsPanel extends StatelessWidget {
  const _StandingsPanel({
    required this.entries,
    required this.roomType,
  });

  final List<LeaderboardEntry> entries;
  final RoomType roomType;

  static const _slotCount = GameHudOverlay.standingsCount;
  static const _rowCount = GameHudOverlay.standingsRows;

  @override
  Widget build(BuildContext context) {
    final slots = List<LeaderboardEntry?>.filled(_slotCount, null);
    for (var i = 0; i < entries.length && i < _slotCount; i++) {
      slots[i] = entries[i];
    }

    final left = slots.sublist(0, _rowCount);
    final right = slots.sublist(_rowCount, _slotCount);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StandingsColumn(
                slots: left,
                roomType: roomType,
              ),
            ),
            Container(
              width: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            Expanded(
              child: _StandingsColumn(
                slots: right,
                roomType: roomType,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingsColumn extends StatelessWidget {
  const _StandingsColumn({
    required this.slots,
    required this.roomType,
  });

  final List<LeaderboardEntry?> slots;
  final RoomType roomType;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          if (slots[i] != null)
            _StandingsRow(
              entry: slots[i]!,
              roomType: roomType,
              isPinnedLocal: slots[i]!.isPinnedLocal,
              dense: true,
            )
          else
            const _StandingsEmptyRow(dense: true),
        ],
      ],
    );
  }
}

class _StandingsEmptyRow extends StatelessWidget {
  const _StandingsEmptyRow({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return SizedBox(height: r.h(dense ? 24 : 26));
  }
}

/// Single standings line — rank, name, size, reward.
class _StandingsRow extends StatelessWidget {
  const _StandingsRow({
    required this.entry,
    required this.roomType,
    this.isPinnedLocal = false,
    this.dense = false,
  });

  final LeaderboardEntry entry;
  final RoomType roomType;
  final bool isPinnedLocal;
  final bool dense;

  static const _localAccent = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final lang = context.lang;
    final rank = entry.rank ?? 0;
    final medal = _medalColor(rank);
    final isLocal = entry.isLocal || isPinnedLocal;
    final reward = roomType.diamondRewardForPlacement(rank);
    final rankColor = medal ??
        (isLocal ? _localAccent : Colors.white.withValues(alpha: 0.55));
    final rowHeight = r.h(dense ? 24 : 26);
    final hPad = r.w(dense ? 5 : 8);
    final rankWidth = r.w(dense ? 16 : 22);

    return ColoredBox(
      color: isLocal
          ? _localAccent.withValues(alpha: 0.07)
          : Colors.transparent,
      child: SizedBox(
        height: rowHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            children: [
              SizedBox(
                width: rankWidth,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: r.sp(dense ? 10.5 : 11.5),
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: _StandingsName(
                  entry: entry,
                  isLocal: isLocal,
                  youLabel: lang.t('leaderboard_you'),
                  dense: dense,
                ),
              ),
              Text(
                entry.visible ? entry.radius.toStringAsFixed(0) : '—',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isLocal ? 0.9 : 0.72),
                  fontSize: r.sp(dense ? 10 : 11),
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (reward > 0) ...[
                SizedBox(width: r.w(dense ? 3 : 6)),
                _DiamondRewardLabel(
                  reward: reward,
                  size: r.sp(dense ? 8.5 : 9.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingsName extends StatelessWidget {
  const _StandingsName({
    required this.entry,
    required this.isLocal,
    required this.youLabel,
    this.dense = false,
  });

  final LeaderboardEntry entry;
  final bool isLocal;
  final String youLabel;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final fontSize = r.sp(dense ? 10 : 11);

    if (!entry.visible) {
      return Text(
        '???',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.75),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final name = isLocal ? youLabel : entry.name;

    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isLocal
            ? Colors.white
            : Colors.white.withValues(alpha: 0.88),
        fontSize: fontSize,
        fontWeight: isLocal ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

/// Row 1 — back, universe title (left), match stats (right).
class _HudHeaderRow extends StatelessWidget {
  const _HudHeaderRow({
    required this.matchElapsed,
    required this.roomType,
    this.roomInstanceNumber,
    this.isLoadTestRoom = false,
    required this.alivePlayerCount,
    required this.aliveBotCount,
    this.hardcoreArenaActive = false,
    this.hardcoreVictoryBlockKey,
    this.onBack,
  });

  final double matchElapsed;
  final RoomType roomType;
  final int? roomInstanceNumber;
  final bool isLoadTestRoom;
  final int alivePlayerCount;
  final int aliveBotCount;
  final bool hardcoreArenaActive;
  final String? hardcoreVictoryBlockKey;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final roomTitle = _RoomBadge(
      roomType: roomType,
      instanceNumber: roomInstanceNumber,
      isLoadTest: isLoadTestRoom,
      asTitle: true,
    );
    final stats = _HudStatsChips(
      matchElapsed: matchElapsed,
      roomType: roomType,
      alivePlayerCount: alivePlayerCount,
      aliveBotCount: aliveBotCount,
      hardcoreArenaActive: hardcoreArenaActive,
      hardcoreVictoryBlockKey: hardcoreVictoryBlockKey,
      chipGap: r.w(r.isCompact ? 4 : 5),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          _HudBackButton(onPressed: onBack!),
          SizedBox(width: r.w(4)),
        ],
        Expanded(
          flex: r.isCompact ? 4 : 5,
          child: roomTitle,
        ),
        SizedBox(width: r.w(r.isCompact ? 4 : 6)),
        Flexible(
          flex: r.isCompact ? 7 : 6,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: stats,
            ),
          ),
        ),
      ],
    );
  }
}

/// Right-side match stats — timer, population, hardcore flags.
class _HudStatsChips extends StatelessWidget {
  const _HudStatsChips({
    required this.matchElapsed,
    required this.roomType,
    required this.alivePlayerCount,
    required this.aliveBotCount,
    this.hardcoreArenaActive = false,
    this.hardcoreVictoryBlockKey,
    required this.chipGap,
  });

  final double matchElapsed;
  final RoomType roomType;
  final int alivePlayerCount;
  final int aliveBotCount;
  final bool hardcoreArenaActive;
  final String? hardcoreVictoryBlockKey;
  final double chipGap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final chips = <Widget>[
      _MatchTimerChip(elapsed: matchElapsed),
      _PopulationChip(
        playerCount: alivePlayerCount,
        botCount: aliveBotCount,
        showBots: roomType.allowsBots,
      ),
      if (roomType == RoomType.hardcore)
        _HardcoreArenaChip(
          alive: alivePlayerCount,
          active: hardcoreArenaActive,
        ),
      if (hardcoreVictoryBlockKey != null)
        _HardcoreGateChip(label: lang.t(hardcoreVictoryBlockKey!)),
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
        minWidth: r.w(28),
        minHeight: r.w(28),
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: Icon(
        Icons.arrow_back_ios_new,
        color: Colors.white.withValues(alpha: 0.85),
        size: r.sp(15),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.child,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(7),
        vertical: r.w(3),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }
}

class _PopulationChip extends StatelessWidget {
  const _PopulationChip({
    required this.playerCount,
    required this.botCount,
    this.showBots = true,
  });

  final int playerCount;
  final int botCount;
  final bool showBots;

  static const _playerColor = Color(0xFF7CFFCB);
  static const _botColor = Color(0xFFFF8AD8);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);

    return _HudChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_rounded,
            size: r.sp(11),
            color: _playerColor.withValues(alpha: 0.9),
          ),
          SizedBox(width: r.w(3)),
          Text(
            '$playerCount',
            style: TextStyle(
              color: _playerColor.withValues(alpha: 0.9),
              fontSize: r.sp(11),
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (showBots) ...[
            SizedBox(width: r.w(5)),
            Icon(
              Icons.smart_toy_rounded,
              size: r.sp(11),
              color: _botColor.withValues(alpha: 0.9),
            ),
            SizedBox(width: r.w(3)),
            Text(
              '$botCount',
              style: TextStyle(
                color: _botColor.withValues(alpha: 0.9),
                fontSize: r.sp(11),
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HardcoreArenaChip extends StatelessWidget {
  const _HardcoreArenaChip({
    required this.alive,
    required this.active,
  });

  final int alive;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final lang = context.lang;
    final color = active ? const Color(0xFF7CFFCB) : const Color(0xFFFF8A5C);
    final minAlive =
        AppEconomyConfigService.instance.config.hardcoreArenaMinAlive;
    final popShort = lang
        .t('hardcore_arena_pop_short')
        .replaceAll('{alive}', '$alive')
        .replaceAll('{min}', '$minAlive');
    final label = active
        ? lang.t('hardcore_arena_active')
        : '${lang.t('hardcore_arena_passive')} · $popShort';

    return Tooltip(
      message: GameHudOverlay._hardcoreTooltip(
        active
            ? 'hardcore_arena_active_tooltip'
            : 'hardcore_arena_passive_tooltip',
      ),
      waitDuration: const Duration(milliseconds: 350),
      child: _HudChip(
        borderColor: color.withValues(alpha: 0.35),
        backgroundColor: color.withValues(alpha: 0.08),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: r.sp(10),
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _HardcoreGateChip extends StatelessWidget {
  const _HardcoreGateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    const color = Color(0xFFFF6688);

    return Tooltip(
      message: GameHudOverlay._hardcoreTooltip(
        'hardcore_gate_low_pop_cap_tooltip',
      ),
      waitDuration: const Duration(milliseconds: 350),
      child: _HudChip(
        borderColor: color.withValues(alpha: 0.4),
        backgroundColor: color.withValues(alpha: 0.1),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: r.sp(9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MatchTimerChip extends StatelessWidget {
  const _MatchTimerChip({required this.elapsed});

  final double elapsed;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);

    return _HudChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: r.sp(11),
            color: Colors.white.withValues(alpha: 0.55),
          ),
          SizedBox(width: r.w(3)),
          Text(
            formatMatchTime(elapsed),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: r.sp(11),
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
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
    this.asTitle = false,
  });

  final RoomType roomType;
  final int? instanceNumber;
  final bool isLoadTest;
  final bool asTitle;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final lang = context.lang;
    final accent = _roomAccent(roomType);
    final compact = r.isCompact;
    final label = _roomLabel(
      lang,
      roomType,
      instanceNumber,
      isLoadTest: isLoadTest,
    );

    final content = Row(
      mainAxisSize: asTitle ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(
          _roomIcon(roomType),
          size: r.sp(asTitle ? 13 : 11),
          color: accent.withValues(alpha: 0.95),
        ),
        SizedBox(width: r.w(asTitle ? 5 : 4)),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent.withValues(alpha: 0.95),
              fontSize: r.sp(asTitle ? (compact ? 11 : 12) : (compact ? 10 : 10.5)),
              fontWeight: asTitle ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: asTitle ? 0.15 : 0,
            ),
          ),
        ),
      ],
    );

    if (asTitle) {
      return content;
    }

    return _HudChip(
      borderColor: accent.withValues(alpha: 0.35),
      backgroundColor: accent.withValues(alpha: 0.08),
      child: content,
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

  @override
  Widget build(BuildContext context) {
    return DiamondAmount(
      amount: reward,
      prefix: '+',
      fontSize: size,
      fontWeight: FontWeight.w700,
      iconSize: size + 1.5,
      spacing: size * 0.12,
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
  if (type == RoomType.hardcore && !isLoadTest) {
    return lang.t('room_hardcore_title');
  }
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
    case RoomType.hardcore:
      return 'room_hardcore_title';
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
    case RoomType.hardcore:
      return const Color(0xFFFF3355);
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
    case RoomType.hardcore:
      return Icons.whatshot;
  }
}
