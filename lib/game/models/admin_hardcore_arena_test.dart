/// Snapshot for Hardcore Arena Test admin harness.
class AdminHardcoreArenaTestSnapshot {
  const AdminHardcoreArenaTestSnapshot({
    required this.roomId,
    required this.status,
    required this.leaderRadius,
    required this.realPlayerCount,
    required this.seatOccupancy,
    required this.maxPlayers,
    required this.players,
    required this.queue,
    required this.queueCount,
    required this.victoryRadius,
    required this.victoryMinAlive,
    required this.victoryStableSeconds,
    required this.victoryMinPvpFraction,
    required this.spawnProtectionSeconds,
    required this.lowPopRadiusCap,
    required this.lateFoodSoftcapRadius,
    required this.lateFoodSoftcapMultiplier,
    required this.matchGeneration,
    required this.economyIsolated,
    required this.fetchedAt,
  });

  final String? roomId;
  final String status;
  final int leaderRadius;
  final int realPlayerCount;
  final int seatOccupancy;
  final int maxPlayers;
  final List<AdminHardcoreArenaTestPlayer> players;
  final List<AdminHardcoreArenaTestQueueEntry> queue;
  final int queueCount;
  final int victoryRadius;
  final int victoryMinAlive;
  final double victoryStableSeconds;
  final double victoryMinPvpFraction;
  final double spawnProtectionSeconds;
  final double lowPopRadiusCap;
  final double lateFoodSoftcapRadius;
  final double lateFoodSoftcapMultiplier;
  final int matchGeneration;
  final bool economyIsolated;
  final DateTime fetchedAt;

  bool get isOpen => status == 'open';

  factory AdminHardcoreArenaTestSnapshot.empty() =>
      AdminHardcoreArenaTestSnapshot(
        roomId: null,
        status: 'missing',
        leaderRadius: 0,
        realPlayerCount: 0,
        seatOccupancy: 0,
        maxPlayers: 20,
        players: const [],
        queue: const [],
        queueCount: 0,
        victoryRadius: 600,
        victoryMinAlive: 6,
        victoryStableSeconds: 20,
        victoryMinPvpFraction: 0.35,
        spawnProtectionSeconds: 12,
        lowPopRadiusCap: 450,
        lateFoodSoftcapRadius: 450,
        lateFoodSoftcapMultiplier: 0.5,
        matchGeneration: 1,
        economyIsolated: true,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  factory AdminHardcoreArenaTestSnapshot.fromJson(Map<String, dynamic> json) {
    final playersRaw = (json['players'] as List?) ?? const [];
    final queueRaw = (json['queue'] as List?) ?? const [];
    final fetchedRaw = json['fetched_at'] as String?;
    return AdminHardcoreArenaTestSnapshot(
      roomId: json['room_id'] as String?,
      status: (json['status'] as String?) ?? 'missing',
      leaderRadius: (json['leader_radius'] as num?)?.toInt() ?? 0,
      realPlayerCount: (json['real_player_count'] as num?)?.toInt() ?? 0,
      seatOccupancy: (json['seat_occupancy'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 20,
      players: playersRaw
          .whereType<Map>()
          .map(
            (e) => AdminHardcoreArenaTestPlayer.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(growable: false),
      queue: queueRaw
          .whereType<Map>()
          .map(
            (e) => AdminHardcoreArenaTestQueueEntry.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(growable: false),
      queueCount: (json['queue_count'] as num?)?.toInt() ?? 0,
      victoryRadius: (json['victory_radius'] as num?)?.toInt() ?? 600,
      victoryMinAlive: (json['victory_min_alive'] as num?)?.toInt() ?? 6,
      victoryStableSeconds:
          (json['victory_stable_seconds'] as num?)?.toDouble() ?? 20,
      victoryMinPvpFraction:
          (json['victory_min_pvp_fraction'] as num?)?.toDouble() ?? 0.35,
      spawnProtectionSeconds:
          (json['spawn_protection_seconds'] as num?)?.toDouble() ?? 12,
      lowPopRadiusCap:
          (json['low_pop_radius_cap'] as num?)?.toDouble() ?? 450,
      lateFoodSoftcapRadius:
          (json['late_food_softcap_radius'] as num?)?.toDouble() ?? 450,
      lateFoodSoftcapMultiplier:
          (json['late_food_softcap_multiplier'] as num?)?.toDouble() ?? 0.5,
      matchGeneration: (json['match_generation'] as num?)?.toInt() ?? 1,
      economyIsolated: json['economy_isolated'] != false,
      fetchedAt: fetchedRaw != null
          ? DateTime.parse(fetchedRaw).toUtc()
          : DateTime.now().toUtc(),
    );
  }
}

class AdminHardcoreArenaTestPlayer {
  const AdminHardcoreArenaTestPlayer({
    required this.userId,
    required this.username,
    required this.joinedAt,
    required this.isAdmin,
    required this.isSim,
    this.radius,
  });

  final String userId;
  final String username;
  final DateTime? joinedAt;
  final bool isAdmin;
  final bool isSim;
  final double? radius;

  factory AdminHardcoreArenaTestPlayer.fromJson(Map<String, dynamic> json) {
    final joinedRaw = json['joined_at'] as String?;
    return AdminHardcoreArenaTestPlayer(
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '—',
      joinedAt:
          joinedRaw != null ? DateTime.tryParse(joinedRaw)?.toUtc() : null,
      isAdmin: json['is_admin'] == true,
      isSim: json['is_sim'] == true,
      radius: (json['current_radius'] as num?)?.toDouble() ??
          (json['radius'] as num?)?.toDouble(),
    );
  }
}

class AdminHardcoreArenaTestQueueEntry {
  const AdminHardcoreArenaTestQueueEntry({
    required this.position,
    required this.userId,
    required this.username,
    required this.enqueuedAt,
  });

  final int position;
  final String userId;
  final String username;
  final DateTime? enqueuedAt;

  factory AdminHardcoreArenaTestQueueEntry.fromJson(Map<String, dynamic> json) {
    final enqueuedRaw = json['enqueued_at'] as String?;
    return AdminHardcoreArenaTestQueueEntry(
      position: (json['position'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '—',
      enqueuedAt:
          enqueuedRaw != null ? DateTime.tryParse(enqueuedRaw)?.toUtc() : null,
    );
  }
}
