import 'package:flutter/material.dart';

/// Visual black-hole skins (no purchase / currency).
enum CosmeticCategory { skin }

class CosmeticItem {
  const CosmeticItem({
    required this.id,
    required this.category,
    required this.nameKey,
    required this.previewColor,
    this.gradientColors,
  });

  final String id;
  final CosmeticCategory category;
  final String nameKey;
  final Color previewColor;
  final List<Color>? gradientColors;
}

class CosmeticCatalog {
  CosmeticCatalog._();

  static const defaultSkinId = 'default';

  static const starterSkins = [
    CosmeticItem(
      id: defaultSkinId,
      category: CosmeticCategory.skin,
      nameKey: 'skin_default',
      previewColor: Color(0xFFFFAA33),
    ),
    CosmeticItem(
      id: 'frost',
      category: CosmeticCategory.skin,
      nameKey: 'skin_frost',
      previewColor: Color(0xFF88CCFF),
    ),
    CosmeticItem(
      id: 'ember',
      category: CosmeticCategory.skin,
      nameKey: 'skin_ember',
      previewColor: Color(0xFFFF5522),
      gradientColors: [
        Color(0xFFFFF0E8),
        Color(0xFFFF7030),
        Color(0xFFE83018),
        Color(0xFF601008),
      ],
    ),
  ];

  /// Bot / default palette skins (not sold).
  static const legendarySkins = [
    CosmeticItem(
      id: 'pulsar',
      category: CosmeticCategory.skin,
      nameKey: 'skin_pulsar',
      previewColor: Color(0xFF00B4FF),
    ),
    CosmeticItem(
      id: 'nebula',
      category: CosmeticCategory.skin,
      nameKey: 'skin_nebula',
      previewColor: Color(0xFFAA44FF),
    ),
    CosmeticItem(
      id: 'plasma',
      category: CosmeticCategory.skin,
      nameKey: 'skin_plasma',
      previewColor: Color(0xFFFF00AA),
      gradientColors: [
        Color(0xFFFF0000),
        Color(0xFF00FF00),
        Color(0xFF0000FF),
      ],
    ),
    CosmeticItem(
      id: 'void',
      category: CosmeticCategory.skin,
      nameKey: 'skin_void',
      previewColor: Color(0xFF5533AA),
    ),
    CosmeticItem(
      id: 'quasar',
      category: CosmeticCategory.skin,
      nameKey: 'skin_quasar',
      previewColor: Color(0xFF00FF88),
    ),
    CosmeticItem(
      id: 'eclipse',
      category: CosmeticCategory.skin,
      nameKey: 'skin_eclipse',
      previewColor: Color(0xFFFFD700),
    ),
    CosmeticItem(
      id: 'supernova',
      category: CosmeticCategory.skin,
      nameKey: 'skin_supernova',
      previewColor: Color(0xFFFF2200),
    ),
    CosmeticItem(
      id: 'aurora',
      category: CosmeticCategory.skin,
      nameKey: 'skin_aurora',
      previewColor: Color(0xFF44FFCC),
      gradientColors: [
        Color(0xFF00FFAA),
        Color(0xFF44AAFF),
        Color(0xFFAA44FF),
      ],
    ),
    CosmeticItem(
      id: 'binary',
      category: CosmeticCategory.skin,
      nameKey: 'skin_binary',
      previewColor: Color(0xFFFF8800),
      gradientColors: [
        Color(0xFFFF6600),
        Color(0xFF0088FF),
      ],
    ),
    CosmeticItem(
      id: 'singularity',
      category: CosmeticCategory.skin,
      nameKey: 'skin_singularity',
      previewColor: Color(0xFFB0C0E0),
      gradientColors: [
        Color(0xFFF0F4FF),
        Color(0xFF8090B8),
        Color(0xFF304868),
        Color(0xFF101820),
      ],
    ),
    CosmeticItem(
      id: 'celestial',
      category: CosmeticCategory.skin,
      nameKey: 'skin_celestial',
      previewColor: Color(0xFFE8C878),
      gradientColors: [
        Color(0xFFFFFAF0),
        Color(0xFFF0D890),
        Color(0xFFD0A848),
        Color(0xFF907020),
      ],
    ),
  ];

  static List<CosmeticItem> get allSkins => [...starterSkins, ...legendarySkins];

  static List<String> get skinIds =>
      allSkins.map((item) => item.id).toList(growable: false);

  static List<String> get botSkinIds =>
      legendarySkins.map((item) => item.id).toList(growable: false);

  static bool isStarterSkin(String id) =>
      starterSkins.any((skin) => skin.id == id);

  static List<CosmeticItem> get all => allSkins;

  static CosmeticItem? findById(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
