import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/models/match_stats.dart';
import '../game/room_type.dart';
import '../services/player_session_service.dart';
import '../services/profile_service.dart';
import '../utils/match_time.dart';
import 'bot_name_badge.dart';
import 'match_result/match_result_shared.dart';
import 'match_stats_sheet.dart';
import 'reward_double_ad_button.dart';

class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    super.key,
    required this.roomType,
    required this.onContinue,
    this.showFirstTrainingTrophy = false,
    this.diamondReward,
    this.victoryElapsed = 0,
    required this.matchStats,
    this.ensureBaseClaimed,
    this.prepareSession,
    this.attestSession,
    this.claimDouble,
    this.ssvUserId,
  });

  final RoomType roomType;
  final VoidCallback onContinue;
  final bool showFirstTrainingTrophy;
  final int? diamondReward;
  final double victoryElapsed;
  final MatchStatsSnapshot matchStats;
  final Future<bool> Function()? ensureBaseClaimed;
  final Future<String?> Function()? prepareSession;
  final Future<bool> Function(String sessionId)? attestSession;
  final Future<PlayerProfile?> Function(String sessionId)? claimDouble;
  final String? ssvUserId;

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay> {
  @override
  void initState() {
    super.initState();
    final reward =
        widget.diamondReward ?? widget.roomType.diamondRewardForPlacement(1);
    if (reward > 0) {
      unawaited(ProfileService.instance.refreshMatchDayDiamonds());
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final reward =
        widget.diamondReward ?? widget.roomType.diamondRewardForPlacement(1);
    final canDouble = reward > 0 &&
        widget.roomType != RoomType.simple &&
        widget.ensureBaseClaimed != null &&
        widget.prepareSession != null &&
        widget.attestSession != null &&
        widget.claimDouble != null;

    return MatchResultShell(
      visual: MatchResultVisual.victory,
      title: lang.t('victory_title'),
      subtitle: lang
          .t('victory_time')
          .replaceAll('{time}', formatMatchTime(widget.victoryElapsed)),
      detail: reward > 0
          ? lang.t('victory_reward').replaceAll('{diamonds}', '$reward')
          : null,
      detailColor: const Color(0xFF00F0FF),
      footer: widget.showFirstTrainingTrophy
          ? Text(
              lang.t('victory_first_trophy_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      actions: Column(
        children: [
          MatchResultStatsButton(
            stats: widget.matchStats,
            accent: const Color(0xFFFFD700),
          ),
          const SizedBox(height: 10),
          if (canDouble) ...[
            RewardDoubleAdButton(
              baseDiamonds: reward,
              ensureBaseClaimed: widget.ensureBaseClaimed!,
              prepareSession: widget.prepareSession!,
              attestSession: widget.attestSession!,
              claimDouble: widget.claimDouble!,
              ssvUserId: widget.ssvUserId,
            ),
            const SizedBox(height: 12),
          ],
          MatchResultActions(
            primaryLabel: lang.t('victory_return_lobby'),
            primaryIcon: Icons.rocket_launch,
            primaryColor: canDouble
                ? const Color(0xFFFFD700)
                : const Color(0xFFFFD700),
            primaryFilled: !canDouble,
            onPrimary: () {
              PlayerSessionService.instance.noteActivity();
              widget.onContinue();
            },
          ),
        ],
      ),
    );
  }
}

/// Universe closed while another player won.
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
    this.attestSession,
    this.claimDouble,
    this.ssvUserId,
    this.showDoubleReward = false,
    required this.matchStats,
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
  final Future<bool> Function(String sessionId)? attestSession;
  final Future<PlayerProfile?> Function(String sessionId)? claimDouble;
  final String? ssvUserId;
  final bool showDoubleReward;
  final MatchStatsSnapshot matchStats;

  @override
  State<FrozenChampionOverlay> createState() => _FrozenChampionOverlayState();
}

class _FrozenChampionOverlayState extends State<FrozenChampionOverlay> {
  bool _isLeaving = false;

  MatchResultVisual get _visual {
    final place = widget.placement;
    if (place == 2) return MatchResultVisual.podiumSecond;
    if (place == 3) return MatchResultVisual.podiumThird;
    return MatchResultVisual.endedOut;
  }

  @override
  void initState() {
    super.initState();
    if (widget.diamondReward > 0) {
      unawaited(ProfileService.instance.refreshMatchDayDiamonds());
    }
  }

  Future<void> _handleLeave() async {
    if (_isLeaving) return;
    PlayerSessionService.instance.noteActivity();
    setState(() => _isLeaving = true);
    await widget.onLeave();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final place = widget.placement;
    final hasPodium = place != null && place >= 2 && place <= 3;
    final title = switch (place) {
      2 => lang.t('match_result_place_2_title'),
      3 => lang.t('match_result_place_3_title'),
      _ => lang.t('match_result_ended_title'),
    };
    final canDouble = widget.showDoubleReward &&
        widget.diamondReward > 0 &&
        widget.ensureBaseClaimed != null &&
        widget.prepareSession != null &&
        widget.attestSession != null &&
        widget.claimDouble != null;

    return MatchResultShell(
      visual: _visual,
      title: title,
      subtitle: MatchChampionResultText.buildPlain(
        template: lang.t('match_champion_result'),
        name: widget.championName,
        isBot: widget.isBot,
        rankPoints: widget.championRankPoints,
        time: formatMatchTime(widget.championElapsed),
      ),
      detail: hasPodium && widget.diamondReward > 0
          ? lang
              .t('frozen_placement_reward')
              .replaceAll('{place}', '$place')
              .replaceAll('{diamonds}', '${widget.diamondReward}')
          : null,
      detailColor: _visual.accent,
      actions: Column(
        children: [
          MatchResultStatsButton(
            stats: widget.matchStats,
            accent: _visual.accent,
          ),
          const SizedBox(height: 10),
          if (canDouble) ...[
            RewardDoubleAdButton(
              baseDiamonds: widget.diamondReward,
              ensureBaseClaimed: widget.ensureBaseClaimed!,
              prepareSession: widget.prepareSession!,
              attestSession: widget.attestSession!,
              claimDouble: widget.claimDouble!,
              ssvUserId: widget.ssvUserId,
              primaryColor: _visual.accent,
              foregroundColor: Colors.black,
            ),
            const SizedBox(height: 12),
          ],
          MatchResultActions(
            primaryLabel: lang.t('game_over_return_lobby'),
            primaryColor: _visual.accent,
            primaryFilled: !canDouble,
            onPrimary: _isLeaving ? null : _handleLeave,
          ),
        ],
      ),
    );
  }
}
