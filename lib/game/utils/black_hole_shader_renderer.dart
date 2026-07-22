import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'black_hole_renderer.dart';
import 'black_hole_shader_service.dart';
import 'canvas_effects.dart';

/// GPU fragment-shader pass for EHT-style black holes.
///
/// Call [beginFrame], then [nominate] for each hole, then [resolveBudget]
/// after the camera/viewport cache is warm. On-screen holes are ranked so the
/// local player and the largest/nearest competitors keep full ray-march quality.
abstract final class BlackHoleShaderRenderer {
  BlackHoleShaderRenderer._();

  /// Full ray-march + bloom (includes the local player slot).
  static const mobileMaxLod2 = 4;

  /// Extra analytic+lens draws for other on-screen holes.
  static const mobileMaxLod1 = 2;

  static const desktopMaxLod2 = 8;
  static const desktopMaxLod1 = 4;

  static final List<_HoleCandidate> _candidates = [];
  static final Map<Object, int> _assignedLod = {};
  static bool _planned = false;

  /// Clears per-frame nominations. Prefer pairing with [resolveBudget].
  static void beginFrame() {
    _candidates.clear();
    _assignedLod.clear();
    _planned = false;
  }

  /// Register a hole that may receive a shader slot this frame.
  /// Skip off-screen competitors — only nominate what the player can see.
  static void nominate({
    required Object key,
    required bool isLocal,
    required double gameRadius,
    required double score,
  }) {
    if (gameRadius <= 0) return;
    _candidates.add(
      _HoleCandidate(
        key: key,
        isLocal: isLocal,
        gameRadius: gameRadius,
        score: score,
      ),
    );
  }

  /// Assign LOD 2 / LOD 1 / 0 from [nominate] scores (higher = better).
  static void resolveBudget() {
    if (!BlackHoleShaderService.enabled || !BlackHoleShaderService.isReady) {
      _planned = true;
      return;
    }

    final mobile = CanvasEffects.isNativeMobile;
    var lod2Left = mobile ? mobileMaxLod2 : desktopMaxLod2;
    var lod1Left = mobile ? mobileMaxLod1 : desktopMaxLod1;

    final ordered = List<_HoleCandidate>.from(_candidates)
      ..sort((a, b) => b.score.compareTo(a.score));

    for (final c in ordered) {
      if (c.isLocal) {
        _assignedLod[c.key] = 2;
        lod2Left = math.max(0, lod2Left - 1);
        continue;
      }

      if (lod2Left > 0 && c.gameRadius >= 14) {
        _assignedLod[c.key] = 2;
        lod2Left--;
      } else if (lod1Left > 0 && c.gameRadius >= 12) {
        _assignedLod[c.key] = 1;
        lod1Left--;
      } else {
        _assignedLod[c.key] = 0;
      }
    }
    _planned = true;
  }

  /// Planned LOD for [key] (0 = Canvas / skip shader).
  static int lodForKey(Object key) {
    if (!_planned) return 0;
    return _assignedLod[key] ?? 0;
  }

  /// LOD 0 = off, 1 = analytic+lens, 2 = ray-march + bloom.
  ///
  /// Fallback when [resolveBudget] was not run for this frame.
  static int lodFor({
    required bool isLocal,
    required bool compact,
    required double gameRadius,
    required bool highDetail,
  }) {
    if (compact) return 0;

    if (CanvasEffects.isNativeMobile) {
      if (isLocal) return 2;
      if (highDetail && gameRadius >= 40) return 2;
      return gameRadius >= 18 ? 1 : 0;
    }

    if (isLocal) return 2;
    if (highDetail && gameRadius >= 36) return 2;
    if (gameRadius >= 22) return 1;
    return 1;
  }

  static bool shouldUse({
    required bool isLocal,
    required bool compact,
    required double gameRadius,
    Object? key,
  }) {
    if (compact || !BlackHoleShaderService.enabled) return false;
    if (!BlackHoleShaderService.isReady) return false;
    if (key != null && _planned) return lodForKey(key) > 0;
    if (isLocal) return true;
    if (CanvasEffects.isNativeMobile) return gameRadius >= 16;
    if (CanvasEffects.mobileLiteMode) return gameRadius >= 20;
    return gameRadius >= 14;
  }

  /// Returns true when the shader drew the body (caller skips Canvas _paintFull).
  static bool paint({
    required Canvas canvas,
    required double gameRadius,
    required double rs,
    required double diskR,
    required double spin,
    required double boostMul,
    required double intensity,
    required double swallowCharge,
    required List<Color> hot,
    required List<Color> cool,
    required int lod,
    required double time,
    double influxFlux = 0,
    bool isLocal = false,
    Object? key,
  }) {
    var effectiveLod = lod;
    if (key != null && _planned) {
      effectiveLod = lodForKey(key);
    }
    if (effectiveLod <= 0) return false;

    final shader = BlackHoleShaderService.borrowShader();
    if (shader == null) return false;

    final extent = BlackHoleRenderer.visualExtentRadius(gameRadius);
    final side = extent * 2;
    final shadowR = BlackHoleRenderer.shadowBoundaryRadius(gameRadius);

    _configureShader(
      shader: shader,
      side: side,
      rs: rs,
      shadowR: shadowR,
      diskR: diskR,
      spin: spin,
      intensity: intensity,
      boostMul: boostMul,
      swallowCharge: swallowCharge,
      hot: hot,
      cool: cool,
      lod: effectiveLod.toDouble(),
      time: time,
      influxFlux: influxFlux,
    );

    // Impeller FlutterFragCoord = drawRect geometry `position` (not screen CTM).
    // Rect.fromLTWH(0,0,side,side) → frag ∈ [0, side] (Skia dest-local matches).
    // Translate keeps the hole centered on Offset.zero in Flame body space.
    canvas.save();
    canvas.translate(-side * 0.5, -side * 0.5);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, side, side),
      Paint()..shader = shader,
    );
    canvas.restore();

    if (effectiveLod >= 2 && CanvasEffects.blurEnabled) {
      _paintOuterBloom(canvas, extent, shadowR, hot[0], intensity);
    } else if (effectiveLod >= 1 && CanvasEffects.isNativeMobile) {
      _paintMobileBloom(canvas, extent, shadowR, hot[0], intensity);
    }

    return true;
  }

  /// Donut bloom — glow around the disk band only, keeping the event-horizon
  /// center pure black (reference art: solid void).
  static void _paintOuterBloom(
    Canvas canvas,
    double extent,
    double shadowR,
    Color hot,
    double intensity,
  ) {
    final bandOuter = math.min(extent * 0.92, shadowR * 1.7);
    if (bandOuter <= shadowR * 1.05) return;
    final bandMid = (shadowR + bandOuter) * 0.5;
    final bandW = bandOuter - shadowR;
    canvas.drawCircle(
      Offset.zero,
      bandMid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandW
        ..color = hot.withValues(alpha: 0.1 * intensity.clamp(0.0, 1.5))
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, bandW * 0.4)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawCircle(
      Offset.zero,
      shadowR * 1.12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bandW * 0.55
        ..color = Colors.white.withValues(alpha: 0.04 * intensity.clamp(0.0, 1.5))
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, bandW * 0.28)
        ..blendMode = BlendMode.plus,
    );
  }

  /// Gradient bloom stack — Impeller-safe substitute when [blurEnabled] is false.
  static void _paintMobileBloom(
    Canvas canvas,
    double extent,
    double shadowR,
    Color hot,
    double intensity,
  ) {
    final mul = intensity.clamp(0.0, 1.5);
    final bloomOuter = math.min(extent * 0.96, shadowR * 1.75);
    for (final layer in const [
      (1.0, 0.10),
      (0.9, 0.07),
      (0.82, 0.04),
    ]) {
      final r = bloomOuter * layer.$1;
      if (r <= shadowR * 1.04) continue;
      final innerStop = (shadowR * 0.98 / r).clamp(0.0, 0.9);
      final span = 1.0 - innerStop;
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              hot.withValues(alpha: layer.$2 * mul),
              hot.withValues(alpha: layer.$2 * mul * 0.35),
              Colors.transparent,
            ],
            stops: [
              innerStop,
              innerStop + span * 0.42,
              innerStop + span * 0.72,
              1.0,
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r))
          ..blendMode = BlendMode.plus,
      );
    }
  }

  static void _configureShader({
    required ui.FragmentShader shader,
    required double side,
    required double rs,
    required double shadowR,
    required double diskR,
    required double spin,
    required double intensity,
    required double boostMul,
    required double swallowCharge,
    required List<Color> hot,
    required List<Color> cool,
    required double lod,
    required double time,
    double influxFlux = 0,
  }) {
    shader.setFloat(0, side);
    shader.setFloat(1, side);
    shader.setFloat(2, rs);
    shader.setFloat(3, shadowR);
    shader.setFloat(4, diskR);
    shader.setFloat(5, spin);
    shader.setFloat(6, intensity);
    shader.setFloat(7, boostMul);
    shader.setFloat(8, swallowCharge);
    _setRgb(shader, 9, hot[0]);
    _setRgb(shader, 12, hot[1]);
    _setRgb(shader, 15, hot[2]);
    _setRgb(shader, 18, cool[0]);
    shader.setFloat(21, time);
    shader.setFloat(22, lod);
    shader.setFloat(23, influxFlux.clamp(0.0, 1.0));
  }

  static void _setRgb(ui.FragmentShader shader, int index, Color color) {
    shader.setFloat(index, color.r);
    shader.setFloat(index + 1, color.g);
    shader.setFloat(index + 2, color.b);
  }
}

class _HoleCandidate {
  const _HoleCandidate({
    required this.key,
    required this.isLocal,
    required this.gameRadius,
    required this.score,
  });

  final Object key;
  final bool isLocal;
  final double gameRadius;
  final double score;
}
