import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Treasure-chest glyph for the daily lobby reward.
class CosmicChestIcon extends StatelessWidget {
  const CosmicChestIcon({
    super.key,
    required this.size,
    this.lit = true,
    this.opacity = 1,
  });

  final double size;
  final bool lit;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: CustomPaint(
        size: Size.square(size),
        painter: _CosmicChestPainter(lit: lit),
      ),
    );
  }
}

class _CosmicChestPainter extends CustomPainter {
  _CosmicChestPainter({required this.lit});

  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final woodFront = lit ? const Color(0xFFB86A1E) : const Color(0xFF4A4A56);
    final woodSide = lit ? const Color(0xFF8F4F12) : const Color(0xFF3A3A44);
    final woodDark = lit ? const Color(0xFF6B3A0C) : const Color(0xFF2E2E38);
    final lidTop = lit ? const Color(0xFFD48A2C) : const Color(0xFF5C5C68);
    final metal = lit ? const Color(0xFFFFD966) : const Color(0xFF6E6E7C);
    final metalDark = lit ? const Color(0xFFB8860B) : const Color(0xFF454552);
    final innerGlow = lit ? const Color(0xFFFFE9A8) : const Color(0xFF5A5A66);

    // Ground shadow
    final shadow = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.94),
          width: w * 0.62,
          height: h * 0.10,
        ),
      );
    canvas.drawPath(
      shadow,
      Paint()
        ..color = Colors.black.withValues(alpha: lit ? 0.28 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    if (lit) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD24A).withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.08, w, h * 0.72));
      canvas.drawCircle(Offset(w * 0.50, h * 0.46), w * 0.34, glow);
    }

    // Back panel (depth)
    final back = Path()
      ..moveTo(w * 0.18, h * 0.30)
      ..lineTo(w * 0.82, h * 0.30)
      ..lineTo(w * 0.86, h * 0.48)
      ..lineTo(w * 0.14, h * 0.48)
      ..close();
    canvas.drawPath(back, Paint()..color = woodDark);

    // Left side
    final leftSide = Path()
      ..moveTo(w * 0.14, h * 0.48)
      ..lineTo(w * 0.18, h * 0.30)
      ..lineTo(w * 0.18, h * 0.86)
      ..lineTo(w * 0.14, h * 0.90)
      ..close();
    canvas.drawPath(leftSide, Paint()..color = woodSide);
    _drawPlanks(
      canvas,
      leftSide,
      woodSide,
      woodDark,
      vertical: true,
      planks: 3,
    );

    // Right side
    final rightSide = Path()
      ..moveTo(w * 0.86, h * 0.48)
      ..lineTo(w * 0.82, h * 0.30)
      ..lineTo(w * 0.82, h * 0.86)
      ..lineTo(w * 0.86, h * 0.90)
      ..close();
    canvas.drawPath(rightSide, Paint()..color = woodSide.withValues(alpha: 0.92));
    _drawPlanks(
      canvas,
      rightSide,
      woodSide,
      woodDark,
      vertical: true,
      planks: 3,
    );

    // Front body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.48, w * 0.72, h * 0.40),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(body, Paint()..color = woodFront);
    _drawPlanks(
      canvas,
      Path()..addRRect(body),
      woodFront,
      woodDark,
      vertical: true,
      planks: 4,
    );

    // Curved lid
    final lidPath = Path()
      ..moveTo(w * 0.12, h * 0.50)
      ..lineTo(w * 0.16, h * 0.28)
      ..quadraticBezierTo(w * 0.50, h * 0.10, w * 0.84, h * 0.28)
      ..lineTo(w * 0.88, h * 0.50)
      ..close();
    canvas.drawPath(lidPath, Paint()..color = lidTop);
    _drawPlanks(
      canvas,
      lidPath,
      lidTop,
      woodDark,
      vertical: false,
      planks: 3,
    );

    // Lid highlight
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.20, h * 0.30)
        ..quadraticBezierTo(w * 0.50, h * 0.16, w * 0.78, h * 0.30),
      Paint()
        ..color = Colors.white.withValues(alpha: lit ? 0.22 : 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..strokeCap = StrokeCap.round,
    );

    // Inner light from opening crack
    if (lit) {
      canvas.drawLine(
        Offset(w * 0.18, h * 0.50),
        Offset(w * 0.82, h * 0.50),
        Paint()
          ..color = innerGlow.withValues(alpha: 0.85)
          ..strokeWidth = w * 0.035
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawLine(
        Offset(w * 0.18, h * 0.50),
        Offset(w * 0.82, h * 0.50),
        Paint()
          ..color = woodDark
          ..strokeWidth = w * 0.03,
      );
    }

    // Metal bands
    for (final y in [0.56, 0.72]) {
      final band = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.13, h * y, w * 0.74, h * 0.06),
        Radius.circular(w * 0.015),
      );
      canvas.drawRRect(band, Paint()..color = metal);
      canvas.drawRRect(
        band,
        Paint()
          ..color = metalDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.018,
      );
    }

    // Corner brackets
    _drawBracket(canvas, Offset(w * 0.14, h * 0.50), w, h, metal, metalDark);
    _drawBracket(canvas, Offset(w * 0.86, h * 0.50), w, h, metal, metalDark, flip: true);

    // Lock plate
    final lockPlate = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.64),
        width: w * 0.20,
        height: h * 0.14,
      ),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(lockPlate, Paint()..color = metalDark);
    canvas.drawRRect(
      lockPlate,
      Paint()
        ..color = metal
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    // Shackle
    final shackle = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.56),
        width: w * 0.12,
        height: h * 0.08,
      ),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(
      shackle,
      Paint()
        ..color = metal
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03,
    );

    // Keyhole
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.64),
      w * 0.022,
      Paint()..color = lit ? const Color(0xFFFFF6D0) : const Color(0xFF2A2A34),
    );
    final keySlot = Path()
      ..moveTo(w * 0.50, h * 0.66)
      ..lineTo(w * 0.47, h * 0.70)
      ..lineTo(w * 0.53, h * 0.70)
      ..close();
    canvas.drawPath(keySlot, Paint()..color = lit ? const Color(0xFF3A2808) : const Color(0xFF1E1E26));

    // Feet
    for (final x in [0.22, 0.78]) {
      final foot = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * x, h * 0.90),
          width: w * 0.10,
          height: h * 0.05,
        ),
        Radius.circular(w * 0.02),
      );
      canvas.drawRRect(foot, Paint()..color = metalDark);
    }

    // Sparkles when ready
    if (lit) {
      for (final point in [
        Offset(w * 0.24, h * 0.22),
        Offset(w * 0.72, h * 0.24),
        Offset(w * 0.58, h * 0.14),
      ]) {
        _drawSparkle(canvas, point, w * 0.035, const Color(0xFFFFF2B0));
      }
    }
  }

  void _drawPlanks(
    Canvas canvas,
    Path clip,
    Color base,
    Color line, {
    required bool vertical,
    required int planks,
  }) {
    canvas.save();
    canvas.clipPath(clip);
    final paint = Paint()
      ..color = line.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    final bounds = clip.getBounds();
    for (var i = 1; i < planks; i++) {
      final t = i / planks;
      if (vertical) {
        final x = bounds.left + bounds.width * t;
        canvas.drawLine(
          Offset(x, bounds.top),
          Offset(x, bounds.bottom),
          paint,
        );
      } else {
        final y = bounds.top + bounds.height * t;
        canvas.drawLine(
          Offset(bounds.left, y),
          Offset(bounds.right, y),
          paint,
        );
      }
    }
    canvas.restore();
  }

  void _drawBracket(
    Canvas canvas,
    Offset corner,
    double w,
    double h,
    Color metal,
    Color metalDark, {
    bool flip = false,
  }) {
    final dir = flip ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(corner.dx, corner.dy)
      ..lineTo(corner.dx + dir * w * 0.08, corner.dy)
      ..lineTo(corner.dx + dir * w * 0.08, corner.dy + h * 0.08)
      ..lineTo(corner.dx, corner.dy + h * 0.08)
      ..close();
    canvas.drawPath(path, Paint()..color = metal);
    canvas.drawPath(
      path,
      Paint()
        ..color = metalDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015,
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        paint..strokeWidth = 1.2,
      );
    }
    canvas.drawCircle(center, radius * 0.28, paint);
  }

  @override
  bool shouldRepaint(covariant _CosmicChestPainter oldDelegate) =>
      oldDelegate.lit != lit;
}
