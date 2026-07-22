/// In-match room standings row for the top HUD.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.radius,
    required this.isLocal,
    required this.visible,
    this.rank,
    this.isPinnedLocal = false,
    this.isBot = false,
    this.rankPoints,
  });

  final String name;
  final double radius;
  final bool isLocal;
  final bool visible;
  final int? rank;
  final bool isPinnedLocal;
  final bool isBot;
  final int? rankPoints;
}

/// Top-3 podium plus optional side slot (local player or 4th place).
class RoomLeaderboardLayout {
  const RoomLeaderboardLayout({
    required this.top,
    this.side,
  });

  final List<LeaderboardEntry> top;
  final LeaderboardEntry? side;
}

RoomLeaderboardLayout layoutRoomLeaderboard(
  List<LeaderboardEntry> entries, {
  int maxTop = 3,
}) {
  final sorted = List<LeaderboardEntry>.from(entries)
    ..sort((a, b) => b.radius.compareTo(a.radius));

  final top = sorted.take(maxTop).toList();

  for (var i = 0; i < top.length; i++) {
    top[i] = LeaderboardEntry(
      name: top[i].name,
      radius: top[i].radius,
      isLocal: top[i].isLocal,
      visible: top[i].visible,
      rank: i + 1,
      isBot: top[i].isBot,
      rankPoints: top[i].rankPoints,
    );
  }

  final localInTop = top.any((e) => e.isLocal);
  if (localInTop) {
    if (sorted.length > maxTop) {
      final fourth = sorted[maxTop];
      return RoomLeaderboardLayout(
        top: top,
        side: LeaderboardEntry(
          name: fourth.name,
          radius: fourth.radius,
          isLocal: fourth.isLocal,
          visible: fourth.visible,
          rank: maxTop + 1,
          isBot: fourth.isBot,
          rankPoints: fourth.rankPoints,
        ),
      );
    }
    return RoomLeaderboardLayout(top: top);
  }

  final local = sorted.where((e) => e.isLocal).firstOrNull;
  if (local == null) return RoomLeaderboardLayout(top: top);

  final localRank = sorted.indexWhere((e) => e.isLocal) + 1;

  return RoomLeaderboardLayout(
    top: top,
    side: LeaderboardEntry(
      name: local.name,
      radius: local.radius,
      isLocal: true,
      visible: local.visible,
      rank: localRank,
      isPinnedLocal: true,
      isBot: local.isBot,
      rankPoints: local.rankPoints,
    ),
  );
}
