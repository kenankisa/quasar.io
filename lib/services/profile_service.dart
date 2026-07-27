import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/skill_tree_config.dart';
import '../game/room_type.dart';
import '../utils/player_name.dart';
import '../utils/player_rank.dart';
import 'admin_access.dart';
import 'auth_service.dart';

enum ProfileUpdateError {
  usernameTaken,
  usernameReserved,
  invalidUsername,
  notAuthenticated,
  unknown,
}

class ProfileUpdateException implements Exception {
  const ProfileUpdateException(this.error, [this.message]);

  final ProfileUpdateError error;
  final String? message;

  @override
  String toString() => message ?? error.name;
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.diamonds,
    required this.gamesWon,
    this.rankPoints = 0,
    this.tutorialCompleted = false,
    required this.activeSkin,
    this.peakDiamonds = 0,
    this.skillLevels = const {},
    this.trophyWinsSimple = 0,
    this.trophyWinsNormal = 0,
    this.trophyWinsElite = 0,
    this.trophyWinsUnique = 0,
    this.hardcorePoints = 0,
    this.hardcoreCooldownUntil,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final diamonds = _asInt(json['diamonds']);
    final peak = _asInt(json['peak_diamonds'], diamonds);
    return PlayerProfile(
      id: json['id'] as String,
      username: clampPlayerName(
        json['username'] as String? ?? 'Cosmic Void',
      ),
      avatarUrl: json['avatar_url'] as String?,
      diamonds: diamonds,
      gamesWon: _asInt(json['games_won']),
      rankPoints: _asInt(json['rank_points']),
      tutorialCompleted: _asBool(json['tutorial_completed']),
      activeSkin: json['active_skin'] as String? ?? 'default',
      peakDiamonds: peak < diamonds ? diamonds : peak,
      skillLevels: _parseSkillTree(json['skill_tree']),
      trophyWinsSimple: _asInt(json['trophy_wins_simple']).clamp(0, 1),
      trophyWinsNormal: _asInt(json['trophy_wins_normal']).clamp(0, 3),
      trophyWinsElite: _asInt(json['trophy_wins_elite']).clamp(0, 3),
      trophyWinsUnique: _asInt(json['trophy_wins_unique']).clamp(0, 3),
      hardcorePoints: _asInt(json['hardcore_points']),
      hardcoreCooldownUntil: _readDateTime(json['hardcore_cooldown_until']),
    );
  }

  static DateTime? _readDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  static int _asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _asBool(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      if (v == 'true' || v == 't' || v == '1') return true;
      if (v == 'false' || v == 'f' || v == '0') return false;
    }
    return fallback;
  }

  static Map<String, int> _parseSkillTree(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((key, value) {
      final id = SkillNodeId.tryParse('$key');
      if (id == null) return;
      final level = value is int
          ? value
          : int.tryParse('$value') ?? 0;
      out[id.key] = AbilityLoadout.clampLevel(level);
    });
    return Map.unmodifiable(out);
  }

  final String id;
  final String username;
  final String? avatarUrl;
  final int diamonds;
  final int gamesWon;

  /// Weighted 1st-place score used for star ranks.
  final int rankPoints;

  /// Training (simple) 1st place completed — unlocks ranked rooms.
  final bool tutorialCompleted;
  final String activeSkin;
  final int peakDiamonds;
  final Map<String, int> skillLevels;

  /// Per-universe 1st-place cups (lobby). Caps: simple 1, others 3.
  final int trophyWinsSimple;
  final int trophyWinsNormal;
  final int trophyWinsElite;
  final int trophyWinsUnique;

  /// Hardcore victories (1 point = 1 hardcore win).
  final int hardcorePoints;

  /// Cannot join hardcore until this UTC time (after win or elimination).
  final DateTime? hardcoreCooldownUntil;

  static const hardcoreTrophyRequirement =
      RoomTypeLobby.hardcoreTrophyRequirement;

  bool get isHardcoreOnCooldown {
    final until = hardcoreCooldownUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now().toUtc());
  }

  Duration? get hardcoreCooldownRemaining {
    final until = hardcoreCooldownUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now().toUtc());
    return left.isNegative ? null : left;
  }

  int trophyWinsFor(RoomType type) => switch (type) {
        RoomType.simple => trophyWinsSimple,
        RoomType.normal => trophyWinsNormal,
        RoomType.elite => trophyWinsElite,
        RoomType.unique => trophyWinsUnique,
        RoomType.hardcore => 0,
      };

  int get totalUniverseTrophies =>
      trophyWinsSimple +
      trophyWinsNormal +
      trophyWinsElite +
      trophyWinsUnique;

  /// Hardcore arena unlock — all universe cups collected.
  bool get hasHardcoreTrophyUnlock =>
      totalUniverseTrophies >= hardcoreTrophyRequirement;

  int get earnedSkillPoints => AbilityLoadout.earnedSp(peakDiamonds);
  int get spentSkillPoints => AbilityLoadout.spentSp(skillLevels);
  int get availableSkillPoints => AbilityLoadout.availableSp(
        peakDiamonds: peakDiamonds,
        levels: skillLevels,
      );

  AbilityLoadout get abilityLoadout =>
      AbilityLoadout.fromLevels(skillLevels);

  int skillLevel(SkillNodeId id) =>
      AbilityLoadout.levelOf(skillLevels, id);

  PlayerProfile copyWith({
    String? username,
    String? avatarUrl,
    int? diamonds,
    int? gamesWon,
    int? rankPoints,
    bool? tutorialCompleted,
    String? activeSkin,
    int? peakDiamonds,
    Map<String, int>? skillLevels,
    int? trophyWinsSimple,
    int? trophyWinsNormal,
    int? trophyWinsElite,
    int? trophyWinsUnique,
    int? hardcorePoints,
    DateTime? hardcoreCooldownUntil,
  }) {
    return PlayerProfile(
      id: id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      diamonds: diamonds ?? this.diamonds,
      gamesWon: gamesWon ?? this.gamesWon,
      rankPoints: rankPoints ?? this.rankPoints,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      activeSkin: activeSkin ?? this.activeSkin,
      peakDiamonds: peakDiamonds ?? this.peakDiamonds,
      skillLevels: skillLevels ?? this.skillLevels,
      trophyWinsSimple: trophyWinsSimple ?? this.trophyWinsSimple,
      trophyWinsNormal: trophyWinsNormal ?? this.trophyWinsNormal,
      trophyWinsElite: trophyWinsElite ?? this.trophyWinsElite,
      trophyWinsUnique: trophyWinsUnique ?? this.trophyWinsUnique,
      hardcorePoints: hardcorePoints ?? this.hardcorePoints,
      hardcoreCooldownUntil:
          hardcoreCooldownUntil ?? this.hardcoreCooldownUntil,
    );
  }
}

class GlobalLeaderboardEntry {
  const GlobalLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.diamonds,
    this.gamesWon = 0,
    this.rankPoints = 0,
    this.hardcorePoints = 0,
    this.isLocal = false,
  });

  final int rank;
  final String userId;
  final String username;
  final int diamonds;
  final int gamesWon;
  final int rankPoints;
  final int hardcorePoints;
  final bool isLocal;
}

enum GlobalLeaderboardSort {
  rank,
  wealth,
  hardcore;

  String get rpcValue => name;
}

class GlobalLeaderboardSnapshot {
  const GlobalLeaderboardSnapshot({
    required this.topPlayers,
    required this.localPlayerInTop,
    required this.sort,
    this.localPlayer,
  });

  final List<GlobalLeaderboardEntry> topPlayers;
  final GlobalLeaderboardEntry? localPlayer;
  final bool localPlayerInTop;
  final GlobalLeaderboardSort sort;
}

class ProfileService {
  ProfileService._() {
    AuthService.instance.authStateChanges.listen((authState) {
      if (authState.session == null) {
        _publishProfile(null);
        dailyChestAvailable.value = null;
        dailyChestNextAvailableAt.value = null;
        matchDayDiamondNotifier.value = null;
      }
    });
  }
  static final ProfileService instance = ProfileService._();


  static final _usernamePattern =
      RegExp(r'^[\p{L}\p{N} _\-.]{3,12}$', unicode: true);

  SupabaseClient get _client => AuthService.instance.client;

  String? get _userId => AuthService.instance.currentUser?.id;

  /// Lobide ve zafer ekranında güncel elmas göstermek için.
  final ValueNotifier<PlayerProfile?> profileNotifier =
      ValueNotifier<PlayerProfile?>(null);

  /// UTC daily chest — true when unclaimed today, false when claimed, null unknown.
  final ValueNotifier<bool?> dailyChestAvailable = ValueNotifier<bool?>(null);

  /// Next UTC reset when today's chest is already claimed.
  final ValueNotifier<DateTime?> dailyChestNextAvailableAt =
      ValueNotifier<DateTime?>(null);

  /// Rolling 24h match placement diamonds vs economy cap (reward UI).
  final ValueNotifier<MatchDayDiamondStatus?> matchDayDiamondNotifier =
      ValueNotifier<MatchDayDiamondStatus?>(null);

  void _publishProfile(PlayerProfile? profile) {
    profileNotifier.value = profile;
  }

  Future<PlayerProfile?> fetchProfile() async {
    final userId = _userId;
    if (userId == null) {
      _publishProfile(null);
      return null;
    }

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (data == null) {
        _publishProfile(null);
        return null;
      }
      final profile = PlayerProfile.fromJson(data);
      _publishProfile(profile);
      return profile;
    } catch (e, stackTrace) {
      debugPrint('fetchProfile failed: $e\n$stackTrace');
      // Keep last known profile so lobby/game can still open.
      return profileNotifier.value;
    }
  }

  static bool isValidUsername(String username) {
    return _usernamePattern.hasMatch(username.trim());
  }

  Future<void> updateProfile({
    required String username,
    String? avatarUrl,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw const ProfileUpdateException(ProfileUpdateError.notAuthenticated);
    }

    final trimmed = username.trim();
    if (!isValidUsername(trimmed)) {
      throw const ProfileUpdateException(ProfileUpdateError.invalidUsername);
    }
    if (isReservedAdminUsername(trimmed) &&
        !AdminAccess.isCurrentUserAdmin) {
      throw const ProfileUpdateException(ProfileUpdateError.usernameReserved);
    }

    try {
      await _client.rpc(
        'update_player_profile',
        params: {
          'p_username': trimmed,
          'p_avatar_url': avatarUrl,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapProfileException(e);
    }
  }

  Future<String> uploadAvatar(XFile file) async {
    final userId = _userId;
    if (userId == null) {
      throw const ProfileUpdateException(ProfileUpdateError.notAuthenticated);
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const ProfileUpdateException(ProfileUpdateError.unknown);
    }

    final mime = _mimeFromMagic(bytes);
    if (mime == null) {
      throw const ProfileUpdateException(ProfileUpdateError.unknown);
    }
    final ext = mime == 'image/png'
        ? 'png'
        : mime == 'image/webp'
            ? 'webp'
            : 'jpg';
    // Tahmin edilebilir avatar.jpg yerine rastgele nesne adı.
    final token = _randomObjectToken();
    final path = '$userId/a$token.$ext';

    await _client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            upsert: false,
            contentType: mime,
          ),
        );

    return _client.storage.from('avatars').getPublicUrl(path);
  }

  /// Magic-byte ile MIME (uzantıya güvenilmez).
  static String? _mimeFromMagic(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  static String _randomObjectToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  ProfileUpdateException _mapProfileException(PostgrestException e) {
    final message = e.message.toLowerCase();
    if (message.contains('username_reserved')) {
      return const ProfileUpdateException(ProfileUpdateError.usernameReserved);
    }
    if (message.contains('username_taken') || e.code == '23505') {
      return const ProfileUpdateException(ProfileUpdateError.usernameTaken);
    }
    if (message.contains('invalid_username')) {
      return const ProfileUpdateException(ProfileUpdateError.invalidUsername);
    }
    if (message.contains('not authenticated')) {
      return const ProfileUpdateException(ProfileUpdateError.notAuthenticated);
    }
    if (message.contains('invalid_avatar_url')) {
      return const ProfileUpdateException(ProfileUpdateError.unknown);
    }
    // Ham Postgrest metnini UI'ya sızdırma.
    return const ProfileUpdateException(ProfileUpdateError.unknown);
  }

  Future<int?> fetchGlobalRank() async {
    final userId = _userId;
    if (userId == null) return null;

    final rank = await _client.rpc(
      'get_user_rank',
      params: {'user_uuid': userId},
    );
    if (rank == null) return null;
    return (rank as num).toInt();
  }

  /// Global sıralama (sunucu RPC — profiles tablosu public değil).
  /// Varsayılan: rütbe puanı; [GlobalLeaderboardSort.wealth] = elmas.
  Future<GlobalLeaderboardSnapshot?> fetchGlobalLeaderboard({
    int limit = 100,
    GlobalLeaderboardSort sort = GlobalLeaderboardSort.rank,
  }) async {
    final userId = _userId;
    if (userId == null) return null;

    final response = await _client.rpc(
      'get_global_leaderboard',
      params: {
        'p_limit': limit,
        'p_sort': sort.rpcValue,
      },
    );
    final map = Map<String, dynamic>.from(response as Map);
    final topRaw = (map['top'] as List?) ?? const [];
    final localInTop = map['local_in_top'] == true;
    final sortRaw = (map['sort'] as String?)?.toLowerCase();
    final resolvedSort = switch (sortRaw) {
      'wealth' => GlobalLeaderboardSort.wealth,
      'hardcore' => GlobalLeaderboardSort.hardcore,
      _ => GlobalLeaderboardSort.rank,
    };

    final topPlayers = <GlobalLeaderboardEntry>[];
    for (final raw in topRaw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['user_id'] as String;
      topPlayers.add(
        GlobalLeaderboardEntry(
          rank: (row['rank_pos'] as num?)?.toInt() ?? topPlayers.length + 1,
          userId: id,
          username: clampPlayerName(row['username'] as String? ?? 'Traveler'),
          diamonds: (row['diamonds'] as num?)?.toInt() ?? 0,
          gamesWon: (row['games_won'] as num?)?.toInt() ?? 0,
          rankPoints: (row['rank_points'] as num?)?.toInt() ?? 0,
          hardcorePoints: (row['hardcore_points'] as num?)?.toInt() ?? 0,
          isLocal: id == userId,
        ),
      );
    }

    // Her sekmede (Rütbe / Zenginlik / Hardcore) en altta "SENİN SIRAN"
    // — top 100 içinde olsan bile sticky satırda görünür.
    GlobalLeaderboardEntry? localPlayer;
    final localRaw = map['local'];
    if (localRaw is Map) {
      final row = Map<String, dynamic>.from(localRaw);
      final rankPos = (row['rank_pos'] as num?)?.toInt() ?? 0;
      if (rankPos > 0) {
        localPlayer = GlobalLeaderboardEntry(
          rank: rankPos,
          userId: row['user_id'] as String? ?? userId,
          username: clampPlayerName(row['username'] as String? ?? 'Traveler'),
          diamonds: (row['diamonds'] as num?)?.toInt() ?? 0,
          gamesWon: (row['games_won'] as num?)?.toInt() ?? 0,
          rankPoints: (row['rank_points'] as num?)?.toInt() ?? 0,
          hardcorePoints: (row['hardcore_points'] as num?)?.toInt() ?? 0,
          isLocal: true,
        );
      }
    }
    if (localPlayer == null) {
      for (final entry in topPlayers) {
        if (entry.isLocal) {
          localPlayer = entry;
          break;
        }
      }
    }

    return GlobalLeaderboardSnapshot(
      topPlayers: topPlayers,
      localPlayer: localPlayer,
      localPlayerInTop: localInTop,
      sort: resolvedSort,
    );
  }

  RealtimeChannel subscribeToProfile(void Function(PlayerProfile) onUpdate) {
    final userId = _userId!;
    return _client
        .channel('profile-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              final profile = PlayerProfile.fromJson(record);
              _publishProfile(profile);
              onUpdate(profile);
            }
          },
        )
        .subscribe();
  }

  Future<PlayerProfile?> spendSkillPoint(SkillNodeId nodeId) async {
    if (_userId == null) {
      throw const AuthException('Oturum bulunamadı.');
    }

    try {
      await _client.rpc(
        'spend_skill_point',
        params: {'p_node_id': nodeId.key},
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('insufficient_skill_points')) {
        throw StateError('insufficient_skill_points');
      }
      if (msg.contains('skill_max_level')) {
        throw StateError('skill_max_level');
      }
      if (msg.contains('unknown_skill_node')) {
        throw StateError('unknown_skill_node');
      }
      rethrow;
    }

    return fetchProfile();
  }

  Future<void> saveLeaderboardScore({
    required double maxMass,
    required String roomType,
  }) async {
    if (_userId == null) return;

    final score = maxMass.round().clamp(0, 500);
    await _client.rpc(
      'save_leaderboard_score',
      params: {
        'p_max_mass': score,
        'p_room_type': roomType,
      },
    );
  }

  /// Maç sonucu: yerleştirme ödülü veya eleme cezası.
  /// [eliminated] true ise oda tipine göre ceza (sunucu floor 0). Aksi halde [placement] (1/2/3).
  /// Çok oyunculu odalarda [roomInstanceId] zorunlu; eğitimde null.
  Future<PlayerProfile?> applyMatchResult({
    required RoomType roomType,
    int? placement,
    bool eliminated = false,
    String? roomInstanceId,
  }) async {
    final userId = _userId;
    if (userId == null) return null;

    final previous = profileNotifier.value;

    try {
      await _client.rpc(
        'apply_match_result',
        params: {
          'p_room_type': roomType.name,
          'p_placement': eliminated ? null : placement,
          'p_eliminated': eliminated,
          'p_room_instance_id': roomType == RoomType.simple
              ? null
              : roomInstanceId,
        },
      );
      final profile = await fetchProfile();
      if (!eliminated) {
        unawaited(refreshMatchDayDiamonds());
      }
      return profile;
    } catch (e, stackTrace) {
      debugPrint('applyMatchResult: $e\n$stackTrace');
      return previous;
    }
  }

  /// Hardcore: absorb another real player → diamonds (server-verified).
  /// [aliveCount] is the arena population at kill time (includes prey).
  Future<PlayerProfile?> applyHardcoreKillReward({
    required String roomInstanceId,
    required String preyUserId,
    int? aliveCount,
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      await _client.rpc(
        'apply_hardcore_kill_reward',
        params: {
          'p_room_instance_id': roomInstanceId,
          'p_prey_user_id': preyUserId,
          'p_alive_count': ?aliveCount,
        },
      );
      return fetchProfile();
    } catch (e, stackTrace) {
      debugPrint('applyHardcoreKillReward: $e\n$stackTrace');
      return profileNotifier.value;
    }
  }

  /// Hardcore passive mode (&lt; min-alive): no kill/elim diamonds, 5 min cooldown.
  Future<PlayerProfile?> applyHardcorePassiveElim({
    required String? roomInstanceId,
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    if (roomInstanceId == null || roomInstanceId.isEmpty) return null;

    final previous = profileNotifier.value;
    try {
      await _client.rpc(
        'apply_hardcore_passive_elim',
        params: {'p_room_instance_id': roomInstanceId},
      );
      return fetchProfile();
    } catch (e, stackTrace) {
      debugPrint('applyHardcorePassiveElim: $e\n$stackTrace');
      return previous;
    }
  }

  /// Rolling 24h match reward diamonds vs dailyMatchDiamondCap.
  Future<MatchDayDiamondStatus?> refreshMatchDayDiamonds() async {
    final userId = _userId;
    if (userId == null) {
      matchDayDiamondNotifier.value = null;
      return null;
    }
    try {
      final response = await _client.rpc('get_match_diamond_day_status');
      final status = MatchDayDiamondStatus.fromRpc(response);
      matchDayDiamondNotifier.value = status;
      return status;
    } catch (e, st) {
      debugPrint('refreshMatchDayDiamonds failed: $e\n$st');
      return matchDayDiamondNotifier.value;
    }
  }

  /// Rewarded ad: grant a second copy of this match's diamond reward.
  /// Requires [prepareRewardedMatchDouble] session + prior base claim.
  Future<String?> prepareRewardedMatchDouble({
    required RoomType roomType,
    required String roomInstanceId,
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    if (roomType == RoomType.simple) return null;

    final response = await _client.rpc(
      'prepare_rewarded_match_double',
      params: {
        'p_room_type': roomType.name,
        'p_room_instance_id': roomInstanceId,
      },
    );
    if (response == null) return null;
    return response.toString();
  }

  /// Marks the ad session as watched.
  /// Prod: raises `ssv_required` unless SSV already attested — then poll
  /// [isRewardedMatchDoubleAttested]. Dev: enable
  /// `app.ad_double_allow_client_attest` in SQL.
  Future<bool> attestRewardedMatchDouble({
    required RoomType roomType,
    required String roomInstanceId,
    required String sessionId,
  }) async {
    final userId = _userId;
    if (userId == null) return false;
    if (roomType == RoomType.simple) return false;
    if (sessionId.isEmpty) return false;

    try {
      await _client.rpc(
        'attest_rewarded_match_double',
        params: {
          'p_room_type': roomType.name,
          'p_room_instance_id': roomInstanceId,
          'p_session_id': sessionId,
        },
      );
      return true;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('ssv_required')) {
        return false;
      }
      rethrow;
    }
  }

  /// True when AdMob SSV (or allowed client attest) has marked the session.
  Future<bool> isRewardedMatchDoubleAttested({
    required RoomType roomType,
    required String roomInstanceId,
    required String sessionId,
  }) async {
    final userId = _userId;
    if (userId == null) return false;
    if (roomType == RoomType.simple) return false;
    if (sessionId.isEmpty) return false;

    final response = await _client.rpc(
      'is_rewarded_match_double_attested',
      params: {
        'p_room_type': roomType.name,
        'p_room_instance_id': roomInstanceId,
        'p_session_id': sessionId,
      },
    );
    return response == true;
  }

  /// Wait for SSV (or client attest) before claiming.
  Future<bool> waitForRewardedMatchDoubleAttest({
    required RoomType roomType,
    required String roomInstanceId,
    required String sessionId,
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      // Prefer client attest when server GUC allows (local/dev).
      try {
        final ok = await attestRewardedMatchDouble(
          roomType: roomType,
          roomInstanceId: roomInstanceId,
          sessionId: sessionId,
        );
        if (ok) return true;
      } catch (_) {
        // ad_watch_too_short / other — keep polling / retrying.
      }

      final ready = await isRewardedMatchDoubleAttested(
        roomType: roomType,
        roomInstanceId: roomInstanceId,
        sessionId: sessionId,
      );
      if (ready) return true;
      await Future<void>.delayed(interval);
    }
    return false;
  }

  /// Rewarded ad: grant a second copy of this match's diamond reward.
  /// Requires a prior [applyMatchResult] reward claim + [sessionId] from prepare.
  Future<PlayerProfile?> claimRewardedMatchDouble({
    required RoomType roomType,
    required String roomInstanceId,
    required String sessionId,
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    if (roomType == RoomType.simple) return null;
    if (sessionId.isEmpty) return null;

    final previous = profileNotifier.value;

    try {
      await _client.rpc(
        'claim_rewarded_match_double',
        params: {
          'p_room_type': roomType.name,
          'p_room_instance_id': roomInstanceId,
          'p_session_id': sessionId,
        },
      );
      return await fetchProfile();
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already_doubled')) {
        return await fetchProfile();
      }
      _publishProfile(previous);
      rethrow;
    } catch (e) {
      _publishProfile(previous);
      rethrow;
    }
  }

  /// UTC daily lobby chest — available until claimed once per calendar day.
  Future<DailyChestStatus?> fetchDailyChestStatus() async {
    final userId = _userId;
    if (userId == null) {
      dailyChestAvailable.value = null;
      dailyChestNextAvailableAt.value = null;
      return null;
    }
    try {
      final response = await _client.rpc('get_daily_lobby_chest_status');
      final status = DailyChestStatus.fromRpc(response);
      dailyChestAvailable.value = status.available;
      dailyChestNextAvailableAt.value =
          status.available ? null : status.nextAvailableAt;
      return status;
    } catch (e, st) {
      debugPrint('fetchDailyChestStatus failed: $e\n$st');
      return null;
    }
  }

  /// Claims today's chest (base from economy config; [doubled] → ×2). Idempotent per UTC day.
  /// Admins bypass the daily limit (server-side).
  Future<DailyChestClaimResult> claimDailyLobbyChest({
    bool doubled = false,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return const DailyChestClaimResult(
        ok: false,
        reason: 'not_authenticated',
      );
    }

    final previous = profileNotifier.value;
    try {
      final response = await _client.rpc(
        'claim_daily_lobby_chest',
        params: {'p_doubled': doubled},
      );
      final result = DailyChestClaimResult.fromRpc(response);
      if (result.ok) {
        await fetchProfile();
        // Admins stay available; normal players flip to claimed.
        await fetchDailyChestStatus();
      } else if (result.reason == 'already_claimed') {
        dailyChestAvailable.value = false;
        dailyChestNextAvailableAt.value = result.nextAvailableAt;
      }
      return result;
    } on PostgrestException catch (e, st) {
      debugPrint('claimDailyLobbyChest failed: $e\n$st');
      _publishProfile(previous);
      return DailyChestClaimResult(
        ok: false,
        reason: e.message,
      );
    } catch (e, st) {
      debugPrint('claimDailyLobbyChest failed: $e\n$st');
      _publishProfile(previous);
      return const DailyChestClaimResult(ok: false, reason: 'unknown');
    }
  }
}

class DailyChestStatus {
  const DailyChestStatus({
    required this.available,
    this.claimDay,
    this.nextAvailableAt,
    this.adminBypass = false,
  });

  factory DailyChestStatus.fromRpc(Object? raw) {
    final map = _asStringKeyedMap(raw);
    return DailyChestStatus(
      available: map['available'] == true,
      claimDay: map['claim_day']?.toString(),
      nextAvailableAt: _parseTimestamptz(map['next_available_at']),
      adminBypass: map['admin_bypass'] == true,
    );
  }

  final bool available;
  final String? claimDay;
  final DateTime? nextAvailableAt;
  final bool adminBypass;
}

class MatchDayDiamondStatus {
  const MatchDayDiamondStatus({
    required this.earned,
    required this.cap,
  });

  factory MatchDayDiamondStatus.fromRpc(Object? raw) {
    final map = _asStringKeyedMap(raw);
    return MatchDayDiamondStatus(
      earned: _rpcInt(map['earned']) ?? 0,
      cap: (_rpcInt(map['cap']) ?? 120).clamp(1, 5000),
    );
  }

  final int earned;
  final int cap;
}

class DailyChestClaimResult {
  const DailyChestClaimResult({
    required this.ok,
    this.awarded,
    this.baseAwarded,
    this.doubled = false,
    this.diamonds,
    this.reason,
    this.nextAvailableAt,
    this.adminBypass = false,
  });

  factory DailyChestClaimResult.fromRpc(Object? raw) {
    final map = _asStringKeyedMap(raw);
    return DailyChestClaimResult(
      ok: map['ok'] == true,
      awarded: _rpcInt(map['awarded']),
      baseAwarded: _rpcInt(map['base_awarded']),
      doubled: map['doubled'] == true,
      diamonds: _rpcInt(map['diamonds']),
      reason: map['reason']?.toString(),
      nextAvailableAt: _parseTimestamptz(map['next_available_at']),
      adminBypass: map['admin_bypass'] == true,
    );
  }

  final bool ok;
  final int? awarded;
  final int? baseAwarded;
  final bool doubled;
  final int? diamonds;
  final String? reason;
  final DateTime? nextAvailableAt;
  final bool adminBypass;
}

Map<String, dynamic> _asStringKeyedMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

int? _rpcInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _parseTimestamptz(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value.toString())?.toUtc();
}
