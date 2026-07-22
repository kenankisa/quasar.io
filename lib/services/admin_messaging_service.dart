import 'package:flutter/foundation.dart';

import '../game/models/admin_message.dart';
import 'admin_access.dart';
import 'auth_service.dart';

/// Admin paneli mesajlaşma (RPC: admin_*_message*).
class AdminMessagingService extends ChangeNotifier {
  AdminMessagingService._();
  static final AdminMessagingService instance = AdminMessagingService._();

  List<MessageThread> _threads = const [];
  List<MessageThread> get threads => _threads;

  ThreadDetail? _selected;
  ThreadDetail? get selected => _selected;

  List<MessagePlayerOption> _players = const [];
  List<MessagePlayerOption> get players => _players;

  String _statusFilter = 'open';
  String get statusFilter => _statusFilter;

  String? _categoryFilter;
  String? get categoryFilter => _categoryFilter;

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

  Future<void> setStatusFilter(String status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
    await refreshThreads();
  }

  Future<void> setCategoryFilter(String? category) async {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    notifyListeners();
    await refreshThreads();
  }

  Future<void> refresh() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    await Future.wait([
      refreshThreads(),
      refreshUnreadCount(),
    ]);
  }

  Future<void> refreshThreads() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    _loading = true;
    notifyListeners();

    try {
      final response = await AuthService.instance.client.rpc(
        'admin_list_message_threads',
        params: {
          'p_status': _statusFilter,
          'p_category': _categoryFilter,
        },
      );

      final map = _asMap(response);
      final list = (map['threads'] as List?) ?? const [];
      _threads = list
          .whereType<Map>()
          .map((e) => MessageThread.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('AdminMessagingService refreshThreads failed: $e\n$stackTrace');
      _error = 'error_generic';
    } finally {
      _loading = false;
      _refreshInFlight = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    try {
      final response =
          await AuthService.instance.client.rpc('admin_unread_message_count');
      _unreadCount = _asInt(response);
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint(
        'AdminMessagingService refreshUnreadCount failed: $e\n$stackTrace',
      );
    }
  }

  Future<void> openThread(
    String threadId, {
    bool refreshList = false,
  }) async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    _detailLoading = true;
    notifyListeners();

    try {
      final response = await AuthService.instance.client.rpc(
        'admin_get_message_thread',
        params: {'p_thread_id': threadId},
      );
      final map = _asMap(response);
      final threadMap = _asMap(map['thread']);
      final messages = ((map['messages'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AdminChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final thread = MessageThread.fromJson(threadMap);
      _selected = ThreadDetail(
        thread: thread,
        messages: messages,
      );
      _patchThreadInList(thread);
      _error = null;
      if (refreshList) {
        await Future.wait([refreshThreads(), refreshUnreadCount()]);
      } else {
        // Okundu sayacı için hafif RPC; tüm thread listesini yeniden çekme.
        await refreshUnreadCount();
      }
    } catch (e, stackTrace) {
      debugPrint('AdminMessagingService openThread failed: $e\n$stackTrace');
      _error = 'error_generic';
    } finally {
      _detailLoading = false;
      notifyListeners();
    }
  }

  void _patchThreadInList(MessageThread thread) {
    final idx = _threads.indexWhere((t) => t.id == thread.id);
    if (idx < 0) return;
    final next = List<MessageThread>.from(_threads);
    next[idx] = thread;
    _threads = next;
  }

  void clearSelected() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  Future<bool> reply(String body) async {
    final threadId = _selected?.thread.id;
    if (threadId == null || !AdminAccess.isCurrentUserAdmin) return false;
    if (_sending) return false;

    _sending = true;
    notifyListeners();
    try {
      await AuthService.instance.client.rpc(
        'admin_reply_to_thread',
        params: {
          'p_thread_id': threadId,
          'p_body': body,
        },
      );
      await openThread(threadId);
      return true;
    } catch (e, stackTrace) {
      debugPrint('AdminMessagingService reply failed: $e\n$stackTrace');
      _error = 'error_generic';
      notifyListeners();
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<bool> sendDirect({
    required String playerId,
    required String subject,
    required String body,
  }) async {
    if (!AdminAccess.isCurrentUserAdmin || _sending) return false;
    _sending = true;
    notifyListeners();
    try {
      final response = await AuthService.instance.client.rpc(
        'admin_send_direct_message',
        params: {
          'p_player_id': playerId,
          'p_subject': subject,
          'p_body': body,
        },
      );
      final map = _asMap(response);
      final thread = MessageThread.fromJson(_asMap(map['thread']));
      await refresh();
      await openThread(thread.id);
      return true;
    } catch (e, stackTrace) {
      debugPrint('AdminMessagingService sendDirect failed: $e\n$stackTrace');
      _error = 'error_generic';
      notifyListeners();
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<int?> broadcast({
    required String subject,
    required String body,
  }) async {
    if (!AdminAccess.isCurrentUserAdmin || _sending) return null;
    _sending = true;
    notifyListeners();
    try {
      final response = await AuthService.instance.client.rpc(
        'admin_broadcast_message',
        params: {
          'p_subject': subject,
          'p_body': body,
        },
      );
      final map = _asMap(response);
      final count = _asInt(map['sent_count']);
      await refreshThreads();
      return count;
    } catch (e, stackTrace) {
      debugPrint('AdminMessagingService broadcast failed: $e\n$stackTrace');
      _error = 'error_generic';
      notifyListeners();
      return null;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<bool> setThreadStatus(String threadId, MessageThreadStatus status) async {
    if (!AdminAccess.isCurrentUserAdmin) return false;
    try {
      await AuthService.instance.client.rpc(
        'admin_set_thread_status',
        params: {
          'p_thread_id': threadId,
          'p_status': status.name,
        },
      );
      if (_selected?.thread.id == threadId) {
        await openThread(threadId);
      } else {
        await refreshThreads();
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'AdminMessagingService setThreadStatus failed: $e\n$stackTrace',
      );
      _error = 'error_generic';
      notifyListeners();
      return false;
    }
  }

  Future<void> searchPlayers(String query) async {
    if (!AdminAccess.isCurrentUserAdmin) return;
    try {
      final response = await AuthService.instance.client.rpc(
        'admin_list_message_players',
        params: {'p_query': query},
      );
      final map = _asMap(response);
      final list = (map['players'] as List?) ?? const [];
      _players = list
          .whereType<Map>()
          .map(
            (e) => MessagePlayerOption.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('AdminMessagingService searchPlayers failed: $e\n$stackTrace');
    }
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
