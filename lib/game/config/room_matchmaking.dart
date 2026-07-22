/// Çok oyunculu evren oda atama kuralları.
class RoomMatchmaking {
  const RoomMatchmaking._();

  /// Lider yarıçapı bu değere ulaştığında odaya yeni oyuncu alınmaz.
  /// 280: snowball kilidi biraz daha geç — orta oyunda koltuklar açık kalsın.
  static const leaderRadiusJoinThreshold = 280;

  /// Rekabetçi odalarda (normal / elite / unique) en fazla gerçek oyuncu.
  /// Eğitim evreni matchmaking kullanmaz; yerel 1 oyuncu + bot doldurması.
  static const maxRealPlayersPerRoom = 10;

  /// Gerçek oyuncu + bot toplam hedefi (10+10 doluyken).
  static const roomEntityCapacity = 20;

  /// [realPlayers] için kaç bot spawn edilmeli.
  static int botCountFor(int realPlayers) {
    final real = realPlayers.clamp(0, maxRealPlayersPerRoom);
    return (roomEntityCapacity - real).clamp(0, roomEntityCapacity);
  }

  /// Eğitim oturumu: 1 insan → kalan koltuklar bot.
  static const trainingBotsPerSession = roomEntityCapacity - 1;

  /// Lobide toplam oyuncu kapasitesi (açık evren × oda tavanı).
  static int playerCapacityForUniverses(int activeUniverses) {
    final universes = activeUniverses < 1 ? 1 : activeUniverses;
    return universes * maxRealPlayersPerRoom;
  }
}
