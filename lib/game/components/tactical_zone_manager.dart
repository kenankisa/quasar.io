import 'dart:math' as math;

import 'package:flame/components.dart';

import '../orbit_game.dart';
import '../utils/gravity_motion.dart';
import '../utils/gravity_scaling.dart';
import 'asteroid.dart';
import 'binary_link_bond.dart';
import 'black_hole_partner.dart';
import 'bot_player.dart';
import 'planet.dart';
import 'player.dart';
import 'quasar_fragment.dart';

class TacticalZoneManager extends Component with HasGameReference<OrbitGame> {
  static const minLinkRadius = 50.0;
  static const maxLinkRadius = 150.0;
  static const linkProximityMultiplier = 3.2;
  static const maxLinkDistanceMultiplier = 5.5;

  BlackHolePartner? linkCandidate;
  BlackHolePartner? linkedPartner;
  BinaryLinkBond? _activeBond;

  bool get isLinked => linkedPartner != null;
  bool get canShowLinkButton => linkCandidate != null && !isLinked;
  BlackHolePartner? get activeLinkPartner => linkedPartner;

  Vector2? get linkMidpoint {
    if (!isLinked || linkedPartner == null) return null;
    return (game.player.position + linkedPartner!.position) / 2;
  }

  List<BotPlayer> get bots => game.botPopulation.bots;

  @override
  void update(double dt) {
    super.update(dt);
    for (final bot in bots) {
      if (!bot.isEliminated) {
        bot.updateBot(dt, game);
      }
    }

    _updateLinkCandidate();
    if (isLinked) {
      _enforceLinkDistance();
    }
  }

  void _updateLinkCandidate() {
    if (isLinked) {
      linkCandidate = null;
      return;
    }

    final player = game.player;
    if (player.radius < minLinkRadius || player.radius > maxLinkRadius) {
      linkCandidate = null;
      return;
    }

    BlackHolePartner? nearest;
    var nearestDist = double.infinity;

    for (final bot in bots) {
      if (bot.isEliminated) continue;
      if (bot.radius < minLinkRadius || bot.radius > maxLinkRadius) continue;
      final dist = player.position.distanceTo(bot.position);
      final threshold = (player.radius + bot.radius) * linkProximityMultiplier;
      if (dist < threshold && dist < nearestDist) {
        nearest = bot;
        nearestDist = dist;
      }
    }

    linkCandidate = nearest;
  }

  void activateLink() {
    if (linkCandidate == null || isLinked) return;
    linkedPartner = linkCandidate;
    linkCandidate = null;
    _activeBond = BinaryLinkBond(
      partnerA: game.player,
      partnerB: linkedPartner!,
    );
    game.world.add(_activeBond!);
  }

  void breakLink() {
    _activeBond?.removeFromParent();
    _activeBond = null;
    linkedPartner = null;
  }

  void _enforceLinkDistance() {
    if (linkedPartner == null) return;
    final dist = game.player.position.distanceTo(linkedPartner!.position);
    final maxDist =
        (game.player.radius + linkedPartner!.holeRadius) * maxLinkDistanceMultiplier;
    if (dist > maxDist) {
      breakLink();
    }
  }

  void applyLinkedGravityPull(
    PositionComponent entity,
    double dt, {
    required double roomMultiplier,
  }) {
    if (!isLinked || linkedPartner == null) return;

    final velocity = _consumableVelocity(entity);
    if (velocity == null) return;

    final mid = linkMidpoint;
    if (mid == null) return;

    // Combined mass of the binary link: M ∝ r₁³ + r₂³
    final r1 = game.player.radius;
    final r2 = linkedPartner!.holeRadius;
    final combinedMass = GravityScaling.massFromRadius(r1) +
        GravityScaling.massFromRadius(r2);
    final equivRadius =
        Player.baseRadius * math.pow(combinedMass, 1 / 3).toDouble();

    final entityRadius = _consumableRadius(entity);
    if (entityRadius == null) return;

    GravityMotion.accelerateToward(
      entityPosition: entity.position,
      entityVelocity: velocity,
      sourcePosition: mid,
      sourceRadius: equivRadius,
      entityRadius: entityRadius,
      dt: dt,
      roomMultiplier: roomMultiplier,
      bonusMultiplier: 2.2,
      capInfluence: false,
    );
  }

  Vector2? _consumableVelocity(PositionComponent entity) {
    if (entity is Asteroid) return entity.velocity;
    if (entity is Planet) return entity.velocity;
    if (entity is QuasarFragment) return entity.velocity;
    return null;
  }

  double? _consumableRadius(PositionComponent entity) {
    if (entity is Asteroid) return entity.collisionRadius;
    if (entity is Planet) return entity.collisionRadius;
    if (entity is QuasarFragment) return entity.collisionRadius;
    return null;
  }
}
