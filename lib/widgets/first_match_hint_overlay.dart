import 'package:flutter/material.dart';

import '../game/orbit_game.dart';
import '../services/lang_service.dart';
import '../game/config/first_match_tuning.dart';
import '../utils/responsive_layout.dart';

/// Short onboarding tips during the player's first match.
class FirstMatchHintOverlay extends StatelessWidget {
  const FirstMatchHintOverlay({super.key, required this.game});

  final OrbitGame game;

  @override
  Widget build(BuildContext context) {
    if (!FirstMatchTuning.shouldShowHints(game.isFirstMatchExperience)) {
      return const SizedBox.shrink();
    }

    final elapsed = game.matchElapsed;
    if (elapsed >= FirstMatchTuning.hintDurationSeconds) {
      return const SizedBox.shrink();
    }

    final lang = LanguageService.instance;
    final r = ResponsiveLayout.of(context);
    final hintKey = elapsed < 12
        ? 'first_match_hint_move'
        : elapsed < 22
            ? 'first_match_hint_absorb'
            : 'first_match_hint_grow';

    return Positioned(
      left: r.w(20),
      right: r.w(20),
      bottom: r.h(118),
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: elapsed < 28 ? 1 : (30 - elapsed).clamp(0.0, 1.0),
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.w(16),
              vertical: r.h(12),
            ),
            decoration: BoxDecoration(
              color: const Color(0xCC050510),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Text(
              lang.t(hintKey),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: r.sp(14),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
