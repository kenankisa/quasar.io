import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/models/app_economy_config.dart';
import 'admin_access.dart';

/// Elmas ekonomisi — yerel önbellek + Supabase tek satır JSON.
class AppEconomyConfigService extends ChangeNotifier {
  AppEconomyConfigService._();
  static final AppEconomyConfigService instance = AppEconomyConfigService._();

  static const _prefsKey = 'quasar_app_economy_config_v1';

  AppEconomyConfig _config = AppEconomyConfig.defaults;
  AppEconomyConfig _persisted = AppEconomyConfig.defaults;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  AppEconomyConfig get config => _config;
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
    if (hasUnsavedChanges) return;
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('app_economy_config')
          .select('config')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return;

      final map = _asStringKeyMap(row['config']);
      if (map == null) return;
      final next = AppEconomyConfig.fromJson(map);
      if (_config.sameAs(next)) return;
      _config = next;
      _persisted = next;
      await _saveLocal();
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('AppEconomyConfigService remote refresh: $e\n$stackTrace');
    }
  }

  void updateConfig(AppEconomyConfig Function(AppEconomyConfig current) transform) {
    final next = transform(_config);
    if (_config.sameAs(next)) return;
    _config = next;
    _error = null;
    notifyListeners();
  }

  Future<void> save() => _flushPersist();

  Future<void> resetToDefaults() async {
    _config = AppEconomyConfig.defaults;
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
      await client.from('app_economy_config').upsert({
        'id': 1,
        'config': _config.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _persisted = _config;
    } catch (e, stackTrace) {
      debugPrint('AppEconomyConfigService save: $e\n$stackTrace');
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
      _config = AppEconomyConfig.fromJson(map);
      _persisted = _config;
    } catch (e, stackTrace) {
      debugPrint('AppEconomyConfigService local load: $e\n$stackTrace');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_config.toJson()));
    } catch (e, stackTrace) {
      debugPrint('AppEconomyConfigService local save: $e\n$stackTrace');
    }
  }

  static Map<String, dynamic>? _asStringKeyMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
