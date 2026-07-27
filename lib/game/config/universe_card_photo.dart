import 'package:flutter/material.dart';

import '../room_type.dart';
import 'universe_palette.dart';

/// NASA public-domain photography — dark, sparse, tier-scaled void mood.
abstract final class UniverseCardPhoto {
  static const _base = 'assets/lobby/universe';

  static UniverseCardPhotoConfig forRoom(RoomType type) => switch (type) {
        // Orion Nebula (M42) — yıldız doğum alanı, sıcak ve tanıdık derin uzay.
        RoomType.simple => const UniverseCardPhotoConfig(
            assetPath: '$_base/simple.jpg',
            alignment: Alignment(0.55, 0.0),
            bannerAlignment: Alignment(0.48, 0.0),
            tint: Color(0xFF0A2818),
            tintAlpha: 0.15,
            darkness: 0.58,
            desaturate: 0.46,
            credit: 'NASA/ESA/STScI',
          ),
        // Horsehead Nebula — karanlık siluet, soğuk derinlik.
        RoomType.normal => const UniverseCardPhotoConfig(
            assetPath: '$_base/normal.jpg',
            alignment: Alignment(0.92, 0.15),
            tint: Color(0xFF0A1428),
            tintAlpha: 0.07,
            darkness: 0.38,
            desaturate: 0.38,
            credit: 'NASA/ESA/STScI',
          ),
        // Cygnus Loop — sürekli mavi örtü bulutsusu, parçasız derin alan.
        RoomType.elite => const UniverseCardPhotoConfig(
            assetPath: '$_base/elite.jpg',
            alignment: Alignment(0.78, 0.0),
            tint: Color(0xFF080818),
            tintAlpha: 0.08,
            darkness: 0.41,
            desaturate: 0.4,
            credit: 'NASA/ESA/STScI',
          ),
        // Tycho süpernova kalıntısı — koyu zemin, amber/kırmızı filamanlar.
        RoomType.unique => const UniverseCardPhotoConfig(
            assetPath: '$_base/unique.jpg',
            alignment: Alignment(0.62, 0.0),
            bannerAlignment: Alignment(0.52, 0.0),
            tint: Color(0xFF140C06),
            tintAlpha: 0.11,
            darkness: 0.5,
            desaturate: 0.32,
            credit: 'NASA/JPL-Caltech/WISE',
          ),
        // Karanlık galaksi çekirdeği / aktif çekim — en derin tehdit.
        RoomType.hardcore => const UniverseCardPhotoConfig(
            assetPath: '$_base/hardcore.jpg',
            alignment: Alignment(0.85, 0.0),
            tint: Color(0xFF1A0604),
            tintAlpha: 0.14,
            darkness: 0.5,
            desaturate: 0.25,
            warmEdge: 0.18,
            credit: 'NASA/JPL-Caltech',
          ),
      };

  static List<Color> fallbackGradient(RoomType type) =>
      UniversePalette.backdropColors(type);

  /// Color matrix: [darken] 0 = unchanged, 0.5 = half brightness.
  static List<double> brightnessMatrix(double darken) {
    final scale = 1.0 - darken.clamp(0.0, 0.75);
    return [
      scale, 0, 0, 0, 0,
      0, scale, 0, 0, 0,
      0, 0, scale, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Color matrix: [desaturate] 0 = full colour, 1 = greyscale.
  static List<double> saturationMatrix(double desaturate) {
    final d = desaturate.clamp(0.0, 1.0);
    final inv = 1 - d;
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    return [
      lr * d + inv, lg * d, lb * d, 0, 0,
      lr * d, lg * d + inv, lb * d, 0, 0,
      lr * d, lg * d, lb * d + inv, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

class UniverseCardPhotoConfig {
  const UniverseCardPhotoConfig({
    required this.assetPath,
    required this.alignment,
    required this.tint,
    required this.tintAlpha,
    required this.darkness,
    required this.desaturate,
    required this.credit,
    this.bannerAlignment,
    this.warmEdge = 0,
    this.imageDarken = 0,
  });

  final String assetPath;
  final Alignment alignment;
  final Color tint;
  final double tintAlpha;
  final double darkness;
  final double desaturate;
  final String credit;

  /// Wide banner cards — keeps the subject in frame on short aspect ratios.
  final Alignment? bannerAlignment;

  /// Hardcore-only warm ember bleed on the right edge.
  final double warmEdge;

  /// Pre-overlay brightness crush — bright assets (e.g. lunar surface).
  final double imageDarken;
}
