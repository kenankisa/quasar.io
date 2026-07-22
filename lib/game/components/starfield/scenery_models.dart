part of '../starfield_background.dart';

// ─────────────────────────────────────────────────────────────────────────
//  Static scenery — nebula complexes, distant galaxies, Milky Way band.
//  All gradient shaders are built ONCE at load; per-frame we only transform
//  the canvas. Re-creating ~60 ui.Gradient objects every frame stalls
//  CanvasKit on web, especially while merger VFX are peaking.
// ─────────────────────────────────────────────────────────────────────────

/// One soft gradient blob inside a nebula complex (local coordinates).
class _NebulaBlob {
  _NebulaBlob({
    required this.offset,
    required this.radius,
    required this.dark,
    required this.paint,
  });

  final Offset offset;
  final double radius;

  /// Dark blobs are dust lanes — painted over the glow to carve structure.
  final bool dark;
  final Paint paint;
}

/// A multi-blob nebula: core glow + accent wisps + dust lanes, giving the
/// layered Hubble-photo look instead of a single flat radial gradient.
class _NebulaComplex {
  const _NebulaComplex({
    required this.position,
    required this.rotation,
    required this.stretchX,
    required this.stretchY,
    required this.driftSpeed,
    required this.phase,
    required this.blobs,
    required this.boundRadius,
  });

  final Vector2 position;
  final double rotation;
  final double stretchX;
  final double stretchY;
  final double driftSpeed;
  final double phase;
  final List<_NebulaBlob> blobs;
  final double boundRadius;
}

class _Galaxy {
  _Galaxy({
    required this.position,
    required this.radius,
    required this.tilt,
    required this.aspect,
    required this.spiral,
    required this.diskPaint,
    required this.corePaint,
    required this.armPaint,
  });

  final Vector2 position;
  final double radius;
  final double tilt;
  final double aspect;
  final bool spiral;
  final Paint diskPaint;
  final Paint corePaint;
  final Paint? armPaint;
}

/// Elongated glow / dust patch forming the Milky Way band.
class _BandPatch {
  _BandPatch({
    required this.center,
    required this.radius,
    required this.stretch,
    required this.rotation,
    required this.paint,
  });

  final Offset center;
  final double radius;
  final double stretch;
  final double rotation;
  final Paint paint;
}

/// Unresolved band star — static micro-dot, no twinkle (CPU-cheap density).
class _BandStar {
  const _BandStar(this.position, this.radius, this.alpha, this.color);

  final Offset position;
  final double radius;
  final double alpha;
  final Color color;
}

class _Pulsar {
  _Pulsar({
    required this.position,
    required this.period,
    required this.phase,
    required this.glowPaint,
  });

  final Vector2 position;
  final double period;
  final double phase;
  final Paint glowPaint;

  /// Reference radius the cached glow gradient was built for.
  static const glowBaseRadius = 12.0;
}

// ─────────────────────────────────────────────────────────────────────────
//  Dynamic events — comets, meteor streaks, supernovae.
// ─────────────────────────────────────────────────────────────────────────

class _Comet {
  _Comet({
    required this.position,
    required this.velocity,
    required this.maxLife,
    required this.curl,
    required this.headRadius,
    required this.angle,
    required this.ionLength,
    required this.ionPaint,
    required this.comaPaint,
  });

  final Vector2 position;
  final Vector2 velocity;
  final double maxLife;

  /// Perpendicular bend of the dust tail (solar-wind curvature illusion).
  final double curl;
  final double headRadius;

  /// Travel direction — constant, so tail paints are cached in local frame.
  final double angle;
  final double ionLength;
  final Paint ionPaint;
  final Paint comaPaint;
  double life = 0;

  bool get isDead => life >= maxLife;
}

class _DecorMeteor {
  _DecorMeteor({
    required this.start,
    required this.end,
    required this.maxLife,
    required this.color,
  });

  final Vector2 start;
  final Vector2 end;
  final double maxLife;
  final Color color;
  double life = 0;

  bool get isDead => life >= maxLife;
  double get progress => (life / maxLife).clamp(0.0, 1.0);
}

class _Supernova {
  _Supernova({required this.position, required this.maxLife});

  final Vector2 position;
  final double maxLife;
  double life = 0;

  bool get isDead => life >= maxLife;
  double get progress => (life / maxLife).clamp(0.0, 1.0);
}
