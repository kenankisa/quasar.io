import 'package:flutter/material.dart';

import '../../game/room_type.dart';
import '../wormhole_portal.dart';
import 'lobby_universe_constellation.dart';

/// Compact play-focused universe list for the redesigned lobby.
class LobbyCompactRoomList extends StatelessWidget {
  const LobbyCompactRoomList({
    super.key,
    required this.diamonds,
    required this.gamesWon,
    required this.tutorialCompleted,
    required this.portalAnimation,
    required this.onRoomSelected,
    this.trophyWinsSimple = 0,
    this.trophyWinsNormal = 0,
    this.trophyWinsElite = 0,
    this.trophyWinsUnique = 0,
    this.hardcoreCooldownUntil,
    this.hardcoreCooldownBypassed = false,
  });

  final int diamonds;
  final int gamesWon;
  final bool tutorialCompleted;
  final Animation<double> portalAnimation;
  final Future<void> Function(RoomType type, WormholePortalFocal? focal)
      onRoomSelected;
  final int trophyWinsSimple;
  final int trophyWinsNormal;
  final int trophyWinsElite;
  final int trophyWinsUnique;
  final DateTime? hardcoreCooldownUntil;
  final bool hardcoreCooldownBypassed;

  @override
  Widget build(BuildContext context) {
    return LobbyUniverseConstellation(
      diamonds: diamonds,
      gamesWon: gamesWon,
      tutorialCompleted: tutorialCompleted,
      portalAnimation: portalAnimation,
      onRoomSelected: onRoomSelected,
      trophyWinsSimple: trophyWinsSimple,
      trophyWinsNormal: trophyWinsNormal,
      trophyWinsElite: trophyWinsElite,
      trophyWinsUnique: trophyWinsUnique,
      hardcoreCooldownUntil: hardcoreCooldownUntil,
      hardcoreCooldownBypassed: hardcoreCooldownBypassed,
    );
  }
}
