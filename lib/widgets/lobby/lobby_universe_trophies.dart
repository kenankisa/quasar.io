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
  static const _passiveBorder = Color(0xFF6E7D98);
  static const _passiveIcon = Color(0xFF8A97B0);
  static const _passiveFill = Color(0xFF121620);

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
        ? LobbyUniverseTrophies._litGold
        : LobbyUniverseTrophies._passiveIcon
            .withValues(alpha: dimmed ? 0.62 : 0.76);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? RadialGradient(
                colors: [
                  const Color(0xFFFFF176).withValues(alpha: 0.38),
                  LobbyUniverseTrophies._litGold.withValues(alpha: 0.16),
                ],
              )
            : null,
        color: active
            ? null
            : LobbyUniverseTrophies._passiveFill.withValues(alpha: 0.78),
        border: Border.all(
          color: active
              ? LobbyUniverseTrophies._litGold.withValues(alpha: 0.92)
              : LobbyUniverseTrophies._passiveBorder
                  .withValues(alpha: dimmed ? 0.58 : 0.72),
          width: active ? 1.1 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: LobbyUniverseTrophies._litGold.withValues(alpha: 0.32),
                  blurRadius: 5,
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        size: 13,
        color: color,
      ),
    );
  }
}
