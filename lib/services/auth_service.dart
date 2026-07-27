import 'dart:async';
import 'dart:convert';

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

  /// While load-test / game-trial sims sign in on the same browser, GoTrue
  /// BroadcastChannel steals the main client's session. Pin the real admin
  /// session and restore it whenever a sim takeover is detected.
  Session? _pinnedSession;
  StreamSubscription<AuthState>? _pinGuardSub;
  bool _restoringPin = false;
  bool _pinActive = false;

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

  /// Call while spawning / running isolated sim clients (web BroadcastChannel).
  void pinCurrentSession() {
    final session = client.auth.currentSession;
    if (session == null) return;
    // Prefer an already-pinned admin session over a possibly-hijacked one.
    if (!_pinActive || _pinnedSession == null) {
      _pinnedSession = session;
    } else if (!_looksLikeSimUser(session.user)) {
      _pinnedSession = session;
    }
    _pinActive = true;
    _pinGuardSub ??= client.auth.onAuthStateChange.listen(_onAuthWhilePinned);
  }

  void unpinSession() {
    _pinActive = false;
    _pinnedSession = null;
    unawaited(_pinGuardSub?.cancel());
    _pinGuardSub = null;
  }

  Future<void> restorePinnedSession() async {
    final pinned = _pinnedSession;
    if (!_pinActive || pinned == null) return;
    await _restorePinned(pinned);
  }

  void _onAuthWhilePinned(AuthState state) {
    if (_restoringPin || !_pinActive) return;
    final pinned = _pinnedSession;
    if (pinned == null) return;

    final next = state.session;
    if (next == null) {
      // Sim sign-out broadcast wiped the main client.
      unawaited(_restorePinned(pinned));
      return;
    }
    if (next.user.id == pinned.user.id) {
      // Keep pin fresh on admin token refresh.
      _pinnedSession = next;
      return;
    }
    if (_looksLikeSimUser(next.user)) {
      unawaited(_restorePinned(pinned));
    }
  }

  bool _looksLikeSimUser(User user) {
    final meta = user.userMetadata ?? const <String, dynamic>{};
    if (meta['is_sim'] == true || meta['is_game_trial'] == true) return true;
    if (meta['is_sim'] == 'true' || meta['is_game_trial'] == 'true') {
      return true;
    }
    final email = (user.email ?? '').toLowerCase();
    return email.endsWith('@quasar.sim.local') ||
        (email.endsWith('@example.com') && email.startsWith('sim.'));
  }

  Future<void> _restorePinned(Session pinned) async {
    if (_restoringPin) return;
    _restoringPin = true;
    try {
      final current = client.auth.currentSession;
      if (current?.user.id == pinned.user.id) return;
      // Prefer setSession so admin stays the RPC principal. Sims must use
      // isolated accessToken clients (never GoTrue signIn on shared channel).
      final refresh = pinned.refreshToken;
      if (refresh != null && refresh.isNotEmpty) {
        await client.auth.setSession(
          refresh,
          accessToken: pinned.accessToken,
        );
      } else {
        await client.auth.recoverSession(jsonEncode(pinned.toJson()));
      }
      if (client.auth.currentUser?.id != pinned.user.id) {
        await client.auth.recoverSession(jsonEncode(pinned.toJson()));
      }
      safeDebugPrint('AuthService: restored pinned session after sim broadcast');
    } catch (e) {
      safeDebugPrint('AuthService: restore pinned session failed: $e');
    } finally {
      _restoringPin = false;
    }
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
    unpinSession();
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
