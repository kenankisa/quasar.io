import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/room_type.dart';
import '../services/lang_service.dart';
import '../services/player_session_service.dart';
import '../services/profile_service.dart';
import '../utils/match_time.dart';
import 'bot_name_badge.dart';
import 'reward_double_ad_button.dart';

class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    super.key,
    required this.roomType,
    required this.onContinue,
    this.diamondReward,
    this.victoryElapsed = 0,
    this.ensureBaseClaimed,
    this.prepareSession,
    this.claimDouble,
  });

  final RoomType roomType;
  final VoidCallback onContinue;
  final int? diamondReward;
  final double victoryElapsed;
  final Future<bool> Function()? ensureBaseClaimed;
  final Future<String?> Function()? prepareSession;
  final Future<PlayerProfile?> Function(String sessionId)? claimDouble;

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final reward =
        widget.diamondReward ?? widget.roomType.diamondRewardForPlacement(1);

    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              return CustomPaint(
                painter: _VictoryBurstPainter(t),
              );
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 88,
                    color: Color(0xFFFFD700),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    lang.t('victory_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          color: Color(0xFFFF00AA),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.t('victory_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang
                        .t('victory_time')
                        .replaceAll('{time}', formatMatchTime(widget.victoryElapsed)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListenableBuilder(
                    listenable: ProfileService.instance.profileNotifier,
                    builder: (context, _) {
                      final diamonds =
                          ProfileService.instance.profileNotifier.value
                                  ?.diamonds ??
                              0;
                      return Column(
                        children: [
                          Text(
                            lang
                                .t('victory_reward')
                                .replaceAll('{diamonds}', '$reward'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF00F0FF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${lang.t('lobby_diamonds')}: $diamonds',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  if (reward > 0 &&
                      widget.roomType != RoomType.simple &&
                      widget.ensureBaseClaimed != null &&
                      widget.prepareSession != null &&
                      widget.claimDouble != null) ...[
                    RewardDoubleAdButton(
                      baseDiamonds: reward,
                      ensureBaseClaimed: widget.ensureBaseClaimed!,
                      prepareSession: widget.prepareSession!,
                      claimDouble: widget.claimDouble!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        PlayerSessionService.instance.noteActivity();
                        widget.onContinue();
                      },
                      icon: const Icon(Icons.rocket_launch),
                      label: Text(lang.t('victory_return_lobby')),
                      style: FilledButton.styleFrom(
                        backgroundColor: reward > 0 &&
                                widget.roomType != RoomType.simple &&
                                widget.claimDouble != null
                            ? const Color(0xFF1A1A3A)
                            : const Color(0xFFFFD700),
                        foregroundColor: reward > 0 &&
                                widget.roomType != RoomType.simple &&
                                widget.claimDouble != null
                            ? const Color(0xFFFFD700)
                            : Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: reward > 0 &&
                                    widget.roomType != RoomType.simple &&
                                    widget.claimDouble != null
                                ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.t('idle_match_result_hint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VictoryBurstPainter extends CustomPainter {
  _VictoryBurstPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.65;

    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2 + t * math.pi;
      final r = maxR * (0.55 + t * 0.45);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(
        center + Offset(math.cos(angle) * r * 0.35, math.sin(angle) * r * 0.35),
        r * 0.25,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VictoryBurstPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Shown when another player finishes and the room closes for everyone.
class FrozenChampionOverlay extends StatefulWidget {
  const FrozenChampionOverlay({
    super.key,
    required this.championName,
    required this.championElapsed,
    required this.onLeave,
    this.isBot = false,
    this.championRankPoints,
    this.placement,
    this.diamondReward = 0,
    this.ensureBaseClaimed,
    this.prepareSession,
    this.claimDouble,
    this.showDoubleReward = false,
  });

  final String championName;
  final double championElapsed;
  final Future<void> Function() onLeave;
  final bool isBot;
  final int? championRankPoints;
  final int? placement;
  final int diamondReward;
  final Future<bool> Function()? ensureBaseClaimed;
  final Future<String?> Function()? prepareSession;
  final Future<PlayerProfile?> Function(String sessionId)? claimDouble;
  final bool showDoubleReward;

  @override
  State<FrozenChampionOverlay> createState() => _FrozenChampionOverlayState();
}

class _FrozenChampionOverlayState extends State<FrozenChampionOverlay> {
  bool _isLeaving = false;

  Future<void> _handleLeave() async {
    if (_isLeaving) return;
    PlayerSessionService.instance.noteActivity();
    setState(() => _isLeaving = true);
    await widget.onLeave();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_outline,
                size: 64,
                color: Color(0xFF00F0FF),
              ),
              const SizedBox(height: 16),
              Text(
                lang.t('frozen_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF00F0FF),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              MatchChampionResultText(
                template: lang.t('match_champion_result'),
                name: widget.championName,
                isBot: widget.isBot,
                rankPoints: widget.championRankPoints,
                time: formatMatchTime(widget.championElapsed),
              ),
              if (widget.diamondReward > 0 && widget.placement != null) ...[
                const SizedBox(height: 12),
                Text(
                  lang
                      .t('frozen_placement_reward')
                      .replaceAll('{place}', '${widget.placement}')
                      .replaceAll('{diamonds}', '${widget.diamondReward}'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF00F0FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                lang.t('frozen_room_closed'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.showDoubleReward &&
                  widget.diamondReward > 0 &&
                  widget.ensureBaseClaimed != null &&
                  widget.prepareSession != null &&
                  widget.claimDouble != null) ...[
                RewardDoubleAdButton(
                  baseDiamonds: widget.diamondReward,
                  ensureBaseClaimed: widget.ensureBaseClaimed!,
                  prepareSession: widget.prepareSession!,
                  claimDouble: widget.claimDouble!,
                  primaryColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLeaving ? null : _handleLeave,
                  icon: const Icon(Icons.home_rounded),
                  label: Text(lang.t('game_over_return_lobby')),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.showDoubleReward &&
                            widget.diamondReward > 0
                        ? const Color(0xFF1A1A3A)
                        : const Color(0xFF00F0FF),
                    foregroundColor: widget.showDoubleReward &&
                            widget.diamondReward > 0
                        ? const Color(0xFF00F0FF)
                        : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: widget.showDoubleReward &&
                                widget.diamondReward > 0
                            ? const Color(0xFF00F0FF).withValues(alpha: 0.45)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lang.t('idle_match_result_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
