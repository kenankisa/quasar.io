import 'package:flutter/foundation.dart';

import '../../game/models/room_instance.dart';
import '../../game/room_type.dart';
import '../../services/admin_access.dart';
import '../../services/lang_service.dart';
import '../../services/room_matchmaking_service.dart';

/// Context-free helpers for competitive join + matchmaking error copy.
/// Full enter-room orchestration stays on [LobbyScreen] (portal / navigator).
class LobbyMatchEntry {
  const LobbyMatchEntry._();

  /// Admin yük testinde açık sim odasına katıl; aksi halde normal matchmaking.
  /// Dolu/bitmek üzere sim odası yüzünden tüm oyuncuların takılmasını engeller.
  static Future<RoomInstance> joinCompetitiveRoom(RoomType roomType) async {
    if (AdminAccess.isCurrentUserAdmin) {
      final simRooms =
          await RoomMatchmakingService.instance.listSimLoadTestRooms();
      final match = simRooms
          .where((r) => r.roomType == roomType.name && r.players > 0)
          .toList();
      if (match.isNotEmpty) {
        match.sort((a, b) => b.players.compareTo(a.players));
        try {
          return await RoomMatchmakingService.instance
              .joinRoomInstance(match.first.roomInstanceId);
        } on RoomMatchmakingException catch (e) {
          debugPrint(
            'Sim room join failed, falling back to matchmaking: ${e.message}',
          );
        }
      }
    }

    return RoomMatchmakingService.instance.joinRoom(roomType);
  }

  static String matchmakingErrorText(String raw) {
    final lang = LanguageService.instance;
    final msg = raw.toLowerCase();
    if (msg.contains('first_login_lock')) {
      return lang.t('lobby_first_login_lock');
    }
    if (msg.contains('insufficient_diamonds')) {
      return lang.t('matchmaking_insufficient_diamonds');
    }
    if (msg.contains('room_full')) {
      return lang.t('matchmaking_room_full');
    }
    if (msg.contains('room_ending') || msg.contains('room_closed')) {
      return lang.t('matchmaking_room_ending');
    }
    if (msg.contains('not authenticated')) {
      return lang.t('matchmaking_not_authenticated');
    }
    return lang.t('matchmaking_error');
  }
}
