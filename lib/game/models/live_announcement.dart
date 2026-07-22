/// Sunucu saatli canlı admin duyurusu.
class LiveAnnouncement {
  const LiveAnnouncement({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  Duration get remaining {
    final left = expiresAt.toUtc().difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  factory LiveAnnouncement.fromJson(Map<String, dynamic> json) {
    DateTime parseTs(Object? raw) {
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) {
        return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      }
      return DateTime.now().toUtc();
    }

    return LiveAnnouncement(
      id: json['id']?.toString() ?? '',
      body: (json['body'] as String? ?? '').trim(),
      createdAt: parseTs(json['created_at']),
      expiresAt: parseTs(json['expires_at']),
    );
  }
}
