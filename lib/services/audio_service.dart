import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'settings_service.dart';

/// Oyun ana tema müziği — tek ses kaynağı, sürekli döngü.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const String _themeAsset = 'audio/quasar_orbit_theme.mp3';

  final AudioPlayer _player = AudioPlayer();
  final _settings = SettingsService.instance;

  bool _assetReady = false;
  bool _isPlaying = false;
  bool _awaitingUserGesture = false;
  bool _fadeInActive = false;
  bool _themeStarting = false;
  bool _initialized = false;

  bool get isPlaying => _isPlaying;
  bool get assetReady => _assetReady;
  bool get awaitingUserGesture => _awaitingUserGesture;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _settings.addListener(_onSettingsChanged);
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.playing) {
        _awaitingUserGesture = false;
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (_settings.musicEnabled && _assetReady) {
        unawaited(_restartTheme());
      }
    });
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0);
    await _loadThemeAsset();
  }

  Future<void> _loadThemeAsset() async {
    try {
      await _player
          .setSource(AssetSource(_themeAsset))
          .timeout(const Duration(seconds: 8));
      _assetReady = true;
    } catch (e) {
      _assetReady = false;
      debugPrint('AudioService: tema müziği yüklenemedi — $e');
    }
  }

  double get _themeTargetVolume {
    if (!_settings.musicEnabled) return 0.0;
    return _settings.musicVolume;
  }

  Future<void> _applyThemeVolume() async {
    if (!_assetReady || _fadeInActive) return;
    await _player.setVolume(_themeTargetVolume);
  }

  void _onSettingsChanged() {
    unawaited(_applyVolume());
    if (!_settings.musicEnabled) {
      unawaited(pauseAmbient());
    } else if (!_isPlaying) {
      unawaited(playAmbient());
    }
  }

  Future<void> _applyVolume() async {
    if (!_assetReady) return;
    _fadeInActive = false;
    await _player.setVolume(_themeTargetVolume);
  }

  Future<void> _fadeInToTargetVolume({
    Duration duration = const Duration(milliseconds: 2500),
  }) async {
    if (!_assetReady || !_settings.musicEnabled) return;

    _fadeInActive = true;
    const steps = 25;
    final stepDuration = duration ~/ steps;

    try {
      await _player.setVolume(0);
      for (var i = 1; i <= steps; i++) {
        if (!_settings.musicEnabled || !_fadeInActive) return;
        final target = _themeTargetVolume;
        await _player.setVolume(target * (i / steps));
        await Future<void>.delayed(stepDuration);
      }
      await _player.setVolume(_themeTargetVolume);
    } finally {
      _fadeInActive = false;
      if (_settings.musicEnabled) {
        unawaited(_player.setVolume(_themeTargetVolume));
      }
    }
  }

  Future<void> playAmbient({bool fadeIn = true}) async {
    if (!_assetReady || !_settings.musicEnabled) return;

    if (_player.state == PlayerState.playing) {
      _awaitingUserGesture = false;
      await _applyThemeVolume();
      return;
    }

    if (_themeStarting) return;

    _themeStarting = true;
    try {
      final isResume = _player.state == PlayerState.paused;
      if (fadeIn && !isResume) {
        await _player.setVolume(0);
      } else {
        await _applyVolume();
      }

      if (isResume) {
        await _player.resume();
      } else {
        await _player.play(AssetSource(_themeAsset));
      }
      _isPlaying = true;
      _awaitingUserGesture = false;

      if (fadeIn && !isResume) {
        unawaited(_fadeInToTargetVolume());
      } else {
        await _applyThemeVolume();
      }
    } catch (e) {
      _isPlaying = false;
      _awaitingUserGesture = true;
      debugPrint('AudioService: çalma hatası — $e');
    } finally {
      _themeStarting = false;
    }
  }

  Future<void> _restartTheme() async {
    if (!_assetReady || !_settings.musicEnabled) return;
    try {
      await _player.seek(Duration.zero);
      if (_player.state != PlayerState.playing) {
        await _player.resume();
      }
      await _applyThemeVolume();
    } catch (e) {
      debugPrint('AudioService: tema yeniden başlatılamadı — $e');
      unawaited(playAmbient(fadeIn: false));
    }
  }

  /// Otomatik oynatma engellendiğinde kullanıcı dokunuşuyla dener.
  Future<void> tryResumeFromUserGesture() async {
    if (!_settings.musicEnabled || !_assetReady) return;
    if (_player.state == PlayerState.playing) {
      await _applyThemeVolume();
      return;
    }
    _awaitingUserGesture = false;
    await playAmbient();
  }

  Future<void> pauseAmbient() async {
    if (!_assetReady) return;
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> dispose() async {
    _settings.removeListener(_onSettingsChanged);
    await _player.dispose();
    _isPlaying = false;
    _assetReady = false;
  }
}
