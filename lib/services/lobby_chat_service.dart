import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class LobbyChatMessage {
  const LobbyChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.sentAt,
  });

  factory LobbyChatMessage.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    DateTime sentAt;
    if (createdRaw is String) {
      sentAt = DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now();
    } else {
      sentAt = DateTime.now();
    }

    return LobbyChatMessage(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? map['id'] as String? ?? '',
      userName: map['username'] as String? ?? map['name'] as String? ?? 'Traveler',
      text: (map['body'] as String? ?? map['text'] as String? ?? '').trim(),
      sentAt: sentAt,
    );
  }

  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime sentAt;
}

/// Global lobby chat — sunucu `send_lobby_chat` + Realtime (kimlik spoof yok).
class LobbyChatService extends ChangeNotifier {
  LobbyChatService._();
  static final LobbyChatService instance = LobbyChatService._();

  static const maxMessageLength = 120;
  static const maxStoredMessages = 40;
  static const sendCooldown = Duration(milliseconds: 900);

  RealtimeChannel? _channel;
  Future<void>? _operation;
  DateTime? _lastSendAt;
  bool _sending = false;
  final List<LobbyChatMessage> _messages = [];

  List<LobbyChatMessage> get messages => List.unmodifiable(_messages);

  SupabaseClient get _client => AuthService.instance.client;

  Future<void> attach() => _run(() async {
        if (_channel != null) return;
        if (AuthService.instance.currentUser == null) return;

        await _loadRecent();

        final channel = _client
            .channel('lobby_chat_messages_rt')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'lobby_chat_messages',
              callback: (payload) {
                final map = payload.newRecord;
                if (map.isEmpty) return;
                _push(LobbyChatMessage.fromMap(Map<String, dynamic>.from(map)));
              },
            );
        _channel = channel;
        channel.subscribe();
      });

  Future<void> detach() => _run(() async {
        final channel = _channel;
        _channel = null;
        _messages.clear();
        notifyListeners();
        if (channel == null) return;
        try {
          await _client.removeChannel(channel);
        } catch (e, st) {
          debugPrint('LobbyChatService detach: $e\n$st');
        }
      });

  bool get canSend {
    if (_sending) return false;
    final last = _lastSendAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= sendCooldown;
  }

  Duration? get sendCooldownRemaining {
    final last = _lastSendAt;
    if (last == null) return null;
    final left = sendCooldown - DateTime.now().difference(last);
    return left.isNegative ? null : left;
  }

  /// Kimlik sunucudan gelir — istemci userId/name gönderemez.
  Future<bool> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > maxMessageLength) return false;
    if (!canSend) return false;
    if (AuthService.instance.currentUser == null) return false;

    _sending = true;
    _lastSendAt = DateTime.now();
    notifyListeners();
    try {
      final response = await _client.rpc(
        'send_lobby_chat',
        params: {'p_body': trimmed},
      );
      if (response is Map) {
        _push(LobbyChatMessage.fromMap(Map<String, dynamic>.from(response)));
      }
      return true;
    } on PostgrestException catch (e) {
      debugPrint('LobbyChatService send: ${e.message}');
      // Sunucu cooldown — yerel timer'ı bozma.
      if (!e.message.toLowerCase().contains('chat_cooldown')) {
        _lastSendAt = null;
      }
      return false;
    } catch (e, st) {
      debugPrint('LobbyChatService send: $e\n$st');
      _lastSendAt = null;
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _loadRecent() async {
    try {
      final rows = await _client
          .from('lobby_chat_messages')
          .select('id, user_id, username, body, created_at')
          .order('created_at', ascending: false)
          .limit(maxStoredMessages);
      final parsed = rows
          .map((row) => LobbyChatMessage.fromMap(Map<String, dynamic>.from(row)))
          .where((m) => m.id.isNotEmpty && m.text.isNotEmpty)
          .toList()
          .reversed;
      _messages
        ..clear()
        ..addAll(parsed);
      notifyListeners();
    } catch (e, st) {
      debugPrint('LobbyChatService loadRecent: $e\n$st');
    }
  }

  void _push(LobbyChatMessage msg) {
    if (msg.id.isEmpty || msg.text.isEmpty || msg.userId.isEmpty) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    _messages.add(msg);
    while (_messages.length > maxStoredMessages) {
      _messages.removeAt(0);
    }
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_operation != null) await _operation;
    _operation = action();
    try {
      await _operation;
    } finally {
      _operation = null;
    }
  }
}
