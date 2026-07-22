import '../../utils/player_name.dart';

/// Network payload broadcast to the room channel (max 12/s per client).
class PlayerSyncState {
  const PlayerSyncState({
    required this.id,
    required this.displayName,
    required this.x,
    required this.y,
    required this.radius,
    required this.activeSkin,
    this.activeEmoji = '',
    this.avatarUrl,
    this.shield = false,
    this.boost = false,
    this.link = false,
    this.diamonds = 0,
    this.rankPoints = 0,
    this.alive = true,
  });

  factory PlayerSyncState.fromMap(Map<String, dynamic> map) {
    return PlayerSyncState(
      id: map['id'] as String,
      displayName: clampPlayerName(
        map['display_name'] as String? ?? 'Traveler',
      ),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
      activeSkin: map['active_skin'] as String? ?? 'default',
      activeEmoji: map['active_emoji'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      shield: map['shield'] as bool? ?? false,
      boost: map['boost'] as bool? ?? false,
      link: map['link'] as bool? ?? false,
      diamonds: map['diamonds'] as int? ?? 0,
      rankPoints: map['rank_points'] as int? ?? 0,
      // Older clients omit this; treat missing as alive.
      alive: map['alive'] as bool? ?? true,
    );
  }

  final String id;
  final String displayName;
  final double x;
  final double y;
  final double radius;
  final String activeSkin;
  final String activeEmoji;
  final String? avatarUrl;
  final bool shield;
  final bool boost;
  final bool link;
  final int diamonds;
  final int rankPoints;
  /// False = eliminated; peers despawn and ignore lagging poses until revive.
  final bool alive;

  Map<String, dynamic> toMap() => {
        'id': id,
        'display_name': displayName,
        'x': x,
        'y': y,
        'radius': radius,
        'active_skin': activeSkin,
        'active_emoji': activeEmoji,
        if (avatarUrl != null && avatarUrl!.isNotEmpty) 'avatar_url': avatarUrl,
        'shield': shield,
        'boost': boost,
        'link': link,
        'diamonds': diamonds,
        'rank_points': rankPoints,
        'alive': alive,
      };
}
