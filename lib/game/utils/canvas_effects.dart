import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

/// Stacked [MaskFilter.blur] layers can blank the game canvas on web (CanvasKit)
/// and on mobile GPUs when many entities render at once.
abstract final class CanvasEffects {
  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Android / iOS — Impeller viewport + shader quirks differ from web CanvasKit.
  static bool get isNativeMobile => _isMobile;

  /// User-enabled low performance (Settings).
  static bool get lowPerformanceMode =>
      SettingsService.instance.isLoaded &&
      SettingsService.instance.lowPerformanceMode;

  /// Platform lite (mobile/web) or user low-performance toggle.
  static bool get economyMode => mobileLiteMode || lowPerformanceMode;

  /// Aggressive render budget for phone/tablet GPUs and web (CanvasKit chokes
  /// on full starfield + tidal VFX when the camera zooms out near mass 500).
  static bool get mobileLiteMode => kIsWeb || _isMobile;

  /// Mobile gameplay frame ceiling — OS refresh + Flame update are paced here.
  /// Low performance mode caps at 30 FPS for weaker devices.
  static int get maxGameplayFps => lowPerformanceMode ? 30 : 60;

  static double get minGameplayFrameTime => 1.0 / maxGameplayFps;

  static bool get blurEnabled =>
      !kIsWeb && !_isMobile && !lowPerformanceMode;

  /// GPU black-hole fragment shader — native mobile + desktop when perf allows.
  /// Web stays on Canvas (CanvasKit quirks).
  static bool get shaderBlackHoleEnabled => !kIsWeb && !lowPerformanceMode;

  /// Web has no blur — compensate with gradients; lite mode keeps layers shallow.
  static double get visualPopMultiplier =>
      blurEnabled ? 1.0 : (economyMode ? 1.1 : 1.42);

  /// Cap galactic-merger shockwaves on phone (world-sized rings freeze Impeller).
  static double capMergerShockwaveRadius({
    required double requested,
    required double viewportHalfExtent,
  }) {
    if (!_isMobile && !lowPerformanceMode) return requested;
    final factor = lowPerformanceMode ? 2.0 : 3.2;
    return math.min(requested, viewportHalfExtent * factor);
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

    final layers = lowPerformanceMode
        ? const [(1.0, 0.45)]
        : const [(1.0, 0.55), (0.7, 0.38), (0.45, 0.22)];
    for (final layer in layers) {
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
