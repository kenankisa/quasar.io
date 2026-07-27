/// Lobi kartlarında gösterilen anlık evren istatistikleri.
class RoomLobbyStats {
  const RoomLobbyStats({
    required this.activeUniverses,
    required this.players,
    required this.bots,
    this.hardcoreSeatOccupancy,
    this.hardcoreMaxSeats,
    this.hardcoreQueueCount,
  });

  const RoomLobbyStats.empty()
      : activeUniverses = 0,
        players = 0,
        bots = 0,
        hardcoreSeatOccupancy = null,
        hardcoreMaxSeats = null,
        hardcoreQueueCount = null;

  final int activeUniverses;
  final int? players;
  final int bots;
  final int? hardcoreSeatOccupancy;
  final int? hardcoreMaxSeats;
  final int? hardcoreQueueCount;

  @override
  bool operator ==(Object other) {
    return other is RoomLobbyStats &&
        other.activeUniverses == activeUniverses &&
        other.players == players &&
        other.bots == bots &&
        other.hardcoreSeatOccupancy == hardcoreSeatOccupancy &&
        other.hardcoreMaxSeats == hardcoreMaxSeats &&
        other.hardcoreQueueCount == hardcoreQueueCount;
  }

  @override
  int get hashCode => Object.hash(
        activeUniverses,
        players,
        bots,
        hardcoreSeatOccupancy,
        hardcoreMaxSeats,
        hardcoreQueueCount,
      );
}
