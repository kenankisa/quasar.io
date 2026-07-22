import 'dart:math' as math;
import 'dart:ui';

import 'black_hole_renderer.dart';

/// Gravitational lensing for background stars near the local player's hole.
///
/// Stars are radially displaced outward (weak lensing), magnified near the
/// photon-ring band, hidden inside the shadow, and optionally echoed on the
/// Einstein ring when [highDetail] is true.
abstract final class StarLensing {
  StarLensing._();

  static bool enabledForLocalPlayer({
    required bool playerAlive,
    required bool dragging,
  }) {
    if (!playerAlive || dragging) return false;
    return true;
  }

  static double lensExtentRadius(double gameRadius) =>
      BlackHoleRenderer.visualExtentRadius(gameRadius) * 1.12;

  static ({
    Offset position,
    double alpha,
    double radiusScale,
    bool inShadow,
    Offset? echo,
    double echoAlpha,
  }) compute({
    required Offset star,
    required Offset holeCenter,
    required double gameRadius,
    required bool highDetail,
  }) {
    final shadowR = BlackHoleRenderer.shadowBoundaryRadius(gameRadius);
    final rs = BlackHoleRenderer.visualCoreRadius(gameRadius);
    final extentR = lensExtentRadius(gameRadius);

    final delta = star - holeCenter;
    final dist = delta.distance;

    if (dist > extentR) {
      return (
        position: star,
        alpha: 1.0,
        radiusScale: 1.0,
        inShadow: false,
        echo: null,
        echoAlpha: 0.0,
      );
    }

    if (dist < shadowR * 0.9) {
      return (
        position: star,
        alpha: 0.0,
        radiusScale: 0.0,
        inShadow: true,
        echo: null,
        echoAlpha: 0.0,
      );
    }

    final dir = delta / dist;
    final falloff = ((dist - shadowR) / (extentR - shadowR)).clamp(0.0, 1.0);
    final strength = (1.0 - falloff) * (1.0 - falloff);

    // Weak-field radial push — stars appear smeared away from the shadow.
    final bend = (rs * rs / (dist * dist * 0.22 + rs)) * 2.1 * strength;
    final lensed = star + dir * bend;

    // Brightening near the critical curve (Einstein ring magnification).
    final ringBand = math.exp(
      -math.pow((dist - shadowR * 1.04) / math.max(rs * 0.38, 1.0), 2).toDouble(),
    );
    final alpha = (1.0 + strength * 0.28 + ringBand * 0.42).clamp(0.0, 1.65);
    final radiusScale = (1.0 + ringBand * 0.35 + strength * 0.12).clamp(1.0, 1.55);

    Offset? echo;
    var echoAlpha = 0.0;
    if (highDetail && strength > 0.22 && dist < shadowR * 1.75) {
      final echoDist = shadowR * (1.08 + 0.06 * math.sin(dist * 0.04));
      echo = holeCenter + dir * echoDist;
      echoAlpha = (0.08 + strength * 0.22 + ringBand * 0.18).clamp(0.0, 0.45);
    }

    return (
      position: lensed,
      alpha: alpha,
      radiusScale: radiusScale,
      inShadow: false,
      echo: echo,
      echoAlpha: echoAlpha,
    );
  }
}
