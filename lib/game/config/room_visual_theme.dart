import 'package:flutter/material.dart';

import '../room_type.dart';

/// Per-room color accents for cosmic objects — palette swaps only, no extra draw calls.
class RoomVisualTheme {
  const RoomVisualTheme({
    required this.accent,
    required this.secondaryAccent,
    required this.objectTint,
    required this.objectTintStrength,
    this.objectGlowAlpha = 0,
    this.rimAccentAlpha = 0,
    this.lobbyGradientTitle = false,
    this.titleGradientEnd,
    this.wormholeRingCount = 3,
    this.wormholeRichness = 1,
  });

  final Color accent;
  final Color secondaryAccent;
  final Color objectTint;
  final double objectTintStrength;

  /// Optional soft halo behind collectibles (desktop only).
  final double objectGlowAlpha;

  /// Thin accent stroke on rocks / planets (all platforms).
  final double rimAccentAlpha;

  final bool lobbyGradientTitle;
  final Color? titleGradientEnd;
  final int wormholeRingCount;
  final int wormholeRichness;

  static const simple = RoomVisualTheme(
    accent: Color(0xFF48C888),
    secondaryAccent: Color(0xFF208868),
    objectTint: Color(0xFF88AA90),
    objectTintStrength: 0.1,
    objectGlowAlpha: 0.05,
    rimAccentAlpha: 0.1,
    wormholeRingCount: 2,
    wormholeRichness: 0,
  );

  static const normal = RoomVisualTheme(
    accent: Color(0xFF00D4FF),
    secondaryAccent: Color(0xFF4080C0),
    objectTint: Color(0xFF8090B8),
    objectTintStrength: 0.16,
    objectGlowAlpha: 0.09,
    rimAccentAlpha: 0.16,
    lobbyGradientTitle: true,
    titleGradientEnd: Color(0xFF4080C0),
    wormholeRingCount: 3,
    wormholeRichness: 1,
  );

  static const elite = RoomVisualTheme(
    accent: Color(0xFF8868FF),
    secondaryAccent: Color(0xFF20A0E8),
    objectTint: Color(0xFF9890D0),
    objectTintStrength: 0.26,
    objectGlowAlpha: 0.12,
    rimAccentAlpha: 0.18,
    lobbyGradientTitle: true,
    titleGradientEnd: Color(0xFF40C8FF),
    wormholeRingCount: 4,
    wormholeRichness: 2,
  );

  static const unique = RoomVisualTheme(
    accent: Color(0xFFFFB020),
    secondaryAccent: Color(0xFFFF6B2C),
    objectTint: Color(0xFFD4A060),
    objectTintStrength: 0.34,
    objectGlowAlpha: 0.16,
    rimAccentAlpha: 0.24,
    lobbyGradientTitle: true,
    titleGradientEnd: Color(0xFFFFE080),
    wormholeRingCount: 5,
    wormholeRichness: 3,
  );

  static const hardcore = RoomVisualTheme(
    accent: Color(0xFFFF6B35),
    secondaryAccent: Color(0xFFFF3D00),
    objectTint: Color(0xFFE87848),
    objectTintStrength: 0.38,
    objectGlowAlpha: 0.18,
    rimAccentAlpha: 0.28,
    lobbyGradientTitle: true,
    titleGradientEnd: Color(0xFFFFD54F),
    wormholeRingCount: 6,
    wormholeRichness: 4,
  );

  static RoomVisualTheme forRoom(RoomType type) => switch (type) {
        RoomType.simple => simple,
        RoomType.normal => normal,
        RoomType.elite => elite,
        RoomType.unique => unique,
        RoomType.hardcore => hardcore,
      };

  Color tint(Color base) =>
      Color.lerp(base, objectTint, objectTintStrength) ?? base;
}
