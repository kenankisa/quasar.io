import '../config/app_config.dart';

enum RoomType { simple, normal, elite, unique, hardcore }

extension RoomTypeRewards on RoomType {
  /// 1. bitiren (evren hakimiyeti) ödülü — geriye dönük uyumluluk.
  int get victoryDiamondReward => diamondRewardForPlacement(1);

  /// Yerleştirme ödülü. Eleme için [eliminationDiamondPenalty] kullanın.
  /// Basit: 1→3, 2→2, 3→1. Normal: 1→5, 2→3, 3→2. Elite: 1→10, 2→6, 3→4. Unique: 1→15, 2→10, 3→5.
  int diamondRewardForPlacement(int placement) {
    if (placement < 1) return 0;
    return switch (this) {
      RoomType.simple => switch (placement) {
          1 => 3,
          2 => 2,
          3 => 1,
          _ => 0,
        },
      RoomType.normal => switch (placement) {
          1 => 5,
          2 => 3,
          3 => 2,
          _ => 0,
        },
      RoomType.elite => switch (placement) {
          1 => 10,
          2 => 6,
          3 => 4,
          _ => 0,
        },
      RoomType.unique => switch (placement) {
          1 => 15,
          2 => 10,
          3 => 5,
          _ => 0,
        },
      RoomType.hardcore => 0,
    };
  }

  /// Yutulma cezası (elmas asla 0 altına inmez — sunucu tarafında floor).
  /// Canlı değerler için [FirstMatchTuning.eliminationPenalty] / ekonomi config.
  int get eliminationDiamondPenalty => switch (this) {
        RoomType.simple => 0,
        RoomType.normal => 1,
        RoomType.elite => 2,
        RoomType.unique => 3,
        RoomType.hardcore => 15,
      };

  bool get awardsPlacementPodium => this != RoomType.hardcore;
}

extension RoomTypeLobby on RoomType {
  static const unlockDiamonds = {
    RoomType.simple: 0,
    RoomType.normal: 25,
    RoomType.elite: 100,
    RoomType.unique: 200,
    RoomType.hardcore: 0,
  };

  /// All universe cups required to unlock Hardcore (1 + 3 + 3 + 3).
  static const hardcoreTrophyRequirement = 10;

  static bool isHardcoreTrophyLocked(int universeTrophies) =>
      universeTrophies < hardcoreTrophyRequirement;

  /// Hardcore is players-only — competitive rooms fill with bots.
  bool get allowsBots => this != RoomType.hardcore;

  static bool isUnlocked(RoomType type, int diamonds) {
    if (AppConfig.devUnlockAllRooms) return true;
    if (type == RoomType.hardcore) return true;
    return diamonds >= (unlockDiamonds[type] ?? 0);
  }

  /// İlk girişte (eğitim tamamlanmadan) yalnızca eğitim evreni açık.
  static bool isFirstLoginLocked(
    RoomType type, {
    required bool tutorialCompleted,
    int gamesWon = 0,
  }) {
    if (AppConfig.devUnlockAllRooms) return false;
    if (type == RoomType.simple) return false;
    // Eski hesaplar: eğitim galibiyeti games_won'a yazılıyordu.
    if (tutorialCompleted || gamesWon > 0) return false;
    return true;
  }

  static bool isLobbyAccessible(
    RoomType type, {
    required bool tutorialCompleted,
    int gamesWon = 0,
    required int diamonds,
    int universeTrophies = 0,
    bool isAdmin = false,
  }) {
    if (isAdmin) return true;
    if (isFirstLoginLocked(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
    )) {
      return false;
    }
    if (type == RoomType.hardcore) {
      return !isHardcoreTrophyLocked(universeTrophies);
    }
    return isUnlocked(type, diamonds);
  }

  /// Lobide kilit nedeni: null = açık.
  static String? lobbyLockKey(
    RoomType type, {
    required bool tutorialCompleted,
    int gamesWon = 0,
    required int diamonds,
    int universeTrophies = 0,
    bool isAdmin = false,
  }) {
    if (isAdmin) return null;
    if (isFirstLoginLocked(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
    )) {
      return 'lobby_first_login_lock';
    }
    if (type == RoomType.hardcore) {
      if (isHardcoreTrophyLocked(universeTrophies)) {
        return 'room_hardcore_lock';
      }
      return null;
    }
    if (!isUnlocked(type, diamonds)) {
      return 'room_requires_diamonds';
    }
    return null;
  }

  String get instanceTitleKey => switch (this) {
        RoomType.simple => 'room_simple_title',
        RoomType.normal => 'room_instance_normal',
        RoomType.elite => 'room_instance_elite',
        RoomType.unique => 'room_instance_unique',
        RoomType.hardcore => 'room_hardcore_title',
      };

  /// Yük testi odası başlığı — "Normal Evren Test{number}".
  String get loadTestInstanceTitleKey => switch (this) {
        RoomType.simple => 'room_simple_title',
        RoomType.normal => 'room_instance_normal_test',
        RoomType.elite => 'room_instance_elite_test',
        RoomType.unique => 'room_instance_unique_test',
        RoomType.hardcore => 'room_hardcore_title',
      };

  String instanceTitle(
    String Function(String key) t, {
    required int number,
    bool isLoadTest = false,
  }) {
    final key = isLoadTest ? loadTestInstanceTitleKey : instanceTitleKey;
    return t(key).replaceAll('{number}', '$number');
  }

  /// İlk kilidi açık oda (basit → normal → elite → unique sırası).
  static RoomType? firstAvailable(int diamonds) {
    for (final type in RoomType.values) {
      if (type == RoomType.hardcore) continue;
      if (isUnlocked(type, diamonds)) return type;
    }
    return null;
  }

  int get requiredDiamonds => unlockDiamonds[this] ?? 0;

  /// Universe cup slots shown in lobby / profile.
  int get trophySlotCount => switch (this) {
        RoomType.simple => 1,
        RoomType.normal => 3,
        RoomType.elite => 3,
        RoomType.unique => 3,
        RoomType.hardcore => 0,
      };

  /// Players-only rooms never spawn bots.
  bool get isPlayersOnly => this == RoomType.hardcore;
}
