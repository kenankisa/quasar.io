import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/settings_service.dart';
import 'settings_dialog.dart';

/// Backward-compatible entry: opens the unified settings hub.
/// Prefer [SettingsDialog.show] for new call sites.
class SoundSettingsDialog {
  SoundSettingsDialog._();

  static Future<void> show(BuildContext context) {
    return SettingsDialog.show(context);
  }

  /// Quick mute/unmute used by lobby / login icon buttons.
  static Future<void> toggleMusic() async {
    final settings = SettingsService.instance;
    final next = !settings.musicEnabled;
    await settings.setMusicEnabled(next);
    if (next) {
      await AudioService.instance.playAmbient();
    } else {
      await AudioService.instance.pauseAmbient();
    }
  }
}
