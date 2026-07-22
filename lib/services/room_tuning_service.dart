import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/bot_difficulty.dart';
import '../game/config/match_pacing.dart';
import '../game/config/room_config.dart';
import '../game/config/universe_difficulty.dart';
import '../game/models/room_game_tuning.dart';
import '../game/room_type.dart';
import 'admin_access.dart';

/// Evren başına oyun dengesi — yerel önbellek + Supabase JSON senkronu.
class RoomTuningService extends ChangeNotifier {
  RoomTuningService._();
  static final RoomTuningService instance = RoomTuningService._();

  /// v2: competitive rooms default to human-like bot profiles (10+10 fill).
  static const _prefsPrefix = 'quasar_room_tuning_v2_';

  final Map<RoomType, RoomGameTuning> _tuning = {
    for (final type in RoomType.values) type: RoomGameTuning.defaultsFor(type),
  };

  final Map<RoomType, RoomGameTuning> _persisted = {
    for (final type in RoomType.values) type: RoomGameTuning.defaultsFor(type),
  };

  bool _loaded = false;
  bool _saving = false;
  String? _error;

  bool get isLoaded => _loaded;
  bool get saving => _saving;
  String? get error => _error;

  bool hasUnsavedChangesFor(RoomType type) =>
      !_sameTuning(_tuning[type]!, _persisted[type]!);

  bool get hasUnsavedChanges =>
      RoomType.values.any(hasUnsavedChangesFor);

  RoomGameTuning tuningFor(RoomType type) =>
      _tuning[type] ?? RoomGameTuning.defaultsFor(type);

  double huntPriorityOf(RoomType type) => tuningFor(type).huntPriority;

  Future<void> init() async {
    if (_loaded) return;
    await _loadLocal();
    _syncPersistedFromTuning();
    _applyRuntimeOverrides();
    _loaded = true;
    notifyListeners();
    unawaited(refreshFromRemote());
  }

  Future<void> refreshFromRemote() async {
    // Kaydedilmemiş düzenlemeleri uzaktan gelen değerle ezme.
    if (hasUnsavedChanges) return;
    try {
      final client = Supabase.instance.client;
      final rows =
          await client.from('room_game_tuning').select('room_type, config');
      if (rows.isEmpty) {
        await _migrateLegacyHuntPriority(client);
        return;
      }

      var changed = false;
      for (final row in rows) {
        final type = _roomTypeFromKey(row['room_type']?.toString());
        if (type == null) continue;
        final raw = row['config'];
        final map = _asStringKeyMap(raw);
        if (map == null || _isPlaceholderConfig(map)) continue;
        final next = RoomGameTuning.fromJson(type, map);
        if (_sameTuning(_tuning[type]!, next)) continue;
        _tuning[type] = next;
        changed = true;
      }

      if (!changed) return;
      _syncPersistedFromTuning();
      _applyRuntimeOverrides();
      await _saveLocal();
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('RoomTuningService remote refresh: $e\n$stackTrace');
      try {
        await _migrateLegacyHuntPriority(Supabase.instance.client);
      } catch (_) {}
    }
  }

  /// Bellek/UI güncellemesi. Kalıcı kayıt için [save] kullanın.
  ///
  /// [persist] true eski çağrılar için hâlâ desteklenir (reset vb.).
  Future<void> updateTuning(
    RoomType type,
    RoomGameTuning Function(RoomGameTuning current) transform, {
    bool persist = false,
  }) async {
    final next = transform(tuningFor(type));
    final changed = !_sameTuning(_tuning[type]!, next);
    if (changed) {
      _tuning[type] = next;
    }
    if (!persist) {
      if (changed) notifyListeners();
      return;
    }
    if (changed) {
      _applyRuntimeOverrides();
      notifyListeners();
    }
    await _flushPersistRooms([type]);
  }

  Future<void> setHuntPriority(
    RoomType type,
    double value, {
    bool persist = false,
  }) {
    return updateTuning(
      type,
      (t) => t.copyWith(huntPriority: value.clamp(0.0, 1.0)),
      persist: persist,
    );
  }

  /// Kaydedilmemiş tüm evren ayarlarını yereline + Supabase'e yazar.
  Future<void> save() async {
    final dirty =
        RoomType.values.where(hasUnsavedChangesFor).toList(growable: false);
    if (dirty.isEmpty) return;
    _applyRuntimeOverrides();
    await _flushPersistRooms(dirty);
  }

  Future<void> saveRoom(RoomType type) async {
    if (!hasUnsavedChangesFor(type)) return;
    _applyRuntimeOverrides();
    await _flushPersistRooms([type]);
  }

  Future<void> resetToDefaults() async {
    for (final type in RoomType.values) {
      _tuning[type] = RoomGameTuning.defaultsFor(type);
    }
    _applyRuntimeOverrides();
    notifyListeners();
    await _flushPersistRooms(RoomType.values.toList(growable: false));
  }

  /// Tek bir evren tipini varsayılan dengelerine döndürür ve kaydeder.
  Future<void> resetRoomToDefaults(RoomType type) async {
    _tuning[type] = RoomGameTuning.defaultsFor(type);
    _applyRuntimeOverrides();
    notifyListeners();
    await _flushPersistRooms([type]);
  }

  /// Apply a universe difficulty ladder chip (world + tempo + hazards + bots).
  /// Yerel önizleme — kalıcı olması için [save] gerekir.
  Future<void> applyUniversePreset(
    RoomType type,
    UniverseAdminPreset preset,
  ) {
    return updateTuning(
      type,
      (_) => UniverseDifficulty.forAdminPreset(type, preset),
    );
  }

  /// Simple→Training, Normal→Ranked, Elite→Predator, Unique→Apex.
  /// Yerel önizleme — kalıcı olması için [save] gerekir.
  Future<void> applyBalancedUniverseDistribution() async {
    for (final entry in UniverseDifficulty.balancedDistribution.entries) {
      _tuning[entry.key] =
          UniverseDifficulty.forAdminPreset(entry.key, entry.value);
    }
    notifyListeners();
  }

  Future<void> _flushPersistRooms(List<RoomType> types) async {
    if (types.isEmpty) return;
    await _saveLocal();

    if (!AdminAccess.isCurrentUserAdmin) {
      _error = 'not_admin';
      notifyListeners();
      return;
    }

    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      final payload = [
        for (final type in types)
          {
            'room_type': type.name,
            'config': _tuning[type]!.toJson(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
      ];
      await client.from('room_game_tuning').upsert(payload);
      for (final type in types) {
        _persisted[type] = _tuning[type]!;
      }
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('RoomTuningService persist remote: $e\n$stackTrace');
      _error = 'error_generic';
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void _syncPersistedFromTuning() {
    for (final type in RoomType.values) {
      _persisted[type] = _tuning[type]!;
    }
  }

  void _applyRuntimeOverrides() {
    RoomConfig.applyOverrides({
      for (final type in RoomType.values)
        type: _tuning[type]!.toRoomConfig(type),
    });
    MatchPacing.applyOverrides({
      for (final type in RoomType.values)
        type: _tuning[type]!.toMatchPacing(type),
    });
    BotDifficulty.applyOverrides({
      for (final type in RoomType.values)
        type: _tuning[type]!.toBotDifficulty(type),
    });
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (final type in RoomType.values) {
      final raw = prefs.getString('$_prefsPrefix${type.name}');
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final map = _asStringKeyMap(decoded);
        if (map == null) continue;
        _tuning[type] = RoomGameTuning.fromJson(type, map);
      } catch (e) {
        debugPrint('RoomTuningService local decode ${type.name}: $e');
      }
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _tuning.entries) {
      await prefs.setString(
        '$_prefsPrefix${entry.key.name}',
        jsonEncode(entry.value.toJson()),
      );
    }
  }

  /// Eski `bot_tuning.hunt_priority` satırlarını yeni modele taşı.
  Future<void> _migrateLegacyHuntPriority(SupabaseClient client) async {
    try {
      final rows =
          await client.from('bot_tuning').select('room_type, hunt_priority');
      if (rows.isEmpty) return;
      var changed = false;
      for (final row in rows) {
        final type = _roomTypeFromKey(row['room_type']?.toString());
        final raw = row['hunt_priority'];
        if (type == null || raw is! num) continue;
        final hunt = raw.toDouble().clamp(0.0, 1.0);
        final current = _tuning[type]!;
        if ((current.huntPriority - hunt).abs() < 0.0005) continue;
        _tuning[type] = current.copyWith(huntPriority: hunt);
        changed = true;
      }
      if (!changed) return;
      _syncPersistedFromTuning();
      _applyRuntimeOverrides();
      await _saveLocal();
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('RoomTuningService legacy hunt migrate: $e\n$stackTrace');
    }
  }

  bool _sameTuning(RoomGameTuning a, RoomGameTuning b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());

  /// Seed satırları (`{"v":1}`) yerel / varsayılan değerleri ezmesin.
  bool _isPlaceholderConfig(Map<String, dynamic> map) {
    final keys = map.keys.where((k) => k != 'v').toList();
    return keys.isEmpty;
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

  RoomType? _roomTypeFromKey(String? key) {
    if (key == null) return null;
    for (final type in RoomType.values) {
      if (type.name == key) return type;
    }
    return null;
  }
}
