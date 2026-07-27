import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/safe_debug.dart';

/// Persists the Supabase auth session in platform secure storage.
///
/// - Android: Keystore-backed secure storage (NOT EncryptedSharedPreferences —
///   that backend crashes on launch on some OEM devices).
/// - iOS/macOS: Keychain
/// - Web: WebCrypto-encrypted localStorage
class SecureSessionLocalStorage extends LocalStorage {
  SecureSessionLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  /// Prefer the classic Android secure-storage path. EncryptedSharedPreferences
  /// (androidx.security.crypto) has caused hard process kills on install/open
  /// for some devices — Dart try/catch cannot catch those native crashes.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    webOptions: WebOptions(
      dbName: 'quasar_secure_storage',
      publicKey: 'quasar.auth',
    ),
  );

  bool _ready = false;
  bool _usePrefsFallback = false;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    await _migrateFromSharedPreferences();
    await _probeSecureOrFallback();
    _ready = true;
  }

  Future<void> _probeSecureOrFallback() async {
    if (kIsWeb) return;
    try {
      await _secure.containsKey(key: persistSessionKey);
    } catch (e, st) {
      _usePrefsFallback = true;
      safeDebugPrint(
        'SecureSessionLocalStorage: secure probe failed, '
        'using SharedPreferences fallback: $e\n$st',
      );
    }
  }

  /// Eski düz metin SharedPreferences oturumunu güvenli depoya taşı.
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy == null || legacy.isEmpty) return;

      try {
        final existing = await _secure.read(key: persistSessionKey);
        if (existing == null || existing.isEmpty) {
          await _secure.write(key: persistSessionKey, value: legacy);
        }
        await prefs.remove(persistSessionKey);
      } catch (_) {
        // Keep legacy prefs until secure write works.
      }
      if (kDebugMode) {
        debugPrint(
          'SecureSessionLocalStorage: migrated session off SharedPreferences',
        );
      }
    } catch (e, st) {
      safeDebugPrint('SecureSessionLocalStorage migrate: $e\n$st');
    }
  }

  Future<String?> _read() async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(persistSessionKey);
    }
    try {
      return await _secure.read(key: persistSessionKey);
    } catch (e, st) {
      _usePrefsFallback = true;
      safeDebugPrint('SecureSessionLocalStorage read fallback: $e\n$st');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(persistSessionKey);
    }
  }

  Future<void> _write(String value) async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(persistSessionKey, value);
      return;
    }
    try {
      await _secure.write(key: persistSessionKey, value: value);
    } catch (e, st) {
      _usePrefsFallback = true;
      safeDebugPrint('SecureSessionLocalStorage write fallback: $e\n$st');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(persistSessionKey, value);
    }
  }

  Future<void> _delete() async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(persistSessionKey);
      return;
    }
    try {
      await _secure.delete(key: persistSessionKey);
    } catch (e, st) {
      _usePrefsFallback = true;
      safeDebugPrint('SecureSessionLocalStorage delete fallback: $e\n$st');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(persistSessionKey);
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await _read();
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _read();

  @override
  Future<void> removePersistedSession() => _delete();

  @override
  Future<void> persistSession(String persistSessionString) =>
      _write(persistSessionString);
}
