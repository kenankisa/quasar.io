import '../services/lang_service.dart';
import 'match_time.dart';

/// Passive elim cooldown is 5 minutes; active win/elim is ~1 hour.
const hardcorePassiveCooldownMax = Duration(minutes: 10);

/// Snackbar / lock message with `{time}` filled from [remaining].
String hardcoreCooldownLockMessage(
  LanguageService lang,
  Duration? remaining,
) {
  final time = remaining != null
      ? formatCooldownRemaining(remaining)
      : formatCooldownRemaining(const Duration(hours: 1));
  final key = remaining != null &&
          remaining <= hardcorePassiveCooldownMax
      ? 'hardcore_cooldown_lock_passive'
      : 'hardcore_cooldown_lock';
  return lang.t(key).replaceAll('{time}', time);
}

/// Lobby card overlay while re-entry is blocked.
String hardcoreLobbyCooldownLabel(
  LanguageService lang,
  Duration remaining,
) {
  return lang
      .t('hardcore_lobby_cooldown')
      .replaceAll('{time}', formatCooldownRemaining(remaining));
}
