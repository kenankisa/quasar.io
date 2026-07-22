// Oyuncu ↔ admin mesajlaşma modelleri.

enum MessageCategory {
  feedback,
  suggestion,
  bug,
  direct,
  broadcast;

  static MessageCategory fromRpc(String? value) {
    return MessageCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => MessageCategory.feedback,
    );
  }

  String get labelKey => switch (this) {
        MessageCategory.feedback => 'msg_category_feedback',
        MessageCategory.suggestion => 'msg_category_suggestion',
        MessageCategory.bug => 'msg_category_bug',
        MessageCategory.direct => 'msg_category_direct',
        MessageCategory.broadcast => 'msg_category_broadcast',
      };

  bool get isPlayerComposable =>
      this == MessageCategory.feedback ||
      this == MessageCategory.suggestion ||
      this == MessageCategory.bug;
}

enum MessageThreadStatus {
  open,
  closed;

  static MessageThreadStatus fromRpc(String? value) {
    return value == 'closed'
        ? MessageThreadStatus.closed
        : MessageThreadStatus.open;
  }
}

enum MessageSenderRole {
  player,
  admin;

  static MessageSenderRole fromRpc(String? value) {
    return value == 'admin'
        ? MessageSenderRole.admin
        : MessageSenderRole.player;
  }
}

class MessageThread {
  const MessageThread({
    required this.id,
    required this.playerId,
    required this.playerUsername,
    required this.playerAvatarUrl,
    required this.category,
    required this.subject,
    required this.status,
    required this.preview,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.createdAt,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      playerUsername: (json['player_username'] as String?)?.trim().isNotEmpty ==
              true
          ? json['player_username'] as String
          : 'Player',
      playerAvatarUrl: json['player_avatar_url'] as String?,
      category: MessageCategory.fromRpc(json['category'] as String?),
      subject: (json['subject'] as String?) ?? '',
      status: MessageThreadStatus.fromRpc(json['status'] as String?),
      preview: (json['preview'] as String?) ?? '',
      unreadCount: _asInt(json['unread_count']),
      lastMessageAt: _asDate(json['last_message_at']) ?? DateTime.now().toUtc(),
      createdAt: _asDate(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }

  final String id;
  final String playerId;
  final String playerUsername;
  final String? playerAvatarUrl;
  final MessageCategory category;
  final String subject;
  final MessageThreadStatus status;
  final String preview;
  final int unreadCount;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  bool get hasUnread => unreadCount > 0;
}

class AdminChatMessage {
  const AdminChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory AdminChatMessage.fromJson(Map<String, dynamic> json) {
    return AdminChatMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: MessageSenderRole.fromRpc(json['sender_role'] as String?),
      body: (json['body'] as String?) ?? '',
      createdAt: _asDate(json['created_at']) ?? DateTime.now().toUtc(),
      readAt: _asDate(json['read_at']),
    );
  }

  final String id;
  final String threadId;
  final String senderId;
  final MessageSenderRole senderRole;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isFromAdmin => senderRole == MessageSenderRole.admin;
}

class MessagePlayerOption {
  const MessagePlayerOption({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory MessagePlayerOption.fromJson(Map<String, dynamic> json) {
    return MessagePlayerOption(
      id: json['id'] as String,
      username: (json['username'] as String?)?.trim().isNotEmpty == true
          ? json['username'] as String
          : 'Player',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String id;
  final String username;
  final String? avatarUrl;
}

class ThreadDetail {
  const ThreadDetail({
    required this.thread,
    required this.messages,
  });

  final MessageThread thread;
  final List<AdminChatMessage> messages;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  return null;
}
