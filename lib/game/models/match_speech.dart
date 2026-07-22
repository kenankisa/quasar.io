/// Ephemeral in-match speech / chat / absorb flex (Realtime broadcast).
enum MatchSpeechKind { reaction, chat, absorb }

class MatchSpeechEvent {
  const MatchSpeechEvent({
    required this.playerId,
    required this.playerName,
    required this.text,
    required this.kind,
    this.preyId,
    this.preyName,
  });

  factory MatchSpeechEvent.fromMap(Map<String, dynamic> map) {
    final kindRaw = map['kind'] as String? ?? 'chat';
    final kind = switch (kindRaw) {
      'reaction' => MatchSpeechKind.reaction,
      'absorb' => MatchSpeechKind.absorb,
      _ => MatchSpeechKind.chat,
    };
    return MatchSpeechEvent(
      playerId: map['id'] as String? ?? '',
      playerName: map['name'] as String? ?? 'Traveler',
      text: (map['text'] as String? ?? '').trim(),
      kind: kind,
      preyId: map['prey_id'] as String?,
      preyName: map['prey_name'] as String?,
    );
  }

  final String playerId;
  final String playerName;
  final String text;
  final MatchSpeechKind kind;
  final String? preyId;
  final String? preyName;

  Map<String, dynamic> toMap() => {
        'id': playerId,
        'name': playerName,
        'text': text,
        'kind': kind.name,
        if (preyId != null) 'prey_id': preyId,
        if (preyName != null) 'prey_name': preyName,
      };
}

class MatchFeedEntry {
  MatchFeedEntry({
    required this.id,
    required this.text,
    required this.createdAt,
    this.isKill = false,
    this.name,
  });

  final String id;
  /// When set (chat lines), shown above [text] so the message is not truncated.
  final String? name;
  final String text;
  final DateTime createdAt;
  final bool isKill;
}

class SpeechBubbleState {
  SpeechBubbleState({required this.text, required this.remaining});

  String text;
  double remaining;
}

/// Quick-reaction presets shown in the radial picker.
class MatchReactionPreset {
  const MatchReactionPreset({
    required this.id,
    required this.labelKey,
    required this.fallback,
  });

  final String id;
  final String labelKey;
  final String fallback;
}

const kMatchReactionPresets = <MatchReactionPreset>[
  MatchReactionPreset(id: 'gg', labelKey: 'match_react_gg', fallback: 'GG'),
  MatchReactionPreset(
    id: 'nice',
    labelKey: 'match_react_nice',
    fallback: 'Nice',
  ),
  MatchReactionPreset(id: 'run', labelKey: 'match_react_run', fallback: 'Run!'),
  MatchReactionPreset(
    id: 'help',
    labelKey: 'match_react_help',
    fallback: 'Help',
  ),
  MatchReactionPreset(id: 'lol', labelKey: 'match_react_lol', fallback: 'Lol'),
  MatchReactionPreset(id: 'wow', labelKey: 'match_react_wow', fallback: 'Wow'),
];

const kAbsorbFlexPresets = <MatchReactionPreset>[
  MatchReactionPreset(
    id: 'absorbed',
    labelKey: 'match_absorb_flex',
    fallback: 'Absorbed!',
  ),
  MatchReactionPreset(
    id: 'bye',
    labelKey: 'match_absorb_bye',
    fallback: 'Bye bye',
  ),
  MatchReactionPreset(
    id: 'small',
    labelKey: 'match_absorb_small',
    fallback: 'Too small',
  ),
  MatchReactionPreset(
    id: 'yummy',
    labelKey: 'match_absorb_yummy',
    fallback: 'Delicious',
  ),
  MatchReactionPreset(
    id: 'gone',
    labelKey: 'match_absorb_gone',
    fallback: 'Gone.',
  ),
  MatchReactionPreset(
    id: 'mine',
    labelKey: 'match_absorb_mine',
    fallback: 'Mine.',
  ),
  MatchReactionPreset(
    id: 'void',
    labelKey: 'match_absorb_void',
    fallback: 'Into the void.',
  ),
  MatchReactionPreset(
    id: 'next',
    labelKey: 'match_absorb_next',
    fallback: 'Next!',
  ),
  MatchReactionPreset(
    id: 'crushed',
    labelKey: 'match_absorb_crushed',
    fallback: 'Crushed.',
  ),
];

/// Settings picker: Random + 9 fixed lines = 10 choices.
const kAbsorbBubbleChoices = <MatchReactionPreset>[
  MatchReactionPreset(
    id: 'random',
    labelKey: 'match_absorb_random',
    fallback: 'Random',
  ),
  ...kAbsorbFlexPresets,
];

MatchReactionPreset? absorbPresetById(String id) {
  for (final preset in kAbsorbBubbleChoices) {
    if (preset.id == id) return preset;
  }
  return null;
}
