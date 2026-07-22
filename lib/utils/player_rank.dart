import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_rank_config_service.dart';
import '../services/lang_service.dart';

/// Win-point based player rank (universe 1st-place score).
///
/// Thresholds / room multipliers are admin-editable via [AppRankConfigService].
/// Visual identity (stars, colors) stays here.
@immutable
class PlayerRankTier {
  const PlayerRankTier({
    required this.id,
    required this.defaultMinPoints,
    required this.starCount,
    required this.nameKey,
    required this.fillColor,
    required this.borderColor,
    required this.letterColor,
    required this.glowColor,
    this.starFillColor,
  });

  final String id;

  /// Compile-time fallback; live value from [AppRankConfigService].
  final int defaultMinPoints;

  /// Visual rank strength shown as filled stars (1–5).
  final int starCount;
  final String nameKey;
  final Color fillColor;
  final Color borderColor;
  final Color letterColor;
  final Color glowColor;

  /// Optional override for star fill (e.g. Singularity gold on magenta glow).
  final Color? starFillColor;

  Color get effectiveStarFill => starFillColor ?? letterColor;

  String localizedName([LanguageService? lang]) =>
      (lang ?? LanguageService.instance).t(nameKey);
}

/// Highest tier first — [playerRankForPoints] walks this list in order.
///
/// Color ladder (hue-separated, competitive UI):
/// Nebula indigo → Stellar cyan → Nova amber → Quasar gold → Singularity violet.
const playerRankTiers = <PlayerRankTier>[
  PlayerRankTier(
    id: 'singularity',
    defaultMinPoints: 200,
    starCount: 5,
    nameKey: 'rank_tier_singularity',
    fillColor: Color(0xFF12081C),
    borderColor: Color(0xFFC084FC),
    letterColor: Color(0xFFE9D5FF),
    glowColor: Color(0xFF7C3AED),
    starFillColor: Color(0xFFD8B4FE),
  ),
  PlayerRankTier(
    id: 'quasar',
    defaultMinPoints: 75,
    starCount: 4,
    nameKey: 'rank_tier_quasar',
    fillColor: Color(0xFF181408),
    borderColor: Color(0xFFE0B83A),
    letterColor: Color(0xFFF6E7A8),
    glowColor: Color(0xFFC9A227),
    starFillColor: Color(0xFFF0D45A),
  ),
  PlayerRankTier(
    id: 'nova',
    defaultMinPoints: 25,
    starCount: 3,
    nameKey: 'rank_tier_nova',
    fillColor: Color(0xFF1A1006),
    borderColor: Color(0xFFFF9A3C),
    letterColor: Color(0xFFFFC078),
    glowColor: Color(0xFFE67A20),
    starFillColor: Color(0xFFFFB35C),
  ),
  PlayerRankTier(
    id: 'stellar',
    defaultMinPoints: 8,
    starCount: 2,
    nameKey: 'rank_tier_stellar',
    fillColor: Color(0xFF06141A),
    borderColor: Color(0xFF00D4E8),
    letterColor: Color(0xFF7AFAFF),
    glowColor: Color(0xFF00A8C0),
    starFillColor: Color(0xFF5EF0FF),
  ),
  PlayerRankTier(
    id: 'nebula',
    defaultMinPoints: 0,
    starCount: 1,
    nameKey: 'rank_tier_nebula',
    // Electric indigo — nebula gas vibe; far from Stellar cyan on the hue wheel.
    fillColor: Color(0xFF0C0A1A),
    borderColor: Color(0xFF6366F1),
    letterColor: Color(0xFFA5B4FC),
    glowColor: Color(0xFF4F46E5),
    starFillColor: Color(0xFF818CF8),
  ),
];

/// Resolves rank from cumulative win points (admin thresholds).
PlayerRankTier playerRankForPoints(int points) {
  final clamped = points.clamp(0, 1 << 30);
  final cfg = AppRankConfigService.instance.config;
  for (final tier in playerRankTiers) {
    final min = cfg.minPointsForTier(tier.id);
    if (clamped >= min) return tier;
  }
  return playerRankTiers.last;
}

/// Width of the star row for [baseSize] (star diameter in logical px).
double playerRankBadgeWidth(
  PlayerRankTier tier,
  double baseSize, {
  bool compact = false,
}) {
  final star = baseSize * (compact ? 0.72 : 0.84);
  final gap = star * (compact ? 0.06 : 0.12);
  final count = tier.starCount.clamp(1, 5);
  return count * star + (count - 1) * gap;
}

double playerRankBadgeHeight(double baseSize, {bool compact = false}) {
  return baseSize * (compact ? 0.72 : 0.84);
}

/// Paints a compact star-row rank mark.
void paintPlayerRankBadge({
  required Canvas canvas,
  required Offset topLeft,
  required double zoom,
  required PlayerRankTier tier,
  double baseSize = 11.0,
  bool compact = true,
}) {
  final safeZoom = zoom.clamp(0.05, 10.0);
  final height = playerRankBadgeHeight(baseSize, compact: compact) / safeZoom;
  final starSize = baseSize * (compact ? 0.72 : 0.84) / safeZoom;
  final gap = starSize * (compact ? 0.06 : 0.12);
  final count = tier.starCount.clamp(1, 5);

  final glow = Paint()
    ..color = tier.glowColor.withValues(alpha: compact ? 0.28 : 0.38)
    ..maskFilter = MaskFilter.blur(
      BlurStyle.normal,
      (compact ? 1.4 : 2.2) / safeZoom,
    );

  final fill = Paint()..color = tier.effectiveStarFill;
  // Dark rim so rank stars don't blend into the starfield.
  final silhouette = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.55 / safeZoom
    ..color = Colors.black.withValues(alpha: 0.62);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7 / safeZoom
    ..color = tier.borderColor.withValues(alpha: 0.95);

  final cy = topLeft.dy + height / 2;
  var x = topLeft.dx;

  for (var i = 0; i < count; i++) {
    final center = Offset(x + starSize / 2, cy);
    final path = _starPath(center, starSize / 2);

    if (tier.id == 'singularity' || tier.id == 'quasar') {
      canvas.drawPath(path, glow);
    }
    canvas.drawPath(path, silhouette);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    x += starSize + gap;
  }
}

/// Convenience: paint the star crown centered on [center].
void paintPlayerRankBadgeCentered({
  required Canvas canvas,
  required Offset center,
  required double zoom,
  required PlayerRankTier tier,
  double baseSize = 7.0,
  bool compact = true,
}) {
  final safeZoom = zoom.clamp(0.05, 10.0);
  final width =
      playerRankBadgeWidth(tier, baseSize, compact: compact) / safeZoom;
  final height =
      playerRankBadgeHeight(baseSize, compact: compact) / safeZoom;
  paintPlayerRankBadge(
    canvas: canvas,
    topLeft: Offset(center.dx - width / 2, center.dy - height / 2),
    zoom: zoom,
    tier: tier,
    baseSize: baseSize,
    compact: compact,
  );
}

Path _starPath(Offset center, double radius) {
  final path = Path();
  const points = 5;
  final inner = radius * 0.42;
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? radius : inner;
    final angle = -math.pi / 2 + i * math.pi / points;
    final p = Offset(
      center.dx + math.cos(angle) * r,
      center.dy + math.sin(angle) * r,
    );
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// Flutter star used by [PlayerRankBadge] and other UI surfaces.
class PlayerRankStar extends StatelessWidget {
  const PlayerRankStar({
    super.key,
    required this.size,
    required this.fill,
    required this.border,
    this.glow,
  });

  final double size;
  final Color fill;
  final Color border;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlayerRankStarPainter(
        fill: fill,
        border: border,
        glow: glow,
      ),
    );
  }
}

class _PlayerRankStarPainter extends CustomPainter {
  _PlayerRankStarPainter({
    required this.fill,
    required this.border,
    this.glow,
  });

  final Color fill;
  final Color border;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = _starPath(center, size.shortestSide / 2);

    if (glow != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glow!.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.shortestSide * 0.16).clamp(1.0, 2.0)
        ..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.shortestSide * 0.08).clamp(0.6, 1.2)
        ..color = border.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _PlayerRankStarPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.border != border ||
        oldDelegate.glow != glow;
  }
}
