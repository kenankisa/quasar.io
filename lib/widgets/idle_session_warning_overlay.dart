import 'package:flutter/material.dart';

import '../services/app_idle_config_service.dart';
import '../services/lang_service.dart';
import '../services/player_session_service.dart';

/// Lobi: geri sayımlı çıkış uyarısı.
/// Maç: önce geri sayım, sonra kütle erimesi uyarısı.
/// Sonuç ekranı: lobiye dönüş geri sayımı (kütle erimesi yok).
class IdleSessionWarningOverlay extends StatelessWidget {
  const IdleSessionWarningOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PlayerSessionService.instance,
        AppIdleConfigService.instance,
      ]),
      builder: (context, _) {
        final session = PlayerSessionService.instance;
        final lobbySeconds = session.warningSecondsRemaining;
        final matchCountdown = session.matchWarningSecondsRemaining;
        final matchResultExit = session.matchResultExitSecondsRemaining;
        final matchAfk = session.isMatchAfkActive;
        final matchDraining = session.isMatchAfkDraining;

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (lobbySeconds != null)
              Positioned.fill(
                child: _IdleWarningBanner(
                  mode: _IdleBannerMode.lobby,
                  seconds: lobbySeconds,
                ),
              )
            else if (matchResultExit != null)
              Positioned.fill(
                child: _IdleWarningBanner(
                  mode: _IdleBannerMode.matchResultExit,
                  seconds: matchResultExit,
                ),
              )
            else if (matchAfk && matchCountdown != null)
              Positioned.fill(
                child: _IdleWarningBanner(
                  mode: _IdleBannerMode.matchCountdown,
                  seconds: matchCountdown,
                ),
              )
            else if (matchAfk && matchDraining)
              Positioned.fill(
                child: _IdleWarningBanner(
                  mode: _IdleBannerMode.matchDrain,
                  seconds: AppIdleConfigService
                      .instance.config.matchKickMassThreshold,
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _IdleBannerMode { lobby, matchCountdown, matchDrain, matchResultExit }

class _IdleWarningBanner extends StatelessWidget {
  const _IdleWarningBanner({
    required this.mode,
    required this.seconds,
  });

  final _IdleBannerMode mode;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final config = AppIdleConfigService.instance.config;

    final title = switch (mode) {
      _IdleBannerMode.lobby => lang.t('idle_session_title'),
      _IdleBannerMode.matchResultExit => lang.t('idle_match_result_title'),
      _IdleBannerMode.matchCountdown ||
      _IdleBannerMode.matchDrain =>
        lang.t('idle_match_title'),
    };

    final message = switch (mode) {
      _IdleBannerMode.lobby => lang
          .t('idle_session_message')
          .replaceAll('{seconds}', '$seconds'),
      _IdleBannerMode.matchResultExit => lang
          .t('idle_match_result_message')
          .replaceAll('{seconds}', '$seconds'),
      _IdleBannerMode.matchCountdown => lang
          .t('idle_match_countdown_message')
          .replaceAll('{seconds}', '$seconds')
          .replaceAll('{drain}', '${config.matchMassDrainPerSecond}'),
      _IdleBannerMode.matchDrain => lang
          .t('idle_match_message')
          .replaceAll('{drain}', '${config.matchMassDrainPerSecond}')
          .replaceAll('{threshold}', '${config.matchKickMassThreshold}'),
    };

    final showBigCountdown = mode == _IdleBannerMode.lobby ||
        mode == _IdleBannerMode.matchCountdown ||
        mode == _IdleBannerMode.matchResultExit;

    final stayKey = switch (mode) {
      _IdleBannerMode.lobby => 'idle_session_stay',
      _IdleBannerMode.matchResultExit => 'idle_match_result_stay',
      _IdleBannerMode.matchCountdown ||
      _IdleBannerMode.matchDrain =>
        'idle_match_stay',
    };

    final accent = mode == _IdleBannerMode.matchResultExit
        ? const Color(0xFF00F0FF)
        : const Color(0xFFFF6688);

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF0A0A1A),
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
                if (showBigCountdown) ...[
                  const SizedBox(height: 18),
                  Text(
                    '$seconds',
                    style: TextStyle(
                      color: accent,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      PlayerSessionService.instance.noteActivity(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00F0FF),
                    foregroundColor: const Color(0xFF020208),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  child: Text(lang.t(stayKey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
