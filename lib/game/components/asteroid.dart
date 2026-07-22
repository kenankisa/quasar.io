import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/room_visual_theme.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../utils/consumable_tidal_spin.dart';
import '../utils/cosmic_body_renderer.dart';
import '../utils/gravity_visual.dart';
import '../utils/viewport_cull.dart';

/// Collectible rock sizes.
/// Asteroids: growth 1–2. Meteorites (göktaşı): growth 3. Basit oda: growth ~3–4.5.
enum CosmicRockType {
  smallAsteroid(growth: 1, collisionRadius: 7),
  mediumAsteroid(growth: 2, collisionRadius: 10),
  meteorite(growth: 3, collisionRadius: 13),
  largeAsteroid(growth: 3.2, collisionRadius: 17),
  xlargeAsteroid(growth: 3.8, collisionRadius: 19),
  giantAsteroid(growth: 4.5, collisionRadius: 21);

  const CosmicRockType({
    required this.growth,
    required this.collisionRadius,
  });

  final double growth;
  final double collisionRadius;

  bool get isMeteorite => this == CosmicRockType.meteorite;

  bool get isSimpleTier =>
      this == CosmicRockType.largeAsteroid ||
      this == CosmicRockType.xlargeAsteroid ||
      this == CosmicRockType.giantAsteroid;
}

class Asteroid extends PositionComponent {
  Asteroid({
    required Vector2 position,
    this.rockType = CosmicRockType.smallAsteroid,
    double? collisionRadius,
    double? growthValue,
    this.isFragment = false,
    Vector2? velocity,
  }) : collisionRadius = collisionRadius ?? rockType.collisionRadius,
       growthValue = growthValue ?? rockType.growth,
       velocity = velocity ?? Vector2.zero(),
       _shapeSeed = CosmicBodyRenderer.seedFrom(position),
       super(
         position: position,
         anchor: Anchor.center,
         size: Vector2.all((collisionRadius ?? rockType.collisionRadius) * 2.6),
       );

  final CosmicRockType rockType;
  final double collisionRadius;
  final double growthValue;
  final bool isFragment;
  final Vector2 velocity;
  final int _shapeSeed;

  bool active = true;
  double _rotation = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    position.addScaled(velocity, dt);

    final spinRate = isFragment
        ? 4.5
        : rockType.isMeteorite
            ? 0.55
            : rockType.isSimpleTier
                ? 0.28
                : 0.4;

    final game = findGame() as OrbitGame?;
    // Off-screen: cheap local spin only — skip gravity-source tidal scans.
    if (game != null &&
        ViewportCull.isFarFromView(
          game,
          position,
          margin: collisionRadius * 4 + ViewportCull.updateMargin,
        )) {
      _rotation += dt * spinRate;
      return;
    }
    _rotation = advanceConsumableTidalSpin(
      currentSpin: _rotation,
      game: game,
      position: position,
      entityRadius: collisionRadius,
      dt: dt,
      baseSpinRate: spinRate,
    );
  }

  void deactivate() {
    active = false;
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    final game = findGame() as OrbitGame?;
    if (game != null &&
        ViewportCull.isOffScreen(game, position, collisionRadius * 3)) {
      return;
    }
    super.render(canvas);
    final center = size / 2;
    final theme = RoomVisualTheme.forRoom(game?.roomType ?? RoomType.normal);

    canvas.save();
    canvas.translate(center.x, center.y);

    final dominant = game != null
        ? GravityVisual.dominantSource(
            position,
            game.activeGravitySources(),
            roomMultiplier: game.roomConfig.gravityMultiplier,
          )
        : null;

    void paintBody(Canvas canvas, double visualRadius) {
      if (rockType.isMeteorite && !isFragment) {
        _renderMeteorite(canvas, theme, visualRadius);
      } else {
        _renderAsteroid(canvas, theme, visualRadius);
      }

      if (theme.rimAccentAlpha > 0 && !isFragment) {
        canvas.drawCircle(
          Offset.zero,
          visualRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = theme.accent.withValues(alpha: theme.rimAccentAlpha),
        );
      }
    }

    if (dominant != null) {
      final baseColor = _baseColor(theme);
      final intensity = GravityVisual.consumableTidalIntensity(
        sourceRadius: dominant.radius,
        entityRadius: collisionRadius,
        distance: position.distanceTo(dominant.position),
        roomMultiplier: game!.roomConfig.gravityMultiplier,
      );
      final spinRetain = GravityVisual.tidalSpinRetain(intensity);
      GravityVisual.paintConsumableWithTides(
        canvas: canvas,
        entityWorldPosition: position,
        sourceWorldPosition: dominant.position,
        sourceRadius: dominant.radius,
        entityRadius: collisionRadius,
        accent: theme.accent,
        bodyColor: baseColor,
        roomMultiplier: game.roomConfig.gravityMultiplier,
        spinAngle: _rotation * spinRetain,
        tidalAxisKey: identityHashCode(this),
        cameraZoom: game.camera.viewfinder.zoom,
        animationPhase: game.matchElapsed,
        paintBody: paintBody,
      );
    } else {
      canvas.save();
      canvas.rotate(_rotation);
      paintBody(canvas, collisionRadius);
      canvas.restore();
    }

    canvas.restore();
  }

  Color _baseColor(RoomVisualTheme theme) {
    if (isFragment) return theme.tint(const Color(0xFF8A8A8A));
    final raw = switch (rockType) {
      CosmicRockType.giantAsteroid => const Color(0xFF9A8A72),
      CosmicRockType.xlargeAsteroid => const Color(0xFF8A8278),
      CosmicRockType.largeAsteroid => const Color(0xFF787878),
      CosmicRockType.mediumAsteroid => const Color(0xFF7A7A7A),
      CosmicRockType.meteorite => const Color(0xFF8B5A3C),
      _ => const Color(0xFF6B6B6B),
    };
    return theme.tint(raw);
  }

  void _renderAsteroid(Canvas canvas, RoomVisualTheme theme, double r) {
    final baseColor = _baseColor(theme);
    final vertices = switch (rockType) {
      CosmicRockType.giantAsteroid => 10,
      CosmicRockType.xlargeAsteroid => 9,
      CosmicRockType.largeAsteroid => 8,
      CosmicRockType.mediumAsteroid => 8,
      _ => 7,
    };
    final irregularity = isFragment ? 0.3 : 0.24;

    CosmicBodyRenderer.drawAsteroid(
      canvas,
      r,
      baseColor,
      _shapeSeed,
      vertexCount: vertices,
      irregularity: irregularity,
    );
  }

  void _renderMeteorite(Canvas canvas, RoomVisualTheme theme, double r) {
    const rawBase = Color(0xFF8B5A3C);
    const rawHighlight = Color(0xFFC48A5A);
    const rawCore = Color(0xFF5C3A28);
    CosmicBodyRenderer.drawMeteorite(
      canvas,
      r,
      theme.tint(rawBase),
      Color.lerp(rawHighlight, theme.accent, 0.22)!,
      theme.tint(rawCore),
      _shapeSeed,
    );
  }
}
