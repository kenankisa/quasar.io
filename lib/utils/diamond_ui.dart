import 'package:flutter/material.dart';

/// Canonical UI color for diamond currency.
const kDiamondColor = Color(0xFF00F0FF);

/// Single diamond glyph used across the app.
const IconData kDiamondIcon = Icons.diamond_rounded;

/// Standard diamond icon — same shape everywhere.
class DiamondIcon extends StatelessWidget {
  const DiamondIcon({
    super.key,
    required this.size,
    this.color = kDiamondColor,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(kDiamondIcon, size: size, color: color);
  }
}

/// Amount label with the standard diamond icon (no unicode ♦).
class DiamondAmount extends StatelessWidget {
  const DiamondAmount({
    super.key,
    required this.amount,
    this.prefix,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w800,
    this.color = kDiamondColor,
    this.textColor,
    this.iconColor,
    this.iconSize,
    this.spacing,
  });

  final int amount;
  final String? prefix;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final Color? textColor;
  final Color? iconColor;
  final double? iconSize;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final glyph = iconSize ?? (fontSize + 1.5);
    final gap = spacing ?? fontSize * 0.28;
    final label = prefix != null ? '$prefix$amount' : '$amount';
    final labelColor = textColor ?? color;
    final diamondColor = iconColor ?? color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1,
          ),
        ),
        SizedBox(width: gap),
        DiamondIcon(size: glyph, color: diamondColor),
      ],
    );
  }
}
