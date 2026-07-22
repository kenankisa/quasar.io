import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// Stacked [MaskFilter.blur] layers can blank the game canvas on web (CanvasKit)
/// and on mobile GPUs when many entities render at once.
abstract final class CanvasEffects {
  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Android / iOS — Impeller viewport + shader quirks differ from web CanvasKit.
  static bool get isNativeMobile => _isMobile;

  /// Aggressive render budget for phone/tablet GPUs and web (CanvasKit chokes
  /// on full starfield + tidal VFX when the camera zooms out near mass 500).
  static bool get mobileLiteMode => kIsWeb || _isMobile;

  /// Mobile gameplay frame ceiling — OS refresh + Flame update are paced here.
  /// 120 Hz panels otherwise double GPU work for little gameplay benefit.
  static const int maxGameplayFps = 60;

  static double get minGameplayFrameTime => 1.0 / maxGameplayFps;

  static bool get blurEnabled => !kIsWeb && !_isMobile;

  /// GPU black-hole fragment shader — native mobile + desktop.
  /// Web stays on Canvas (CanvasKit quirks). Draw via LTWH(0,0)+translate so
  /// FragCoord is [0, size] on Impeller (see [BlackHoleShaderRenderer.paint]).
  static bool get shaderBlackHoleEnabled => !kIsWeb;

  /// Web has no blur — compensate with gradients; lite mode keeps layers shallow.
  static double get visualPopMultiplier =>
      blurEnabled ? 1.0 : (mobileLiteMode ? 1.1 : 1.42);

  /// Cap galactic-merger shockwaves on phone (world-sized rings freeze Impeller).
  static double capMergerShockwaveRadius({
    required double requested,
    required double viewportHalfExtent,
  }) {
    if (!_isMobile) return requested;
    return math.min(requested, viewportHalfExtent * 3.2);
  }

  static MaskFilter? blur(double sigma) {
    if (!blurEnabled || sigma <= 0) return null;
    return MaskFilter.blur(BlurStyle.normal, sigma);
  }

  /// Soft glow that works on web (radial gradient stack) and desktop (blur).
  static void drawSoftGlowCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double intensity = 1.0,
  }) {
    if (radius <= 0 || intensity <= 0) return;

    if (blurEnabled) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: intensity)
          ..maskFilter = blur(radius * 0.38),
      );
      return;
    }

    for (final layer in const [(1.0, 0.55), (0.7, 0.38), (0.45, 0.22)]) {
      final r = radius * layer.$1;
      final alpha = intensity * layer.$2;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.42, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }
}
