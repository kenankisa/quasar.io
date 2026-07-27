import 'package:flutter/material.dart';

/// Shared visual language for the admin console.
abstract final class AdminTheme {
  static const bg = Color(0xFF07070F);
  static const surface = Color(0xFF10101C);
  static const surfaceElevated = Color(0xFF161624);
  static const border = Color(0x22FFFFFF);
  static const accent = Color(0xFF00D4E8);
  static const accentSoft = Color(0xFF22E0A8);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF4466);
  static const textPrimary = Color(0xFFF2F4F8);
  static const textSecondary = Color(0x99F2F4F8);
  static const textMuted = Color(0x55F2F4F8);

  static const sideNavWidth = 248.0;
  static const contentMaxWidth = 1100.0;
  static const radius = 14.0;
  static const radiusSm = 10.0;

  static BoxDecoration panel({
    Color? borderColor,
    Color? fill,
    double radius = AdminTheme.radius,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border),
      color: fill ?? surface.withValues(alpha: 0.92),
    );
  }

  static BoxDecoration softPanel({Color? accentColor}) {
    final a = accentColor ?? accent;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: a.withValues(alpha: 0.28)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          a.withValues(alpha: 0.1),
          surface.withValues(alpha: 0.95),
        ],
      ),
    );
  }
}

/// Contained content block used across admin pages.
class AdminPanelCard extends StatelessWidget {
  const AdminPanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
    this.title,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AdminTheme.softPanel(accentColor: accentColor),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: accentColor ?? AdminTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class AdminMetricTile extends StatelessWidget {
  const AdminMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: AdminTheme.panel(
        borderColor: accent.withValues(alpha: 0.28),
        fill: AdminTheme.surface.withValues(alpha: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: accent.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AdminTheme.panel(
        borderColor: AdminTheme.danger.withValues(alpha: 0.45),
        fill: AdminTheme.danger.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AdminTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFCCD5),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
