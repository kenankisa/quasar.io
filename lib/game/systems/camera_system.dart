import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/black_hole_partner.dart';
import '../orbit_game.dart';
import '../utils/black_hole_renderer.dart';

/// Kamera zoom ve izleyici (spectator) takibi.
class CameraSystem {
  CameraSystem(this.game);

  final OrbitGame game;

  static const _baseRadius = 25.0;
  static const _baseZoom = 1.0;
  static const _minZoom = 0.18;
  static const _maxZoom = 1.2;
  static const _zoomCompensation = 0.52;

  PositionComponent? _spectatorTarget;

  void clearSpectatorTarget() {
    _spectatorTarget = null;
  }

  void startSpectating() {
    if (!game.player.isEliminated || game.isSpectating.value) return;
    game.isSpectating.value = true;
    _spectatorTarget = null;
    final leader = findSpectatorLeader();
    if (leader != null) {
      _spectatorTarget = leader.component;
      game.camera.follow(leader.component, snap: true);
    }
  }

  void stopSpectating() {
    if (!game.isSpectating.value) return;
    game.isSpectating.value = false;
    _spectatorTarget = null;
    game.hudTick.value++;
  }

  void updateZoom(double dt) {
    applyCameraZoom(dt, game.player.radius);
  }

  void updateSpectator(double dt) {
    if (!game.isSpectating.value) return;

    final leader = findSpectatorLeader();
    if (leader == null) return;

    if (!identical(_spectatorTarget, leader.component)) {
      _spectatorTarget = leader.component;
      game.camera.follow(leader.component, snap: false);
    }

    applyCameraZoom(dt, leader.holeRadius);
  }

  ({PositionComponent component, double holeRadius})? findSpectatorLeader() {
    BlackHolePartner? leaderPartner;
    PositionComponent? leaderComponent;

    void consider(BlackHolePartner hole, PositionComponent component) {
      if (hole.isEliminated) return;
      if (leaderPartner == null ||
          hole.holeRadius > leaderPartner!.holeRadius) {
        leaderPartner = hole;
        leaderComponent = component;
      }
    }

    for (final bot in game.botPopulation.bots) {
      consider(bot, bot);
    }
    for (final enemy in game.enemyPlayers) {
      consider(enemy, enemy);
    }

    if (leaderPartner == null || leaderComponent == null) return null;
    return (component: leaderComponent!, holeRadius: leaderPartner!.holeRadius);
  }

  void applyCameraZoom(double dt, double focusRadius) {
    final visualR = BlackHoleRenderer.visualExtentRadius(focusRadius);
    final ratio = _baseRadius / visualR;
    final targetZoom =
        (math.pow(ratio, _zoomCompensation) * _baseZoom).clamp(_minZoom, _maxZoom);

    final currentZoom = game.camera.viewfinder.zoom;
    final t = 1 - math.exp(-dt * 6);
    game.camera.viewfinder.zoom = currentZoom + (targetZoom - currentZoom) * t;
  }
}
