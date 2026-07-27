import 'dart:async';

import 'package:flutter/material.dart';

import '../services/lang_service.dart';
import '../utils/lang_scope.dart';
import '../utils/match_time.dart';
import '../utils/responsive_layout.dart';

String dailyQuestLobbyTooltip(
  LanguageService lang, {
  required bool loaded,
  required int inProgressCount,
  required bool allComplete,
  DateTime? nextResetAt,
}) {
  if (allComplete) {
    return lang.t('daily_quest_tooltip_done');
  }
  if (inProgressCount > 0) {
    return lang
        .t('daily_quest_tooltip_active')
        .replaceAll('{count}', '$inProgressCount');
  }
  if (!loaded) return lang.t('daily_quest_tooltip_ready');
  if (nextResetAt != null) {
    final remaining = nextResetAt.toUtc().difference(DateTime.now().toUtc());
    if (remaining > Duration.zero) {
      return lang
          .t('daily_quest_tooltip_reset')
          .replaceAll('{time}', formatCooldownRemaining(remaining));
    }
  }
  return lang.t('daily_quest_tooltip_ready');
}

/// Lobby header daily quests — glows while quests are active.
class DailyQuestsLobbyButton extends StatefulWidget {
  const DailyQuestsLobbyButton({
    super.key,
    required this.loaded,
    required this.inProgressCount,
    required this.allComplete,
    this.nextResetAt,
    required this.onTap,
    this.compact = false,
  });

  final bool loaded;
  final int inProgressCount;
  final bool allComplete;
  final DateTime? nextResetAt;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<DailyQuestsLobbyButton> createState() => _DailyQuestsLobbyButtonState();
}

class _DailyQuestsLobbyButtonState extends State<DailyQuestsLobbyButton>
    with SingleTickerProviderStateMixin {
  Timer? _tick;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncTimer();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant DailyQuestsLobbyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextResetAt != widget.nextResetAt ||
        oldWidget.inProgressCount != widget.inProgressCount ||
        oldWidget.allComplete != widget.allComplete) {
      _syncTimer();
      _syncPulse();
    }
  }

  void _syncPulse() {
    final shouldPulse = widget.inProgressCount > 0 && !widget.allComplete;
    if (shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldPulse) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  void _syncTimer() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final inProgress = widget.inProgressCount > 0 && !widget.allComplete;
    final active = inProgress;
    final radius = widget.compact ? 10.0 : 12.0;
    final iconSize = r.sp(widget.compact ? 18 : 20);
    final tooltip = dailyQuestLobbyTooltip(
      lang,
      loaded: widget.loaded,
      inProgressCount: widget.inProgressCount,
      allComplete: widget.allComplete,
      nextResetAt: widget.nextResetAt,
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radius),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final pulse = active ? (0.35 + _pulse.value * 0.65) : 0.0;
              final bgAlpha = active
                  ? 0.10 + pulse * 0.10
                  : widget.loaded
                      ? 0.08
                      : 0.04;
              final borderAlpha = active
                  ? 0.40 + pulse * 0.35
                  : widget.loaded
                      ? 0.30
                      : 0.12;
              final iconColor = widget.allComplete
                  ? const Color(0xFF22FFAA)
                  : active
                      ? const Color(0xFF00F0FF)
                      : widget.loaded
                          ? const Color(0xFF80E8FF)
                          : Colors.white.withValues(alpha: 0.55);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.w(widget.compact ? 6 : 8),
                      vertical: r.w(widget.compact ? 5 : 6),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF00F0FF).withValues(alpha: bgAlpha),
                          const Color(0xFF00F0FF).withValues(alpha: bgAlpha * 0.45),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF00F0FF).withValues(alpha: borderAlpha),
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00F0FF)
                                    .withValues(alpha: 0.18 + pulse * 0.22),
                                blurRadius: 8 + pulse * 8,
                              ),
                            ]
                          : widget.loaded
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00F0FF)
                                        .withValues(alpha: 0.08),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                    ),
                    child: Icon(
                      widget.allComplete
                          ? Icons.verified_rounded
                          : Icons.flag_rounded,
                      size: iconSize,
                      color: iconColor,
                    ),
                  ),
                  if (inProgress)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00F0FF),
                          border: Border.all(
                            color: const Color(0xFF0A0A1A),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F0FF)
                                  .withValues(alpha: 0.55 + pulse * 0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
