import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../models/cosmetic_item.dart';
import '../config/first_match_tuning.dart';
import '../config/room_matchmaking.dart';
import '../models/bot_sync_state.dart';
import '../orbit_game.dart';
import '../room_type.dart';
import '../../utils/bot_name.dart';
import '../utils/world_positions.dart';
import 'bot_player.dart';
import 'player.dart';

/// Keeps room entity count at [roomCapacity] (real players + bots).
///
/// Competitive rooms: max 10 real → 10 bots when full.
/// Training (simple): 1 local player → 19 bots (same total fill).
///
/// In competitive multiplayer only the bot-host runs AI/spawn; peers apply
/// [BotSnapshot] from Realtime.
class BotPopulationManager extends Component with HasGameReference<OrbitGame> {
  static const roomCapacity = RoomMatchmaking.roomEntityCapacity;

  static const _botNames = [
    'Nebula-X',
    'Void Prime',
    'Quasar Drift',
    'Dark Matter',
    'Singularity',
    'Horizon',
    'CosmicWraith',
    'Pulsar Ghost',
    'Gravity Well',
    'Stellar Maw',
    'Abyss Walker',
    'Nova Hunter',
    'Eclipse Core',
    'Orbit Reaper',
    'Warp Shade',
    'Ion Void',
    'Rift Stalker',
    'Photon Eater',
    'StarCollapse',
    'Nebula Fang',
    'Quantum Sink',
    'Void Serpent',
    'Plasma Maw',
    'Supernova',
    'Black Tide',
    'Cosmic Leech',
    'Gravity Fang',
    'Dark Pulse',
    'ShadowOrbit',
    'xNovaKid',
    'GalaxyFox',
    'VoidWalker99',
    'LunarDrift',
    'StarPilot',
    'OrbitKing',
    'NyxPlayer',
    'CosmoAce',
    'ZeroGravity',
    'NightComet',
    'PulseRider',
  ];

  static final _skins = CosmeticCatalog.botSkinIds;

  /// Distinct hues so each bot disk / portrait reads differently in a room.
  static const _botAccentHues = <double>[
    0, 18, 36, 54, 72, 90, 108, 126, 144, 162,
    180, 198, 216, 234, 252, 270, 288, 306, 324, 342,
  ];

  final List<BotPlayer> bots = [];
  final Map<String, BotPlayer> _byNetworkId = {};
  /// Bots removed locally (eaten) — ignore snapshot re-adds until host drops them.
  final Set<String> _absorbedNetworkIds = {};
  int _realPlayerCount = 1;
  int _nameIndex = 0;
  int _colorIndex = 0;
  int _idSeq = 0;
  final _rng = math.Random();

  int _targetBotCount = 0;
  bool _syncInFlight = false;
  bool _closed = false;
  bool _isAuthority = true;

  bool get isAuthority => _isAuthority;

  int get targetBotCount =>
      (roomCapacity - _realPlayerCount).clamp(0, roomCapacity);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (game.isBotOnlyRoom) {
      _isAuthority = true;
      _targetBotCount = targetBotCount;
      await _syncPopulation();
    } else {
      // Competitive: wait for OrbitGame host election before spawning.
      _isAuthority = false;
      _targetBotCount = 0;
    }
  }

  /// Host runs AI/spawn; peers only render snapshots.
  void setAuthority(bool value) {
    if (_closed) return;
    if (_isAuthority == value) return;
    _isAuthority = value;

    for (final bot in bots) {
      bot.isNetworkDriven = !value;
      // Freeze lerp targets on the current pose to avoid a teleport.
      bot.applyNetworkState(
        BotSyncState(
          id: bot.networkId,
          displayName: bot.displayName,
          x: bot.position.x,
          y: bot.position.y,
          radius: bot.radius,
          activeSkin: bot.skin,
          accentHue: bot.accentHue,
          boost: bot.isBoosting,
          shield: bot.isShieldActive || bot.isSpawnProtected,
        ),
      );
    }

    if (value) {
      unawaited(_syncPopulation());
    }
  }

  /// Called when additional real players join the room (multiplayer).
  void setRealPlayerCount(int count) {
    _realPlayerCount = count.clamp(0, roomCapacity);
    if (_isAuthority) {
      unawaited(_syncPopulation());
    }
  }

  /// Called when the local real player is eliminated.
  /// Population target is synced from [NetworkSyncSystem.syncRealPlayerCount].
  void onRealPlayerEliminated() {}

  BotSnapshot buildSnapshot(String hostId) {
    final states = <BotSyncState>[];
    for (final bot in bots) {
      if (bot.isEliminated) continue;
      states.add(
        BotSyncState(
          id: bot.networkId,
          displayName: bot.displayName,
          x: bot.position.x,
          y: bot.position.y,
          radius: bot.radius,
          activeSkin: bot.skin,
          accentHue: bot.accentHue,
          boost: bot.isBoosting,
          shield: bot.isShieldActive || bot.isSpawnProtected,
        ),
      );
    }
    return BotSnapshot(hostId: hostId, bots: states);
  }

  Future<void> applySnapshot(BotSnapshot snapshot) async {
    if (_closed || _isAuthority) return;

    final seen = <String>{};
    for (final state in snapshot.bots) {
      if (state.id.isEmpty) continue;
      seen.add(state.id);
      // Host has not yet dropped an absorbed bot — don't resurrect the ghost.
      if (_absorbedNetworkIds.contains(state.id)) continue;
      final existing = _byNetworkId[state.id];
      if (existing != null) {
        existing.isNetworkDriven = true;
        existing.applyNetworkState(state);
        continue;
      }
      await _spawnFromNetwork(state);
    }

    // Host confirmed absence — clear local absorb tombstones.
    _absorbedNetworkIds.removeWhere((id) => !seen.contains(id));

    for (final bot in List<BotPlayer>.from(bots)) {
      if (seen.contains(bot.networkId)) continue;
      _detachBot(bot, respawn: false);
    }
  }

  Future<void> _syncPopulation() async {
    if (!_isAuthority || _syncInFlight || _closed) return;
    _syncInFlight = true;

    try {
      // Re-read the live target every iteration: clearAll() (universe
      // shutdown) can run while a spawn is awaited. The old fixed-target
      // `while (bots.length < target)` loop then spun forever because
      // _spawnBot early-returned without adding a bot — freezing the app
      // the moment the local player was swallowed.
      while (!_closed && _isAuthority) {
        final target = targetBotCount;
        _targetBotCount = target;

        if (bots.length > target) {
          final bot = bots.removeLast();
          _byNetworkId.remove(bot.networkId);
          bot.isEliminated = true;
          bot.removeFromParent();
          continue;
        }

        if (bots.length < target) {
          final countBefore = bots.length;
          await _spawnBot();
          if (bots.length <= countBefore) break; // No progress — bail out.
          continue;
        }

        break;
      }
    } finally {
      _syncInFlight = false;
    }
  }

  int get _preyBotCount => bots.where((bot) => bot.isPreyBot).length;

  String _allocNetworkId() {
    while (true) {
      final id = 'bot_$_idSeq';
      _idSeq++;
      if (!_byNetworkId.containsKey(id)) return id;
    }
  }

  Future<void> _spawnBot() async {
    if (_closed || !_isAuthority || bots.length >= _targetBotCount) return;

    final difficulty = game.effectiveBotDifficulty;
    final isPrey = game.roomType == RoomType.simple &&
        _preyBotCount < FirstMatchTuning.simpleRoomPreyBotCount;
    final personality =
        isPrey ? BotPersonality.coward : difficulty.pickPersonality(_rng.nextInt);
    final position = randomWorldPosition(
      worldSize: game.worldSize,
      margin: 60,
      avoid: _occupiedPositions(),
      minSeparation: isPrey ? 140 : 180,
    );

    final startMin = isPrey ? 17.0 : difficulty.startRadiusMin;
    final startMax = isPrey ? 21.0 : difficulty.startRadiusMax;
    final hue = _nextAccentHue();

    final bot = BotPlayer(
      networkId: _allocNetworkId(),
      displayName: _nextName(),
      personality: personality,
      difficulty: difficulty,
      position: position,
      radius: startMin + _rng.nextDouble() * (startMax - startMin),
      skin: _skins[_rng.nextInt(_skins.length)],
      accentHue: hue,
      isPreyBot: isPrey,
      isNetworkDriven: false,
    );

    _register(bot);
    bot.activateSpawnProtection(duration: Player.spawnProtectionDuration);
    await game.world.add(bot);
  }

  Future<void> _spawnFromNetwork(BotSyncState state) async {
    if (_closed || _isAuthority || _byNetworkId.containsKey(state.id)) return;

    final difficulty = game.effectiveBotDifficulty;
    final bot = BotPlayer(
      networkId: state.id,
      displayName: state.displayName,
      personality: BotPersonality.opportunist,
      difficulty: difficulty,
      position: Vector2(state.x, state.y),
      radius: state.radius,
      skin: state.activeSkin,
      accentHue: state.accentHue,
      isPreyBot: false,
      isNetworkDriven: true,
    );
    bot.applyNetworkState(state);
    _register(bot);
    await game.world.add(bot);
  }

  void _register(BotPlayer bot) {
    bots.add(bot);
    _byNetworkId[bot.networkId] = bot;
  }

  Iterable<Vector2> _occupiedPositions() sync* {
    if (!game.player.isEliminated) yield game.player.position;
    for (final enemy in game.enemyPlayers) {
      if (!enemy.isEliminated) yield enemy.position;
    }
    for (final bot in bots) {
      if (!bot.isEliminated) yield bot.position;
    }
  }

  String _nextName() {
    final name = _botNames[_nameIndex % _botNames.length];
    _nameIndex++;
    return formatBotDisplayName(name);
  }

  double _nextAccentHue() {
    final hue = _botAccentHues[_colorIndex % _botAccentHues.length];
    _colorIndex++;
    return hue;
  }

  void removeBot(BotPlayer bot) {
    _absorbedNetworkIds.add(bot.networkId);
    _detachBot(bot, respawn: _isAuthority);
  }

  /// Despawn by network id (absorb broadcast from another client / host).
  void removeBotByNetworkId(String networkId) {
    if (networkId.isEmpty) return;
    _absorbedNetworkIds.add(networkId);
    final bot = _byNetworkId[networkId];
    if (bot != null) {
      _detachBot(bot, respawn: _isAuthority);
    }
  }

  BotPlayer? botByNetworkId(String networkId) => _byNetworkId[networkId];

  void _detachBot(BotPlayer bot, {required bool respawn}) {
    if (!_byNetworkId.containsKey(bot.networkId) && !bots.contains(bot)) {
      return;
    }
    bots.remove(bot);
    _byNetworkId.remove(bot.networkId);
    bot.isEliminated = true;
    bot.removeFromParent();
    if (respawn && _isAuthority) {
      unawaited(_syncPopulation());
    }
  }

  /// Evren kapandığında tüm botları kaldır (yeniden doğurma yok).
  void clearAll() {
    _closed = true;
    for (final bot in List<BotPlayer>.from(bots)) {
      bot.isEliminated = true;
      bot.removeFromParent();
    }
    bots.clear();
    _byNetworkId.clear();
    _absorbedNetworkIds.clear();
    _realPlayerCount = 0;
    _targetBotCount = 0;
  }
}
