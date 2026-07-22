import 'dart:async';

import '../components/bot_player.dart';
import '../components/enemy_player.dart';
import '../match_phase.dart';
import '../orbit_game.dart';
import '../session/match_placement.dart';

/// Maç zaferi, oda kapanışı ve terk edilmiş evren mantığı.
class MatchLifecycleSystem {
  MatchLifecycleSystem(this.game);

  final OrbitGame game;

  bool _universeEntitiesEvicted = false;
  bool _universeShutdownInitiated = false;

  bool get universeShutdownInitiated => _universeShutdownInitiated;

  /// Büyüme sonrası anında zafer kontrolü — tam eşik beklenmez, >= yeterlidir.
  void checkVictoryAfterGrowth() {
    if (!game.isReady || game.isMatchEnded || _universeShutdownInitiated) {
      return;
    }
    checkVictories();
  }

  void checkVictories() {
    _checkUniverseVictory();
    _checkBotVictory();
  }

  /// Gerçek oyuncu sayısı değişince (ağ / eliminasyon) terk kontrolü.
  void onRealPlayerCountChanged() {
    _checkAbandonedUniverse();
  }

  /// Bir oyuncu veya bot bitirdiğinde tüm oda kapanır.
  void handleRoomClosedByWinner(
    String winnerId,
    String winnerName,
    double elapsedSeconds,
    bool isBot, {
    int? winnerRankPoints,
  }) {
    if (game.isMatchEnded || _universeShutdownInitiated) return;

    final placement = game.matchPhase.value == MatchPhase.eliminated
        ? null
        : computeLocalPlacement(
            winnerId: winnerId,
            winnerName: winnerName,
            winnerIsBot: isBot,
          );

    closeMatchForChampion(
      championName: winnerName,
      elapsed: elapsedSeconds,
      isBot: isBot,
      placement: placement,
      championRankPoints: winnerRankPoints,
    );
    unawaited(game.leaveRoom());
  }

  /// Maç bittiğinde faz ve kazanan bilgisini doğru sırada günceller.
  void closeMatchForChampion({
    required String championName,
    required double elapsed,
    required bool isBot,
    int? placement,
    int? championRankPoints,
  }) {
    if (game.isMatchEnded) return;

    shutdownUniverseEntities();
    game.isSpectating.value = false;
    game.cameraSystem.clearSpectatorTarget();
    if (placement != null) {
      game.localPlacement = placement;
    }
    // Faz önce güncellenmeli; aksi halde champion dinleyicileri
    // frozen olmadan tetiklenir ve bitiş ekranı hiç gösterilmez.
    game.matchPhase.value = MatchPhase.frozen;

    game.remoteChampionElapsed.value = elapsed;
    game.remoteChampionName.value = championName;
    game.remoteChampionIsBot.value = isBot;
    game.remoteChampionRankPoints.value = isBot ? null : championRankPoints;
    game.hudTick.value++;
  }

  void shutdownUniverseEntities() {
    if (_universeEntitiesEvicted) return;
    _universeEntitiesEvicted = true;

    game.endHoleDrag();
    game.botPopulation.clearAll();

    for (final enemy in List<EnemyPlayer>.from(game.enemyPlayersById.values)) {
      enemy.isEliminated = true;
      enemy.removeFromParent();
    }
    game.enemyPlayersById.clear();
    game.absorbedRemoteIds.clear();
    game.confirmedDeadRemoteIds.clear();
  }

  /// Kazanan 1. sırada sabit; yerel oyuncu kalan canlılar arasında kütleye göre sıralanır.
  int? computeLocalPlacement({
    required String winnerId,
    required String winnerName,
    required bool winnerIsBot,
  }) {
    if (winnerId == game.playerId) {
      return game.player.isEliminated ? null : 1;
    }
    return MatchPlacement.localAfterWinner(
      localEliminated: game.player.isEliminated,
      localRadius: game.player.radius,
      winnerId: winnerId,
      winnerName: winnerName,
      winnerIsBot: winnerIsBot,
      bots: game.botPopulation.bots.map(
        (bot) => CompetitorStandings(
          networkId: bot.networkId,
          displayName: bot.displayName,
          radius: bot.radius,
          eliminated: bot.isEliminated,
        ),
      ),
      enemies: game.enemyPlayers.map(
        (enemy) => CompetitorStandings(
          networkId: enemy.networkId,
          displayName: enemy.displayName,
          radius: enemy.radius,
          eliminated: enemy.isEliminated,
        ),
      ),
    );
  }

  /// Gerçek oyuncu kalmadıysa (hepsi yutuldu/çıktı, sadece botlar kaldı) evreni kapat.
  void _checkAbandonedUniverse() {
    if (_universeShutdownInitiated || game.isBotOnlyRoom || game.isMatchEnded) {
      return;
    }
    if (game.roomInstanceId == null) return;
    if (game.aliveRealPlayerCount > 0) return;

    // Son insan yutuldu / tüm insanlar çıktı — oda tamamen bot. Sunucuyu kapat.
    // Yerel oyuncu zaten game-over'daysa ekranı zorla frozen'a çevirme.
    final localAlreadyOut = game.matchPhase.value == MatchPhase.eliminated;
    initiateUniverseShutdown(
      championName: nominalChampionName(),
      showFrozenOverlay: !localAlreadyOut,
      closeServer: false,
    );
    unawaited(game.leaveRoom(tryCloseIfEmpty: false));
  }

  String nominalChampionName() {
    BotPlayer? top;
    for (final bot in game.botPopulation.bots) {
      if (bot.isEliminated) continue;
      if (top == null || bot.radius > top.radius) top = bot;
    }
    return top?.displayName ?? 'Bot';
  }

  void initiateUniverseShutdown({
    required String championName,
    required bool showFrozenOverlay,
    String? broadcastWinnerId,
    bool closeServer = true,
  }) {
    if (_universeShutdownInitiated || game.isBotOnlyRoom || game.isMatchEnded) {
      return;
    }
    if (game.roomInstanceId == null) return;

    _universeShutdownInitiated = true;

    if (showFrozenOverlay) {
      closeMatchForChampion(
        championName: championName,
        elapsed: game.matchElapsed,
        isBot: true,
        placement: game.matchPhase.value == MatchPhase.eliminated ? null : 2,
      );
    } else {
      // Game-over / çıkış yolu: bot simülasyonunu durdur (sunucuda boşuna yer tutmasın).
      shutdownUniverseEntities();
    }

    game.realtime.broadcastRoomClosed(
      playerId: broadcastWinnerId ?? 'system:abandoned',
      playerName: championName,
      elapsedSeconds: game.matchElapsed,
      isBot: true,
    );
    // close_game_room üyeliği de temizler; kanal ayrılığı leaveRoom ile yapılır.
    if (closeServer) {
      game.network.closeServerRoom();
    }
    game.hudTick.value++;
  }

  void _checkUniverseVictory() {
    if (_universeShutdownInitiated ||
        game.player.isEliminated ||
        game.isFrozen) {
      return;
    }
    if (!game.hasUniverseVictory(game.player.radius)) return;

    _universeShutdownInitiated = true;
    shutdownUniverseEntities();
    game.localPlacement = 1;
    game.victoryElapsed = game.matchElapsed;
    game.matchPhase.value = MatchPhase.victory;
    game.realtime.broadcastVictory(
      playerId: game.playerId,
      playerName: game.playerName,
      elapsedSeconds: game.matchElapsed,
      rankPoints: game.playerRankPoints,
    );
    // Oda kapandı — kanaldan ayrıl (ekran zafer overlay'de kalır).
    // close, leaveRoom içinde (leave ile yarışmasın).
    unawaited(game.leaveRoom(tryCloseIfEmpty: false));
  }

  void _checkBotVictory() {
    if (_universeShutdownInitiated || game.isMatchEnded) return;

    BotPlayer? winner;
    for (final bot in game.botPopulation.bots) {
      if (!bot.isEliminated && game.hasUniverseVictory(bot.radius)) {
        winner = bot;
        break;
      }
    }
    if (winner == null) return;

    _universeShutdownInitiated = true;
    final placement = computeLocalPlacement(
      winnerId: winner.networkId,
      winnerName: winner.displayName,
      winnerIsBot: true,
    );

    closeMatchForChampion(
      championName: winner.displayName,
      elapsed: game.matchElapsed,
      isBot: true,
      placement: placement,
    );
    game.realtime.broadcastRoomClosed(
      playerId: 'bot:${winner.displayName}',
      playerName: winner.displayName,
      elapsedSeconds: game.matchElapsed,
      isBot: true,
    );
    unawaited(game.leaveRoom(tryCloseIfEmpty: false));
  }
}
