import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/config/hardcore_rules_copy.dart';

/// Lobby / help — 3-bullet Hardcore rules (same copy as first-match guide).
Future<void> showHardcoreRulesSheet(BuildContext context) {
  final lang = context.lang;
  const accent = Color(0xFFFF3355);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.12),
                const Color(0xFF0A0A1A).withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.whatshot_rounded, color: accent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.t('hardcore_onboarding_header'),
                        style: const TextStyle(
                          color: accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < hardcoreRulesSteps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _RuleBullet(
                    index: i + 1,
                    title: hardcoreRulesText(hardcoreRulesSteps[i].titleKey),
                    body: hardcoreRulesText(hardcoreRulesSteps[i].bodyKey),
                    accent: accent,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    lang.t('hardcore_rules_sheet_close'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _RuleBullet extends StatelessWidget {
  const _RuleBullet({
    required this.index,
    required this.title,
    required this.body,
    required this.accent,
  });

  final int index;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.16),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Text(
            '$index',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
