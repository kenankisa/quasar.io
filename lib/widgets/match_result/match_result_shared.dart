import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual identity for each post-match outcome.
enum MatchResultVisual {
  /// Local player won — gold radial burst.
  victory,

  /// Absorbed / eliminated — collapsing magenta rings.
  eliminated,

  /// Universe closed, 2nd on podium — silver shimmer.
  podiumSecond,

  /// Universe closed, 3rd on podium — bronze glow.
  podiumThird,

  /// Universe closed without podium (4th+, or out before finish).
  endedOut,
}

extension MatchResultVisualX on MatchResultVisual {
  Color get accent => switch (this) {
        MatchResultVisual.victory => const Color(0xFFFFD700),
        MatchResultVisual.eliminated => const Color(0xFFFF00AA),
        MatchResultVisual.podiumSecond => const Color(0xFFC0C8D8),
        MatchResultVisual.podiumThird => const Color(0xFFE08A4A),
        MatchResultVisual.endedOut => const Color(0xFF5A6A7A),
      };

  IconData get icon => switch (this) {
        MatchResultVisual.victory => Icons.auto_awesome,
        MatchResultVisual.eliminated => Icons.blur_circular,
        MatchResultVisual.podiumSecond => Icons.looks_two_rounded,
        MatchResultVisual.podiumThird => Icons.looks_3_rounded,
        MatchResultVisual.endedOut => Icons.nights_stay_outlined,
      };

  double get scrimOpacity => switch (this) {
        MatchResultVisual.victory => 0.9,
        MatchResultVisual.eliminated => 0.86,
        _ => 0.82,
      };
}

/// Compact post-match layout with per-outcome background animation.
class MatchResultShell extends StatefulWidget {
  const MatchResultShell({
    super.key,
    required this.visual,
    required this.title,
    this.subtitle,
    this.detail,
    this.detailColor,
    this.footer,
    required this.actions,
  });

  final MatchResultVisual visual;
  final String title;
  final String? subtitle;
  final String? detail;
  final Color? detailColor;
  final Widget? footer;
  final Widget actions;

  @override
  State<MatchResultShell> createState() => _MatchResultShellState();
}

class _MatchResultShellState extends State<MatchResultShell>
    with TickerProviderStateMixin {
  late final AnimationController _bg;
  late final AnimationController _enter;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _bg = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _enter.forward();
  }

  @override
  void dispose() {
    _bg.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.visual.accent;

    return Material(
      color: Colors.black.withValues(alpha: widget.visual.scrimOpacity),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _bg,
            builder: (context, _) => CustomPaint(
              painter: _MatchResultBgPainter(
                visual: widget.visual,
                t: _bg.value,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.72, end: 1).animate(_scale),
                        child: Icon(
                          widget.visual.icon,
                          size: 76,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          height: 1.2,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (widget.detail != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          widget.detail!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.detailColor ?? accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                      if (widget.footer != null) ...[
                        const SizedBox(height: 16),
                        widget.footer!,
                      ],
                      const SizedBox(height: 32),
                      widget.actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchResultBgPainter extends CustomPainter {
  _MatchResultBgPainter({required this.visual, required this.t});

  final MatchResultVisual visual;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (visual) {
      case MatchResultVisual.victory:
        _paintVictoryBurst(canvas, size);
      case MatchResultVisual.eliminated:
        _paintCollapse(canvas, size);
      case MatchResultVisual.podiumSecond:
        _paintShimmer(canvas, size, const Color(0xFFC0C8D8));
      case MatchResultVisual.podiumThird:
        _paintShimmer(canvas, size, const Color(0xFFE08A4A));
      case MatchResultVisual.endedOut:
        _paintDrift(canvas, size);
    }
  }

  void _paintVictoryBurst(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxR = size.shortestSide * 0.7;
    for (var i = 0; i < 10; i++) {
      final angle = (i / 10) * math.pi * 2 + t * math.pi * 2;
      final r = maxR * (0.5 + 0.5 * math.sin(t * math.pi * 2 + i));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(
        center + Offset(math.cos(angle) * r * 0.3, math.sin(angle) * r * 0.3),
        r * 0.22,
        paint,
      );
    }
  }

  void _paintCollapse(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    for (var i = 0; i < 5; i++) {
      final phase = (t + i * 0.18) % 1.0;
      final radius = size.shortestSide * (0.55 - phase * 0.45);
      final paint = Paint()
        ..color = const Color(0xFFFF00AA).withValues(alpha: 0.14 * (1 - phase))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius.clamp(8.0, size.shortestSide), paint);
    }
  }

  void _paintShimmer(Canvas canvas, Size size, Color color) {
    final y = size.height * (0.25 + 0.12 * math.sin(t * math.pi * 2));
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + t * 2, 0),
        end: Alignment(t * 2, 0),
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.12),
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0, 0.35, 0.5, 0.65, 1],
      ).createShader(Rect.fromLTWH(0, y - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _paintDrift(Canvas canvas, Size size) {
    final rng = math.Random(7);
    for (var i = 0; i < 24; i++) {
      final bx = (rng.nextDouble() * size.width + t * 40 * (i.isEven ? 1 : -1)) %
          size.width;
      final by = (rng.nextDouble() * size.height + t * 20) % size.height;
      canvas.drawCircle(
        Offset(bx, by),
        1.2 + rng.nextDouble(),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06 + 0.04 * math.sin(t * math.pi * 2 + i)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MatchResultBgPainter oldDelegate) =>
      oldDelegate.visual != visual || oldDelegate.t != t;
}

/// Primary / secondary action row used on result screens.
class MatchResultActions extends StatelessWidget {
  const MatchResultActions({
    super.key,
    this.primaryLabel,
    this.primaryIcon = Icons.home_rounded,
    this.onPrimary,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.primaryColor,
    this.primaryFilled = true,
  });

  final String? primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final Color? primaryColor;
  final bool primaryFilled;

  @override
  Widget build(BuildContext context) {
    final accent = primaryColor ?? const Color(0xFF00F0FF);
    return Column(
      children: [
        if (secondaryLabel != null && onSecondary != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSecondary,
              icon: Icon(secondaryIcon ?? Icons.visibility_outlined, size: 20),
              label: Text(secondaryLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (primaryLabel != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPrimary,
              icon: Icon(primaryIcon, size: 20),
              label: Text(primaryLabel!),
              style: FilledButton.styleFrom(
                backgroundColor:
                    primaryFilled ? accent : const Color(0xFF1A1A3A),
                foregroundColor: primaryFilled ? Colors.black : accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: primaryFilled
                        ? Colors.transparent
                        : accent.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
