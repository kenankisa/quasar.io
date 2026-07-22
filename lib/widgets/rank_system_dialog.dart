import 'dart:ui';

import 'package:flutter/material.dart';

import '../game/models/app_rank_config.dart';
import '../services/app_rank_config_service.dart';
import '../services/lang_service.dart';
import '../utils/player_rank.dart';
import 'bot_name_badge.dart';

/// Visual guide: star ranks, thresholds, and win-point rules.
class RankSystemDialog extends StatelessWidget {
  const RankSystemDialog({
    super.key,
    this.playerRankPoints = 0,
  });

  final int playerRankPoints;

  static Future<void> show(
    BuildContext context, {
    int playerRankPoints = 0,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Rank System',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return RankSystemDialog(playerRankPoints: playerRankPoints);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final size = MediaQuery.sizeOf(context);
    final cfg = AppRankConfigService.instance.config;
    final currentTier = playerRankForPoints(playerRankPoints);
    // Lowest tier first for a climb story (Nebula → Singularity).
    final tiersAsc = playerRankTiers.reversed.toList();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.92,
          height: size.height * 0.78,
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF12122A).withValues(alpha: 0.95),
                const Color(0xFF0A0A1A).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.12),
                blurRadius: 28,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        PlayerRankBadge(
                          tier: currentTier,
                          size: 16,
                          compact: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lang.t('profile_rank_system'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text(
                      lang.t('rank_system_intro'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      children: [
                        _YourRankCard(
                          tier: currentTier,
                          points: playerRankPoints,
                          config: cfg,
                          lang: lang,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          lang.t('rank_system_ladder_title'),
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final tier in tiersAsc) ...[
                          _TierVisualRow(
                            tier: tier,
                            minPoints: cfg.minPointsForTier(tier.id),
                            isCurrent: tier.id == currentTier.id,
                            lang: lang,
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          lang.t('rank_system_earn_title'),
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _EarnPointsCard(config: cfg, lang: lang),
                        const SizedBox(height: 14),
                        Text(
                          lang.t('rank_system_note'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD54F),
                          foregroundColor: const Color(0xFF1A1200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(lang.t('rank_system_close')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YourRankCard extends StatelessWidget {
  const _YourRankCard({
    required this.tier,
    required this.points,
    required this.config,
    required this.lang,
  });

  final PlayerRankTier tier;
  final int points;
  final AppRankConfig config;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    final next = _nextTier(tier);
    final nextMin = next == null ? null : config.minPointsForTier(next.id);
    final progress = nextMin == null
        ? 1.0
        : ((points - config.minPointsForTier(tier.id)) /
                (nextMin - config.minPointsForTier(tier.id)))
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            tier.glowColor.withValues(alpha: 0.18),
            const Color(0xFF0A0A1A).withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: tier.borderColor.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('rank_system_your_rank'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PlayerRankBadge(tier: tier, size: 22, compact: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.localizedName(lang),
                      style: TextStyle(
                        color: tier.letterColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang
                          .t('rank_system_your_points')
                          .replaceAll('{points}', '$points'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (next != null && nextMin != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    lang
                        .t('rank_system_next')
                        .replaceAll('{tier}', next.localizedName(lang))
                        .replaceAll('{points}', '$nextMin'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ),
                PlayerRankBadge(tier: next, size: 12, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: tier.glowColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  PlayerRankTier? _nextTier(PlayerRankTier current) {
    final asc = playerRankTiers.reversed.toList();
    final i = asc.indexWhere((t) => t.id == current.id);
    if (i < 0 || i >= asc.length - 1) return null;
    return asc[i + 1];
  }
}

class _TierVisualRow extends StatelessWidget {
  const _TierVisualRow({
    required this.tier,
    required this.minPoints,
    required this.isCurrent,
    required this.lang,
  });

  final PlayerRankTier tier;
  final int minPoints;
  final bool isCurrent;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isCurrent
            ? tier.glowColor.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isCurrent
              ? tier.borderColor.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PlayerRankBadge(tier: tier, size: 15, compact: false),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.localizedName(lang),
                  style: TextStyle(
                    color: isCurrent ? tier.letterColor : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isCurrent)
                  Text(
                    lang.t('rank_system_current_badge'),
                    style: TextStyle(
                      color: tier.glowColor.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            tier.id == 'nebula' ? '0' : '$minPoints+',
            style: TextStyle(
              color: Colors.white.withValues(alpha: isCurrent ? 0.85 : 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnPointsCard extends StatelessWidget {
  const _EarnPointsCard({
    required this.config,
    required this.lang,
  });

  final AppRankConfig config;
  final LanguageService lang;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int, Color)>[
      (lang.t('admin_rank_points_simple'), config.winPointsSimple, const Color(0xFF90A4AE)),
      (lang.t('admin_rank_points_normal'), config.winPointsNormal, const Color(0xFF00F0FF)),
      (lang.t('admin_rank_points_elite'), config.winPointsElite, const Color(0xFFCE93D8)),
      (lang.t('admin_rank_points_unique'), config.winPointsUnique, const Color(0xFFFFD54F)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rows[i].$3,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  rows[i].$2 == 0
                      ? lang.t('rank_system_points_none')
                      : lang
                          .t('rank_system_points_per_win')
                          .replaceAll('{n}', '${rows[i].$2}'),
                  style: TextStyle(
                    color: rows[i].$3,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
