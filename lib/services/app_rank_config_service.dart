import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/models/app_rank_config.dart';
import 'admin_access.dart';

/// Rütbe puan çarpanları + eşikler — yerel önbellek + Supabase tek satır.
class AppRankConfigService extends ChangeNotifier {
  AppRankConfigService._();
  static final AppRankConfigService instance = AppRankConfigService._();

  static const _prefsKey = 'quasar_app_rank_config_v1';

  AppRankConfig _config = AppRankConfig.defaults;
  AppRankConfig _persisted = AppRankConfig.defaults;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  AppRankConfig get config => _config;
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
          .from('app_rank_config')
          .select('config')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return;

      final map = _asStringKeyMap(row['config']);
      if (map == null) return;
      final next = AppRankConfig.fromJson(map);
      if (_config.sameAs(next)) return;
      _config = next;
      _persisted = next;
      await _saveLocal();
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('AppRankConfigService remote refresh: $e\n$stackTrace');
    }
  }

  void updateConfig(AppRankConfig Function(AppRankConfig current) transform) {
    final next = transform(_config);
    if (_config.sameAs(next)) return;
    _config = next;
    _error = null;
    notifyListeners();
  }

  Future<void> save() => _flushPersist();

  Future<void> resetToDefaults() async {
    _config = AppRankConfig.defaults;
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
      await client.from('app_rank_config').upsert({
        'id': 1,
        'config': _config.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _persisted = _config;
    } catch (e, stackTrace) {
      debugPrint('AppRankConfigService save: $e\n$stackTrace');
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
      _config = AppRankConfig.fromJson(map);
      _persisted = _config;
    } catch (e, stackTrace) {
      debugPrint('AppRankConfigService local load: $e\n$stackTrace');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_config.toJson()));
    } catch (e, stackTrace) {
      debugPrint('AppRankConfigService local save: $e\n$stackTrace');
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
