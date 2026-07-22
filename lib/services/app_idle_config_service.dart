import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/models/app_idle_config.dart';
import 'admin_access.dart';

/// Global AFK ayarları — yerel önbellek + Supabase tek satır senkronu.
class AppIdleConfigService extends ChangeNotifier {
  AppIdleConfigService._();
  static final AppIdleConfigService instance = AppIdleConfigService._();

  static const _prefsKey = 'quasar_app_idle_config_v1';

  AppIdleConfig _config = AppIdleConfig.defaults;
  AppIdleConfig _persisted = AppIdleConfig.defaults;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  AppIdleConfig get config => _config;
  bool get isLoaded => _loaded;
  bool get saving => _saving;
  String? get error => _error;
  bool get hasUnsavedChanges => !_config.sameAs(_persisted);

  Future<void> init() async {
    if (_loaded) return;
    await _loadLocal();
    _persisted = _config;
    _loaded = true;
    notifyListeners();
    unawaited(refreshFromRemote());
  }

  Future<void> refreshFromRemote() async {
    // Kaydedilmemiş düzenlemeleri uzaktan gelen değerle ezme.
    if (hasUnsavedChanges) return;
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('app_idle_config')
          .select('config')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return;

      final map = _asStringKeyMap(row['config']);
      if (map == null) return;
      final next = AppIdleConfig.fromJson(map);
      if (_config.sameAs(next)) return;
      _config = next;
      _persisted = next;
      await _saveLocal();
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('AppIdleConfigService remote refresh: $e\n$stackTrace');
    }
  }

  /// Sadece bellek/UI günceller. Kalıcı kayıt için [save] kullanın.
  void updateConfig(AppIdleConfig Function(AppIdleConfig current) transform) {
    final next = transform(_config);
    if (_config.sameAs(next)) return;
    _config = next;
    _error = null;
    notifyListeners();
  }

  Future<void> save() => _flushPersist();

  Future<void> resetToDefaults() async {
    _config = AppIdleConfig.defaults;
    notifyListeners();
    await _flushPersist();
  }

  Future<void> _flushPersist() async {
    if (!AdminAccess.isCurrentUserAdmin) {
      _error = 'not_admin';
      notifyListeners();
      return;
    }

    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await _saveLocal();
      final client = Supabase.instance.client;
      await client.from('app_idle_config').upsert({
        'id': 1,
        'config': _config.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _persisted = _config;
    } catch (e, stackTrace) {
      debugPrint('AppIdleConfigService save: $e\n$stackTrace');
      _error = e.toString();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      final map = _asStringKeyMap(decoded);
      if (map == null) return;
      _config = AppIdleConfig.fromJson(map);
      _persisted = _config;
    } catch (e, stackTrace) {
      debugPrint('AppIdleConfigService local load: $e\n$stackTrace');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_config.toJson()));
    } catch (e, stackTrace) {
      debugPrint('AppIdleConfigService local save: $e\n$stackTrace');
    }
  }

  Map<String, dynamic>? _asStringKeyMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        return _asStringKeyMap(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
