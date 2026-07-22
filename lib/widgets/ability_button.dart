import 'package:flutter/material.dart';

import '../utils/responsive_layout.dart';
import 'charge_ring_button.dart';

/// Circular cooldown ability button (teleport / shield / shockwave).
class AbilityButton extends StatelessWidget {
  const AbilityButton({
    super.key,
    required this.icon,
    required this.accent,
    required this.charge,
    required this.isReady,
    required this.isActive,
    required this.onActivate,
    this.size,
  });

  final IconData icon;
  final Color accent;
  final double charge;
  final bool isReady;
  final bool isActive;
  final VoidCallback onActivate;

  /// When null, uses the responsive bottom-bar ability size.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return ChargeRingButton(
      icon: icon,
      accent: accent,
      charge: charge,
      isReady: isReady,
      isActive: isActive,
      onActivate: onActivate,
      size: size ?? r.bottomAbilitySize,
    );
  }
}
