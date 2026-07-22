import '../room_type.dart';

/// Zaman penceresi — admin geçmiş istatistikleri.
enum AdminAnalyticsWindow {
  hour1,
  day1,
  week1,
  month1,
  all;

  String get rpcValue => switch (this) {
        AdminAnalyticsWindow.hour1 => '1h',
        AdminAnalyticsWindow.day1 => '1d',
        AdminAnalyticsWindow.week1 => '7d',
        AdminAnalyticsWindow.month1 => '30d',
        AdminAnalyticsWindow.all => 'all',
      };

  String get labelKey => switch (this) {
        AdminAnalyticsWindow.hour1 => 'admin_analytics_window_1h',
        AdminAnalyticsWindow.day1 => 'admin_analytics_window_1d',
        AdminAnalyticsWindow.week1 => 'admin_analytics_window_7d',
        AdminAnalyticsWindow.month1 => 'admin_analytics_window_30d',
        AdminAnalyticsWindow.all => 'admin_analytics_window_all',
      };
}

/// Tek evren için geçmiş metrikler.
class AdminUniverseAnalytics {
  const AdminUniverseAnalytics({
    required this.roomType,
    required this.uniquePlayers,
    required this.matches,
    required this.playSeconds,
    required this.diamondsEarned,
    required this.diamondsLost,
    required this.netDiamonds,
    required this.wins,
    required this.eliminations,
    required this.avgMatchSeconds,
  });

  factory AdminUniverseAnalytics.empty(RoomType type) {
    return AdminUniverseAnalytics(
      roomType: type,
      uniquePlayers: 0,
      matches: 0,
      playSeconds: 0,
      diamondsEarned: 0,
      diamondsLost: 0,
      netDiamonds: 0,
      wins: 0,
      eliminations: 0,
      avgMatchSeconds: 0,
    );
  }

  factory AdminUniverseAnalytics.fromJson(Map<String, dynamic> json) {
    final roomName = json['room_type'] as String?;
    final roomType = RoomType.values.firstWhere(
      (t) => t.name == roomName,
      orElse: () => RoomType.normal,
    );
    return AdminUniverseAnalytics(
      roomType: roomType,
      uniquePlayers: _asInt(json['unique_players']),
      matches: _asInt(json['matches']),
      playSeconds: _asInt(json['play_seconds']),
      diamondsEarned: _asInt(json['diamonds_earned']),
      diamondsLost: _asInt(json['diamonds_lost']),
      netDiamonds: _asInt(json['net_diamonds']),
      wins: _asInt(json['wins']),
      eliminations: _asInt(json['eliminations']),
      avgMatchSeconds: _asDouble(json['avg_match_seconds']),
    );
  }

  final RoomType roomType;
  final int uniquePlayers;
  final int matches;
  final int playSeconds;
  final int diamondsEarned;
  final int diamondsLost;
  final int netDiamonds;
  final int wins;
  final int eliminations;
  final double avgMatchSeconds;
}

/// Admin geçmiş istatistik özeti (tek zaman penceresi).
class AdminAnalyticsSnapshot {
  const AdminAnalyticsSnapshot({
    required this.window,
    required this.uniqueLogins,
    required this.totalLogins,
    required this.uniquePlayersPlayed,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.totalPlaySeconds,
    required this.avgPlaySecondsPerMatch,
    required this.avgPlaySecondsPerPlayer,
    required this.diamondsEarned,
    required this.diamondsLost,
    required this.netDiamonds,
    required this.diamondsHeld,
    required this.registeredPlayers,
    required this.byUniverse,
    required this.fetchedAt,
  });

  factory AdminAnalyticsSnapshot.empty([
    AdminAnalyticsWindow window = AdminAnalyticsWindow.day1,
  ]) {
    return AdminAnalyticsSnapshot(
      window: window,
      uniqueLogins: 0,
      totalLogins: 0,
      uniquePlayersPlayed: 0,
      matchesPlayed: 0,
      matchesWon: 0,
      totalPlaySeconds: 0,
      avgPlaySecondsPerMatch: 0,
      avgPlaySecondsPerPlayer: 0,
      diamondsEarned: 0,
      diamondsLost: 0,
      netDiamonds: 0,
      diamondsHeld: 0,
      registeredPlayers: 0,
      byUniverse: {
        for (final type in RoomType.values)
          type: AdminUniverseAnalytics.empty(type),
      },
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  factory AdminAnalyticsSnapshot.fromJson(
    Map<String, dynamic> json, {
    required AdminAnalyticsWindow window,
  }) {
    final byUniverse = <RoomType, AdminUniverseAnalytics>{
      for (final type in RoomType.values)
        type: AdminUniverseAnalytics.empty(type),
    };

    final rawList = json['by_universe'];
    if (rawList is List) {
      for (final raw in rawList) {
        if (raw is! Map) continue;
        final item = AdminUniverseAnalytics.fromJson(
          Map<String, dynamic>.from(raw),
        );
        byUniverse[item.roomType] = item;
      }
    }

    return AdminAnalyticsSnapshot(
      window: window,
      uniqueLogins: _asInt(json['unique_logins']),
      totalLogins: _asInt(json['total_logins']),
      uniquePlayersPlayed: _asInt(json['unique_players_played']),
      matchesPlayed: _asInt(json['matches_played']),
      matchesWon: _asInt(json['matches_won']),
      totalPlaySeconds: _asInt(json['total_play_seconds']),
      avgPlaySecondsPerMatch: _asDouble(json['avg_play_seconds_per_match']),
      avgPlaySecondsPerPlayer: _asDouble(json['avg_play_seconds_per_player']),
      diamondsEarned: _asInt(json['diamonds_earned']),
      diamondsLost: _asInt(json['diamonds_lost']),
      netDiamonds: _asInt(json['net_diamonds']),
      diamondsHeld: _asInt(json['diamonds_held']),
      registeredPlayers: _asInt(json['registered_players']),
      byUniverse: byUniverse,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  final AdminAnalyticsWindow window;
  final int uniqueLogins;
  final int totalLogins;
  final int uniquePlayersPlayed;
  final int matchesPlayed;
  final int matchesWon;
  final int totalPlaySeconds;
  final double avgPlaySecondsPerMatch;
  final double avgPlaySecondsPerPlayer;
  final int diamondsEarned;
  final int diamondsLost;
  final int netDiamonds;
  /// Oyuncuların şu an elindeki toplam elmas (anlık).
  final int diamondsHeld;
  final int registeredPlayers;
  final Map<RoomType, AdminUniverseAnalytics> byUniverse;
  final DateTime fetchedAt;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
