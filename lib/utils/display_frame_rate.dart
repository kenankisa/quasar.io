import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import '../game/utils/canvas_effects.dart';

/// Asks the OS to keep the display near [CanvasEffects.maxGameplayFps].
///
/// Android: MethodChannel → window preferredRefreshRate + Surface.setFrameRate.
/// iOS: [CADisableMinimumFrameDurationOnPhone] is false in Info.plist (60 Hz).
abstract final class DisplayFrameRate {
  DisplayFrameRate._();

  static const _channel = MethodChannel('quasar_io/display');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Reinforce the 60 FPS vote when a match starts (safe no-op elsewhere).
  static Future<void> applyGameplayCap() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setMaxFps', {
        'fps': CanvasEffects.maxGameplayFps,
      });
    } on PlatformException {
      // Older embeds / missing handler — MainActivity onCreate still applies.
    }
  }
}
