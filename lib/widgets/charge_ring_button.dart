import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular action button with a charge/energy ring (boost + abilities).
class ChargeRingButton extends StatelessWidget {
  const ChargeRingButton({
    super.key,
    required this.icon,
    required this.accent,
    required this.charge,
    required this.isReady,
    required this.isActive,
    required this.onActivate,
    required this.size,
    this.iconSizeFactor = 0.41,
    this.ringWidthFactor = 0.052,
    this.ringWidthMin = 2.0,
    this.ringWidthMax = 3.5,
    this.borderWidth = 1.8,
    this.activeBlur = 16,
    this.readyBlur = 12,
    this.idleBlur = 6,
  });

  final IconData icon;
  final Color accent;
  final double charge;
  final bool isReady;
  final bool isActive;
  final VoidCallback onActivate;
  final double size;
  final double iconSizeFactor;
  final double ringWidthFactor;
  final double ringWidthMin;
  final double ringWidthMax;
  final double borderWidth;
  final double activeBlur;
  final double readyBlur;
  final double idleBlur;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * iconSizeFactor;
    final ringWidth = (size * ringWidthFactor).clamp(ringWidthMin, ringWidthMax);

    final glowAlpha = isActive ? 0.55 : (isReady ? 0.4 : 0.16);
    final fillAlpha = isActive ? 0.3 : (isReady ? 0.2 : 0.08);
    final borderAlpha = isActive ? 0.95 : (isReady ? 0.8 : 0.32);

    return GestureDetector(
      onTap: isReady ? onActivate : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _ChargeRingPainter(
                charge: charge.clamp(0.0, 1.0),
                ringWidth: ringWidth,
                accent: accent,
                isReady: isReady,
                isActive: isActive,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: size - ringWidth * 2.4,
              height: size - ringWidth * 2.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: fillAlpha),
                border: Border.all(
                  color: accent.withValues(alpha: borderAlpha),
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: glowAlpha),
                    blurRadius: isActive
                        ? activeBlur
                        : (isReady ? readyBlur : idleBlur),
                    spreadRadius: isActive ? 1 : 0,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: accent.withValues(alpha: isReady || isActive ? 1 : 0.4),
                size: iconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeRingPainter extends CustomPainter {
  _ChargeRingPainter({
    required this.charge,
    required this.ringWidth,
    required this.accent,
    required this.isReady,
    required this.isActive,
  });

  final double charge;
  final double ringWidth;
  final Color accent;
  final bool isReady;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - ringWidth / 2;
    final trackPaint = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (charge <= 0) return;

    final fillPaint = Paint()
      ..color = Color.lerp(
        accent.withValues(alpha: 0.45),
        accent,
        isActive ? 1.0 : (isReady ? 1.0 : 0.55),
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * charge,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChargeRingPainter oldDelegate) {
    return oldDelegate.charge != charge ||
        oldDelegate.isReady != isReady ||
        oldDelegate.isActive != isActive ||
        oldDelegate.accent != accent;
  }
}
