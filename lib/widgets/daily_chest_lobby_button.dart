import 'dart:async';

import 'package:flutter/material.dart';

import '../services/lang_service.dart';
import '../utils/lang_scope.dart';
import '../utils/match_time.dart';
import '../utils/responsive_layout.dart';
import 'cosmic_chest_icon.dart';

DateTime dailyChestNextUtcMidnight() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day + 1);
}

String dailyChestLobbyTooltip(
  LanguageService lang, {
  required bool available,
  DateTime? nextAvailableAt,
}) {
  if (available) return lang.t('daily_chest_tooltip_ready');
  final target = nextAvailableAt ?? dailyChestNextUtcMidnight();
  final remaining = target.toUtc().difference(DateTime.now().toUtc());
  if (remaining > Duration.zero) {
    return lang
        .t('daily_chest_tooltip_countdown')
        .replaceAll('{time}', formatCooldownRemaining(remaining));
  }
  return lang.t('daily_chest_tooltip_done');
}

/// Lobby header daily chest — glows when ready, passive with countdown when claimed.
class DailyChestLobbyButton extends StatefulWidget {
  const DailyChestLobbyButton({
    super.key,
    required this.available,
    this.nextAvailableAt,
    required this.onTap,
    this.glowAnimation,
    this.compact = false,
  });

  final bool available;
  final DateTime? nextAvailableAt;
  final VoidCallback? onTap;
  final Animation<double>? glowAnimation;
  final bool compact;

  @override
  State<DailyChestLobbyButton> createState() => _DailyChestLobbyButtonState();
}

class _DailyChestLobbyButtonState extends State<DailyChestLobbyButton> {
  Timer? _countdownTick;

  @override
  void initState() {
    super.initState();
    _syncCountdownTimer();
  }

  @override
  void didUpdateWidget(covariant DailyChestLobbyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.available != widget.available ||
        oldWidget.nextAvailableAt != widget.nextAvailableAt) {
      _syncCountdownTimer();
    }
  }

  void _syncCountdownTimer() {
    _countdownTick?.cancel();
    _countdownTick = null;
    if (!widget.available) {
      _countdownTick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _countdownTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final r = ResponsiveLayout.of(context);
    final chestSize = r.sp(
      widget.compact ? (r.isCompact ? 22 : 24) : (r.isCompact ? 28 : 32),
    );
    final radius = widget.compact ? 10.0 : 12.0;
    final tooltip = dailyChestLobbyTooltip(
      lang,
      available: widget.available,
      nextAvailableAt: widget.nextAvailableAt,
    );

    Widget chestBody(double blink, double glow) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.w(widget.compact ? 4 : (r.isCompact ? 6 : 8)),
          vertical: r.w(widget.compact ? 4 : (r.isCompact ? 4 : 5)),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: widget.available
              ? const Color(0xFFFFD24A)
                  .withValues(alpha: 0.08 + (widget.glowAnimation?.value ?? 0.5) * 0.10)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: widget.available
                ? const Color(0xFFFFD24A).withValues(
                    alpha: 0.35 +
                        (widget.glowAnimation?.value ?? 0.5) * 0.45,
                  )
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: widget.available
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD24A)
                        .withValues(alpha: glow * 0.75),
                    blurRadius: 14 + (widget.glowAnimation?.value ?? 0) * 10,
                    spreadRadius: (widget.glowAnimation?.value ?? 0) * 1.5,
                  ),
                ]
              : null,
        ),
        child: CosmicChestIcon(
          size: chestSize,
          lit: widget.available,
          opacity: widget.available ? blink : 0.40,
        ),
      );
    }

    final child = widget.glowAnimation != null
        ? AnimatedBuilder(
            animation: widget.glowAnimation!,
            builder: (context, _) {
              final blink = widget.available
                  ? (0.42 + widget.glowAnimation!.value * 0.58)
                  : 0.38;
              final glow = widget.available
                  ? (0.25 + widget.glowAnimation!.value * 0.65)
                  : 0.0;
              return chestBody(blink, glow);
            },
          )
        : chestBody(widget.available ? 1.0 : 0.40, 0.0);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.available ? widget.onTap : null,
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      ),
    );
  }
}
