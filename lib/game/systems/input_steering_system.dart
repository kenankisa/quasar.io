import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../services/player_session_service.dart';
import '../orbit_game.dart';

/// Touch drag → black-hole velocity steering for the local player.
class InputSteeringSystem {
  InputSteeringSystem(this.game);

  final OrbitGame game;

  static const _steerSharpness = 22.0;
  static const _stopRadiusWorld = 10.0;
  static const _arriveRadiusWorld = 56.0;
  static const _fullSpeedScreenFraction = 0.30;

  bool _holeDragActive = false;
  Vector2? _dragFingerWidget;

  bool get isHoleDragActive => _holeDragActive;

  void beginHoleDrag(Vector2 widgetPosition) {
    _holeDragActive = true;
    _dragFingerWidget = widgetPosition;
  }

  void endHoleDrag() {
    _holeDragActive = false;
    _dragFingerWidget = null;
  }

  void onPanDown(DragDownInfo info) {
    if (game.player.isEliminated || game.isFrozen) return;
    beginHoleDrag(info.eventPosition.widget);
  }

  void onPanStart(DragStartInfo info) {
    if (game.player.isEliminated || game.isFrozen) return;
    if (_holeDragActive) return;
    beginHoleDrag(info.eventPosition.widget);
  }

  void onPanUpdate(DragUpdateInfo info) {
    if (!_holeDragActive || game.player.isEliminated || game.isFrozen) return;
    _dragFingerWidget = info.eventPosition.widget;
    PlayerSessionService.instance.noteActivity();
  }

  void onPanEnd(DragEndInfo info) {
    if (!_holeDragActive) return;
    endHoleDrag();
  }

  void onPanCancel() {
    if (!_holeDragActive) return;
    endHoleDrag();
  }

  /// Call once per frame while the match is live and the local player is alive.
  void tick(double dt) {
    if (!_holeDragActive) return;
    if (game.player.isEliminated) return;
    applyPullSteering(dt);
  }

  double _fullSpeedWorldDistance() {
    final vp = game.camera.viewport.virtualSize;
    final screenDist = math.min(vp.x, vp.y) * _fullSpeedScreenFraction;
    return screenDist / game.camera.viewfinder.zoom;
  }

  Vector2 _widgetToWorld(Vector2 widget) {
    return game.camera.globalToLocal(widget);
  }

  /// Parmağın dünya konumuna ivmeli takip — parmak nereye giderse karadelik oraya akar.
  void applyPullSteering(double dt) {
    if (game.gravityPhysics.isInspiralLocked(game.player)) return;

    final finger = _dragFingerWidget;
    if (finger == null) return;

    final player = game.player;
    final toFinger = _widgetToWorld(finger) - player.position;
    final dist = toFinger.length;

    if (dist < _stopRadiusWorld) {
      final brake = math.exp(-dt * 16);
      player.velocity.scale(brake);
      return;
    }

    final fullDist = math.max(
      _fullSpeedWorldDistance(),
      _arriveRadiusWorld + _stopRadiusWorld,
    );
    final range = fullDist - _stopRadiusWorld;
    final t = ((dist - _stopRadiusWorld) / range).clamp(0.0, 1.0);
    final strength = t * t * (3 - 2 * t);

    var targetSpeed = player.effectiveMaxSpeed * strength;
    if (dist < _arriveRadiusWorld) {
      final arriveFactor = (dist / _arriveRadiusWorld).clamp(0.12, 1.0);
      targetSpeed = math.min(
        targetSpeed,
        player.effectiveMaxSpeed * arriveFactor,
      );
    }

    final targetVel = toFinger.normalized() * targetSpeed;
    final blend = 1 - math.exp(-_steerSharpness * dt);
    player.velocity.addScaled(targetVel - player.velocity, blend);

    final cap = player.effectiveMaxSpeed;
    final speed = player.velocity.length;
    if (speed > cap) {
      player.velocity.scale(cap / speed);
    }
  }
}
