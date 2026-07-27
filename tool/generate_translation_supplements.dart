// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final missing = File('tool/missing_keys.txt')
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('Used:'))
      .toList();

  const extraKeys = [
    'hardcore_onboarding_modes_title',
    'hardcore_onboarding_modes_body',
    'hardcore_onboarding_cap_title',
    'hardcore_onboarding_cap_body',
    'hardcore_onboarding_victory_title',
    'hardcore_onboarding_victory_body',
    'daily_chest_error',
    'daily_chest_already',
    'daily_chest_opened',
    'daily_chest_opened_doubled',
    'daily_chest_ad_loading',
    'daily_chest_ad_failed',
    'daily_chest_ad_unavailable',
    'daily_chest_admin_skip_ad',
    'match_day_diamond_tooltip',
    'room_hardcore_presence',
    'hardcore_gate_low_pop',
    'hardcore_gate_low_pop_cap',
    'hardcore_arena_active_tooltip',
    'hardcore_arena_passive_tooltip',
    'hardcore_gate_low_pop_cap_tooltip',
    'hardcore_onboarding_step_label',
    'lobby_version_notes',
    'v23_change_lobby_redesign',
    'v23_change_universe_cards',
    'v23_change_nasa_photos',
    'v23_change_unique_photo',
    'v23_change_title_polish',
    'v23_change_wormhole_blend',
    'v23_change_next_goal',
    'v23_change_version_notes',
    'v23_section_subtitle',
    'v23_section_title',
    'v22_change_hardcore',
    'v22_change_trophies',
    'v22_change_hc_queue',
    'v22_change_hc_rules',
    'v22_change_daily_chest',
    'v22_change_wormhole',
    'v22_change_hc_visuals',
    'v22_change_stability',
    'v22_change_security',
    'v22_change_version_notes',
  ];

  final keys = {...missing, ...extraKeys}.toList()..sort();

  final en = _enTranslations;
  final tr = _trTranslations;

  for (final k in keys) {
    if (!en.containsKey(k)) {
      throw StateError('Missing EN translation for $k');
    }
    if (!tr.containsKey(k)) {
      throw StateError('Missing TR translation for $k');
    }
  }

  _writeFile(
    'lib/services/lang/translations_supplement_en.dart',
    'kEnTranslationsSupplement',
    en,
    keys,
  );
  _writeFile(
    'lib/services/lang/translations_supplement_tr.dart',
    'kTrTranslationsSupplement',
    tr,
    keys,
  );

  print('Generated ${keys.length} keys in EN + TR supplement files.');
}

void _writeFile(
  String path,
  String mapName,
  Map<String, String> source,
  List<String> keys,
) {
  final b = StringBuffer()
    ..writeln('/// Supplemental strings merged into [LanguageService] locale maps.')
    ..writeln('const Map<String, String> $mapName = {');
  for (final k in keys) {
    b.writeln("  '${_escape(k)}': '${_escape(source[k]!)}',");
  }
  b.writeln('};');
  b.writeln();
  File(path).writeAsStringSync(b.toString());
}

String _escape(String s) => s
    .replaceAll('\\', r'\\')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll("'", r"\'");

const _enTranslations = <String, String>{
  'admin_economy_ad_doubles': 'Rewarded ad doubles per day',
  'admin_economy_chest_high': 'Chest roll — high tier',
  'admin_economy_chest_low': 'Chest roll — low tier',
  'admin_economy_chest_mid': 'Chest roll — mid tier',
  'admin_economy_chest_section': 'Daily lobby chest',
  'admin_economy_daily_cap': 'Daily match diamond cap',
  'admin_economy_hardcore_hint':
      'Hardcore victory and kill rewards, plus elimination penalty, are edited here and in Hardcore tuning.',
  'admin_economy_hardcore_section': 'Hardcore economy',
  'admin_economy_intro':
      'Diamond rewards for podium finishes, swallow penalties, universe unlock thresholds, daily lobby chest tiers, and per-day claim limits.',
  'admin_economy_limits_section': 'Daily limits',
  'admin_economy_penalty_section': 'Elimination penalties',
  'admin_economy_place_1': '1st place',
  'admin_economy_place_2': '2nd place',
  'admin_economy_place_3': '3rd place',
  'admin_economy_reset': 'Reset to defaults',
  'admin_economy_reward_claims': 'Reward claims per day',
  'admin_economy_rewards_hint':
      'Diamonds awarded for 1st / 2nd / 3rd in each universe. Training defaults are intentionally low.',
  'admin_economy_rewards_section': 'Match rewards',
  'admin_economy_save': 'Save',
  'admin_economy_start_note':
      'Changes apply on the server after save. Existing match claims are not retroactively adjusted.',
  'admin_economy_training_claims': 'Training claims per day',
  'admin_economy_unlock_section': 'Universe unlock thresholds',
  'admin_game_trial_active': 'Active sim clients',
  'admin_game_trial_added_ok':
      'Added {count} sim(s). {active} now active in Game Trial.',
  'admin_game_trial_events': 'Recent events',
  'admin_game_trial_events_empty': 'No Game Trial events yet.',
  'admin_game_trial_hc_seats': 'Hardcore {occ}/{max} · queue {q}',
  'admin_game_trial_how_body':
      'Spawn real Supabase clients that join live Hardcore and other universes like phones: hunt, grow, sync radius, and fight real players.\n'
      '\n'
      'Use this to stress the live arena, queue, and economy without touching player accounts. Reset clears sim users and seats.',
  'admin_game_trial_how_title': 'Game Trial — live Hardcore stress',
  'admin_game_trial_in_arena': 'In arena now',
  'admin_game_trial_join_failed': 'Could not join the universe.',
  'admin_game_trial_join_hardcore': 'Join live Hardcore',
  'admin_game_trial_join_queued': 'Hardcore is full — you were queued instead of admitted.',
  'admin_game_trial_jump_hint':
      'Jump in yourself or open the lobby to watch sims fight alongside real players.',
  'admin_game_trial_jump_title': 'Jump in',
  'admin_game_trial_migration_hint':
      'Game Trial needs a database update. Run the Game Trial migrations in the Supabase SQL Editor.',
  'admin_game_trial_no_instances': 'No live room instances for this universe.',
  'admin_game_trial_queued': 'Queued sims',
  'admin_game_trial_rankings_empty': 'No sim rankings yet — add clients first.',
  'admin_game_trial_rankings_hint':
      'Live radius leaderboard for Game Trial sims in the arena.',
  'admin_game_trial_rankings_title': 'Sim rankings',
  'admin_game_trial_reset': 'Reset all',
  'admin_game_trial_reset_cancel': 'Cancel',
  'admin_game_trial_reset_confirm': 'Reset',
  'admin_game_trial_reset_confirm_body':
      'Stops all sim clients, deletes trial users, and clears Hardcore seats they occupied. Real player data is untouched.',
  'admin_game_trial_reset_confirm_title': 'Reset Game Trial?',
  'admin_game_trial_reset_failed': 'Could not reset Game Trial.',
  'admin_game_trial_reset_ok':
      'Reset complete — stopped {clients} client(s), deleted {deleted} user(s), cleared {left} seat(s).',
  'admin_game_trial_session_wins': 'Session wins',
  'admin_game_trial_spawn_label': 'Spawn sim clients',
  'admin_game_trial_start_failed': 'Could not start Game Trial sims.',
  'admin_game_trial_stop': 'Stop all',
  'admin_game_trial_stopped_ok': 'Stopped {count} Game Trial sim client(s).',
  'admin_game_trial_universes_hint':
      'Live room instances across universes — tap Join to enter as admin.',
  'admin_game_trial_universes_title': 'Live universes',
  'admin_hardcore_afk_countdown': 'Warning countdown (s)',
  'admin_hardcore_afk_drain': 'Mass drain per second',
  'admin_hardcore_afk_drain_late': 'Late mass drain per second',
  'admin_hardcore_afk_hint':
      'In-match idle protection for Hardcore — warning, then mass drain until kick mass.',
  'admin_hardcore_afk_idle': 'Idle before warning (s)',
  'admin_hardcore_afk_idle_late': 'Late idle before warning (s)',
  'admin_hardcore_afk_late_radius': 'Late rules start radius',
  'admin_hardcore_afk_save_note': 'Saved with Hardcore tuning — applies to live arena matches.',
  'admin_hardcore_afk_section': 'AFK / idle (Hardcore)',
  'admin_hardcore_arena_empty': 'No players in the arena right now.',
  'admin_hardcore_arena_hint':
      'Active vs passive arena, low-pop cap, food scaling, and PvP sim tuning for the live Hardcore universe.',
  'admin_hardcore_arena_min_alive': 'Min alive for active arena',
  'admin_hardcore_arena_players': 'Arena players ({n})',
  'admin_hardcore_arena_pvp': 'PvP sim aggression',
  'admin_hardcore_arena_save_note':
      'Arena rules save with this room\'s tuning and affect the next live Hardcore matches.',
  'admin_hardcore_arena_section': 'Arena rules',
  'admin_hardcore_arena_shield': 'Spawn protection (s)',
  'admin_hardcore_arena_sim_section': 'Sim behaviour',
  'admin_hardcore_arena_stable': 'Stable sim count target',
  'admin_hardcore_capacity_title': 'Seat capacity',
  'admin_hardcore_diamonds_lost_hour': 'Lost (last hour)',
  'admin_hardcore_diamonds_lost_today': 'Lost today',
  'admin_hardcore_diamonds_title': 'Diamond flow',
  'admin_hardcore_diamonds_won_hour': 'Won (last hour)',
  'admin_hardcore_diamonds_won_today': 'Won today',
  'admin_hardcore_economy_hint':
      'Victory diamonds, kill bonus, and elimination penalty for Hardcore — synced with Economy panel.',
  'admin_hardcore_economy_save_note': 'Economy sliders here mirror the global Economy settings.',
  'admin_hardcore_economy_section': 'Hardcore economy',
  'admin_hardcore_food_late_mult': 'Late food growth multiplier',
  'admin_hardcore_food_late_radius': 'Late food rules start radius',
  'admin_hardcore_food_pop_1': 'Food growth — 1 alive',
  'admin_hardcore_food_pop_2': 'Food growth — 2 alive',
  'admin_hardcore_food_pop_34': 'Food growth — 3–4 alive',
  'admin_hardcore_food_pop_5': 'Food growth — 5 alive',
  'admin_hardcore_food_pop_6': 'Food growth — 6+ alive',
  'admin_hardcore_live_hint':
      'Live Hardcore ops — seat fill, queue, diamond flow, and who is in the arena right now.',
  'admin_hardcore_live_section': 'Live Hardcore ops',
  'admin_hardcore_low_pop_cap': 'Low-pop radius cap',
  'admin_hardcore_meta_max': 'Max players cap: {n} (server enforced)',
  'admin_hardcore_metric_fill': 'Fill',
  'admin_hardcore_metric_leader': 'Leader radius',
  'admin_hardcore_metric_lost_hour': '♦ lost / hr',
  'admin_hardcore_metric_players': 'Seats',
  'admin_hardcore_metric_queue': 'Queue',
  'admin_hardcore_metric_raw_count': 'Real players',
  'admin_hardcore_metric_won_hour': '♦ won / hr',
  'admin_hardcore_penalty_elim': 'Elimination penalty',
  'admin_hardcore_player_admin': 'ADMIN',
  'admin_hardcore_queue_empty': 'Queue is empty.',
  'admin_hardcore_queue_title': 'Queue ({n})',
  'admin_hardcore_reward_kill': 'Kill bonus',
  'admin_hardcore_reward_victory': 'Victory reward',
  'admin_hardcore_rule_admin_seat': 'Admin seat',
  'admin_hardcore_rule_admin_seat_value': 'Reserved (does not block players)',
  'admin_hardcore_rule_bots': 'Bots',
  'admin_hardcore_rule_cooldown': 'Re-entry cooldown',
  'admin_hardcore_rule_players': 'Max players',
  'admin_hardcore_rule_points': 'Hardcore rank points',
  'admin_hardcore_rule_queue': 'Queue when full',
  'admin_hardcore_rule_queue_yes': 'Yes — auto-admit',
  'admin_hardcore_rule_start': 'Start radius',
  'admin_hardcore_rule_universe': 'Universe instances',
  'admin_hardcore_rule_universe_single': 'Single live arena',
  'admin_hardcore_rule_victory': 'Victory radius',
  'admin_hardcore_status_idle': 'IDLE',
  'admin_hardcore_status_live': 'LIVE',
  'admin_hardcore_tuning_section': 'Hardcore tuning',
  'admin_hc_test_active': '{n} active',
  'admin_hc_test_busy': 'Working…',
  'admin_hc_test_economy_badge': 'Real economy OFF',
  'admin_hc_test_empty_inside': 'No one in the test arena.',
  'admin_hc_test_empty_outside': 'No one waiting in queue.',
  'admin_hc_test_events': 'Test event log',
  'admin_hc_test_events_empty': 'No test events yet.',
  'admin_hc_test_fill_50': 'Fill 50',
  'admin_hc_test_force_eat': 'Force absorb',
  'admin_hc_test_gates': 'Live gates (read-only)',
  'admin_hc_test_gates_detail':
      'Victory {size} · active at {alive}+ alive · low-pop cap {cap} · spawn shield {spawn}s · late food from {late} ({lateMult}% growth)',
  'admin_hc_test_hint':
      'Isolated Hardcore test harness — sims use fake economy, real rules. Join to debug gates, queue, and PvP live.',
  'admin_hc_test_inside': 'In arena ({n})',
  'admin_hc_test_join': 'Join test arena',
  'admin_hc_test_join_failed': 'Could not join the test arena.',
  'admin_hc_test_joining': 'Joining…',
  'admin_hc_test_migration_hint':
      'Arena Test needs a database update. Run supabase/migration_hardcore_arena_test.sql in the Supabase SQL Editor.',
  'admin_hc_test_minus': '−1 sim',
  'admin_hc_test_outside': 'Queue ({n})',
  'admin_hc_test_plus': '+1 sim',
  'admin_hc_test_plus_10': '+10 sims',
  'admin_hc_test_predator': 'Predator',
  'admin_hc_test_prey': 'Prey',
  'admin_hc_test_queued': '{n} queued',
  'admin_hc_test_radius_600': 'Set 600',
  'admin_hc_test_seats': '{in}/{cap} seats',
  'admin_hc_test_section': 'Arena Test',
  'admin_hc_test_select_player': 'Select player',
  'admin_hc_test_set_radius': 'Set radius',
  'admin_hc_test_sim_badge': 'SIM',
  'admin_hc_test_sims': 'Test sims',
  'admin_hc_test_stop': 'Stop sims',
  'admin_player_radius': 'r {radius}',
  'admin_rank_points_hardcore': 'Hardcore universe',
  'admin_tools_roles_title': 'Admin tool roles',
  'admin_tune_hardcore_banner': 'Hardcore — players only, no bots',
  'admin_tune_hardcore_players_only': 'Players only (no bots)',
  'admin_tune_hardcore_rules_hint':
      'Fixed live rules summary plus editable arena, economy, and AFK tuning for Hardcore.',
  'admin_tune_max_players': 'Max players',
  'admin_tune_max_players_short': 'Max',
  'admin_tune_mode': 'Mode',
  'admin_tune_players_only': 'Players only',
  'admin_tune_supernova_shrink_max': 'Supernova shrink max',
  'admin_tune_supernova_shrink_min': 'Supernova shrink min',
  'admin_tune_tab_hardcore_rules': 'Hardcore rules',
  'admin_tune_world_size_short': 'World',
  'daily_chest_admin_again': 'Open again (admin)',
  'daily_chest_ad_failed': 'Ad failed — try again or open without doubling.',
  'daily_chest_ad_loading': 'Loading rewarded ad…',
  'daily_chest_ad_unavailable': 'Ads unavailable on this device.',
  'daily_chest_admin_skip_ad': 'Admin bypass — ad skipped.',
  'daily_chest_already': 'You already opened today\'s chest.',
  'daily_chest_body':
      'Open once per UTC day for a random diamond roll. Optional ad can double it.',
  'daily_chest_close': 'Close',
  'daily_chest_double_hint': 'Watch a short ad to double your roll.',
  'daily_chest_error': 'Could not load chest status. Try again.',
  'daily_chest_open_double': 'Open & double (ad)',
  'daily_chest_open_normal': 'Open chest',
  'daily_chest_opened': 'Chest opened — +{diamonds} ♦',
  'daily_chest_opened_doubled': 'Doubled — +{diamonds} ♦ total',
  'daily_chest_opening': 'Opening…',
  'daily_chest_title': 'Daily lobby chest',
  'daily_chest_tooltip_countdown': 'Next chest in {time}',
  'daily_chest_tooltip_done': 'Opened today',
  'daily_chest_tooltip_ready': 'Daily chest ready',
  'game_over_hardcore_diamond_lost': '−{diamonds} ♦ lost',
  'game_over_watch_hardcore': 'Watch arena',
  'global_rank_hardcore_points': 'Hardcore points',
  'global_rank_tab_hardcore': 'Hardcore',
  'hardcore_arena_active': 'Active arena',
  'hardcore_arena_active_tooltip':
      'Active arena: {minAlive}+ players alive — kills +{kill} ♦, eliminations −{elim} ♦, victory at {victory}.',
  'hardcore_arena_passive': 'Passive',
  'hardcore_arena_passive_tooltip':
      'Passive mode: fewer than {minAlive} alive — no kill diamonds, growth capped near {cap}, no victory claim.',
  'hardcore_arena_pop_short': '{alive}/{min} alive',
  'hardcore_gate_low_pop': 'Low pop',
  'hardcore_gate_low_pop_cap': 'Cap {cap}',
  'hardcore_gate_low_pop_cap_tooltip':
      'Low population — growth stops near {cap} until {minAlive}+ players are alive. Victory requires active arena.',
  'hardcore_lobby_cooldown': 'Re-entry in {time}',
  'hardcore_onboarding_cap_body':
      'While fewer than {minAlive} players are alive, growth stops near {cap} until more join.',
  'hardcore_onboarding_cap_title': 'Low-pop size cap',
  'hardcore_onboarding_header': 'Hardcore Arena',
  'hardcore_onboarding_modes_body':
      'With {minAlive}+ players alive the arena is active: kill +{kill} ♦, elim −{elim} ♦, reach {victory} to win. Below that, passive mode applies.',
  'hardcore_onboarding_modes_title': 'Active vs passive',
  'hardcore_onboarding_step_label': 'Step {n} of {total}',
  'hardcore_onboarding_victory_body':
      'Reach radius {victory} to win. Active arena only — passive mode cannot claim victory at cap.',
  'hardcore_onboarding_victory_title': 'Victory at {victory}',
  'hardcore_queue_body':
      'Hardcore is full. You will enter automatically when a seat frees — stay on this screen.',
  'hardcore_queue_cancel': 'Leave queue',
  'hardcore_queue_position': 'Position #{n}',
  'hardcore_queue_title': 'Hardcore queue',
  'hardcore_queue_waiting': 'Waiting for a seat…',
  'hardcore_rules_sheet_close': 'Got it',
  'how_to_play_hardcore_desc':
      'Unlock with {trophies} universe trophies from Normal, Elite, and Unique wins. Players-only arena — no bots. Active at {minAlive}+ alive: victory radius {victory}, kill +{kill} ♦, elim −{elim} ♦, win +{winDiamonds} ♦. Passive below {minAlive}: growth caps near {cap}. Hardcore rank +{rank} on victory. Cooldown after win or elimination.',
  'how_to_play_shield_ability_desc':
      'Tap Shield when ready — {duration}s of gravity protection. Cooldown {cd}s (Skill Tree can improve both).',
  'how_to_play_shield_teleport_desc':
      'Tap Teleport to jump to a safe spot with a brief {duration}s arrival shield. Cooldown {cd}s.',
  'live_announce_hardcore_win': '{name} conquered Hardcore!',
  'lobby_menu_more': 'More',
  'lobby_next_goal_diamonds': '{count} more ♦ to unlock {room}',
  'lobby_next_goal_training': 'Complete {room} to unlock other universes',
  'lobby_next_goal_trophies': '{remaining} more trophies to unlock {room}',
  'lobby_online_label': 'online',
  'lobby_online_tooltip': 'Players signed in across the lobby right now',
  'lobby_tab_play': 'Play',
  'lobby_tab_social': 'Social',
  'lobby_trophies_progress': '{lit} of {slots} universe trophies',
  'lobby_version_notes': 'v2.3',
  'match_day_diamond_progress': 'Today {earned} / {cap}',
  'match_day_diamond_tooltip':
      'Match diamonds earned today toward your daily cap. Resets at UTC midnight.',
  'profile_hardcore_locked': 'Earn universe trophies to unlock Hardcore',
  'profile_hardcore_points': 'Hardcore points',
  'profile_hardcore_unlocked': 'Hardcore unlocked',
  'profile_trophies_dialog_intro':
      'Win 1st place in Normal, Elite, or Unique to earn universe trophies. Collect 10 to enter Hardcore.',
  'profile_trophies_dialog_title': 'Universe trophies',
  'profile_trophies_hardcore_body':
      'Hardcore opens at 10 universe trophies — one cup per competitive 1st place in Normal, Elite, or Unique.',
  'profile_trophies_total': 'Total trophies',
  'profile_universe_trophies': 'Universe trophies',
  'profile_universe_trophies_tooltip':
      '{earned} / {cap} universe trophies — unlock Hardcore at {cap}',
  'profile_username_reserved': 'That username is reserved.',
  'room_hardcore_desc':
      'Live players-only arena. Real PvP, Hardcore points on victory, fire-themed void. Queue when full.',
  'room_hardcore_lock': '{earned} / {cap} trophies — earn more to enter',
  'room_hardcore_presence': '{players}/{cap} in arena',
  'room_hardcore_title': 'Hardcore',
  'settings_low_performance': 'Low performance mode',
  'settings_low_performance_desc':
      'Reduces visual effects and shader work for smoother play on weaker devices.',
  'settings_performance_section': 'Performance',
  'settings_show_other_sizes': 'Show other players\' sizes',
  'settings_show_other_sizes_desc':
      'Display radius labels on other black holes during a match.',
  'settings_show_own_size': 'Show my size',
  'settings_show_own_size_desc': 'Display your radius label during a match.',
  'v23_change_lobby_redesign':
      'Compact cosmic lobby — Play and Social tabs, streamlined header with diamonds, daily progress, chest, and inbox at a glance.',
  'v23_change_universe_cards':
      'Tier-scaled universe cards — Training dock, Normal/Elite sector tiles, Unique anomaly banner, and Hardcore singularity event row.',
  'v23_change_nasa_photos':
      'NASA deep-space photography on every universe card with tuned darkness so art and text stay readable together.',
  'v23_change_unique_photo':
      'Unique universe artwork refreshed — Tycho supernova remnant replaces the bright lunar surface.',
  'v23_change_title_polish':
      'Normal and Elite titles now share matching size, weight, and gradient styling side by side.',
  'v23_change_wormhole_blend':
      'Wormhole gates blend into banner cards with softer glow — no visible seam on Unique or Training rows.',
  'v23_change_next_goal':
      'Lobby progress hints show your next trophy or diamond goal toward unlocking universes.',
  'v23_change_version_notes':
      'What\'s New refreshed for v2.3 — cosmic lobby polish at the top. Shows once in the lobby until you dismiss it.',
  'v23_section_subtitle':
      'Cosmic lobby redesign, NASA universe photography, balanced card readability, and smoother wormhole blending.',
  'v23_section_title': 'Version 2.3',
  'v22_change_daily_chest':
      'Daily lobby chest — open once per UTC day for diamonds; optional rewarded ad can double the roll.',
  'v22_change_hardcore':
      'Hardcore is live — a players-only arena (no bots) with real PvP, Hardcore points on victory, and a fire-themed void.',
  'v22_change_hc_queue':
      'When Hardcore is full, you join a live queue with your position and enter automatically when a seat frees.',
  'v22_change_hc_rules':
      'Hardcore rules: large victory size with fair-play gates, kill diamonds, elimination losses, and a cooldown after win or elimination.',
  'v22_change_hc_visuals':
      'Hardcore visuals upgraded — molten nebulas, ember stars, and a scorched void that reads as a different universe.',
  'v22_change_security':
      'Safer logins and rewards — tighter OAuth redirects, hardened match claims, and stronger server checks against abuse.',
  'v22_change_stability':
      'Seats and sessions are more reliable — ghost seats clear faster, heartbeats keep you counted, and empty rooms clean up better.',
  'v22_change_trophies':
      'Universe trophies unlock Hardcore — earn cups from Normal, Elite, and Unique wins to reach the 10-trophy gate.',
  'v22_change_version_notes':
      'What\'s New refreshed for v2.2 — Hardcore, trophies, daily chest, and stability at the top. Shows once in the lobby until you dismiss it.',
  'v22_change_wormhole':
      'Wormhole travel into matches — a stronger dive into Hardcore so entering the arena feels like a real jump.',
  'v22_section_subtitle':
      'Live Hardcore arena, universe trophies, daily lobby chest, wormhole travel, tougher PvP rules, and more stable sessions.',
  'v22_section_title': 'Version 2.2',
  'victory_first_trophy_desc':
      'You earned your first universe trophy ({earned} / {total}). Keep winning in competitive universes.',
  'victory_first_trophy_normal_unlock':
      'Normal universe is now unlocked — keep collecting trophies toward Hardcore.',
  'victory_first_trophy_title': 'First universe trophy!',
};

const _trTranslations = <String, String>{
  'admin_economy_ad_doubles': 'Günlük ödüllü reklam ile ikiye katlama',
  'admin_economy_chest_high': 'Sandık çekilişi — yüksek kademe',
  'admin_economy_chest_low': 'Sandık çekilişi — düşük kademe',
  'admin_economy_chest_mid': 'Sandık çekilişi — orta kademe',
  'admin_economy_chest_section': 'Günlük lobi sandığı',
  'admin_economy_daily_cap': 'Günlük maç elmas üst sınırı',
  'admin_economy_hardcore_hint':
      'Hardcore zafer ve öldürme ödülleri ile elenme cezası burada ve Hardcore ayarlarında düzenlenir.',
  'admin_economy_hardcore_section': 'Hardcore ekonomisi',
  'admin_economy_intro':
      'Podyum ödülleri, yutulma cezaları, evren açılış eşikleri, günlük lobi sandığı kademeleri ve günlük claim limitleri.',
  'admin_economy_limits_section': 'Günlük limitler',
  'admin_economy_penalty_section': 'Elenme cezaları',
  'admin_economy_place_1': '1. sıra',
  'admin_economy_place_2': '2. sıra',
  'admin_economy_place_3': '3. sıra',
  'admin_economy_reset': 'Varsayılana sıfırla',
  'admin_economy_reward_claims': 'Günlük ödül claim sayısı',
  'admin_economy_rewards_hint':
      'Her evrende 1. / 2. / 3. için elmas ödülleri. Eğitim varsayılanları kasıtlı olarak düşüktür.',
  'admin_economy_rewards_section': 'Maç ödülleri',
  'admin_economy_save': 'Kaydet',
  'admin_economy_start_note':
      'Kayıttan sonra sunucuda uygulanır. Mevcut maç claim\'leri geriye dönük değişmez.',
  'admin_economy_training_claims': 'Günlük eğitim claim sayısı',
  'admin_economy_unlock_section': 'Evren açılış eşikleri',
  'admin_game_trial_active': 'Aktif sim istemcileri',
  'admin_game_trial_added_ok':
      '{count} sim eklendi. Game Trial\'da şu an {active} aktif.',
  'admin_game_trial_events': 'Son olaylar',
  'admin_game_trial_events_empty': 'Henüz Game Trial olayı yok.',
  'admin_game_trial_hc_seats': 'Hardcore {occ}/{max} · kuyruk {q}',
  'admin_game_trial_how_body':
      'Canlı Hardcore ve diğer evrenlere telefon gibi katılan gerçek Supabase istemcileri oluşturun: avlan, büyü, yarıçap senkronize et, gerçek oyuncularla savaş.\n'
      '\n'
      'Canlı arena, kuyruk ve ekonomiyi oyuncu hesaplarına dokunmadan test edin. Sıfırlama sim kullanıcılarını ve koltukları temizler.',
  'admin_game_trial_how_title': 'Game Trial — canlı Hardcore stres testi',
  'admin_game_trial_in_arena': 'Şu an arenada',
  'admin_game_trial_join_failed': 'Evrene katılınamadı.',
  'admin_game_trial_join_hardcore': 'Canlı Hardcore\'a katıl',
  'admin_game_trial_join_queued':
      'Hardcore dolu — kabul yerine kuyruğa alındınız.',
  'admin_game_trial_jump_hint':
      'Kendiniz girin veya simlerin gerçek oyuncularla savaşını izlemek için lobiyi açın.',
  'admin_game_trial_jump_title': 'Hemen gir',
  'admin_game_trial_migration_hint':
      'Game Trial veritabanı güncellemesi gerektiriyor. Supabase SQL Editor\'da Game Trial migration\'larını çalıştırın.',
  'admin_game_trial_no_instances': 'Bu evren için canlı oda örneği yok.',
  'admin_game_trial_queued': 'Kuyruktaki simler',
  'admin_game_trial_rankings_empty':
      'Henüz sim sıralaması yok — önce istemci ekleyin.',
  'admin_game_trial_rankings_hint':
      'Arenadaki Game Trial simleri için canlı yarıçap sıralaması.',
  'admin_game_trial_rankings_title': 'Sim sıralaması',
  'admin_game_trial_reset': 'Tümünü sıfırla',
  'admin_game_trial_reset_cancel': 'İptal',
  'admin_game_trial_reset_confirm': 'Sıfırla',
  'admin_game_trial_reset_confirm_body':
      'Tüm sim istemcilerini durdurur, deneme kullanıcılarını siler ve işgal ettikleri Hardcore koltuklarını temizler. Gerçek oyuncu verisi etkilenmez.',
  'admin_game_trial_reset_confirm_title': 'Game Trial sıfırlansın mı?',
  'admin_game_trial_reset_failed': 'Game Trial sıfırlanamadı.',
  'admin_game_trial_reset_ok':
      'Sıfırlama tamam — {clients} istemci durduruldu, {deleted} kullanıcı silindi, {left} koltuk temizlendi.',
  'admin_game_trial_session_wins': 'Oturum galibiyetleri',
  'admin_game_trial_spawn_label': 'Sim istemci oluştur',
  'admin_game_trial_start_failed': 'Game Trial simleri başlatılamadı.',
  'admin_game_trial_stop': 'Tümünü durdur',
  'admin_game_trial_stopped_ok': '{count} Game Trial sim istemcisi durduruldu.',
  'admin_game_trial_universes_hint':
      'Evrenlerdeki canlı oda örnekleri — yönetici olarak girmek için Katıl\'a dokunun.',
  'admin_game_trial_universes_title': 'Canlı evrenler',
  'admin_hardcore_afk_countdown': 'Uyarı geri sayımı (sn)',
  'admin_hardcore_afk_drain': 'Saniyede kütle kaybı',
  'admin_hardcore_afk_drain_late': 'Geç dönem saniyede kütle kaybı',
  'admin_hardcore_afk_hint':
      'Hardcore maç içi boşta kalma koruması — uyarı, ardından atılma kütlesine kadar kütle kaybı.',
  'admin_hardcore_afk_idle': 'Uyarıdan önce boşta kalma (sn)',
  'admin_hardcore_afk_idle_late': 'Geç dönem uyarıdan önce boşta kalma (sn)',
  'admin_hardcore_afk_late_radius': 'Geç kurallar başlangıç yarıçapı',
  'admin_hardcore_afk_save_note':
      'Hardcore ayarlarıyla kaydedilir — canlı arena maçlarına uygulanır.',
  'admin_hardcore_afk_section': 'AFK / boşta kalma (Hardcore)',
  'admin_hardcore_arena_empty': 'Şu an arenada oyuncu yok.',
  'admin_hardcore_arena_hint':
      'Aktif ve pasif arena, düşük nüfus tavanı, yiyecek ölçekleme ve canlı Hardcore evreni için PvP sim ayarları.',
  'admin_hardcore_arena_min_alive': 'Aktif arena için min hayatta',
  'admin_hardcore_arena_players': 'Arena oyuncuları ({n})',
  'admin_hardcore_arena_pvp': 'PvP sim saldırganlığı',
  'admin_hardcore_arena_save_note':
      'Arena kuralları bu odanın ayarlarıyla kaydedilir ve sonraki canlı Hardcore maçlarını etkiler.',
  'admin_hardcore_arena_section': 'Arena kuralları',
  'admin_hardcore_arena_shield': 'Doğuş koruması (sn)',
  'admin_hardcore_arena_sim_section': 'Sim davranışı',
  'admin_hardcore_arena_stable': 'Hedef stabil sim sayısı',
  'admin_hardcore_capacity_title': 'Koltuk kapasitesi',
  'admin_hardcore_diamonds_lost_hour': 'Kaybedilen (son saat)',
  'admin_hardcore_diamonds_lost_today': 'Bugün kaybedilen',
  'admin_hardcore_diamonds_title': 'Elmas akışı',
  'admin_hardcore_diamonds_won_hour': 'Kazanılan (son saat)',
  'admin_hardcore_diamonds_won_today': 'Bugün kazanılan',
  'admin_hardcore_economy_hint':
      'Hardcore zafer elmasları, öldürme bonusu ve elenme cezası — Ekonomi paneliyle senkron.',
  'admin_hardcore_economy_save_note':
      'Buradaki ekonomi kaydırıcıları genel Ekonomi ayarlarını yansıtır.',
  'admin_hardcore_economy_section': 'Hardcore ekonomisi',
  'admin_hardcore_food_late_mult': 'Geç dönem yiyecek büyüme çarpanı',
  'admin_hardcore_food_late_radius': 'Geç yiyecek kuralları başlangıç yarıçapı',
  'admin_hardcore_food_pop_1': 'Yiyecek büyümesi — 1 hayatta',
  'admin_hardcore_food_pop_2': 'Yiyecek büyümesi — 2 hayatta',
  'admin_hardcore_food_pop_34': 'Yiyecek büyümesi — 3–4 hayatta',
  'admin_hardcore_food_pop_5': 'Yiyecek büyümesi — 5 hayatta',
  'admin_hardcore_food_pop_6': 'Yiyecek büyümesi — 6+ hayatta',
  'admin_hardcore_live_hint':
      'Canlı Hardcore operasyonları — koltuk doluluğu, kuyruk, elmas akışı ve şu an arenada kim var.',
  'admin_hardcore_live_section': 'Canlı Hardcore operasyonları',
  'admin_hardcore_low_pop_cap': 'Düşük nüfus yarıçap tavanı',
  'admin_hardcore_meta_max': 'Maks oyuncu sınırı: {n} (sunucu zorunlu)',
  'admin_hardcore_metric_fill': 'Doluluk',
  'admin_hardcore_metric_leader': 'Lider yarıçapı',
  'admin_hardcore_metric_lost_hour': '♦ kayıp / saat',
  'admin_hardcore_metric_players': 'Koltuklar',
  'admin_hardcore_metric_queue': 'Kuyruk',
  'admin_hardcore_metric_raw_count': 'Gerçek oyuncular',
  'admin_hardcore_metric_won_hour': '♦ kazanç / saat',
  'admin_hardcore_penalty_elim': 'Elenme cezası',
  'admin_hardcore_player_admin': 'YÖNETİCİ',
  'admin_hardcore_queue_empty': 'Kuyruk boş.',
  'admin_hardcore_queue_title': 'Kuyruk ({n})',
  'admin_hardcore_reward_kill': 'Öldürme bonusu',
  'admin_hardcore_reward_victory': 'Zafer ödülü',
  'admin_hardcore_rule_admin_seat': 'Yönetici koltuğu',
  'admin_hardcore_rule_admin_seat_value': 'Ayrılmış (oyuncuları engellemez)',
  'admin_hardcore_rule_bots': 'Botlar',
  'admin_hardcore_rule_cooldown': 'Yeniden giriş bekleme süresi',
  'admin_hardcore_rule_players': 'Maks oyuncu',
  'admin_hardcore_rule_points': 'Hardcore rütbe puanı',
  'admin_hardcore_rule_queue': 'Dolu olunca kuyruk',
  'admin_hardcore_rule_queue_yes': 'Evet — otomatik kabul',
  'admin_hardcore_rule_start': 'Başlangıç yarıçapı',
  'admin_hardcore_rule_universe': 'Evren örnekleri',
  'admin_hardcore_rule_universe_single': 'Tek canlı arena',
  'admin_hardcore_rule_victory': 'Zafer yarıçapı',
  'admin_hardcore_status_idle': 'BEKLEMEDE',
  'admin_hardcore_status_live': 'CANLI',
  'admin_hardcore_tuning_section': 'Hardcore ayarları',
  'admin_hc_test_active': '{n} aktif',
  'admin_hc_test_busy': 'Çalışıyor…',
  'admin_hc_test_economy_badge': 'Gerçek ekonomi KAPALI',
  'admin_hc_test_empty_inside': 'Test arenasında kimse yok.',
  'admin_hc_test_empty_outside': 'Kuyrukta bekleyen yok.',
  'admin_hc_test_events': 'Test olay günlüğü',
  'admin_hc_test_events_empty': 'Henüz test olayı yok.',
  'admin_hc_test_fill_50': '50 doldur',
  'admin_hc_test_force_eat': 'Zorla yut',
  'admin_hc_test_gates': 'Canlı kapılar (salt okunur)',
  'admin_hc_test_gates_detail':
      'Zafer {size} · {alive}+ hayatta aktif · düşük nüfus tavanı {cap} · doğuş kalkanı {spawn} sn · geç yiyecek {late}\'den ({lateMult}% büyüme)',
  'admin_hc_test_hint':
      'İzole Hardcore test ortamı — simler sahte ekonomi, gerçek kurallar kullanır. Kapıları, kuyruğu ve PvP\'yi canlı debug etmek için katılın.',
  'admin_hc_test_inside': 'Arenada ({n})',
  'admin_hc_test_join': 'Test arenasına katıl',
  'admin_hc_test_join_failed': 'Test arenasına katılınamadı.',
  'admin_hc_test_joining': 'Katılınıyor…',
  'admin_hc_test_migration_hint':
      'Arena Test veritabanı güncellemesi gerektiriyor. Supabase SQL Editor\'da supabase/migration_hardcore_arena_test.sql dosyasını çalıştırın.',
  'admin_hc_test_minus': '−1 sim',
  'admin_hc_test_outside': 'Kuyruk ({n})',
  'admin_hc_test_plus': '+1 sim',
  'admin_hc_test_plus_10': '+10 sim',
  'admin_hc_test_predator': 'Avcı',
  'admin_hc_test_prey': 'Av',
  'admin_hc_test_queued': '{n} kuyrukta',
  'admin_hc_test_radius_600': '600 yap',
  'admin_hc_test_seats': '{in}/{cap} koltuk',
  'admin_hc_test_section': 'Arena Test',
  'admin_hc_test_select_player': 'Oyuncu seç',
  'admin_hc_test_set_radius': 'Yarıçap ayarla',
  'admin_hc_test_sim_badge': 'SIM',
  'admin_hc_test_sims': 'Test simleri',
  'admin_hc_test_stop': 'Simleri durdur',
  'admin_player_radius': 'r {radius}',
  'admin_rank_points_hardcore': 'Hardcore evreni',
  'admin_tools_roles_title': 'Yönetici araç rolleri',
  'admin_tune_hardcore_banner': 'Hardcore — yalnızca oyuncu, bot yok',
  'admin_tune_hardcore_players_only': 'Yalnızca oyuncu (bot yok)',
  'admin_tune_hardcore_rules_hint':
      'Sabit canlı kural özeti ve Hardcore için düzenlenebilir arena, ekonomi ve AFK ayarları.',
  'admin_tune_max_players': 'Maks oyuncu',
  'admin_tune_max_players_short': 'Maks',
  'admin_tune_mode': 'Mod',
  'admin_tune_players_only': 'Yalnızca oyuncu',
  'admin_tune_supernova_shrink_max': 'Süpernova küçülme max',
  'admin_tune_supernova_shrink_min': 'Süpernova küçülme min',
  'admin_tune_tab_hardcore_rules': 'Hardcore kuralları',
  'admin_tune_world_size_short': 'Dünya',
  'daily_chest_admin_again': 'Tekrar aç (yönetici)',
  'daily_chest_ad_failed':
      'Reklam başarısız — tekrar deneyin veya ikiye katlamadan açın.',
  'daily_chest_ad_loading': 'Ödüllü reklam yükleniyor…',
  'daily_chest_ad_unavailable': 'Bu cihazda reklamlar kullanılamıyor.',
  'daily_chest_admin_skip_ad': 'Yönetici bypass — reklam atlandı.',
  'daily_chest_already': 'Bugünkü sandığı zaten açtınız.',
  'daily_chest_body':
      'UTC gününde bir kez rastgele elmas çekilişi. İsteğe bağlı reklam ikiye katlayabilir.',
  'daily_chest_close': 'Kapat',
  'daily_chest_double_hint': 'Çekilişi ikiye katlamak için kısa bir reklam izleyin.',
  'daily_chest_error': 'Sandık durumu yüklenemedi. Tekrar deneyin.',
  'daily_chest_open_double': 'Aç ve ikiye katla (reklam)',
  'daily_chest_open_normal': 'Sandığı aç',
  'daily_chest_opened': 'Sandık açıldı — +{diamonds} ♦',
  'daily_chest_opened_doubled': 'İkiye katlandı — toplam +{diamonds} ♦',
  'daily_chest_opening': 'Açılıyor…',
  'daily_chest_title': 'Günlük lobi sandığı',
  'daily_chest_tooltip_countdown': 'Sonraki sandık {time} içinde',
  'daily_chest_tooltip_done': 'Bugün açıldı',
  'daily_chest_tooltip_ready': 'Günlük sandık hazır',
  'game_over_hardcore_diamond_lost': '−{diamonds} ♦ kaybedildi',
  'game_over_watch_hardcore': 'Arenayı izle',
  'global_rank_hardcore_points': 'Hardcore puanı',
  'global_rank_tab_hardcore': 'Hardcore',
  'hardcore_arena_active': 'Aktif arena',
  'hardcore_arena_active_tooltip':
      'Aktif arena: {minAlive}+ oyuncu hayatta — öldürme +{kill} ♦, elenme −{elim} ♦, zafer {victory}.',
  'hardcore_arena_passive': 'Pasif',
  'hardcore_arena_passive_tooltip':
      'Pasif mod: {minAlive}\'den az hayatta — öldürme elması yok, büyüme {cap} civarında sınırlı, zafer yok.',
  'hardcore_arena_pop_short': '{alive}/{min} hayatta',
  'hardcore_gate_low_pop': 'Düşük nüfus',
  'hardcore_gate_low_pop_cap': 'Tavan {cap}',
  'hardcore_gate_low_pop_cap_tooltip':
      'Düşük nüfus — {minAlive}+ oyuncu hayatta olana kadar büyüme {cap} civarında durur. Zafer aktif arena gerektirir.',
  'hardcore_lobby_cooldown': 'Yeniden giriş {time} içinde',
  'hardcore_onboarding_cap_body':
      '{minAlive}\'den az oyuncu hayatta olduğu sürece büyüme {cap} civarında durur; daha fazlası katılana kadar.',
  'hardcore_onboarding_cap_title': 'Düşük nüfus boyut tavanı',
  'hardcore_onboarding_header': 'Hardcore Arenası',
  'hardcore_onboarding_modes_body':
      '{minAlive}+ oyuncu hayattayken arena aktiftir: öldürme +{kill} ♦, elenme −{elim} ♦, zafer için {victory}\'e ulaşın. Altında pasif mod geçerli.',
  'hardcore_onboarding_modes_title': 'Aktif ve pasif',
  'hardcore_onboarding_step_label': 'Adım {n} / {total}',
  'hardcore_onboarding_victory_body':
      'Zafer için yarıçap {victory}. Yalnızca aktif arenada — pasif modda tavanda zafer alınamaz.',
  'hardcore_onboarding_victory_title': '{victory}\'de zafer',
  'hardcore_queue_body':
      'Hardcore dolu. Koltuk boşalınca otomatik gireceksiniz — bu ekranda kalın.',
  'hardcore_queue_cancel': 'Kuyruktan çık',
  'hardcore_queue_position': 'Sıra #{n}',
  'hardcore_queue_title': 'Hardcore kuyruğu',
  'hardcore_queue_waiting': 'Koltuk bekleniyor…',
  'hardcore_rules_sheet_close': 'Anladım',
  'how_to_play_hardcore_desc':
      'Normal, Elite ve Unique galibiyetlerinden {trophies} evren kupasıyla açılır. Yalnızca oyuncu arenası — bot yok. {minAlive}+ hayatta aktif: zafer yarıçapı {victory}, öldürme +{kill} ♦, elenme −{elim} ♦, galibiyet +{winDiamonds} ♦. {minAlive} altında pasif: büyüme {cap} civarında sınırlı. Zaferde Hardcore rütbe +{rank}. Galibiyet veya elenmeden sonra bekleme süresi.',
  'how_to_play_shield_ability_desc':
      'Hazır olunca Kalkan\'a basın — {duration} sn yerçekimi koruması. Bekleme {cd} sn (Yetenek Ağacı iyileştirebilir).',
  'how_to_play_shield_teleport_desc':
      'Güvenli bir noktaya zıplamak için Işınlan\'a basın; kısa {duration} sn varış kalkanı. Bekleme {cd} sn.',
  'live_announce_hardcore_win': '{name} Hardcore\'u fethetti!',
  'lobby_menu_more': 'Daha fazla',
  'lobby_next_goal_diamonds': '{room} açmak için {count} ♦ daha',
  'lobby_next_goal_training': 'Diğer evrenleri açmak için {room} tamamlayın',
  'lobby_next_goal_trophies': '{room} açmak için {remaining} kupa daha',
  'lobby_online_label': 'çevrimiçi',
  'lobby_online_tooltip': 'Şu an lobide oturum açmış oyuncu sayısı',
  'lobby_tab_play': 'Oyna',
  'lobby_tab_social': 'Sosyal',
  'lobby_trophies_progress': '{lit} / {slots} evren kupası',
  'lobby_version_notes': 'v2.3',
  'match_day_diamond_progress': 'Bugün {earned} / {cap}',
  'match_day_diamond_tooltip':
      'Günlük üst sınıra doğru bugün kazanılan maç elmasları. UTC gece yarısında sıfırlanır.',
  'profile_hardcore_locked': 'Hardcore\'u açmak için evren kupaları kazanın',
  'profile_hardcore_points': 'Hardcore puanı',
  'profile_hardcore_unlocked': 'Hardcore açık',
  'profile_trophies_dialog_intro':
      'Normal, Elite veya Unique\'de 1. olunca evren kupası kazanın. Hardcore için 10 toplayın.',
  'profile_trophies_dialog_title': 'Evren kupaları',
  'profile_trophies_hardcore_body':
      'Hardcore 10 evren kupasında açılır — Normal, Elite veya Unique\'de rekabetçi her 1.lik bir kupa.',
  'profile_trophies_total': 'Toplam kupa',
  'profile_universe_trophies': 'Evren kupaları',
  'profile_universe_trophies_tooltip':
      '{earned} / {cap} evren kupası — {cap}\'te Hardcore açılır',
  'profile_username_reserved': 'Bu kullanıcı adı ayrılmış.',
  'room_hardcore_desc':
      'Canlı, yalnızca oyunculu arena. Gerçek PvP, zaferde Hardcore puanı, ateş temalı boşluk. Dolu olunca kuyruk.',
  'room_hardcore_lock': '{earned} / {cap} kupa — girmek için daha fazla kazanın',
  'room_hardcore_presence': 'Arenada {players}/{cap}',
  'room_hardcore_title': 'Hardcore',
  'settings_low_performance': 'Düşük performans modu',
  'settings_low_performance_desc':
      'Zayıf cihazlarda daha akıcı oyun için görsel efektleri ve shader yükünü azaltır.',
  'settings_performance_section': 'Performans',
  'settings_show_other_sizes': 'Diğer oyuncuların boyutlarını göster',
  'settings_show_other_sizes_desc':
      'Maç sırasında diğer kara deliklerin yarıçap etiketlerini göster.',
  'settings_show_own_size': 'Boyutumu göster',
  'settings_show_own_size_desc': 'Maç sırasında kendi yarıçap etiketinizi gösterin.',
  'v23_change_lobby_redesign':
      'Kompakt kozmik lobi — Oyna ve Sosyal sekmeleri; elmas, günlük ilerleme, sandık ve gelen kutusu tek bakışta.',
  'v23_change_universe_cards':
      'Kademeli evren kartları — Eğitim dock, Normal/Elit sektör karoları, Eşsiz anomali bandı ve Hardcore singularity satırı.',
  'v23_change_nasa_photos':
      'Her evren kartında NASA derin uzay fotoğrafları — metin okunaklı kalacak şekilde dengeli karartma.',
  'v23_change_unique_photo':
      'Eşsiz evren görseli yenilendi — parlak ay yüzeyi yerine Tycho süpernova kalıntısı.',
  'v23_change_title_polish':
      'Normal ve Elit başlıkları yan yana aynı boyut, ağırlık ve gradient stiline kavuştu.',
  'v23_change_wormhole_blend':
      'Solucan kapıları banner kartlara yumuşak glow ile karışıyor — Eşsiz ve Eğitim satırlarında görünür çizgi yok.',
  'v23_change_next_goal':
      'Lobi ilerleme ipuçları bir sonraki kupa veya elmas hedefinizi gösterir — evren kilidini açmaya doğru.',
  'v23_change_version_notes':
      'Yenilikler v2.3 için güncellendi — kozmik lobi cilası üstte. Lobide bir kez gösterilir; kapatana kadar.',
  'v23_section_subtitle':
      'Kozmik lobi yenilemesi, NASA evren fotoğrafları, dengeli kart okunabilirliği ve daha yumuşak solucan geçişleri.',
  'v23_section_title': 'Sürüm 2.3',
  'v22_change_daily_chest':
      'Günlük lobi sandığı — UTC gününde bir kez elmas için açın; isteğe bağlı ödüllü reklam çekilişi ikiye katlayabilir.',
  'v22_change_hardcore':
      'Hardcore canlı — bot yok, yalnızca oyunculu arena; gerçek PvP, zaferde Hardcore puanı ve ateş temalı boşluk.',
  'v22_change_hc_queue':
      'Hardcore dolu olunca canlı kuyruğa girersiniz; sıranız gösterilir ve koltuk boşalınca otomatik girersiniz.',
  'v22_change_hc_rules':
      'Hardcore kuralları: büyük zafer boyutu ve adil oyun kapıları, öldürme elmasları, elenme kayıpları; galibiyet veya elenmeden sonra bekleme süresi.',
  'v22_change_hc_visuals':
      'Hardcore görselleri yenilendi — erimiş nebulalar, kor yıldızlar ve farklı bir evren hissi veren kavrulmuş boşluk.',
  'v22_change_security':
      'Daha güvenli girişler ve ödüller — sıkı OAuth yönlendirmeleri, güçlendirilmiş maç claim\'leri ve kötüye kullanıma karşı daha sağlam sunucu kontrolleri.',
  'v22_change_stability':
      'Koltuklar ve oturumlar daha güvenilir — hayalet koltuklar daha hızlı temizlenir, heartbeat sizi sayımda tutar, boş odalar daha iyi kapanır.',
  'v22_change_trophies':
      'Evren kupaları Hardcore\'u açar — Normal, Elite ve Unique galibiyetlerinden kupa kazanarak 10 kupa kapısına ulaşın.',
  'v22_change_version_notes':
      'Yenilikler v2.2 için güncellendi — Hardcore, kupalar, günlük sandık ve stabilite üstte. Lobide bir kez gösterilir; kapatana kadar.',
  'v22_change_wormhole':
      'Maçlara wormhole geçişi — Hardcore\'a daha güçlü bir dalış; arenaya girmek gerçek bir sıçrama gibi hissedilir.',
  'v22_section_subtitle':
      'Canlı Hardcore arenası, evren kupaları, günlük lobi sandığı, wormhole geçişi, daha sert PvP kuralları ve daha stabil oturumlar.',
  'v22_section_title': 'Sürüm 2.2',
  'victory_first_trophy_desc':
      'İlk evren kupanızı kazandınız ({earned} / {total}). Rekabetçi evrenlerde kazanmaya devam edin.',
  'victory_first_trophy_normal_unlock':
      'Normal evren artık açık — Hardcore\'a doğru kupa toplamaya devam edin.',
  'victory_first_trophy_title': 'İlk evren kupası!',
};
