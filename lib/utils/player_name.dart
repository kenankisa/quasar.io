/// In-game and profile display names are capped at [maxLength] characters.
const int maxPlayerNameLength = 12;

/// Returns [name] trimmed; if longer than [maxPlayerNameLength], keeps the first
/// [maxPlayerNameLength] characters only.
String clampPlayerName(String name) {
  final trimmed = name.trim();
  if (trimmed.length <= maxPlayerNameLength) return trimmed;
  return trimmed.substring(0, maxPlayerNameLength);
}
