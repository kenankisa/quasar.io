import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_version.dart';
import '../services/auth_service.dart';
import '../services/lang_service.dart';
import '../services/player_session_service.dart';
import '../services/settings_service.dart';
import '../utils/app_lifecycle.dart';
import '../utils/responsive_layout.dart';
import 'settings_dialog.dart';
import 'sound_settings_dialog.dart';
import 'neon_space_particle_painter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _particleController;
  late final AnimationController _glowController;
  late final AnimationController _enterController;
  bool _isSigningIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycle.shouldPause(state)) {
      _particleController.stop();
      _glowController.stop();
    } else {
      if (!_particleController.isAnimating) {
        _particleController.repeat();
      }
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _particleController.dispose();
    _glowController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return;
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signInWithGoogle();

      try {
        final status =
            await PlayerSessionService.instance.checkStatusAfterAuth();
        if (status.blockedOnOtherDevice) {
          await AuthService.instance.signOut();
          if (mounted) {
            setState(() {
              _errorMessage =
                  LanguageService.instance.t('player_already_active_message');
            });
          }
          return;
        }
        // Aktif oturum AuthGate.ensureAppSession ile açılır (giriş yeterli).
      } catch (e, st) {
        // Giriş başarılı; oturum AuthGate tarafında yeniden denenir.
        debugPrint('checkStatus after sign-in: $e\n$st');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(
          () => _errorMessage = LanguageService.instance.t('sign_in_error'),
        );
      }
    } catch (e) {
      if (!AuthService.instance.isSignedIn && mounted) {
        setState(
          () => _errorMessage = LanguageService.instance.t('sign_in_error'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _showLanguagePicker() {
    final lang = LanguageService.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A0A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  lang.t('select_language'),
                  style: const TextStyle(
                    color: Color(0xFF00F0FF),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...LanguageService.supportedLanguages.map((code) {
                final isSelected = lang.currentLanguage == code;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? const Color(0xFF00F0FF)
                        : Colors.white38,
                  ),
                  title: Text(
                    LanguageService.languageLabels[code] ?? code,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00F0FF) : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    lang.setLanguage(code);
                    Navigator.pop(context);
                    setState(() {});
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final size = MediaQuery.sizeOf(context);
    final r = ResponsiveLayout.of(context);
    final enter = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF020208),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: NeonSpaceParticlePainter(
                  progress: _particleController.value,
                  particleCount: 90,
                  seed: 42,
                  blurSigma: 4,
                  maxOpacity: 0.85,
                  driftAmplitude: 0.02,
                  drawGlow: true,
                ),
              );
            },
          ),
          // Atmospheric depth — cyan core + magenta rim
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 1.15,
                colors: [
                  const Color(0xFF0A1A33).withValues(alpha: 0.55),
                  const Color(0xFF1A0033).withValues(alpha: 0.45),
                  const Color(0xFF020208).withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          // Soft horizon glow behind brand
          Positioned(
            top: size.height * 0.18,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  final pulse = 0.35 + _glowController.value * 0.45;
                  return Center(
                    child: Container(
                      width: r.w(260),
                      height: r.w(260),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00F0FF).withValues(alpha: pulse * 0.14),
                            const Color(0xFFFF2D95).withValues(alpha: pulse * 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.w(12), r.h(8), r.w(12), 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListenableBuilder(
                          listenable: SettingsService.instance,
                          builder: (context, _) {
                            final enabled =
                                SettingsService.instance.musicEnabled;
                            return IconButton(
                              tooltip: lang.t('settings_sound_title'),
                              onPressed: () => SoundSettingsDialog.toggleMusic(),
                              icon: Icon(
                                enabled
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                color: enabled
                                    ? const Color(0xFF00F0FF)
                                    : Colors.white54,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: lang.t('settings_title'),
                          onPressed: () => SettingsDialog.show(context),
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Color(0xFF00F0FF),
                          ),
                        ),
                        _LanguageButton(onTap: _showLanguagePicker),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: enter,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(enter),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          _LoginBrandHero(
                            glowAnimation: _glowController,
                            responsive: r,
                          ),
                          SizedBox(height: r.h(28)),
                          if (_errorMessage != null) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: r.w(32)),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFFFF4466),
                                  fontSize: r.sp(13),
                                ),
                              ),
                            ),
                            SizedBox(height: r.h(14)),
                          ],
                          _GoogleSignInButton(
                            label: _isSigningIn
                                ? lang.t('signing_in')
                                : lang.t('sign_in_google'),
                            isLoading: _isSigningIn,
                            onPressed: _handleGoogleSignIn,
                            responsive: r,
                          ),
                          const Spacer(flex: 3),
                          Padding(
                            padding: EdgeInsets.only(bottom: r.h(16)),
                            child: Text(
                              AppVersion.display,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.32),
                                fontSize: r.sp(11),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lobby ile aynı Quasar.io marka dili — cyan / magenta glow.
class _LoginBrandHero extends StatelessWidget {
  const _LoginBrandHero({
    required this.glowAnimation,
    required this.responsive,
  });

  final Animation<double> glowAnimation;
  final ResponsiveLayout responsive;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final r = responsive;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.w(24)),
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, _) {
          final pulse = 0.45 + glowAnimation.value * 0.55;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icon/logo.png',
                width: r.w(160),
                height: r.w(160),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
              SizedBox(height: r.h(10)),
              Text(
                lang.t('lobby_brand_eyebrow').toUpperCase(),
                style: TextStyle(
                  color: const Color(0xFF7B2FFF).withValues(alpha: 0.9),
                  fontSize: r.sp(10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.2,
                ),
              ),
              SizedBox(height: r.h(10)),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Quasar',
                      style: TextStyle(
                        fontSize: r.sp(44),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        height: 1,
                        color: const Color(0xFF00F0FF),
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00F0FF)
                                .withValues(alpha: pulse * 0.85),
                            blurRadius: 28,
                          ),
                          Shadow(
                            color: const Color(0xFFFF00AA)
                                .withValues(alpha: pulse * 0.35),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: '.io',
                      style: TextStyle(
                        fontSize: r.sp(44),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                        height: 1,
                        color: const Color(0xFFFF2D95),
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFF2D95)
                                .withValues(alpha: pulse * 0.7),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.h(12)),
              Container(
                width: r.w(78),
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00F0FF).withValues(alpha: 0),
                      Color.lerp(
                        const Color(0xFF00F0FF),
                        const Color(0xFFFF00AA),
                        glowAnimation.value,
                      )!,
                      const Color(0xFFFF00AA).withValues(alpha: 0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F0FF)
                          .withValues(alpha: pulse * 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.h(14)),
              Text(
                lang.t('welcome_cosmic'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: r.sp(15),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.6,
                  height: 1.35,
                ),
              ),
              SizedBox(height: r.h(8)),
              Text(
                lang.t('login_atmosphere'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: r.sp(12.5),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.4,
                  height: 1.4,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, color: Color(0xFF00F0FF), size: 22),
              SizedBox(width: 6),
              Icon(Icons.arrow_drop_down, color: Color(0xFF00F0FF), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.responsive,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final ResponsiveLayout responsive;

  @override
  Widget build(BuildContext context) {
    final r = responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.w(36)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF00F0FF).withValues(alpha: 0.18),
                  const Color(0xFFFF00AA).withValues(alpha: 0.14),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFFFF00AA).withValues(alpha: 0.16),
                  blurRadius: 32,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.w(26),
                    vertical: r.h(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        SizedBox(
                          width: r.w(22),
                          height: r.w(22),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00F0FF),
                          ),
                        )
                      else
                        Container(
                          width: r.w(28),
                          height: r.w(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                color: const Color(0xFF4285F4),
                                fontWeight: FontWeight.bold,
                                fontSize: r.sp(18),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(width: r.w(14)),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.sp(16),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
