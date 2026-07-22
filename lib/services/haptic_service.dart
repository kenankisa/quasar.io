import 'package:vibration/vibration.dart';
import 'package:vibration/vibration_presets.dart';

import 'settings_service.dart';

class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  bool _available = false;
  bool _checked = false;

  bool get _enabled => SettingsService.instance.hapticsEnabled;

  Future<void> _ensureChecked() async {
    if (_checked) return;
    _checked = true;
    _available = await Vibration.hasVibrator();
  }

  Future<void> lightImpact() async {
    if (!_enabled) return;
    await _ensureChecked();
    if (!_available) return;
    await Vibration.vibrate(
      preset: VibrationPreset.softPulse,
    );
  }

  Future<void> heavyImpact() async {
    if (!_enabled) return;
    await _ensureChecked();
    if (!_available) return;
    await Vibration.vibrate(
      preset: VibrationPreset.emergencyAlert,
    );
  }

  Future<void> mergerVibration() async {
    if (!_enabled) return;
    await _ensureChecked();
    if (!_available) return;
    await Vibration.vibrate(
      duration: 3200,
      amplitude: 255,
    );
  }
}
