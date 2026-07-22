import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/models/match_speech.dart';

/// Kalıcı oyun ayarları: ses, titreşim, görünüm ve maç HUD.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _musicEnabledKey = 'quasar_music_enabled';
  static const _musicVolumeKey = 'quasar_music_volume';
  static const _hapticsEnabledKey = 'quasar_haptics_enabled';
  static const _showOwnNameKey = 'quasar_show_own_name';
  static const _showOtherNamesKey = 'quasar_show_other_names';
  static const _showProfilePicturesKey = 'quasar_show_profile_pictures';
  static const _showKillFeedKey = 'quasar_show_kill_feed';
  static const _absorbBubblePresetKey = 'quasar_absorb_bubble_preset';
  static const defaultAbsorbBubblePresetId = 'absorbed';

  bool _musicEnabled = true;
  double _musicVolume = 0.28;
  bool _hapticsEnabled = true;
  bool _showOwnName = true;
  bool _showOtherNames = true;
  bool _showProfilePictures = true;
  bool _showKillFeed = true;
  String _absorbBubblePresetId = defaultAbsorbBubblePresetId;
  bool _loaded = false;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  bool get isLoaded => _loaded;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get showOwnName => _showOwnName;
  bool get showOtherNames => _showOtherNames;
  bool get showProfilePictures => _showProfilePictures;
  bool get showKillFeed => _showKillFeed;

  /// Selected absorb bubble preset id (`random` or a fixed line id).
  String get absorbBubblePresetId => _absorbBubblePresetId;

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await _preferences;
    _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
    _musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.28;
    _hapticsEnabled = prefs.getBool(_hapticsEnabledKey) ?? true;
    _showOwnName = prefs.getBool(_showOwnNameKey) ?? true;
    _showOtherNames = prefs.getBool(_showOtherNamesKey) ?? true;
    _showProfilePictures = prefs.getBool(_showProfilePicturesKey) ?? true;
    _showKillFeed = prefs.getBool(_showKillFeedKey) ?? true;
    _absorbBubblePresetId = _sanitizeAbsorbPresetId(
      prefs.getString(_absorbBubblePresetKey),
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool value) async {
    if (_musicEnabled == value) return;
    _musicEnabled = value;
    final prefs = await _preferences;
    await prefs.setBool(_musicEnabledKey, value);
    notifyListeners();
  }

  Future<void> toggleMusicEnabled() => setMusicEnabled(!_musicEnabled);

  Future<void> setMusicVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if ((_musicVolume - clamped).abs() < 0.001) return;
    _musicVolume = clamped;
    final prefs = await _preferences;
    await prefs.setDouble(_musicVolumeKey, clamped);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    final prefs = await _preferences;
    await prefs.setBool(_hapticsEnabledKey, value);
    notifyListeners();
  }

  Future<void> setShowOwnName(bool value) async {
    if (_showOwnName == value) return;
    _showOwnName = value;
    final prefs = await _preferences;
    await prefs.setBool(_showOwnNameKey, value);
    notifyListeners();
  }

  Future<void> setShowOtherNames(bool value) async {
    if (_showOtherNames == value) return;
    _showOtherNames = value;
    final prefs = await _preferences;
    await prefs.setBool(_showOtherNamesKey, value);
    notifyListeners();
  }

  Future<void> setShowProfilePictures(bool value) async {
    if (_showProfilePictures == value) return;
    _showProfilePictures = value;
    final prefs = await _preferences;
    await prefs.setBool(_showProfilePicturesKey, value);
    notifyListeners();
  }

  Future<void> setShowKillFeed(bool value) async {
    if (_showKillFeed == value) return;
    _showKillFeed = value;
    final prefs = await _preferences;
    await prefs.setBool(_showKillFeedKey, value);
    notifyListeners();
  }

  Future<void> setAbsorbBubblePresetId(String id) async {
    final sanitized = _sanitizeAbsorbPresetId(id);
    if (_absorbBubblePresetId == sanitized) return;
    _absorbBubblePresetId = sanitized;
    final prefs = await _preferences;
    await prefs.setString(_absorbBubblePresetKey, sanitized);
    notifyListeners();
  }

  static String _sanitizeAbsorbPresetId(String? raw) {
    final id = (raw ?? '').trim();
    if (absorbPresetById(id) != null) return id;
    return defaultAbsorbBubblePresetId;
  }
}
