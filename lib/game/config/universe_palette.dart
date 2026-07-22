import 'package:flutter/material.dart';

import '../room_type.dart';

/// Shared per-universe colors for void backdrop, starfield wash, and scenery.
abstract final class UniversePalette {
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
      };

  /// Edge vignette strength — higher tiers feel deeper.
  static double vignetteAlpha(RoomType type) => switch (type) {
        RoomType.simple => 0.22,
        RoomType.normal => 0.28,
        RoomType.elite => 0.34,
        RoomType.unique => 0.4,
      };

  static Color washA(RoomType type) => switch (type) {
        RoomType.simple => const Color(0xFF14503C),
        RoomType.normal => const Color(0xFF1E3C7C),
        RoomType.elite => const Color(0xFF4A2CA0),
        RoomType.unique => const Color(0xFF7020C0),
      };

  static Color washB(RoomType type) => switch (type) {
        RoomType.simple => const Color(0xFF103A50),
        RoomType.normal => const Color(0xFF10486C),
        RoomType.elite => const Color(0xFF1A6AA8),
        RoomType.unique => const Color(0xFF0C7C9C),
      };
}
