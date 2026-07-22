import 'package:flutter/material.dart';

import '../game/orbit_game.dart';
import '../services/lang_service.dart';
import '../utils/match_time.dart';
import 'bot_name_badge.dart';

/// Shown while spectating after elimination — stop-watching bar and match-end banner.
class SpectatorOverlay extends StatelessWidget {
  const SpectatorOverlay({
    super.key,
    required this.game,
    required this.onQuit,
    required this.onStopWatching,
  });

  final OrbitGame game;
  final Future<void> Function() onQuit;
  final VoidCallback onStopWatching;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        game.remoteChampionName,
        game.remoteChampionElapsed,
        game.remoteChampionIsBot,
        game.remoteChampionRankPoints,
      ]),
      builder: (context, _) {
        final championName = game.remoteChampionName.value;
        final elapsed = game.remoteChampionElapsed.value;
        final matchEnded = championName != null && elapsed != null;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: 0.78),
                border: Border.all(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (matchEnded) ...[
                      MatchChampionResultText(
                        template: lang.t('match_champion_result'),
                        name: championName,
                        isBot: game.remoteChampionIsBot.value,
                        rankPoints: game.remoteChampionRankPoints.value,
                        time: formatMatchTime(elapsed),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => onQuit(),
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: Text(lang.t('game_over_return_lobby')),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00F0FF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onStopWatching,
                          icon: const Icon(Icons.visibility_off_outlined, size: 18),
                          label: Text(lang.t('spectator_stop_watching')),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A3A),
                            foregroundColor: const Color(0xFF00F0FF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: const Color(0xFF00F0FF)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
