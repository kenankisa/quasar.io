import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../orbit_game.dart';
import 'black_hole_name_label.dart';
import 'black_hole_renderer.dart';
import 'gravity_threat_indicator.dart';
import 'gravity_visual.dart';
import 'hole_swallow_visual.dart';
import 'viewport_cull.dart';

/// Shared render path for [BotPlayer] and [EnemyPlayer].
abstract final class CompetitorHoleRenderer {
  CompetitorHoleRenderer._();

  static void paintThreatIndicators({
    required Canvas canvas,
    required OrbitGame? game,
    required Vector2 position,
    required double radius,
    required double diskRotation,
  }) {
    if (game == null || game.player.isEliminated) return;

    final dist = game.player.position.distanceTo(position);
    if (radius > game.player.radius) {
      GravityThreatIndicator.paintThreat(
        canvas: canvas,
        sourceRadius: radius,
        playerRadius: game.player.radius,
        distanceToPlayer: dist,
        pulse: diskRotation,
      );
    } else if (game.player.radius > radius) {
      GravityThreatIndicator.paintPrey(
        canvas: canvas,
        sourceRadius: radius,
        playerRadius: game.player.radius,
        distanceToPlayer: dist,
        pulse: diskRotation,
      );
    }
  }

  static SwallowEntityState swallowState(
    OrbitGame? game,
    Vector2 position,
    double radius,
  ) {
    return game?.holeSwallowManager.stateFor(position, radius) ??
        SwallowEntityState.none;
  }

  static void paintSwallowDistortion({
    required Canvas canvas,
    required OrbitGame? game,
    required Vector2 position,
    required double radius,
  }) {
    if (game == null) return;
    HoleSwallowVisual.paintPreyDistortion(
      canvas: canvas,
      gameRadius: radius,
      state: swallowState(game, position, radius),
    );
  }

  /// Full competitor hole draw (threat → body → name → speech).
  /// Returns false when culled / eliminated so callers can skip further work.
  static bool paint({
    required Canvas canvas,
    required Vector2 componentSize,
    required OrbitGame? game,
    required Vector2 position,
    required double radius,
    required double diskRotation,
    required String skin,
    required bool isBoosting,
    required bool showShieldRing,
    bool showLinkRing = false,
    required Color fragmentationAccent,
    required double quasarFlash,
    required Object shaderKey,
    required String displayName,
    required String networkId,
    Color? accentColor,
    double shieldPhase = 0,
    bool isBot = false,
    int? rankPoints,
    ui.Image? portrait,
    String? portraitEmoji,
    String? portraitInitial,
    Color? portraitColor,
  }) {
    if (game != null &&
        ViewportCull.isOffScreen(game, position, radius * 3)) {
      return false;
    }

    final center = componentSize / 2;
    canvas.save();
    canvas.translate(center.x, center.y);

    paintThreatIndicators(
      canvas: canvas,
      game: game,
      position: position,
      radius: radius,
      diskRotation: diskRotation,
    );

    final state = swallowState(game, position, radius);
    paintSwallowDistortion(
      canvas: canvas,
      game: game,
      position: position,
      radius: radius,
    );

    final showPortraits = SettingsService.instance.showProfilePictures;
    final detail = BlackHoleRenderer.detailForRadius(radius);
    final influx = game != null && game.isReady
        ? game.spawnManager.influxIntensityAt(position, radius)
        : 0.0;

    BlackHoleRenderer.paint(
      canvas: canvas,
      radius: radius,
      diskRotation: diskRotation,
      skin: skin,
      accentColor: accentColor,
      isBoosting: isBoosting,
      showShieldRing: showShieldRing,
      showLinkRing: showLinkRing,
      shieldPhase: shieldPhase,
      highDetail: detail.highDetail,
      compact: detail.compact,
      gravityIntensity: GravityVisual.holeVisualIntensity(radius),
      swallowCharge: HoleSwallowVisual.photonRingBoost(state),
      influxFlux: influx,
      quasarActivation: quasarFlash,
      shaderKey: shaderKey,
    );

    HoleSwallowVisual.paintPreyFragmentation(
      canvas: canvas,
      gameRadius: radius,
      state: state,
      accent: fragmentationAccent,
    );

    if (BlackHoleNameLabel.shouldShow(isLocal: false) || showPortraits) {
      BlackHoleNameLabel.paint(
        canvas: canvas,
        radius: radius,
        name: BlackHoleNameLabel.shouldShow(isLocal: false) ? displayName : '',
        zoom: game?.camera.viewfinder.zoom ?? 1.0,
        isLocal: false,
        isBot: isBot,
        rankPoints: rankPoints,
        portrait: showPortraits ? portrait : null,
        portraitEmoji: showPortraits ? portraitEmoji : null,
        portraitInitial: showPortraits ? portraitInitial : null,
        portraitColor: portraitColor,
      );
    }

    final speech = game?.speechBubbleTextFor(networkId);
    if (speech != null && speech.isNotEmpty) {
      BlackHoleNameLabel.paintSpeechBubble(
        canvas: canvas,
        radius: radius,
        text: speech,
        zoom: game?.camera.viewfinder.zoom ?? 1.0,
      );
    }

    canvas.restore();
    return true;
  }
}
