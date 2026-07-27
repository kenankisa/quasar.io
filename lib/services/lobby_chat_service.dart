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

  /// HH:mm — lobi sohbet satırında gösterim.
  String get timeLabel {
    final t = sentAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  bool isExpired(Duration ttl, [DateTime? now]) {
    final anchor = now ?? DateTime.now();
    return anchor.difference(sentAt) >= ttl;
  }
}

/// Global lobby chat — sunucu `send_lobby_chat` + Realtime (kimlik spoof yok).
class LobbyChatService extends ChangeNotifier {
  LobbyChatService._();
  static final LobbyChatService instance = LobbyChatService._();

  static const maxMessageLength = 120;
  static const maxStoredMessages = 40;
  static const messageTtl = Duration(minutes: 30);
  static const _expirySweepInterval = Duration(seconds: 30);

  RealtimeChannel? _channel;
  Timer? _expiryTimer;
  Future<void>? _operation;
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
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'lobby_chat_messages',
              callback: (payload) {
                final id = payload.oldRecord['id'] as String?;
                if (id == null || id.isEmpty) return;
                _removeById(id);
              },
            );
        _channel = channel;
        channel.subscribe();
        _startExpiryTimer();
      });

  Future<void> detach() => _run(() async {
        _stopExpiryTimer();
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

  bool get canSend => AuthService.instance.currentUser != null;

  /// Kimlik sunucudan gelir — istemci userId/name gönderemez.
  Future<bool> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > maxMessageLength) return false;
    if (!canSend) return false;

    unawaited(_dispatchSend(trimmed));
    return true;
  }

  Future<void> _dispatchSend(String trimmed) async {
    try {
      final response = await _client.rpc(
        'send_lobby_chat',
        params: {'p_body': trimmed},
      );
      if (response is Map) {
        _push(LobbyChatMessage.fromMap(Map<String, dynamic>.from(response)));
      }
    } on PostgrestException catch (e) {
      debugPrint('LobbyChatService send: ${e.message}');
    } catch (e, st) {
      debugPrint('LobbyChatService send: $e\n$st');
    }
  }

  Future<void> _loadRecent() async {
    try {
      unawaited(
        _client.rpc('purge_stale_lobby_chat').catchError((Object e, StackTrace st) {
          debugPrint('LobbyChatService purge: $e\n$st');
        }),
      );

      final cutoff = DateTime.now().toUtc().subtract(messageTtl).toIso8601String();
      final rows = await _client
          .from('lobby_chat_messages')
          .select('id, user_id, username, body, created_at')
          .gte('created_at', cutoff)
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
    if (msg.isExpired(messageTtl)) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    _messages.add(msg);
    _trimOverflow();
    notifyListeners();
  }

  void _removeById(String id) {
    final before = _messages.length;
    _messages.removeWhere((m) => m.id == id);
    if (_messages.length != before) notifyListeners();
  }

  void _trimOverflow() {
    _pruneExpired();
    while (_messages.length > maxStoredMessages) {
      _messages.removeAt(0);
    }
  }

  void _pruneExpired() {
    final before = _messages.length;
    _messages.removeWhere((m) => m.isExpired(messageTtl));
    if (_messages.length != before) notifyListeners();
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(_expirySweepInterval, (_) => _pruneExpired());
  }

  void _stopExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
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
