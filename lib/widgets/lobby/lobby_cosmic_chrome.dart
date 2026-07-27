import 'package:flutter/material.dart';

import '../../services/settings_service.dart';

/// Lightweight cosmic shell for lobby chrome — static paint, no animation.
class LobbyCosmicPanel extends StatelessWidget {
  const LobbyCosmicPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 14,
    this.accent = const Color(0xFF00F0FF),
    this.secondary = const Color(0xFF7020C0),
    this.showStars = true,
    this.glowStrength = 0.12,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color accent;
  final Color secondary;
  final bool showStars;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final lowPerf = SettingsService.instance.lowPerformanceMode;
    final stars = showStars && !lowPerf;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: glowStrength),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: secondary.withValues(alpha: glowStrength * 0.45),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 0.5),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0C1438).withValues(alpha: 0.92),
                      const Color(0xFF060818),
                      const Color(0xFF120A28),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -24,
              top: -28,
              child: _ChromeNebulaOrb(
                color: accent,
                size: 90,
                alpha: 0.14,
              ),
            ),
            Positioned(
              left: -20,
              bottom: -24,
              child: _ChromeNebulaOrb(
                color: secondary,
                size: 72,
                alpha: 0.1,
              ),
            ),
            if (stars)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: LobbyChromeStarDustPainter(
                      accent: accent,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      accent.withValues(alpha: 0.45),
                      secondary.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChromeNebulaOrb extends StatelessWidget {
  const _ChromeNebulaOrb({
    required this.color,
    required this.size,
    required this.alpha,
  });

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class LobbyChromeStarDustPainter extends CustomPainter {
  const LobbyChromeStarDustPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final dust = Paint()..style = PaintingStyle.fill;
    const points = [
      Offset(0.12, 0.28),
      Offset(0.34, 0.18),
      Offset(0.58, 0.32),
      Offset(0.78, 0.22),
      Offset(0.9, 0.48),
      Offset(0.22, 0.72),
      Offset(0.48, 0.82),
      Offset(0.68, 0.68),
    ];

    for (var i = 0; i < points.length; i++) {
      final p = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      dust.color = (i.isEven ? Colors.white : accent).withValues(
        alpha: 0.08 + (i % 3) * 0.04,
      );
      canvas.drawCircle(p, i.isEven ? 0.75 : 0.45, dust);
    }
  }

  @override
  bool shouldRepaint(covariant LobbyChromeStarDustPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

/// Tab indicator with cosmic glow — used by lobby TabBar.
class LobbyCosmicTabIndicator extends Decoration {
  const LobbyCosmicTabIndicator({
    this.accent = const Color(0xFF00F0FF),
    this.secondary = const Color(0xFF8868FF),
    this.borderRadius = 10,
  });

  final Color accent;
  final Color secondary;
  final double borderRadius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _LobbyCosmicTabIndicatorPainter(
      accent: accent,
      secondary: secondary,
      borderRadius: borderRadius,
    );
  }
}

class _LobbyCosmicTabIndicatorPainter extends BoxPainter {
  _LobbyCosmicTabIndicatorPainter({
    required this.accent,
    required this.secondary,
    required this.borderRadius,
  });

  final Color accent;
  final Color secondary;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(3),
      Radius.circular(borderRadius),
    );

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.22),
          secondary.withValues(alpha: 0.14),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: 0.42);
    canvas.drawRRect(rrect, border);

    final glow = Paint()
      ..color = accent.withValues(alpha: 0.08);
    canvas.drawRRect(rrect.inflate(3), glow);
  }
}
