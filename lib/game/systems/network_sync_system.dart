import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/realtime_room_service.dart';
import '../../services/room_matchmaking_service.dart';
import '../../services/training_presence_service.dart';
import '../components/enemy_player.dart';
import '../match_phase.dart';
import '../models/bot_sync_state.dart';
import '../models/player_sync_state.dart';
import '../orbit_game.dart';

/// Realtime oda senkronu, bot host failover ve yayın döngüsü.
class NetworkSyncSystem {
  NetworkSyncSystem(this.game);

  final OrbitGame game;

  static const _botHostSilenceSeconds = 2.0;

  bool _forceBotAuthority = false;
  double _botSnapshotAge = 0;
  double _broadcastTimer = 0;
  double _leaderRadiusSyncTimer = 0;

  bool get forceBotAuthority => _forceBotAuthority;

  Future<void> joinRealtimeRoom() async {
    if (game.isBotOnlyRoom) {
      syncRealPlayerCount();
      unawaited(TrainingPresenceService.instance.enter(game.playerId));
      return;
    }

    game.realtime.onPlayerState = handleRemoteState;
    game.realtime.onBotSnapshot = handleBotSnapshot;
    game.realtime.onPlayerLeft = handleRemoteLeft;
    game.realtime.onRemoteVictory = game.lifecycle.handleRoomClosedByWinner;
    game.realtime.onRoomClosed = game.lifecycle.handleRoomClosedByWinner;
    game.realtime.onMatchSpeech = game.handleRemoteMatchSpeech;

    await game.realtime.joinRoom(
      roomType: game.roomType,
      playerId: game.playerId,
      roomInstanceId: game.roomInstanceId,
    );
    game.botPopulation.setRealPlayerCount(game.initialRealPlayerCount);
    refreshBotHostAuthority();
    syncRealPlayerCount();
  }

  void refreshBotHostAuthority() {
    if (game.isBotOnlyRoom || !game.isReady) return;
    if (game.electedBotHostId == game.playerId) {
      _forceBotAuthority = false;
    }
    game.botPopulation.setAuthority(game.isBotHost);
  }

  void handleBotSnapshot(BotSnapshot snapshot) {
    if (game.isBotOnlyRoom ||
        game.isMatchEnded ||
        game.lifecycle.universeShutdownInitiated) {
      return;
    }
    if (snapshot.hostId.isEmpty || snapshot.hostId == game.playerId) return;

    final sorted = presentPlayerIdsSorted();
    final elected = sorted.first;
    final nextInLine = sorted.length > 1 ? sorted[1] : null;
    // Elected host, or next-in-line after silence failover.
    if (snapshot.hostId != elected && snapshot.hostId != nextInLine) return;

    _botSnapshotAge = 0;
    if (_forceBotAuthority || game.botPopulation.isAuthority) {
      _forceBotAuthority = false;
      game.botPopulation.setAuthority(false);
    }
    unawaited(game.botPopulation.applySnapshot(snapshot));
  }

  List<String> presentPlayerIdsSorted() {
    final ids = <String>{game.playerId, ...game.enemyPlayersById.keys};
    final sorted = ids.toList()..sort();
    return sorted;
  }

  void tickBotHostFailover(double dt) {
    if (game.isBotOnlyRoom ||
        game.isMatchEnded ||
        game.lifecycle.universeShutdownInitiated) {
      return;
    }
    final sorted = presentPlayerIdsSorted();
    final elected = sorted.first;

    if (elected == game.playerId) {
      if (_forceBotAuthority) {
        _forceBotAuthority = false;
      }
      if (!game.botPopulation.isAuthority) {
        game.botPopulation.setAuthority(true);
      }
      return;
    }

    _botSnapshotAge += dt;
    // Only the next-in-line may steal after silence (avoids multi-host thrash
    // when load-test sims occupy the elected id but never publish bots).
    final nextInLine = sorted.length > 1 ? sorted[1] : null;
    final mayForce = nextInLine == game.playerId;

    if (_botSnapshotAge >= _botHostSilenceSeconds && mayForce) {
      if (!_forceBotAuthority) {
        _forceBotAuthority = true;
        game.botPopulation.setAuthority(true);
      }
    } else if (_forceBotAuthority && !mayForce) {
      _forceBotAuthority = false;
      game.botPopulation.setAuthority(false);
    }
  }

  void handleRemoteState(PlayerSyncState state) {
    if (!state.alive) {
      game.confirmedDeadRemoteIds.add(state.id);
      despawnAbsorbedRemote(state.id);
      return;
    }

    if (game.absorbedRemoteIds.contains(state.id)) {
      // Lagging pre-death poses still have alive:true — ignore until we saw
      // a death broadcast, then treat the next alive pose as a revive.
      if (!game.confirmedDeadRemoteIds.contains(state.id)) return;
      game.absorbedRemoteIds.remove(state.id);
      game.confirmedDeadRemoteIds.remove(state.id);
    }

    final existing = game.enemyPlayersById[state.id];
    if (existing != null) {
      existing.applyNetworkState(state);
      return;
    }

    final enemy = EnemyPlayer(networkId: state.id, initial: state);
    game.enemyPlayersById[state.id] = enemy;
    game.world.add(enemy);
    refreshBotHostAuthority();
    syncRealPlayerCount();
  }

  void handleRemoteLeft(String id) {
    game.absorbedRemoteIds.remove(id);
    game.confirmedDeadRemoteIds.remove(id);
    final enemy = game.enemyPlayersById.remove(id);
    enemy?.removeFromParent();
    refreshBotHostAuthority();
    syncRealPlayerCount();
  }

  void onRemotePlayerEliminated(EnemyPlayer enemy) {
    despawnAbsorbedRemote(enemy.networkId);
  }

  void despawnAbsorbedRemote(String networkId) {
    if (networkId.isEmpty) return;
    game.absorbedRemoteIds.add(networkId);
    final enemy = game.enemyPlayersById.remove(networkId);
    if (enemy == null) return;
    enemy.isEliminated = true;
    enemy.removeFromParent();
    refreshBotHostAuthority();
    syncRealPlayerCount();
  }

  void syncRealPlayerCount() {
    final aliveLocal = game.player.isEliminated ? 0 : 1;
    final remoteCount = game.isBotOnlyRoom
        ? 0
        : game.enemyPlayersById.values
            .where((enemy) => !enemy.isEliminated)
            .length;
    game.botPopulation.setRealPlayerCount(aliveLocal + remoteCount);
    game.lifecycle.onRealPlayerCountChanged();
  }

  PlayerSyncState buildSyncState({bool? alive}) {
    return PlayerSyncState(
      id: game.playerId,
      displayName: game.playerName,
      x: game.player.position.x,
      y: game.player.position.y,
      radius: game.player.radius,
      activeSkin: game.activeSkin,
      activeEmoji: '',
      avatarUrl: game.avatarUrl,
      shield: game.player.isShieldActive || game.player.isSpawnProtected,
      boost: game.player.isBoosting,
      link: game.tacticalManager.isLinked,
      diamonds: game.playerDiamonds,
      rankPoints: game.playerRankPoints,
      alive: alive ?? !game.player.isEliminated,
    );
  }

  void tickBroadcast(double dt) {
    // Keep bot host publishing while spectating (eliminated ≠ match over).
    if (game.isBotOnlyRoom ||
        game.isMatchEnded ||
        game.lifecycle.universeShutdownInitiated) {
      return;
    }
    final phase = game.matchPhase.value;
    if (phase != MatchPhase.playing && phase != MatchPhase.eliminated) return;

    tickBotHostFailover(dt);
    _broadcastTimer += dt;
    if (_broadcastTimer < RealtimeRoomService.broadcastMinInterval) return;
    _broadcastTimer = 0;
    if (!game.player.isEliminated) {
      game.realtime.broadcastState(buildSyncState());
    }
    if (game.isBotHost && game.botPopulation.isAuthority) {
      game.realtime.broadcastBotSnapshot(
        game.botPopulation.buildSnapshot(game.playerId),
      );
    }
  }

  double currentRoomLeaderRadius() {
    var maxRadius = game.player.isEliminated ? 0.0 : game.player.radius;
    for (final bot in game.botPopulation.bots) {
      if (!bot.isEliminated) {
        maxRadius = math.max(maxRadius, bot.radius);
      }
    }
    for (final enemy in game.enemyPlayers) {
      if (!enemy.isEliminated) {
        maxRadius = math.max(maxRadius, enemy.radius);
      }
    }
    return maxRadius;
  }

  void tickLeaderRadiusSync(double dt) {
    final instanceId = game.roomInstanceId;
    if (instanceId == null || game.isBotOnlyRoom || game.isFrozen) return;

    _leaderRadiusSyncTimer += dt;
    if (_leaderRadiusSyncTimer < 5) return;
    _leaderRadiusSyncTimer = 0;

    final leaderRadius = currentRoomLeaderRadius().round();
    unawaited(
      RoomMatchmakingService.instance.updateLeaderRadius(
        instanceId,
        leaderRadius,
      ),
    );
  }

  void closeServerRoom() {
    final instanceId = game.roomInstanceId;
    if (instanceId == null) return;
    // close_game_room zafer eşiği için güncel leader_radius ister — son sync.
    final leaderRadius = currentRoomLeaderRadius().round();
    unawaited(() async {
      await RoomMatchmakingService.instance.updateLeaderRadius(
        instanceId,
        leaderRadius,
      );
      await RoomMatchmakingService.instance.closeRoom(instanceId);
    }());
  }

  Future<void> detachRealtimeAndMembership({bool preferClose = false}) async {
    final instanceId = game.roomInstanceId;
    try {
      await game.realtime.leaveRoom().timeout(const Duration(seconds: 3));
    } catch (e, st) {
      debugPrint('realtime leaveRoom: $e\n$st');
    }
    if (game.isBotOnlyRoom) {
      try {
        await TrainingPresenceService.instance
            .leave()
            .timeout(const Duration(seconds: 3));
      } catch (e, st) {
        debugPrint('training leave: $e\n$st');
      }
    }
    if (instanceId == null) return;

    // close + leave aynı anda FOR UPDATE kilidinde takılabiliyor.
    if (preferClose || game.lifecycle.universeShutdownInitiated) {
      try {
        await RoomMatchmakingService.instance
            .closeRoom(instanceId)
            .timeout(const Duration(seconds: 4));
      } catch (e, st) {
        debugPrint('closeRoom during detach: $e\n$st');
        try {
          await RoomMatchmakingService.instance
              .leaveRoom(instanceId)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    } else {
      try {
        await RoomMatchmakingService.instance
            .leaveRoom(instanceId)
            .timeout(const Duration(seconds: 4));
      } catch (e, st) {
        debugPrint('leave_game_room: $e\n$st');
      }
    }
  }

  /// leaveRoom orkestrasyonu — ağ + son oyuncu kapanışı.
  Future<void> leaveRoom({bool tryCloseIfEmpty = true}) async {
    final instanceId = game.roomInstanceId;

    // Son (veya tek) gerçek oyuncu çıkıyorsa evreni kapat — sadece bot kalmasın.
    var closingAsLast = false;
    if (tryCloseIfEmpty &&
        instanceId != null &&
        !game.isBotOnlyRoom &&
        !game.lifecycle.universeShutdownInitiated &&
        game.aliveRealPlayerCount <= 1) {
      closingAsLast = true;
      game.lifecycle.initiateUniverseShutdown(
        championName: game.lifecycle.nominalChampionName(),
        showFrozenOverlay: false,
        broadcastWinnerId: game.playerId,
        closeServer: false,
      );
    }

    await detachRealtimeAndMembership(
      preferClose: closingAsLast || game.lifecycle.universeShutdownInitiated,
    );
  }
}
