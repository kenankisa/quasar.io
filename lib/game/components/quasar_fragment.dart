import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../config/room_visual_theme.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../utils/canvas_effects.dart';
import '../utils/consumable_tidal_spin.dart';
import '../utils/cosmic_body_renderer.dart';
import '../utils/gravity_visual.dart';
import '../utils/viewport_cull.dart';

/// Collectible quasar fragment — growth size 5 (unique rooms).
/// Compact accretion-disk look: hot core + thin tilted disk + subtle jets.
class QuasarFragment extends PositionComponent {
  QuasarFragment({
    required Vector2 position,
    this.collisionRadius = 15,
    this.growthValue = 5,
    Vector2? velocity,
  }) : velocity = velocity ?? Vector2.zero(),
       super(
         position: position,
         anchor: Anchor.center,
         size: Vector2.all(collisionRadius * 3.6),
       );

  final double collisionRadius;
  final double growthValue;
  final Vector2 velocity;

  bool active = true;
  double _spin = 0;
  double _pulse = 0;

  static const _gold = Color(0xFFFFC266);
  static const _core = Color(0xFFFFF8E8);

  Color _cyan(RoomVisualTheme theme) => theme.accent;
  Color _magenta(RoomVisualTheme theme) => theme.secondaryAccent;

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;

    if (velocity.length > 0) {
      position.addScaled(velocity, dt);
      velocity.scale(1 / (1 + 0.65 * dt));
    }

    final game = findGame() as OrbitGame?;
    const spinRate = 1.1;
    if (game != null &&
        ViewportCull.isFarFromView(
          game,
          position,
          margin: collisionRadius * 4 + ViewportCull.updateMargin,
        )) {
      // Pulse is render-only; skip when far so CPU stays on nearby matter.
      _spin += dt * spinRate;
      return;
    }
    _pulse += dt * 2.4;
    _spin = advanceConsumableTidalSpin(
      currentSpin: _spin,
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
        ViewportCull.isOffScreen(game, position, collisionRadius * 3.5)) {
      return;
    }
    super.render(canvas);
    final center = size / 2;
    final theme = RoomVisualTheme.forRoom(game?.roomType ?? RoomType.unique);
    final pulse = 1 + math.sin(_pulse) * 0.05;

    canvas.save();
    canvas.translate(center.x, center.y);
    canvas.scale(pulse);

    final dominant = game != null
        ? GravityVisual.dominantSource(
            position,
            game.activeGravitySources(),
            roomMultiplier: game.roomConfig.gravityMultiplier,
          )
        : null;

    if (dominant != null) {
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
        bodyColor: _gold,
        roomMultiplier: game.roomConfig.gravityMultiplier,
        spinAngle: _spin * 0.15 * spinRetain,
        tidalAxisKey: identityHashCode(this),
        cameraZoom: game.camera.viewfinder.zoom,
        animationPhase: game.matchElapsed,
        paintBody: (c, visualRadius) =>
            _drawQuasarBody(c, visualRadius, theme, spin: 0),
      );
    } else {
      _drawQuasarBody(canvas, collisionRadius, theme, spin: _spin);
    }

    canvas.restore();
  }

  void _drawQuasarBody(
    Canvas canvas,
    double r,
    RoomVisualTheme theme, {
    required double spin,
  }) {
    if (CanvasEffects.mobileLiteMode) {
      canvas.save();
      canvas.rotate(0.5);
      canvas.scale(1.0, 0.35);
      canvas.drawCircle(
        Offset.zero,
        r * 1.55,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = _magenta(theme).withValues(alpha: 0.75),
      );
      canvas.restore();
      CosmicBodyRenderer.drawQuasarCore(
        canvas,
        r,
        _core,
        _gold,
        _magenta(theme),
        spin,
      );
      return;
    }

    canvas.save();
    canvas.rotate(spin * 0.15);
    for (final dir in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(0, dir * r * 0.35),
        Offset(0, dir * r * 1.7),
        Paint()
          ..color = _cyan(theme).withValues(alpha: 0.28)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();

    canvas.save();
    canvas.rotate(0.55);
    canvas.scale(1.0, 0.32);
    canvas.clipRect(Rect.fromLTRB(-r * 2.2, -r * 2.2, r * 2.2, 0));
    CosmicBodyRenderer.drawQuasarDisk(
      canvas,
      r,
      _gold,
      _cyan(theme),
      _magenta(theme),
    );
    canvas.restore();

    CosmicBodyRenderer.drawQuasarCore(
      canvas,
      r,
      _core,
      _gold,
      _magenta(theme),
      spin,
    );

    canvas.save();
    canvas.rotate(0.55);
    canvas.scale(1.0, 0.32);
    canvas.clipRect(Rect.fromLTRB(-r * 2.2, 0, r * 2.2, r * 2.2));
    CosmicBodyRenderer.drawQuasarDisk(
      canvas,
      r,
      _gold,
      _cyan(theme),
      _magenta(theme),
    );
    canvas.restore();
  }
}
