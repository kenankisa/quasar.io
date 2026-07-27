import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

/// Radius label drawn on a black hole body (world canvas).
class BlackHoleSizeLabel {
  BlackHoleSizeLabel._();

  static const double screenFontSize = 12.0;

  static bool shouldShowOnHole({required bool isLocal}) {
    if (isLocal) return false;
    return SettingsService.instance.showOtherSizes;
  }

  static void paint({
    required Canvas canvas,
    required double radius,
    required double value,
    double zoom = 1.0,
  }) {
    final safeZoom = zoom.clamp(0.05, 10.0);
    final fontSize = screenFontSize / safeZoom;
    final text = value.round().toString();

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 4 / safeZoom,
              offset: Offset(0, 1 / safeZoom),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );
  }
}
