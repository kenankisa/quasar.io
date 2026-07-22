import '../../utils/bot_name.dart';
import '../../utils/player_name.dart';

/// Single bot pose in a host-authored [BotSnapshot].
class BotSyncState {
  const BotSyncState({
    required this.id,
    required this.displayName,
    required this.x,
    required this.y,
    required this.radius,
    required this.activeSkin,
    this.accentHue = 200,
    this.boost = false,
    this.shield = false,
  });

  factory BotSyncState.fromMap(Map<String, dynamic> map) {
    return BotSyncState(
      id: map['id'] as String? ?? '',
      displayName: formatBotDisplayName(
        clampPlayerName(map['display_name'] as String? ?? 'Bot'),
      ),
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      radius: (map['radius'] as num?)?.toDouble() ?? 25,
      activeSkin: map['active_skin'] as String? ?? 'pulsar',
      accentHue: (map['accent_hue'] as num?)?.toDouble() ?? 200,
      boost: map['boost'] == true,
      shield: map['shield'] == true,
    );
  }

  final String id;
  final String displayName;
  final double x;
  final double y;
  final double radius;
  final String activeSkin;
  final double accentHue;
  final bool boost;
  final bool shield;

  Map<String, dynamic> toMap() => {
        'id': id,
        'display_name': displayName,
        'x': x,
        'y': y,
        'radius': radius,
        'active_skin': activeSkin,
        'accent_hue': accentHue,
        'boost': boost,
        'shield': shield,
      };
}

/// Host-authored room bot set (~12 Hz).
class BotSnapshot {
  const BotSnapshot({
    required this.hostId,
    required this.bots,
  });

  factory BotSnapshot.fromMap(Map<String, dynamic> map) {
    final rawBots = map['bots'];
    final bots = <BotSyncState>[];
    if (rawBots is List) {
      for (final entry in rawBots) {
        if (entry is Map) {
          final state = BotSyncState.fromMap(Map<String, dynamic>.from(entry));
          if (state.id.isNotEmpty) bots.add(state);
        }
      }
    }
    return BotSnapshot(
      hostId: map['host_id'] as String? ?? '',
      bots: bots,
    );
  }

  final String hostId;
  final List<BotSyncState> bots;

  Map<String, dynamic> toMap() => {
        'host_id': hostId,
        'bots': bots.map((b) => b.toMap()).toList(),
      };
}
