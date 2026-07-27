import '../room_type.dart';
import 'first_match_tuning.dart';

enum LobbyNextGoalKind { training, diamonds, trophies }

/// Next unlock milestone shown in the lobby for early progression clarity.
class LobbyNextGoal {
  const LobbyNextGoal({
    required this.targetRoom,
    required this.kind,
    this.deficit = 0,
  });

  final RoomType targetRoom;
  final LobbyNextGoalKind kind;

  /// Diamonds still needed, or cups remaining for Hardcore.
  final int deficit;

  static String titleKeyFor(RoomType type) => switch (type) {
        RoomType.simple => 'room_simple_title',
        RoomType.normal => 'room_normal_title',
        RoomType.elite => 'room_elite_title',
        RoomType.unique => 'room_unique_title',
        RoomType.hardcore => 'room_hardcore_title',
      };

  /// Returns null when every gate is open (widget hidden).
  static LobbyNextGoal? resolve({
    required bool tutorialCompleted,
    int gamesWon = 0,
    required int diamonds,
    int universeTrophies = 0,
  }) {
    if (FirstMatchTuning.shouldRecommendSimpleRoom(
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
    )) {
      return const LobbyNextGoal(
        targetRoom: RoomType.simple,
        kind: LobbyNextGoalKind.training,
      );
    }

    for (final type in [
      RoomType.normal,
      RoomType.elite,
      RoomType.unique,
    ]) {
      if (!RoomTypeLobby.isUnlocked(type, diamonds)) {
        final required = type.requiredDiamonds;
        return LobbyNextGoal(
          targetRoom: type,
          kind: LobbyNextGoalKind.diamonds,
          deficit: (required - diamonds).clamp(1, required),
        );
      }
    }

    if (RoomTypeLobby.isHardcoreTrophyLocked(universeTrophies)) {
      final remaining =
          RoomTypeLobby.hardcoreTrophyRequirement - universeTrophies;
      return LobbyNextGoal(
        targetRoom: RoomType.hardcore,
        kind: LobbyNextGoalKind.trophies,
        deficit: remaining.clamp(1, RoomTypeLobby.hardcoreTrophyRequirement),
      );
    }

    return null;
  }
}
