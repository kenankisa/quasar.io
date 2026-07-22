import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/config/first_match_tuning.dart';
import '../game/config/skill_tree_config.dart';
import '../game/match_phase.dart';
import '../game/models/room_instance.dart';
import '../game/orbit_game.dart';
import '../game/models/room_leaderboard.dart';
import '../services/analytics_play_tracker.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/lang_service.dart';
import '../services/player_session_service.dart';
import '../utils/app_lifecycle.dart';
import '../utils/display_frame_rate.dart';
import '../utils/player_name.dart';
import '../utils/responsive_layout.dart';
import '../widgets/cosmic_event_overlay.dart';
import '../widgets/match_comms_overlay.dart';
import '../widgets/first_match_hint_overlay.dart';
import '../widgets/game_hud_overlay.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/link_button.dart';
import '../widgets/spawn_protection_overlay.dart';
import '../widgets/spectator_overlay.dart';
import '../widgets/victory_overlay.dart';
import 'room_type.dart';

export 'room_type.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.roomType,
    this.roomInstance,
    this.onReady,
  });

  final RoomType roomType;
  final RoomInstance? roomInstance;

  /// Fired once the match world is mounted (lobby wormhole can finish diving).
  final VoidCallback? onReady;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  OrbitGame? _game;
  bool _matchResultSaved = false;
  bool _isLeaving = false;
  bool _readyNotified = false;
  bool _showQuitConfirm = false;
  bool _quitConfirmPausedGame = false;
  Completer<bool>? _quitConfirmCompleter;
  int _gamesWonAtStart = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final game = _game;
    if (game == null) return;
    if (AppLifecycle.shouldPause(state)) {
      if (!game.paused) game.pauseEngine();
      // Web sekme kapatma / uygulama öldürme — koltuğu hemen bırak.
      if (state == AppLifecycleState.detached) {
        unawaited(game.leaveRoom());
      }
    } else if (game.paused) {
      game.resumeEngine();
    }
  }

  Future<void> _initGame() async {
    // Prefer cached lobby profile so match never waits on a hung network call.
    var profile = ProfileService.instance.profileNotifier.value;
    try {
      profile ??= await ProfileService.instance.fetchProfile();
    } catch (e, stackTrace) {
      debugPrint('GameScreen profile: $e\n$stackTrace');
    }
    if (!mounted) return;

    _gamesWonAtStart = profile?.gamesWon ?? 0;
    final game = OrbitGame(
      roomType: widget.roomType,
      playerId: profile?.id ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
      avatarUrl: profile?.avatarUrl,
      activeSkin: profile?.activeSkin ?? 'default',
      playerName: clampPlayerName(profile?.username ?? 'You'),
      playerDiamonds: profile?.diamonds ?? 0,
      playerRankPoints: profile?.rankPoints ?? 0,
      gamesWonAtStart: _gamesWonAtStart,
      tutorialCompletedAtStart: profile?.tutorialCompleted ?? false,
      roomInstance: widget.roomInstance,
      abilityLoadout: profile?.abilityLoadout ?? AbilityLoadout.base,
    );
    game.matchPhase.addListener(_onMatchPhaseChanged);
    unawaited(DisplayFrameRate.applyGameplayCap());
    PlayerSessionService.instance.attachMatchIdleHooks(
      MatchIdleHooks(
        massProvider: () => game.player.radius,
        onMassDrain: (amount) {
          if (game.player.isEliminated) return;
          if (game.matchPhase.value != MatchPhase.playing) return;
          game.player.growBy(-amount);
        },
        onAfkEliminated: () => _handleMatchAfkElimination(game),
        isResultScreen: () {
          final phase = game.matchPhase.value;
          return phase == MatchPhase.victory || phase == MatchPhase.frozen;
        },
        onResultIdleLeave: () => _quitToLobby(skipConfirm: true),
      ),
    );
    setState(() => _game = game);
    _notifyReadySoon();
  }

  Future<void> _handleMatchAfkElimination(OrbitGame game) async {
    if (_isLeaving) return;
    _isLeaving = true;

    try {
      if (game.matchPhase.value == MatchPhase.playing &&
          !game.player.isEliminated) {
        game.eliminateLocalPlayerForAfk();
      }

      if (!_matchResultSaved) {
        try {
          await _applyMatchResultAsync(eliminated: true)
              .timeout(const Duration(seconds: 4));
        } catch (e, st) {
          debugPrint('AFK eliminate penalty: $e\n$st');
        }
      }

      try {
        await game.leaveRoom().timeout(const Duration(seconds: 5));
      } catch (e, st) {
        debugPrint('AFK leaveRoom: $e\n$st');
      }
    } finally {
      // Oturum kapatma PlayerSessionService tarafında yapılır.
    }
  }

  void _notifyReadySoon() {
    if (_readyNotified) return;
    // Let Flame mount a frame under the lobby wormhole, then unveil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _readyNotified) return;
        _readyNotified = true;
        widget.onReady?.call();
      });
    });
  }

  void _onMatchPhaseChanged() {
    final game = _game;
    if (game == null) return;

    final phase = game.matchPhase.value;
    if (phase == MatchPhase.victory || phase == MatchPhase.frozen) {
      // Sonuç ekranı idle sayacı sıfırdan başlasın (önceki AFK taşımasın).
      PlayerSessionService.instance.noteActivity();
    }

    if (_matchResultSaved) return;

    if (phase == MatchPhase.victory) {
      _applyMatchResult(placement: 1);
      return;
    }
    if (phase == MatchPhase.frozen) {
      final placement = game.localPlacement;
      if (placement == null) return;
      final reward = widget.roomType.diamondRewardForPlacement(placement);
      if (reward > 0) {
        _applyMatchResult(placement: placement);
      } else {
        // Ödül yok ama sonucu işlenmiş say (çift kayıt olmasın).
        _matchResultSaved = true;
      }
    }
  }

  Future<bool>? _matchResultInFlight;

  void _applyMatchResult({int? placement, bool eliminated = false}) {
    unawaited(_applyMatchResultAsync(
      placement: placement,
      eliminated: eliminated,
    ));
  }

  Future<bool> _applyMatchResultAsync({
    int? placement,
    bool eliminated = false,
  }) async {
    if (_matchResultSaved) return true;
    if (_matchResultInFlight != null) return _matchResultInFlight!;

    final future = () async {
      _matchResultSaved = true;
      try {
        final profile = await ProfileService.instance.applyMatchResult(
          roomType: widget.roomType,
          placement: placement,
          eliminated: eliminated,
          roomInstanceId: widget.roomInstance?.id,
        );
        // Ödül/ceza işlendikten sonra oturumu kapat — sonraki maç yeni
        // play_session açabilsin (already_claimed / cooldown çakışmasın).
        if (profile != null) {
          unawaited(
            AnalyticsPlayTracker.instance.end(roomType: widget.roomType),
          );
        }
        return true;
      } catch (e, st) {
        debugPrint('applyMatchResult: $e\n$st');
        _matchResultSaved = false;
        return false;
      }
    }();

    _matchResultInFlight = future;
    final ok = await future;
    if (!ok) {
      _matchResultInFlight = null;
    }
    return ok;
  }

  /// 2× reklam öncesi base ödül claim'inin sunucuda bittiğinden emin ol.
  Future<bool> _ensureMatchRewardClaimed({required int placement}) {
    return _applyMatchResultAsync(placement: placement);
  }

  Future<PlayerProfile?> _claimRewardedMatchDouble(String sessionId) {
    final roomId = widget.roomInstance?.id;
    if (roomId == null ||
        widget.roomType == RoomType.simple ||
        sessionId.isEmpty) {
      return Future<PlayerProfile?>.value(null);
    }
    return ProfileService.instance.claimRewardedMatchDouble(
      roomType: widget.roomType,
      roomInstanceId: roomId,
      sessionId: sessionId,
    );
  }

  Future<bool> _attestRewardedMatchDouble(String sessionId) {
    final roomId = widget.roomInstance?.id;
    if (roomId == null ||
        widget.roomType == RoomType.simple ||
        sessionId.isEmpty) {
      return Future<bool>.value(false);
    }
    return ProfileService.instance.waitForRewardedMatchDoubleAttest(
      roomType: widget.roomType,
      roomInstanceId: roomId,
      sessionId: sessionId,
    );
  }

  Future<String?> _prepareRewardedMatchDouble() {
    final roomId = widget.roomInstance?.id;
    if (roomId == null || widget.roomType == RoomType.simple) {
      return Future<String?>.value(null);
    }
    return ProfileService.instance.prepareRewardedMatchDouble(
      roomType: widget.roomType,
      roomInstanceId: roomId,
    );
  }

  bool get _canOfferRewardDouble {
    if (widget.roomType == RoomType.simple) return false;
    if (widget.roomInstance?.id == null) return false;
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PlayerSessionService.instance.detachMatchIdleHooks();
    _game?.matchPhase.removeListener(_onMatchPhaseChanged);
    final pending = _quitConfirmCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete(false);
    }
    _quitConfirmCompleter = null;
    final game = _game;
    if (game != null && !_isLeaving) {
      unawaited(game.leaveRoom());
    }
    super.dispose();
  }

  int get _eliminationPenalty => FirstMatchTuning.eliminationPenalty(
        roomType: widget.roomType,
        gamesWon: _gamesWonAtStart,
      );

  /// Lobide yazılan yutulma cezası — uyarıda da aynı rakam gösterilir.
  int get _roomEliminationPenalty =>
      widget.roomType.eliminationDiamondPenalty;

  bool _shouldConfirmQuit(OrbitGame game) {
    if (_matchResultSaved || _isLeaving) return false;
    // Eğitim evreninde elmas cezası yok.
    if (_roomEliminationPenalty <= 0) return false;

    final phase = game.matchPhase.value;
    if (phase == MatchPhase.victory || phase == MatchPhase.frozen) {
      return false;
    }
    // Game over ekranı cezayı zaten gösteriyor.
    if (phase == MatchPhase.eliminated && !game.isSpectating.value) {
      return false;
    }
    return phase == MatchPhase.playing ||
        (phase == MatchPhase.eliminated && game.isSpectating.value);
  }

  void _resolveQuitConfirm(bool leave) {
    final completer = _quitConfirmCompleter;
    if (completer == null || completer.isCompleted) return;
    if (mounted && _showQuitConfirm) {
      setState(() => _showQuitConfirm = false);
    } else {
      _showQuitConfirm = false;
    }
    completer.complete(leave);
    _quitConfirmCompleter = null;

    final game = _game;
    if (_quitConfirmPausedGame &&
        game != null &&
        game.paused &&
        mounted &&
        !_isLeaving &&
        !leave) {
      game.resumeEngine();
    }
    _quitConfirmPausedGame = false;
  }

  Future<bool> _showQuitConfirmOverlay() async {
    if (_showQuitConfirm) {
      return _quitConfirmCompleter?.future ?? Future.value(false);
    }

    final game = _game;
    _quitConfirmPausedGame = false;
    if (game != null && !game.paused) {
      game.pauseEngine();
      _quitConfirmPausedGame = true;
    }

    final completer = Completer<bool>();
    _quitConfirmCompleter = completer;
    if (mounted) {
      setState(() => _showQuitConfirm = true);
    } else {
      _showQuitConfirm = true;
    }

    return completer.future;
  }

  Future<void> _quitToLobby({bool skipConfirm = false}) async {
    if (_isLeaving || !mounted) return;

    final game = _game;
    if (!skipConfirm && game != null && _shouldConfirmQuit(game)) {
      final confirmed = await _showQuitConfirmOverlay();
      if (!confirmed || !mounted || _isLeaving) return;
    }

    _isLeaving = true;
    _showQuitConfirm = false;
    _quitConfirmCompleter = null;

    // Onay sırasında pause edilmiş olabilir — çıkışta kilitli kalmasın.
    if (_quitConfirmPausedGame && game != null && game.paused) {
      try {
        game.resumeEngine();
      } catch (_) {}
    }
    _quitConfirmPausedGame = false;

    final maxMass = game?.maxRadiusReached ?? 0;
    final roomType = widget.roomType.name;

    try {
      // Ceza başarısız olsa bile çıkışa izin ver (match_too_short / ağ).
      if (game != null && !_matchResultSaved) {
        final phase = game.matchPhase.value;
        if (phase == MatchPhase.playing || phase == MatchPhase.eliminated) {
          if (_eliminationPenalty > 0) {
            try {
              await _applyMatchResultAsync(eliminated: true)
                  .timeout(const Duration(seconds: 4));
            } catch (e, st) {
              debugPrint('quit penalty skipped: $e\n$st');
            }
          } else {
            _matchResultSaved = true;
          }
        }
      }

      if (game != null) {
        try {
          await game.leaveRoom().timeout(const Duration(seconds: 5));
        } catch (e, st) {
          debugPrint('leaveRoom on quit: $e\n$st');
        }
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    unawaited(
      ProfileService.instance
          .saveLeaderboardScore(maxMass: maxMass, roomType: roomType)
          .catchError((Object e, StackTrace st) {
        debugPrint('saveLeaderboardScore: $e\n$st');
      }),
    );
  }

  Future<void> _leaveMatchViaBack() async {
    await _quitToLobby();
  }

  Future<void> _handleVictoryContinue() async {
    if (_isLeaving || !mounted) return;
    _isLeaving = true;

    final game = _game;
    final roomType = widget.roomType.name;
    final maxMass = game?.maxRadiusReached ?? 0;

    Navigator.of(context).pop();

    if (game == null) return;

    unawaited(
      ProfileService.instance
          .saveLeaderboardScore(maxMass: maxMass, roomType: roomType)
          .catchError((Object e, StackTrace st) {
        debugPrint('saveLeaderboardScore: $e\n$st');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showQuitConfirm) {
          _resolveQuitConfirm(false);
          return;
        }
        unawaited(_leaveMatchViaBack());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: game == null
            // Covered by lobby wormhole transit — keep blank, no second graphic.
            ? const ColoredBox(color: Color(0xFF020208))
            : Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: GameWidget(
                      key: ValueKey(game.playerId),
                      game: game,
                      loadingBuilder: (context) =>
                          const ColoredBox(color: Color(0xFF020208)),
                      errorBuilder: (context, error) {
                        debugPrint('GameWidget error: $error');
                        return ColoredBox(
                          color: const Color(0xFF020208),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '$error',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _GameOverlayLayer(game: game, onQuit: _quitToLobby),
                  ValueListenableBuilder<MatchPhase>(
                    valueListenable: game.matchPhase,
                    builder: (context, phase, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: game.isSpectating,
                        builder: (context, spectating, _) {
                          if (phase == MatchPhase.eliminated && !spectating) {
                            return GameOverOverlay(
                              game: game,
                              onQuit: () => _quitToLobby(skipConfirm: true),
                              onWatch: () {
                                game.startSpectating();
                                setState(() {});
                              },
                              diamondPenalty: _eliminationPenalty,
                            );
                          }
                          if (phase == MatchPhase.victory) {
                            return VictoryOverlay(
                              roomType: widget.roomType,
                              diamondReward:
                                  widget.roomType.diamondRewardForPlacement(1),
                              victoryElapsed:
                                  game.victoryElapsed ?? game.matchElapsed,
                              onContinue: _handleVictoryContinue,
                              ensureBaseClaimed: _canOfferRewardDouble
                                  ? () => _ensureMatchRewardClaimed(
                                        placement: 1,
                                      )
                                  : null,
                              prepareSession: _canOfferRewardDouble
                                  ? _prepareRewardedMatchDouble
                                  : null,
                              attestSession: _canOfferRewardDouble
                                  ? _attestRewardedMatchDouble
                                  : null,
                              claimDouble: _canOfferRewardDouble
                                  ? _claimRewardedMatchDouble
                                  : null,
                              ssvUserId: AuthService.instance.currentUser?.id,
                            );
                          }
                          if (spectating) {
                            return SpectatorOverlay(
                              game: game,
                              onQuit: _quitToLobby,
                              onStopWatching: () {
                                game.stopSpectating();
                                setState(() {});
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      game.matchPhase,
                      game.remoteChampionName,
                      game.remoteChampionElapsed,
                      game.remoteChampionIsBot,
                      game.remoteChampionRankPoints,
                    ]),
                    builder: (context, _) {
                      final championName = game.remoteChampionName.value;
                      if (championName == null ||
                          game.matchPhase.value != MatchPhase.frozen) {
                        return const SizedBox.shrink();
                      }
                      final placement = game.localPlacement;
                      final reward = placement == null
                          ? 0
                          : widget.roomType.diamondRewardForPlacement(placement);
                      return FrozenChampionOverlay(
                        championName: championName,
                        championElapsed: game.remoteChampionElapsed.value ?? 0,
                        isBot: game.remoteChampionIsBot.value,
                        championRankPoints: game.remoteChampionRankPoints.value,
                        placement: placement,
                        diamondReward: reward,
                        onLeave: () => _quitToLobby(skipConfirm: true),
                        showDoubleReward:
                            _canOfferRewardDouble && reward > 0,
                        ensureBaseClaimed:
                            _canOfferRewardDouble &&
                                reward > 0 &&
                                placement != null
                            ? () => _ensureMatchRewardClaimed(
                                  placement: placement,
                                )
                            : null,
                        prepareSession: _canOfferRewardDouble && reward > 0
                            ? _prepareRewardedMatchDouble
                            : null,
                        attestSession: _canOfferRewardDouble && reward > 0
                            ? _attestRewardedMatchDouble
                            : null,
                        claimDouble: _canOfferRewardDouble && reward > 0
                            ? _claimRewardedMatchDouble
                            : null,
                        ssvUserId: AuthService.instance.currentUser?.id,
                      );
                    },
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _LeaderboardStrip(
                      game: game,
                      onBack: () {
                        unawaited(_leaveMatchViaBack());
                      },
                    ),
                  ),
                  if (_showQuitConfirm)
                    _MatchQuitConfirmOverlay(
                      diamondPenalty: _eliminationPenalty,
                      onStay: () => _resolveQuitConfirm(false),
                      onLeave: () => _resolveQuitConfirm(true),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Flame GameWidget üstünde kalması için [showDialog] yerine in-stack onay.
class _MatchQuitConfirmOverlay extends StatelessWidget {
  const _MatchQuitConfirmOverlay({
    required this.diamondPenalty,
    required this.onStay,
    required this.onLeave,
  });

  final int diamondPenalty;
  final VoidCallback onStay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF0A0A1A),
              border: Border.all(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.14),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.t('match_quit_confirm_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF00F0FF),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (diamondPenalty > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    lang
                        .t('match_quit_confirm_message')
                        .replaceAll('{diamonds}', '$diamondPenalty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onStay,
                        child: Text(
                          lang.t('match_quit_confirm_stay'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onLeave,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF00AA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(lang.t('match_quit_confirm_leave')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top leaderboard strip — listens to [OrbitGame.hudTick] internally.
class _LeaderboardStrip extends StatelessWidget {
  const _LeaderboardStrip({
    required this.game,
    this.onBack,
  });

  final OrbitGame game;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        game.hudTick,
        game.isReadyNotifier,
      ]),
      builder: (context, _) => _LeaderboardStripBody(
        game: game,
        onBack: onBack,
      ),
    );
  }
}

class _LeaderboardStripBody extends StatelessWidget {
  const _LeaderboardStripBody({
    required this.game,
    this.onBack,
  });

  final OrbitGame game;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ready = game.isReady;

    return GameHudOverlay(
      entries: _leaderboardEntries(),
      roomType: game.roomType,
      roomInstanceNumber: game.roomInstanceNumber,
      isLoadTestRoom: game.isLoadTestRoom,
      matchElapsed: game.matchElapsed,
      alivePlayerCount: ready ? game.aliveRealPlayerCount : 1,
      aliveBotCount: ready ? game.aliveBotCount : 0,
      onBack: onBack,
    );
  }

  List<LeaderboardEntry> _leaderboardEntries() {
    if (!game.isReady) {
      return [
        LeaderboardEntry(
          name: game.playerName,
          radius: 25,
          isLocal: true,
          visible: true,
          rank: 1,
          rankPoints: game.playerRankPoints,
        ),
      ];
    }
    return game.roomLeaderboardEntries();
  }
}

/// Rebuilds in-game overlays only — keeps [GameWidget] out of parent [setState].
class _GameOverlayLayer extends StatefulWidget {
  const _GameOverlayLayer({
    required this.game,
    required this.onQuit,
  });

  final OrbitGame game;
  final Future<void> Function() onQuit;

  @override
  State<_GameOverlayLayer> createState() => _GameOverlayLayerState();
}

class _GameOverlayLayerState extends State<_GameOverlayLayer> {
  @override
  void initState() {
    super.initState();
    widget.game.matchPhase.addListener(_onPhaseOrSpectate);
    widget.game.isSpectating.addListener(_onPhaseOrSpectate);
    widget.game.isReadyNotifier.addListener(_onPhaseOrSpectate);
  }

  @override
  void dispose() {
    widget.game.matchPhase.removeListener(_onPhaseOrSpectate);
    widget.game.isSpectating.removeListener(_onPhaseOrSpectate);
    widget.game.isReadyNotifier.removeListener(_onPhaseOrSpectate);
    super.dispose();
  }

  void _onPhaseOrSpectate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    if (!game.isReady) return const SizedBox.shrink();

    final phase = game.matchPhase.value;
    final spectating = game.isSpectating.value;
    final showHud = phase == MatchPhase.playing;
    final showWorldEvents = showHud || spectating;
    final r = ResponsiveLayout.of(context);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (showWorldEvents)
          Positioned.fill(
            child: IgnorePointer(
              child: CosmicEventOverlay(game: game),
            ),
          ),
        if (showWorldEvents) MatchFeedOverlay(game: game),
        if (showHud)
          Positioned.fill(
            child: ValueListenableBuilder<int>(
              valueListenable: game.hudTick,
              builder: (context, _, child) {
                final player = game.player;
                return SpawnProtectionOverlay(
                  countdown: player.spawnProtectionCountdown,
                  progress: player.spawnProtectionTotal <= 0
                      ? 0
                      : player.spawnProtectionRemaining /
                          player.spawnProtectionTotal,
                );
              },
            ),
          ),
        if (showHud)
          ValueListenableBuilder<int>(
            valueListenable: game.hudTick,
            builder: (context, _, child) => FirstMatchHintOverlay(game: game),
          ),
        if (showHud) MatchCommsControls(game: game),
        if (showHud)
          Positioned(
            left: 0,
            right: 0,
            bottom: r.linkButtonBottom,
            child: SafeArea(
              child: Center(
                child: LinkButton(
                  visible: game.tacticalManager.canShowLinkButton,
                  onPressed: game.tacticalManager.activateLink,
                ),
              ),
            ),
          ),
        ],
    );
  }
}
