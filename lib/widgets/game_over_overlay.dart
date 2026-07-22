import 'package:flutter/material.dart';

import '../game/orbit_game.dart';
import '../services/lang_service.dart';
import '../utils/match_time.dart';
import 'bot_name_badge.dart';

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.game,
    required this.onQuit,
    required this.onWatch,
    this.diamondPenalty = 1,
  });

  final OrbitGame game;
  final Future<void> Function() onQuit;
  final VoidCallback onWatch;
  final int diamondPenalty;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _isQuitting = false;

  Future<void> _handleQuit() async {
    if (_isQuitting) return;
    setState(() => _isQuitting = true);
    await widget.onQuit();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final texts = lang.gameOverTexts;
    return ValueListenableBuilder<int>(
      valueListenable: widget.game.hudTick,
      builder: (context, _, _) => _buildBody(context, lang, texts),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LanguageService lang,
    Map<String, String> texts,
  ) {
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.blur_circular,
                size: 72,
                color: const Color(0xFFFF00AA).withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                texts['title']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF00F0FF),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                texts['subtitle']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${lang.t('game_over_peak_mass')}: ${widget.game.maxRadiusReached.toStringAsFixed(0)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              if (widget.diamondPenalty > 0) ...[
                const SizedBox(height: 8),
                Text(
                  lang
                      .t('game_over_diamond_penalty')
                      .replaceAll('{diamonds}', '${widget.diamondPenalty}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFFF00AA).withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              ListenableBuilder(
                listenable: Listenable.merge([
                  widget.game.remoteChampionName,
                  widget.game.remoteChampionElapsed,
                  widget.game.remoteChampionIsBot,
                  widget.game.remoteChampionRankPoints,
                ]),
                builder: (context, _) {
                  final championName = widget.game.remoteChampionName.value;
                  final elapsed = widget.game.remoteChampionElapsed.value;
                  if (championName == null || elapsed == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
                        border: Border.all(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: MatchChampionResultText(
                          template: lang.t('match_champion_result'),
                          name: championName,
                          isBot: widget.game.remoteChampionIsBot.value,
                          rankPoints: widget.game.remoteChampionRankPoints.value,
                          time: formatMatchTime(elapsed),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              ValueListenableBuilder<String?>(
                valueListenable: widget.game.remoteChampionName,
                builder: (context, championName, _) {
                  final canWatch = championName == null &&
                      !widget.game.isUniverseClosed;
                  return Column(
                    children: [
                      if (canWatch) ...[
                        _CosmicButton(
                          label: texts['watch_match']!,
                          icon: Icons.visibility_outlined,
                          primary: true,
                          onPressed: widget.onWatch,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _CosmicButton(
                        label: texts['return_lobby']!,
                        icon: Icons.home_rounded,
                        primary: !canWatch,
                        onPressed: _isQuitting ? null : _handleQuit,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CosmicButton extends StatelessWidget {
  const _CosmicButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: primary
              ? const Color(0xFF00F0FF)
              : const Color(0xFF1A1A3A),
          foregroundColor: primary ? Colors.black : const Color(0xFF00F0FF),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: const Color(0xFF00F0FF).withValues(alpha: primary ? 0 : 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
