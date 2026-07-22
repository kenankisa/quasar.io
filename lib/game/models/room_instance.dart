/// Sunucu tarafından atanan çok oyunculu oda örneği.
class RoomInstance {
  const RoomInstance({
    required this.id,
    required this.instanceNumber,
    required this.realPlayerCount,
    required this.leaderRadius,
    this.isLoadTest = false,
    this.matchStartedAt,
    this.cosmicSeed,
  });

  factory RoomInstance.fromJson(Map<String, dynamic> json) {
    return RoomInstance(
      id: json['room_instance_id'] as String,
      instanceNumber: json['instance_number'] as int? ?? 1,
      realPlayerCount: json['real_player_count'] as int? ?? 1,
      leaderRadius: json['leader_radius'] as int? ?? 25,
      isLoadTest: json['is_load_test'] == true,
      matchStartedAt: _readDateTime(json['match_started_at']),
      cosmicSeed: _readInt(json['cosmic_seed']),
    );
  }

  final String id;
  final int instanceNumber;
  final int realPlayerCount;
  final int leaderRadius;

  /// Yük testi odası (Normal Evren Test1…) — normal oyuncular gelmez.
  final bool isLoadTest;

  /// Sunucu maç saati — cosmic olay senkronu için.
  final DateTime? matchStartedAt;

  /// Deterministik cosmic olay takvimi seed'i.
  final int? cosmicSeed;

  RoomInstance copyWith({
    int? realPlayerCount,
    int? leaderRadius,
    DateTime? matchStartedAt,
    int? cosmicSeed,
  }) {
    return RoomInstance(
      id: id,
      instanceNumber: instanceNumber,
      realPlayerCount: realPlayerCount ?? this.realPlayerCount,
      leaderRadius: leaderRadius ?? this.leaderRadius,
      isLoadTest: isLoadTest,
      matchStartedAt: matchStartedAt ?? this.matchStartedAt,
      cosmicSeed: cosmicSeed ?? this.cosmicSeed,
    );
  }

  Map<String, dynamic> toJsonBase() => {
        'room_instance_id': id,
        'instance_number': instanceNumber,
        'real_player_count': realPlayerCount,
        'leader_radius': leaderRadius,
        'is_load_test': isLoadTest,
      };

  static DateTime? _readDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }

  static int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
