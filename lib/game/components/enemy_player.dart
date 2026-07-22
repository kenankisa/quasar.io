import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../models/player_sync_state.dart';
import '../orbit_game.dart';
import '../utils/black_hole_avatar_loader.dart';
import '../utils/black_hole_renderer.dart';
import '../utils/competitor_hole_renderer.dart';
import '../utils/entity_status_mixins.dart';
import '../utils/gravity_scaling.dart';
import '../utils/world_bounds.dart';
import 'black_hole_partner.dart';

/// Remote real player rendered from Supabase Realtime broadcasts.
class EnemyPlayer extends PositionComponent
    with QuasarActivationMixin
    implements BlackHolePartner {
  EnemyPlayer({
    required this.networkId,
    required PlayerSyncState initial,
  })  : displayName = initial.displayName,
        activeSkin = initial.activeSkin,
        activeEmoji = initial.activeEmoji,
        _avatarUrl = initial.avatarUrl,
        radius = initial.radius,
        _targetPosition = Vector2(initial.x, initial.y),
        super(
          position: Vector2(initial.x, initial.y),
          anchor: Anchor.center,
          size: Vector2.all(BlackHoleRenderer.componentBoxSize(initial.radius)),
        ) {
    diamonds = initial.diamonds;
    rankPoints = initial.rankPoints;
    isShieldActive = initial.shield;
    isBoosting = initial.boost;
    isLinked = initial.link;
  }

  final String networkId;

  @override
  String displayName;

  int diamonds = 0;
  int rankPoints = 0;

  String activeSkin;
  String activeEmoji;
  double radius;

  @override
  final Vector2 velocity = Vector2.zero();

  @override
  bool isBoosting = false;

  @override
  bool isEliminated = false;

  @override
  bool get isSpawnProtected => false;

  bool isShieldActive = false;
  bool isLinked = false;

  double diskRotation = 0;
  final Vector2 _targetPosition;
  String? _avatarUrl;
  ui.Image? _avatarImage;

  static const _lerpSpeed = 14.0;

  @override
  double get holeRadius => radius;

  @override
  bool isImmuneToGravityFrom(double otherRadius) =>
      isShieldActive && otherRadius > radius;

  @override
  void growBy(double amount) => setRadius(radius + amount);

  @override
  void recordAbsorb() {}

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _refreshAvatar();
  }

  void setRadius(double value) {
    final game = findGame() as OrbitGame?;
    final cap = game?.universeVictoryRadius ?? 500.0;
    radius = value >= cap ? value : value.clamp(8.0, cap);
    size = Vector2.all(BlackHoleRenderer.componentBoxSize(radius));
  }

  void applyNetworkState(PlayerSyncState state) {
    _targetPosition.setValues(state.x, state.y);
    displayName = state.displayName;
    diamonds = state.diamonds;
    rankPoints = state.rankPoints;
    activeSkin = state.activeSkin;
    activeEmoji = state.activeEmoji;
    isShieldActive = state.shield;
    isBoosting = state.boost;
    isLinked = state.link;
    _targetRadius = state.radius;

    if (state.avatarUrl != _avatarUrl) {
      _avatarUrl = state.avatarUrl;
      _refreshAvatar();
    }
  }

  Future<void> _refreshAvatar() async {
    _avatarImage = await BlackHoleAvatarLoader.load(_avatarUrl);
  }

  double _targetRadius = 25;

  @override
  void update(double dt) {
    super.update(dt);
    if (isEliminated) return;

    tickQuasarFlash(dt);

    final t = 1 - math.exp(-dt * _lerpSpeed);
    position.lerp(_targetPosition, t);
    setRadius(radius + (_targetRadius - radius) * t);

    final game = findGame() as OrbitGame?;
    if (game != null) {
      WorldBounds.clampHoleCenter(
        position,
        radius: radius,
        worldSize: game.worldSize,
      );
    }

    final massSpin =
        math.sqrt(GravityScaling.massFromRadius(radius)).clamp(0.85, 2.35);
    diskRotation += dt * (isBoosting ? 2.4 : 1.4) * massSpin;
  }

  @override
  void render(Canvas canvas) {
    if (isEliminated) return;
    super.render(canvas);
    final game = findGame() as OrbitGame?;
    final showPortraits = SettingsService.instance.showProfilePictures;
    CompetitorHoleRenderer.paint(
      canvas: canvas,
      componentSize: size,
      game: game,
      position: position,
      radius: radius,
      diskRotation: diskRotation,
      skin: activeSkin,
      isBoosting: isBoosting,
      showShieldRing: isShieldActive,
      showLinkRing: isLinked,
      fragmentationAccent: const Color(0xFFFFAA66),
      quasarFlash: quasarFlash,
      shaderKey: this,
      displayName: displayName,
      networkId: networkId,
      rankPoints: rankPoints,
      portrait: showPortraits ? _avatarImage : null,
      portraitEmoji: showPortraits && _avatarImage == null
          ? _emojiGlyph(activeEmoji)
          : null,
    );
  }

  String _emojiGlyph(String emoteId) {
    switch (emoteId) {
      case 'emote_wave':
        return '👋';
      case 'emote_burst':
        return '💥';
      case 'emote_void':
        return '😈';
      default:
        return emoteId.isEmpty ? '' : '✨';
    }
  }
}
