import 'package:flutter/material.dart';

import '../room_type.dart';

/// Shared per-universe colors for void backdrop, starfield wash, and scenery.
abstract final class UniversePalette {
  static int tierIndex(RoomType type) => switch (type) {
        RoomType.simple => 0,
        RoomType.normal => 1,
        RoomType.elite => 2,
        RoomType.unique => 3,
        RoomType.hardcore => 4,
      };

  static double cardGlowStrength(RoomType type) => switch (type) {
        RoomType.simple => 0.08,
        RoomType.normal => 0.12,
        RoomType.elite => 0.18,
        RoomType.unique => 0.24,
        RoomType.hardcore => 0.3,
      };

  static double cardBorderAlpha(
    RoomType type, {
    bool locked = false,
  }) {
    if (locked) return 0.22;
    return switch (type) {
      RoomType.simple => 0.28,
      RoomType.normal => 0.34,
      RoomType.elite => 0.42,
      RoomType.unique => 0.5,
      RoomType.hardcore => 0.58,
    };
  }

  static List<Color> backdropColors(RoomType type) => switch (type) {
        RoomType.simple => const [
            Color(0xFF08201B),
            Color(0xFF04120E),
            Color(0xFF010504),
          ],
        RoomType.normal => const [
            Color(0xFF0A1430),
            Color(0xFF050A1A),
            Color(0xFF010207),
          ],
        RoomType.elite => const [
            Color(0xFF150F38),
            Color(0xFF0A0824),
            Color(0xFF02020A),
          ],
        RoomType.unique => const [
            Color(0xFF1C1040),
            Color(0xFF0D0824),
            Color(0xFF03020C),
          ],
        RoomType.hardcore => const [
            Color(0xFF3A0A08),
            Color(0xFF1A0504),
            Color(0xFF080202),
          ],
      };

  /// Edge vignette strength — higher tiers feel deeper.
  static double vignetteAlpha(RoomType type) => switch (type) {
        RoomType.simple => 0.22,
        RoomType.normal => 0.28,
        RoomType.elite => 0.34,
        RoomType.unique => 0.4,
        RoomType.hardcore => 0.46,
      };

  static Color washA(RoomType type) => switch (type) {
        RoomType.simple => const Color(0xFF14503C),
        RoomType.normal => const Color(0xFF1E3C7C),
        RoomType.elite => const Color(0xFF4A2CA0),
        RoomType.unique => const Color(0xFF7020C0),
        RoomType.hardcore => const Color(0xFFFF4A18),
      };

  static Color washB(RoomType type) => switch (type) {
        RoomType.simple => const Color(0xFF103A50),
        RoomType.normal => const Color(0xFF10486C),
        RoomType.elite => const Color(0xFF1A6AA8),
        RoomType.unique => const Color(0xFF0C7C9C),
        RoomType.hardcore => const Color(0xFFFF2A10),
      };
}
