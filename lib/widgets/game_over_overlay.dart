import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/orbit_game.dart';
import '../game/room_type.dart';
import '../services/lang_service.dart';
import '../utils/match_time.dart';
import 'bot_name_badge.dart';
import 'match_result/match_result_shared.dart';
import 'match_stats_sheet.dart';

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({
    super.key,
    required this.game,
    required this.onQuit,
    required this.onWatch,
    this.diamondPenalty = 1,
    this.hardcorePassiveElim = false,
  });

  final OrbitGame game;
  final Future<void> Function() onQuit;
  final VoidCallback onWatch;
  final int diamondPenalty;
  final bool hardcorePassiveElim;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _isQuitting = false;

  bool get _isHardcore => widget.game.roomType == RoomType.hardcore;

  Future<void> _handleQuit() async {
    if (_isQuitting) return;
    setState(() => _isQuitting = true);
    await widget.onQuit();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
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
    final watchLabel = _isHardcore
        ? lang.t('game_over_watch_hardcore')
        : texts['watch_match']!;

    String? detail;
    Color? detailColor;
    if (widget.diamondPenalty > 0) {
      detail = _isHardcore
          ? lang
              .t('game_over_hardcore_diamond_lost')
              .replaceAll('{diamonds}', '${widget.diamondPenalty}')
          : lang
              .t('game_over_diamond_penalty')
              .replaceAll('{diamonds}', '${widget.diamondPenalty}');
      detailColor = const Color(0xFFFF00AA);
    } else {
      detail = '${lang.t('game_over_peak_mass')}: '
          '${widget.game.maxRadiusReached.toStringAsFixed(0)}';
      detailColor = Colors.white.withValues(alpha: 0.55);
    }

    if (_isHardcore) {
      final cooldown = lang.t(widget.hardcorePassiveElim
          ? 'game_over_hardcore_cooldown_passive'
          : 'game_over_hardcore_cooldown');
      detail = '$detail · $cooldown';
    }

    final championName = widget.game.remoteChampionName.value;
    final championElapsed = widget.game.remoteChampionElapsed.value;
    final championLine = championName != null && championElapsed != null
        ? MatchChampionResultText.buildPlain(
            template: lang.t('match_champion_result'),
            name: championName,
            isBot: widget.game.remoteChampionIsBot.value,
            rankPoints: widget.game.remoteChampionRankPoints.value,
            time: formatMatchTime(championElapsed),
          )
        : null;

    return ListenableBuilder(
      listenable: widget.game.remoteChampionName,
      builder: (context, _) {
        final canWatch = !_isHardcore &&
            widget.game.remoteChampionName.value == null &&
            !widget.game.isUniverseClosed;

        return MatchResultShell(
          visual: MatchResultVisual.eliminated,
          title: texts['title']!,
          subtitle: championLine ?? texts['subtitle']!,
          detail: detail,
          detailColor: detailColor,
          actions: Column(
            children: [
              MatchResultStatsButton(
                stats: widget.game.matchStatsSnapshot(),
                accent: const Color(0xFFFF00AA),
              ),
              const SizedBox(height: 10),
              MatchResultActions(
                secondaryLabel: canWatch ? watchLabel : null,
                onSecondary: canWatch ? widget.onWatch : null,
                primaryLabel: texts['return_lobby']!,
                primaryColor: const Color(0xFF00F0FF),
                primaryFilled: !canWatch,
                onPrimary: _isQuitting ? null : _handleQuit,
              ),
            ],
          ),
        );
      },
    );
  }
}
