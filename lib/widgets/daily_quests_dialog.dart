import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_quest.dart';
import '../services/profile_service.dart';
import '../utils/lang_scope.dart';
import '../utils/diamond_ui.dart';
import '../utils/responsive_layout.dart';

class DailyQuestsDialog extends StatefulWidget {
  const DailyQuestsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const DailyQuestsDialog(),
    );
  }

  @override
  State<DailyQuestsDialog> createState() => _DailyQuestsDialogState();
}

class _DailyQuestsDialogState extends State<DailyQuestsDialog> {
  bool _loading = true;
  String? _errorKey;
  DailyQuestsStatus? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final status = await ProfileService.instance.fetchDailyQuestsStatus();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = status;
      _errorKey = status == null ? 'daily_quest_error' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final status = _status;

    return Dialog(
      backgroundColor: const Color(0xFF0A0A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: const Color(0xFF00F0FF).withValues(alpha: 0.25)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.w(420)),
        child: Padding(
          padding: EdgeInsets.all(r.w(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    color: const Color(0xFF00F0FF),
                    size: r.sp(22),
                  ),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: Text(
                      lang.t('daily_quest_title'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.sp(18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              Text(
                lang.t('daily_quest_subtitle'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: r.sp(12.5),
                ),
              ),
              SizedBox(height: r.h(14)),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
                  ),
                )
              else if (_errorKey != null && status == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    lang.t(_errorKey!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFF6688)),
                  ),
                )
              else ...[
                _SummaryCard(status: status!),
                SizedBox(height: r.h(10)),
                ...status.quests.map((q) => _QuestCard(quest: q)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.status});

  final DailyQuestsStatus status;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final total = status.totalQuests > 0 ? status.totalQuests : 3;
    final progress = total == 0 ? 0.0 : (status.completedCount / total).clamp(0.0, 1.0);
    final done = status.allComplete;

    final detail = done
        ? lang.t('daily_quest_all_done')
        : lang
            .t('daily_quest_progress_summary')
            .replaceAll('{current}', '${status.completedCount}')
            .replaceAll('{total}', '$total');

    return Container(
      padding: EdgeInsets.all(r.w(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: done ? 0.92 : 0.72),
                    fontSize: r.sp(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (done)
                Icon(
                  Icons.check_circle_rounded,
                  size: r.sp(16),
                  color: const Color(0xFF22FFAA),
                ),
            ],
          ),
          SizedBox(height: r.h(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: done
                  ? const Color(0xFF22FFAA)
                  : const Color(0xFF00F0FF),
            ),
          ),
          SizedBox(height: r.h(8)),
          Wrap(
            spacing: r.w(10),
            runSpacing: r.h(4),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RewardLegend(
                label: lang.t('daily_quest_difficulty_easy'),
                amount: DailyQuestIds.completionRewardFor('easy'),
                color: const Color(0xFF22FFAA),
              ),
              _RewardLegend(
                label: lang.t('daily_quest_difficulty_medium'),
                amount: DailyQuestIds.completionRewardFor('medium'),
                color: const Color(0xFFFFD24A),
              ),
              _RewardLegend(
                label: lang.t('daily_quest_difficulty_hard'),
                amount: DailyQuestIds.completionRewardFor('hard'),
                color: const Color(0xFFFF6688),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardLegend extends StatelessWidget {
  const _RewardLegend({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: r.w(6),
          height: r.w(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: r.w(4)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: r.sp(10.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: r.w(4)),
        DiamondAmount(
          amount: amount,
          prefix: '+',
          fontSize: r.sp(10.5),
          fontWeight: FontWeight.w700,
          color: kDiamondColor,
          iconSize: r.sp(11),
        ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final DailyQuestEntry quest;

  Color _difficultyColor(String difficulty) => switch (difficulty) {
        'easy' => const Color(0xFF22FFAA),
        'medium' => const Color(0xFFFFD24A),
        'hard' => const Color(0xFFFF6688),
        _ => const Color(0xFF00F0FF),
      };

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final color = _difficultyColor(quest.difficulty);
    final title = lang.t(DailyQuestIds.titleKey(quest.questId));
    final difficulty = lang.t(DailyQuestIds.difficultyKey(quest.difficulty));

    final statusStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: r.sp(11.5),
    );

    Widget statusWidget;
    if (quest.claimed) {
      statusWidget = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: r.w(4),
        runSpacing: r.h(2),
        children: [
          Text(lang.t('daily_quest_auto_rewarded_prefix'), style: statusStyle),
          DiamondAmount(
            amount: quest.rewardDiamonds,
            prefix: '+',
            fontSize: r.sp(11.5),
            fontWeight: FontWeight.w700,
            textColor: kDiamondColor,
            iconColor: kDiamondColor,
            iconSize: r.sp(12),
          ),
          Text(lang.t('daily_quest_auto_rewarded_suffix'), style: statusStyle),
        ],
      );
    } else if (quest.completed) {
      statusWidget = Text(lang.t('daily_quest_complete'), style: statusStyle);
    } else if (quest.showProgress) {
      statusWidget = Text(
        lang
            .t('daily_quest_progress')
            .replaceAll('{current}', '${quest.progress}')
            .replaceAll('{target}', '${quest.target}'),
        style: statusStyle,
      );
    } else {
      statusWidget = Text(lang.t('daily_quest_in_progress'), style: statusStyle);
    }

    return Container(
      margin: EdgeInsets.only(bottom: r.h(10)),
      padding: EdgeInsets.all(r.w(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: quest.claimed
              ? const Color(0xFF22FFAA).withValues(alpha: 0.35)
              : color.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  difficulty,
                  style: TextStyle(
                    color: color,
                    fontSize: r.sp(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (quest.claimed) ...[
                SizedBox(width: r.w(6)),
                Icon(
                  Icons.check_circle_rounded,
                  size: r.sp(14),
                  color: const Color(0xFF22FFAA),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DiamondAmount(
                    amount: quest.rewardDiamonds,
                    prefix: '+',
                    fontSize: r.sp(13),
                    textColor: kDiamondColor,
                    iconColor: kDiamondColor,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: r.h(8)),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: r.sp(14),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.h(4)),
          statusWidget,
        ],
      ),
    );
  }
}
