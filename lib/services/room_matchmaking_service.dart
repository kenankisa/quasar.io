import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/models/room_instance.dart';
import '../game/room_type.dart';
import 'auth_service.dart';

class RoomMatchmakingException implements Exception {
  const RoomMatchmakingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SimLoadTestRoom {
  const SimLoadTestRoom({
    required this.roomInstanceId,
    required this.roomType,
    required this.instanceNumber,
    required this.players,
    required this.leaderRadius,
  });

  factory SimLoadTestRoom.fromJson(Map<String, dynamic> json) {
    return SimLoadTestRoom(
      roomInstanceId: json['room_instance_id'] as String,
      roomType: json['room_type'] as String? ?? 'normal',
      instanceNumber: json['instance_number'] as int? ?? 1,
      players: json['players'] as int? ?? 0,
      leaderRadius: json['leader_radius'] as int? ?? 25,
    );
  }

  final String roomInstanceId;
  final String roomType;
  final int instanceNumber;
  final int players;
  final int leaderRadius;
}

/// Sunucu tarafı oda atama — eğitim evreni hariç tüm evrenler.
class RoomMatchmakingService {
  RoomMatchmakingService._();
  static final RoomMatchmakingService instance = RoomMatchmakingService._();

  SupabaseClient get _client => AuthService.instance.client;

  String? _activeRoomInstanceId;

  Future<RoomInstance> joinRoom(RoomType roomType) async {
    if (roomType == RoomType.simple) {
      throw const RoomMatchmakingException('training_room_no_matchmaking');
    }

    try {
      final response = await _client.rpc(
        'join_game_room',
        params: {'p_room_type': roomType.name},
      );

      if (response == null) {
        throw const RoomMatchmakingException('join_game_room_empty_response');
      }

      final map = Map<String, dynamic>.from(response as Map);
      final instance = RoomInstance.fromJson(map);
      _activeRoomInstanceId = instance.id;
      return ensureRoomCosmicSync(instance);
    } on PostgrestException catch (e) {
      debugPrint('join_game_room: ${e.message}');
      throw RoomMatchmakingException(e.message);
    }
  }

  /// Belirli oda instance'ına katıl (sim / yük testi odası).
  Future<RoomInstance> joinRoomInstance(String roomInstanceId) async {
    try {
      final response = await _client.rpc(
        'join_game_room_instance',
        params: {'p_room_instance_id': roomInstanceId},
      );

      if (response == null) {
        throw const RoomMatchmakingException('join_game_room_empty_response');
      }

      final map = Map<String, dynamic>.from(response as Map);
      final instance = RoomInstance.fromJson(map);
      _activeRoomInstanceId = instance.id;
      return ensureRoomCosmicSync(instance);
    } on PostgrestException catch (e) {
      debugPrint('join_game_room_instance: ${e.message}');
      throw RoomMatchmakingException(e.message);
    }
  }

  /// Paylaşılan maç saati + cosmic seed — tüm oyuncular aynı olay takvimini kullanır.
  Future<RoomInstance> ensureRoomCosmicSync(RoomInstance instance) async {
    try {
      final response = await _client.rpc(
        'ensure_room_cosmic_sync',
        params: {'p_room_instance_id': instance.id},
      );
      if (response == null) return instance;
      final map = Map<String, dynamic>.from(response as Map);
      final synced = RoomInstance.fromJson({
        ...instance.toJsonBase(),
        'match_started_at': map['match_started_at'],
        'cosmic_seed': map['cosmic_seed'],
      });
      return synced;
    } on PostgrestException catch (e) {
      debugPrint('ensure_room_cosmic_sync: ${e.message}');
      return instance;
    }
  }

  /// Aktif sim (yük testi) odaları — telefon aynı kanala düşmek için.
  Future<List<SimLoadTestRoom>> listSimLoadTestRooms() async {
    try {
      final response = await _client.rpc('list_sim_load_test_rooms');
      if (response is! List) return const [];
      return response
          .map((e) => SimLoadTestRoom.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('list_sim_load_test_rooms: ${e.message}');
      return const [];
    }
  }

  Future<void> leaveRoom([String? roomInstanceId]) async {
    final targetId = roomInstanceId ?? _activeRoomInstanceId;
    if (targetId == null) return;

    try {
      await _client.rpc(
        'leave_game_room',
        params: {'p_room_instance_id': targetId},
      );
    } on PostgrestException catch (e) {
      debugPrint('leave_game_room: ${e.message}');
    } finally {
      if (_activeRoomInstanceId == targetId) {
        _activeRoomInstanceId = null;
      }
    }
  }

  Future<void> leaveActiveRoom() => leaveRoom();

  Future<void> updateLeaderRadius(String roomInstanceId, int leaderRadius) async {
    try {
      await _client.rpc(
        'update_room_leader_radius',
        params: {
          'p_room_instance_id': roomInstanceId,
          'p_leader_radius': leaderRadius,
        },
      );
    } on PostgrestException catch (e) {
      debugPrint('update_room_leader_radius: ${e.message}');
    }
  }

  /// Aktif oda üyeleri — Realtime broadcast allowlist için.
  Future<List<String>> listActiveMemberIds(String roomInstanceId) async {
    try {
      final response = await _client.rpc(
        'get_room_active_member_ids',
        params: {'p_room_instance_id': roomInstanceId},
      );
      if (response is! List) return const [];
      return response
          .map((e) => e?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('get_room_active_member_ids: ${e.message}');
      return const [];
    }
  }

  Future<void> closeRoom(String roomInstanceId) async {
    try {
      await _client.rpc(
        'close_game_room',
        params: {'p_room_instance_id': roomInstanceId},
      );
    } on PostgrestException catch (e) {
      debugPrint('close_game_room: ${e.message}');
    } finally {
      if (_activeRoomInstanceId == roomInstanceId) {
        _activeRoomInstanceId = null;
      }
    }
  }
}
