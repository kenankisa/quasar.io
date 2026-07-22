part of '../starfield_background.dart';

// ─────────────────────────────────────────────────────────────────────────
//  Per-universe budget & mood — richness scales with difficulty tier.
// ─────────────────────────────────────────────────────────────────────────

class _SpaceSpec {
  const _SpaceSpec({
    required this.washA,
    required this.washB,
    required this.nebulaPalettes,
    required this.nebulaCount,
    required this.nebulaAlpha,
    required this.galaxyCount,
    required this.bandStrength,
    required this.bandStarCount,
    required this.bandWarmth,
    required this.cometMax,
    required this.cometInterval,
    required this.meteorInterval,
    required this.pulsarCount,
    required this.supernovaInterval,
    required this.galacticCoreGlow,
  });

  final Color washA;
  final Color washB;
  final List<(Color, Color)> nebulaPalettes;
  final int nebulaCount;
  final double nebulaAlpha;
  final int galaxyCount;

  /// 0 disables the Milky Way band entirely.
  final double bandStrength;
  final int bandStarCount;

  /// Band hue: 0 = pale blue halo, 1 = warm golden galactic-bulge light.
  final double bandWarmth;

  final int cometMax;
  final (double, double) cometInterval;
  final (double, double) meteorInterval;
  final int pulsarCount;

  /// (min, max) seconds between supernovae; (0, 0) disables them.
  final (double, double) supernovaInterval;
  final bool galacticCoreGlow;

  static _SpaceSpec forRoom(RoomType type) => switch (type) {
        // Training void: calm, sparse, slightly cold — an empty frontier.
        RoomType.simple => _SpaceSpec(
            washA: UniversePalette.washA(RoomType.simple),
            washB: UniversePalette.washB(RoomType.simple),
            nebulaPalettes: const [
              (Color(0xFF0E5444), Color(0xFF1A6C9A)),
              (Color(0xFF0B4638), Color(0xFF25628C)),
              (Color(0xFF12604E), Color(0xFF187FA8)),
            ],
            nebulaCount: 5,
            nebulaAlpha: 0.72,
            galaxyCount: 2,
            bandStrength: 0.0,
            bandStarCount: 0,
            bandWarmth: 0.0,
            cometMax: 0,
            cometInterval: (0, 0),
            meteorInterval: (16.0, 26.0),
            pulsarCount: 0,
            supernovaInterval: (0, 0),
            galacticCoreGlow: false,
          ),
        // Deep interstellar blue: first taste of the Milky Way, lone comets.
        RoomType.normal => _SpaceSpec(
            washA: UniversePalette.washA(RoomType.normal),
            washB: UniversePalette.washB(RoomType.normal),
            nebulaPalettes: const [
              (Color(0xFF17336E), Color(0xFF3E7FD0)),
              (Color(0xFF1B2A64), Color(0xFF6E9CE0)),
              (Color(0xFF122B58), Color(0xFF3894C8)),
              (Color(0xFF5A4416), Color(0xFFD0A050)),
              (Color(0xFF20255E), Color(0xFF5078D8)),
            ],
            nebulaCount: 7,
            nebulaAlpha: 0.88,
            galaxyCount: 3,
            bandStrength: 0.55,
            bandStarCount: 420,
            bandWarmth: 0.25,
            cometMax: 1,
            cometInterval: (26.0, 44.0),
            meteorInterval: (9.0, 16.0),
            pulsarCount: 0,
            supernovaInterval: (0, 0),
            galacticCoreGlow: false,
          ),
        // Hubble deep field: violet-cyan emission clouds, pulsars, dying stars.
        RoomType.elite => _SpaceSpec(
            washA: UniversePalette.washA(RoomType.elite),
            washB: UniversePalette.washB(RoomType.elite),
            nebulaPalettes: const [
              (Color(0xFF3A1880), Color(0xFF22A2E8)),
              (Color(0xFF2C1494), Color(0xFF00C8E8)),
              (Color(0xFF4E1660), Color(0xFF8868FF)),
              (Color(0xFF321A9C), Color(0xFF48A8E8)),
              (Color(0xFF4418B4), Color(0xFF00E0C4)),
              (Color(0xFF28189C), Color(0xFF74B4FF)),
              (Color(0xFF441C98), Color(0xFFA48CFF)),
            ],
            nebulaCount: 9,
            nebulaAlpha: 1.12,
            galaxyCount: 4,
            bandStrength: 0.85,
            bandStarCount: 560,
            bandWarmth: 0.45,
            cometMax: 2,
            cometInterval: (16.0, 30.0),
            meteorInterval: (5.5, 10.0),
            pulsarCount: 2,
            supernovaInterval: (45.0, 80.0),
            galacticCoreGlow: false,
          ),
        // Quasar heartland: magenta-cyan-gold spectacle, galactic core glow,
        // frequent comets, pulsars, supernova shells — the full deep-space show.
        RoomType.unique => _SpaceSpec(
            washA: UniversePalette.washA(RoomType.unique),
            washB: UniversePalette.washB(RoomType.unique),
            nebulaPalettes: const [
              (Color(0xFF5A18B0), Color(0xFF40F0FF)),
              (Color(0xFF6E1258), Color(0xFFFF6EC8)),
              (Color(0xFF321CB0), Color(0xFF50FFB8)),
              (Color(0xFF6A3410), Color(0xFFFFB060)),
              (Color(0xFF4C18B8), Color(0xFF7CC8FF)),
              (Color(0xFF64129C), Color(0xFFFF48E0)),
              (Color(0xFF2C1AA8), Color(0xFF6AE8FF)),
              (Color(0xFF5C18A4), Color(0xFFFF8CD8)),
              (Color(0xFF3E20C0), Color(0xFFA8F0FF)),
            ],
            nebulaCount: 11,
            nebulaAlpha: 1.34,
            galaxyCount: 6,
            bandStrength: 1.0,
            bandStarCount: 680,
            bandWarmth: 0.7,
            cometMax: 3,
            cometInterval: (11.0, 20.0),
            meteorInterval: (3.5, 7.0),
            pulsarCount: 3,
            supernovaInterval: (28.0, 52.0),
            galacticCoreGlow: true,
          ),
      };
}
