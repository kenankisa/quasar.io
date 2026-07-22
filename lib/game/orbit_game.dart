import 'dart:math' as math;
import 'dart:async';

import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../services/realtime_room_service.dart';
import '../services/room_matchmaking_service.dart';
import '../services/room_tuning_service.dart';
import '../services/lang_service.dart';
import '../services/settings_service.dart';
import 'models/room_instance.dart';
import 'models/match_speech.dart';
import 'components/black_hole_partner.dart';
import 'components/cosmic_sparkle.dart';
import 'components/cosmic_event_manager.dart';
import 'components/cosmic_spawn_manager.dart';
import 'components/enemy_player.dart';
import 'components/explosion_effect.dart';
import 'components/player.dart';
import 'components/bot_population_manager.dart';
import 'components/bot_player.dart';
import 'components/camera_shake_behavior.dart';
import 'components/gravity_physics_manager.dart';
import 'components/hole_swallow_manager.dart';
import 'components/relativistic_jet_effect.dart';
import 'components/tactical_zone_manager.dart';
import 'components/starfield_background.dart';
import 'components/universe_edge_veil.dart';
import 'components/void_camera_backdrop.dart';
import 'models/room_leaderboard.dart';
import 'systems/camera_system.dart';
import 'systems/input_steering_system.dart';
import 'systems/match_lifecycle_system.dart';
import 'systems/network_sync_system.dart';
import 'systems/pickup_collision_system.dart';
import '../utils/player_name.dart';
import 'utils/entity_status_mixins.dart';
import 'config/room_config.dart';
import 'config/bot_difficulty.dart';
import 'config/first_match_tuning.dart';
import 'config/match_pacing.dart';
import 'config/skill_tree_config.dart';
import 'match_phase.dart';
import 'room_type.dart';
import 'utils/black_hole_renderer.dart';
import 'utils/black_hole_shader_renderer.dart';
import 'utils/black_hole_shader_service.dart';
import 'utils/canvas_effects.dart';
import 'utils/viewport_cull.dart';
import 'utils/world_positions.dart';

class OrbitGame extends FlameGame with PanDetector {
  OrbitGame({
    required this.roomType,
    required this.playerId,
    required this.activeSkin,
    this.avatarUrl,
    String playerName = 'You',
    this.playerDiamonds = 0,
    this.playerRankPoints = 0,
    this.gamesWonAtStart = 0,
    this.tutorialCompletedAtStart = false,
    this.roomInstance,
    this.abilityLoadout = AbilityLoadout.base,
  }) : playerName = clampPlayerName(playerName),
       isFirstMatchExperience = FirstMatchTuning.isFirstMatch(
         tutorialCompleted: tutorialCompletedAtStart,
         gamesWon: gamesWonAtStart,
       ),
       initialRealPlayerCount = roomInstance?.realPlayerCount ?? 1;

  double get universeVictoryRadius =>
      RoomTuningService.instance.tuningFor(roomType).victoryRadius;

  /// Maç, yarıçap evren zafer eşiğine ulaştığında veya geçtiğinde biter (500 / 550).
  bool hasUniverseVictory(double radius) => radius >= universeVictoryRadius;

  /// Büyüme sonrası anında zafer kontrolü — tam eşik beklenmez, >= yeterlidir.
  void checkVictoryAfterGrowth() => lifecycle.checkVictoryAfterGrowth();

  static const _baseRadius = 25.0;
  static const _shakeDuration = 0.3;

  late final MatchLifecycleSystem lifecycle = MatchLifecycleSystem(this);
  late final NetworkSyncSystem network = NetworkSyncSystem(this);
  late final CameraSystem cameraSystem = CameraSystem(this);
  late final InputSteeringSystem input = InputSteeringSystem(this);

  /// Accumulates vsync dt so mobile sims do not run above [CanvasEffects.maxGameplayFps].
  double _gameplayFrameAccum = 0;

  final RoomType roomType;
  final String playerId;
  final String activeSkin;
  final String? avatarUrl;
  final String playerName;
  final int playerDiamonds;
  final int playerRankPoints;
  final int gamesWonAtStart;
  final bool tutorialCompletedAtStart;
  final bool isFirstMatchExperience;
  final AbilityLoadout abilityLoadout;
  final RoomInstance? roomInstance;
  final int initialRealPlayerCount;

  String? get roomInstanceId => roomInstance?.id;
  int? get roomInstanceNumber => roomInstance?.instanceNumber;
  bool get isLoadTestRoom => roomInstance?.isLoadTest ?? false;

  bool get isBotOnlyRoom => FirstMatchTuning.isBotOnlyRoom(roomType);

  /// Multiplayer rooms share one server clock + cosmic seed for events.
  bool get usesSharedCosmicSchedule =>
      !isBotOnlyRoom &&
      roomInstanceId != null &&
      roomInstance?.cosmicSeed != null &&
      roomInstance?.matchStartedAt != null;

  DateTime? get matchStartedAt => roomInstance?.matchStartedAt;
  int? get cosmicSeed => roomInstance?.cosmicSeed;

  /// Wall-clock match time from the server when available; else local dt sum.
  double get sharedMatchElapsed {
    final started = matchStartedAt;
    if (started != null) {
      final seconds =
          DateTime.now().toUtc().difference(started).inMilliseconds / 1000.0;
      return seconds < 0 ? 0.0 : seconds;
    }
    return _matchElapsed;
  }

  /// Lexicographically smallest present player id owns shared bot simulation.
  String get electedBotHostId {
    final ids = <String>{playerId};
    for (final id in enemyPlayersById.keys) {
      ids.add(id);
    }
    final sorted = ids.toList()..sort();
    return sorted.first;
  }

  bool get isBotHost =>
      !isBotOnlyRoom &&
      (network.forceBotAuthority || electedBotHostId == playerId);

  BotDifficulty get effectiveBotDifficulty => FirstMatchTuning.adjustBotDifficulty(
        BotDifficulty.forRoom(roomType),
        roomType: roomType,
        isFirstMatch: isFirstMatchExperience,
      );

  double get playerSpawnProtectionDuration =>
      FirstMatchTuning.spawnProtectionDuration(
        roomType: roomType,
        isFirstMatch: isFirstMatchExperience,
      );

  late final Player player;
  late final CosmicSpawnManager spawnManager;
  late final BotPopulationManager botPopulation;
  late final GravityPhysicsManager gravityPhysics;
  late final HoleSwallowManager holeSwallowManager;
  late final TacticalZoneManager tacticalManager;
  late final CosmicEventManager eventManager;
  late final RoomConfig roomConfig;
  late final double worldSize;

  final Map<String, EnemyPlayer> enemyPlayersById = {};
  /// Remotes absorbed locally / announced — ignore lagging alive poses.
  final Set<String> absorbedRemoteIds = {};
  /// Remotes that broadcast alive == false (safe to revive).
  final Set<String> confirmedDeadRemoteIds = {};
  Iterable<EnemyPlayer> get enemyPlayers => enemyPlayersById.values;

  final List<({Vector2 position, double radius})> _gravitySourcesCache = [];

  /// Alive humans in the room (local + remote).
  int get aliveRealPlayerCount {
    if (!isReady) return 1;
    var count = player.isEliminated ? 0 : 1;
    for (final enemy in enemyPlayers) {
      if (!enemy.isEliminated) count++;
    }
    return count;
  }

  /// Alive AI opponents filling the room.
  int get aliveBotCount {
    if (!isReady) return 0;
    return botPopulation.bots.where((bot) => !bot.isEliminated).length;
  }

  /// All black holes that exert Newtonian gravity on matter and each other.
  /// Rebuilt once per [update] — safe to call from every consumable render.
  List<({Vector2 position, double radius})> activeGravitySources() =>
      _gravitySourcesCache;

  void _rebuildGravitySourcesCache() {
    _gravitySourcesCache.clear();
    if (!player.isEliminated) {
      _gravitySourcesCache.add(
        (position: player.position, radius: player.radius),
      );
    }
    if (isReady) {
      for (final bot in botPopulation.bots) {
        if (bot.isEliminated) continue;
        _gravitySourcesCache.add(
          (position: bot.position, radius: bot.radius),
        );
      }
    }
    for (final enemy in enemyPlayersById.values) {
      if (enemy.isEliminated) continue;
      _gravitySourcesCache.add(
        (position: enemy.position, radius: enemy.radius),
      );
    }
  }

  /// Live room standings for the top HUD — always shows names and ranks.
  List<LeaderboardEntry> roomLeaderboardEntries() {
    final entries = <LeaderboardEntry>[];

    if (!player.isEliminated) {
      entries.add(
        LeaderboardEntry(
          name: player.displayName,
          radius: player.radius,
          isLocal: true,
          visible: true,
          rankPoints: playerRankPoints,
        ),
      );
    }

    for (final bot in botPopulation.bots) {
      if (bot.isEliminated) continue;
      entries.add(
        LeaderboardEntry(
          name: bot.displayName,
          radius: bot.radius,
          isLocal: false,
          visible: true,
          isBot: true,
        ),
      );
    }

    for (final enemy in enemyPlayers) {
      if (enemy.isEliminated) continue;
      entries.add(
        LeaderboardEntry(
          name: enemy.displayName,
          radius: enemy.radius,
          isLocal: false,
          visible: true,
          rankPoints: enemy.rankPoints,
        ),
      );
    }

    entries.sort((a, b) => b.radius.compareTo(a.radius));
    return entries;
  }

  final matchPhase = ValueNotifier<MatchPhase>(MatchPhase.playing);
  final isSpectating = ValueNotifier<bool>(false);
  final remoteChampionName = ValueNotifier<String?>(null);
  final remoteChampionIsBot = ValueNotifier<bool>(false);
  final remoteChampionRankPoints = ValueNotifier<int?>(null);
  final remoteChampionElapsed = ValueNotifier<double?>(null);

  double _matchElapsed = 0;
  double get matchElapsed => _matchElapsed;
  double? victoryElapsed;

  /// Oda kapandığında yerel oyuncunun sırası (1 = birincilik). Elemede null.
  int? localPlacement;

  double maxRadiusReached = _baseRadius;
  double eliminatedRadius = 0;
  bool hasUsedRevive = false;

  bool get isFrozen => matchPhase.value != MatchPhase.playing;

  bool get isMatchEnded =>
      matchPhase.value == MatchPhase.victory ||
      matchPhase.value == MatchPhase.frozen;

  final RealtimeRoomService realtime = RealtimeRoomService.instance;

  final isReadyNotifier = ValueNotifier<bool>(false);
  bool get isReady => isReadyNotifier.value;
  final hudTick = ValueNotifier<int>(0);
  final matchFeedTick = ValueNotifier<int>(0);

  static const speechBubbleDuration = 2.2;
  static const matchChatMaxLength = 48;
  static const reactionCooldown = 2.0;
  static const chatCooldown = 3.0;
  static const maxFeedEntries = 5;

  final Map<String, SpeechBubbleState> _speechBubbles = {};
  final List<MatchFeedEntry> _matchFeed = [];
  double _reactionCooldownLeft = 0;
  double _chatCooldownLeft = 0;
  int _feedSeq = 0;

  List<MatchFeedEntry> get matchFeed => List.unmodifiable(_matchFeed);

  String? speechBubbleTextFor(String entityId) =>
      _speechBubbles[entityId]?.text;

  bool get canSendReaction =>
      _reactionCooldownLeft <= 0 &&
      matchPhase.value == MatchPhase.playing &&
      !player.isEliminated;

  bool get canSendMatchChat =>
      _chatCooldownLeft <= 0 &&
      matchPhase.value == MatchPhase.playing &&
      !player.isEliminated;

  double get reactionCooldownLeft => _reactionCooldownLeft;
  double get chatCooldownLeft => _chatCooldownLeft;
  double _radiationShrinkTimer = 0;
  double _shakeRemaining = 0;
  double _shakeDurationCurrent = _shakeDuration;
  double _shakeIntensity = 18;
  bool get isScreenShaking => _shakeRemaining > 0;
  final Vector2 _shakeOffset = Vector2.zero();
  final _rng = math.Random();

  bool get isHoleDragActive => input.isHoleDragActive;

  Vector2 _randomSpawnPosition({bool avoidOthers = false}) {
    final avoid = <Vector2>[];
    if (avoidOthers) {
      for (final bot in botPopulation.bots) {
        if (!bot.isEliminated) avoid.add(bot.position);
      }
      for (final enemy in enemyPlayers) {
        if (!enemy.isEliminated) avoid.add(enemy.position);
      }
    }

    return randomWorldPosition(
      worldSize: worldSize,
      margin: 60,
      avoid: avoid,
      minSeparation: 120,
    );
  }

  @override
  Color backgroundColor() => switch (roomType) {
        RoomType.simple => const Color(0xFF010806),
        RoomType.normal => const Color(0xFF010104),
        RoomType.elite => const Color(0xFF030308),
        RoomType.unique => const Color(0xFF040510),
      };

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await BlackHoleShaderService.preload();

    roomConfig = RoomConfig.forRoom(roomType);
    worldSize = roomConfig.worldSize;

    await world.add(StarfieldBackground(roomType: roomType));
    await world.add(UniverseEdgeVeil(roomType: roomType));

    final startRadius =
        RoomTuningService.instance.tuningFor(roomType).playerStartRadius;
    maxRadiusReached = startRadius;
    player = Player(
      activeSkin: activeSkin,
      avatarUrl: avatarUrl,
      displayName: playerName,
      position: _randomSpawnPosition(),
      radius: startRadius,
      abilityLoadout: abilityLoadout,
    );
    await world.add(player);
    player.armAbilityCooldowns();
    player.activateSpawnProtection(
      duration: playerSpawnProtectionDuration,
      trackTotal: true,
    );

    camera.backdrop = VoidCameraBackdrop(roomType: roomType);
    camera.follow(player, snap: true);
    camera.viewfinder.add(CameraShakeBehavior(this));
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, worldSize, worldSize),
      considerViewport: true,
    );
    camera.viewfinder.zoom = 1.0;

    // Managers needed by render/update paths before food/bots finish spawning.
    holeSwallowManager = HoleSwallowManager();
    await world.add(holeSwallowManager);

    tacticalManager = TacticalZoneManager();
    await add(tacticalManager);

    spawnManager = CosmicSpawnManager(config: roomConfig);
    await add(spawnManager);

    gravityPhysics = GravityPhysicsManager();
    await add(gravityPhysics);

    eventManager = CosmicEventManager();
    await add(eventManager);
    _bindSharedCosmicSchedule();

    botPopulation = BotPopulationManager();
    await add(botPopulation);

    // Overlays read eventManager / gravityPhysics — only flip ready after all managers exist.
    isReadyNotifier.value = true;
    hudTick.value++;

    unawaited(network.joinRealtimeRoom());
  }

  void _bindSharedCosmicSchedule() {
    final seed = cosmicSeed;
    if (!usesSharedCosmicSchedule || seed == null) return;
    eventManager.bindSharedSchedule(seed: seed, worldSize: worldSize);
  }

  void onRemotePlayerEliminated(EnemyPlayer enemy) {
    network.onRemotePlayerEliminated(enemy);
  }

  void onLocalPlayerEliminated(double radiusAtDeath) {
    if (matchPhase.value != MatchPhase.playing) return;
    eliminatedRadius = radiusAtDeath;
    maxRadiusReached = math.max(maxRadiusReached, radiusAtDeath);
    isSpectating.value = false;
    cameraSystem.clearSpectatorTarget();
    matchPhase.value = MatchPhase.eliminated;
    network.syncRealPlayerCount();
    // One final death pose so peers despawn us even if they never resolved the merge.
    if (!isBotOnlyRoom && !lifecycle.universeShutdownInitiated) {
      realtime.broadcastState(network.buildSyncState(alive: false));
    }
    // Koltuk boşalsın: lider join eşiğinin altındaysa sıradaki oyuncu alınabilsin.
    // Realtime kanalı izlemek için açık kalır; dirilişte yeniden üyelik alınır.
    unawaited(_releaseMatchmakingSeat());
  }

  /// Maç içi AFK — yutulmuş gibi elenir (elmas cezası GameScreen'de uygulanır).
  void eliminateLocalPlayerForAfk() {
    if (player.isEliminated || matchPhase.value != MatchPhase.playing) return;
    final radiusAtDeath = player.radius;
    player.isEliminated = true;
    player.velocity.setZero();
    botPopulation.onRealPlayerEliminated();
    onLocalPlayerEliminated(radiusAtDeath);
  }

  /// Called when this client resolves a hole merge and the winner is local
  /// authority (local player, or bot host for bots).
  void announceAbsorbVictory({
    required String predatorId,
    required String predatorName,
    required String preyId,
    required String preyName,
  }) {
    if (isMatchEnded) return;
    final resolved = _resolveAbsorbBubbleText(predatorId);

    _showSpeechBubble(predatorId, resolved);
    _pushFeed(
      '${clampPlayerName(predatorName)} → ${clampPlayerName(preyName)}',
      isKill: true,
    );

    if (isBotOnlyRoom) return;
    realtime.broadcastMatchSpeech(
      MatchSpeechEvent(
        playerId: predatorId,
        playerName: predatorName,
        text: resolved,
        kind: MatchSpeechKind.absorb,
        preyId: preyId,
        preyName: preyName,
      ),
    );
  }

  String _resolveAbsorbBubbleText(String predatorId) {
    final lang = LanguageService.instance;
    String labelFor(MatchReactionPreset preset) {
      final text = lang.t(preset.labelKey);
      return text == preset.labelKey ? preset.fallback : text;
    }

    if (predatorId == playerId) {
      final selectedId = SettingsService.instance.absorbBubblePresetId;
      if (selectedId != 'random') {
        final fixed = absorbPresetById(selectedId);
        if (fixed != null && fixed.id != 'random') {
          return labelFor(fixed);
        }
      }
    }

    final presets = kAbsorbFlexPresets;
    return labelFor(presets[_rng.nextInt(presets.length)]);
  }

  bool trySendReaction(String label) {
    final text = label.trim();
    if (text.isEmpty || !canSendReaction) return false;
    _reactionCooldownLeft = reactionCooldown;
    _emitSpeech(
      text: text,
      kind: MatchSpeechKind.reaction,
    );
    return true;
  }

  bool trySendMatchChat(String raw) {
    final text = raw.trim();
    if (text.isEmpty || !canSendMatchChat) return false;
    if (text.length > matchChatMaxLength) return false;
    _chatCooldownLeft = chatCooldown;
    _emitSpeech(
      text: text,
      kind: MatchSpeechKind.chat,
    );
    return true;
  }

  void _emitSpeech({
    required String text,
    required MatchSpeechKind kind,
  }) {
    _showSpeechBubble(playerId, text);
    if (kind == MatchSpeechKind.chat) {
      _pushFeed(text, name: clampPlayerName(playerName));
    }
    hudTick.value++;
    if (isBotOnlyRoom) return;
    realtime.broadcastMatchSpeech(
      MatchSpeechEvent(
        playerId: playerId,
        playerName: playerName,
        text: text,
        kind: kind,
      ),
    );
  }

  void handleRemoteMatchSpeech(MatchSpeechEvent event) {
    if (isMatchEnded) return;
    _showSpeechBubble(event.playerId, event.text);
    if (event.kind == MatchSpeechKind.absorb) {
      final prey = event.preyName ?? '?';
      _pushFeed(
        '${clampPlayerName(event.playerName)} → ${clampPlayerName(prey)}',
        isKill: true,
      );
      _applyRemoteAbsorb(event.preyId);
    } else if (event.kind == MatchSpeechKind.chat) {
      _pushFeed(
        event.text,
        name: clampPlayerName(event.playerName),
      );
    }
    hudTick.value++;
  }

  /// Peer/host announced an absorb — despawn prey so it cannot linger as a ghost.
  void _applyRemoteAbsorb(String? preyId) {
    if (preyId == null || preyId.isEmpty || preyId == playerId) return;
    network.despawnAbsorbedRemote(preyId);
    botPopulation.removeBotByNetworkId(preyId);
  }

  void _showSpeechBubble(String entityId, String text) {
    if (entityId.isEmpty || text.isEmpty) return;
    _speechBubbles[entityId] = SpeechBubbleState(
      text: text,
      remaining: speechBubbleDuration,
    );
  }

  void _pushFeed(String text, {bool isKill = false, String? name}) {
    _feedSeq++;
    _matchFeed.insert(
      0,
      MatchFeedEntry(
        id: '$_feedSeq',
        name: name,
        text: text,
        createdAt: DateTime.now(),
        isKill: isKill,
      ),
    );
    while (_matchFeed.length > maxFeedEntries) {
      _matchFeed.removeLast();
    }
    matchFeedTick.value++;
  }

  void _tickMatchComms(double dt) {
    if (_reactionCooldownLeft > 0) {
      _reactionCooldownLeft = (_reactionCooldownLeft - dt).clamp(0.0, reactionCooldown);
    }
    if (_chatCooldownLeft > 0) {
      _chatCooldownLeft = (_chatCooldownLeft - dt).clamp(0.0, chatCooldown);
    }

    if (_matchFeed.isNotEmpty) {
      final cutoff =
          DateTime.now().subtract(const Duration(milliseconds: 5000));
      final before = _matchFeed.length;
      _matchFeed.removeWhere((e) => e.createdAt.isBefore(cutoff));
      if (_matchFeed.length != before) matchFeedTick.value++;
    }

    if (_speechBubbles.isEmpty) return;
    final expired = <String>[];
    _speechBubbles.forEach((id, bubble) {
      bubble.remaining -= dt;
      if (bubble.remaining <= 0) expired.add(id);
    });
    if (expired.isEmpty) return;
    for (final id in expired) {
      _speechBubbles.remove(id);
    }
    hudTick.value++;
  }

  Future<void> _releaseMatchmakingSeat() async {
    final instanceId = roomInstanceId;
    if (instanceId == null || isBotOnlyRoom) return;
    await RoomMatchmakingService.instance.leaveRoom(instanceId);
  }

  Future<void> _reclaimMatchmakingSeat() async {
    final instanceId = roomInstanceId;
    if (instanceId == null || isBotOnlyRoom) return;
    try {
      await RoomMatchmakingService.instance.joinRoomInstance(instanceId);
    } on RoomMatchmakingException catch (e) {
      debugPrint('revive rejoin failed: ${e.message}');
    }
  }

  void startSpectating() => cameraSystem.startSpectating();

  void stopSpectating() => cameraSystem.stopSpectating();

  Future<void> leaveRoom({bool tryCloseIfEmpty = true}) =>
      network.leaveRoom(tryCloseIfEmpty: tryCloseIfEmpty);

  /// Sunucu odası kapatıldı (zafer, terk veya bot-only).
  bool get isUniverseClosed => lifecycle.universeShutdownInitiated;

  /// Diriliş: henüz kullanılmadı ve evren bot-only kapanmamış olmalı.
  bool get canRevive =>
      !hasUsedRevive &&
      !lifecycle.universeShutdownInitiated &&
      !isMatchEnded &&
      matchPhase.value == MatchPhase.eliminated;

  void revivePlayer() {
    if (!canRevive) return;

    hasUsedRevive = true;
    isSpectating.value = false;
    player.isEliminated = false;
    player.setRadius(eliminatedRadius * 0.5);
    player.activateShield(duration: 6);
    player.resetBoostEnergy();
    player.resetAbilityCooldowns();
    player.velocity.setZero();
    player.position = _randomSpawnPosition(avoidOthers: true);
    cameraSystem.clearSpectatorTarget();
    camera.follow(player, snap: true);
    matchPhase.value = MatchPhase.playing;
    network.syncRealPlayerCount();
    unawaited(_reclaimMatchmakingSeat());
  }

  bool get _canUseActiveAbilities =>
      isReady &&
      !isMatchEnded &&
      matchPhase.value == MatchPhase.playing &&
      !player.isEliminated &&
      !gravityPhysics.isInspiralLocked(player);

  /// Random reposition with a brief shield so a bad roll is not instant death.
  bool tryActivateTeleport() {
    if (!_canUseActiveAbilities || !player.beginTeleportCooldown()) {
      return false;
    }
    player.velocity.setZero();
    player.position = _randomSpawnPosition(avoidOthers: true);
    player.activateShield(duration: abilityLoadout.teleportBriefShield);
    camera.follow(player, snap: true);
    hudTick.value++;
    return true;
  }

  bool tryActivateAbilityShield() {
    if (!_canUseActiveAbilities || !player.beginAbilityShieldCooldown()) {
      return false;
    }
    player.activateShield(duration: abilityLoadout.abilityShieldDuration);
    hudTick.value++;
    return true;
  }

  /// Pushes smaller bots and nearby food/matter outward. Does not move remote
  /// humans (network-authoritative) or larger holes.
  bool tryActivateShockwave() {
    if (!_canUseActiveAbilities || !player.beginShockwaveCooldown()) {
      return false;
    }

    final origin = player.position.clone();
    final range =
        (player.radius * 7.0 + 90.0) * abilityLoadout.shockwaveRangeMult;
    final rangeSq = range * range;
    final holeImpulse = abilityLoadout.shockwaveHoleImpulse;
    final matterImpulse = abilityLoadout.shockwaveMatterImpulse;

    void pushBody(Vector2 position, Vector2 velocity, double impulse) {
      final dx = position.x - origin.x;
      final dy = position.y - origin.y;
      final distSq = dx * dx + dy * dy;
      if (distSq > rangeSq || distSq < 1.0) return;
      final dist = math.sqrt(distSq);
      final strength = impulse * (1.0 - dist / range);
      velocity.x += dx / dist * strength;
      velocity.y += dy / dist * strength;
    }

    for (final bot in botPopulation.bots) {
      if (bot.isEliminated || bot.radius >= player.radius) continue;
      pushBody(bot.position, bot.velocity, holeImpulse);
    }

    for (final asteroid in spawnManager.asteroids) {
      if (!asteroid.active) continue;
      pushBody(asteroid.position, asteroid.velocity, matterImpulse);
    }
    for (final planet in spawnManager.planets) {
      if (!planet.active) continue;
      pushBody(planet.position, planet.velocity, matterImpulse * 0.85);
    }
    for (final fragment in spawnManager.quasarFragments) {
      if (!fragment.active) continue;
      pushBody(fragment.position, fragment.velocity, matterImpulse);
    }

    world.add(
      ExplosionEffect(
        position: origin,
        maxRadius: range * 0.55,
        duration: 0.42,
      ),
    );
    hudTick.value++;
    return true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isReady && !player.isEliminated) {
      camera.follow(player, snap: true);
    }
  }

  @override
  void update(double dt) {
    if (CanvasEffects.isNativeMobile) {
      _gameplayFrameAccum += dt;
      if (_gameplayFrameAccum < CanvasEffects.minGameplayFrameTime) {
        return;
      }
      dt = _gameplayFrameAccum;
      _gameplayFrameAccum = 0;
    }
    dt = dt.clamp(0.0, 1 / 20);
    if (!isReady) return;

    _rebuildGravitySourcesCache();

    if (isMatchEnded) {
      _tickHud(dt);
      ViewportCull.warmCache(this);
      _planBlackHoleShaderLod();
      return;
    }

    if (matchPhase.value == MatchPhase.playing ||
        matchPhase.value == MatchPhase.eliminated) {
      if (usesSharedCosmicSchedule) {
        _matchElapsed = sharedMatchElapsed;
      } else {
        _matchElapsed += dt;
      }
    }
    if (!player.isEliminated) {
      player.tickSpawnProtection(dt);
      player.tickBoostEnergy(dt);
      player.tickAbilityCooldowns(dt);
      player.tickStatus(dt);
      maxRadiusReached = math.max(maxRadiusReached, player.radius);
      input.tick(dt);
    }
    // Velocity integration runs in component update — apply gravity accelerations first.
    spawnManager.applyGravityPull(dt);

    super.update(dt);
    _updateAntiCamping(dt);
    if (!player.isEliminated) {
      player.updatePhysics(dt);
    }
    gravityPhysics.tickInspirals(dt);
    _checkCollisions();
    lifecycle.checkVictories();
    if (player.isEliminated && isSpectating.value) {
      cameraSystem.updateSpectator(dt);
    } else if (!player.isEliminated) {
      cameraSystem.clearSpectatorTarget();
      cameraSystem.updateZoom(dt);
    }
    network.tickBroadcast(dt);
    network.tickLeaderRadiusSync(dt);
    _tickMatchComms(dt);
    _tickHud(dt);

    // After camera follow + shake so Impeller cull matches what is on screen.
    ViewportCull.warmCache(this);
    _planBlackHoleShaderLod();
  }

  /// On-screen holes get full shader quality; off-screen get none.
  void _planBlackHoleShaderLod() {
    BlackHoleShaderRenderer.beginFrame();

    final view = ViewportCull.visibleWorldRect(this);
    if (view.width <= 0 || view.height <= 0) {
      BlackHoleShaderRenderer.resolveBudget();
      return;
    }

    final focusX = view.center.dx;
    final focusY = view.center.dy;

    void nominateHole({
      required Object key,
      required bool isLocal,
      required Vector2 position,
      required double radius,
      required bool eliminated,
    }) {
      if (eliminated || radius <= 0) return;
      if (!isLocal &&
          ViewportCull.isOffScreen(this, position, radius * 3)) {
        return;
      }

      final dx = position.x - focusX;
      final dy = position.y - focusY;
      final dist = math.sqrt(dx * dx + dy * dy);
      final score = isLocal
          ? double.maxFinite
          : radius * radius / math.max(dist, 48.0);

      BlackHoleShaderRenderer.nominate(
        key: key,
        isLocal: isLocal,
        gameRadius: radius,
        score: score,
      );
    }

    nominateHole(
      key: player,
      isLocal: true,
      position: player.position,
      radius: player.radius,
      eliminated: player.isEliminated,
    );
    for (final bot in botPopulation.bots) {
      nominateHole(
        key: bot,
        isLocal: false,
        position: bot.position,
        radius: bot.radius,
        eliminated: bot.isEliminated,
      );
    }
    for (final enemy in enemyPlayers) {
      nominateHole(
        key: enemy,
        isLocal: false,
        position: enemy.position,
        radius: enemy.radius,
        eliminated: enemy.isEliminated,
      );
    }

    BlackHoleShaderRenderer.resolveBudget();
  }

  void triggerScreenShake() {
    triggerExtendedScreenShake();
  }

  /// Stage 4 "Total Consumption & Quasar Activation": fires twin relativistic
  /// jets and briefly flares the accretion disk after a hole swallows a
  /// significant chunk of mass. Screen shakes proportionally for the local
  /// player, matching the swallowed-mass ratio.
  void triggerQuasarActivation(BlackHolePartner consumer, double growthAmount) {
    if (consumer.isEliminated || growthAmount <= 0) return;

    final ratio = growthAmount / math.max(consumer.holeRadius, 1.0);
    if (ratio < 0.12) return;

    final strength = (ratio / 0.6).clamp(0.15, 1.0);

    if (consumer is QuasarActivationMixin) {
      (consumer as QuasarActivationMixin).triggerQuasarActivation(strength: strength);
    }

    final skin = switch (consumer) {
      Player p => p.activeSkin,
      BotPlayer b => b.skin,
      EnemyPlayer e => e.activeSkin,
      _ => 'default',
    };
    final accent = consumer is BotPlayer ? consumer.accentColor : null;
    final palette = BlackHoleRenderer.plasmaPalette(skin: skin, accentColor: accent);

    world.add(
      RelativisticJetEffect(
        position: consumer.position.clone(),
        holeRadius: consumer.holeRadius,
        coreColor: palette.hot[0],
        intensity: strength,
      ),
    );

    if (identical(consumer, player)) {
      triggerExtendedScreenShake(
        duration: 0.22 + strength * 0.28,
        intensity: 9 + strength * 24,
      );
    }
  }

  void triggerExtendedScreenShake({
    double duration = _shakeDuration,
    double intensity = 18,
  }) {
    _shakeRemaining = duration;
    _shakeDurationCurrent = duration;
    _shakeIntensity = intensity;
  }

  double _hudTimer = 0;

  void _tickHud(double dt) {
    _hudTimer += dt;
    final boostBusy = !player.isEliminated &&
        (player.boostEnergy < 1.0 || player.isBoostActive);
    final abilityBusy = !player.isEliminated &&
        (player.teleportCooldownRemaining > 0 ||
            player.abilityShieldCooldownRemaining > 0 ||
            player.shockwaveCooldownRemaining > 0 ||
            player.isShieldActive);
    final spawnBusy = !player.isEliminated && player.isSpawnProtected;
    final interval = (boostBusy || abilityBusy || spawnBusy) ? 0.05 : 0.25;
    if (_hudTimer >= interval) {
      _hudTimer = 0;
      hudTick.value++;
    }
  }

  /// Called by [CameraShakeBehavior] after the camera follow step each frame.
  Vector2 consumeShakeOffset(double dt) {
    if (_shakeRemaining <= 0) {
      _shakeOffset.setZero();
      return Vector2.zero();
    }

    _shakeRemaining -= dt;
    final t = (_shakeRemaining / _shakeDurationCurrent).clamp(0.0, 1.0);
    var intensity = t * _shakeIntensity;

    // Near the arena border, clamp shake so the cull rect doesn't thrash
    // entities on/off at the screen rim.
    if (isReady && !player.isEliminated) {
      final px = player.position.x;
      final py = player.position.y;
      final edgeDist = math.min(
        math.min(px, py),
        math.min(worldSize - px, worldSize - py),
      );
      if (edgeDist < 420) {
        intensity *= (edgeDist / 420).clamp(0.2, 1.0);
      }
    }

    _shakeOffset.setValues(
      (_rng.nextDouble() * 2 - 1) * intensity,
      (_rng.nextDouble() * 2 - 1) * intensity,
    );
    return _shakeOffset;
  }

  void _updateAntiCamping(double dt) {
    if (player.isSpawnProtected || !player.isRadiating) {
      _radiationShrinkTimer = 0;
      return;
    }

    final pacing = MatchPacing.forRoom(roomType);
    final shrinkRate = player.radius >= pacing.lateGameRadiationRadius
        ? pacing.lateGameRadiationShrinkPerSecond
        : 1.0;

    _radiationShrinkTimer += dt * shrinkRate;
    var shrinkSteps = 0;
    while (_radiationShrinkTimer >= 1 && shrinkSteps < 3) {
      shrinkSteps++;
      _radiationShrinkTimer -= 1;
      if (player.radius <= 8) break;
      player.growBy(-1);
      _scatterRadiationSparkles(3 + _rng.nextInt(3));
    }
  }

  void _scatterRadiationSparkles(int count) {
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final dist = player.radius * (1.2 + _rng.nextDouble() * 2.5);
      final offset = Vector2(math.cos(angle), math.sin(angle)) * dist;
      world.add(
        CosmicSparkle(position: player.position + offset),
      );
    }
  }

  void _checkCollisions() {
    PickupCollisionSystem.collectFor(
      consumer: player,
      spawn: spawnManager,
      events: eventManager,
    );
  }

  void endHoleDrag() => input.endHoleDrag();

  @override
  void onPanDown(DragDownInfo info) => input.onPanDown(info);

  @override
  void onPanStart(DragStartInfo info) => input.onPanStart(info);

  @override
  void onPanUpdate(DragUpdateInfo info) => input.onPanUpdate(info);

  @override
  void onPanEnd(DragEndInfo info) => input.onPanEnd(info);

  @override
  void onPanCancel() => input.onPanCancel();

  @override
  void onRemove() {
    leaveRoom();
    super.onRemove();
  }
}
