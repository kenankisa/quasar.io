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

class Planet extends PositionComponent {
  Planet({
    required Vector2 position,
    required this.colorIndex,
    this.collisionRadius = 14,
    this.growthValue = 4,
    Vector2? velocity,
    this.isEventReward = false,
  }) : velocity = velocity ?? Vector2.zero(),
       _kind = PlanetKind.values[colorIndex % PlanetKind.values.length],
       super(
         position: position,
         anchor: Anchor.center,
         size: Vector2.all(collisionRadius * 3.2),
       );

  final int colorIndex;
  final double collisionRadius;
  final double growthValue;
  final Vector2 velocity;
  final bool isEventReward;
  final PlanetKind _kind;

  bool active = true;
  double _spin = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    if (velocity.length > 0) {
      position.addScaled(velocity, dt);
      velocity.scale(1 / (1 + 0.8 * dt));
    }

    final game = findGame() as OrbitGame?;
    final spinRate = _kind.spinSpeed;
    if (game != null &&
        ViewportCull.isFarFromView(
          game,
          position,
          margin: collisionRadius * 4 + ViewportCull.updateMargin,
        )) {
      _spin += dt * spinRate;
      return;
    }
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
        ViewportCull.isOffScreen(game, position, collisionRadius * 3)) {
      return;
    }
    super.render(canvas);
    final center = size / 2;
    final theme = RoomVisualTheme.forRoom(game?.roomType ?? RoomType.normal);

    canvas.save();
    canvas.translate(center.x, center.y);

    if (_kind.hasRings) {
      _drawRingFar(canvas, theme);
    }

    final dominant = game != null
        ? GravityVisual.dominantSource(
            position,
            game.activeGravitySources(),
            roomMultiplier: game.roomConfig.gravityMultiplier,
          )
        : null;

    void paintBody(Canvas canvas, double visualRadius, double spin) {
      CosmicBodyRenderer.drawPlanetSphere(
        canvas,
        visualRadius,
        theme.tint(_kind.base),
        theme.tint(_kind.shade),
        Color.lerp(_kind.atmosphere, theme.accent, 0.28)!,
        spin,
        (c, r) => _drawSurface(c, r),
      );
    }

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
        bodyColor: theme.tint(_kind.base),
        roomMultiplier: game.roomConfig.gravityMultiplier,
        spinAngle: 0,
        tidalAxisKey: identityHashCode(this),
        cameraZoom: game.camera.viewfinder.zoom,
        animationPhase: game.matchElapsed,
        paintBody: (c, r) => paintBody(c, r, _spin * spinRetain),
      );
    } else {
      paintBody(canvas, collisionRadius, _spin);
    }

    if (_kind.hasRings) {
      _drawRingNear(canvas, theme);
    }

    canvas.restore();
  }

  void _drawSurface(Canvas canvas, double r) {
    switch (_kind) {
      case PlanetKind.gasGiant:
      case PlanetKind.iceGiant:
        _drawBands(canvas, r);
      case PlanetKind.terrestrial:
      case PlanetKind.ocean:
        _drawContinents(canvas, r);
      case PlanetKind.desert:
      case PlanetKind.volcanic:
        _drawBlotches(canvas, r);
      case PlanetKind.rocky:
        _drawCraters(canvas, r);
    }
  }

  void _drawBands(Canvas canvas, double r) {
    final bandPaint = Paint()..style = PaintingStyle.stroke;
    final count = CanvasEffects.mobileLiteMode ? 3 : 5;
    for (var i = 0; i < count; i++) {
      final t = (i + 1) / (count + 1);
      final y = -r + r * 2 * t;
      bandPaint
        ..strokeWidth = r * (0.08 + (i.isEven ? 0.06 : 0.03))
        ..color = Color.lerp(
          _kind.detail,
          _kind.base,
          i.isEven ? 0.15 : 0.55,
        )!.withValues(alpha: 0.45);
      canvas.drawLine(Offset(-r, y), Offset(r, y), bandPaint);
    }
  }

  void _drawContinents(Canvas canvas, double r) {
    final land = Paint()..color = _kind.detail.withValues(alpha: 0.55);
    final spots = <Offset>[
      Offset(-r * 0.35, -r * 0.2),
      Offset(r * 0.25, r * 0.1),
      Offset(-r * 0.05, r * 0.4),
      Offset(r * 0.4, -r * 0.35),
    ];
    for (var i = 0; i < spots.length; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: spots[i],
          width: r * (0.45 + (i % 3) * 0.12),
          height: r * (0.28 + (i % 2) * 0.1),
        ),
        land,
      );
    }
  }

  void _drawBlotches(Canvas canvas, double r) {
    final paint = Paint()..color = _kind.detail.withValues(alpha: 0.4);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + 0.4;
      canvas.drawCircle(
        Offset(math.cos(a) * r * 0.45, math.sin(a) * r * 0.35),
        r * (0.18 + (i % 2) * 0.08),
        paint,
      );
    }
  }

  void _drawCraters(Canvas canvas, double r) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _kind.detail.withValues(alpha: 0.5);
    final craters = <(Offset, double)>[
      (Offset(-r * 0.3, -r * 0.15), r * 0.16),
      (Offset(r * 0.22, r * 0.2), r * 0.12),
      (Offset(r * 0.05, -r * 0.4), r * 0.09),
    ];
    for (final (c, size) in craters) {
      canvas.drawCircle(c, size, paint);
    }
  }

  void _drawRingFar(Canvas canvas, RoomVisualTheme theme) {
    canvas.save();
    canvas.rotate(_kind.ringTilt);
    canvas.scale(1.0, 0.28);
    _strokeRing(canvas, behind: true, theme: theme);
    canvas.restore();
  }

  void _drawRingNear(Canvas canvas, RoomVisualTheme theme) {
    canvas.save();
    canvas.rotate(_kind.ringTilt);
    canvas.scale(1.0, 0.28);
    canvas.clipRect(Rect.fromLTRB(-collisionRadius * 2.2, 0, collisionRadius * 2.2, collisionRadius * 2));
    _strokeRing(canvas, behind: false, theme: theme);
    canvas.restore();
  }

  void _strokeRing(Canvas canvas, {required bool behind, required RoomVisualTheme theme}) {
    final r = collisionRadius * 1.75;
    final alpha = behind ? 0.35 : 0.55;
    final ringColor = Color.lerp(theme.tint(_kind.base), theme.accent, 0.25)!;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Color.lerp(ringColor, Colors.white, 0.35)!
            .withValues(alpha: alpha),
    );
    if (!CanvasEffects.mobileLiteMode) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.08,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = theme.secondaryAccent.withValues(alpha: alpha * 0.7),
      );
    }
  }
}

enum PlanetKind {
  gasGiant(
    base: Color(0xFFC9954A),
    shade: Color(0xFF6B3E18),
    detail: Color(0xFFE8C078),
    atmosphere: Color(0xFFFFD9A0),
    hasRings: true,
    ringTilt: 0.35,
    spinSpeed: 0.55,
  ),
  iceGiant(
    base: Color(0xFF6FA8C9),
    shade: Color(0xFF244A66),
    detail: Color(0xFFB8DFF0),
    atmosphere: Color(0xFFA8D8F0),
    hasRings: true,
    ringTilt: -0.25,
    spinSpeed: 0.45,
  ),
  terrestrial(
    base: Color(0xFF3D7A54),
    shade: Color(0xFF1A3328),
    detail: Color(0xFF8B6B3E),
    atmosphere: Color(0xFF7EC8E8),
    hasRings: false,
    ringTilt: 0,
    spinSpeed: 0.7,
  ),
  ocean(
    base: Color(0xFF2F6F9E),
    shade: Color(0xFF12324A),
    detail: Color(0xFF4A9A5C),
    atmosphere: Color(0xFF8FD0F0),
    hasRings: false,
    ringTilt: 0,
    spinSpeed: 0.65,
  ),
  desert(
    base: Color(0xFFC47A4A),
    shade: Color(0xFF5A2E18),
    detail: Color(0xFFE0A878),
    atmosphere: Color(0xFFD8B090),
    hasRings: false,
    ringTilt: 0,
    spinSpeed: 0.5,
  ),
  volcanic(
    base: Color(0xFF6B3030),
    shade: Color(0xFF2A1010),
    detail: Color(0xFFE06830),
    atmosphere: Color(0xFFFF8855),
    hasRings: false,
    ringTilt: 0,
    spinSpeed: 0.4,
  ),
  rocky(
    base: Color(0xFF8A8580),
    shade: Color(0xFF3A3836),
    detail: Color(0xFFB8B0A8),
    atmosphere: Color(0xFFAAA8A4),
    hasRings: false,
    ringTilt: 0,
    spinSpeed: 0.35,
  );

  const PlanetKind({
    required this.base,
    required this.shade,
    required this.detail,
    required this.atmosphere,
    required this.hasRings,
    required this.ringTilt,
    required this.spinSpeed,
  });

  final Color base;
  final Color shade;
  final Color detail;
  final Color atmosphere;
  final bool hasRings;
  final double ringTilt;
  final double spinSpeed;
}
