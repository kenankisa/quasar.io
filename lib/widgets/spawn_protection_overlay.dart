import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/lang_service.dart';
import '../utils/responsive_layout.dart';

/// Upper-screen spawn protection HUD with shield ring and countdown.
class SpawnProtectionOverlay extends StatefulWidget {
  const SpawnProtectionOverlay({
    super.key,
    required this.countdown,
    required this.progress,
  });

  final int countdown;
  final double progress;

  static const _cyan = Color(0xFF00F0FF);
  static const _panel = Color(0xFF0A0A1A);
  static const _surface = Color(0xFF12122A);

  @override
  State<SpawnProtectionOverlay> createState() => _SpawnProtectionOverlayState();
}

class _SpawnProtectionOverlayState extends State<SpawnProtectionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.countdown <= 0) {
      return const SizedBox.shrink();
    }

    final r = ResponsiveLayout.of(context);
    final label = LanguageService.instance.t('spawn_protection_label');
    final ringSize = r.w(88);
    final ringWidth = r.w(3.5);

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glow = 0.28 + _pulse.value * 0.22;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.w(18)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    SpawnProtectionOverlay._panel.withValues(alpha: 0.94),
                    SpawnProtectionOverlay._surface.withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(
                  color: SpawnProtectionOverlay._cyan
                      .withValues(alpha: 0.45 + glow * 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SpawnProtectionOverlay._cyan.withValues(alpha: glow),
                    blurRadius: r.w(22),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: r.w(12),
                    offset: Offset(0, r.w(4)),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: r.w(20),
                  vertical: r.w(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(ringSize, ringSize),
                            painter: _SpawnShieldRingPainter(
                              progress: widget.progress.clamp(0.0, 1.0),
                              ringWidth: ringWidth,
                              pulse: _pulse.value,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                color: SpawnProtectionOverlay._cyan.withValues(
                                  alpha: 0.85 + _pulse.value * 0.15,
                                ),
                                size: r.sp(18),
                              ),
                              SizedBox(height: r.sp(2)),
                              Text(
                                '${widget.countdown}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.sp(34),
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  shadows: [
                                    Shadow(
                                      color: SpawnProtectionOverlay._cyan
                                          .withValues(alpha: 0.65),
                                      blurRadius: r.sp(12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.sp(10)),
                    Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            SpawnProtectionOverlay._cyan.withValues(alpha: 0.92),
                        fontSize: r.sp(11),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpawnShieldRingPainter extends CustomPainter {
  _SpawnShieldRingPainter({
    required this.progress,
    required this.ringWidth,
    required this.pulse,
  });

  final double progress;
  final double ringWidth;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - ringWidth;
    const cyan = SpawnProtectionOverlay._cyan;

    final trackPaint = Paint()
      ..color = cyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * progress;
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          cyan.withValues(alpha: 0.35),
          cyan,
          const Color(0xFF88FFFF),
        ],
        stops: const [0.0, 0.55, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );

    final glowPaint = Paint()
      ..color = cyan.withValues(alpha: 0.18 + pulse * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpawnShieldRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}
