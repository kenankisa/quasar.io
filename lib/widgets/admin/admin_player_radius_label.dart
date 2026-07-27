import 'package:flutter/material.dart';

import '../../services/lang_service.dart';
import 'admin_theme.dart';

/// Compact live radius badge for admin player rows.
class AdminPlayerRadiusLabel extends StatelessWidget {
  const AdminPlayerRadiusLabel({
    super.key,
    required this.radius,
    this.accent,
  });

  final double radius;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (radius <= 0) return const SizedBox.shrink();
    final color = accent ?? AdminTheme.textSecondary;
    return Text(
      LanguageService.instance
          .t('admin_player_radius')
          .replaceAll('{radius}', radius.toStringAsFixed(0)),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
