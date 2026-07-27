import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/profile_service.dart';
import '../../services/room_matchmaking_service.dart';
import '../config/hardcore_rules.dart';
import '../orbit_game.dart';
import '../room_type.dart';

/// Live Hardcore arena rules — passive softcap, active victory gate, economy RPCs.
class HardcoreArenaSystem {
  HardcoreArenaSystem(this.game);

  final OrbitGame game;

  bool get isHardcore => game.roomType == RoomType.hardcore;

  bool? _arenaActive;
  DateTime? _passivePhaseAtUtc;
  double? _passiveAnchorRadius;

  /// Prefer DB seat count when fresh; else count alive remotes + local.
  int get aliveCount {
    if (!isHardcore) return game.aliveRealPlayerCount;
    final hint = HardcoreArenaAliveHint.populationHint;
    if (hint != null) return hint;
    return game.aliveRealPlayerCount;
  }

  int get minAlive => HardcoreRules.liveVictoryMinAlive;

  bool get isArenaActive => aliveCount >= minAlive;

  bool get _arenaHudReady => game.isReady;

  /// HUD: low-pop cap applies while arena is passive.
  String? get victoryBlockKey {
    if (!_arenaHudReady || !isHardcore || game.player.isEliminated) {
      return null;
    }
    if (game.player.radius >= game.universeVictoryRadius - 1 && !isArenaActive) {
      return 'hardcore_gate_low_pop_cap';
    }
    return null;
  }

  bool get canClaimVictory =>
      _arenaHudReady &&
      isHardcore &&
      isArenaActive &&
      !game.player.isEliminated;

  double foodGrowthMultiplier() {
    if (!isHardcore) return 1.0;
    var mult = HardcoreRules.foodGrowthMultiplierForAlive(aliveCount);
    if (!_arenaHudReady) return mult;
    if (game.player.radius >= HardcoreRules.liveLateFoodSoftcapRadius) {
      mult *= HardcoreRules.liveLateFoodSoftcapMultiplier;
    }
    if (!isArenaActive && game.player.radius > HardcoreRules.liveLowPopRadiusCap - 40) {
      mult *= 0.28;
    }
    return mult;
  }

  void tick(double dt) {
    if (!_arenaHudReady ||
        !isHardcore ||
        game.isMatchEnded ||
        game.player.isEliminated) {
      return;
    }
    _tickPhaseFlip();
    _tickLowPopSoftcap(dt);
  }

  double clampGrowth(double radius) {
    if (!isHardcore || isArenaActive) return radius;
    return math.min(radius, HardcoreRules.liveLowPopRadiusCap);
  }

  void onLocalAbsorbedRealPlayer(String preyUserId) {
    if (!isHardcore || preyUserId.isEmpty || preyUserId == game.playerId) {
      return;
    }
    game.realtime.broadcastHardcoreElim(preyId: preyUserId);
    unawaited(_applyKillReward(preyUserId));
  }

  void onRemoteElim(String preyId) {
    if (!isHardcore || preyId.isEmpty) return;
    game.network.despawnAbsorbedRemote(preyId);
  }

  void applyArenaPhase({
    required bool active,
    String? phaseAtUtc,
    String? anchorPlayerId,
    double? anchorRadius,
  }) {
    if (!isHardcore) return;
    if (active) {
      _passivePhaseAtUtc = null;
      _passiveAnchorRadius = null;
      _arenaActive = true;
      game.hudTick.value++;
      return;
    }

    _arenaActive = false;
    final at = phaseAtUtc != null ? DateTime.tryParse(phaseAtUtc) : null;
    _passivePhaseAtUtc = at ?? DateTime.now().toUtc();

    if (anchorPlayerId == game.playerId &&
        anchorRadius != null &&
        anchorRadius > 0) {
      _passiveAnchorRadius = anchorRadius;
    } else if (anchorRadius != null && anchorRadius > 0) {
      _passiveAnchorRadius = anchorRadius;
    }

    _alignPassiveDrain();
    game.hudTick.value++;
  }

  Future<void> syncLeaderRadiusForVictory() async {
    if (!isHardcore) return;
    final roomId = game.roomInstanceId;
    if (roomId == null) return;
    final target = math.max(
      game.maxRadiusReached.round(),
      game.universeVictoryRadius.round(),
    );
    try {
      await RoomMatchmakingService.instance.updateLeaderRadius(
        roomId,
        target,
        selfRadius: game.player.radius.round(),
      );
    } catch (e) {
      debugPrint('hardcore victory leader sync: $e');
    }
  }

  void _tickPhaseFlip() {
    final active = isArenaActive;
    final prev = _arenaActive;
    if (prev != null && prev == active) return;
    _arenaActive = active;

    if (!_isPhaseBroadcaster) {
      game.hudTick.value++;
      return;
    }

    if (active) {
      game.realtime.broadcastHardcoreArenaPhase(active: true);
    } else {
      game.realtime.broadcastHardcoreArenaPhase(
        active: false,
        anchorPlayerId: game.playerId,
        anchorRadius: game.player.radius,
      );
      _passivePhaseAtUtc = DateTime.now().toUtc();
      _passiveAnchorRadius = game.player.radius;
      _alignPassiveDrain();
    }
    game.hudTick.value++;
  }

  bool get _isPhaseBroadcaster {
    if (game.isBotOnlyRoom || game.roomInstanceId == null) return false;
    final ids = <String>{game.playerId, ...game.enemyPlayersById.keys};
    final sorted = ids.toList()..sort();
    return sorted.isNotEmpty && sorted.first == game.playerId;
  }

  void _tickLowPopSoftcap(double dt) {
    if (isArenaActive || dt <= 0) return;
    final soft = HardcoreRules.liveLowPopRadiusCap;
    var r = game.player.radius;
    if (r <= soft) return;
    r = HardcoreLowPopDrain.drainStep(r, soft, dt);
    if ((game.player.radius - r).abs() > 0.01) {
      game.player.setRadius(r);
    }
  }

  void _alignPassiveDrain() {
    final at = _passivePhaseAtUtc;
    if (at == null || isArenaActive) return;
    final anchor = _passiveAnchorRadius ?? game.player.radius;
    final elapsed =
        DateTime.now().toUtc().difference(at).inMilliseconds / 1000.0;
    if (elapsed <= 0) return;
    final soft = HardcoreRules.liveLowPopRadiusCap;
    final r = HardcoreLowPopDrain.radiusAfterElapsed(anchor, elapsed, soft);
    if (r < game.player.radius - 0.5) {
      game.player.setRadius(r);
    }
  }

  Future<void> _applyKillReward(String preyUserId) async {
    final roomId = game.roomInstanceId;
    if (roomId == null || !isArenaActive) return;
    try {
      await ProfileService.instance.applyHardcoreKillReward(
        roomInstanceId: roomId,
        preyUserId: preyUserId,
        aliveCount: aliveCount,
      );
    } catch (e) {
      debugPrint('applyHardcoreKillReward: $e');
    }
    try {
      await RoomMatchmakingService.instance.hardcoreReleaseMember(
        roomInstanceId: roomId,
        userId: preyUserId,
      );
    } catch (e) {
      debugPrint('hardcore_release_member prey: $e');
    }
  }
}