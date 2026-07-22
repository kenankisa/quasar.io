import 'package:flutter/material.dart';

import 'player_name.dart';

/// Legacy text suffix — stripped when migrating old stored names.
const legacyBotNameSuffix = '·B';

/// Badge letter shown on bot players.
const botBadgeLetter = 'B';

/// Bot badge palette — matches cosmic HUD accents.
const botBadgeFill = Color(0xFF2A1048);
const botBadgeBorder = Color(0xFF00F0FF);
const botBadgeLetterColor = Color(0xFF00F0FF);
const botBadgeGlow = Color(0xFFFF00AA);

String botBaseName(String name) {
  final trimmed = name.trim();
  if (trimmed.endsWith(legacyBotNameSuffix)) {
    return trimmed.substring(0, trimmed.length - legacyBotNameSuffix.length);
  }
  return trimmed;
}

/// Clean in-game name for bots (no text suffix).
String formatBotDisplayName(String name) {
  return clampPlayerName(botBaseName(name));
}

/// Paints a compact [botBadgeLetter] pill for world-space name labels.
void paintBotBadge({
  required Canvas canvas,
  required Offset topLeft,
  required double zoom,
}) {
  final safeZoom = zoom.clamp(0.05, 10.0);
  final height = 11.0 / safeZoom;
  final width = 11.0 / safeZoom;
  final radius = 3.0 / safeZoom;

  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(topLeft.dx, topLeft.dy, width, height),
    Radius.circular(radius),
  );

  canvas.drawRRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        colors: [
          botBadgeGlow.withValues(alpha: 0.55),
          botBadgeFill,
        ],
      ).createShader(rect.outerRect),
  );

  canvas.drawRRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 / safeZoom
      ..color = botBadgeBorder.withValues(alpha: 0.85),
  );

  final painter = TextPainter(
    text: TextSpan(
      text: botBadgeLetter,
      style: TextStyle(
        color: botBadgeLetterColor,
        fontSize: 7.5 / safeZoom,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  painter.paint(
    canvas,
    Offset(
      topLeft.dx + (width - painter.width) / 2,
      topLeft.dy + (height - painter.height) / 2,
    ),
  );
}
