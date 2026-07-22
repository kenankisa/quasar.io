part of '../starfield_background.dart';

// ─────────────────────────────────────────────────────────────────────────
//  Stars — realistic spectral distribution (M/K common & warm-dim,
//  O/B rare & blue-bright), layered by depth for parallax-free density.
// ─────────────────────────────────────────────────────────────────────────

enum _TwinkleStyle { smooth, pulse, breathe }

/// Blackbody-ish star palette: (color, relative abundance).
const List<(Color, double)> _spectralColors = [
  (Color(0xFFFFC9A0), 0.24), // M — orange-red dwarfs
  (Color(0xFFFFDDBB), 0.18), // K — orange
  (Color(0xFFFFF1DC), 0.16), // G — sun-like yellow-white
  (Color(0xFFFFFFFF), 0.14), // F — white
  (Color(0xFFF2F6FF), 0.11), // A — blue-white
  (Color(0xFFDFE9FF), 0.08), // A/B
  (Color(0xFFC4D8FF), 0.06), // B — blue
  (Color(0xFFA9C5FF), 0.03), // O — rare hot blue giants
];

Color _sampleStarColor(math.Random rng, double hotBias) {
  // Hot bias re-rolls toward the blue end — big bright stars read hotter.
  if (hotBias > 0 && rng.nextDouble() < hotBias * 0.55) {
    return _spectralColors[5 + rng.nextInt(3)].$1;
  }
  var roll = rng.nextDouble();
  for (final (color, weight) in _spectralColors) {
    roll -= weight;
    if (roll <= 0) return color;
  }
  return Colors.white;
}

class _Star {
  const _Star({
    required this.position,
    required this.radius,
    required this.alpha,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.twinkleStyle,
    required this.color,
  });

  final Vector2 position;
  final double radius;
  final double alpha;
  final double twinklePhase;
  final double twinkleSpeed;
  final _TwinkleStyle twinkleStyle;
  final Color color;

  double twinkleFactor(double elapsed) {
    final t = elapsed * twinkleSpeed + twinklePhase;
    return switch (twinkleStyle) {
      _TwinkleStyle.smooth => 0.55 + math.sin(t) * 0.45,
      _TwinkleStyle.pulse => math.pow((math.sin(t) + 1) * 0.5, 2.8).toDouble(),
      _TwinkleStyle.breathe =>
        0.08 + math.pow((math.sin(t * 0.55) + 1) * 0.5, 1.6).toDouble() * 0.92,
    };
  }
}

class _StarLayer {
  _StarLayer({
    required this.count,
    required this.minRadius,
    required this.maxRadius,
    required this.minAlpha,
    required this.maxAlpha,
    required this.seed,
    this.hotBias = 0.0,
  });

  final int count;
  final double minRadius;
  final double maxRadius;
  final double minAlpha;
  final double maxAlpha;
  final int seed;

  /// 0 = realistic warm-heavy mix, 1 = strongly biased toward blue giants.
  final double hotBias;

  /// Hot / bright layers stay procedural for twinkle + lensing when tiles bake.
  bool get isLiveLayer => hotBias > 0;

  late final List<_Star> stars;
  late final _StarSpatialGrid grid;

  /// [fullBudget] skips the mobile half-count cut — used for bake-only dim layers
  /// (paid once at bake time, not every frame).
  void generate(double worldSize, {bool fullBudget = false}) {
    final rng = math.Random(seed);
    final liteFactor =
        (!fullBudget && CanvasEffects.mobileLiteMode) ? 0.5 : 1.0;
    final budget = liteFactor < 1.0
        ? (count * liteFactor).round().clamp(1, count)
        : count;

    stars = List.generate(budget, (i) {
      final styleRoll = rng.nextDouble();
      final style = styleRoll < 0.62
          ? _TwinkleStyle.smooth
          : styleRoll < 0.86
              ? _TwinkleStyle.pulse
              : _TwinkleStyle.breathe;

      return _Star(
        position: Vector2(
          rng.nextDouble() * worldSize,
          rng.nextDouble() * worldSize,
        ),
        radius: minRadius + rng.nextDouble() * (maxRadius - minRadius),
        alpha: minAlpha + rng.nextDouble() * (maxAlpha - minAlpha),
        twinklePhase: rng.nextDouble() * math.pi * 2,
        twinkleSpeed: 0.28 + rng.nextDouble() * 1.8,
        twinkleStyle: style,
        color: _sampleStarColor(rng, hotBias),
      );
    });
    grid = _StarSpatialGrid(worldSize: worldSize, stars: stars);
  }
}

/// Buckets stars into world cells so draw only visits nearby cells.
class _StarSpatialGrid {
  _StarSpatialGrid({
    required double worldSize,
    required List<_Star> stars,
  })  : cellSize = _defaultCellSize,
        cols = math.max(1, (worldSize / _defaultCellSize).ceil()) {
    rows = cols;
    buckets = List.generate(cols * rows, (_) => <_Star>[]);
    for (final star in stars) {
      final cx = (star.position.x / cellSize).floor().clamp(0, cols - 1);
      final cy = (star.position.y / cellSize).floor().clamp(0, rows - 1);
      buckets[cy * cols + cx].add(star);
    }
  }

  static const _defaultCellSize = 480.0;

  final double cellSize;
  final int cols;
  late final int rows;
  late final List<List<_Star>> buckets;

  void forEachInRect(Rect rect, void Function(_Star star) visit) {
    if (buckets.isEmpty) return;
    final minX = (rect.left / cellSize).floor().clamp(0, cols - 1);
    final maxX = (rect.right / cellSize).floor().clamp(0, cols - 1);
    final minY = (rect.top / cellSize).floor().clamp(0, rows - 1);
    final maxY = (rect.bottom / cellSize).floor().clamp(0, rows - 1);
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        for (final star in buckets[y * cols + x]) {
          visit(star);
        }
      }
    }
  }
}
