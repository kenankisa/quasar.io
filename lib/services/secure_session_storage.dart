import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/safe_debug.dart';

/// Persists the Supabase auth session in platform secure storage.
///
/// - Android: EncryptedSharedPreferences
/// - iOS/macOS: Keychain
/// - Web: WebCrypto-encrypted localStorage (not plaintext SharedPreferences)
class SecureSessionLocalStorage extends LocalStorage {
  SecureSessionLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    webOptions: WebOptions(
      dbName: 'quasar_secure_storage',
      publicKey: 'quasar.auth',
    ),
  );

  bool _ready = false;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    await _migrateFromSharedPreferences();
    _ready = true;
  }

  /// Eski düz metin SharedPreferences oturumunu güvenli depoya taşı.
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy == null || legacy.isEmpty) return;

      final existing = await _secure.read(key: persistSessionKey);
      if (existing == null || existing.isEmpty) {
        await _secure.write(key: persistSessionKey, value: legacy);
      }
      await prefs.remove(persistSessionKey);
      if (kDebugMode) {
        debugPrint(
          'SecureSessionLocalStorage: migrated session off SharedPreferences',
        );
      }
    } catch (e, st) {
      safeDebugPrint('SecureSessionLocalStorage migrate: $e\n$st');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await _secure.read(key: persistSessionKey);
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _secure.read(key: persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _secure.delete(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secure.write(key: persistSessionKey, value: persistSessionString);
}
