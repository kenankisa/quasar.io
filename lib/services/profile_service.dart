import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/config/skill_tree_config.dart';
import '../game/room_type.dart';
import '../utils/player_name.dart';
import 'auth_service.dart';

enum ProfileUpdateError {
  usernameTaken,
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
    );
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
    this.isLocal = false,
  });

  final int rank;
  final String userId;
  final String username;
  final int diamonds;
  final int gamesWon;
  final int rankPoints;
  final bool isLocal;
}

enum GlobalLeaderboardSort {
  rank,
  wealth;

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
    final resolvedSort = sortRaw == 'wealth'
        ? GlobalLeaderboardSort.wealth
        : GlobalLeaderboardSort.rank;

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
          isLocal: id == userId,
        ),
      );
    }

    GlobalLeaderboardEntry? localPlayer;
    if (!localInTop) {
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
            isLocal: true,
          );
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
      return await fetchProfile();
    } catch (e) {
      _publishProfile(previous);
      rethrow;
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
}
