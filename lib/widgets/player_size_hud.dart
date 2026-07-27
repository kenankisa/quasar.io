import 'package:flutter/material.dart';

import '../utils/responsive_layout.dart';

/// Live local-player radius badge — top-right during a match.
class PlayerSizeHud extends StatelessWidget {
  const PlayerSizeHud({
    super.key,
    required this.radius,
  });

  final double radius;

  static const _cyan = Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    final value = radius.round();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF0A0A1A).withValues(alpha: 0.88),
        border: Border.all(color: _cyan.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: _cyan.withValues(alpha: 0.12),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.w(10),
          vertical: r.w(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: r.sp(8),
              color: _cyan.withValues(alpha: 0.85),
            ),
            SizedBox(width: r.w(5)),
            Text(
              '$value',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: r.sp(13),
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(
                    color: _cyan.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
