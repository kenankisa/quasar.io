/// Daily quest pool metadata (titles are i18n keys on the client).
class DailyQuestIds {
  DailyQuestIds._();

  static const easy = [
    'K1', 'K2', 'K3', 'K4', 'K5', 'K6', 'K7', 'K8', 'K9', 'K10',
  ];
  static const medium = [
    'O1', 'O2', 'O3', 'O4', 'O5', 'O6', 'O7', 'O8', 'O9', 'O10',
  ];
  static const hard = [
    'Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Z6', 'Z7', 'Z8', 'Z9', 'Z10',
  ];

  static String titleKey(String questId) =>
      'daily_quest_${questId.toLowerCase()}_title';

  static String difficultyKey(String difficulty) => switch (difficulty) {
        'easy' => 'daily_quest_difficulty_easy',
        'medium' => 'daily_quest_difficulty_medium',
        'hard' => 'daily_quest_difficulty_hard',
        _ => 'daily_quest_difficulty_easy',
      };

  static int completionRewardFor(String difficulty) => switch (difficulty) {
        'easy' => 2,
        'medium' => 4,
        'hard' => 6,
        _ => 2,
      };
}

class DailyQuestGrant {
  const DailyQuestGrant({
    required this.kind,
    required this.diamonds,
    this.questId,
  });

  factory DailyQuestGrant.fromJson(Map<String, dynamic> json) {
    return DailyQuestGrant(
      kind: json['kind'] as String? ?? 'quest',
      diamonds: _asInt(json['diamonds']),
      questId: json['quest_id'] as String?,
    );
  }

  static int _asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  final String kind;
  final int diamonds;
  final String? questId;
}

class DailyQuestEntry {
  const DailyQuestEntry({
    required this.questId,
    required this.difficulty,
    required this.rewardDiamonds,
    required this.progress,
    required this.target,
    required this.completed,
    required this.claimed,
  });

  factory DailyQuestEntry.fromJson(Map<String, dynamic> json) {
    final difficulty = json['difficulty'] as String? ?? 'easy';
    return DailyQuestEntry(
      questId: json['quest_id'] as String? ?? '',
      difficulty: difficulty,
      rewardDiamonds: _asInt(json['reward_diamonds']) > 0
          ? _asInt(json['reward_diamonds'])
          : DailyQuestIds.completionRewardFor(difficulty),
      progress: _asInt(json['progress']),
      target: _asInt(json['target'], 1),
      completed: json['completed'] == true,
      claimed: json['claimed'] == true,
    );
  }

  static int _asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  final String questId;
  final String difficulty;
  final int rewardDiamonds;
  final int progress;
  final int target;
  final bool completed;
  final bool claimed;

  bool get showProgress => target > 1 && !completed;
}

class DailyQuestsStatus {
  const DailyQuestsStatus({
    required this.questDay,
    this.nextResetAt,
    required this.quests,
    required this.completedCount,
    required this.grants,
  });

  factory DailyQuestsStatus.fromRpc(Object? raw) {
    final map = _asMap(raw);
    final questsRaw = map['quests'];
    final quests = <DailyQuestEntry>[];
    if (questsRaw is List) {
      for (final item in questsRaw) {
        if (item is Map) {
          quests.add(DailyQuestEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final grantsRaw = map['grants'];
    final grants = <DailyQuestGrant>[];
    if (grantsRaw is List) {
      for (final item in grantsRaw) {
        if (item is Map) {
          grants.add(DailyQuestGrant.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return DailyQuestsStatus(
      questDay: map['quest_day']?.toString(),
      nextResetAt: _readDateTime(map['next_reset_at']),
      quests: quests,
      completedCount: _asInt(map['completed_count']),
      grants: grants,
    );
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static int _asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  final String? questDay;
  final DateTime? nextResetAt;
  final List<DailyQuestEntry> quests;
  final int completedCount;
  final List<DailyQuestGrant> grants;

  int get inProgressCount => quests.where((q) => !q.completed).length;

  int get totalQuests => quests.length;

  int get maxDailyReward => quests.fold<int>(
        0,
        (sum, quest) => sum + quest.rewardDiamonds,
      );

  int get grantsTotal =>
      grants.fold<int>(0, (sum, grant) => sum + grant.diamonds);

  bool get allComplete =>
      quests.isNotEmpty && quests.every((quest) => quest.completed);
}
