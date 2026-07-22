import 'package:flutter/material.dart';

import '../utils/bot_name.dart';
import '../utils/player_rank.dart';

/// Colored [botBadgeLetter] pill — used beside bot names in HUD and overlays.
class BotBadge extends StatelessWidget {
  const BotBadge({
    super.key,
    this.size = 14,
    this.compact = false,
  });

  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? size * 0.85 : size;
    final width = compact ? size * 0.9 : size;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 3 : 3.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            botBadgeGlow.withValues(alpha: 0.5),
            botBadgeFill,
          ],
        ),
        border: Border.all(
          color: botBadgeBorder.withValues(alpha: 0.8),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: botBadgeGlow.withValues(alpha: 0.22),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        botBadgeLetter,
        style: TextStyle(
          color: botBadgeLetterColor,
          fontSize: compact ? size * 0.52 : size * 0.55,
          fontWeight: FontWeight.w800,
          height: 1,
          shadows: [
            Shadow(
              color: botBadgeLetterColor.withValues(alpha: 0.45),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Diamond-tier star row shown before real player names.
class PlayerRankBadge extends StatelessWidget {
  const PlayerRankBadge({
    super.key,
    required this.tier,
    this.size = 14,
    this.compact = false,
  });

  final PlayerRankTier tier;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = playerRankBadgeHeight(size, compact: compact);
    final starSize = size * (compact ? 0.72 : 0.84);
    final gap = starSize * (compact ? 0.06 : 0.12);
    final showGlow = tier.id == 'quasar' || tier.id == 'singularity';

    return Tooltip(
      message: tier.localizedName(),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < tier.starCount; i++) ...[
              if (i > 0) SizedBox(width: gap),
              PlayerRankStar(
                size: starSize,
                fill: tier.effectiveStarFill,
                border: tier.borderColor,
                glow: showGlow ? tier.glowColor : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Player name with optional rank crown above and/or bot badge prefix.
class BotNameLabel extends StatelessWidget {
  const BotNameLabel({
    super.key,
    required this.name,
    this.isBot = false,
    this.showBotBadge = true,
    this.diamonds,
    this.rankPoints,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
    this.badgeSize = 12,
    this.compactBadge = false,
  });

  final String name;
  final bool isBot;
  final bool showBotBadge;
  @Deprecated('Use rankPoints for star ranks')
  final int? diamonds;
  final int? rankPoints;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;
  final double badgeSize;
  final bool compactBadge;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    final points = rankPoints ?? diamonds;
    final rank = !isBot && points != null
        ? playerRankForPoints(points)
        : null;
    if (rank == null && (!isBot || !showBotBadge)) return text;

    final gap = compactBadge ? 2.0 : 3.0;
    final crossAlign = textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    Widget nameRow = text;
    if (showBotBadge && isBot) {
      final botBadge = BotBadge(size: badgeSize, compact: compactBadge);
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: textAlign == TextAlign.center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          botBadge,
          SizedBox(width: gap),
          // Do not wrap in Flexible — FittedBox gives unbounded width and a
          // Flex child there throws / blanks Unique HUD cards on phone.
          text,
        ],
      );
      nameRow = textAlign == TextAlign.center
          ? row
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                botBadge,
                SizedBox(width: gap),
                Flexible(fit: FlexFit.loose, child: text),
              ],
            );
    } else if (textAlign != TextAlign.center && rank != null) {
      nameRow = text;
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAlign,
      children: [
        if (rank != null) ...[
          PlayerRankBadge(
            tier: rank,
            size: badgeSize,
            compact: compactBadge,
          ),
          SizedBox(height: compactBadge ? 1.5 : 2),
        ],
        nameRow,
      ],
    );

    if (textAlign == TextAlign.center) {
      return FittedBox(fit: BoxFit.scaleDown, child: column);
    }
    return column;
  }
}

/// Localized champion line with inline rank or bot badge when applicable.
class MatchChampionResultText extends StatelessWidget {
  const MatchChampionResultText({
    super.key,
    required this.template,
    required this.name,
    required this.isBot,
    required this.time,
    this.diamonds,
    this.rankPoints,
    this.style,
  });

  final String template;
  final String name;
  final bool isBot;
  final String time;
  @Deprecated('Use rankPoints')
  final int? diamonds;
  final int? rankPoints;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.35,
        );

    final displayName = isBot ? botBaseName(name) : name;
    final parts = template.split('{name}');
    if (parts.length != 2) {
      return Text(
        template
            .replaceAll('{name}', displayName)
            .replaceAll('{time}', time),
        textAlign: TextAlign.center,
        style: baseStyle,
      );
    }

    final afterName = parts[1].replaceAll('{time}', time);

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: BotNameLabel(
                name: displayName,
                isBot: isBot,
                rankPoints: isBot ? null : (rankPoints ?? diamonds),
                style: baseStyle.copyWith(fontWeight: FontWeight.w700),
                badgeSize: 10,
                compactBadge: true,
              ),
            ),
          ),
          TextSpan(text: afterName),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
