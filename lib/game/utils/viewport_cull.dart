import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../orbit_game.dart';
import 'canvas_effects.dart';

/// Skips off-screen [render] / heavy [update] to stay within GPU/CPU budgets.
/// Only entities inside the player's visible screen (+ [margin]) are drawn;
/// far entities keep lightweight simulation so re-entry looks correct.
abstract final class ViewportCull {
  static OrbitGame? _cachedGame;
  static Rect _cachedRect = Rect.zero;

  /// Extra pad beyond the view so AI / VFX near the edge stay warm.
  static const double updateMargin = 420;

  /// Extra cull inflate when the camera is pressed against the world border —
  /// prevents shake / clamp jitter from popping entities on/off.
  static const double _borderCullBoost = 140;

  /// Call once per frame from [OrbitGame.update] before entity render passes.
  static void warmCache(OrbitGame game) {
    _cachedGame = game;
    _cachedRect = visibleWorldRect(game);
  }

  static Rect _rectFor(OrbitGame game) {
    if (identical(_cachedGame, game)) return _cachedRect;
    return visibleWorldRect(game);
  }

  static bool _viewTouchesWorldBorder(OrbitGame game, Rect rect) {
    if (!game.isReady) return false;
    final ws = game.worldSize;
    const pad = 160.0;
    return rect.left <= pad ||
        rect.top <= pad ||
        rect.right >= ws - pad ||
        rect.bottom >= ws - pad;
  }

  static bool isOffScreen(OrbitGame game, Vector2 worldPos, double margin) {
    final rect = _rectFor(game);
    if (rect.width <= 0 || rect.height <= 0) return false;

    var effectiveMargin = margin;
    if (_viewTouchesWorldBorder(game, rect)) {
      effectiveMargin += _borderCullBoost;
    }

    return !rect
        .inflate(effectiveMargin)
        .contains(Offset(worldPos.x, worldPos.y));
  }

  /// True when heavy per-frame work can be skipped (AI scans, particle sims,
  /// tidal spin queries). Uses a larger margin than typical render culls.
  static bool isFarFromView(
    OrbitGame game,
    Vector2 worldPos, {
    double margin = updateMargin,
  }) =>
      isOffScreen(game, worldPos, margin);

  /// Visible world area for culling / starfield.
  ///
  /// Prefers Flame's [CameraComponent.visibleWorldRect], but on Android/iOS
  /// (Impeller) falls back to a viewfinder-centered rect when the cached camera
  /// rect is empty or clearly misaligned after zoom, shake, or bounds updates.
  /// A bad rect culls the entire starfield + consumables while the local player
  /// (which skips cull) still draws — empty void with only the hole on phone.
  static Rect visibleWorldRect(OrbitGame game) {
    final fallback = _viewfinderCenteredRect(game);

    // Impeller mis-reports [CameraComponent.visibleWorldRect] after zoom/shake.
    // Viewfinder-centered rect keeps starfield + VFX visible on phone like web.
    if (CanvasEffects.isNativeMobile &&
        fallback.width > 0 &&
        fallback.height > 0) {
      return fallback;
    }

    Rect? fromCamera;
    try {
      final rect = game.camera.visibleWorldRect;
      if (rect.width > 0 && rect.height > 0) {
        fromCamera = rect;
      }
    } catch (_) {
      fromCamera = null;
    }

    if (fromCamera == null) return fallback;

    if (CanvasEffects.mobileLiteMode) {
      final focus = game.camera.viewfinder.position;
      final pad = math.max(fromCamera.shortestSide * 0.35, 120.0);
      if (!fromCamera.inflate(pad).contains(Offset(focus.x, focus.y))) {
        return fallback.width > 0 ? fallback : fromCamera;
      }
    }

    return fromCamera;
  }

  /// Half-width/height of the visible world slice — for capping fullscreen VFX.
  static double viewportHalfExtent(OrbitGame game) {
    final rect = visibleWorldRect(game);
    if (rect.width <= 0 || rect.height <= 0) return 900;
    return math.max(rect.width, rect.height) * 0.5;
  }

  static Rect _viewfinderCenteredRect(OrbitGame game) {
    final zoom = game.camera.viewfinder.zoom;
    var size = game.camera.viewport.size;
    if (size.x <= 0 || size.y <= 0) {
      size = game.size;
    }
    if (size.x <= 0 || size.y <= 0 || zoom <= 0) {
      return Rect.zero;
    }

    final halfW = size.x / (2 * zoom);
    final halfH = size.y / (2 * zoom);
    final center = game.camera.viewfinder.position;
    return Rect.fromLTRB(
      center.x - halfW,
      center.y - halfH,
      center.x + halfW,
      center.y + halfH,
    );
  }
}
