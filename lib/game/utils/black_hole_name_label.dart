import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../utils/bot_name.dart';
import '../../utils/player_rank.dart';

/// Floating name label drawn above a black hole in world space.
///
/// Font size and avatar size are kept constant in screen pixels so labels stay
/// readable regardless of black-hole radius or camera zoom.
class BlackHoleNameLabel {
  BlackHoleNameLabel._();

  /// Target size on screen (logical pixels).
  static const double screenFontSize = 13.0;
  static const double screenAvatarDiameter = 24.0;
  static const double screenSpeechFontSize = 12.0;

  static bool shouldShow({
    required bool isLocal,
  }) {
    final settings = SettingsService.instance;
    if (isLocal) return settings.showOwnName;
    return settings.showOtherNames;
  }

  /// Temporary chat / reaction / absorb flex bubble above the hole.
  static void paintSpeechBubble({
    required Canvas canvas,
    required double radius,
    required String text,
    double zoom = 1.0,
    bool isLocal = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final safeZoom = zoom.clamp(0.05, 10.0);
    final fontSize = screenSpeechFontSize / safeZoom;
    final y = -(radius * 1.35 + fontSize * 2.6);

    final painter = TextPainter(
      text: TextSpan(
        text: trimmed,
        style: TextStyle(
          color: isLocal ? const Color(0xFF041018) : const Color(0xFF101018),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 130 / safeZoom);

    final padX = 8 / safeZoom;
    final padY = 5 / safeZoom;
    final bubbleW = painter.width + padX * 2;
    final bubbleH = painter.height + padY * 2;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, y),
        width: bubbleW,
        height: bubbleH,
      ),
      Radius.circular(10 / safeZoom),
    );

    final fill = isLocal ? const Color(0xFF7EF9FF) : const Color(0xFFF2F4FF);
    canvas.drawRRect(bubbleRect, Paint()..color = fill);
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / safeZoom
        ..color = Colors.black.withValues(alpha: 0.22),
    );

    // Small tail pointing down toward the hole.
    final tipY = y + bubbleH / 2;
    final tail = Path()
      ..moveTo(-5 / safeZoom, tipY - 1 / safeZoom)
      ..lineTo(0, tipY + 7 / safeZoom)
      ..lineTo(5 / safeZoom, tipY - 1 / safeZoom)
      ..close();
    canvas.drawPath(tail, Paint()..color = fill);

    painter.paint(
      canvas,
      Offset(-painter.width / 2, y - painter.height / 2),
    );
  }

  static void paint({
    required Canvas canvas,
    required double radius,
    required String name,
    double zoom = 1.0,
    bool isLocal = false,
    bool isBot = false,
    bool showBotBadge = false,
    int? rankPoints,
    ui.Image? portrait,
    String? portraitEmoji,
    String? portraitInitial,
    Color? portraitColor,
    bool showPortraitFallback = false,
  }) {
    final showAvatar = portrait != null ||
        (portraitEmoji != null && portraitEmoji.isNotEmpty) ||
        (portraitInitial != null && portraitInitial.isNotEmpty) ||
        showPortraitFallback;
    if (name.isEmpty && !showAvatar) return;

    final safeZoom = zoom.clamp(0.05, 10.0);
    final fontSize = screenFontSize / safeZoom;
    final avatarD = screenAvatarDiameter / safeZoom;
    final avatarR = avatarD / 2;
    final y = -(radius * 1.35 + fontSize * 0.35);
    final displayName = isBot ? botBaseName(name) : name;
    final rank = !isBot && rankPoints != null && name.isNotEmpty
        ? playerRankForPoints(rankPoints)
        : null;

    final namePainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: TextStyle(
          color: isLocal
              ? const Color(0xFF00F0FF)
              : Colors.white.withValues(alpha: 0.92),
          fontSize: fontSize,
          fontWeight: isLocal ? FontWeight.w700 : FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black87,
              blurRadius: 4 / safeZoom,
              offset: Offset(0, 1 / safeZoom),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140 / safeZoom);

    final badgeGap = 3.0 / safeZoom;
    final hasName = displayName.isNotEmpty;
    final showRank = rank != null;
    const rankBase = 7.0;
    final rankH = showRank
        ? playerRankBadgeHeight(rankBase, compact: true) / safeZoom
        : 0.0;
    final rankGap = showRank ? 1.5 / safeZoom : 0.0;

    var prefixWidth = 0.0;
    if (showAvatar) {
      prefixWidth += avatarD;
      if ((showBotBadge && isBot) || hasName) {
        prefixWidth += badgeGap;
      }
    }
    if (showBotBadge && isBot) {
      prefixWidth += 11.0 / safeZoom;
      prefixWidth += badgeGap;
    }

    final rowWidth = namePainter.width + prefixWidth;
    final contentHeight = math.max(
      namePainter.height,
      showAvatar ? avatarD : 0,
    );
    final plateHeight = contentHeight + rankH + rankGap;
    // Keep the name row near the old anchor; crown sits above (no dark plate).
    final plateCenterY = y - (rankH + rankGap) / 2;
    final contentCenterY = plateCenterY + (rankH + rankGap) / 2;

    if (showRank) {
      paintPlayerRankBadgeCentered(
        canvas: canvas,
        center: Offset(0, plateCenterY - plateHeight / 2 + rankH / 2),
        zoom: safeZoom,
        tier: rank,
        baseSize: rankBase,
        compact: true,
      );
    }

    final contentLeft = -rowWidth / 2;
    var cursorX = contentLeft;

    if (showAvatar) {
      final avatarCenter = Offset(cursorX + avatarR, contentCenterY);
      _paintAvatar(
        canvas: canvas,
        center: avatarCenter,
        radius: avatarR,
        zoom: safeZoom,
        portrait: portrait,
        portraitEmoji: portraitEmoji,
        portraitInitial: portraitInitial,
        portraitColor: portraitColor,
        showPortraitFallback: showPortraitFallback,
      );
      cursorX += avatarD;
      if ((showBotBadge && isBot) || hasName) {
        cursorX += badgeGap;
      }
    }

    if (showBotBadge && isBot) {
      paintBotBadge(
        canvas: canvas,
        topLeft: Offset(
          cursorX,
          contentCenterY - (11.0 / safeZoom) / 2,
        ),
        zoom: safeZoom,
      );
      cursorX += 11.0 / safeZoom + badgeGap;
    }

    if (hasName) {
      namePainter.paint(
        canvas,
        Offset(cursorX, contentCenterY - namePainter.height / 2),
      );
    }
  }

  static void _paintAvatar({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double zoom,
    ui.Image? portrait,
    String? portraitEmoji,
    String? portraitInitial,
    Color? portraitColor,
    bool showPortraitFallback = false,
  }) {
    if (portrait != null) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      );
      final src = Rect.fromLTWH(
        0,
        0,
        portrait.width.toDouble(),
        portrait.height.toDouble(),
      );
      final dst = Rect.fromCircle(center: center, radius: radius);
      canvas.drawImageRect(portrait, src, dst, Paint());
      canvas.restore();
    } else if (portraitEmoji != null && portraitEmoji.isNotEmpty) {
      canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF111118));
      final painter = TextPainter(
        text: TextSpan(text: portraitEmoji, style: TextStyle(fontSize: radius * 1.1)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    } else if (portraitInitial != null && portraitInitial.isNotEmpty) {
      final color = portraitColor ?? const Color(0xFF3366AA);
      final hsl = HSLColor.fromColor(color);
      final bg = hsl.withLightness(0.28).withSaturation(0.65).toColor();
      canvas.drawCircle(center, radius, Paint()..color = bg);
      final trimmed = portraitInitial.trim();
      final glyph = trimmed.isEmpty
          ? '?'
          : String.fromCharCodes([trimmed.runes.first]).toUpperCase();
      final painter = TextPainter(
        text: TextSpan(
          text: glyph,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 1.05,
            fontWeight: FontWeight.w700,
            height: 1,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    } else if (showPortraitFallback) {
      canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1A1A28));
      canvas.drawCircle(
        center,
        radius * 0.35,
        Paint()..color = const Color(0xFF00F0FF).withValues(alpha: 0.7),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 / zoom
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }
}
