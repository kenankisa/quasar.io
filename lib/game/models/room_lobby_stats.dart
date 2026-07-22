/// Lobi kartlarında gösterilen anlık evren istatistikleri.
class RoomLobbyStats {
  const RoomLobbyStats({
    required this.activeUniverses,
    required this.players,
    required this.bots,
  });

  const RoomLobbyStats.empty()
      : activeUniverses = 0,
        players = 0,
        bots = 0;

  final int activeUniverses;
  final int? players;
  final int bots;

  @override
  bool operator ==(Object other) {
    return other is RoomLobbyStats &&
        other.activeUniverses == activeUniverses &&
        other.players == players &&
        other.bots == bots;
  }

  @override
  int get hashCode => Object.hash(
        activeUniverses,
        players,
        bots,
      );
}
