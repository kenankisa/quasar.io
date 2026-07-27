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

/// Top-N standings for the match HUD grid.
class RoomLeaderboardLayout {
  const RoomLeaderboardLayout({
    required this.top,
    this.side,
  });

  final List<LeaderboardEntry> top;
  /// Legacy — HUD grid uses [top] only (local player pinned into slot 6).
  final LeaderboardEntry? side;
}

RoomLeaderboardLayout layoutRoomLeaderboard(
  List<LeaderboardEntry> entries, {
  int maxTop = 6,
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
  if (!localInTop) {
    final local = sorted.where((e) => e.isLocal).firstOrNull;
    if (local != null) {
      final localRank = sorted.indexWhere((e) => e.isLocal) + 1;
      final pinned = LeaderboardEntry(
        name: local.name,
        radius: local.radius,
        isLocal: true,
        visible: local.visible,
        rank: localRank,
        isPinnedLocal: true,
        isBot: local.isBot,
        rankPoints: local.rankPoints,
      );
      if (top.length >= maxTop) {
        top[maxTop - 1] = pinned;
      } else {
        top.add(pinned);
      }
    }
  }

  return RoomLeaderboardLayout(top: top);
}
