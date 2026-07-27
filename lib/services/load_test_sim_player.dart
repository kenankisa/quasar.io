import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';


import '../config/app_config.dart';
import '../game/components/player.dart';
import '../game/config/hardcore_rules.dart';
import '../game/config/room_config.dart';
import '../game/config/room_matchmaking.dart';
import '../game/models/bot_sync_state.dart';
import '../game/models/match_speech.dart';
import '../game/models/player_sync_state.dart';
import '../game/models/room_instance.dart';
import '../game/room_type.dart';
import '../models/cosmetic_item.dart';
import '../utils/bot_name.dart';
import '../utils/safe_debug.dart';

class LoadTestSimCredentials {
  LoadTestSimCredentials({
    required this.email,
    required this._password,
    this.userId,
    this.username,
  });

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

/// Where a sim client is deployed.
enum SimDeploymentMode {
  /// Isolated load-test rooms (normal / elite / unique).
  loadTest,

  /// Isolated Hardcore Arena Test singleton (`is_load_test`).
  arenaTest,

  /// Live Hardcore universe — grind HC points until the harness stops.
  gameTrial,
}

/// Tek bir gerçek Supabase istemcisi — ayrı hesap + oturum + oda + Realtime.
///
/// Hafif AI ile gerçek oyuncu gibi oynar: farm, avla, kaç, boost, büy belki
/// yenil / yeniden doğ; `player_state` + paylaşılan `bot_snapshot` +
/// `update_room_leader_radius` telefon istemcisiyle aynı protokolü üretir.
class LoadTestSimPlayer {
  LoadTestSimPlayer({
    required this.index,
    required RoomType roomType,
    required this.worldSize,
    this.onArenaEvent,
    SimDeploymentMode? mode,
  })  : _roomType = roomType,
        mode = mode ??
            (roomType == RoomType.hardcore
                ? SimDeploymentMode.arenaTest
                : SimDeploymentMode.loadTest);

  final int index;
  RoomType _roomType;
  RoomType get roomType => _roomType;
  double worldSize;
  final SimDeploymentMode mode;

  /// Arena Test / Game Trial harness: kill / victory lines for the admin log.
  final void Function(String message)? onArenaEvent;

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _tickTimer;
  Timer? _leaderSyncTimer;

  /// Isolated JWT — never use GoTrue signIn on the long-lived client (web
  /// BroadcastChannel would steal the admin session and credit diamonds to it).
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiresAt;
  Future<void>? _tokenRefreshInFlight;

  String? userId;
  String? displayName;
  String? roomInstanceId;
  int? roomInstanceNumber;
  String? deviceId;
  String? error;

  /// Online sim client. Game-trial career counts from auth→stop (training
  /// has no room_instance_id, so the old gate falsely showed 0/500).
  bool get isAlive {
    if (userId == null || error != null || _stopped) return false;
    if (_isGameTrial) return true;
    return !_roomEnded && (roomInstanceId != null || _queued);
  }

  /// Seated in a live room (not training / not between matches).
  bool get isSeated =>
      !_stopped &&
      !_queued &&
      roomInstanceId != null &&
      !_roomEnded;

  /// Waiting outside the Hardcore test arena (seat full).
  bool get isQueued => _queued && !_stopped;

  void _emitArenaEvent(String message) {
    final cb = onArenaEvent;
    if (cb == null || message.isEmpty) return;
    cb(message);
  }

  String get _label => displayName ?? 'Sim${index.toString().padLeft(3, '0')}';

  String _peerLabel(String id, {String? fallback}) {
    final peer = _peers[id];
    final name = peer?.displayName;
    if (name != null && name.isNotEmpty) return name;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  int? queuePosition;

  static const _tickHz = 12.0;
  static const _tickDt = 1.0 / _tickHz;

  /// Oyun Deneme (test) — sadece [SimDeploymentMode.gameTrial].
  /// Load-test / Arena Test bu çarpanları kullanmaz.
  static const _gtSpeedMul = 4.5;
  static const _gtFarmIntervalCompetitive = 0.04;
  static const _gtFarmIntervalHardcore = 0.04;
  static const _gtCompetitiveFarmBase = 90.0;
  static const _gtHardcoreFarmMul = 28.0;
  static const _gtBoostChargeScale = 0.10; // daha hızlı boost dolumu
  static const _gtSpawnProtectionSeconds = 0.35;
  /// Sunucu game_trial min-süre bypass varsa ~0; join + sync için kısa buffer.
  static const _gtCompetitiveMinAliveSeconds = 0.45;

  /// Normal/Elite/Unique load-test: zafer eşiğinin altında kal.
  static const _radiusCapLoadTest = 320.0;

  /// Hardcore (Arena Test): headroom for admin force-radius.
  /// Oyun Deneme live Hardcore: zafer 600 — 900'e şişmesin.
  static const _radiusCapHardcore = 900.0;
  static const _radiusCapGameTrialHardcore = 612.0;

  /// Isolated Arena Test harness only.
  bool get _isHardcoreTest => mode == SimDeploymentMode.arenaTest;

  /// Live Hardcore grind (Oyun Deneme) — real singleton + HC points.
  bool get _isGameTrial => mode == SimDeploymentMode.gameTrial;

  /// Hardcore combat / growth / victory path (test or live hardcore seat).
  bool get _isHardcorePlay =>
      _isHardcoreTest || (_isGameTrial && _roomType == RoomType.hardcore);

  /// Competitive live match (normal/elite/unique) during game trial.
  bool get _isGameTrialCompetitive =>
      _isGameTrial &&
      (_roomType == RoomType.normal ||
          _roomType == RoomType.elite ||
          _roomType == RoomType.unique);

  double get _competitiveVictoryRadius => 350;

  double get _radiusCap {
    if (_isGameTrial && _roomType == RoomType.hardcore) {
      // <6 canlı: softcap; arena açılınca zafer + küçük headroom.
      if (_aliveRealCount < HardcoreRules.liveVictoryMinAlive) {
        return HardcoreRules.liveLowPopRadiusCap;
      }
      return _radiusCapGameTrialHardcore;
    }
    if (_isHardcorePlay) return _radiusCapHardcore;
    if (_isGameTrialCompetitive) {
      return _competitiveVictoryRadius + 40;
    }
    return _radiusCapLoadTest;
  }

  /// Cumulative Hardcore wins claimed this session (Game Trial).
  int hardcoreWins = 0;

  int _gtDiamonds = 20;
  int _gtTrophies = 0;
  int _gtTrophySimple = 0;
  int _gtTrophyNormal = 0;
  int _gtTrophyElite = 0;
  int _gtTrophyUnique = 0;
  bool _gtTutorial = false;
  DateTime? _gtCooldownUntil;
  bool _gtTransitioning = false;
  /// Claim başarısız olursa hemen spam etmesin.
  double _gtWinRetryCooldown = 0;

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

  /// Hardcore PvP mass tracking (food vs player absorbs).
  double _massFromFood = 0;
  double _massFromPlayers = 0;
  double _commandPollTimer = 0;
  double? _forcedRadius;
  String? _forceAbsorbPreyId;

  bool _queued = false;
  Timer? _queuePollTimer;

  /// Hardcore AFK: accumulates while nearly still (mirrors match idle drain).
  double _idleSeconds = 0;

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

  /// Peer sightings (lossy under flood) ∪ harness DB member hint.
  int get _aliveRealCount {
    final fromPeers = 1 + _peers.length;
    if (!_isHardcorePlay) return fromPeers;
    final hint = HardcoreArenaAliveHint.populationHint;
    if (hint != null && hint > fromPeers) return hint;
    return fromPeers;
  }

  /// Arena Test: pause auto-PvP while filling / queue waiting.
  /// Softcap (~450) and size-600 victory follow live rules (6+ alive).
  bool get _hcHoldSeats =>
      _isHardcoreTest && HardcoreArenaAliveHint.shouldHoldSeatsForQueueTest;

  double _broadcastAccumulator = 0;

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
    if (_isHardcorePlay) return false;
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

    await _authenticate(minted);
    if (minted == null) {
      await _prepareProfile();
    } else if (minted.username != null && minted.username!.isNotEmpty) {
      displayName = minted.username;
    }
    if (_isGameTrial) {
      // Career starts in training/normal — don't claim a Hardcore seat yet.
      _roomType = RoomType.normal;
      worldSize = RoomConfig.forRoom(RoomType.normal).worldSize;
      await _claimSession();
      // Heartbeat before prepare — purge (~60–90s) can wipe the row while
      // mint/prepare RPCs backlog under multi-sim spawn.
      _startHeartbeat();
      await _prepareGameTrialPlayer();
      await _claimGameTrialDailyChest();
      await _refreshGameTrialProfile();
      // Career loop runs in background so admin spawn returns immediately.
      unawaited(_enterNextGameTrialMatch());
      return;
    }
    await _claimSession();
    _startHeartbeat();
    await _joinRoom();
    if (_queued) {
      // Seat full — stay outside; admit poll runs in background so more sims
      // can still be spawned (Arena Test up to 50).
      _startQueuePoll();
      return;
    }
    await _joinRealtime();
    _startGameplayLoop();
    _startLeaderRadiusSync();
  }

  Future<void> _authenticate(LoadTestSimCredentials? minted) async {
    if (minted == null) {
      throw StateError(
        'Sim#$index: minted credentials required. '
        'Run migration_load_test_sim_mint.sql (admin_mint_sim_player). '
        'Anonymous Auth is disabled for sim mint.',
      );
    }

    // Password grant over HTTP — does not touch GoTrue BroadcastChannel, so
    // the admin JWT (and diamond balance) stay isolated from every sim.
    final tokens = await _passwordGrantWithRetry(
      email: minted.email,
      password: minted.password,
      fallbackUserId: minted.userId,
    );
    minted.clearPassword();

    userId = tokens.userId;
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _accessTokenExpiresAt = tokens.expiresAt;

    await _client?.dispose();
    _client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      accessToken: _resolveSimAccessToken,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    safeDebugPrint('Sim#$index auth: isolated accessToken $userId');
  }

  Future<String?> _resolveSimAccessToken() async {
    await _ensureSimAccessTokenFresh();
    return _accessToken;
  }

  Future<void> _ensureSimAccessTokenFresh() async {
    final expiresAt = _accessTokenExpiresAt;
    final token = _accessToken;
    if (token == null || token.isEmpty) return;
    if (expiresAt != null &&
        expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 90)),
        )) {
      return;
    }
    final inflight = _tokenRefreshInFlight;
    if (inflight != null) {
      await inflight;
      return;
    }
    final future = _refreshSimAccessToken();
    _tokenRefreshInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_tokenRefreshInFlight, future)) {
        _tokenRefreshInFlight = null;
      }
    }
  }

  Future<void> _refreshSimAccessToken() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return;
    try {
      final tokens = await _authTokenRequest(
        body: {
          'refresh_token': refresh,
        },
        grantType: 'refresh_token',
      );
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken ?? refresh;
      _accessTokenExpiresAt = tokens.expiresAt;
    } catch (e) {
      debugPrint('Sim#$index token refresh failed: $e');
    }
  }

  Future<_SimAuthTokens> _passwordGrantWithRetry({
    required String email,
    required String password,
    String? fallbackUserId,
  }) async {
    const maxAttempts = 6;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final tokens = await _authTokenRequest(
          body: {
            'email': email,
            'password': password,
          },
          grantType: 'password',
        );
        if (tokens.userId == null || tokens.userId!.isEmpty) {
          if (fallbackUserId == null || fallbackUserId.isEmpty) {
            throw StateError('Sim#$index: password grant returned no user');
          }
          return _SimAuthTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: tokens.expiresAt,
            userId: fallbackUserId,
          );
        }
        return tokens;
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

  Future<_SimAuthTokens> _authTokenRequest({
    required Map<String, dynamic> body,
    required String grantType,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.supabaseUrl}/auth/v1/token',
    ).replace(queryParameters: {'grant_type': grantType});
    final response = await http.post(
      uri,
      headers: {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 429) {
      throw AuthApiException(
        'over_request_rate_limit',
        statusCode: '429',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        'Sim#$index auth $grantType failed '
        '(${response.statusCode}): ${response.body}',
      );
    }
    final map = jsonDecode(response.body);
    if (map is! Map) {
      throw StateError('Sim#$index: auth response not a map');
    }
    final access = map['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw StateError('Sim#$index: auth response missing access_token');
    }
    final expiresIn = (map['expires_in'] as num?)?.toInt() ?? 3600;
    final userMap = map['user'];
    String? uid;
    if (userMap is Map) {
      uid = userMap['id'] as String?;
    }
    return _SimAuthTokens(
      accessToken: access,
      refreshToken: map['refresh_token'] as String?,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      userId: uid,
    );
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
    Future<void> claimOnce() => _rpcWithNetworkRetry(
          'claim_player_session',
          () => _client!.rpc(
            'claim_player_session',
            params: {
              'p_device_id': deviceId,
              'p_room_type': roomType.name,
            },
          ),
        );

    try {
      await claimOnce();
    } catch (e) {
      // Web BroadcastChannel can briefly bind another device_id to this sim.
      if (!_isAlreadyActiveError(e)) rethrow;
      try {
        await _client!.rpc(
          'sim_reclaim_player_session',
          params: {
            'p_device_id': deviceId,
            'p_room_type': roomType.name,
          },
        );
      } catch (_) {
        // Migration not applied yet — retry claim; updated SQL allows takeover.
        await claimOnce();
      }
    }
  }

  bool _isAlreadyActiveError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('player_already_active');
  }

  Future<void> _joinRoom() async {
    if (_isHardcoreTest) {
      await _joinHardcoreTestUniverse();
      return;
    }
    if (_isGameTrial) {
      // Career entry is handled by [_enterNextGameTrialMatch].
      return;
    }
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

  Future<void> _prepareGameTrialPlayer() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc('prepare_game_trial_player');
    } catch (e) {
      debugPrint(
        'Sim#$index prepare_game_trial_player '
        '(run migration_game_trial_real_rules.sql): $e',
      );
      try {
        await client.rpc('sim_prepare_live_hardcore');
      } catch (_) {}
    }
  }

  /// Lobideki günlük hediye sandığı — test oyuncuları da ilk işte alsın.
  Future<void> _claimGameTrialDailyChest() async {
    final client = _client;
    if (client == null || _stopped) return;
    try {
      final response = await client.rpc(
        'claim_daily_lobby_chest',
        params: {'p_doubled': false},
      );
      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        if (map['ok'] == true) {
          final awarded = (map['awarded'] as num?)?.toInt();
          final diamonds = (map['diamonds'] as num?)?.toInt();
          if (diamonds != null) _gtDiamonds = diamonds;
          _emitArenaEvent(
            '$_label daily chest'
            '${awarded != null ? ' +$awarded♦' : ''}'
            ' → ♦$_gtDiamonds',
          );
          return;
        }
        final reason = map['reason']?.toString();
        if (reason == 'already_claimed') {
          _emitArenaEvent('$_label daily chest already claimed');
          return;
        }
      }
      _emitArenaEvent('$_label daily chest: $response');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already_claimed')) {
        _emitArenaEvent('$_label daily chest already claimed');
        return;
      }
      debugPrint('Sim#$index daily chest: $e');
      _emitArenaEvent('$_label daily chest failed: $e');
    }
  }

  Future<void> _refreshGameTrialProfile() async {
    final client = _client;
    final id = userId;
    if (client == null || id == null) return;
    try {
      final row = await client
          .from('profiles')
          .select(
            'diamonds, games_won, tutorial_completed, hardcore_points, '
            'hardcore_cooldown_until, trophy_wins_simple, trophy_wins_normal, '
            'trophy_wins_elite, trophy_wins_unique, username',
          )
          .eq('id', id)
          .maybeSingle();
      if (row == null) return;
      final map = Map<String, dynamic>.from(row);
      _gtDiamonds = (map['diamonds'] as num?)?.toInt() ?? _gtDiamonds;
      _gtTutorial = map['tutorial_completed'] == true ||
          ((map['games_won'] as num?)?.toInt() ?? 0) > 0;
      _gtTrophySimple = (map['trophy_wins_simple'] as num?)?.toInt() ?? 0;
      _gtTrophyNormal = (map['trophy_wins_normal'] as num?)?.toInt() ?? 0;
      _gtTrophyElite = (map['trophy_wins_elite'] as num?)?.toInt() ?? 0;
      _gtTrophyUnique = (map['trophy_wins_unique'] as num?)?.toInt() ?? 0;
      _gtTrophies = _gtTrophySimple +
          _gtTrophyNormal +
          _gtTrophyElite +
          _gtTrophyUnique;
      hardcoreWins = (map['hardcore_points'] as num?)?.toInt() ?? hardcoreWins;
      final cdRaw = map['hardcore_cooldown_until'] as String?;
      _gtCooldownUntil =
          cdRaw != null ? DateTime.tryParse(cdRaw)?.toUtc() : null;
      final name = map['username'] as String?;
      if (name != null && name.isNotEmpty) displayName = name;
    } catch (e) {
      debugPrint('Sim#$index refresh game-trial profile: $e');
    }
  }

  bool get _gtOnCooldown {
    final until = _gtCooldownUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now().toUtc());
  }

  Future<void> _waitGameTrialHardcoreCooldown() async {
    if (!_isGameTrial || _stopped) return;
    await _refreshGameTrialProfile();
    if (!_gtOnCooldown) return;

    final until = _gtCooldownUntil;
    if (until == null) return;

    var remaining = until.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return;

    _emitArenaEvent(
      '$_label HC cooldown ${remaining.inSeconds}s',
    );
    while (remaining > Duration.zero && !_stopped) {
      final step = remaining > const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : remaining;
      await Future<void>.delayed(step);
      await _refreshGameTrialProfile();
      if (!_gtOnCooldown) return;
      final nextUntil = _gtCooldownUntil;
      if (nextUntil == null) return;
      remaining = nextUntil.difference(DateTime.now().toUtc());
    }
  }

  int get _gtUnlockNormal => 25;
  int get _gtUnlockElite => 100;
  int get _gtUnlockUnique => 200;

  RoomType? _pickGameTrialRoom() {
    // Hardcore when cups ready — each sim enters alone (no shared cooldown wait).
    if (_gtTrophies >= 10) {
      return RoomType.hardcore;
    }
    // Fill trophy slots toward 10; prefer higher tiers when unlocked.
    if (_gtDiamonds >= _gtUnlockUnique && _gtTrophyUnique < 3) {
      return RoomType.unique;
    }
    if (_gtDiamonds >= _gtUnlockElite && _gtTrophyElite < 3) {
      return RoomType.elite;
    }
    if (_gtDiamonds >= _gtUnlockNormal) {
      return RoomType.normal;
    }
    return null; // need training diamonds / tutorial
  }

  Future<void> _enterNextGameTrialMatch() async {
    if (_stopped || !_isGameTrial || _gtTransitioning) return;
    _gtTransitioning = true;
    // Training ends with _roomEnded=true for claim; must clear before the
    // next seat or the tick loop no-ops and sims never earn cups.
    _roomEnded = false;
    var reenter = false;
    try {
      await _refreshGameTrialProfile();
      if (_stopped) return;

      // 1) Eğitim evreni — gerçek yerel maç (bot’larla oyna, kazan).
      // Need tutorial + ≥25♦ (starter 20 → ~2 training wins at +3).
      var trainingAttempts = 0;
      while (!_stopped &&
          (!_gtTutorial || _gtDiamonds < _gtUnlockNormal)) {
        trainingAttempts++;
        if (trainingAttempts > 8) {
          throw StateError(
            'training_stuck: ♦$_gtDiamonds tutorial=$_gtTutorial',
          );
        }
        _emitArenaEvent(
          '$_label enters training match #$trainingAttempts '
          '(♦$_gtDiamonds tutorial=$_gtTutorial)',
        );
        await _playTrainingMatch();
        _roomEnded = false;
        await _refreshGameTrialProfile();
        if (!_gtTutorial || _gtDiamonds < _gtUnlockNormal) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      }
      if (_stopped) return;

      await _waitGameTrialHardcoreCooldown();

      final next = _pickGameTrialRoom();
      if (next == null) {
        await _playTrainingMatch();
        _roomEnded = false;
        await _refreshGameTrialProfile();
        reenter = !_stopped;
        return;
      }

      _roomType = next;
      worldSize = RoomConfig.forRoom(next).worldSize;
      _roomEnded = false;
      try {
        await _claimSession();
      } catch (e) {
        debugPrint('Sim#$index re-claim session for ${next.name}: $e');
      }
      _emitArenaEvent(
        '$_label joins ${next.name} match '
        '(♦$_gtDiamonds, cups $_gtTrophies/10)',
      );

      if (next == RoomType.hardcore) {
        await _joinLiveHardcoreUniverse();
        if (!_queued) {
          try {
            await _client?.rpc(
              'analytics_begin_play_session',
              params: {'p_room_type': 'hardcore'},
            );
          } catch (_) {}
        }
      } else {
        await _joinLiveCompetitiveRoom(next);
        try {
          await _client?.rpc(
            'analytics_begin_play_session',
            params: {'p_room_type': next.name},
          );
        } catch (_) {}
      }
      if (_stopped) return;
      if (_queued) {
        _startQueuePoll();
        return;
      }
      // Seat taken — clear end flag again in case join paths set it.
      _roomEnded = false;
      await _joinRealtime();
      _startGameplayLoop();
      _startLeaderRadiusSync();
    } catch (e) {
      debugPrint('Sim#$index game-trial enter failed: $e');
      _emitArenaEvent('$_label enter failed: $e');
      if (!_stopped) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        reenter = !_stopped;
      }
    } finally {
      _gtTransitioning = false;
    }
    // Re-enter only after clearing the gate — otherwise unawaited recursion
    // hits `_gtTransitioning` and the career silently dies.
    if (reenter && !_stopped) {
      unawaited(_enterNextGameTrialMatch());
    }
  }

  /// Eğitim: gerçek oyun gibi bot’larla büyü, kazan, ödül al.
  Future<void> _playTrainingMatch() async {
    final client = _client;
    if (client == null || _stopped) return;

    _tickTimer?.cancel();
    _tickTimer = null;
    _leaderSyncTimer?.cancel();
    _leaderSyncTimer = null;

    _roomType = RoomType.simple;
    worldSize = RoomConfig.forRoom(RoomType.simple).worldSize;
    roomInstanceId = null;
    roomInstanceNumber = null;
    _queued = false;
    _roomEnded = false;
    _peers.clear();
    _bots.clear();
    _aliveSeconds = 0;
    _massFromFood = 0;
    _massFromPlayers = 0;
    _respawn(initial: true);

    // Game-trial: no session-age wait — each sim farms + claims on its own JWT.
    DateTime? sessionStarted;
    try {
      await client.rpc(
        'analytics_begin_play_session',
        params: {'p_room_type': 'simple'},
      );
      sessionStarted = DateTime.now().toUtc();
    } catch (e) {
      _emitArenaEvent('$_label training session: $e');
      // One quick retry (server may still have old cooldown SQL).
      if (!_stopped) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        try {
          await client.rpc(
            'analytics_begin_play_session',
            params: {'p_room_type': 'simple'},
          );
          sessionStarted = DateTime.now().toUtc();
        } catch (e2) {
          _emitArenaEvent('$_label training session retry: $e2');
        }
      }
    }

    if (sessionStarted == null) {
      _emitArenaEvent('$_label training aborted — no play session');
      return;
    }

    // Local training bots (no Realtime channel) so farm + absorb feel real.
    _forceBotAuthority = true;
    _syncHostBotPopulation();
    _startGameplayLoop();

    // Test: eğitim anında 200 — sandık + starter elmasla hızlı Normal kilidi.
    const trainVictory = 200.0;
    _radius = trainVictory;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (_stopped) return;

    _tickTimer?.cancel();
    _tickTimer = null;
    _forceBotAuthority = false;
    _bots.clear();
    _roomEnded = true;

    if (_stopped) return;

    final wallSecs =
        DateTime.now().toUtc().difference(sessionStarted).inSeconds;

    var claimed = false;
    for (var attempt = 1; attempt <= 4; attempt++) {
      if (_stopped) return;
      try {
        final response = await client.rpc(
          'apply_match_result',
          params: {
            'p_room_type': 'simple',
            'p_placement': 1,
            'p_eliminated': false,
            'p_room_instance_id': null,
          },
        );
        if (response is num) {
          _gtDiamonds = response.toInt();
        } else if (response is Map && response['diamonds'] != null) {
          _gtDiamonds = (response['diamonds'] as num).toInt();
        }
        _gtTutorial = true;
        claimed = true;
        _emitArenaEvent(
          '$_label training victory '
          '(size ${_radius.round()}, ${wallSecs}s, ♦$_gtDiamonds)',
        );
        break;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if ((msg.contains('match_too_short') ||
                msg.contains('reward_cooldown') ||
                msg.contains('play_session')) &&
            attempt < 4) {
          _emitArenaEvent(
            '$_label training claim retry $attempt/4 — run SQL exemption',
          );
          await Future<void>.delayed(
            Duration(milliseconds: 350 * attempt),
          );
          continue;
        }
        _emitArenaEvent('$_label training claim failed: $e');
        break;
      }
    }

    if (!claimed) {
      _emitArenaEvent('$_label training claim gave up — diamonds unchanged');
    }

    try {
      await client.rpc(
        'analytics_end_play_session',
        params: {'p_room_type': 'simple'},
      );
    } catch (_) {}
  }

  Future<void> _joinLiveCompetitiveRoom(RoomType type) async {
    final response = await _rpcWithNetworkRetry(
      'join_game_room',
      () => _client!.rpc(
        'join_game_room',
        params: {'p_room_type': type.name},
      ),
    );
    if (response == null) {
      throw StateError('Sim#$index: join_game_room($type) empty');
    }
    final room = RoomInstance.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    roomInstanceId = room.id;
    roomInstanceNumber = room.instanceNumber;
    _queued = false;
    queuePosition = null;
    _respawn(initial: true);
  }

  Future<void> _joinLiveHardcoreUniverse() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (_stopped) return;
      try {
        final response = await _rpcWithNetworkRetry(
          'join_hardcore_universe',
          () => _client!.rpc('join_hardcore_universe'),
        );
        if (response == null) {
          throw StateError('Sim#$index: join_hardcore_universe empty');
        }
        final map = Map<String, dynamic>.from(response as Map);
        if (map['queued'] == true) {
          _queued = true;
          queuePosition = (map['position'] as num?)?.toInt();
          debugPrint(
            'Sim#$index live hardcore queued'
            '${queuePosition != null ? ' at #$queuePosition' : ''}',
          );
          return;
        }
        _queued = false;
        queuePosition = null;
        final room = RoomInstance.fromJson(map);
        roomInstanceId = room.id;
        roomInstanceNumber = room.instanceNumber;
        _respawn(initial: true);
        return;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (_isGameTrial &&
            msg.contains('hardcore_cooldown') &&
            attempt < 7) {
          await _waitGameTrialHardcoreCooldown();
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _joinHardcoreTestUniverse() async {
    final response = await _rpcWithNetworkRetry(
      'join_hardcore_test_universe',
      () => _client!.rpc('join_hardcore_test_universe'),
    );
    if (response == null) {
      throw StateError('Sim#$index: join_hardcore_test_universe empty');
    }
    final map = Map<String, dynamic>.from(response as Map);
    if (map['queued'] == true) {
      _queued = true;
      queuePosition = (map['position'] as num?)?.toInt();
      debugPrint(
        'Sim#$index hardcore test queued'
        '${queuePosition != null ? ' at #$queuePosition' : ''}',
      );
      return;
    }
    _queued = false;
    queuePosition = null;
    final room = RoomInstance.fromJson(map);
    roomInstanceId = room.id;
    roomInstanceNumber = room.instanceNumber;
    _respawn(initial: true);
  }

  void _startQueuePoll() {
    _queuePollTimer?.cancel();
    _queuePollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollHardcoreAdmit());
    });
    unawaited(_pollHardcoreAdmit());
  }

  Future<void> _pollHardcoreAdmit() async {
    if (_stopped || !_queued || _client == null) return;
    try {
      final status = await _client!.rpc(
        _isGameTrial
            ? 'get_hardcore_queue_status'
            : 'get_hardcore_test_queue_status',
      );
      if (status is! Map) return;
      final map = Map<String, dynamic>.from(status);
      final queued = map['queued'] == true || map['status'] == 'queued';
      if (queued) {
        queuePosition = (map['position'] as num?)?.toInt() ?? queuePosition;
        return;
      }
      final admitted = map['admitted'] == true ||
          map['status'] == 'admitted' ||
          map['room_instance_id'] != null;
      if (admitted) {
        final room = RoomInstance.fromJson(map);
        roomInstanceId = room.id;
        roomInstanceNumber = room.instanceNumber;
        _queued = false;
        queuePosition = null;
        _queuePollTimer?.cancel();
        _queuePollTimer = null;
        _roomEnded = false;
        _respawn(initial: true);
        if (_isGameTrial) {
          try {
            await _client?.rpc(
              'analytics_begin_play_session',
              params: {'p_room_type': 'hardcore'},
            );
          } catch (_) {}
        }
        await _joinRealtime();
        _startGameplayLoop();
        _startLeaderRadiusSync();
        debugPrint(
          'Sim#$index hardcore ${_isGameTrial ? 'live' : 'test'} '
          'admitted → ${room.id}',
        );
      }
    } catch (e) {
      debugPrint('Sim#$index hardcore queue poll: $e');
    }
  }

  /// Admin harness: set local radius immediately (also served via command poll).
  void applyForcedRadius(double radius) {
    var target = radius.clamp(Player.baseRadius * 0.7, _radiusCap);
    // Same low-pop softcap as live Hardcore.
    if (_isHardcorePlay &&
        _aliveRealCount < HardcoreRules.liveVictoryMinAlive) {
      target = math.min(target, HardcoreRules.liveLowPopRadiusCap);
    }
    _forcedRadius = target;
    _radius = target;
  }

  /// Admin harness: predator absorbs [preyUserId] on next tick.
  void applyForceAbsorb(String preyUserId) {
    if (preyUserId.isEmpty || preyUserId == userId) return;
    _forceAbsorbPreyId = preyUserId;
  }

  double get radius => _radius;

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
              if (!state.alive) {
                _peers.remove(state.id);
                return;
              }
              _peers[state.id] = _PeerSnapshot(
                id: state.id,
                displayName: state.displayName,
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
            if (_roomEnded || _stopped) return;
            if (_isGameTrial) {
              _roomEnded = true;
              unawaited(_leaveMatchWithoutWin(reason: 'room_closed'));
            }
          },
        )
        .onBroadcast(
          event: 'universe_victory',
          callback: (payload) {
            // Hardcore stays open — only the winner leaves; peers keep playing.
            if (_isHardcorePlay) {
              final winnerId = payload['id'] as String?;
              if (winnerId != null) {
                _peers.remove(winnerId);
                if (winnerId == userId) {
                  _roomEnded = true;
                }
              }
              return;
            }
            if (_roomEnded || _stopped) return;
            final winnerId = payload['id'] as String?;
            // Oyun Deneme: peer zaferini YOK SAY — herkes kendi 350 claim'ini yapsın.
            // Aksi halde 1 kazanan + N kupasız çıkış → kimse ilerleyemiyor.
            if (_isGameTrialCompetitive) {
              if (winnerId != null && winnerId != userId) {
                _peers.remove(winnerId);
              }
              return;
            }
            _roomEnded = true;
            if (_isGameTrial) {
              if (winnerId == userId) {
                return;
              }
              unawaited(_leaveMatchWithoutWin(reason: 'peer_victory'));
            }
          },
        )
        .onBroadcast(
          event: 'hc_elim',
          callback: (payload) {
            if (!_isHardcorePlay || _stopped) return;
            final preyId = payload['prey_id'] as String?;
            if (preyId == null) return;
            if (preyId == userId) {
              _roomEnded = true;
              unawaited(_leaveHardcoreAfterElim());
              return;
            }
            _peers.remove(preyId);
          },
        )
        .onBroadcast(
          event: 'match_speech',
          callback: (payload) {
            if (!_isHardcorePlay || _stopped) return;
            try {
              final event = MatchSpeechEvent.fromMap(
                Map<String, dynamic>.from(payload),
              );
              if (event.kind != MatchSpeechKind.absorb) return;
              final preyId = event.preyId;
              if (preyId == null || preyId.isEmpty) return;
              if (preyId == userId) {
                _roomEnded = true;
                unawaited(_leaveHardcoreAfterElim());
                return;
              }
              _peers.remove(preyId);
            } catch (_) {}
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
    } on PostgrestException catch (e) {
      if (e.message.toLowerCase().contains('session_not_found')) {
        // Stale purge or mid-spawn race — re-claim instead of spamming.
        try {
          await _claimSession();
        } catch (reclaimError) {
          debugPrint('Sim#$index heartbeat re-claim: $reclaimError');
        }
      } else {
        debugPrint('Sim#$index heartbeat: $e');
      }
    } catch (e) {
      debugPrint('Sim#$index heartbeat: $e');
    }
    if (_stopped) return;
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
    // Game trial: sık sync — peak doğrulama + admin HUD için.
    // Diğer modlar: gerçek istemci ~5 sn; sim'leri biraz kaydır.
    final intervalSecs = _isGameTrial ? 1 : 5;
    final offsetMs = _isGameTrial ? (index % 8) * 40 : (800 + (index % 20) * 200);
    Future<void>.delayed(Duration(milliseconds: offsetMs), () {
      if (_stopped) return;
      unawaited(_syncLeaderRadius());
      _leaderSyncTimer = Timer.periodic(Duration(seconds: intervalSecs), (_) {
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

    // Oyun Deneme Hardcore: lider HUD softcap/zafer ile uyumlu kalsın.
    if (_isGameTrial && _roomType == RoomType.hardcore) {
      final cap = _aliveRealCount < HardcoreRules.liveVictoryMinAlive
          ? HardcoreRules.liveLowPopRadiusCap.round()
          : HardcoreRules.victoryRadius.round();
      leader = leader.clamp(25, cap);
    } else if (_isGameTrialCompetitive) {
      leader = leader.clamp(25, _competitiveVictoryRadius.round());
    }

    try {
      await client.rpc(
        'update_room_leader_radius',
        params: {
          'p_room_instance_id': roomId,
          'p_leader_radius': leader,
          'p_self_radius': _radius.round(),
        },
      );
    } catch (e) {
      debugPrint('Sim#$index leader_radius: $e');
    }
  }

  void _onTick() {
    if (_stopped || _roomEnded) return;
    _pruneStalePeers();
    if (_isHardcoreTest) {
      _commandPollTimer += _tickDt;
      if (_commandPollTimer >= 0.75) {
        _commandPollTimer = 0;
        unawaited(_pollHardcoreTestCommands());
      }
      _applyPendingForceAbsorb();
    }
    _tickBotHostFailover(_tickDt);
    _tickStatus(_tickDt);
    if (_isBotHost) {
      _tickHostBots(_tickDt);
    }
    _tickAi(_tickDt);
    _tickPhysics(_tickDt);
    _tickCombat();
    _tickGrowth(_tickDt);
    if (_isHardcorePlay) {
      _tickHardcoreAfk(_tickDt);
      _tickHardcoreLowPopSoftcap(_tickDt);
      _tickHardcoreVictory(_tickDt);
    } else if (_isGameTrialCompetitive) {
      _tickCompetitiveVictory(_tickDt);
    }
    // Hardcore: throttle poses — full 12Hz × N sims floods Realtime and
    // peers under-count → softcap stuck at 450 even with 6+ in the room.
    // Game-trial: faster poses so admins see real movement in live rooms.
    if (_isHardcorePlay) {
      _broadcastAccumulator += _tickDt;
      final poseInterval = _isGameTrial ? 0.10 : 0.28;
      if (_broadcastAccumulator >= poseInterval) {
        _broadcastAccumulator = 0;
        _broadcastState();
      }
    } else {
      _broadcastState();
    }
    if (_isBotHost) {
      _broadcastBotSnapshot();
    }
  }

  Future<void> _pollHardcoreTestCommands() async {
    final client = _client;
    if (client == null || _stopped || !_isHardcoreTest) return;
    try {
      final raw = await client.rpc('claim_hardcore_test_commands');
      if (raw is! List) return;
      for (final row in raw) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final kind = map['kind'] as String?;
        if (kind == 'set_radius') {
          final r = (map['radius'] as num?)?.toDouble();
          if (r != null) applyForcedRadius(r);
        } else if (kind == 'force_absorb') {
          final predator = map['predator_id'] as String?;
          final prey = map['prey_id'] as String?;
          if (predator == userId && prey != null) {
            applyForceAbsorb(prey);
          } else if (prey == userId) {
            _roomEnded = true;
            unawaited(_leaveHardcoreAfterElim());
          }
        }
      }
    } catch (e) {
      debugPrint('Sim#$index claim_hardcore_test_commands: $e');
    }
  }

  void _applyPendingForceAbsorb() {
    final preyId = _forceAbsorbPreyId;
    if (preyId == null) return;
    _forceAbsorbPreyId = null;
    final prey = _peers[preyId];
    final preyName = _peerLabel(preyId);
    final preyRadius = prey?.radius ?? 40.0;
    final gain = preyRadius * 0.85;
    _massFromPlayers += gain;
    _grow(gain);
    _peers.remove(preyId);
    final roomId = roomInstanceId;
    final client = _client;
    if (roomId != null && client != null) {
      unawaited(_applyKillRewardNoopSafe(client, roomId, preyId));
    }
    unawaited(_broadcastHardcoreElim(preyId));
    _emitArenaEvent('$_label → $preyName');
    debugPrint(
      'Sim#$index force-absorb $preyId (+$gain → r=${_radius.toStringAsFixed(1)})',
    );
  }

  /// Live Hardcore match-AFK tempo (idle → warning → mass drain).
  void _tickHardcoreAfk(double dt) {
    final speed = math.sqrt(_vx * _vx + _vy * _vy);
    final active = speed > 8 || _isBoosting || _spawnProtection > 0;
    if (active) {
      _idleSeconds = 0;
      return;
    }
    _idleSeconds += dt;
    final late = _radius >= HardcoreRules.afkLateGameRadius;
    final idleBefore = late
        ? HardcoreRules.matchIdleBeforeWarningLateSeconds
        : HardcoreRules.matchIdleBeforeWarningSeconds;
    if (_idleSeconds <
        idleBefore + HardcoreRules.matchWarningCountdownSeconds) {
      return;
    }
    final drainPerSec = late
        ? HardcoreRules.matchMassDrainLatePerSecond
        : HardcoreRules.matchMassDrainPerSecond;
    _radius = math.max(
      Player.baseRadius * 0.7,
      _radius - drainPerSec * dt,
    );
  }

  void _tickHardcoreLowPopSoftcap(double dt) {
    // Live + Oyun Deneme: < min-alive (6) iken ~450 tavan — tek başına 600 fetih yok.
    if (_aliveRealCount >= HardcoreRules.liveVictoryMinAlive) return;
    final soft = HardcoreRules.liveLowPopRadiusCap;
    if (_radius <= soft) return;
    final excess = _radius - soft;
    final drain = math.max(40.0, excess * 2.5) * dt;
    _radius = math.max(soft, _radius - drain);
    if (_forcedRadius != null && _forcedRadius! > soft) {
      _forcedRadius = soft;
    }
  }

  void _tickHardcoreVictory(double dt) {
    if (_roomEnded || _stopped) return;
    // Don't claim victory while seats must stay full for queue testing.
    if (_hcHoldSeats) return;
    if (_isGameTrial && _gtWinRetryCooldown > 0) {
      _gtWinRetryCooldown = math.max(0, _gtWinRetryCooldown - dt);
      return;
    }
    // Canlı kural: arena aktif olmadan (min 6 canlı) zafer yok.
    if (_aliveRealCount < HardcoreRules.liveVictoryMinAlive) return;

    // Oyun Deneme: 600'de kazan — 900 farm yok. Hafif stagger claim yarışını azaltır.
    if (_isGameTrial) {
      final readyAt =
          _gtCompetitiveMinAliveSeconds + (index % 10) * 0.55;
      if (_aliveSeconds < readyAt) return;
      if (_radius < HardcoreRules.victoryRadius) {
        _radius = HardcoreRules.victoryRadius;
      } else if (_radius > _radiusCapGameTrialHardcore) {
        _radius = _radiusCapGameTrialHardcore;
      }
    } else if (_radius < HardcoreRules.victoryRadius) {
      return;
    }
    _roomEnded = true;
    _emitArenaEvent(
      '$_label won (size ${HardcoreRules.victoryRadius.round()}, '
      'alive $_aliveRealCount)',
    );
    unawaited(_broadcastVictoryAndLeave());
  }

  void _tickCompetitiveVictory(double dt) {
    if (_roomEnded || _stopped || !_isGameTrialCompetitive) return;
    if (_gtWinRetryCooldown > 0) {
      _gtWinRetryCooldown = math.max(0, _gtWinRetryCooldown - dt);
      return;
    }
    // game_trial sunucu bypass (migration_game_trial_isolated_progress) →
    // min süre 0; yine de oda join + leader radius için kısa buffer.
    if (_aliveSeconds < _gtCompetitiveMinAliveSeconds) return;
    // Test: zafer boyutuna anında — farm bekleme yok.
    if (_radius < _competitiveVictoryRadius) {
      _radius = _competitiveVictoryRadius + 8;
    }
    _roomEnded = true;
    _emitArenaEvent(
      '$_label won ${_roomType.name} '
      '(size ${_competitiveVictoryRadius.round()})',
    );
    unawaited(_broadcastVictoryAndLeave());
  }

  double get _pvpMassFraction {
    final total = _massFromFood + _massFromPlayers;
    if (total <= 0) return 0;
    return (_massFromPlayers / total).clamp(0.0, 1.0);
  }

  Future<void> _broadcastVictoryAndLeave() async {
    final roomId = roomInstanceId;
    final client = _client;
    final id = userId;
    final channel = _channel;

    // Önce claim — sonra yayın. Eskiden önce universe_victory gidiyordu;
    // diğer game-trial sim'ler peer_victory ile kupasız çıkıyordu.
    var claimed = false;
    if (roomId != null && client != null) {
      final targetPeak = _roomType == RoomType.hardcore
          ? HardcoreRules.victoryRadius.round()
          : 350;
      // victory_bypass migration ile 1 sync yeter; yoksa kısa 2. deneme.
      final syncAttempts = _isGameTrial ? 2 : 1;
      for (var s = 0; s < syncAttempts; s++) {
        try {
          final syncRadius = _isGameTrial
              ? targetPeak
              : math.max(_radius.round(), targetPeak).clamp(25, 900);
          await client.rpc(
            'update_room_leader_radius',
            params: {
              'p_room_instance_id': roomId,
              'p_leader_radius': syncRadius,
              'p_self_radius': _radius.round(),
            },
          );
        } catch (e) {
          debugPrint('Sim#$index leader radius before win: $e');
        }
        if (s + 1 < syncAttempts) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }

      for (var attempt = 1; attempt <= 6; attempt++) {
        if (_stopped) return;
        try {
          if (_isGameTrial && _roomType == RoomType.hardcore) {
            // apply_match_result zinciri (play_session / peak / first_place)
            // denemede sık kırılıyor — doğrudan HC puanı yaz.
            final raw = await client.rpc(
              'game_trial_claim_hardcore_victory',
              params: {'p_room_instance_id': roomId},
            );
            claimed = true;
            if (raw is Map) {
              final pts = (raw['hardcore_points'] as num?)?.toInt();
              if (pts != null) hardcoreWins = pts;
              final dia = (raw['diamonds'] as num?)?.toInt();
              if (dia != null) _gtDiamonds = dia;
            } else {
              hardcoreWins++;
            }
            _emitArenaEvent(
              '$_label HC victory claimed → pts $hardcoreWins',
            );
          } else {
            await client.rpc(
              'apply_match_result',
              params: {
                'p_room_type': _roomType.name,
                'p_placement': 1,
                'p_eliminated': false,
                'p_room_instance_id': roomId,
              },
            );
            claimed = true;
            if (_isGameTrial) {
              await _refreshGameTrialProfile();
            }
          }
          break;
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (_isGameTrial &&
              _roomType == RoomType.hardcore &&
              (msg.contains('game_trial_claim_hardcore_victory') ||
                  msg.contains('could not find') ||
                  msg.contains('pgrst202') ||
                  msg.contains('404'))) {
            // Migration henüz yok — sim_claim / apply_match_result dene.
            try {
              await client.rpc(
                'sim_claim_hardcore_victory',
                params: {'p_room_instance_id': roomId},
              );
              claimed = true;
              hardcoreWins++;
              _emitArenaEvent('$_label HC via sim_claim → pts $hardcoreWins');
              break;
            } catch (e2) {
              final m2 = e2.toString().toLowerCase();
              if (m2.contains('use_apply_match_result') ||
                  m2.contains('could not find') ||
                  m2.contains('pgrst202')) {
                try {
                  await client.rpc(
                    'apply_match_result',
                    params: {
                      'p_room_type': 'hardcore',
                      'p_placement': 1,
                      'p_eliminated': false,
                      'p_room_instance_id': roomId,
                    },
                  );
                  claimed = true;
                  hardcoreWins++;
                  await _refreshGameTrialProfile();
                  break;
                } catch (e3) {
                  debugPrint('Sim#$index HC fallback claim: $e3');
                  _emitArenaEvent(
                    '$_label HC claim failed — run '
                    'migration_game_trial_hardcore_claim.sql ($e3)',
                  );
                  break;
                }
              }
              _emitArenaEvent('$_label HC sim_claim failed: $e2');
              break;
            }
          }
          if (msg.contains('already_claimed')) {
            // Hardcore singleton: başka sim bu generation'ı aldı — çıkma, tekrar dene.
            if (_isGameTrial && _roomType == RoomType.hardcore && attempt < 6) {
              _emitArenaEvent(
                '$_label hardcore gen busy — retry $attempt/6',
              );
              await Future<void>.delayed(
                Duration(milliseconds: 350 + attempt * 200),
              );
              continue;
            }
            // Rekabetçi: bu maç için ödül zaten alınmış — kariyere devam.
            claimed = true;
            if (_isGameTrial) await _refreshGameTrialProfile();
            _emitArenaEvent('$_label win already claimed — continue');
            break;
          }
          if (_isGameTrial &&
              msg.contains('no_play_session') &&
              attempt < 6) {
            _emitArenaEvent(
              '$_label no_play_session — open session & retry',
            );
            try {
              await client.rpc(
                'analytics_begin_play_session',
                params: {'p_room_type': _roomType.name},
              );
            } catch (_) {}
            await Future<void>.delayed(
              Duration(milliseconds: 200 + attempt * 100),
            );
            continue;
          }
          final retryable = _isGameTrial &&
              (msg.contains('match_too_short') ||
                  msg.contains('reward_cooldown') ||
                  msg.contains('victory_not_verified')) &&
              attempt < 6;
          if (retryable) {
            _emitArenaEvent('$_label win claim retry $attempt/6 — $e');
            final waitMs = msg.contains('victory_not_verified')
                ? 500 + attempt * 200
                : 250 + attempt * 150;
            await Future<void>.delayed(Duration(milliseconds: waitMs));
            try {
              await client.rpc(
                'update_room_leader_radius',
                params: {
                  'p_room_instance_id': roomId,
                  'p_leader_radius': _isGameTrial
                      ? targetPeak
                      : math.max(_radius.round(), targetPeak).clamp(25, 900),
                  'p_self_radius': _radius.round(),
                },
              );
            } catch (_) {}
            continue;
          }
          debugPrint('Sim#$index apply_match_result (win): $e');
          _emitArenaEvent('$_label win claim failed: $e');
          if (_isGameTrial &&
              (msg.contains('hardcore_arena_inactive') ||
                  msg.contains('diamond_daily_cap') ||
                  msg.contains('reward_daily_limit') ||
                  msg.contains('training_daily_limit'))) {
            if (msg.contains('hardcore_arena_inactive')) {
              _emitArenaEvent(
                '$_label HC blocked — need '
                '${HardcoreRules.liveVictoryMinAlive}+ alive '
                '(have $_aliveRealCount)',
              );
            } else {
              _emitArenaEvent(
                '$_label economy gate — run '
                'migration_game_trial_economy_bypass.sql',
              );
            }
          }
          if (_isGameTrial && msg.contains('no_play_session')) {
            _emitArenaEvent(
              '$_label hardcore session gate — run '
              'migration_game_trial_hardcore_claim.sql',
            );
          }
          break;
        }
      }
    }

    if (!claimed && _isGameTrial) {
      // Claim olmadı — odadan çıkma; softcap/zafer boyutunda kal.
      _roomEnded = false;
      if (_roomType == RoomType.hardcore) {
        if (_aliveRealCount < HardcoreRules.liveVictoryMinAlive) {
          _radius = math.min(_radius, HardcoreRules.liveLowPopRadiusCap);
        } else {
          _radius = HardcoreRules.victoryRadius;
        }
      } else if (_isGameTrialCompetitive) {
        _radius = _competitiveVictoryRadius;
      }
      _gtWinRetryCooldown = 1.5;
      _emitArenaEvent(
        '$_label win claim deferred — keep playing '
        '(hardcore_claim / economy_bypass SQL)',
      );
      return;
    }

    // Claim OK → yayın + çıkış
    _broadcastDeathState();
    if (channel != null && id != null) {
      try {
        await channel.sendBroadcastMessage(
          event: 'universe_victory',
          payload: {
            'id': id,
            'name': displayName ?? 'Sim',
            'elapsed': _aliveSeconds.round(),
            'sender_id': id,
          },
        );
      } catch (_) {}
      try {
        channel.sendBroadcastMessage(
          event: 'player_left',
          payload: {'id': id},
        );
      } catch (_) {}
    }

    if (roomId != null && client != null) {
      final uid = userId;
      if (uid != null) {
        try {
          if (_roomType == RoomType.hardcore) {
            await client.rpc(
              'hardcore_release_member',
              params: {
                'p_room_instance_id': roomId,
                'p_user_id': uid,
              },
            );
          } else {
            // Sadece kendini çıkar — close_game_room diğer sim claim'lerini bozmasın.
            await client.rpc(
              'leave_game_room',
              params: {'p_room_instance_id': roomId},
            );
          }
        } catch (_) {
          try {
            await client.rpc(
              'leave_game_room',
              params: {'p_room_instance_id': roomId},
            );
          } catch (_) {}
        }
      }
    }

    if (_isGameTrial && !_stopped) {
      _emitArenaEvent(
        '$_label win claimed → next '
        '(HC pts $hardcoreWins, cups $_gtTrophies/10, ♦$_gtDiamonds)',
      );
      await _continueGameTrialAfterMatch();
      return;
    }
    await stop();
  }

  /// Tear down channel and continue career (cups → hardcore → cooldown).
  Future<void> _continueGameTrialAfterMatch() async {
    if (_stopped || !_isGameTrial) return;

    _tickTimer?.cancel();
    _tickTimer = null;
    _leaderSyncTimer?.cancel();
    _leaderSyncTimer = null;
    _queuePollTimer?.cancel();
    _queuePollTimer = null;

    final client = _client;
    final channel = _channel;
    try {
      if (channel != null) {
        await client?.removeChannel(channel);
      }
    } catch (_) {}
    _channel = null;
    _peers.clear();
    _bots.clear();
    roomInstanceId = null;
    roomInstanceNumber = null;
    _queued = false;
    queuePosition = null;
    _roomEnded = false;
    _forcedRadius = null;
    _forceAbsorbPreyId = null;
    _massFromFood = 0;
    _massFromPlayers = 0;
    _aliveSeconds = 0;
    _idleSeconds = 0;

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_stopped) return;
    await _enterNextGameTrialMatch();
  }

  void _pruneStalePeers() {
    // Hardcore test: keep presence longer — softcap must not flicker from
    // dropped broadcasts when many sims share one channel.
    final ttl = _isHardcorePlay
        ? const Duration(seconds: 20)
        : const Duration(seconds: 4);
    final cutoff = DateTime.now().subtract(ttl);
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
    final target =
        RoomMatchmaking.botCountFor(_aliveRealCount, roomType: roomType);
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
      final chargeDt = _isGameTrial ? dt / _gtBoostChargeScale : dt;
      _boostEnergy =
          math.min(1.0, _boostEnergy + chargeDt / Player.boostChargeDuration);
    }
  }

  bool get _isBoosting => _boostActiveRemaining > 0;

  void _tickAi(double dt) {
    if (_isHardcorePlay) {
      _tickHardcoreHuntAi(dt);
      return;
    }
    _decisionTimer -= dt;
    if (_decisionTimer > 0) return;

    // Oyun Deneme: daha sık karar + sürekli hedef — evrende kıpırdamayan
    // sim görünümünü kırar, maç temposunu yükseltir.
    final interval = _isGameTrial
        ? (0.05 + _rng.nextDouble() * 0.08)
        : switch (_personality) {
            _SimPersonality.aggressive => 0.18 + _rng.nextDouble() * 0.22,
            _SimPersonality.farmer => 0.35 + _rng.nextDouble() * 0.35,
            _SimPersonality.cautious => 0.28 + _rng.nextDouble() * 0.3,
          };
    _decisionTimer = interval;

    final threat = _nearestThreat();
    final prey = _bestPrey();

    // Tehditten kaç
    if (threat != null) {
      final fleeWeight = _isGameTrial
          ? 0.65
          : switch (_personality) {
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
    if (prey != null && _radius >= (_isGameTrial ? 24 : 30)) {
      final huntChance = _isGameTrial
          ? 0.95
          : switch (_personality) {
              _SimPersonality.aggressive => 0.92,
              _SimPersonality.farmer => 0.45,
              _SimPersonality.cautious => 0.62,
            };
      if (_rng.nextDouble() < huntChance) {
        _aimToward(prey.x, prey.y, intercept: true, peer: prey);
        final dist = _distanceTo(prey.x, prey.y);
        if (dist < _radius * (_isGameTrial ? 10.0 : 6.5)) {
          _tryBoost(force: _isGameTrial);
        }
        return;
      }
    }

    // Farm / dolaş — haritada rastgele hedef
    final retargetChance = _isGameTrial ? 0.98 : 0.35;
    if (_rng.nextDouble() < retargetChance || (_aimX == 0 && _aimY == 0)) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final dist = _isGameTrial
          ? 420 + _rng.nextDouble() * worldSize * 0.42
          : 180 + _rng.nextDouble() * worldSize * 0.18;
      final tx = (_x + math.cos(angle) * dist).clamp(80.0, worldSize - 80);
      final ty = (_y + math.sin(angle) * dist).clamp(80.0, worldSize - 80);
      _aimToward(tx, ty);
      if (_isGameTrial && _rng.nextDouble() < 0.42) {
        _tryBoost(force: true);
      }
    }

    // Ara sıra kalkan (gerçek oyuncu yeteneği trafiği)
    if (!_shield && _spawnProtection <= 0 && _rng.nextDouble() < 0.04) {
      _shield = true;
      _shieldRemaining = 2.2 + _rng.nextDouble() * 1.5;
    }
  }

  /// Hardcore Arena Test: hunt only after seats are full; fill phase = farm only.
  /// Game Trial live Hardcore: aggressive roam/hunt like a real player.
  void _tickHardcoreHuntAi(double dt) {
    if (_isGameTrial) {
      _tickGameTrialHardcoreAi(dt);
      return;
    }

    _decisionTimer -= dt;
    if (_decisionTimer > 0) return;
    _decisionTimer = 0.5 + _rng.nextDouble() * 0.45;

    final soft = HardcoreRules.liveLowPopRadiusCap;
    final nearCap = _radius >= soft - 8;

    // Seat-hold (fill / queue): wander / farm only — never chase peers.
    if (_hcHoldSeats) {
      if (_rng.nextDouble() < 0.6 || (_aimX == 0 && _aimY == 0)) {
        final angle = _rng.nextDouble() * math.pi * 2;
        final dist = nearCap
            ? 50 + _rng.nextDouble() * 100
            : 180 + _rng.nextDouble() * worldSize * 0.2;
        final tx = (_x + math.cos(angle) * dist).clamp(80.0, worldSize - 80);
        final ty = (_y + math.sin(angle) * dist).clamp(80.0, worldSize - 80);
        _aimToward(tx, ty);
      }
      return;
    }

    final threat = _nearestThreat();
    final prey = _bestPrey();
    final arenaOn = _aliveRealCount >= HardcoreRules.liveVictoryMinAlive;

    // Bigger threats: flee only if clearly outmatched.
    if (threat != null && threat.radius > _radius * 1.25) {
      _aimAwayFrom(threat.x, threat.y);
      if (_rng.nextDouble() < 0.4) _tryBoost(force: true);
      return;
    }

    // Rare hunts after fill — mostly farm so occupancy stays readable.
    if (prey != null && _rng.nextDouble() < 0.28) {
      _aimToward(prey.x, prey.y, intercept: true, peer: prey);
      final dist = _distanceTo(prey.x, prey.y);
      if (dist < _radius * 2.2 && _rng.nextDouble() < 0.2) {
        _tryBoost(force: true);
      }
      return;
    }

    if (_rng.nextDouble() < 0.55 || (_aimX == 0 && _aimY == 0)) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final dist = (!arenaOn && nearCap)
          ? 60 + _rng.nextDouble() * 120
          : 200 + _rng.nextDouble() * worldSize * 0.22;
      final tx = (_x + math.cos(angle) * dist).clamp(80.0, worldSize - 80);
      final ty = (_y + math.sin(angle) * dist).clamp(80.0, worldSize - 80);
      _aimToward(tx, ty);
    }
  }

  /// Oyun Deneme Hardcore: sürekli dolaş, avla, boost — sabit durma yok.
  void _tickGameTrialHardcoreAi(double dt) {
    _decisionTimer -= dt;
    if (_decisionTimer > 0) return;
    _decisionTimer = 0.06 + _rng.nextDouble() * 0.08;

    final threat = _nearestThreat();
    final prey = _bestPrey();

    if (threat != null && threat.radius > _radius * 1.08) {
      _aimAwayFrom(threat.x, threat.y);
      _tryBoost(force: true);
      return;
    }

    if (prey != null && _rng.nextDouble() < 0.92) {
      _aimToward(prey.x, prey.y, intercept: true, peer: prey);
      final dist = _distanceTo(prey.x, prey.y);
      if (dist < _radius * 10) _tryBoost(force: true);
      return;
    }

    final angle = _rng.nextDouble() * math.pi * 2;
    final dist = 480 + _rng.nextDouble() * worldSize * 0.45;
    final tx = (_x + math.cos(angle) * dist).clamp(80.0, worldSize - 80);
    final ty = (_y + math.sin(angle) * dist).clamp(80.0, worldSize - 80);
    _aimToward(tx, ty);
    if (_rng.nextDouble() < 0.48) _tryBoost(force: true);
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
    if (!force && _rng.nextDouble() > (_isGameTrial ? 0.78 : 0.55)) return;
    _boostActiveRemaining = Player.boostActiveDuration;
    _boostEnergy = 1.0;
  }

  void _tickPhysics(double dt) {
    final speedMul = _isGameTrial ? _gtSpeedMul : 1.0;
    final maxSpeed = Player.maxSpeedForRadius(_radius) *
        (_isBoosting ? Player.boostSpeedMultiplier : 1.0) *
        speedMul;
    final pull = _isGameTrial
        ? (1.2 + _rng.nextDouble() * 0.25)
        : (0.68 + _rng.nextDouble() * 0.22);
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
    // Hold all peer absorbs while filling or while queue must stay stable.
    if (_hcHoldSeats) return;

    // Arena Test: harder absorbs (need clear size lead + deep overlap).
    final sizeMul = _isHardcorePlay ? 1.28 : 1.05;
    final hitFrac = _isHardcorePlay ? 0.45 : 0.9;

    for (final peer in _peers.values.toList()) {
      final dist = _distanceTo(peer.x, peer.y);
      // Biz avladık
      if (_radius > peer.radius * sizeMul && dist < _radius * hitFrac) {
        final gain = _isHardcorePlay ? peer.radius * 0.55 : peer.radius * 0.12;
        if (_isHardcorePlay) {
          final preyName = peer.displayName;
          _massFromPlayers += gain;
          final roomId = roomInstanceId;
          final preyId = peer.id;
          final client = _client;
          if (roomId != null &&
              client != null &&
              !preyId.startsWith('bot_')) {
            unawaited(_applyKillRewardNoopSafe(client, roomId, preyId));
          }
          _peers.remove(peer.id);
          unawaited(_broadcastHardcoreElim(preyId));
          _emitArenaEvent('$_label → $preyName');
        }
        _grow(gain);
        continue;
      }
      // Bizi yediler
      if (peer.radius > _radius * sizeMul && dist < peer.radius * hitFrac) {
        if (_isHardcorePlay || _isGameTrialCompetitive) {
          _roomEnded = true;
          unawaited(_leaveHardcoreAfterElim());
          return;
        }
        _respawn();
        return;
      }
    }

    if (_isHardcorePlay) return;

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

  Future<void> _broadcastHardcoreElim(String preyId) async {
    final channel = _channel;
    final id = userId;
    final name = displayName;
    if (channel == null || id == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: 'hc_elim',
        payload: {
          'predator_id': id,
          'prey_id': preyId,
        },
      );
    } catch (_) {}
    // Flutter clients listen to match_speech absorb (same path as live play).
    if (name == null || name.isEmpty) return;
    try {
      await channel.sendBroadcastMessage(
        event: 'match_speech',
        payload: MatchSpeechEvent(
          playerId: id,
          playerName: name,
          text: 'Absorbed!',
          kind: MatchSpeechKind.absorb,
          preyId: preyId,
          preyName: 'Traveler',
        ).toMap(),
      );
    } catch (_) {}
  }

  Future<void> _leaveHardcoreAfterElim() async {
    if (_stopped) return;
    _roomEnded = true;
    _broadcastDeathState();
    final channel = _channel;
    final id = userId;
    if (channel != null && id != null) {
      try {
        channel.sendBroadcastMessage(
          event: 'player_left',
          payload: {'id': id},
        );
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final roomId = roomInstanceId;
    final client = _client;
    final uid = userId;
    if (roomId != null && client != null && uid != null) {
      // Real elim penalty + HC cooldown (hardcore) via apply_match_result.
      if (_isGameTrial) {
        try {
          await client.rpc(
            'apply_match_result',
            params: {
              'p_room_type': _roomType.name,
              'p_placement': null,
              'p_eliminated': true,
              'p_room_instance_id': roomId,
            },
          );
        } catch (e) {
          debugPrint('Sim#$index elim apply_match_result: $e');
        }
      }
      try {
        if (_roomType == RoomType.hardcore) {
          await client.rpc(
            'hardcore_release_member',
            params: {
              'p_room_instance_id': roomId,
              'p_user_id': uid,
            },
          );
        } else {
          await client.rpc(
            'leave_game_room',
            params: {'p_room_instance_id': roomId},
          );
        }
      } catch (_) {
        try {
          await client.rpc(
            'leave_game_room',
            params: {'p_room_instance_id': roomId},
          );
        } catch (_) {}
      }
    }
    if (_isGameTrial && !_stopped) {
      _emitArenaEvent('$_label elim → continue career');
      await _continueGameTrialAfterMatch();
      return;
    }
    await stop();
  }

  Future<void> _leaveMatchWithoutWin({required String reason}) async {
    if (_stopped || !_isGameTrial) return;
    _emitArenaEvent('$_label left ($reason)');
    final roomId = roomInstanceId;
    final client = _client;
    final uid = userId;
    if (roomId != null && client != null && uid != null) {
      try {
        await client.rpc(
          'leave_game_room',
          params: {'p_room_instance_id': roomId},
        );
      } catch (_) {}
    }
    await _continueGameTrialAfterMatch();
  }

  /// One final alive:false pose so human clients despawn this hole immediately.
  void _broadcastDeathState() {
    final channel = _channel;
    final id = userId;
    final name = displayName;
    if (channel == null || id == null || name == null) return;
    try {
      final state = PlayerSyncState(
        id: id,
        displayName: name,
        x: _x,
        y: _y,
        radius: _radius,
        activeSkin: _skin,
        shield: false,
        boost: false,
        rankPoints: 25 + (index % 40) * 5,
        alive: false,
      );
      channel.sendBroadcastMessage(
        event: 'player_state',
        payload: state.toMap(),
      );
    } catch (_) {}
  }

  Future<void> _applyKillRewardNoopSafe(
    SupabaseClient client,
    String roomId,
    String preyId,
  ) async {
    try {
      await client.rpc(
        'apply_hardcore_kill_reward',
        params: {
          'p_room_instance_id': roomId,
          'p_prey_user_id': preyId,
          'p_alive_count': _aliveRealCount,
        },
      );
    } catch (e) {
      debugPrint('Sim#$index kill reward: $e');
    }
    // Always free prey seat (live + test) — ghosts block the 20-cap.
    try {
      await client.rpc(
        'hardcore_release_member',
        params: {
          'p_room_instance_id': roomId,
          'p_user_id': preyId,
        },
      );
    } catch (e) {
      debugPrint('Sim#$index hardcore_release_member prey: $e');
    }
  }

  void _tickGrowth(double dt) {
    if (_isHardcorePlay) {
      _farmTimer += dt;
      // Arena Test: slow/watchable. Game Trial: hızlı elmas/kupa grind.
      final farmInterval =
          _isGameTrial ? _gtFarmIntervalHardcore : 1.05;
      if (_farmTimer < farmInterval) return;
      _farmTimer = 0;
      final arenaOn = _aliveRealCount >= HardcoreRules.liveVictoryMinAlive;
      final soft = HardcoreRules.liveLowPopRadiusCap;
      // Index bands create big/small fish so hunts happen.
      final tier = 1.0 + (index % 7) * 0.10;
      var rate = (arenaOn ? 2.4 : 1.7) * tier;
      if (_isGameTrial) {
        // Arena kapalıyken softcap; 6+ olunca 600'e koş.
        if (_aliveRealCount < HardcoreRules.liveVictoryMinAlive) {
          if (_radius >= HardcoreRules.liveLowPopRadiusCap) return;
        } else if (_radius >= HardcoreRules.victoryRadius) {
          return;
        }
        rate *= _gtHardcoreFarmMul;
        if (_aliveRealCount >= HardcoreRules.liveVictoryMinAlive &&
            _radius < HardcoreRules.victoryRadius) {
          rate = math.max(rate, 140);
        }
        if (arenaOn) rate *= 1.15;
      } else {
        // Live Hardcore food pop multiplier + late softcap.
        rate *= HardcoreRules.foodGrowthMultiplierForAlive(_aliveRealCount);
      }
      if (!_isGameTrial &&
          _radius >= HardcoreRules.liveLateFoodSoftcapRadius) {
        rate *= HardcoreRules.liveLateFoodSoftcapMultiplier;
      }
      if (_personality == _SimPersonality.aggressive) rate *= 1.12;
      if (_personality == _SimPersonality.farmer) rate *= 1.08;
      if (!arenaOn && _radius > soft - 40) {
        rate *= _isGameTrial ? 1.0 : 0.28;
      }
      // Contested arena: successful hunters still push to 600, but slower.
      if (arenaOn && _radius >= 280 && _pvpMassFraction >= 0.28) {
        rate *= 1.28;
      } else if (arenaOn && _radius >= 400) {
        rate *= 1.12;
      }
      _grow(rate * (0.7 + _rng.nextDouble() * 0.45));
      return;
    }

    // Yiyecek farm — game-trial: eğitim + rekabetçi maçlarda kupa için tempo.
    _farmTimer += dt;
    if (_isGameTrial &&
        (_isGameTrialCompetitive || _roomType == RoomType.simple)) {
      if (_farmTimer < _gtFarmIntervalCompetitive) return;
      _farmTimer = 0;
      var rate = switch (_personality) {
        _SimPersonality.farmer => _gtCompetitiveFarmBase * 1.15,
        _SimPersonality.cautious => _gtCompetitiveFarmBase * 1.05,
        _SimPersonality.aggressive => _gtCompetitiveFarmBase,
      };
      if (_roomType == RoomType.simple) {
        rate *= 2.0;
      } else {
        // Rekabetçi: tick'lerde 350 — snap öncesi tampon.
        if (_radius < _competitiveVictoryRadius) {
          rate = math.max(rate, 120);
        }
      }
      _grow(rate * (0.95 + _rng.nextDouble() * 0.35));
      return;
    }

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
    final before = _radius;
    var next = (_radius + amount).clamp(Player.baseRadius * 0.7, _radiusCap);
    // Softcap (~450) only under min-alive — at 6+ they push toward 600.
    if (_isHardcorePlay &&
        _aliveRealCount < HardcoreRules.liveVictoryMinAlive) {
      next = math.min(next, HardcoreRules.liveLowPopRadiusCap);
    }
    _radius = next;
    if (_isHardcorePlay && _forcedRadius == null) {
      final delta = _radius - before;
      // Small farm ticks count as food mass; combat/force already tag PvP.
      if (delta > 0 && amount < 8) {
        _massFromFood += delta;
      }
    }
  }

  void _respawn({bool initial = false}) {
    _x = worldSize * (0.15 + _rng.nextDouble() * 0.7);
    _y = worldSize * (0.15 + _rng.nextDouble() * 0.7);
    if (_isHardcorePlay && initial) {
      // Mild size spread — avoids instant wipe while seats are still filling.
      final band = index % 5;
      _radius = switch (band) {
        0 => 22 + _rng.nextDouble() * 6,
        1 => 26 + _rng.nextDouble() * 8,
        2 => 32 + _rng.nextDouble() * 10,
        3 => 40 + _rng.nextDouble() * 12,
        _ => 48 + _rng.nextDouble() * 14,
      };
    } else {
      _radius = Player.baseRadius + _rng.nextDouble() * 4;
    }
    _vx = 0;
    _vy = 0;
    final angle = _rng.nextDouble() * math.pi * 2;
    _aimX = math.cos(angle);
    _aimY = math.sin(angle);
    _boostEnergy = 0;
    _boostActiveRemaining = 0;
    _shield = false;
    _shieldRemaining = 0;
    _spawnProtection = _isHardcorePlay
        // Arena Test: long shield while seats fill.
        // Game Trial: kısa koruma — test temposu için hemen avlanabilsinler.
        ? (_isGameTrial
            ? _gtSpawnProtectionSeconds
            : math.max(HardcoreRules.liveSpawnProtectionSeconds, 45))
        : (initial
            ? (_isGameTrial ? 0.8 : 2.5)
            : Player.spawnProtectionDuration);
    _idleSeconds = 0;
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

    void consider(String id, double px, double py, double pr, {String name = ''}) {
      if (pr <= radius * 1.05) return;
      final dist = math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2));
      final range = radius * 7.5;
      if (dist < range && dist < bestDist) {
        best = _PeerSnapshot(
          id: id,
          displayName: name,
          x: px,
          y: py,
          radius: pr,
          updatedAt: DateTime.now(),
        );
        bestDist = dist;
      }
    }

    for (final peer in _peers.values) {
      consider(peer.id, peer.x, peer.y, peer.radius, name: peer.displayName);
    }
    // Host sim is a threat to bots.
    if (ignoreBotId != null && userId != null) {
      consider(userId!, _x, _y, _radius, name: displayName ?? '');
    }
    for (final bot in _bots.values) {
      if (bot.id == ignoreBotId) continue;
      consider(bot.id, bot.x, bot.y, bot.radius, name: bot.displayName);
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
    final huntRange = _isHardcorePlay ? radius * 11.0 : radius * 8.5;
    // Arena Test: only chase clearly smaller prey (~22%+ size lead).
    final maxPreyFrac = _isHardcorePlay ? 0.78 : 0.92;

    void consider(String id, double px, double py, double pr, {String name = ''}) {
      if (pr >= radius * maxPreyFrac) return;
      final dist = math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2));
      if (dist > huntRange) return;
      final advantage = (radius - pr) / radius;
      final score = advantage / (1 + dist / radius);
      if (score > bestScore) {
        bestScore = score;
        best = _PeerSnapshot(
          id: id,
          displayName: name,
          x: px,
          y: py,
          radius: pr,
          updatedAt: DateTime.now(),
        );
      }
    }

    for (final peer in _peers.values) {
      consider(peer.id, peer.x, peer.y, peer.radius, name: peer.displayName);
    }
    if (ignoreBotId != null && userId != null) {
      consider(userId!, _x, _y, _radius, name: displayName ?? '');
    }
    // Hardcore: no bots — only real peers.
    if (!_isHardcorePlay) {
      for (final bot in _bots.values) {
        if (bot.id == ignoreBotId) continue;
        consider(bot.id, bot.x, bot.y, bot.radius, name: bot.displayName);
      }
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
      rankPoints: 25 + (index % 40) * 5,
    );
    channel.sendBroadcastMessage(
      event: 'player_state',
      payload: state.toMap(),
    );
  }

  Future<void> stop() async {
    _stopped = true;
    _queued = false;
    queuePosition = null;
    _queuePollTimer?.cancel();
    _queuePollTimer = null;
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
      if (_isHardcoreTest && client != null) {
        await client.rpc('leave_hardcore_test_queue');
      }
      if (_isGameTrial && client != null) {
        await client.rpc('leave_hardcore_queue');
      }
    } catch (_) {}

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
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiresAt = null;
    _tokenRefreshInFlight = null;
    userId = null;
    roomInstanceId = null;
    roomInstanceNumber = null;
  }
}

class _SimAuthTokens {
  const _SimAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String? userId;
}

class _PeerSnapshot {
  _PeerSnapshot({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
    required this.updatedAt,
    this.displayName = '',
  });

  final String id;
  final String displayName;
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
