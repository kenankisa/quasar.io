import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../game/components/player.dart';
import '../game/config/room_matchmaking.dart';
import '../game/models/bot_sync_state.dart';
import '../game/models/player_sync_state.dart';
import '../game/models/room_instance.dart';
import '../game/room_type.dart';
import '../models/cosmetic_item.dart';
import '../utils/bot_name.dart';
import '../utils/safe_debug.dart';

class LoadTestSimCredentials {
  LoadTestSimCredentials({
    required this.email,
    required String password,
    this.userId,
    this.username,
  }) : _password = password;

  final String email;
  String _password;
  final String? userId;
  final String? username;

  String get password => _password;

  /// Clear plaintext after successful sign-in (low: reduce memory / log leak).
  void clearPassword() {
    _password = '';
  }
}

enum _SimPersonality { aggressive, farmer, cautious }

/// Tek bir gerçek Supabase istemcisi — ayrı hesap + oturum + oda + Realtime.
///
/// Hafif AI ile gerçek oyuncu gibi oynar: farm, avla, kaç, boost, büy belki
/// yenil / yeniden doğ; `player_state` + paylaşılan `bot_snapshot` +
/// `update_room_leader_radius` telefon istemcisiyle aynı protokolü üretir.
class LoadTestSimPlayer {
  LoadTestSimPlayer({
    required this.index,
    required this.roomType,
    required this.worldSize,
  });

  final int index;
  final RoomType roomType;
  final double worldSize;

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _tickTimer;
  Timer? _leaderSyncTimer;

  String? userId;
  String? displayName;
  String? roomInstanceId;
  int? roomInstanceNumber;
  String? deviceId;
  String? error;

  bool get isAlive =>
      userId != null &&
      roomInstanceId != null &&
      _channel != null &&
      error == null &&
      !_stopped;

  static const _tickHz = 12.0;
  static const _tickDt = 1.0 / _tickHz;

  /// Zafer eşiğinin altında kal — odaları sürekli kapatmasın, ama lider
  /// yarıçap senkronunu ve join eşiğini (280) strese soksun.
  static const _radiusCap = 320.0;

  final _rng = math.Random();
  final Map<String, _PeerSnapshot> _peers = {};
  final Map<String, _SimBot> _bots = {};

  double _x = 0;
  double _y = 0;
  double _radius = Player.baseRadius;
  double _vx = 0;
  double _vy = 0;
  double _aimX = 1;
  double _aimY = 0;

  double _boostEnergy = 0;
  double _boostActiveRemaining = 0;
  bool _shield = false;
  double _shieldRemaining = 0;
  double _spawnProtection = 0;
  double _decisionTimer = 0;
  double _farmTimer = 0;
  double _aliveSeconds = 0;
  bool _stopped = false;
  bool _roomEnded = false;

  bool _forceBotAuthority = false;
  double _botSnapshotAge = 0;
  int _botIdSeq = 0;
  int _botNameIndex = 0;
  int _botHueIndex = 0;

  static const _botHostSilenceSeconds = 2.0;

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
  ];

  static const _botAccentHues = <double>[
    0, 18, 36, 54, 72, 90, 108, 126, 144, 162,
    180, 198, 216, 234, 252, 270, 288, 306, 324, 342,
  ];

  late final _SimPersonality _personality;
  late final String _skin;

  static final _skins = CosmeticCatalog.botSkinIds;

  int get _aliveRealCount => 1 + _peers.length;

  List<String> _presentPlayerIdsSorted() {
    final id = userId;
    final ids = <String>{?id, ..._peers.keys};
    final sorted = ids.toList()..sort();
    return sorted;
  }

  String? get _electedBotHostId {
    final sorted = _presentPlayerIdsSorted();
    if (sorted.isEmpty) return null;
    return sorted.first;
  }

  bool get _isBotHost {
    final id = userId;
    if (id == null) return false;
    return _forceBotAuthority || _electedBotHostId == id;
  }

  /// [minted] admin RPC ile üretilmiş onaylı hesap (Anonymous gerekmez).
  Future<void> start({LoadTestSimCredentials? minted}) async {
    _stopped = false;
    _roomEnded = false;
    deviceId = 'sim_${index}_${DateTime.now().microsecondsSinceEpoch}';
    displayName = minted?.username ?? 'Sim${index.toString().padLeft(3, '0')}';
    _personality = _SimPersonality.values[index % _SimPersonality.values.length];
    _skin = _skins[index % _skins.length];

    _client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

    await _authenticate(minted);
    if (minted == null) {
      await _prepareProfile();
    } else if (minted.username != null && minted.username!.isNotEmpty) {
      displayName = minted.username;
    }
    await _claimSession();
    await _joinRoom();
    await _joinRealtime();
    _startHeartbeat();
    _startGameplayLoop();
    _startLeaderRadiusSync();
  }

  Future<void> _authenticate(LoadTestSimCredentials? minted) async {
    final client = _client!;

    if (minted == null) {
      throw StateError(
        'Sim#$index: minted credentials required. '
        'Run migration_load_test_sim_mint.sql (admin_mint_sim_player). '
        'Anonymous Auth is disabled for sim mint.',
      );
    }

    userId = await _signInWithRetry(
      () => client.auth.signInWithPassword(
        email: minted.email,
        password: minted.password,
      ),
      fallbackUserId: minted.userId,
    );
    minted.clearPassword();
    safeDebugPrint('Sim#$index auth: minted signIn $userId');
  }

  Future<String> _signInWithRetry(
    Future<AuthResponse> Function() signIn, {
    String? fallbackUserId,
  }) async {
    const maxAttempts = 6;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final signedIn = await signIn();
        final id = signedIn.user?.id ?? fallbackUserId;
        if (id != null) return id;
        throw StateError('Sim#$index: sign-in returned no user');
      } catch (e) {
        lastError = e;
        if (!_isAuthRateLimit(e) || attempt == maxAttempts) rethrow;
        final waitSec = 12 + (attempt * 6);
        debugPrint(
          'Sim#$index auth rate-limited (attempt $attempt/$maxAttempts), '
          'waiting ${waitSec}s…',
        );
        await Future<void>.delayed(Duration(seconds: waitSec));
      }
    }

    throw lastError ?? StateError('Sim#$index: sign-in failed');
  }

  bool _isAuthRateLimit(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('over_request_rate_limit') ||
        msg.contains('request rate limit') ||
        msg.contains('statuscode: 429') ||
        msg.contains('status code: 429') ||
        (e is AuthApiException && e.statusCode == '429');
  }

  Future<void> _prepareProfile() async {
    final client = _client!;
    final response = await client.rpc(
      'prepare_simulated_player',
      params: {'p_display_name': displayName},
    );
    if (response is Map) {
      final name = response['username'] as String?;
      if (name != null && name.isNotEmpty) displayName = name;
      userId ??= response['user_id'] as String?;
    }
  }

  Future<void> _claimSession() async {
    await _rpcWithNetworkRetry(
      'claim_player_session',
      () => _client!.rpc(
        'claim_player_session',
        params: {
          'p_device_id': deviceId,
          'p_room_type': roomType.name,
        },
      ),
    );
  }

  Future<void> _joinRoom() async {
    final response = await _rpcWithNetworkRetry(
      'join_game_room',
      () => _client!.rpc(
        'join_game_room',
        params: {'p_room_type': roomType.name},
      ),
    );
    if (response == null) {
      throw StateError('Sim#$index: join_game_room empty');
    }
    final room = RoomInstance.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    roomInstanceId = room.id;
    roomInstanceNumber = room.instanceNumber;
    _respawn(initial: true);
  }

  Future<dynamic> _rpcWithNetworkRetry(
    String label,
    Future<dynamic> Function() call, {
    int maxAttempts = 5,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await call();
      } catch (e) {
        lastError = e;
        if (!_isTransientNetworkError(e) || attempt == maxAttempts) {
          rethrow;
        }
        final waitMs = 800 * attempt * attempt;
        debugPrint(
          'Sim#$index $label network glitch '
          '(attempt $attempt/$maxAttempts), waiting ${waitMs}ms… $e',
        );
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
    }
    throw lastError ?? StateError('Sim#$index: $label failed');
  }

  static bool _isTransientNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('failed to fetch') ||
        msg.contains('clientexception') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('network error') ||
        msg.contains('socketexception') ||
        msg.contains('timed out') ||
        msg.contains('timeout');
  }

  Future<void> _joinRealtime() async {
    final client = _client!;
    final id = userId!;
    final channelName = 'quasar_room_${roomType.name}_$roomInstanceId';

    _channel = client
        .channel(channelName)
        .onBroadcast(
          event: 'player_state',
          callback: (payload) {
            if (_stopped) return;
            try {
              final state = PlayerSyncState.fromMap(
                Map<String, dynamic>.from(payload),
              );
              if (state.id == id) return;
              _peers[state.id] = _PeerSnapshot(
                id: state.id,
                x: state.x,
                y: state.y,
                radius: state.radius,
                updatedAt: DateTime.now(),
              );
            } catch (_) {}
          },
        )
        .onBroadcast(
          event: 'bot_snapshot',
          callback: (payload) {
            if (_stopped) return;
            try {
              _handleBotSnapshot(
                BotSnapshot.fromMap(Map<String, dynamic>.from(payload)),
              );
            } catch (_) {}
          },
        )
        .onBroadcast(
          event: 'player_left',
          callback: (payload) {
            final leftId = payload['id'] as String?;
            if (leftId != null) _peers.remove(leftId);
          },
        )
        .onBroadcast(
          event: 'room_closed',
          callback: (_) {
            _roomEnded = true;
          },
        )
        .onBroadcast(
          event: 'universe_victory',
          callback: (_) {
            _roomEnded = true;
          },
        );

    _channel!.subscribe();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    debugPrint('Sim#$index realtime play: $channelName as $id ($_personality)');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_sendHeartbeat());
    });
    unawaited(_sendHeartbeat());
  }

  Future<void> _sendHeartbeat() async {
    final client = _client;
    final device = deviceId;
    if (client == null || device == null || _stopped) return;
    try {
      await client.rpc(
        'heartbeat_player_session',
        params: {'p_device_id': device},
      );
    } catch (e) {
      debugPrint('Sim#$index heartbeat: $e');
    }
    final roomId = roomInstanceId;
    if (roomId != null) {
      try {
        await client.rpc(
          'touch_game_room',
          params: {'p_room_instance_id': roomId},
        );
      } catch (e) {
        debugPrint('Sim#$index touch_game_room: $e');
      }
    }
  }

  void _startGameplayLoop() {
    _tickTimer?.cancel();
    // Index offset — tüm sim'ler aynı milisaniyede broadcast etmesin
    final offsetMs = (index * 7) % 80;
    Future<void>.delayed(Duration(milliseconds: offsetMs), () {
      if (_stopped) return;
      _tickTimer = Timer.periodic(
        Duration(milliseconds: (1000 / _tickHz).round()),
        (_) => _onTick(),
      );
    });
  }

  void _startLeaderRadiusSync() {
    _leaderSyncTimer?.cancel();
    // Gerçek istemci ~5 sn; sim'leri biraz kaydır
    final offsetMs = 800 + (index % 20) * 200;
    Future<void>.delayed(Duration(milliseconds: offsetMs), () {
      if (_stopped) return;
      unawaited(_syncLeaderRadius());
      _leaderSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        unawaited(_syncLeaderRadius());
      });
    });
  }

  Future<void> _syncLeaderRadius() async {
    final client = _client;
    final roomId = roomInstanceId;
    if (client == null || roomId == null || _stopped || _roomEnded) return;

    var leader = _radius.round();
    for (final peer in _peers.values) {
      if (peer.radius > leader) leader = peer.radius.round();
    }
    for (final bot in _bots.values) {
      if (bot.radius > leader) leader = bot.radius.round();
    }

    try {
      await client.rpc(
        'update_room_leader_radius',
        params: {
          'p_room_instance_id': roomId,
          'p_leader_radius': leader,
        },
      );
    } catch (e) {
      debugPrint('Sim#$index leader_radius: $e');
    }
  }

  void _onTick() {
    if (_stopped || _roomEnded) return;
    _pruneStalePeers();
    _tickBotHostFailover(_tickDt);
    _tickStatus(_tickDt);
    if (_isBotHost) {
      _tickHostBots(_tickDt);
    }
    _tickAi(_tickDt);
    _tickPhysics(_tickDt);
    _tickCombat();
    _tickGrowth(_tickDt);
    _broadcastState();
    if (_isBotHost) {
      _broadcastBotSnapshot();
    }
  }

  void _pruneStalePeers() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 4));
    _peers.removeWhere((_, peer) => peer.updatedAt.isBefore(cutoff));
  }

  void _handleBotSnapshot(BotSnapshot snapshot) {
    final id = userId;
    if (id == null || snapshot.hostId.isEmpty || snapshot.hostId == id) return;

    final sorted = _presentPlayerIdsSorted();
    if (sorted.isEmpty) return;
    final elected = sorted.first;
    final nextInLine = sorted.length > 1 ? sorted[1] : null;
    if (snapshot.hostId != elected && snapshot.hostId != nextInLine) return;

    // Rightful elected host keeps simulating — ignore peer snapshots.
    if (elected == id) return;

    _botSnapshotAge = 0;
    if (_forceBotAuthority) {
      _forceBotAuthority = false;
    }
    _applyBotSnapshot(snapshot);
  }

  void _applyBotSnapshot(BotSnapshot snapshot) {
    final seen = <String>{};
    final now = DateTime.now();
    for (final state in snapshot.bots) {
      if (state.id.isEmpty) continue;
      seen.add(state.id);
      final existing = _bots[state.id];
      if (existing != null) {
        existing.x = state.x;
        existing.y = state.y;
        existing.radius = state.radius;
        existing.displayName = state.displayName;
        existing.skin = state.activeSkin;
        existing.accentHue = state.accentHue;
        existing.boost = state.boost;
        existing.shield = state.shield;
        existing.updatedAt = now;
        continue;
      }
      _bots[state.id] = _SimBot.fromSync(state)..updatedAt = now;
    }
    _bots.removeWhere((botId, _) => !seen.contains(botId));
  }

  void _tickBotHostFailover(double dt) {
    final id = userId;
    if (id == null) return;
    final sorted = _presentPlayerIdsSorted();
    if (sorted.isEmpty) return;
    final elected = sorted.first;

    if (elected == id) {
      _forceBotAuthority = false;
      return;
    }

    _botSnapshotAge += dt;
    final nextInLine = sorted.length > 1 ? sorted[1] : null;
    final mayForce = nextInLine == id;

    if (_botSnapshotAge >= _botHostSilenceSeconds && mayForce) {
      _forceBotAuthority = true;
    } else if (_forceBotAuthority && !mayForce) {
      _forceBotAuthority = false;
    }
  }

  void _tickHostBots(double dt) {
    _syncHostBotPopulation();
    for (final bot in _bots.values) {
      _tickOneHostBot(bot, dt);
    }
    _resolveHostBotCombat();
  }

  void _syncHostBotPopulation() {
    final target = RoomMatchmaking.botCountFor(_aliveRealCount);
    while (_bots.length > target) {
      final id = _bots.keys.last;
      _bots.remove(id);
    }
    while (_bots.length < target) {
      _spawnHostBot();
    }
  }

  void _spawnHostBot() {
    final networkId = _allocBotId();
    final name = formatBotDisplayName(
      _botNames[_botNameIndex % _botNames.length],
    );
    _botNameIndex++;
    final hue = _botAccentHues[_botHueIndex % _botAccentHues.length];
    _botHueIndex++;
    final skin = _skins[_rng.nextInt(_skins.length)];
    final margin = 80.0;
    _bots[networkId] = _SimBot(
      id: networkId,
      displayName: name,
      skin: skin,
      accentHue: hue,
      x: margin + _rng.nextDouble() * (worldSize - margin * 2),
      y: margin + _rng.nextDouble() * (worldSize - margin * 2),
      radius: 18 + _rng.nextDouble() * 10,
    );
  }

  String _allocBotId() {
    while (true) {
      final id = 'bot_$_botIdSeq';
      _botIdSeq++;
      if (!_bots.containsKey(id)) return id;
    }
  }

  void _tickOneHostBot(_SimBot bot, double dt) {
    bot.decisionTimer -= dt;
    if (bot.decisionTimer <= 0) {
      bot.decisionTimer = 0.28 + _rng.nextDouble() * 0.35;
      final threat = _nearestThreatFor(bot.x, bot.y, bot.radius, ignoreBotId: bot.id);
      final prey = _bestPreyFor(bot.x, bot.y, bot.radius, ignoreBotId: bot.id);
      if (threat != null && _rng.nextDouble() < 0.7) {
        final dx = bot.x - threat.x;
        final dy = bot.y - threat.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 1) {
          bot.aimX = dx / len;
          bot.aimY = dy / len;
        }
        bot.boost = true;
      } else if (prey != null && _rng.nextDouble() < 0.65) {
        final dx = prey.x - bot.x;
        final dy = prey.y - bot.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 1) {
          bot.aimX = dx / len;
          bot.aimY = dy / len;
        }
        bot.boost = len < bot.radius * 6;
      } else {
        final angle = _rng.nextDouble() * math.pi * 2;
        bot.aimX = math.cos(angle);
        bot.aimY = math.sin(angle);
        bot.boost = false;
      }
      bot.shield = _rng.nextDouble() < 0.03;
    }

    final maxSpeed = Player.maxSpeedForRadius(bot.radius) *
        (bot.boost ? Player.boostSpeedMultiplier : 1.0);
    bot.vx += bot.aimX * maxSpeed * 0.75 * 14 * dt;
    bot.vy += bot.aimY * maxSpeed * 0.75 * 14 * dt;
    final speed = math.sqrt(bot.vx * bot.vx + bot.vy * bot.vy);
    if (speed > maxSpeed && speed > 0) {
      bot.vx *= maxSpeed / speed;
      bot.vy *= maxSpeed / speed;
    }
    bot.x += bot.vx * dt;
    bot.y += bot.vy * dt;
    bot.vx /= 1 + Player.movementFriction * dt;
    bot.vy /= 1 + Player.movementFriction * dt;

    final margin = bot.radius + 8;
    bot.x = bot.x.clamp(margin, worldSize - margin);
    bot.y = bot.y.clamp(margin, worldSize - margin);

    // Light farm so bots stay relevant vs sim growth.
    bot.radius = (bot.radius + dt * 1.1).clamp(14.0, _radiusCap * 0.85);
    bot.updatedAt = DateTime.now();
  }

  void _resolveHostBotCombat() {
    // Bot ↔ peer (sim/human poses): bots grow; peers stay (same as game v1).
    for (final bot in _bots.values) {
      for (final peer in _peers.values) {
        final dist = math.sqrt(
          math.pow(bot.x - peer.x, 2) + math.pow(bot.y - peer.y, 2),
        );
        if (bot.radius > peer.radius * 1.08 && dist < bot.radius * 0.82) {
          bot.radius =
              (bot.radius + peer.radius * 0.12).clamp(14.0, _radiusCap * 0.85);
        } else if (peer.radius > bot.radius * 1.08 &&
            dist < peer.radius * 0.82) {
          // Peer ate this bot — remove; population sync respawns.
          bot.radius = 0;
        }
      }
      // Host sim itself vs bots handled in _tickCombat.
    }
    _bots.removeWhere((_, bot) => bot.radius <= 0);
  }

  void _broadcastBotSnapshot() {
    final channel = _channel;
    final id = userId;
    if (channel == null || id == null || _roomEnded) return;

    final snapshot = BotSnapshot(
      hostId: id,
      bots: _bots.values
          .map(
            (bot) => BotSyncState(
              id: bot.id,
              displayName: bot.displayName,
              x: bot.x,
              y: bot.y,
              radius: bot.radius,
              activeSkin: bot.skin,
              accentHue: bot.accentHue,
              boost: bot.boost,
              shield: bot.shield,
            ),
          )
          .toList(),
    );
    channel.sendBroadcastMessage(
      event: 'bot_snapshot',
      payload: snapshot.toMap(),
    );
  }

  void _tickStatus(double dt) {
    _aliveSeconds += dt;
    if (_spawnProtection > 0) {
      _spawnProtection = math.max(0, _spawnProtection - dt);
    }
    if (_shieldRemaining > 0) {
      _shieldRemaining -= dt;
      _shield = _shieldRemaining > 0;
    } else {
      _shield = false;
    }

    if (_boostActiveRemaining > 0) {
      _boostActiveRemaining -= dt;
      _boostEnergy =
          (_boostActiveRemaining / Player.boostActiveDuration).clamp(0.0, 1.0);
      if (_boostActiveRemaining <= 0) {
        _boostActiveRemaining = 0;
        _boostEnergy = 0;
      }
    } else if (_boostEnergy < 1.0) {
      _boostEnergy =
          math.min(1.0, _boostEnergy + dt / Player.boostChargeDuration);
    }
  }

  bool get _isBoosting => _boostActiveRemaining > 0;

  void _tickAi(double dt) {
    _decisionTimer -= dt;
    if (_decisionTimer > 0) return;

    final interval = switch (_personality) {
      _SimPersonality.aggressive => 0.18 + _rng.nextDouble() * 0.22,
      _SimPersonality.farmer => 0.35 + _rng.nextDouble() * 0.35,
      _SimPersonality.cautious => 0.28 + _rng.nextDouble() * 0.3,
    };
    _decisionTimer = interval;

    final threat = _nearestThreat();
    final prey = _bestPrey();

    // Tehditten kaç
    if (threat != null) {
      final fleeWeight = switch (_personality) {
        _SimPersonality.cautious => 1.0,
        _SimPersonality.farmer => 0.85,
        _SimPersonality.aggressive => 0.55,
      };
      if (_rng.nextDouble() < fleeWeight) {
        _aimAwayFrom(threat.x, threat.y);
        _tryBoost(force: true);
        return;
      }
    }

    // Avla
    if (prey != null && _radius >= 30) {
      final huntChance = switch (_personality) {
        _SimPersonality.aggressive => 0.92,
        _SimPersonality.farmer => 0.45,
        _SimPersonality.cautious => 0.62,
      };
      if (_rng.nextDouble() < huntChance) {
        _aimToward(prey.x, prey.y, intercept: true, peer: prey);
        final dist = _distanceTo(prey.x, prey.y);
        if (dist < _radius * 6.5) _tryBoost();
        return;
      }
    }

    // Farm / dolaş — haritada rastgele hedef
    if (_rng.nextDouble() < 0.35 || (_aimX == 0 && _aimY == 0)) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final dist = 180 + _rng.nextDouble() * worldSize * 0.18;
      final tx = (_x + math.cos(angle) * dist).clamp(80.0, worldSize - 80);
      final ty = (_y + math.sin(angle) * dist).clamp(80.0, worldSize - 80);
      _aimToward(tx, ty);
    }

    // Ara sıra kalkan (gerçek oyuncu yeteneği trafiği)
    if (!_shield && _spawnProtection <= 0 && _rng.nextDouble() < 0.04) {
      _shield = true;
      _shieldRemaining = 2.2 + _rng.nextDouble() * 1.5;
    }
  }

  void _aimToward(
    double tx,
    double ty, {
    bool intercept = false,
    _PeerSnapshot? peer,
  }) {
    var dx = tx - _x;
    var dy = ty - _y;
    if (intercept && peer != null) {
      // Basit lead — peer son konumuna göre hafif tahmin
      dx += (peer.x - _x) * 0.08;
      dy += (peer.y - _y) * 0.08;
    }
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    _aimX = dx / len;
    _aimY = dy / len;
  }

  void _aimAwayFrom(double tx, double ty) {
    _aimToward(_x * 2 - tx, _y * 2 - ty);
  }

  void _tryBoost({bool force = false}) {
    if (_isBoosting || _boostEnergy < 1.0) return;
    if (!force && _rng.nextDouble() > 0.55) return;
    _boostActiveRemaining = Player.boostActiveDuration;
    _boostEnergy = 1.0;
  }

  void _tickPhysics(double dt) {
    final maxSpeed = Player.maxSpeedForRadius(_radius) *
        (_isBoosting ? Player.boostSpeedMultiplier : 1.0);
    final pull = 0.68 + _rng.nextDouble() * 0.22;
    _vx += _aimX * maxSpeed * pull * 14 * dt;
    _vy += _aimY * maxSpeed * pull * 14 * dt;

    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    if (speed > maxSpeed && speed > 0) {
      _vx *= maxSpeed / speed;
      _vy *= maxSpeed / speed;
    }

    _x += _vx * dt;
    _y += _vy * dt;
    _vx /= 1 + Player.movementFriction * dt;
    _vy /= 1 + Player.movementFriction * dt;

    final margin = _radius + 8;
    if (_x < margin) {
      _x = margin;
      _vx = _vx.abs();
    } else if (_x > worldSize - margin) {
      _x = worldSize - margin;
      _vx = -_vx.abs();
    }
    if (_y < margin) {
      _y = margin;
      _vy = _vy.abs();
    } else if (_y > worldSize - margin) {
      _y = worldSize - margin;
      _vy = -_vy.abs();
    }
  }

  void _tickCombat() {
    if (_spawnProtection > 0 || _shield) return;

    for (final peer in _peers.values) {
      final dist = _distanceTo(peer.x, peer.y);
      // Biz avladık
      if (_radius > peer.radius * 1.08 && dist < _radius * 0.82) {
        _grow(peer.radius * 0.12);
        continue;
      }
      // Bizi yediler
      if (peer.radius > _radius * 1.08 && dist < peer.radius * 0.82) {
        _respawn();
        return;
      }
    }

    for (final entry in _bots.entries.toList()) {
      final bot = entry.value;
      final dist = _distanceTo(bot.x, bot.y);
      if (_radius > bot.radius * 1.08 && dist < _radius * 0.82) {
        _grow(bot.radius * 0.12);
        // Host removes authoritatively; peers hide until next snapshot.
        _bots.remove(entry.key);
        continue;
      }
      if (bot.radius > _radius * 1.08 && dist < bot.radius * 0.82) {
        _respawn();
        return;
      }
    }
  }

  void _tickGrowth(double dt) {
    // Yiyecek farm simülasyonu — kişiliğe göre tempo
    _farmTimer += dt;
    final farmRate = switch (_personality) {
      _SimPersonality.farmer => 2.8,
      _SimPersonality.cautious => 2.1,
      _SimPersonality.aggressive => 1.55,
    };
    if (_farmTimer >= 1.0) {
      _farmTimer = 0;
      // Erken oyun daha hızlı, sonra yavaşlar (gerçek maça yakın)
      final early = _aliveSeconds < 90 ? 1.35 : 1.0;
      final lateSlow = _radius > 120 ? 0.55 : 1.0;
      _grow(farmRate * early * lateSlow * (0.7 + _rng.nextDouble() * 0.6));
    }
  }

  void _grow(double amount) {
    if (amount <= 0) return;
    _radius = (_radius + amount).clamp(Player.baseRadius * 0.7, _radiusCap);
  }

  void _respawn({bool initial = false}) {
    _x = worldSize * (0.15 + _rng.nextDouble() * 0.7);
    _y = worldSize * (0.15 + _rng.nextDouble() * 0.7);
    _radius = Player.baseRadius + _rng.nextDouble() * 4;
    _vx = 0;
    _vy = 0;
    final angle = _rng.nextDouble() * math.pi * 2;
    _aimX = math.cos(angle);
    _aimY = math.sin(angle);
    _boostEnergy = 0;
    _boostActiveRemaining = 0;
    _shield = false;
    _shieldRemaining = 0;
    _spawnProtection = initial ? 2.5 : Player.spawnProtectionDuration;
    _decisionTimer = 0;
    if (!initial) {
      debugPrint('Sim#$index respawned after elimination');
    }
  }

  _PeerSnapshot? _nearestThreat() =>
      _nearestThreatFor(_x, _y, _radius);

  _PeerSnapshot? _bestPrey() => _bestPreyFor(_x, _y, _radius);

  _PeerSnapshot? _nearestThreatFor(
    double x,
    double y,
    double radius, {
    String? ignoreBotId,
  }) {
    _PeerSnapshot? best;
    var bestDist = double.infinity;

    void consider(String id, double px, double py, double pr) {
      if (pr <= radius * 1.05) return;
      final dist = math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2));
      final range = radius * 7.5;
      if (dist < range && dist < bestDist) {
        best = _PeerSnapshot(
          id: id,
          x: px,
          y: py,
          radius: pr,
          updatedAt: DateTime.now(),
        );
        bestDist = dist;
      }
    }

    for (final peer in _peers.values) {
      consider(peer.id, peer.x, peer.y, peer.radius);
    }
    // Host sim is a threat to bots.
    if (ignoreBotId != null && userId != null) {
      consider(userId!, _x, _y, _radius);
    }
    for (final bot in _bots.values) {
      if (bot.id == ignoreBotId) continue;
      consider(bot.id, bot.x, bot.y, bot.radius);
    }
    return best;
  }

  _PeerSnapshot? _bestPreyFor(
    double x,
    double y,
    double radius, {
    String? ignoreBotId,
  }) {
    _PeerSnapshot? best;
    var bestScore = 0.0;

    void consider(String id, double px, double py, double pr) {
      if (pr >= radius * 0.92) return;
      final dist = math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2));
      final range = radius * 8.5;
      if (dist > range) return;
      final advantage = (radius - pr) / radius;
      final score = advantage / (1 + dist / radius);
      if (score > bestScore) {
        bestScore = score;
        best = _PeerSnapshot(
          id: id,
          x: px,
          y: py,
          radius: pr,
          updatedAt: DateTime.now(),
        );
      }
    }

    for (final peer in _peers.values) {
      consider(peer.id, peer.x, peer.y, peer.radius);
    }
    if (ignoreBotId != null && userId != null) {
      consider(userId!, _x, _y, _radius);
    }
    for (final bot in _bots.values) {
      if (bot.id == ignoreBotId) continue;
      consider(bot.id, bot.x, bot.y, bot.radius);
    }
    return best;
  }

  double _distanceTo(double x, double y) {
    final dx = x - _x;
    final dy = y - _y;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _broadcastState() {
    final channel = _channel;
    final id = userId;
    final name = displayName;
    if (channel == null || id == null || name == null || _roomEnded) return;

    final state = PlayerSyncState(
      id: id,
      displayName: name,
      x: _x,
      y: _y,
      radius: _radius,
      activeSkin: _skin,
      shield: _shield || _spawnProtection > 0,
      boost: _isBoosting,
      link: false,
      rankPoints: 25 + (index % 40) * 5,
    );
    channel.sendBroadcastMessage(
      event: 'player_state',
      payload: state.toMap(),
    );
  }

  Future<void> stop() async {
    _stopped = true;
    _tickTimer?.cancel();
    _tickTimer = null;
    _leaderSyncTimer?.cancel();
    _leaderSyncTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _peers.clear();
    _bots.clear();
    _forceBotAuthority = false;
    _botSnapshotAge = 0;

    final client = _client;
    final channel = _channel;
    final id = userId;
    final device = deviceId;
    final roomId = roomInstanceId;

    try {
      if (channel != null && id != null) {
        channel.sendBroadcastMessage(
          event: 'player_left',
          payload: {'id': id},
        );
        await client?.removeChannel(channel);
      }
    } catch (e) {
      debugPrint('Sim#$index leave channel: $e');
    }
    _channel = null;

    try {
      if (client != null && roomId != null) {
        await client.rpc(
          'leave_game_room',
          params: {'p_room_instance_id': roomId},
        );
      }
    } catch (e) {
      debugPrint('Sim#$index leave room: $e');
    }

    try {
      if (client != null && device != null) {
        await client.rpc(
          'release_player_session',
          params: {'p_device_id': device},
        );
      }
    } catch (e) {
      debugPrint('Sim#$index release session: $e');
    }

    try {
      await client?.dispose();
    } catch (_) {}

    _client = null;
    userId = null;
    roomInstanceId = null;
    roomInstanceNumber = null;
  }
}

class _PeerSnapshot {
  _PeerSnapshot({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
    required this.updatedAt,
  });

  final String id;
  final double x;
  final double y;
  final double radius;
  final DateTime updatedAt;
}

/// Lightweight shared-room bot pose used by load-test sims.
class _SimBot {
  _SimBot({
    required this.id,
    required this.displayName,
    required this.skin,
    required this.accentHue,
    required this.x,
    required this.y,
    required this.radius,
  });

  factory _SimBot.fromSync(BotSyncState state) {
    return _SimBot(
      id: state.id,
      displayName: state.displayName,
      skin: state.activeSkin,
      accentHue: state.accentHue,
      x: state.x,
      y: state.y,
      radius: state.radius,
    )
      ..boost = state.boost
      ..shield = state.shield;
  }

  final String id;
  String displayName;
  String skin;
  double accentHue;
  double x;
  double y;
  double radius;
  double vx = 0;
  double vy = 0;
  double aimX = 1;
  double aimY = 0;
  double decisionTimer = 0;
  bool boost = false;
  bool shield = false;
  DateTime updatedAt = DateTime.now();
}
