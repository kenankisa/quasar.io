import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;

import 'canvas_effects.dart';

/// Loads and caches the GPU black-hole fragment shader (POC).
abstract final class BlackHoleShaderService {
  BlackHoleShaderService._();

  static ui.FragmentProgram? _program;
  static bool _loadFailed = false;
  static bool _loggedReady = false;

  static bool get isReady => _program != null;

  /// Shader path: native mobile + desktop. Web falls back to Canvas.
  static bool get enabled => CanvasEffects.shaderBlackHoleEnabled;

  static Future<void> preload() async {
    if (!enabled || _loadFailed || _program != null) return;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/black_hole.frag');
      if (!_loggedReady) {
        _loggedReady = true;
        debugPrint('BlackHoleShaderService: GPU shader ACTIVE');
      }
    } catch (e, st) {
      _loadFailed = true;
      debugPrint('BlackHoleShaderService: load failed — Canvas fallback ($e)\n$st');
    }
  }

  /// Retry once if the first load raced app startup.
  static Future<void> ensureReady() async {
    if (isReady || _loadFailed || !enabled) return;
    await preload();
  }

  static ui.FragmentShader? borrowShader() {
    if (!isReady) return null;
    return _program!.fragmentShader();
  }
}
