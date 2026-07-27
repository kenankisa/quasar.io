import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/lang_service.dart';
import 'services/room_tuning_service.dart';
import 'services/app_economy_config_service.dart';
import 'services/app_idle_config_service.dart';
import 'services/app_rank_config_service.dart';
import 'services/secure_session_storage.dart';
import 'services/settings_service.dart';
import 'utils/app_lifecycle.dart';
import 'utils/app_navigator.dart';
import 'utils/lang_rebuild.dart';
import 'utils/lang_scope.dart';
import 'utils/responsive_layout.dart';
import 'services/admin_access.dart';
import 'services/player_session_service.dart';
import 'widgets/idle_session_warning_overlay.dart';
import 'widgets/live_announcement_overlay.dart';
import 'widgets/lobby_screen.dart';
import 'widgets/login_screen.dart';
import 'services/live_announcement_service.dart';
import 'services/server_clock_service.dart';

final _appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF020208),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00F0FF),
    secondary: Color(0xFFFF00AA),
    surface: Color(0xFF0A0A1A),
  ),
  useMaterial3: true,
  splashFactory: NoSplash.splashFactory,
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(enableFeedback: false),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(enableFeedback: false),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(enableFeedback: false),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(enableFeedback: false),
  ),
);

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true;
  };

  await SettingsService.instance.init();
  unawaited(_startAmbientMusic());

  if (!AppConfig.hasRequiredConfig) {
    debugPrint(
      'Eksik yapılandırma: flutter run '
      '--dart-define-from-file=dart_defines.dev.json',
    );
    runApp(
      const _StartupErrorApp(
        message:
            'Uygulama yapılandırması eksik.\n'
            'dart_defines.dev.json oluşturup '
            '--dart-define-from-file ile çalıştırın.\n'
            '(Şablon: dart_defines.dev.json.example)',
      ),
    );
    FlutterNativeSplash.remove();
    return;
  }

  // Pre-store: allow test AdMob in release/profile; warn only.
  // Re-harden (StartupErrorApp) before Play Store when using real units.
  if (!kDebugMode &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      AppConfig.isUsingTestAdMobIds) {
    debugPrint(
      'WARNING: AdMob still using Google TEST ids. '
      'OK for internal builds — switch to dart_defines.prod.json before store.',
    );
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionLocalStorage(
          persistSessionKey: 'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token',
        ),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Supabase başlatma hatası: $e\n$stackTrace');
    runApp(const _StartupErrorApp());
    FlutterNativeSplash.remove();
    return;
  }

  runApp(const QuasarApp());

  unawaited(_bootstrapServices());
}

Future<void> _startAmbientMusic() async {
  try {
    await AudioService.instance.init();
    if (SettingsService.instance.musicEnabled &&
        AudioService.instance.assetReady) {
      await AudioService.instance.playAmbient();
    }
  } catch (e, stackTrace) {
    debugPrint('Müzik başlatma hatası: $e\n$stackTrace');
  }
}

Future<void> _bootstrapServices() async {
  // Never leave the native splash up if a service hangs.
  final splashWatchdog = Timer(const Duration(seconds: 4), () {
    FlutterNativeSplash.remove();
  });
  try {
    await LanguageService.instance
        .init()
        .timeout(const Duration(seconds: 3));
    unawaited(
      RoomTuningService.instance.init().catchError((Object e, StackTrace st) {
        debugPrint('RoomTuningService init: $e\n$st');
      }),
    );
    unawaited(
      AppIdleConfigService.instance.init().catchError((Object e, StackTrace st) {
        debugPrint('AppIdleConfigService init: $e\n$st');
      }),
    );
    unawaited(
      AppRankConfigService.instance.init().catchError((Object e, StackTrace st) {
        debugPrint('AppRankConfigService init: $e\n$st');
      }),
    );
    unawaited(
      AppEconomyConfigService.instance.init().catchError((Object e, StackTrace st) {
        debugPrint('AppEconomyConfigService init: $e\n$st');
      }),
    );
    // Google Sign-In + AdMob stay lazy (first sign-in / first ad) so a flaky
    // Play Services / Ads native path cannot kill the process on cold start.
    unawaited(
      AuthService.instance.init().catchError((Object e, StackTrace st) {
        debugPrint('AuthService init: $e\n$st');
      }),
    );
  } catch (e, stackTrace) {
    debugPrint('Bootstrap hatası: $e\n$stackTrace');
  } finally {
    splashWatchdog.cancel();
    FlutterNativeSplash.remove();
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _appTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message ??
                  'Uygulama başlatılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class QuasarApp extends StatefulWidget {
  const QuasarApp({super.key});

  @override
  State<QuasarApp> createState() => _QuasarAppState();
}

class _QuasarAppState extends State<QuasarApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycle.shouldPause(state)) {
      unawaited(AudioService.instance.pauseAmbient());
    } else {
      unawaited(AudioService.instance.playAmbient(fadeIn: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      child: LangRebuild(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            PlayerSessionService.instance.noteActivity();
            unawaited(AudioService.instance.tryResumeFromUserGesture());
          },
          child: MaterialApp(
            title: LanguageService.instance.t('app_title'),
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            builder: (context, child) {
              return LangRebuild(
                child: LiveAnnouncementOverlay(
                  child: IdleSessionWarningOverlay(
                    child: responsiveAppBuilder(context, child),
                  ),
                ),
              );
            },
            theme: _appTheme,
            home: const AuthGate(),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _boundUserId;
  Timer? _logoutDebounce;

  static const _logoutGrace = Duration(milliseconds: 900);

  @override
  void dispose() {
    _logoutDebounce?.cancel();
    super.dispose();
  }

  void _scheduleLogoutCleanup() {
    if (_logoutDebounce?.isActive ?? false) return;
    _logoutDebounce?.cancel();
    _logoutDebounce = Timer(_logoutGrace, () {
      if (!mounted) return;
      // Session came back during grace — stay signed in.
      if (Supabase.instance.client.auth.currentSession != null) return;
      final hadUser = _boundUserId != null;
      _boundUserId = null;
      if (!hadUser) return;
      AdminAccess.clearCache();
      popAppToRoot();
      unawaited(PlayerSessionService.instance.release());
      unawaited(LiveAnnouncementService.instance.detach());
      ServerClockService.instance.detach();
      setState(() {});
    });
  }

  void _cancelLogoutCleanup() {
    _logoutDebounce?.cancel();
    _logoutDebounce = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, _) {
        // currentSession kaynak doğruluk — stream yalnızca yeniden çizim tetikler.
        final session = Supabase.instance.client.auth.currentSession;
        final userId = session?.user.id;

        if (userId != null) {
          _cancelLogoutCleanup();
          if (_boundUserId != userId) {
            _boundUserId = userId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(AdminAccess.refreshAdminStatus());
              unawaited(PlayerSessionService.instance.ensureAppSession());
              ServerClockService.instance.attach();
              unawaited(LiveAnnouncementService.instance.attach());
            });
          }
          // Admin dahil herkes lobiye düşer — yönetim paneli gizli girişle açılır.
          return const LobbyScreen();
        }

        // Brief null sessions (token recover / refresh) must not pop AdminScreen.
        if (_boundUserId != null) {
          _scheduleLogoutCleanup();
          // Keep lobby (and pushed AdminScreen) mounted during grace.
          return const LobbyScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
