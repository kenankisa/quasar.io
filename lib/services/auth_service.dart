import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../utils/safe_debug.dart';
import 'admin_access.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool _initialized = false;

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId: AppConfig.googleWebClientId,
        );
      } catch (e, stackTrace) {
        safeDebugPrint('GoogleSignIn init failed: $e\n$stackTrace');
        return;
      }
    }

    _initialized = true;
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final redirectTo = AppConfig.webOAuthRedirectTo(Uri.base);
      if (redirectTo == null || redirectTo.isEmpty) {
        throw const AuthException(
          'OAuth redirect yapılandırılmadı (OAUTH_REDIRECT_ORIGIN).',
        );
      }
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      return;
    }

    await init();

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw const AuthException('Google ID token alınamadı.');
    }

    String? accessToken;
    final authz = await googleUser.authorizationClient.authorizationForScopes(
      const ['email', 'profile', 'openid'],
    );
    accessToken = authz?.accessToken;

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    await AdminAccess.refreshAdminStatus();
  }

  Future<void> signOut() async {
    // Önce Supabase oturumu — AuthGate hemen LoginScreen'e geçsin.
    AdminAccess.clearCache();
    await client.auth.signOut();
    if (!kIsWeb) {
      try {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
      } catch (_) {
        // Google oturumu yoksa veya zaten kapatılmışsa devam et.
      }
    }
  }
}
