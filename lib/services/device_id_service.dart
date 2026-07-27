import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/safe_debug.dart';

/// Kurulum başına kalıcı cihaz kimliği (secure storage; web'de prefs).
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  static const _prefKey = 'quasar_device_id';

  /// Same as session storage: EncryptedSharedPreferences can hard-crash on
  /// some OEM Android builds during first launch.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: true,
    ),
  );

  String? _cached;

  Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_prefKey);
      if (existing != null && existing.isNotEmpty) {
        _cached = existing;
        return existing;
      }
      final generated = _generateId();
      await prefs.setString(_prefKey, generated);
      _cached = generated;
      return generated;
    }

    try {
      final fromSecure = await _secure.read(key: _prefKey);
      if (fromSecure != null && fromSecure.isNotEmpty) {
        _cached = fromSecure;
        return fromSecure;
      }
    } catch (e, st) {
      safeDebugPrint('DeviceIdService secure read: $e\n$st');
    }

    // Eski SharedPreferences kaydını taşı / fallback.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_prefKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _secure.write(key: _prefKey, value: legacy);
        await prefs.remove(_prefKey);
      } catch (_) {
        // Keep prefs copy if secure write fails.
      }
      _cached = legacy;
      return legacy;
    }

    final generated = _generateId();
    try {
      await _secure.write(key: _prefKey, value: generated);
    } catch (e, st) {
      safeDebugPrint('DeviceIdService secure write: $e\n$st');
      await prefs.setString(_prefKey, generated);
    }
    _cached = generated;
    return generated;
  }

  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'qio_$hex';
  }
}
