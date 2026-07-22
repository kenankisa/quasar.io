import 'package:flutter/foundation.dart';

import '../game/models/admin_message.dart';
import 'auth_service.dart';

/// Oyuncu gelen kutusu ve admin'e mesaj gönderme.
class PlayerInboxService extends ChangeNotifier {
  PlayerInboxService._();
  static final PlayerInboxService instance = PlayerInboxService._();

  List<MessageThread> _threads = const [];
  List<MessageThread> get threads => _threads;

  ThreadDetail? _selected;
  ThreadDetail? get selected => _selected;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _loading = false;
  bool get loading => _loading;

  bool _detailLoading = false;
  bool get detailLoading => _detailLoading;

  bool _sending = false;
  bool get sending => _sending;

  String? _error;
  String? get error => _error;

  bool _refreshInFlight = false;

  Future<void> refresh() async {
    await Future.wait([
      refreshThreads(),
      refreshUnreadCount(),
    ]);
  }

  Future<void> refreshThreads() async {
    if (AuthService.instance.currentUser == null) return;
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    _loading = true;
    notifyListeners();

    try {
      final response =
          await AuthService.instance.client.rpc('player_list_threads');
      final map = _asMap(response);
      final list = (map['threads'] as List?) ?? const [];
      _threads = list
          .whereType<Map>()
          .map((e) => MessageThread.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('PlayerInboxService refreshThreads failed: $e\n$stackTrace');
      _error = 'msg_err_generic';
    } finally {
      _loading = false;
      _refreshInFlight = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    if (AuthService.instance.currentUser == null) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }
    try {
      final response =
          await AuthService.instance.client.rpc('player_unread_message_count');
      _unreadCount = _asInt(response);
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint(
        'PlayerInboxService refreshUnreadCount failed: $e\n$stackTrace',
      );
    }
  }

  Future<void> openThread(String threadId) async {
    _detailLoading = true;
    notifyListeners();
    try {
      final response = await AuthService.instance.client.rpc(
        'player_get_thread',
        params: {'p_thread_id': threadId},
      );
      final map = _asMap(response);
      _selected = ThreadDetail(
        thread: MessageThread.fromJson(_asMap(map['thread'])),
        messages: ((map['messages'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AdminChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
      _error = null;
      await Future.wait([refreshThreads(), refreshUnreadCount()]);
    } catch (e, stackTrace) {
      debugPrint('PlayerInboxService openThread failed: $e\n$stackTrace');
      _error = 'msg_err_generic';
    } finally {
      _detailLoading = false;
      notifyListeners();
    }
  }

  void clearSelected() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  Future<bool> submit({
    required MessageCategory category,
    required String subject,
    required String body,
  }) async {
    if (!category.isPlayerComposable || _sending) return false;
    _sending = true;
    notifyListeners();
    try {
      final response = await AuthService.instance.client.rpc(
        'submit_player_message',
        params: {
          'p_category': category.name,
          'p_subject': subject,
          'p_body': body,
        },
      );
      final map = _asMap(response);
      final thread = MessageThread.fromJson(_asMap(map['thread']));
      await refreshThreads();
      await openThread(thread.id);
      return true;
    } catch (e, stackTrace) {
      debugPrint('PlayerInboxService submit failed: $e\n$stackTrace');
      _error = _mapMessagingError(e);
      notifyListeners();
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<bool> reply(String body) async {
    final thread = _selected?.thread;
    if (thread == null || _sending) return false;
    if (thread.category == MessageCategory.broadcast) return false;

    _sending = true;
    notifyListeners();
    try {
      await AuthService.instance.client.rpc(
        'player_reply_to_thread',
        params: {
          'p_thread_id': thread.id,
          'p_body': body,
        },
      );
      await openThread(thread.id);
      return true;
    } catch (e, stackTrace) {
      debugPrint('PlayerInboxService reply failed: $e\n$stackTrace');
      _error = _mapMessagingError(e);
      notifyListeners();
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Rate-limit / validation hatalarını lang key'e çevirir.
  static String _mapMessagingError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('too_many_open_threads')) {
      return 'msg_err_too_many_open';
    }
    if (msg.contains('thread_hourly_limit')) {
      return 'msg_err_thread_hourly';
    }
    if (msg.contains('thread_cooldown')) {
      return 'msg_err_thread_cooldown';
    }
    if (msg.contains('message_hourly_limit')) {
      return 'msg_err_message_hourly';
    }
    if (msg.contains('message_cooldown')) {
      return 'msg_err_message_cooldown';
    }
    return 'msg_err_generic';
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
