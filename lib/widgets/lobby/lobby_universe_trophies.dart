import 'package:flutter/material.dart';

import '../../utils/lang_scope.dart';

class LobbyUniverseTrophies extends StatelessWidget {
  const LobbyUniverseTrophies({
    super.key,
    required this.lit,
    required this.slots,
    required this.accent,
    required this.locked,
  });

  final int lit;
  final int slots;
  final Color accent;
  final bool locked;

  static const _litGold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final filled = lit.clamp(0, slots);
    return Semantics(
      label: lang
          .t('lobby_trophies_progress')
          .replaceAll('{lit}', '$filled')
          .replaceAll('{slots}', '$slots'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < slots; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _TrophyCup(
              active: i < filled,
              accent: accent,
              dimmed: locked,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrophyCup extends StatelessWidget {
  const _TrophyCup({
    required this.active,
    required this.accent,
    required this.dimmed,
  });

  final bool active;
  final Color accent;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? LobbyUniverseTrophies._litGold.withValues(alpha: dimmed ? 0.55 : 1)
        : Color.lerp(accent, const Color(0xFFFFE0A8), 0.45)!
            .withValues(alpha: dimmed ? 0.5 : 0.42);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? LobbyUniverseTrophies._litGold
                .withValues(alpha: dimmed ? 0.1 : 0.16)
            : accent.withValues(alpha: dimmed ? 0.14 : 0.1),
        border: Border.all(
          color: active
              ? LobbyUniverseTrophies._litGold
                  .withValues(alpha: dimmed ? 0.35 : 0.65)
              : Color.lerp(accent, const Color(0xFFFFE0A8), 0.4)!
                  .withValues(alpha: dimmed ? 0.45 : 0.38),
        ),
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        size: 13,
        color: color,
      ),
    );
  }
}
