import 'package:flutter/material.dart';

import '../utils/responsive_layout.dart';
import 'charge_ring_button.dart';

class BoostButton extends StatelessWidget {
  const BoostButton({
    super.key,
    required this.energy,
    required this.isReady,
    required this.isActive,
    required this.onActivate,
    this.size,
  });

  /// Boost energy 0–1.
  final double energy;
  final bool isReady;
  final bool isActive;
  final VoidCallback onActivate;

  /// When null, uses the responsive bottom-bar boost size.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout.of(context);
    return ChargeRingButton(
      icon: Icons.rocket_launch_rounded,
      accent: const Color(0xFF00F0FF),
      charge: energy,
      isReady: isReady,
      isActive: isActive,
      onActivate: onActivate,
      size: size ?? r.bottomBoostSize,
      iconSizeFactor: 0.42,
      ringWidthFactor: 0.049,
      ringWidthMin: 2.2,
      ringWidthMax: 4.0,
      borderWidth: 2,
      activeBlur: 20,
      readyBlur: 14,
      idleBlur: 8,
    );
  }
}
