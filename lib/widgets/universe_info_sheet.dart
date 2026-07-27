import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/config/room_visual_theme.dart';
import '../game/room_type.dart';
import 'hardcore_rules_sheet.dart';

String roomLobbyTitleKey(RoomType type) => switch (type) {
      RoomType.simple => 'room_simple_title',
      RoomType.normal => 'room_normal_title',
      RoomType.elite => 'room_elite_title',
      RoomType.unique => 'room_unique_title',
      RoomType.hardcore => 'room_hardcore_title',
    };

String roomLobbyDescKey(RoomType type) => switch (type) {
      RoomType.simple => 'room_simple_desc',
      RoomType.normal => 'room_normal_desc',
      RoomType.elite => 'room_elite_desc',
      RoomType.unique => 'room_unique_desc',
      RoomType.hardcore => 'room_hardcore_desc',
    };

String roomLobbyRulesHelpKey(RoomType type) => switch (type) {
      RoomType.simple => 'room_simple_rules_help',
      RoomType.normal => 'room_normal_rules_help',
      RoomType.elite => 'room_elite_rules_help',
      RoomType.unique => 'room_unique_rules_help',
      RoomType.hardcore => 'room_hardcore_rules_help',
    };

IconData roomLobbyInfoIcon(RoomType type) => switch (type) {
      RoomType.simple => Icons.school_outlined,
      RoomType.normal => Icons.public_outlined,
      RoomType.elite => Icons.military_tech_outlined,
      RoomType.unique => Icons.auto_awesome_outlined,
      RoomType.hardcore => Icons.whatshot_rounded,
    };

/// Responsive lobby card sizing for narrow phones.
class LobbyRoomMetrics {
  const LobbyRoomMetrics._();

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double gateBadgeWidth(BuildContext context) {
    final w = screenWidth(context);
    if (w < 330) return 92;
    if (w < 360) return 104;
    return 118;
  }

  static double titleFontSize(BuildContext context) {
    final w = screenWidth(context);
    if (w < 330) return 14.5;
    if (w < 360) return 15.5;
    if (w < 400) return 16;
    return 17;
  }

  static double subtitleFontSize(BuildContext context) {
    final w = screenWidth(context);
    if (w < 330) return 10.5;
    if (w < 360) return 11;
    return 11.5;
  }

  static double helpIconSize(BuildContext context) {
    final w = screenWidth(context);
    if (w < 360) return 16;
    return 18;
  }

  static int titleMaxLines(BuildContext context) =>
      screenWidth(context) < 340 ? 2 : 1;

  static EdgeInsets listPadding(BuildContext context) {
    final w = screenWidth(context);
    final horizontal = w < 360 ? 14.0 : 20.0;
    return EdgeInsets.fromLTRB(horizontal, 0, horizontal, 120);
  }

  static EdgeInsets cardContentPadding(BuildContext context) {
    final w = screenWidth(context);
    final left = w < 360 ? 10.0 : 12.0;
    final right = w < 360 ? 10.0 : 14.0;
    return EdgeInsets.fromLTRB(left, 14, right, 12);
  }

  static double headerColumnGap(BuildContext context) =>
      screenWidth(context) < 360 ? 6 : 10;
}

/// Title text with help icon immediately after the title (not at row end).
class LobbyUniverseTitleWithHelp extends StatelessWidget {
  const LobbyUniverseTitleWithHelp({
    super.key,
    required this.roomType,
    required this.color,
    required this.locked,
    required this.title,
    this.helpIconSize,
  });

  final RoomType roomType;
  final Color color;
  final bool locked;
  final Widget title;
  final double? helpIconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: title,
        ),
        LobbyUniverseHelpButton(
          roomType: roomType,
          color: color,
          locked: locked,
          iconSize: helpIconSize ?? LobbyRoomMetrics.helpIconSize(context),
        ),
      ],
    );
  }
}

Future<void> showUniverseInfoSheet(BuildContext context, RoomType type) {
  if (type == RoomType.hardcore) {
    return showHardcoreRulesSheet(context);
  }

  final lang = context.lang;
  final theme = RoomVisualTheme.forRoom(type);
  final accent = theme.accent;
  final lines = lang
      .t(roomLobbyDescKey(type))
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.12),
                const Color(0xFF0A0A1A).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(roomLobbyInfoIcon(type), color: accent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.t(roomLobbyTitleKey(type)),
                        style: TextStyle(
                          color: accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Text(
                    lines[i],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    lang.t('hardcore_rules_sheet_close'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class LobbyUniverseHelpButton extends StatelessWidget {
  const LobbyUniverseHelpButton({
    super.key,
    required this.roomType,
    required this.color,
    required this.locked,
    this.iconSize = 18,
  });

  final RoomType roomType;
  final Color color;
  final bool locked;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showUniverseInfoSheet(context, roomType),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
          child: Tooltip(
            message: lang.t(roomLobbyRulesHelpKey(roomType)),
            child: Icon(
              Icons.help_outline_rounded,
              size: iconSize,
              color: color.withValues(alpha: locked ? 0.35 : 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
