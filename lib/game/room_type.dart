import '../config/app_config.dart';

enum RoomType { simple, normal, elite, unique }

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
    };
  }

  /// Yutulma cezası (elmas asla 0 altına inmez — sunucu tarafında floor).
  /// Basit 0, Normal −1, Elite −2, Unique −3.
  int get eliminationDiamondPenalty => switch (this) {
        RoomType.simple => 0,
        RoomType.normal => 1,
        RoomType.elite => 2,
        RoomType.unique => 3,
      };

  bool get awardsPlacementPodium => true;
}

extension RoomTypeLobby on RoomType {
  static const unlockDiamonds = {
    RoomType.simple: 0,
    RoomType.normal: 25,
    RoomType.elite: 100,
    RoomType.unique: 200,
  };

  static bool isUnlocked(RoomType type, int diamonds) {
    if (AppConfig.devUnlockAllRooms) return true;
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
  }) {
    if (isFirstLoginLocked(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
    )) {
      return false;
    }
    return isUnlocked(type, diamonds);
  }

  /// Lobide kilit nedeni: null = açık.
  static String? lobbyLockKey(
    RoomType type, {
    required bool tutorialCompleted,
    int gamesWon = 0,
    required int diamonds,
  }) {
    if (isFirstLoginLocked(
      type,
      tutorialCompleted: tutorialCompleted,
      gamesWon: gamesWon,
    )) {
      return 'lobby_first_login_lock';
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
      };

  /// Yük testi odası başlığı — "Normal Evren Test{number}".
  String get loadTestInstanceTitleKey => switch (this) {
        RoomType.simple => 'room_simple_title',
        RoomType.normal => 'room_instance_normal_test',
        RoomType.elite => 'room_instance_elite_test',
        RoomType.unique => 'room_instance_unique_test',
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
      if (isUnlocked(type, diamonds)) return type;
    }
    return null;
  }

  int get requiredDiamonds => unlockDiamonds[this] ?? 0;
}
