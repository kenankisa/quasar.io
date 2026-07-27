import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/lang_scope.dart';

import '../game/config/room_visual_theme.dart';
import '../game/room_type.dart';
import '../services/profile_service.dart';
import '../utils/lang_rebuild.dart';
import 'lobby/lobby_universe_trophies.dart';

/// Explains universe cups + Hardcore unlock with a visual breakdown.
class UniverseTrophiesDialog extends StatelessWidget {
  const UniverseTrophiesDialog({super.key, required this.profile});

  final PlayerProfile profile;

  static Future<void> show(
    BuildContext context, {
    required PlayerProfile profile,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Universe Trophies',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return LangRebuild(child: UniverseTrophiesDialog(profile: profile));
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

  static const _gold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final size = MediaQuery.sizeOf(context);
    final earned = profile.totalUniverseTrophies;
    final cap = PlayerProfile.hardcoreTrophyRequirement;
    final cupsComplete = profile.hasHardcoreTrophyUnlock;
    final remaining = (cap - earned).clamp(0, cap);
    final progress = (earned / cap).clamp(0.0, 1.0);
    const fill = _gold;

    final rows = <({RoomType type, String titleKey})>[
      (type: RoomType.simple, titleKey: 'room_simple_title'),
      (type: RoomType.normal, titleKey: 'room_normal_title'),
      (type: RoomType.elite, titleKey: 'room_elite_title'),
      (type: RoomType.unique, titleKey: 'room_unique_title'),
    ];

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
            border: Border.all(color: fill.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: fill.withValues(alpha: 0.12),
                blurRadius: 24,
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: fill,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lang.t('profile_trophies_dialog_title'),
                            style: TextStyle(
                              color: fill,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      lang.t('profile_trophies_dialog_intro'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        for (final row in rows) ...[
                          _UniverseTrophyRow(
                            title: lang.t(row.titleKey),
                            lit: profile.trophyWinsFor(row.type),
                            slots: row.type.trophySlotCount,
                            accent: RoomVisualTheme.forRoom(row.type).accent,
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.04),
                            border: Border.all(
                              color: fill.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    lang.t('profile_trophies_total'),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$earned / $cap',
                                    style: TextStyle(
                                      color: fill,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  color: fill,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _HardcoreInfoPanel(
                          cupsComplete: cupsComplete,
                          remaining: remaining,
                          cap: cap,
                        ),
                      ],
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

class _UniverseTrophyRow extends StatelessWidget {
  const _UniverseTrophyRow({
    required this.title,
    required this.lit,
    required this.slots,
    required this.accent,
  });

  final String title;
  final int lit;
  final int slots;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.1),
            const Color(0xFF0A0A1A).withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$lit / $slots',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          LobbyUniverseTrophies(
            lit: lit,
            slots: slots,
            accent: accent,
            locked: false,
          ),
        ],
      ),
    );
  }
}

class _HardcoreInfoPanel extends StatelessWidget {
  const _HardcoreInfoPanel({
    required this.cupsComplete,
    required this.remaining,
    required this.cap,
  });

  final bool cupsComplete;
  final int remaining;
  final int cap;

  static const _accent = Color(0xFFFF3B4A);
  static const _ember = Color(0xFFFF7A3B);

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: 0.12),
            const Color(0xFF1A0A0C).withValues(alpha: 0.9),
            const Color(0xFF050208),
          ],
        ),
        border: Border.all(
          color: _accent.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.1),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _ember.withValues(alpha: 0.45),
                      _accent.withValues(alpha: 0.15),
                    ],
                  ),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.whatshot_rounded,
                  color: _accent.withValues(alpha: 0.85),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.t('room_hardcore_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.t('room_hardcore_desc'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lang.t('profile_trophies_hardcore_body'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                color: _accent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  cupsComplete
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 16,
                  color: _accent.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cupsComplete
                        ? lang.t('profile_hardcore_unlocked')
                        : lang.t('room_hardcore_lock')
                            .replaceAll('{earned}', '${cap - remaining}')
                            .replaceAll('{cap}', '$cap'),
                    style: TextStyle(
                      color: _accent.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cupsComplete
                ? lang.t('profile_hardcore_unlocked')
                : lang
                    .t('profile_hardcore_locked')
                    .replaceAll('{remaining}', '$remaining')
                    .replaceAll('{cap}', '$cap'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
