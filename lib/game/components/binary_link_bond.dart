import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../utils/canvas_effects.dart';

import 'black_hole_partner.dart';

class BinaryLinkBond extends Component {
  BinaryLinkBond({
    required this.partnerA,
    required this.partnerB,
  });

  final BlackHolePartner partnerA;
  final BlackHolePartner partnerB;

  double _pulse = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 5;
  }

  Vector2 get midpoint =>
      (partnerA.position + partnerB.position) / 2;

  @override
  void render(Canvas canvas) {
    final a = partnerA.position;
    final b = partnerB.position;
    final pulse = 0.7 + math.sin(_pulse) * 0.3;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * pulse
      ..shader = ui.Gradient.linear(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        [
          const Color(0xFF00F0FF).withValues(alpha: 0.9),
          const Color(0xFFFF00AA).withValues(alpha: 0.9),
          const Color(0xFF00F0FF).withValues(alpha: 0.9),
        ],
        [0, 0.5, 1],
      )
      ..maskFilter = CanvasEffects.blur(8);

    canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), paint);

    final mid = midpoint;
    canvas.drawCircle(
      Offset(mid.x, mid.y),
      18 * pulse,
      Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.35)
        ..maskFilter = CanvasEffects.blur(12),
    );
  }
}
