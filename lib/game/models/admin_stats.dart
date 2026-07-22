import '../config/bot_difficulty.dart';
import '../room_type.dart';

/// Tek bir aktif evren örneğinin admin özeti.
class AdminUniverseInstance {
  const AdminUniverseInstance({
    required this.id,
    required this.roomType,
    required this.instanceNumber,
    required this.players,
    required this.bots,
    required this.leaderRadius,
    required this.difficultyLabelKey,
    this.isLoadTest = false,
  });

  final String id;
  final RoomType roomType;
  final int instanceNumber;
  final int players;
  final int bots;
  final int leaderRadius;
  final String difficultyLabelKey;
  final bool isLoadTest;
}

/// Evren tipine göre toplu istatistik + zorluk.
class AdminUniverseTierStats {
  const AdminUniverseTierStats({
    required this.roomType,
    required this.difficultyLabelKey,
    required this.activeUniverses,
    required this.players,
    required this.bots,
    required this.huntPriority,
    required this.instances,
  });

  final RoomType roomType;
  final String difficultyLabelKey;
  final int activeUniverses;
  final int players;
  final int bots;
  final double huntPriority;
  final List<AdminUniverseInstance> instances;

  static AdminUniverseTierStats empty(RoomType type) {
    final difficulty = BotDifficulty.forRoom(type);
    return AdminUniverseTierStats(
      roomType: type,
      difficultyLabelKey: difficultyLabelKeyFor(type),
      activeUniverses: 0,
      players: 0,
      bots: 0,
      huntPriority: difficulty.huntPriority,
      instances: const [],
    );
  }

  static String difficultyLabelKeyFor(RoomType type) => switch (type) {
        RoomType.simple => 'admin_difficulty_relaxed',
        RoomType.normal => 'admin_difficulty_standard',
        RoomType.elite => 'admin_difficulty_elite',
        RoomType.unique => 'admin_difficulty_unique',
      };
}

/// Admin panelinin tam anlık görüntüsü.
class AdminStatsSnapshot {
  const AdminStatsSnapshot({
    required this.tiers,
    required this.totalPlayers,
    required this.totalBots,
    required this.totalActiveUniverses,
    required this.registeredPlayers,
    required this.totalGamesWon,
    required this.activeSessions,
    required this.topWinners,
    required this.fetchedAt,
  });

  factory AdminStatsSnapshot.empty() {
    return AdminStatsSnapshot(
      tiers: {
        for (final type in RoomType.values)
          type: AdminUniverseTierStats.empty(type),
      },
      totalPlayers: 0,
      totalBots: 0,
      totalActiveUniverses: 0,
      registeredPlayers: 0,
      totalGamesWon: 0,
      activeSessions: 0,
      topWinners: const [],
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  final Map<RoomType, AdminUniverseTierStats> tiers;
  final int totalPlayers;
  final int totalBots;
  final int totalActiveUniverses;
  final int registeredPlayers;
  final int totalGamesWon;
  final int activeSessions;
  final List<AdminTopWinner> topWinners;
  final DateTime fetchedAt;
}

class AdminTopWinner {
  const AdminTopWinner({
    required this.username,
    required this.gamesWon,
    required this.diamonds,
  });

  final String username;
  final int gamesWon;
  final int diamonds;
}
