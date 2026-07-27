/// Snapshot for the admin Hardcore live-ops dashboard.
class AdminHardcoreLiveSnapshot {
  const AdminHardcoreLiveSnapshot({
    required this.roomId,
    required this.status,
    required this.leaderRadius,
    required this.realPlayerCount,
    required this.seatOccupancy,
    required this.maxPlayers,
    required this.players,
    required this.queue,
    required this.queueCount,
    required this.diamondsWonToday,
    required this.diamondsLostToday,
    required this.diamondsWonHour,
    required this.diamondsLostHour,
    required this.fetchedAt,
  });

  final String? roomId;
  final String status;
  final int leaderRadius;
  final int realPlayerCount;
  final int seatOccupancy;
  final int maxPlayers;
  final List<AdminHardcorePlayer> players;
  final List<AdminHardcoreQueueEntry> queue;
  final int queueCount;
  final int diamondsWonToday;
  final int diamondsLostToday;
  final int diamondsWonHour;
  final int diamondsLostHour;
  final DateTime fetchedAt;

  bool get isOpen => status == 'open';

  double get fillRatio {
    if (maxPlayers <= 0) return 0;
    return (seatOccupancy / maxPlayers).clamp(0.0, 1.0);
  }

  factory AdminHardcoreLiveSnapshot.empty() => AdminHardcoreLiveSnapshot(
        roomId: null,
        status: 'missing',
        leaderRadius: 0,
        realPlayerCount: 0,
        seatOccupancy: 0,
        maxPlayers: 20,
        players: const [],
        queue: const [],
        queueCount: 0,
        diamondsWonToday: 0,
        diamondsLostToday: 0,
        diamondsWonHour: 0,
        diamondsLostHour: 0,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  factory AdminHardcoreLiveSnapshot.fromJson(Map<String, dynamic> json) {
    final playersRaw = (json['players'] as List?) ?? const [];
    final queueRaw = (json['queue'] as List?) ?? const [];
    final fetchedRaw = json['fetched_at'] as String?;
    return AdminHardcoreLiveSnapshot(
      roomId: json['room_id'] as String?,
      status: (json['status'] as String?) ?? 'missing',
      leaderRadius: (json['leader_radius'] as num?)?.toInt() ?? 0,
      realPlayerCount: (json['real_player_count'] as num?)?.toInt() ?? 0,
      seatOccupancy: (json['seat_occupancy'] as num?)?.toInt() ?? 0,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 20,
      players: playersRaw
          .whereType<Map>()
          .map((e) => AdminHardcorePlayer.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      queue: queueRaw
          .whereType<Map>()
          .map(
            (e) =>
                AdminHardcoreQueueEntry.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false),
      queueCount: (json['queue_count'] as num?)?.toInt() ?? 0,
      diamondsWonToday: (json['diamonds_won_today'] as num?)?.toInt() ?? 0,
      diamondsLostToday: (json['diamonds_lost_today'] as num?)?.toInt() ?? 0,
      diamondsWonHour: (json['diamonds_won_hour'] as num?)?.toInt() ?? 0,
      diamondsLostHour: (json['diamonds_lost_hour'] as num?)?.toInt() ?? 0,
      fetchedAt: fetchedRaw != null
          ? DateTime.parse(fetchedRaw).toUtc()
          : DateTime.now().toUtc(),
    );
  }
}

class AdminHardcorePlayer {
  const AdminHardcorePlayer({
    required this.userId,
    required this.username,
    required this.joinedAt,
    required this.isAdmin,
    this.currentRadius,
  });

  final String userId;
  final String username;
  final DateTime? joinedAt;
  final bool isAdmin;
  final int? currentRadius;

  factory AdminHardcorePlayer.fromJson(Map<String, dynamic> json) {
    final joinedRaw = json['joined_at'] as String?;
    return AdminHardcorePlayer(
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '—',
      joinedAt:
          joinedRaw != null ? DateTime.tryParse(joinedRaw)?.toUtc() : null,
      isAdmin: json['is_admin'] == true,
      currentRadius: (json['current_radius'] as num?)?.toInt(),
    );
  }
}

class AdminHardcoreQueueEntry {
  const AdminHardcoreQueueEntry({
    required this.position,
    required this.userId,
    required this.username,
    required this.enqueuedAt,
  });

  final int position;
  final String userId;
  final String username;
  final DateTime? enqueuedAt;

  factory AdminHardcoreQueueEntry.fromJson(Map<String, dynamic> json) {
    final enqueuedRaw = json['enqueued_at'] as String?;
    return AdminHardcoreQueueEntry(
      position: (json['position'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '—',
      enqueuedAt:
          enqueuedRaw != null ? DateTime.tryParse(enqueuedRaw)?.toUtc() : null,
    );
  }
}
