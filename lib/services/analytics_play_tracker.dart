import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/room_type.dart';
import 'admin_access.dart';
import 'auth_service.dart';

/// Evren oyun süresi takibi — tüm oda tipleri (kalıcı analytics tablosu).
///
/// [game_room_members] oda yeniden açılınca silindiği için oynayan oyuncu
/// sayımı burada tutulur.
class AnalyticsPlayTracker {
  AnalyticsPlayTracker._();
  static final AnalyticsPlayTracker instance = AnalyticsPlayTracker._();

  RoomType? _openRoom;

  Future<void> begin(RoomType roomType) async {
    if (AdminAccess.isCurrentUserAdmin) return;
    if (!AuthService.instance.isSignedIn) return;

    try {
      await AuthService.instance.client.rpc(
        'analytics_begin_play_session',
        params: {'p_room_type': roomType.name},
      );
      _openRoom = roomType;
    } on PostgrestException catch (e) {
      debugPrint('analytics_begin_play_session: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('analytics_begin_play_session failed: $e\n$stackTrace');
    }
  }

  Future<void> end({RoomType? roomType}) async {
    final open = _openRoom;
    if (open == null) return;
    if (AdminAccess.isCurrentUserAdmin) {
      _openRoom = null;
      return;
    }
    if (!AuthService.instance.isSignedIn) {
      _openRoom = null;
      return;
    }

    try {
      await AuthService.instance.client.rpc(
        'analytics_end_play_session',
        params: {'p_room_type': (roomType ?? open).name},
      );
    } on PostgrestException catch (e) {
      debugPrint('analytics_end_play_session: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('analytics_end_play_session failed: $e\n$stackTrace');
    } finally {
      _openRoom = null;
    }
  }
}
