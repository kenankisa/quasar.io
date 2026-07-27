import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import '../utils/viewport_cull.dart';

/// Short-lived +N / −N label that floats up from a black hole.
class GrowthDeltaPopup extends PositionComponent {
  GrowthDeltaPopup({
    required Vector2 worldPosition,
    required int delta,
    required double holeRadius,
    double horizontalJitter = 0,
  }) : super(
          position: worldPosition,
          anchor: Anchor.center,
          priority: 900,
        ) {
    _delta = delta;
    _holeRadius = holeRadius;
    _jitterX = horizontalJitter;
  }

  late final int _delta;
  late final double _holeRadius;
  late final double _jitterX;

  static const _duration = 1.2;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _duration) {
      removeFromParent();
      return;
    }
    final game = findGame() as OrbitGame?;
    if (game != null &&
        ViewportCull.isOffScreen(game, position, _holeRadius + 48)) {
      return;
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final game = findGame() as OrbitGame?;
    if (game != null &&
        ViewportCull.isOffScreen(game, position, _holeRadius + 48)) {
      return;
    }

    final zoom = game?.camera.viewfinder.zoom ?? 1.0;
    final safeZoom = zoom.clamp(0.05, 10.0);
    final t = (_age / _duration).clamp(0.0, 1.0);
    final alpha = (1.0 - t * t).clamp(0.0, 1.0);
    final rise = t * (42 / safeZoom);
    final baseSize = (14 / safeZoom) +
        math.min(_holeRadius * 0.08, 10 / safeZoom);
    final fontSize = baseSize.clamp(12 / safeZoom, 22 / safeZoom);
    final color = _delta > 0
        ? const Color(0xFF3DFF9A)
        : const Color(0xFFFF5555);
    final text = _delta > 0 ? '+$_delta' : '$_delta';

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: alpha),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.75 * alpha),
              blurRadius: 5 / safeZoom,
              offset: Offset(0, 1 / safeZoom),
            ),
            Shadow(
              color: color.withValues(alpha: 0.35 * alpha),
              blurRadius: 10 / safeZoom,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(
        _jitterX / safeZoom - painter.width / 2,
        -rise - painter.height / 2,
      ),
    );
  }
}
