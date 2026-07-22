import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desteklenen diller ve yerelleştirilmiş metin haritası.
class LanguageService extends ChangeNotifier {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  static const String _prefKey = 'quasar_language';
  static const String defaultLanguage = 'en';

  static const List<String> supportedLanguages = [
    'en',
    'tr',
    'de',
    'ru',
    'es',
    'fr',
  ];

  static const Map<String, String> languageLabels = {
    'en': 'English',
    'tr': 'Türkçe',
    'de': 'Deutsch',
    'ru': 'Русский',
    'es': 'Español',
    'fr': 'Français',
  };

  String _currentLanguage = defaultLanguage;
  String get currentLanguage => _currentLanguage;
  bool _initialized = false;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'Quasar.io',
      'sign_in_google': 'Sign in with Google',
      'signing_in': 'Signing in...',
      'sign_out': 'Sign Out',
      'admin_badge': 'OWNER',
      'admin_title': 'Admin Control',
      'admin_subtitle': 'Live universe, player and bot overview',
      'admin_nav_live': 'Live',
      'admin_nav_analytics': 'Statistics',
      'admin_nav_universes': 'Universes',
      'admin_nav_idle': 'AFK / Idle',
      'admin_nav_ranks': 'Ranks',
      'admin_nav_players': 'Players',
      'admin_nav_load_test': 'Load test',
      'admin_nav_messages': 'Messages',
      'admin_page_live_title': 'Live overview',
      'admin_page_live_desc': 'Who is online right now — players, bots and universes.',
      'admin_page_analytics_title': 'Statistics',
      'admin_page_analytics_desc':
          'Historical trends to tune rewards, difficulty and match length.',
      'admin_page_universes_title': 'Universe tuning',
      'admin_page_universes_desc':
          'Pick a universe and adjust balance, tempo, events and bots.',
      'admin_page_idle_title': 'AFK / idle protection',
      'admin_page_idle_desc':
          'Lobby logout timers and in-match mass drain for inactive players.',
      'admin_idle_intro':
          'Lobby: after idle time a countdown warning appears, then the player is signed out.\n'
          'Match: after idle time a short countdown warning appears, then mass drains each second; at the kick mass they are treated as eliminated (diamond penalty) and signed out.',
      'admin_idle_lobby_section': 'Lobby / out of match',
      'admin_idle_lobby_before_warning': 'Idle time before warning',
      'admin_idle_lobby_countdown': 'Warning countdown',
      'admin_idle_match_section': 'During match',
      'admin_idle_match_before_warning': 'Idle time before warning',
      'admin_idle_match_countdown': 'Warning countdown before mass drain',
      'admin_idle_match_mass_drain': 'Mass lost per second while AFK',
      'admin_idle_match_kick_mass': 'Kick mass (eliminated at or below)',
      'admin_idle_reset': 'Reset to defaults',
      'admin_idle_save': 'Save',
      'admin_page_ranks_title': 'Rank settings',
      'admin_page_ranks_desc':
          'Win-point multipliers per universe and star-rank thresholds.',
      'admin_rank_intro':
          'Ranks use weighted 1st-place points (not diamonds).\n'
          'Training (simple) defaults to 0 so tutorial wins do not count.\n'
          'Normal 1 · Elite 2 · Unique 3. Thresholds are intentionally hard to climb.',
      'admin_rank_win_points_section': 'Points per 1st place',
      'admin_rank_points_simple': 'Training universe',
      'admin_rank_points_normal': 'Normal universe',
      'admin_rank_points_elite': 'Elite universe',
      'admin_rank_points_unique': 'Unique universe',
      'admin_rank_thresholds_section': 'Star rank thresholds (min points)',
      'admin_rank_nebula_note': 'Nebula is always 0 points (★).',
      'admin_rank_preview': 'Live ladder preview',
      'admin_rank_reset': 'Reset to defaults',
      'admin_rank_save': 'Save',
      'admin_page_players_title': 'Players',
      'admin_page_players_desc': 'Registration totals, live mix and top winners.',
      'admin_page_load_test_title': 'Real client simulation',
      'admin_page_load_test_desc':
          'Spawn real Supabase clients that play like phones: hunt, farm, boost, grow, share room bots (~12 Hz bot_snapshot), sync leader radius and fight sims + bots in the same room.',
      'admin_load_test_how_title': 'How to find your player ceiling',
      'admin_load_test_how_body':
          'Each client is a real account that plays like a phone: moves, farms, hunts peers and shared bots, boosts, grows, syncs leader radius (~12 Hz player_state) and room bots (~12 Hz bot_snapshot, host-authoritative).\n'
          '\n'
          '1) Pick universes, start with 25. Join a sim room from your phone to see them fight live.\n'
          '2) If “Live simulated clients” reaches your target and stays stable ~30–60s → OK. Stop, then try the next preset (50 → 100 → 200 → 300 → 400).\n'
          '3) Ceiling = last successful count. If start fails mid-way, the number that stayed alive is your practical limit.\n'
          '\n'
          'Common free-tier wall: Auth sign-in rate limit (~30–50 rapid logins per IP) — not Realtime yet. Raise it in Dashboard → Authentication → Rate Limits, or let the app pace/retry (slower start).\n'
          'Realtime concurrent limit depends on your Supabase plan. Your admin session counts. Max from this panel: {max}.',
      'admin_load_test_active': 'Live simulated clients',
      'admin_load_test_count_label': 'Client count',
      'admin_load_test_count_hint':
          '1–{max}. Use presets and step up. Note the highest number that fully started without errors.',
      'admin_load_test_auth_rate_limit':
          'Auth rate limit (429). {alive} clients stay live. Wait 1–5 min or raise Dashboard → Authentication → Rate Limits (sign-ins), then continue. Not a Realtime ceiling yet.',
      'admin_load_test_connection_ceiling':
          'Browser/device ceiling while sims are playing (Failed to fetch). {alive} live clients on this device — that is your practical single-PC limit with full gameplay AI. Stop, or continue from a second machine / raise Realtime plan.',
      'admin_load_test_room_label': 'Universes',
      'admin_load_test_room_multi_hint':
          'Select one or more. Clients are distributed round-robin across the selected universes.',
      'admin_load_test_no_universe':
          'Select at least one universe (Normal / Elite / Unique).',
      'admin_load_test_start': 'Start simulation',
      'admin_load_test_stop': 'Stop simulation',
      'admin_load_test_room_line':
          '{room}: {players} clients across {rooms} room(s)',
      'admin_load_test_join_title': 'Join sim room',
      'admin_load_test_join_hint':
          'Dedicated Test rooms only (e.g. Normal Universe Test1). Real players never join these — use the buttons below.',
      'admin_load_test_join_button': 'Join {room} ({players} sims)',
      'admin_load_test_join_failed': 'Could not join the sim room.',
      'admin_load_test_started_ok':
          'Started {count} clients in {universes} ({rooms} room instance(s)).',
      'admin_load_test_stopped_ok': 'Stopped {count} simulated clients.',
      'admin_load_test_migration_hint':
          'Load test needs an update. Run supabase/migration_load_test_ghosts.sql in the Supabase SQL Editor.',
      'admin_load_test_sim_migration_hint':
          'Run supabase/migration_load_test_sim_clients.sql in the Supabase SQL Editor, then try again.',
      'admin_load_test_sim_mint_hint':
          'Run supabase/migration_load_test_sim_mint.sql in the Supabase SQL Editor (creates sim accounts without Anonymous auth).',
      'admin_load_test_auth_settings_hint':
          'Auth blocked sim logins. Prefer running migration_load_test_sim_mint.sql. Or enable Anonymous in Authentication → Providers.',
      'admin_load_test_start_failed': 'Could not start the load test. Try again.',
      'admin_load_test_stop_failed': 'Could not stop the load test. Try again.',
      'admin_load_test_forbidden':
          'Admin permission required. Sign in again with the owner account.',
      'admin_load_test_forbidden_mint':
          'Mint RPC denied admin. In SQL Editor add your user to admin_users, re-run migration_load_test_sim_mint.sql, then sign out/in.',
      'admin_load_test_forbidden_rpc':
          'Server says this account is not admin (is_current_user_admin). Add user_id to public.admin_users, then sign out/in.',
      'admin_load_test_forbidden_session':
          'Session expired during the test. Sign in again with the owner account, then retry.',
      'admin_load_test_permission':
          'Database blocked creating test users (auth.users permission). Re-run the fix SQL as the project owner in Supabase SQL Editor.',
      'admin_load_test_auth_create_failed':
          'Could not create synthetic auth users. Run supabase/migration_load_test_players_fix.sql in the SQL Editor, then try again.',
      'admin_load_test_no_training':
          'Training universe has no matchmaking — pick Normal, Elite or Unique.',
      'admin_page_messages_title': 'Messages',
      'admin_page_messages_desc':
          'Read player feedback, reply one-by-one, or broadcast to everyone.',
      'msg_player_title': 'Messages',
      'msg_tab_inbox': 'Inbox',
      'msg_tab_compose': 'Write',
      'msg_open_inbox': 'Inbox',
      'msg_write_to_admin': 'Write to admin',
      'msg_category_feedback': 'Feedback',
      'msg_category_suggestion': 'Suggestion',
      'msg_category_bug': 'Bug',
      'msg_category_direct': 'Direct',
      'msg_category_broadcast': 'Broadcast',
      'msg_filter_open': 'Open',
      'msg_filter_closed': 'Closed',
      'msg_filter_all': 'All',
      'msg_filter_category_all': 'All types',
      'msg_broadcast': 'Broadcast',
      'live_announce_action': 'Live announce',
      'live_announce_title': 'Announcement',
      'live_announce_hint':
          'Shows a non-blocking banner to all online players for ~12 seconds. Not saved to inboxes.',
      'live_announce_body_hint': 'Short announcement (max 160 chars)…',
      'live_announce_send': 'Send live',
      'live_announce_sent': 'Live announcement sent.',
      'live_announce_dismiss': 'Dismiss',
      'live_announce_empty': 'Write a short announcement first.',
      'live_announce_cooldown': 'Wait 30 seconds before another live announce.',
      'live_announce_err': 'Could not send live announcement.',
      'live_announce_tile_hint': 'Instant on-screen banner for everyone online',
      'msg_broadcast_tile_hint': 'Save a notice to every player inbox',
      'msg_direct_tile_hint': 'Write a private message to one player',
      'msg_actions_section': 'COMPOSE',
      'msg_inbox_section': 'INBOX',
      'msg_status_label': 'STATUS',
      'msg_category_label': 'TYPE',
      'msg_unread_badge': '{count} unread',
      'msg_compose_cancel': 'Cancel',
      'msg_time_just_now': 'Just now',
      'msg_time_minutes': '{n}m',
      'msg_time_hours': '{n}h',
      'msg_time_days': '{n}d',
      'msg_send_direct': 'Message player',
      'msg_search_player': 'Search player…',
      'msg_to_player': 'To: {name}',
      'msg_subject_hint': 'Subject',
      'msg_body_hint': 'Write your message…',
      'msg_reply_hint': 'Write a reply…',
      'msg_send': 'Send',
      'msg_send_to_admin': 'Send to admin',
      'msg_empty_inbox': 'No messages yet.',
      'msg_empty_player_inbox': 'No messages yet. Write to the admin anytime.',
      'msg_migration_hint':
          'Messaging is not available yet. Run migration_admin_messaging.sql in Supabase.',
      'msg_close_thread': 'Close',
      'msg_reopen_thread': 'Reopen',
      'msg_from_admin': 'Admin',
      'msg_from_player': 'Player',
      'msg_from_you': 'You',
      'msg_compose_hint':
          'Share feedback, suggestions, or report a bug. The admin will reply here.',
      'msg_sent_ok': 'Message sent.',
      'msg_err_generic': 'Could not send message. Try again.',
      'msg_err_too_many_open': 'You have too many open threads. Close some first.',
      'msg_err_thread_hourly': 'Too many new messages this hour. Try later.',
      'msg_err_thread_cooldown': 'Please wait a moment before starting another thread.',
      'msg_err_message_hourly': 'Message limit reached for this hour.',
      'msg_err_message_cooldown': 'Please wait a few seconds before sending again.',
      'msg_broadcast_sent': 'Broadcast sent to {count} players.',
      'msg_broadcast_readonly': 'Broadcast messages cannot be replied to.',
      'admin_menu': 'Menu',
      'admin_refresh': 'Refresh',
      'admin_enter_lobby': 'Back to Lobby',
      'admin_open_panel': 'Control panel',
      'admin_total_players': 'Live players',
      'admin_total_bots': 'Live bots',
      'admin_total_universes': 'Active universes',
      'admin_active_sessions': 'Signed-in players',
      'admin_universes_section': 'Universes & difficulty',
      'admin_players_section': 'Player & bot statistics',
      'admin_difficulty': 'Difficulty',
      'admin_difficulty_relaxed': 'Relaxed',
      'admin_difficulty_standard': 'Standard',
      'admin_difficulty_elite': 'Elite',
      'admin_difficulty_unique': 'Unique',
      'admin_hunt_priority': 'Bot difficulty: {pct}%',
      'admin_hunt_priority_short': 'Bots',
      'admin_hunt_priority_howto':
          'Bot difficulty (0–100%) controls how aggressively bots hunt instead of farming. Higher = less fleeing, steadier aim, earlier boosts. Aim for human-like play around the tier default. First match uses ×0.85 of this value.',
      'admin_hunt_priority_formula':
          'Prey score ≈ sizeAdvantage × difficulty / (1 + distance/radius). Default for this tier: {default}%. Drag the slider to change; new matches use the saved value.',
      'admin_hunt_priority_reset': 'Reset bot difficulty to defaults',
      'admin_tune_bots_human_intro':
          'Competitive rooms fill to 10 players + 10 bots. Use presets so bots farm, fight and flee like real players — then fine-tune sliders if needed.',
      'admin_tune_universe_presets': 'Universe difficulty',
      'admin_tune_universe_presets_hint':
          'Ladder scaled from this universe’s defaults — food, tempo, events, radiation, and bots together. Ranked = compile-time balance.',
      'admin_tune_universe_preset_training': 'Training',
      'admin_tune_universe_preset_casual': 'Casual',
      'admin_tune_universe_preset_ranked': 'Ranked',
      'admin_tune_universe_preset_predator': 'Predator',
      'admin_tune_universe_preset_apex': 'Apex',
      'admin_tune_universe_balanced_distribute': 'Apply balanced ladder to all',
      'admin_tune_universe_balanced_distribute_hint':
          'Simple→Training · Normal→Ranked · Elite→Predator · Unique→Apex',
      'admin_tune_bot_presets': 'Bot difficulty',
      'admin_tune_bot_presets_hint':
          'Five skill ladders. Ranked is the competitive baseline. Active chip shows the current profile; slider edits clear selection until you pick again.',
      'admin_tune_bot_preset_training': 'Training',
      'admin_tune_bot_preset_casual': 'Casual',
      'admin_tune_bot_preset_ranked': 'Ranked',
      'admin_tune_bot_preset_predator': 'Predator',
      'admin_tune_bot_preset_apex': 'Apex',
      'admin_tune_bot_preset_soft': 'Training',
      'admin_tune_bot_preset_human': 'Ranked',
      'admin_tune_bot_preset_aggressive': 'Apex',
      'admin_room_tuning_howto':
          'Select a universe, then tune by category. Changes apply to new matches only.',
      'admin_room_tuning_reset': 'Reset all universe tuning to defaults',
      'admin_room_tuning_reset_one': 'Reset this universe',
      'admin_room_tuning_save': 'Save',
      'admin_tune_saving': 'Saving…',
      'admin_tune_default': 'Default {value}',
      'admin_tune_tab_world': 'World',
      'admin_tune_tab_tempo': 'Tempo',
      'admin_tune_tab_objects': 'Objects',
      'admin_tune_tab_events': 'Events',
      'admin_tune_tab_radiation': 'Radiation',
      'admin_tune_tab_bots': 'Bots',
      'admin_tune_tab_live': 'Live',
      'admin_live_instances': 'Live instances',
      'admin_tune_world': 'World & radii',
      'admin_tune_world_hint':
          'Match length and win pace: larger world / higher victory radius = longer games.',
      'admin_tune_gravity': 'Food pull gravity',
      'admin_tune_tempo_hint':
          'Target length is how long you want matches to feel. Early help protects new players; food return controls how full the map stays.',
      'admin_tune_target_min': 'Target match length (min)',
      'admin_tune_target_max': 'Target match length (max)',
      'admin_tune_early_duration': 'Early help duration',
      'admin_tune_early_growth': 'Early growth multiplier',
      'admin_tune_respawn_delay': 'Food return delay',
      'admin_tune_objects': 'Swallowable objects',
      'admin_tune_objects_hint':
          'Set a count to 0 to remove that object type from the universe.',
      'admin_tune_events': 'Cosmic events',
      'admin_tune_events_short': 'Events',
      'admin_tune_events_enabled': 'Supernova & meteor shower',
      'admin_tune_events_enabled_hint':
          'Off = no supernova/meteor (simple-room style).',
      'admin_tune_radiation_hint':
          'If a large player stands still (camps), they start shrinking. Higher radius / shorter stillness = harsher penalty.',
      'admin_tune_radiation_radius': 'Radiation start radius',
      'admin_tune_radiation_idle': 'Stillness time before penalty',
      'admin_tune_late_radiation_radius': 'Late-game radiation radius',
      'admin_tune_late_radiation_idle': 'Late-game stillness time',
      'admin_tune_late_radiation_shrink': 'Late-game shrink speed',
      'admin_tune_bots': 'Bots',
      'admin_tune_bot_ai': 'AI behaviour',
      'admin_tune_bot_ai_hint':
          'Lower decision time = faster reactions (more human). Prey ratio near 0.92–0.95 eats near same-size rivals. Keep human focus near 1.1–1.3 so bots do not tunnel only on players.',
      'admin_tune_decision_min': 'Decision interval (min)',
      'admin_tune_decision_max': 'Decision interval (max)',
      'admin_tune_prey_ratio': 'Prey size ratio',
      'admin_tune_threat_ratio': 'Threat size ratio (flee)',
      'admin_tune_prey_search': 'Prey search range',
      'admin_tune_food_search': 'Food search range',
      'admin_tune_event_awareness': 'Event awareness',
      'admin_tune_mine_avoidance': 'Mine avoidance',
      'admin_tune_min_hunt_radius': 'Min radius before hunting',
      'admin_tune_player_bias': 'Human player focus',
      'admin_tune_intercept_prey': 'Cut off moving prey',
      'admin_tune_personality': 'Personality mix',
      'admin_tune_personality_hint':
          'Relative weights for bot personalities. They do not need to sum to 100.',
      'admin_tune_personality_coward': 'Coward',
      'admin_tune_personality_aggressive': 'Aggressive',
      'admin_tune_personality_opportunist': 'Opportunist',
      'admin_tune_on': 'On',
      'admin_tune_off': 'Off',
      'admin_tune_victory_radius': 'Victory radius',
      'admin_tune_player_start_radius': 'Player start radius',
      'admin_tune_world_size': 'World size',
      'admin_tune_food_growth': 'Food growth multiplier',
      'admin_tune_asteroids': 'Small/medium asteroids',
      'admin_tune_meteorites': 'Meteorites',
      'admin_tune_planets': 'Planets',
      'admin_tune_quasar_fragments': 'Quasar fragments',
      'admin_tune_large_asteroids': 'Large asteroids',
      'admin_tune_xlarge_asteroids': 'XLarge asteroids',
      'admin_tune_giant_asteroids': 'Giant asteroids',
      'admin_tune_mines': 'Mines',
      'admin_tune_supernova_interval': 'Supernova interval',
      'admin_tune_supernova_first': 'First supernova delay',
      'admin_tune_meteor_cooldown': 'First meteor delay',
      'admin_tune_event_growth_cap': 'Max growth per event burst',
      'admin_tune_supernova_planets': 'Supernova planet burst',
      'admin_tune_bot_start_min': 'Bot start radius (min)',
      'admin_tune_bot_start_max': 'Bot start radius (max)',
      'admin_help_tooltip': 'What does this do?',
      'admin_help_got_it': 'Got it',
      'admin_help_world':
          'These settings control the size of the map and how fast players grow toward winning.\n\nBigger map + higher victory size usually = longer matches.',
      'admin_help_victory_radius':
          'The size a black hole must reach to win.\n\nHigher value = players must eat more before anyone wins, so matches last longer.',
      'admin_help_player_start_radius':
          'How big human players are when they first appear on the map.\n\nHigher = easier start and faster early growth.',
      'admin_help_world_size':
          'How large the playable map is.\n\nBigger map = players are more spread out, so it takes longer for one player to dominate.',
      'admin_help_food_growth':
          'How much bigger a hole becomes from eating asteroids/planets/food.\n\nLower = everyone grows slower; matches take longer.',
      'admin_help_gravity':
          'How strongly nearby food is pulled into holes.\n\nHigher = food “sticks” more easily, so collecting food feels easier.',
      'admin_help_tempo':
          'Tempo is about match length and early-game feel.\n\n• Target minutes = the match length you want for this universe (a design guide).\n• Early boost = humans grow faster for the first seconds.\n• Food return delay = how quickly eaten food comes back on the map.',
      'admin_help_target_min':
          'The shortest match length you aim for on this universe (in minutes).\n\nThis is a balance guide for you — not a hard timer that ends the match.',
      'admin_help_target_max':
          'The longest match length you aim for on this universe (in minutes).\n\nThis is a balance guide for you — not a hard timer that ends the match.',
      'admin_help_early_duration':
          'How many seconds the “early help” for human players lasts.\n\nDuring this time, real players grow faster than usual so they don’t fall behind bots immediately.',
      'admin_help_early_growth':
          'How much extra growth humans get during early help.\n\nExample: 1.15 means +15% growth. Helps new players catch up.',
      'admin_help_respawn_delay':
          'After food is eaten, how long until similar food appears again.\n\n• Below 1.0 = food returns faster (map stays full).\n• Above 1.0 = food returns slower (map feels emptier).',
      'admin_help_objects':
          'These numbers decide which swallowable objects exist in the universe.\n\nSet a type to 0 to remove it completely from the map.',
      'admin_help_object_count':
          'How many of this object appear on the map.\n\n0 = none. More objects = more things to eat = faster growth.',
      'admin_help_events':
          'Cosmic events suddenly add lots of planets/meteors.\n\nThey create chaos, give smaller players a chance to catch up, and change match pacing.',
      'admin_help_events_enabled':
          'Turns supernova and meteor shower on or off.\n\nOff = calm map with only normal food (like the Simple universe).',
      'admin_help_supernova_interval':
          'How many seconds between supernova events after the first one.\n\nShorter = events happen more often.',
      'admin_help_supernova_first':
          'How long to wait from match start until the first supernova warning.\n\nLower = first event comes earlier.',
      'admin_help_meteor_cooldown':
          'How long to wait from match start until the first meteor shower.\n\nHigher = early game stays calmer for longer.',
      'admin_help_event_growth_cap':
          'Maximum size one hole can gain from a single event wave.\n\nStops one lucky player from becoming huge instantly from an event.',
      'admin_help_supernova_planets':
          'How many planets a supernova can drop onto the map.\n\nMore planets = bigger feeding rush for everyone nearby.',
      'admin_help_radiation':
          'What is “camping” / “idle camping”?\nA player (or bot) who is already large stays still on purpose — not eating, not chasing — just waiting to protect their lead or stall the match.\n\nWhat does radiation do?\nIf a large hole stays still for too long, the game starts shrinking them. This forces action so the match cannot freeze forever.\n\nSettings:\n• Start radius = how big they must be before this rule can apply.\n• Stillness time = how long they may stay still before shrinking starts.\n• Late-game settings = stricter rules when someone is close to winning.\n• Shrink speed = how fast they lose size while being punished.',
      'admin_help_radiation_radius':
          'Only holes this big (or bigger) can be punished for staying still.\n\nHigher = only very large leaders get radiation. Lower = pressure starts on smaller sizes too.',
      'admin_help_radiation_idle':
          'How many seconds a large hole can stay completely still before radiation starts shrinking them.\n\nLower = camping is punished sooner. Higher = they may wait longer safely.',
      'admin_help_late_radiation_radius':
          'When a hole reaches this near-win size, stricter late-game radiation rules apply.\n\nHigher = endgame pressure starts later.',
      'admin_help_late_radiation_idle':
          'Near the end of the match: how many seconds a leader may stay still before late radiation starts.\n\nLower = finals feel more aggressive; leaders must keep moving.',
      'admin_help_late_radiation_shrink':
          'Near the end: how much size is removed each second while radiation is active.\n\nHigher = camping leaders shrink faster.',
      'admin_help_bots':
          'Bot settings shape AI like real players: start size near humans, quick decisions, balanced hunt/farm, event awareness, and personality mix. Prefer the Human-like preset, then nudge individual sliders.',
      'admin_help_hunt_priority':
          'How much bots prefer chasing/eating other holes instead of collecting food (0–100%).\n\nHigher = more aggressive hunters. Lower = they mostly eat asteroids/planets and avoid fights.',
      'admin_help_bot_start_min':
          'Smallest size a bot can have when it first appears.',
      'admin_help_bot_start_max':
          'Largest size a bot can have when it first appears.',
      'admin_help_bot_ai':
          'Advanced bot behavior: reaction speed, who they try to eat, who they run from, how far they look, and how much they notice events/mines.',
      'admin_help_decision_min':
          'Shortest time between a bot rethinking its direction.\n\nLower = bots react faster and feel smarter/harder.',
      'admin_help_decision_max':
          'Longest time between a bot rethinking its direction.\n\nLower max = bots stay consistently quick.',
      'admin_help_prey_ratio':
          'Who counts as “prey” (someone bots will try to eat).\n\nA target must be smaller than the bot × this ratio. Higher = bots also attack targets closer to their own size (riskier).',
      'admin_help_threat_ratio':
          'Who counts as a “threat” (someone bots run away from).\n\nBots flee from holes larger than themselves × this ratio. Lower = they flee earlier / more carefully.',
      'admin_help_prey_search':
          'How far bots look while searching for someone to eat.\n\nHigher = they notice prey from farther away.',
      'admin_help_food_search':
          'How far bots look while searching for food objects.\n\nHigher = better at finding asteroids/planets to eat.',
      'admin_help_event_awareness':
          'How strongly bots notice and react to supernova/meteor events (0–100%).\n\nHigher = they rush toward event food more smartly.',
      'admin_help_mine_avoidance':
          'How carefully bots avoid mines (0–100%).\n\nHigher = safer pathing around mines. (Some personality types still take more risk.)',
      'admin_help_min_hunt_radius':
          'Bots only start hunting other holes after they themselves reach this size.\n\nLower = they become aggressive earlier.',
      'admin_help_player_bias':
          'How much bots prefer chasing real human players instead of other bots.\n\nHigher = bots focus humans more.',
      'admin_help_intercept_prey':
          'When ON: bots aim ahead of a moving target (cut them off).\nWhen OFF: bots chase the target’s current position (easier to dodge).',
      'admin_help_personality':
          'How common each bot personality is.\n\nThese are relative weights — they do not need to add up to 100. Higher number = that personality appears more often.',
      'admin_help_personality_coward':
          'Coward bots care most about surviving. They flee from danger more and hunt less.',
      'admin_help_personality_aggressive':
          'Aggressive bots hunt more often and take riskier fights.',
      'admin_help_personality_opportunist':
          'Opportunist bots mostly collect food, then attack when they see an easy opening. They may risk mines more than cowards.',
      'admin_no_active_universes': 'No active universes right now',
      'admin_registered_players': 'Registered players',
      'admin_total_games_won': 'Total games won',
      'admin_live_entities': 'Live players + bots',
      'admin_bot_share': 'Bot share of live entities',
      'admin_top_winners': 'Top winners',
      'admin_no_players_yet': 'No registered players yet',
      'admin_last_updated': 'Updated {time}',
      'admin_analytics_section': 'Historical statistics',
      'admin_analytics_subtitle':
          'Signed-in = opened the app. Played = ever entered a universe (includes past leaderboard/wins). Detailed playtime & diamond flow count from when analytics was enabled.',
      'admin_analytics_window_1h': '1 hour',
      'admin_analytics_window_1d': '1 day',
      'admin_analytics_window_7d': '1 week',
      'admin_analytics_window_30d': '1 month',
      'admin_analytics_window_all': 'All time',
      'admin_analytics_unique_logins': 'Players who signed in',
      'admin_analytics_total_logins': 'Total sign-ins',
      'admin_analytics_unique_played': 'Players who played',
      'admin_analytics_matches': 'Matches entered',
      'admin_analytics_wins': 'Victories',
      'admin_analytics_registered': 'Registered players',
      'admin_analytics_playtime_title': 'Time spent in game',
      'admin_analytics_total_playtime': 'Total play time',
      'admin_analytics_avg_per_match': 'Avg. time per match',
      'admin_analytics_avg_per_player': 'Avg. time per player',
      'admin_analytics_diamonds_title': 'Diamonds economy',
      'admin_analytics_diamonds_held': 'Diamonds held by players',
      'admin_analytics_diamonds_earned': 'Earned in period (matches)',
      'admin_analytics_diamonds_lost': 'Lost in period (matches)',
      'admin_analytics_diamonds_net': 'Net in period',
      'admin_analytics_by_universe': 'By universe',
      'admin_analytics_uni_players': 'Players',
      'admin_analytics_uni_matches': 'Matches',
      'admin_analytics_uni_wins': 'Wins',
      'admin_analytics_uni_elim': 'Eliminations',
      'admin_analytics_uni_avg': 'Avg match',
      'admin_analytics_uni_diamonds': 'Net ♦',
      'admin_analytics_migration_hint':
          'Analytics unavailable. Run supabase/migration_admin_analytics.sql in the SQL Editor, then refresh.',
      'select_language': 'Language',
      'welcome_cosmic': 'Cross the event horizon',
      'login_atmosphere':
          'Absorb matter. Outplay rivals. Rule the deep-space arena.',
      'lobby_brand_eyebrow': 'Deep space arena',
      'lobby_choose_universe': 'Choose your universe',
      'store_tab_skins': 'Skins',
      'store_tab_trails': 'Trails',
      'store_tab_emotes': 'Emotes',
      'store_buy': 'Buy',
      'store_equip': 'Equip',
      'store_owned': 'Owned',
      'store_insufficient_gold': 'Not enough Gold',
      'event_quasar_storm': 'Quasar Storm!',
      'event_supernova': 'Supernova Eruption!',
      'event_supernova_warning': 'Warning: Supernova Event in {s}s!',
      'event_meteor_shower': 'Meteor Shower!',
      'event_meteor_warning': 'Warning: Meteor Shower in {s}s!',
      'event_black_hole_merge': 'Black Hole Merger!',
      'merge_stage_tidal': 'Tidal Deformation & Mass Transfer!',
      'merge_stage_dance': 'The Dance — Massive Gravitational Waves!',
      'merge_stage_ringdown': 'Merger & Ringdown — One Quasar!',
      'event_cosmic_mine': 'Cosmic Mine Detonation!',
      'event_cosmic_dust_welcome': 'Cosmic Dust Shower — free growth!',
      'first_match_hint_move':
          'Drag anywhere to steer your black hole',
      'first_match_hint_absorb':
          'Absorb asteroids and smaller holes to grow',
      'first_match_hint_grow':
          'Grow fast now — spawn shield is still active!',
      'lobby_recommended_room': 'RECOMMENDED',
      'spawn_protection_label': 'Spawn Protection Shield',
      'game_over_title': 'Event Horizon Collapse',
      'game_over_subtitle': 'Your mass was consumed by a greater void',
      'game_over_watch_ad_revive': 'Watch Ad to Revive',
      'game_over_quit': 'Quit',
      'game_over_watch_match': 'Watch Match',
      'spectator_stop_watching': 'Stop Watching',
      'game_over_peak_mass': 'Peak mass',
      'game_over_diamond_penalty':
          '−{diamonds} Diamond on quit (never below 0)',
      'game_over_play_again': 'Play Again',
      'game_over_return_lobby': 'Return to Lobby',
      'match_quit_confirm_title': 'Leave Match?',
      'match_quit_confirm_message':
          'Are you sure you want to exit? You will lose {diamonds} Diamond(s).',
      'match_quit_confirm_stay': 'Stay',
      'match_quit_confirm_leave': 'Leave',
      'leaderboard_title': 'LEADERBOARD',
      'hud_population_players': 'Players',
      'hud_population_bots': 'Bots',
      'leaderboard_you': 'You',
      'leaderboard_name': 'Name',
      'leaderboard_mass': 'Mass',
      'victory_title': 'You Conquered the Universe!',
      'victory_subtitle': 'The cosmos bows before your gravity',
      'victory_time': 'Victory time: {time}',
      'victory_reward': '+{diamonds} Diamonds · +1 Games Won',
      'victory_return_lobby': 'Return to Lobby in Glory',
      'reward_double_cta': 'Double Reward',
      'reward_double_micro': '+{extra} extra Diamonds (total {total})',
      'reward_double_done': '2× claimed · +{total} Diamonds',
      'reward_double_loading': 'Loading ad…',
      'reward_double_claiming': 'Claiming bonus…',
      'reward_double_claim_wait': 'Saving your reward… try again in a moment',
      'reward_double_ad_failed': 'Ad unavailable. Your base reward is safe.',
      'reward_double_grant_failed': 'Bonus pending — tap to retry (no new ad)',
      'reward_double_retry_grant': 'Claim Bonus',
      'reward_double_unavailable': 'Ads not available on this device',
      'frozen_title': 'Universe Conquered',
      'frozen_champion': '{name} conquered the universe in {time}',
      'match_champion_result': '{name} won the match in {time}',
      'frozen_placement_reward': 'Place #{place}: +{diamonds} Diamonds',
      'frozen_room_closed': 'The universe has closed.',
      'match_returning_lobby': 'Returning to lobby in {seconds}s…',
      'lobby_diamonds': 'Diamonds',
      'rank_tier_nebula': 'Nebula',
      'rank_tier_stellar': 'Stellar',
      'rank_tier_nova': 'Nova',
      'rank_tier_quasar': 'Quasar',
      'rank_tier_singularity': 'Singularity',
      'lobby_gold': 'Gold',
      'lobby_play': 'Play',
      'lobby_stat_universes': '{count} universes',
      'lobby_stat_players': '{count} players',
      'lobby_stat_bots': '{count} bots',
      'lobby_stat_universes_short': 'Universes',
      'lobby_stat_players_short': 'Players',
      'lobby_stat_bots_short': 'Bots',
      'lobby_room_fill_hint':
          'Each open universe: up to 10 real players, filled with bots to 20.',
      'lobby_low_population_hint':
          'Few real players online — bots fill the rest of the match.',
      'lobby_stat_solo_players': 'Solo',
      'room_entry_free': 'Entry: Free',
      'room_entry_cost': 'You need at least {count}',
      'room_entry_cost_prefix': 'You need at least {count} ',
      'room_entry_cost_suffix': '',
      'room_rewards_label': 'Rewards',
      'room_elimination_label': 'Eliminated',
      'room_elimination_none': 'no loss',
      'room_simple_title': 'Tutorial Universe',
      'lobby_first_login_lock': 'Complete the tutorial first',
      'room_instance_normal': 'Normal Universe {number}',
      'room_instance_elite': 'Elite Universe {number}',
      'room_instance_unique': 'Unique Universe {number}',
      'room_instance_normal_test': 'Normal Universe Test{number}',
      'room_instance_elite_test': 'Elite Universe Test{number}',
      'room_instance_unique_test': 'Unique Universe Test{number}',
      'matchmaking_error': 'Could not join a room. Please try again.',
      'matchmaking_insufficient_diamonds':
          'Not enough diamonds to enter this universe.',
      'matchmaking_room_full': 'That room is full. Please try again.',
      'matchmaking_room_ending':
          'That universe is ending. Please try again.',
      'matchmaking_not_authenticated': 'Please sign in again.',
      'player_already_active_title': 'Player Already Active',
      'player_already_active_message':
          'This account is already signed in on another device. Sign out there before continuing here.',
      'player_already_active_ok': 'OK',
      'idle_session_title': 'Still there?',
      'idle_session_message':
          'No activity detected. Signing out in {seconds} seconds.',
      'idle_session_stay': 'Stay signed in',
      'idle_match_title': 'AFK warning',
      'idle_match_countdown_message':
          'No activity detected. Mass drain starts in {seconds} seconds '
          '(-{drain} / sec).',
      'idle_match_message':
          'Mass is dropping by {drain} each second. '
          'At mass {threshold} you are eliminated and signed out.',
      'idle_match_stay': 'I\'m here — keep playing',
      'idle_match_result_title': 'Returning to lobby',
      'idle_match_result_message':
          'No action on this results screen. Leaving for the lobby in {seconds} seconds.',
      'idle_match_result_stay': 'Stay on this screen',
      'idle_match_result_hint':
          'If you stay idle for 10 seconds, a 10-second countdown starts and you return to the lobby.',
      'room_simple_desc':
          'Entry: Free · Bot-only tutorial\nRewards +3 · +2 · +1 · No elimination penalty · large asteroids',
      'room_normal_title': 'Normal Universes',
      'room_normal_desc':
          'You need at least 25\nRewards +5 · +3 · +2 · Eliminated -1',
      'room_elite_title': 'Elite Universes',
      'room_elite_desc':
          'You need at least 100\nRewards +10 · +6 · +4 · Eliminated -2',
      'room_unique_title': 'Unique Universes',
      'room_unique_desc':
          'You need at least 200\nRewards +15 · +10 · +5 · Eliminated -3',
      'room_requires_100': 'You need at least 100',
      'room_requires_300': 'You need at least 200',
      'room_requires_diamonds': 'You need at least {count}',
      'profile_stats_tab': 'Stats',
      'profile_store_tab': 'Store',
      'feature_coming_soon_badge': 'Coming soon',
      'feature_coming_soon_title': 'Under construction',
      'feature_coming_soon_body':
          'This section is being forged in deep space. Cosmetics and the store will open soon.',
      'profile_games_won': 'Games Won',
      'profile_global_rank': 'Global World Rank',
      'profile_rank_system': 'Rank system',
      'rank_system_intro':
          'Star badges next to names show your rank. Rank comes from win points (weighted 1st places) — not Diamonds.',
      'rank_system_your_rank': 'YOUR RANK',
      'rank_system_your_points': '{points} win points',
      'rank_system_next': 'Next: {tier} at {points}+',
      'rank_system_ladder_title': 'STAR LADDER',
      'rank_system_current_badge': 'You are here',
      'rank_system_earn_title': 'POINTS PER 1ST PLACE',
      'rank_system_points_per_win': '+{n}',
      'rank_system_points_none': 'Does not count',
      'rank_system_note':
          'Only finishing 1st in Normal / Elite / Unique adds win points and Games Won. Training does not count toward either. The Rank board sorts by win points; Wealth sorts by Diamonds.',
      'rank_system_close': 'Got it',
      'global_rank_player': 'Player',
      'global_rank_wins': 'Wins',
      'global_rank_points': 'Pts',
      'global_rank_tab_rank': 'Rank',
      'global_rank_tab_wealth': 'Wealth',
      'global_rank_blurb':
          'Rank board: win points. Wealth board: Diamonds. Wins = competitive 1st places (Training excluded).',
      'global_rank_blurb_rank':
          'Sorted by win points (then Wins). Only Normal / Elite / Unique 1st places count — Training never does.',
      'global_rank_blurb_wealth':
          'Sorted by Diamonds (then Wins). Star badges still show your competitive rank from win points.',
      'global_rank_your_position': 'YOUR POSITION',
      'global_rank_empty': 'No players ranked yet.',
      'global_rank_error': 'Could not load rankings.',
      'global_rank_retry': 'Retry',
      'profile_legendary_skins': 'Legendary Skins',
      'skin_default': 'Solar Flare',
      'skin_frost': 'Frost Veil',
      'skin_ember': 'Ember Core',
      'skin_pulsar': 'Blue Pulsar',
      'skin_nebula': 'Purple Nebula',
      'skin_plasma': 'RGB Plasma',
      'skin_void': 'Dark Void',
      'skin_quasar': 'Green Quasar',
      'skin_eclipse': 'Solar Eclipse',
      'skin_supernova': 'Red Supernova',
      'skin_aurora': 'Aurora Borealis',
      'skin_binary': 'Binary Star',
      'skin_singularity': 'Singularity Prime',
      'skin_celestial': 'Celestial Crown',
      'skin_picker_title': 'Black Hole Skins',
      'skin_picker_subtitle': 'Choose your accretion disk appearance',
      'skin_picker_equipped': 'Equipped',
      'skin_picker_locked': 'Locked',
      'skin_picker_free': 'Free',
      'trail_comet': 'Plasma Jet',
      'trail_nebula': 'Lensing Wake',
      'trail_quantum': 'Gravity Ripple',
      'trail_picker_section': 'Movement Trails',
      'trail_picker_subtitle': 'Tap an owned trail to equip it',
      'trail_picker_empty': 'Acquire trails from the Store to equip them here.',
      'trail_picker_owned': 'Owned',
      'store_trail_equip_hint': 'Equip this trail from the Appearance tab.',
      'store_trail_claim_success':
          'Trail unlocked! Equip it from the Appearance tab.',
      'emote_wave': 'Cosmic Wave',
      'emote_burst': 'Supernova Burst',
      'emote_void': 'Void Laugh',
      'store_purchase_success': 'Purchase successful!',
      'store_equip_success': 'Equipped!',
      'store_error': 'Something went wrong',
      'error_generic': 'Something went wrong. Please try again.',
      'sign_in_error': 'Sign-in failed. Please try again.',
      'profile_edit': 'Edit Profile',
      'profile_edit_name': 'Display Name',
      'profile_edit_avatar': 'Tap to change photo',
      'profile_edit_save': 'Save',
      'profile_edit_cancel': 'Cancel',
      'profile_username_taken': 'This name is already taken',
      'profile_username_invalid': 'Name must be 3–12 characters (letters, numbers, spaces)',
      'profile_update_success': 'Profile updated!',
      'profile_update_error': 'Failed to update profile',
      'lobby_how_to_play': 'Survive',
      'lobby_skill_tree': 'Power Matrix',
      'lobby_version_notes_hint': 'Transmission log',
      'skill_tree_title': 'Skill Tree',
      'skill_sp_available': 'Available SP',
      'skill_sp_earned': 'Spent / Earned',
      'skill_sp_rules':
          'Every {n} peak diamonds unlock 1 SP. Diamonds are not spent. Next SP in {next} ♦.',
      'skill_branch_boost': 'Boost',
      'skill_branch_teleport': 'Teleport',
      'skill_branch_shield': 'Shield',
      'skill_branch_shockwave': 'Shockwave',
      'skill_level': 'Lv',
      'skill_upgrade': '+1 SP',
      'skill_maxed': 'MAX',
      'skill_value_now': 'Now',
      'skill_error_no_sp': 'No skill points available',
      'skill_error_max': 'This skill is already maxed',
      'skill_error_generic': 'Could not upgrade skill',
      'skill_node_boost_speed': 'Boost Speed',
      'skill_node_boost_speed_desc': 'Higher top speed while boosting',
      'skill_node_boost_duration': 'Boost Duration',
      'skill_node_boost_duration_desc': 'Boost stays active longer',
      'skill_node_boost_charge': 'Boost Charge',
      'skill_node_boost_charge_desc': 'Faster recharge between boosts',
      'skill_node_teleport_cd': 'Teleport Cooldown',
      'skill_node_teleport_cd_desc': 'Shorter wait between teleports',
      'skill_node_teleport_shield': 'Arrival Shield',
      'skill_node_teleport_shield_desc': 'Longer protection after teleport',
      'skill_node_shield_cd': 'Shield Cooldown',
      'skill_node_shield_cd_desc': 'Shorter wait between shields',
      'skill_node_shield_duration': 'Shield Duration',
      'skill_node_shield_duration_desc': 'Active shield lasts longer',
      'skill_node_shockwave_cd': 'Shockwave Cooldown',
      'skill_node_shockwave_cd_desc': 'Shorter wait between shockwaves',
      'skill_node_shockwave_range': 'Shockwave Range',
      'skill_node_shockwave_range_desc': 'Pushes enemies from farther away',
      'skill_node_shockwave_power': 'Shockwave Power',
      'skill_node_shockwave_power_desc': 'Stronger push on smaller holes & matter',
      'settings_title': 'Settings',
      'settings_sound_title': 'Sound',
      'settings_language_section': 'Language',
      'settings_audio_section': 'Audio',
      'settings_music': 'Music',
      'settings_music_desc': 'Quasar Orbit theme',
      'settings_music_volume': 'Music volume',
      'settings_haptics': 'Vibration',
      'settings_haptics_desc': 'Haptics on hits and big events',
      'settings_audio_missing': 'Audio file could not be loaded.',
      'settings_display_section': 'Display',
      'settings_show_own_name': 'My name',
      'settings_show_own_name_desc': 'Show your name above your hole',
      'settings_show_other_names': 'Other names',
      'settings_show_other_names_desc':
          'Show other players and bots',
      'settings_show_profile_pictures': 'Avatars',
      'settings_show_profile_pictures_desc':
          'Show profile pictures on holes',
      'settings_match_section': 'Match',
      'settings_show_kill_feed': 'Kill feed',
      'settings_show_kill_feed_desc':
          'Show who absorbed whom at the top left',
      'settings_absorb_bubble': 'Absorb line',
      'settings_absorb_bubble_desc':
          'Pick what appears above your hole when you absorb someone.',
      'settings_absorb_bubble_hint': 'e.g. Absorbed!',
      'settings_absorb_bubble_save': 'Save',
      'settings_absorb_bubble_clear': 'Clear',
      'settings_support_section': 'Support',
      'how_to_play_title': 'How to Play',
      'how_to_play_close': 'Got it',
      'how_to_play_move_title': 'Movement',
      'how_to_play_move_desc':
          'Touch anywhere on the screen and drag to steer your black hole through space.',
      'how_to_play_absorb_title': 'Grow Your Mass',
      'how_to_play_absorb_desc':
          'Absorb asteroids, planets, and smaller players to grow. Avoid larger black holes or you will be consumed!',
      'how_to_play_boost_title': 'Boost',
      'how_to_play_boost_desc':
          'Energy charges in 10 seconds. Tap once when full for 5 seconds of speed — no mass loss.',
      'how_to_play_link_title': 'Binary Link',
      'how_to_play_link_desc':
          'When near another player, tap Link to form a gravitational bond and gain tactical advantages.',
      'how_to_play_shield_title': 'Shield',
      'how_to_play_shield_desc':
          'Collect shield power-ups to temporarily ignore gravity from larger black holes.',
      'how_to_play_victory_title': 'Victory',
      'how_to_play_victory_desc':
          'Grow to radius 500 to finish the match (550 in Unique universes) — the universe closes for everyone. Normal: 1st +5, 2nd +3, 3rd +2 (−1 on elimination). Elite: 1st +10, 2nd +6, 3rd +4 (−2 on elimination). Unique: 1st +15, 2nd +10, 3rd +5 (−3 on elimination). Diamonds never go below 0. New players start with 20 Diamonds.',
      'how_to_play_ranks_title': 'Rank system',
      'how_to_play_ranks_desc':
          'Your star rank (Nebula → Singularity) is based on win points, not Diamonds.\n'
          'Only finishing 1st adds win points. Training wins do not count.\n'
          'Points per 1st place: Normal +{normal}, Elite +{elite}, Unique +{unique}.\n'
          'Thresholds: Stellar {stellar}+ · Nova {nova}+ · Quasar {quasar}+ · Singularity {singularity}+.\n'
          'Games Won also excludes Training. World Rank defaults to win points (Rank tab); Wealth tab sorts by Diamonds.',
      'how_to_play_currencies_title': 'Currencies',
      'how_to_play_currencies_desc':
          'New accounts start with 20 Diamonds. Tutorial Universe is free. Normal universes need at least 25 Diamonds. Diamonds unlock Elite (100) and Unique (200) universes.',
      'how_to_play_events_title': 'Cosmic Events',
      'how_to_play_events_desc':
          'Watch for Quasar Storms, Supernovas, Meteor Showers, and more — they change the battlefield dramatically.',
      'version_notes_title': 'What\'s New',
      'version_current': 'Current version: {version}',
      'version_notes_close': 'Close',
      'version_notes_dont_show': 'Don\'t show again',
      'lobby_version_notes': 'v2.1',
      'v21_section_title': 'Version 2.1',
      'v21_section_subtitle':
          'Win-point star ranks, fairer Games Won (Training excluded), tutorial-first lock, Wins on the world leaderboard, lobby chat, inbox broadcasts, and live admin announcements.',
      'v21_change_rank_points':
          'Star ranks (Nebula → Singularity) now come from win points — weighted 1st places. Default: Normal +1, Elite +2, Unique +3. Training awards 0.',
      'v21_change_training_excluded':
          'Finishing 1st in Training no longer adds Games Won or win points — only Normal, Elite, and Unique count.',
      'v21_change_tutorial_lock':
          'New accounts must complete the Training universe before other rooms unlock (diamond gates still apply after that).',
      'v21_change_leaderboard_wins':
          'Global World Rank has Rank (win points) and Wealth (Diamonds) boards. Wins = competitive 1st places; Training never counts.',
      'v21_change_rank_dialog':
          'Rank system screen in your profile — see your tier, next threshold, and points per universe.',
      'v21_change_lobby_chat':
          'Lobby chat — talk with other players in real time while waiting in the lobby.',
      'v21_change_broadcast':
          'General announcements — team notices are delivered to every player\'s Messages inbox and stay there until you read them.',
      'v21_change_live_announce':
          'Live announcement banners — when the team sends a short notice, everyone online sees it on screen right away.',
      'v21_change_idle':
          'AFK / idle protection updated — more reliable lobby and in-match warnings, clearer countdown flow, and several idle-kick bugs fixed.',
      'v21_change_menus':
          'Lobby and profile menus refreshed — clearer layout, updated stats and rank info, and smoother navigation between lobby actions.',
      'v21_change_version_notes':
          'What\'s New refreshed for v2.1 — ranks, chat, announcements, and fair wins at the top. Shows once in the lobby until you dismiss it.',
      'v20_section_title': 'Version 2.0',
      'v20_section_subtitle':
          'Tighter competitive rooms, fairer seat and lobby counts, diamond rewards every match, shared universe events, and a true top-100 leaderboard.',
      'v20_change_room_capacity':
          'Competitive rooms are now 10 players + 10 bots — fuller fights when the room is packed; alone you still get a full 20-entity match (1 + 19 bots). Training stays 1 + 19 bots.',
      'v20_change_ghost_cleanup':
          'Ghost seats from crashed tabs or force-quits are cleared automatically — lobby counts stay honest instead of showing fake full rooms.',
      'v20_change_seat_free':
          'Dying or leaving frees your seat so someone else can join while the leader is still under radius 280. Reviving reclaims a seat if the room still has room.',
      'v20_change_match_rewards':
          'Diamond rewards work every match again — reopening a universe starts a new match generation, so podium and elimination diamonds are no longer blocked after the first claim.',
      'v20_change_cosmic_sync':
          'Supernovas, meteor showers, and their warnings are now server-timed — every player in a universe sees the same event at the same place and the same time.',
      'v20_change_real_matchmaking':
          'Matchmaking and lobby stats count real players only — cleaner rooms and accurate universe counts.',
      'v20_change_smarter_bots':
          'Bots retuned for the new 10+10 fill — more human-like farm, fight, and flee so half-bot rooms still feel competitive.',
      'v20_change_leaderboard_100':
          'Global leaderboard now returns a true top 100 by diamonds — matching what the profile already promised.',
      'v20_change_unique_theme':
          'Unique Universe has its own gold/amber look — easier to tell apart from Normal (cyan) and Elite (purple) in the lobby and in-match.',
      'v20_change_version_notes':
          'What\'s New refreshed for v2.0 — competitive rooms, fair seats, synced cosmic events, and match rewards at the top.',
      'v19_section_title': 'Version 1.9',
      'v19_section_subtitle':
          'Skill Tree progression, four combat abilities you can upgrade, player–admin messaging, idle session protection, and a harder server-side economy.',
      'v19_change_skill_tree':
          'Skill Tree in the lobby — earn Skill Points from your peak diamond balance (1 SP per 20 peak ♦). Diamonds are never spent; upgrades sync to your account.',
      'v19_change_boost_upgrades':
          'Boost branch — raise top speed, active duration, and recharge rate up to level 10 per node for soft but meaningful gains.',
      'v19_change_teleport':
          'Teleport ability — jump to a random safe spot with a short arrival shield. Skills cut the cooldown and extend the shield.',
      'v19_change_shield':
          'On-demand Shield ability — timed gravity protection separate from pickup shields. Skills shorten cooldown and lengthen duration.',
      'v19_change_shockwave':
          'Shockwave ability — push smaller bots and nearby matter away. Skills improve cooldown, range, and knockback power.',
      'v19_change_messages':
          'Messages inbox in the lobby — send feedback, suggestions, or bug reports and get replies from the team; unread badge included.',
      'v19_change_idle_protect':
          'Idle session protection — after inactivity a “Still there?” check appears; stay signed in or get signed out so abandoned sessions clear.',
      'v19_change_economy_security':
          'Economy hardened on the server — diamonds, wins, and skill upgrades only change through trusted server actions.',
      'v19_change_version_notes':
          'What\'s New refreshed for v1.9 — Skill Tree, combat abilities, and messaging at the top.',
      'v18_section_title': 'Version 1.8',
      'v18_section_subtitle':
          'Next-generation black hole graphics, longer match pacing, smarter matchmaking, cinematic swallow animations, and major performance fixes on web and mobile.',
      'v18_change_blackhole_shader':
          'Black holes rebuilt from scratch on the GPU — tilted accretion disk with turbulent plasma filaments, white-hot photon ring, pitch-black event horizon, and twin relativistic jets, modeled after real scientific imagery.',
      'v18_change_swallow_visuals':
          'Swallowing redone as a real astrophysical event — prey is stretched by tidal forces (spaghettification), torn apart at the Roche limit, and spirals into the accretion disk.',
      'v18_change_merger_rework':
          'Black hole mergers redesigned to match reference visuals — an orbital dance, matter bridge, and final collapse, without freezing the game.',
      'v18_change_merger_ripples':
          'Merger gravitational waves tuned down — fewer rings over a shorter range, so the screen stays readable during big collisions.',
      'v18_change_space_background':
          'Deep-space backdrop rebuilt for high-tier universes — nebulae, the Milky Way band, distant galaxies, and comets for a truly deep, scary void.',
      'v18_change_web_performance':
          'Web slowdown fixed — background shaders are now built once and cached instead of being recreated every frame, so matches no longer get slower over time.',
      'v18_change_meteor_perf':
          'Meteor shower events no longer tank the frame rate.',
      'v18_change_mobile_fixes':
          'Mobile fixes — the quarter-rendered black hole on phones (Impeller) and the crash-on-launch after install are both resolved.',
      'v18_change_big_hole_clarity':
          'Giant black holes render crisply — the hard "container circle" edge and the grey haze over the shadow at large sizes are gone, and full detail is kept at every size.',
      'v18_change_match_pacing':
          'Match length retuned — food growth slowed so games last closer to the targets: Training ~1.5–2.5 min, Normal ~4–6, Elite ~5–7, Unique ~7–9.',
      'v18_change_smarter_bots':
          'Bots now play to win like real players — they push for universe domination, hunt down the leader or avoid them based on size, use boost to escape supernovas and close out matches, and hesitate less as they grow.',
      'v18_change_supernova_events':
          'Supernova explosions are back and the first blast comes earlier in Normal, Elite, and Unique — a mild extra challenge outside the training universe.',
      'v18_change_event_warnings':
          'Event alerts cleaned up — only meteor showers and supernovas warn you 5 seconds ahead; other mid-event banners are gone.',
      'v18_change_leader_threshold':
          'Room join threshold lowered from radius 300 to 250 — once the leader grows that large, new players are sent to a fresh universe instance.',
      'v18_change_empty_close':
          'When the last real player leaves, the universe closes immediately so bot-only rooms no longer keep running empty.',
      'v18_change_avatar_hud_only':
          'Profile photos no longer sit in the center of the black hole — your portrait stays next to the name tag above it.',
      'v18_change_rewarded_ads':
          'Rewarded video ads integrated for revives via Google Mobile Ads.',
      'v18_change_version_notes':
          'What\'s New refreshed for v1.8 — graphics overhaul, match pacing, and matchmaking at the top.',
      'v17_section_title': 'Version 1.7',
      'v17_section_subtitle':
          'Diamond economy, player profiles, single-device sessions, live lobby stats, and onboarding for new cosmic travelers.',
      'v17_change_match_rewards':
          'Earn and lose Diamonds based on match results — podium rewards up to +15/+10/+5 in Unique universes and elimination penalties of −1/−2/−3 by tier. Results are saved server-side.',
      'v17_change_diamond_gates':
          'New accounts start with 20 Diamonds. Tutorial is free; Normal requires 25, Elite 100, Unique 200. Lobby cards show entry costs, rewards, and penalties.',
      'v17_change_profile_hub':
          'Tap your avatar in the lobby for a 3-tab profile: Stats, Skins, and Store. Games won, global rank, and live profile sync via Supabase.',
      'v17_change_edit_profile':
          'Change your 3–12 character display name and upload a profile photo from your gallery (max 5 MB). Avatars are stored in Supabase Storage.',
      'v17_change_ingame_avatars':
          'Your uploaded avatar appears inside your black hole during matches. Toggle visibility in Settings → Profile Pictures.',
      'v17_change_cosmetic_store':
          'Spend Gold in the Store to unlock legendary accretion-disk skins. Equip them from the profile menu — your active skin applies in-game.',
      'v17_change_global_leaderboard':
          'View the top 100 players worldwide ranked by Diamonds from your profile. See your own position even outside the top 100.',
      'v17_change_single_session':
          'Each account can only be in one active match at a time. Another device shows a "Player Already Active" warning until you leave.',
      'v17_change_live_lobby_stats':
          'Universe cards in the lobby show real-time counts: active universes, players, and bots — updated via Supabase Realtime.',
      'v17_change_onboarding':
          'New players must complete the Tutorial Universe first. Your first match shows timed hints.',
      'v17_change_native_splash':
          'A branded splash screen displays instantly on launch while language, auth, and settings load in the background.',
      'v17_change_hud_podium_rewards':
          'The in-match leaderboard podium now shows Diamond rewards for 1st, 2nd, and 3rd place alongside opponent rank tiers.',
      'v17_change_swallow_vfx':
          'Hunt visuals upgraded — the tidal matter bridge between black holes is now a layered Flame particle effect with hot filaments and horizon sparks.',
      'v17_change_victory_fix':
          'Matches now end as soon as radius reaches 500 (550 in Unique) — no more freezing when displayed mass rounds to the cap.',
      'v17_change_login_fix':
          'Fixed a brief "not authenticated" error flash after Google sign-in. Session checks retry while the JWT settles.',
      'v17_change_hud_loading':
          'The match HUD and leaderboard render sooner — less black loading screen at match start.',
      'v17_change_version_notes':
          'What\'s New refreshed for v1.7 — diamond economy, profiles, and session management at the top.',
      'v16_section_title': 'Version 1.6',
      'v16_section_subtitle':
          'Telescope-inspired black holes, server-side universe matchmaking, smart room splitting, and fairer random spawns.',
      'v16_change_server_matchmaking':
          'Normal, Elite, and Unique universes now use server-side room assignment — you are placed in the right universe from the lobby.',
      'v16_change_universe_instances':
          'The HUD shows which universe you are in — numbered server instances like Normal Universe 1 or Elite Universe 2.',
      'v16_change_leader_radius_split':
          'When the room leader reaches radius 300 or the room is full, new players are routed to the next universe instance.',
      'v16_change_room_lifecycle':
          'Universes close when a match ends; ghost members are cleaned up after crashes or force-quits — empty Universe 1 is no longer skipped.',
      'v16_change_abandoned_universe':
          'If all real players are eliminated or leave, the universe closes automatically — even when only bots remain.',
      'v16_change_black_hole_graphics':
          'Black holes redesigned with gravitational shadow, bright photon ring, and tilted accretion disk — scaling with your mass.',
      'v16_change_star_lensing':
          'Background stars bend, brighten, and vanish in your shadow — gravitational lensing across the universe.',
      'v16_change_swallow_animations':
          'New hunt visuals: tidal matter streams between holes, photon-ring capture flashes, and hunt sparks while closing in.',
      'v16_change_food_spaghettify':
          'Asteroids and planets stretch into ribbons only when truly in capture range — closer, more physical infall.',
      'v16_change_gravity_physics':
          'Newtonian inverse-square gravity and photon-ring capture distance — mass and pull feel more physical.',
      'v16_change_universe_tiers':
          'Four universe tiers play differently — training sandbox, normal, elite, and unique rooms with their own pacing and stakes.',
      'v16_change_cosmic_events':
          'Supernovas, meteor showers, and quasar storms reshape the battlefield mid-match.',
      'v16_change_hole_merger':
          'Two dominant black holes can trigger a galactic merger — screen shake, fabric tear, and combined mass.',
      'v16_change_random_spawn':
          'Players and bots now spawn at random positions across the universe — no more everyone starting at the center.',
      'v16_change_revive_spawn':
          'Revive also returns you to a random safe spot, kept away from other players and bots.',
      'v16_change_prey_bot_spawn':
          'Simple-room prey bots no longer spawn near your screen — they appear randomly across the whole map like everyone else.',
      'v16_change_spawn_spacing':
          'Spawn positions keep a minimum distance from other players and bots so you do not stack on top of each other.',
      'v16_change_version_notes':
          'What\'s New refreshed for v1.6 — server matchmaking and universe lifecycle fixes included at the top.',
      'v15_section_title': 'Version 1.5',
      'v15_section_subtitle':
          'A major update with fairer bots, rank badges, spawn protection, and a redesigned boost system.',
      'v15_change_match_end':
          'When anyone wins, the match freezes for all players — winner name, time, and auto-return to lobby.',
      'v15_change_bot_victory':
          'Bots can conquer the universe at mass 500. After you are eliminated, bots keep fighting for victory.',
      'v15_change_rank_system':
          'Diamond-based rank badges (I–V) now appear before player names — in-game, HUD, and match results.',
      'v15_change_spawn_shield':
          '3-second spawn protection shield on universe entry — full invulnerability with on-screen countdown.',
      'v15_change_boost':
          'Boost reworked: energy fills in 10 s, tap once for 5 s of speed — no more mass loss.',
      'v15_change_spectator':
          'Spectator mode now has a Stop Watching button at the bottom of the screen.',
      'v15_change_bot_badge':
          'Bot badge moved to the start of the name for quicker identification.',
      'v15_change_global_rank':
          'Rank badges are now shown in the Global World Rank leaderboard.',
      'v15_change_audio':
          'Only the official Quasar Orbit theme plays — looping ambient music, all other SFX removed.',
      'v15_change_bot_fixes':
          'Bots no longer stall at ~140 mass and correctly trigger match end at 500.',
      'lobby_chat_title': 'Lobby chat',
      'lobby_chat_hint': 'Say hi…',
      'lobby_chat_empty': 'No messages yet',
      'match_chat_hint': 'Short message…',
      'match_react_gg': 'GG',
      'match_react_nice': 'Nice',
      'match_react_run': 'Run!',
      'match_react_help': 'Help',
      'match_react_lol': 'Lol',
      'match_react_wow': 'Wow',
      'match_absorb_flex': 'Absorbed!',
      'match_absorb_bye': 'Bye bye',
      'match_absorb_small': 'Too small',
      'match_absorb_yummy': 'Delicious',
      'match_absorb_gone': 'Gone.',
      'match_absorb_mine': 'Mine.',
      'match_absorb_void': 'Into the void.',
      'match_absorb_next': 'Next!',
      'match_absorb_crushed': 'Crushed.',
      'match_absorb_random': 'Random',
    },
    'tr': {
      'app_title': 'Quasar.io',
      'sign_in_google': 'Google ile Giriş Yap',
      'signing_in': 'Giriş yapılıyor...',
      'sign_out': 'Çıkış Yap',
      'admin_badge': 'SAHİP',
      'admin_title': 'Yönetici Paneli',
      'admin_subtitle': 'Canlı evren, oyuncu ve bot özeti',
      'admin_nav_live': 'Canlı',
      'admin_nav_analytics': 'İstatistikler',
      'admin_nav_universes': 'Evrenler',
      'admin_nav_idle': 'AFK / Boşta',
      'admin_nav_ranks': 'Rütbeler',
      'admin_nav_players': 'Oyuncular',
      'admin_nav_load_test': 'Yük testi',
      'admin_nav_messages': 'Mesajlar',
      'admin_page_idle_title': 'AFK / boşta koruma',
      'admin_page_idle_desc':
          'Lobi çıkış süreleri ve maç içinde hareketsiz oyuncu kütle erimesi.',
      'admin_idle_intro':
          'Lobi: hareketsizlikten sonra geri sayımlı uyarı gelir; süre dolunca oyuncu oturumdan çıkar.\n'
          'Maç: hareketsizlikten sonra kısa geri sayımlı uyarı gelir, sonra her saniye kütle düşer; kick kütlesine inince yutulmuş sayılır (elmas cezası) ve oturum kapanır.',
      'admin_idle_lobby_section': 'Lobi / maç dışı',
      'admin_idle_lobby_before_warning': 'Uyarı öncesi hareketsizlik',
      'admin_idle_lobby_countdown': 'Uyarı geri sayımı',
      'admin_idle_match_section': 'Maç esnasında',
      'admin_idle_match_before_warning': 'Uyarı öncesi hareketsizlik',
      'admin_idle_match_countdown': 'Kütle erimesi öncesi uyarı süresi',
      'admin_idle_match_mass_drain': 'AFK iken saniyede kaybedilen kütle',
      'admin_idle_match_kick_mass': 'Kick kütlesi (bu değere inince elenir)',
      'admin_idle_reset': 'Varsayılanlara dön',
      'admin_idle_save': 'Kaydet',
      'admin_page_ranks_title': 'Rütbe ayarları',
      'admin_page_ranks_desc':
          'Evren başına galibiyet puanı çarpanları ve yıldız rütbe eşikleri.',
      'admin_rank_intro':
          'Rütbe elmasa değil, ağırlıklı 1.’lik puanına göre yükselir.\n'
          'Eğitim (simple) varsayılan 0 — eğitim galibiyeti sayılmaz.\n'
          'Normal 1 · Elite 2 · Unique 3. Eşikler bilerek yüksek tutulur.',
      'admin_rank_win_points_section': '1.’lik başına puan',
      'admin_rank_points_simple': 'Eğitim evreni',
      'admin_rank_points_normal': 'Normal evren',
      'admin_rank_points_elite': 'Elite evren',
      'admin_rank_points_unique': 'Unique evren',
      'admin_rank_thresholds_section': 'Yıldız rütbe eşikleri (min puan)',
      'admin_rank_nebula_note': 'Nebula her zaman 0 puan (★).',
      'admin_rank_preview': 'Canlı merdiven önizleme',
      'admin_rank_reset': 'Varsayılanlara dön',
      'admin_rank_save': 'Kaydet',
      'admin_page_live_title': 'Canlı özet',
      'admin_page_live_desc': 'Şu an kim online — oyuncu, bot ve aktif evrenler.',
      'admin_page_analytics_title': 'İstatistikler',
      'admin_page_load_test_title': 'Gerçek istemci simülasyonu',
      'admin_page_load_test_desc':
          'Gerçek Supabase istemcileri aç — telefon gibi oynar: avlanır, farm yapar, boost kullanır, büyür, odadaki ortak botları paylaşır (~12 Hz bot_snapshot), lider yarıçapı senkronlar ve sim + bot’larla savaşır.',
      'admin_load_test_how_title': 'Kaç oyuncu kaldırır? Nasıl bulursun',
      'admin_load_test_how_body':
          'Her istemci gerçek hesap; telefon gibi oynar: hareket, farm, sim + ortak bot avı, boost, büyüme, lider yarıçap senkronu (~12 Hz player_state) ve oda botları (~12 Hz bot_snapshot, host senkronu).\n'
          '\n'
          '1) Evrenleri seç, 25 ile başlat. Telefondan sim odasına girip canlı savaştıklarını gör.\n'
          '2) “Canlı simüle istemciler” istediğin sayıya ulaşıp ~30–60 sn stabil kaldıysa → başarılı. Durdur, bir üst preset dene (50 → 100 → 200 → 300 → 400).\n'
          '3) Tavan = sorunsuz tamamlanan son sayı. Yarıda kırılırsa o anda canlı kalan sayı pratik limitindir.\n'
          '\n'
          'Ücretsiz planda sık duvar: Auth giriş hız limiti (~30–50 hızlı login / IP) — henüz Realtime tavanı değil. Dashboard → Authentication → Rate Limits’ten yükselt veya uygulamanın yavaş/retry modunu kullan.\n'
          'Realtime eşzamanlı limiti Supabase planına bağlıdır. Admin oturumun da sayılır. Bu panelden en fazla: {max}.',
      'admin_load_test_active': 'Canlı simüle istemciler',
      'admin_load_test_count_label': 'İstemci sayısı',
      'admin_load_test_count_hint':
          '1–{max}. Preset’lerle adım adım artır. Hatasız tam açılan en yüksek sayıyı not et.',
      'admin_load_test_auth_rate_limit':
          'Auth hız limiti (429). {alive} oyuncu canlı kaldı — bu normal. 1–5 dk bekle veya Dashboard → Authentication → Rate Limits’ten sign-in limitini yükselt, sonra devam et. Bu henüz Realtime tavanı değil.',
      'admin_load_test_connection_ceiling':
          'Oynayan sim’lerle tek cihaz tavanı (join_game_room → Failed to fetch). Bu cihazda {alive} canlı istemci — tam oyun AI ile pratik limit bu. Durdur, ikinci cihazdan devam et veya Realtime planını yükselt.',
      'admin_load_test_room_label': 'Evrenler',
      'admin_load_test_room_multi_hint':
          'Bir veya daha fazla seç. İstemciler seçili evrenlere sırayla dağıtılır.',
      'admin_load_test_no_universe':
          'En az bir evren seç (Normal / Elit / Eşsiz).',
      'admin_load_test_start': 'Simülasyonu başlat',
      'admin_load_test_stop': 'Simülasyonu durdur',
      'admin_load_test_room_line':
          '{room}: {players} istemci · {rooms} oda',
      'admin_load_test_join_title': 'Sim odasına katıl',
      'admin_load_test_join_hint':
          'Yalnızca Test odaları (ör. Normal Evren Test1). Gerçek oyuncular buraya düşmez — aşağıdaki butonlarla katıl.',
      'admin_load_test_join_button': '{room} odasına katıl ({players} sim)',
      'admin_load_test_join_failed': 'Sim odasına katılınamadı.',
      'admin_load_test_started_ok':
          '{count} istemci {universes} evrenlerinde başlatıldı ({rooms} oda).',
      'admin_load_test_stopped_ok': '{count} simüle istemci durduruldu.',
      'admin_load_test_migration_hint':
          'Yük testi güncellenmeli. Supabase SQL Editor’da supabase/migration_load_test_ghosts.sql dosyasını çalıştırın.',
      'admin_load_test_sim_migration_hint':
          'SQL Editor’da supabase/migration_load_test_sim_clients.sql dosyasını çalıştırıp tekrar deneyin.',
      'admin_load_test_sim_mint_hint':
          'SQL Editor’da supabase/migration_load_test_sim_mint.sql dosyasını çalıştırın (Anonymous açmadan sim hesap üretir).',
      'admin_load_test_auth_settings_hint':
          'Auth sim girişlerini engelledi. Önce migration_load_test_sim_mint.sql çalıştırın. İsterseniz Authentication → Providers’tan Anonymous da açabilirsiniz.',
      'admin_load_test_start_failed': 'Yük testi başlatılamadı. Tekrar deneyin.',
      'admin_load_test_stop_failed': 'Yük testi durdurulamadı. Tekrar deneyin.',
      'admin_load_test_forbidden':
          'Admin yetkisi gerekli. Sahip hesabıyla yeniden giriş yapın.',
      'admin_load_test_forbidden_mint':
          'Mint RPC admin reddetti. SQL Editor’da hesabını admin_users’a ekle, migration_load_test_sim_mint.sql’i yeniden çalıştır, çıkış/giriş yap.',
      'admin_load_test_forbidden_rpc':
          'Sunucu bu hesabı admin görmüyor (is_current_user_admin). public.admin_users’a user_id ekleyip çıkış/giriş yap.',
      'admin_load_test_forbidden_session':
          'Test sırasında oturum düştü. Sahip hesabıyla yeniden giriş yapıp tekrar dene.',
      'admin_load_test_permission':
          'Veritabanı test kullanıcısı oluşturmayı engelledi (auth.users izni). Supabase SQL Editor’da düzeltme SQL’ini proje sahibi olarak yeniden çalıştırın.',
      'admin_load_test_auth_create_failed':
          'Sahte auth kullanıcıları oluşturulamadı. SQL Editor’da supabase/migration_load_test_players_fix.sql dosyasını çalıştırıp tekrar deneyin.',
      'admin_load_test_no_training':
          'Eğitim evreninde matchmaking yok — Normal, Elit veya Eşsiz seçin.',
      'admin_page_messages_title': 'Mesajlar',
      'admin_page_messages_desc':
          'Oyuncu görüşlerini oku, tek tek yanıtla veya herkese duyuru gönder.',
      'msg_player_title': 'Mesajlar',
      'msg_tab_inbox': 'Gelen kutusu',
      'msg_tab_compose': 'Yaz',
      'msg_open_inbox': 'Gelen kutusu',
      'msg_write_to_admin': 'Admine yaz',
      'msg_category_feedback': 'Görüş',
      'msg_category_suggestion': 'Öneri',
      'msg_category_bug': 'Hata',
      'msg_category_direct': 'Özel',
      'msg_category_broadcast': 'Duyuru',
      'msg_filter_open': 'Açık',
      'msg_filter_closed': 'Kapalı',
      'msg_filter_all': 'Tümü',
      'msg_filter_category_all': 'Tüm türler',
      'msg_broadcast': 'Toplu mesaj',
      'live_announce_action': 'Canlı duyuru',
      'live_announce_title': 'Duyuru',
      'live_announce_hint':
          'Çevrimiçi tüm oyunculara ~12 saniye süren, oyunu engellemeyen bir balon gösterir. Mesaj kutusuna kaydedilmez.',
      'live_announce_body_hint': 'Kısa duyuru (en fazla 160 karakter)…',
      'live_announce_send': 'Canlı gönder',
      'live_announce_sent': 'Canlı duyuru gönderildi.',
      'live_announce_dismiss': 'Kapat',
      'live_announce_empty': 'Önce kısa bir duyuru yazın.',
      'live_announce_cooldown': 'Yeni canlı duyuru için 30 saniye bekleyin.',
      'live_announce_err': 'Canlı duyuru gönderilemedi.',
      'live_announce_tile_hint': 'Online herkese anlık ekran balonu',
      'msg_broadcast_tile_hint': 'Herkesin mesaj kutusuna kalıcı duyuru',
      'msg_direct_tile_hint': 'Tek oyuncuya özel mesaj yaz',
      'msg_actions_section': 'GÖNDER',
      'msg_inbox_section': 'GELEN KUTUSU',
      'msg_status_label': 'DURUM',
      'msg_category_label': 'TÜR',
      'msg_unread_badge': '{count} okunmamış',
      'msg_compose_cancel': 'Vazgeç',
      'msg_time_just_now': 'Az önce',
      'msg_time_minutes': '{n}dk',
      'msg_time_hours': '{n}sa',
      'msg_time_days': '{n}g',
      'msg_send_direct': 'Oyuncuya yaz',
      'msg_search_player': 'Oyuncu ara…',
      'msg_to_player': 'Kime: {name}',
      'msg_subject_hint': 'Konu',
      'msg_body_hint': 'Mesajını yaz…',
      'msg_reply_hint': 'Yanıt yaz…',
      'msg_send': 'Gönder',
      'msg_send_to_admin': 'Admine gönder',
      'msg_empty_inbox': 'Henüz mesaj yok.',
      'msg_empty_player_inbox': 'Henüz mesaj yok. İstediğin zaman admine yazabilirsin.',
      'msg_migration_hint':
          'Mesajlaşma henüz hazır değil. Supabase\'de migration_admin_messaging.sql dosyasını çalıştırın.',
      'msg_close_thread': 'Kapat',
      'msg_reopen_thread': 'Yeniden aç',
      'msg_from_admin': 'Admin',
      'msg_from_player': 'Oyuncu',
      'msg_from_you': 'Sen',
      'msg_compose_hint':
          'Görüş, öneri veya hata bildirimi yaz. Admin buradan yanıtlar.',
      'msg_sent_ok': 'Mesaj gönderildi.',
      'msg_err_generic': 'Mesaj gönderilemedi. Tekrar deneyin.',
      'msg_err_too_many_open': 'Çok fazla açık konuşmanız var. Önce bazılarını kapatın.',
      'msg_err_thread_hourly': 'Bu saat için yeni mesaj kotası doldu. Daha sonra deneyin.',
      'msg_err_thread_cooldown': 'Yeni bir konuşma açmadan önce biraz bekleyin.',
      'msg_err_message_hourly': 'Bu saat için mesaj limitine ulaştınız.',
      'msg_err_message_cooldown': 'Tekrar göndermeden önce birkaç saniye bekleyin.',
      'msg_broadcast_sent': 'Toplu mesaj {count} oyuncuya gönderildi.',
      'msg_broadcast_readonly': 'Duyuru mesajlarına yanıt verilemez.',
      'admin_page_analytics_desc':
          'Ödül, zorluk ve maç süresini ayarlamak için geçmiş trendler.',
      'admin_page_universes_title': 'Evren ayarları',
      'admin_page_universes_desc':
          'Evren seçin; denge, tempo, olaylar ve botları ayarlayın.',
      'admin_page_players_title': 'Oyuncular',
      'admin_page_players_desc': 'Kayıt, canlı karışım ve en çok kazananlar.',
      'admin_menu': 'Menü',
      'admin_refresh': 'Yenile',
      'admin_enter_lobby': 'Lobiye Dön',
      'admin_open_panel': 'Kontrol paneli',
      'admin_total_players': 'Canlı oyuncular',
      'admin_total_bots': 'Canlı botlar',
      'admin_total_universes': 'Aktif evrenler',
      'admin_active_sessions': 'Giriş yapmış oyuncular',
      'admin_universes_section': 'Evrenler ve zorluk',
      'admin_players_section': 'Oyuncu ve bot istatistikleri',
      'admin_difficulty': 'Zorluk',
      'admin_difficulty_relaxed': 'Rahat',
      'admin_difficulty_standard': 'Standart',
      'admin_difficulty_elite': 'Elit',
      'admin_difficulty_unique': 'Eşsiz',
      'admin_hunt_priority': 'Bot zorluğu: %{pct}',
      'admin_hunt_priority_short': 'Bot',
      'admin_hunt_priority_howto':
          'Bot zorluğu (0–100%), avlanma / farm dengesini ayarlar. Yüksek = daha az kaçış, daha isabetli nişan, daha erken boost. İnsan gibi his için kademe varsayılanına yakın tutun. İlk maçta ×0.85 uygulanır.',
      'admin_hunt_priority_formula':
          'Av skoru ≈ boyutAvantajı × zorluk / (1 + mesafe/yarıçap). Bu kademenin varsayılanı: %{default}. Kaydırıcıyla değiştirin; yeni maçlar kayıtlı değeri kullanır.',
      'admin_hunt_priority_reset': 'Bot zorluğunu varsayılana sıfırla',
      'admin_tune_bots_human_intro':
          'Rekabetçi odalar 10 oyuncu + 10 bot ile dolar. Önce hazır ayarlarla botları farm/savaş/kaçışta gerçek oyuncu gibi yapın; gerekirse kaydırıcılarla ince ayar.',
      'admin_tune_universe_presets': 'Evren zorluğu',
      'admin_tune_universe_presets_hint':
          'Bu evrenin varsayılanlarından ölçeklenir — yiyecek, tempo, olaylar, radyasyon ve botlar birlikte. Rekabetçi = derleme dengesi.',
      'admin_tune_universe_preset_training': 'Eğitim',
      'admin_tune_universe_preset_casual': 'Rahat',
      'admin_tune_universe_preset_ranked': 'Rekabetçi',
      'admin_tune_universe_preset_predator': 'Avcı',
      'admin_tune_universe_preset_apex': 'Zirve',
      'admin_tune_universe_balanced_distribute': 'Dengeli kademeyi tümüne uygula',
      'admin_tune_universe_balanced_distribute_hint':
          'Basit→Eğitim · Normal→Rekabetçi · Elit→Avcı · Eşsiz→Zirve',
      'admin_tune_bot_presets': 'Bot zorluğu',
      'admin_tune_bot_presets_hint':
          'Beş kademeli beceri. Rekabetçi temel ayardır. Aktif chip mevcut profili gösterir; kaydırıcı değişince seçim kalkar.',
      'admin_tune_bot_preset_training': 'Eğitim',
      'admin_tune_bot_preset_casual': 'Rahat',
      'admin_tune_bot_preset_ranked': 'Rekabetçi',
      'admin_tune_bot_preset_predator': 'Avcı',
      'admin_tune_bot_preset_apex': 'Zirve',
      'admin_tune_bot_preset_soft': 'Eğitim',
      'admin_tune_bot_preset_human': 'Rekabetçi',
      'admin_tune_bot_preset_aggressive': 'Zirve',
      'admin_room_tuning_howto':
          'Bir evren seçin, ardından kategorilere göre ayarlayın. Değişiklikler yalnızca yeni maçlara uygulanır.',
      'admin_room_tuning_reset': 'Tüm evren ayarlarını varsayılana sıfırla',
      'admin_room_tuning_reset_one': 'Bu evreni sıfırla',
      'admin_room_tuning_save': 'Kaydet',
      'admin_tune_saving': 'Kaydediliyor…',
      'admin_tune_default': 'Varsayılan {value}',
      'admin_tune_tab_world': 'Dünya',
      'admin_tune_tab_tempo': 'Tempo',
      'admin_tune_tab_objects': 'Nesneler',
      'admin_tune_tab_events': 'Olaylar',
      'admin_tune_tab_radiation': 'Radyasyon',
      'admin_tune_tab_bots': 'Botlar',
      'admin_tune_tab_live': 'Canlı',
      'admin_live_instances': 'Canlı örnekler',
      'admin_tune_world': 'Dünya ve yarıçaplar',
      'admin_tune_world_hint':
          'Maç süresi ve zafer temposu: daha büyük dünya / daha yüksek zafer yarıçapı = daha uzun maçlar.',
      'admin_tune_gravity': 'Yiyecek çekim gücü',
      'admin_tune_tempo_hint':
          'Hedef süre bu evrenin ne kadar uzun sürmesini istediğini gösterir. Erken yardım yeni oyuncuları korur; yiyecek dönüşü haritanın doluluğunu ayarlar.',
      'admin_tune_target_min': 'Hedef maç süresi (min)',
      'admin_tune_target_max': 'Hedef maç süresi (max)',
      'admin_tune_early_duration': 'Erken yardım süresi',
      'admin_tune_early_growth': 'Erken büyüme çarpanı',
      'admin_tune_respawn_delay': 'Yiyecek geri gelme süresi',
      'admin_tune_objects': 'Yutulabilir nesneler',
      'admin_tune_objects_hint':
          'Bir nesne türünü kaldırmak için sayısını 0 yapın.',
      'admin_tune_events': 'Kozmik olaylar',
      'admin_tune_events_short': 'Olay',
      'admin_tune_events_enabled': 'Süpernova ve meteor yağmuru',
      'admin_tune_events_enabled_hint':
          'Kapalı = süpernova/meteor yok (basit evren gibi).',
      'admin_tune_radiation_hint':
          'Büyük oyuncu yerinde beklerse (kamp) küçülmeye başlar. Yüksek yarıçap / kısa hareketsizlik = daha sert ceza.',
      'admin_tune_radiation_radius': 'Radyasyon başlangıç yarıçapı',
      'admin_tune_radiation_idle': 'Hareketsizlik süresi (ceza öncesi)',
      'admin_tune_late_radiation_radius': 'Geç oyun radyasyon yarıçapı',
      'admin_tune_late_radiation_idle': 'Geç oyun hareketsizlik süresi',
      'admin_tune_late_radiation_shrink': 'Geç oyun daralma hızı',
      'admin_tune_bots': 'Botlar',
      'admin_tune_bot_ai': 'Yapay zeka davranışı',
      'admin_tune_bot_ai_hint':
          'Düşük karar süresi = daha hızlı (daha insan) tepki. Av oranı 0.92–0.95 yakın boyutta rakibe saldırır. İnsan önceliğini 1.1–1.3 civarında tutun ki botlar sadece oyuncuya kilitlenmesin.',
      'admin_tune_decision_min': 'Karar aralığı (min)',
      'admin_tune_decision_max': 'Karar aralığı (max)',
      'admin_tune_prey_ratio': 'Av boyut oranı',
      'admin_tune_threat_ratio': 'Tehdit boyut oranı (kaçış)',
      'admin_tune_prey_search': 'Av arama menzili',
      'admin_tune_food_search': 'Yiyecek arama menzili',
      'admin_tune_event_awareness': 'Olay farkındalığı',
      'admin_tune_mine_avoidance': 'Mayın kaçınma',
      'admin_tune_min_hunt_radius': 'Av için min yarıçap',
      'admin_tune_player_bias': 'İnsan oyuncu önceliği',
      'admin_tune_intercept_prey': 'Hareketli avın önünü kes',
      'admin_tune_personality': 'Kişilik karışımı',
      'admin_tune_personality_hint':
          'Bot kişiliklerinin göreli ağırlıkları. Toplamı 100 olmak zorunda değil.',
      'admin_tune_personality_coward': 'Korkak',
      'admin_tune_personality_aggressive': 'Agresif',
      'admin_tune_personality_opportunist': 'Fırsatçı',
      'admin_tune_on': 'Açık',
      'admin_tune_off': 'Kapalı',
      'admin_tune_victory_radius': 'Zafer yarıçapı',
      'admin_tune_player_start_radius': 'Oyuncu başlangıç yarıçapı',
      'admin_tune_world_size': 'Dünya boyutu',
      'admin_tune_food_growth': 'Yiyecek büyüme çarpanı',
      'admin_tune_asteroids': 'Küçük/orta asteroidler',
      'admin_tune_meteorites': 'Göktaşları',
      'admin_tune_planets': 'Gezegenler',
      'admin_tune_quasar_fragments': 'Quasar parçaları',
      'admin_tune_large_asteroids': 'Büyük asteroidler',
      'admin_tune_xlarge_asteroids': 'Çok büyük asteroidler',
      'admin_tune_giant_asteroids': 'Dev asteroidler',
      'admin_tune_mines': 'Mayınlar',
      'admin_tune_supernova_interval': 'Süpernova aralığı',
      'admin_tune_supernova_first': 'İlk süpernova gecikmesi',
      'admin_tune_meteor_cooldown': 'İlk meteor gecikmesi',
      'admin_tune_event_growth_cap': 'Olay başına max büyüme',
      'admin_tune_supernova_planets': 'Süpernova gezegen sayısı',
      'admin_tune_bot_start_min': 'Bot başlangıç yarıçapı (min)',
      'admin_tune_bot_start_max': 'Bot başlangıç yarıçapı (max)',
      'admin_help_tooltip': 'Bu ne işe yarar?',
      'admin_help_got_it': 'Anladım',
      'admin_help_world':
          'Bu ayarlar haritanın büyüklüğünü ve oyuncuların kazanmaya ne kadar hızlı yaklaşacağını belirler.\n\nDaha büyük harita + daha yüksek zafer boyutu genelde = daha uzun maç.',
      'admin_help_victory_radius':
          'Bir kara deliğin kazanmak için ulaşması gereken boyut.\n\nYüksek değer = daha fazla yemek gerekir, maçlar uzar.',
      'admin_help_player_start_radius':
          'İnsan oyuncular haritaya ilk çıktığında ne kadar büyük başlar.\n\nYüksek = başlangıç daha kolay, erken büyüme daha hızlı.',
      'admin_help_world_size':
          'Oynanabilir haritanın ne kadar büyük olduğu.\n\nBüyük harita = oyuncular dağınık kalır, bir kişinin herkesi ezmesi zorlaşır.',
      'admin_help_food_growth':
          'Asteroid/gezegen/yiyecek yenince delik ne kadar büyür.\n\nDüşük = herkes daha yavaş büyür; maçlar uzar.',
      'admin_help_gravity':
          'Yakındaki yiyeceğin deliğe ne kadar güçlü çekildiği.\n\nYüksek = yiyecek daha kolay “yapışır”, toplamak daha rahat gelir.',
      'admin_help_tempo':
          'Tempo = maçın ne kadar sürmesini istediğin ve erken oyunun temposu.\n\n• Hedef dakika = bu evren için istediğin maç süresi (sana rehber; maçı zorla bitirmez).\n• Erken yardım = ilk saniyelerde insanlar daha hızlı büyür.\n• Yiyecek geri gelme = yenilen yiyeceğin haritaya ne kadar çabuk döndüğü.',
      'admin_help_target_min':
          'Bu evren için hedeflediğin en kısa maç süresi (dakika).\n\nBu bir denge rehberidir; maçı otomatik bitiren bir süre değildir.',
      'admin_help_target_max':
          'Bu evren için hedeflediğin en uzun maç süresi (dakika).\n\nBu bir denge rehberidir; maçı otomatik bitiren bir süre değildir.',
      'admin_help_early_duration':
          'İnsan oyunculara verilen “erken yardım” kaç saniye sürer.\n\nBu sürede gerçek oyuncular normalden hızlı büyür; botların hemen gerisinde kalmazlar.',
      'admin_help_early_growth':
          'Erken yardım sırasında insanlara verilen ekstra büyüme miktarı.\n\nÖrnek: 1.15 = %15 daha hızlı büyüme. Yeni oyuncuların yetişmesine yardım eder.',
      'admin_help_respawn_delay':
          'Yiyecek yenildikten sonra benzer yiyeceğin haritada tekrar belirmesi ne kadar sürer.\n\n• 1.0’ın altı = yiyecek daha çabuk döner (harita dolu kalır).\n• 1.0’ın üstü = yiyecek daha geç döner (harita daha boş hisseder).',
      'admin_help_objects':
          'Bu sayılar evrende hangi yutulabilir nesnelerin olacağını belirler.\n\nBir türü 0 yapmak o nesneyi haritadan tamamen kaldırır.',
      'admin_help_object_count':
          'Haritada bu nesneden kaç tane olacağı.\n\n0 = hiç yok. Daha fazla nesne = daha çok yiyecek = daha hızlı büyüme.',
      'admin_help_events':
          'Kozmik olaylar birdenbire çok sayıda gezegen/meteor getirir.\n\nKaos yaratır, küçük oyunculara yetişme şansı verir, maçın temposunu değiştirir.',
      'admin_help_events_enabled':
          'Süpernova ve meteor yağmurunu açar/kapatır.\n\nKapalı = sakin harita, sadece normal yiyecek (Basit evren gibi).',
      'admin_help_supernova_interval':
          'İlk süpernovadan sonra bir sonraki süpernovaya kadar kaç saniye geçeceği.\n\nKısa = olaylar daha sık gelir.',
      'admin_help_supernova_first':
          'Maç başladıktan sonra ilk süpernova uyarısına kadar beklenen süre.\n\nDüşük = ilk olay daha erken gelir.',
      'admin_help_meteor_cooldown':
          'Maç başladıktan sonra ilk meteor yağmuruna kadar beklenen süre.\n\nYüksek = erken oyun daha uzun süre sakin kalır.',
      'admin_help_event_growth_cap':
          'Tek bir olay dalgasından bir deliğin kazanabileceği en fazla boyut.\n\nBir oyuncunun olaydan aniden devasa olmasını engeller.',
      'admin_help_supernova_planets':
          'Bir süpernovanın haritaya kaç gezegen bırakabileceği.\n\nDaha fazla gezegen = yakındakiler için daha büyük beslenme fırsatı.',
      'admin_help_radiation':
          '“Kamp” / “idle kamp” nedir?\nZaten büyümüş bir oyuncu (veya bot) bilerek yerinde durur: yemez, kovalamaz; sadece liderliğini korumak veya maçı uzatmak için bekler.\n\nRadyasyon ne yapar?\nBüyük bir delik çok uzun süre hareketsiz kalırsa oyun onu küçültmeye başlar. Böylece maç sonsuza kadar kilitlenmez; oyuncu hareket etmek zorunda kalır.\n\nAyarlar:\n• Başlangıç yarıçapı = bu cezanın uygulanması için ne kadar büyük olunmalı.\n• Hareketsizlik süresi = küçülme başlamadan önce kaç saniye durulabilir.\n• Geç oyun ayarları = zafere yaklaşınca daha sert kurallar.\n• Daralma hızı = ceza sırasında boyutun ne kadar hızlı eridiği.',
      'admin_help_radiation_radius':
          'Sadece bu boyuta (veya daha büyüğe) ulaşmış delikler hareketsiz kaldığı için cezalandırılabilir.\n\nYüksek = yalnızca çok büyük liderler etkilenir. Düşük = daha küçük boyutlarda da baskı başlar.',
      'admin_help_radiation_idle':
          'Büyük bir delik radyasyon başlamadan önce kaç saniye tamamen hareketsiz kalabilir.\n\nDüşük = kamp daha çabuk cezalandırılır. Yüksek = daha uzun güvenli bekleyebilir.',
      'admin_help_late_radiation_radius':
          'Bir delik bu “neredeyse kazandım” boyutuna gelince geç oyun radyasyon kuralları devreye girer.\n\nYüksek = son baskı daha geç başlar.',
      'admin_help_late_radiation_idle':
          'Maçın sonuna yakın: lider kaç saniye yerinde durabilir, sonra geç radyasyon başlar.\n\nDüşük = final daha agresif; liderlerin sürekli hareket etmesi gerekir.',
      'admin_help_late_radiation_shrink':
          'Maçın sonuna yakın: radyasyon açıkken her saniye ne kadar boyut silinir.\n\nYüksek = kampta bekleyen liderler daha hızlı küçülür.',
      'admin_help_bots':
          'Bot ayarları yapay zekayı gerçek oyuncu gibi şekillendirir: insanlara yakın başlangıç boyutu, hızlı karar, dengeli av/farm, olay farkındalığı ve kişilik karışımı. Önce “İnsan gibi” hazır ayarını kullanın, sonra kaydırıcılarla ince ayar yapın.',
      'admin_help_hunt_priority':
          'Botların yiyecek toplamak yerine başka delikleri kovalayıp yemeyi ne kadar tercih ettiği (0–100%).\n\nYüksek = daha saldırgan avcı. Düşük = çoğunlukla asteroid/gezegen yer, dövüşten kaçınır.',
      'admin_help_bot_start_min':
          'Bir bot haritaya ilk çıktığında olabileceği en küçük boyut.',
      'admin_help_bot_start_max':
          'Bir bot haritaya ilk çıktığında olabileceği en büyük boyut.',
      'admin_help_bot_ai':
          'Gelişmiş bot davranışı: tepki hızı, kimi yemeye çalışacağı, kimden kaçacağı, ne kadar uzağı tarayacağı, olayları/mayınları ne kadar umursayacağı.',
      'admin_help_decision_min':
          'Botun yönünü yeniden düşünmesi arasındaki en kısa süre.\n\nDüşük = botlar daha hızlı tepki verir, daha zor hissedilir.',
      'admin_help_decision_max':
          'Botun yönünü yeniden düşünmesi arasındaki en uzun süre.\n\nDüşük üst sınır = botlar sürekli hızlı kalır.',
      'admin_help_prey_ratio':
          '“Av” kimdir? (Botun yemeye çalışacağı rakip.)\n\nHedef, botun kendi boyutunun bu oranından küçük olmalı. Yüksek = botlar kendine yakın boyuttaki riskli rakiplere de saldırır.',
      'admin_help_threat_ratio':
          '“Tehdit” kimdir? (Botun kaçacağı rakip.)\n\nBot, kendi boyutunun bu oranından büyük deliklerden kaçar. Düşük = daha erken / daha temkinli kaçar.',
      'admin_help_prey_search':
          'Botların yiyecek (rakip) ararken ne kadar uzağa baktığı.\n\nYüksek = uzaktaki rakipleri daha erken fark eder.',
      'admin_help_food_search':
          'Botların asteroid/gezegen ararken ne kadar uzağa baktığı.\n\nYüksek = yiyecek bulmada daha iyidir.',
      'admin_help_event_awareness':
          'Botların süpernova/meteor olaylarını ne kadar fark edip tepki verdiği (0–100%).\n\nYüksek = olay yiyeceğine daha akıllıca koşar.',
      'admin_help_mine_avoidance':
          'Botların mayınlardan ne kadar dikkatli kaçındığı (0–100%).\n\nYüksek = mayınlardan daha güvenli yol çizer. (Bazı kişilikler yine de daha risk alır.)',
      'admin_help_min_hunt_radius':
          'Botlar, kendi boyutları buna ulaşmadan başka delikleri avlamaz.\n\nDüşük = daha erken saldırganlaşırlar.',
      'admin_help_player_bias':
          'Botların diğer botlar yerine gerçek insan oyuncuları ne kadar öncelikli kovaladığı.\n\nYüksek = botlar insanlara daha çok odaklanır.',
      'admin_help_intercept_prey':
          'Açıkken: botlar hareket eden hedefin önünü kesmeye çalışır.\nKapalıyken: hedefin şu anki konumuna koşar (kaçmak daha kolaydır).',
      'admin_help_personality':
          'Her bot kişiliğinin ne sıklıkta göründüğü.\n\nBunlar göreli ağırlıklardır — toplamının 100 olması gerekmez. Yüksek sayı = o kişilik daha sık çıkar.',
      'admin_help_personality_coward':
          'Korkak botlar hayatta kalmayı önceler. Tehlikeden daha çok kaçar, daha az avlanır.',
      'admin_help_personality_aggressive':
          'Agresif botlar daha sık avlanır ve daha riskli dövüşlere girer.',
      'admin_help_personality_opportunist':
          'Fırsatçı botlar çoğunlukla yiyecek toplar; kolay açık görünce saldırır. Korkaklara göre mayın riskini daha fazla göze alabilir.',
      'admin_no_active_universes': 'Şu an aktif evren yok',
      'admin_registered_players': 'Kayıtlı oyuncular',
      'admin_total_games_won': 'Toplam galibiyet',
      'admin_live_entities': 'Canlı oyuncu + bot',
      'admin_bot_share': 'Botların canlı oranı',
      'admin_top_winners': 'En çok kazananlar',
      'admin_no_players_yet': 'Henüz kayıtlı oyuncu yok',
      'admin_last_updated': 'Güncelleme {time}',
      'admin_analytics_section': 'Geçmiş istatistikler',
      'admin_analytics_subtitle':
          'Oyuna giren = uygulamaya giriş. Oynayan = evrene girenler (eski skor/galibiyet dahil). Detaylı süre ve elmas akışı analytics açıldıktan sonra birikir.',
      'admin_analytics_window_1h': '1 saat',
      'admin_analytics_window_1d': '1 gün',
      'admin_analytics_window_7d': '1 hafta',
      'admin_analytics_window_30d': '1 ay',
      'admin_analytics_window_all': 'Başından beri',
      'admin_analytics_unique_logins': 'Oyuna giren farklı oyuncu',
      'admin_analytics_total_logins': 'Toplam giriş sayısı',
      'admin_analytics_unique_played': 'Oynayan farklı oyuncu',
      'admin_analytics_matches': 'Girilen maç',
      'admin_analytics_wins': 'Zafer',
      'admin_analytics_registered': 'Kayıtlı oyuncu',
      'admin_analytics_playtime_title': 'Oyunda geçirilen süre',
      'admin_analytics_total_playtime': 'Toplam oyun süresi',
      'admin_analytics_avg_per_match': 'Maç başına ort. süre',
      'admin_analytics_avg_per_player': 'Oyuncu başına ort. süre',
      'admin_analytics_diamonds_title': 'Elmas ekonomisi',
      'admin_analytics_diamonds_held': 'Oyuncuların elindeki elmas',
      'admin_analytics_diamonds_earned': 'Dönemde kazanılan (maç)',
      'admin_analytics_diamonds_lost': 'Dönemde kaybedilen (maç)',
      'admin_analytics_diamonds_net': 'Dönem net',
      'admin_analytics_by_universe': 'Evrenlere göre',
      'admin_analytics_uni_players': 'Oyuncu',
      'admin_analytics_uni_matches': 'Maç',
      'admin_analytics_uni_wins': 'Zafer',
      'admin_analytics_uni_elim': 'Eleme',
      'admin_analytics_uni_avg': 'Ort. maç',
      'admin_analytics_uni_diamonds': 'Net ♦',
      'admin_analytics_migration_hint':
          'İstatistikler henüz yok. Supabase SQL Editor’da supabase/migration_admin_analytics.sql dosyasını çalıştırıp yenileyin.',
      'select_language': 'Dil',
      'welcome_cosmic': 'Olay ufkunu aş',
      'login_atmosphere':
          'Maddeyi yut. Rakipleri geç. Derin uzay arenasına hükmet.',
      'lobby_brand_eyebrow': 'Derin uzay arenası',
      'lobby_choose_universe': 'Evrenini seç',
      'store_tab_skins': 'Görünümler',
      'store_tab_trails': 'İzler',
      'store_tab_emotes': 'Emojiler',
      'store_buy': 'Satın Al',
      'store_equip': 'Kuşan',
      'store_owned': 'Sahip',
      'store_insufficient_gold': 'Yetersiz Altın',
      'event_quasar_storm': 'Kuasar Fırtınası!',
      'event_supernova': 'Süpernova Patlaması!',
      'event_supernova_warning': 'Uyarı: {s} saniye içinde Süpernova!',
      'event_meteor_shower': 'Meteor Yağmuru!',
      'event_meteor_warning': 'Uyarı: {s} saniye içinde Meteor Yağmuru!',
      'event_black_hole_merge': 'Kara Delik Birleşmesi!',
      'merge_stage_tidal': 'Gelgit Bozulması ve Kütle Aktarımı!',
      'merge_stage_dance': 'Dans — Devasa Kütleçekim Dalgaları!',
      'merge_stage_ringdown': 'Birleşme ve Sönümleme — Tek Kuasar!',
      'event_cosmic_mine': 'Kozmik Mayın Patlaması!',
      'event_cosmic_dust_welcome': 'Kozmik Toz Yağmuru — bedava büyüme!',
      'first_match_hint_move':
          'Yön vermek için ekranda sürükleyin',
      'first_match_hint_absorb':
          'Büyümek için asteroidleri ve küçük delikleri yutun',
      'first_match_hint_grow':
          'Hızlı büyü — başlangıç kalkanın hâlâ aktif!',
      'lobby_recommended_room': 'ÖNERİLEN',
      'spawn_protection_label': 'Başlangıç Koruma Kalkanı',
      'game_over_title': 'Olay Ufku Çöküşü',
      'game_over_subtitle': 'Kütleniz daha büyük bir boşluk tarafından yutuldu',
      'game_over_watch_ad_revive': 'Reklam İzle ve Diril',
      'game_over_quit': 'Çık',
      'game_over_watch_match': 'Maçı İzle',
      'spectator_stop_watching': 'İzlemeyi Bırak',
      'game_over_peak_mass': 'Zirve kütle',
      'game_over_diamond_penalty':
          'Çıkışta −{diamonds} Elmas (0\'ın altına inmez)',
      'game_over_play_again': 'Tekrar Oyna',
      'game_over_return_lobby': 'Lobiye Dön',
      'match_quit_confirm_title': 'Maçtan Çık',
      'match_quit_confirm_message':
          'Çıkmak istediğinize emin misiniz? {diamonds} elmas kaybedeceksiniz.',
      'match_quit_confirm_stay': 'Kal',
      'match_quit_confirm_leave': 'Çık',
      'leaderboard_title': 'LİDERLİK',
      'hud_population_players': 'Oyuncu',
      'hud_population_bots': 'Bot',
      'leaderboard_you': 'Sen',
      'leaderboard_name': 'İsim',
      'leaderboard_mass': 'Kütle',
      'victory_title': 'Evrenin Hakimi Oldunuz!',
      'victory_subtitle': 'Kozmos yerçekiminizin önünde eğiliyor',
      'victory_time': 'Zafer süresi: {time}',
      'victory_reward': '+{diamonds} Elmas · +1 Galibiyet',
      'victory_return_lobby': 'Şanla Lobiye Dön',
      'reward_double_cta': 'Ödülü 2× Yap',
      'reward_double_micro': '+{extra} ekstra Elmas (toplam {total})',
      'reward_double_done': '2× alındı · +{total} Elmas',
      'reward_double_loading': 'Reklam yükleniyor…',
      'reward_double_claiming': 'Bonus işleniyor…',
      'reward_double_claim_wait': 'Ödül kaydediliyor… biraz sonra tekrar dene',
      'reward_double_ad_failed': 'Reklam yok. Temel ödülünüz güvende.',
      'reward_double_grant_failed': 'Bonus bekliyor — tekrar dokun (yeni reklam yok)',
      'reward_double_retry_grant': 'Bonusu Al',
      'reward_double_unavailable': 'Bu cihazda reklam yok',
      'frozen_title': 'Evren Fethedildi',
      'frozen_champion': '{name}, {time} içinde evreni fethetti',
      'match_champion_result': '{name} maçı {time} sürede kazandı',
      'frozen_placement_reward': '{place}. sıra: +{diamonds} Elmas',
      'frozen_room_closed': 'Evren kapandı.',
      'match_returning_lobby': '{seconds} sn içinde lobiye dönülüyor…',
      'lobby_diamonds': 'Elmas',
      'rank_tier_nebula': 'Nebula',
      'rank_tier_stellar': 'Yıldız',
      'rank_tier_nova': 'Nova',
      'rank_tier_quasar': 'Kuasar',
      'rank_tier_singularity': 'Tekillik',
      'lobby_gold': 'Altın',
      'lobby_play': 'Oyna',
      'lobby_stat_universes': '{count} evren',
      'lobby_stat_players': '{count} oyuncu',
      'lobby_stat_bots': '{count} bot',
      'lobby_stat_universes_short': 'Evren',
      'lobby_stat_players_short': 'Oyuncu',
      'lobby_stat_bots_short': 'Bot',
      'lobby_room_fill_hint':
          'Her açık evren: en fazla 10 gerçek oyuncu, botlarla 20’ye tamamlanır.',
      'lobby_low_population_hint':
          'Az gerçek oyuncu var — maçın geri kalanını botlar doldurur.',
      'lobby_stat_solo_players': 'Solo',
      'room_entry_free': 'Giriş: Ücretsiz',
      'room_entry_cost': 'En az {count}',
      'room_entry_cost_prefix': 'En az {count} ',
      'room_entry_cost_suffix': 'ınız olmalı',
      'room_rewards_label': 'Ödüller',
      'room_elimination_label': 'Yutulma',
      'room_elimination_none': 'kayıp yok',
      'room_simple_title': 'Eğitim Evreni',
      'lobby_first_login_lock': 'Önce eğitim evrenini tamamlayın',
      'room_instance_normal': 'Normal Evren {number}',
      'room_instance_elite': 'Elit Evren {number}',
      'room_instance_unique': 'Eşsiz Evren {number}',
      'room_instance_normal_test': 'Normal Evren Test{number}',
      'room_instance_elite_test': 'Elit Evren Test{number}',
      'room_instance_unique_test': 'Eşsiz Evren Test{number}',
      'matchmaking_error': 'Odaya katılınamadı. Lütfen tekrar deneyin.',
      'matchmaking_insufficient_diamonds':
          'Bu evrene girmek için yeterli elmasınız yok.',
      'matchmaking_room_full': 'Oda dolu. Lütfen tekrar deneyin.',
      'matchmaking_room_ending':
          'Bu evren sona eriyor. Lütfen tekrar deneyin.',
      'matchmaking_not_authenticated': 'Lütfen tekrar giriş yapın.',
      'player_already_active_title': 'Oyuncu Zaten Aktif',
      'player_already_active_message':
          'Bu hesap başka bir cihazda oturum açık. Buradan devam etmek için önce oradan çıkış yapın.',
      'player_already_active_ok': 'Tamam',
      'idle_session_title': 'Hâlâ orada mısın?',
      'idle_session_message':
          'Hiç işlem yapılmadı. {seconds} saniye içinde oturum kapatılacak.',
      'idle_session_stay': 'Oturumda kal',
      'idle_match_title': 'AFK uyarısı',
      'idle_match_countdown_message':
          'Hareket yok. Kütle erimesi {seconds} saniye sonra başlar '
          '(-{drain} / sn).',
      'idle_match_message':
          'Her saniye kütlen {drain} düşüyor. '
          'Kütle {threshold} olunca yutulmuş sayılıp oturum kapanır.',
      'idle_match_stay': 'Buradayım — oynamaya devam',
      'idle_match_result_title': 'Lobiye dönülüyor',
      'idle_match_result_message':
          'Sonuç ekranında işlem yapılmadı. {seconds} saniye içinde lobiye dönülecek.',
      'idle_match_result_stay': 'Bu ekranda kal',
      'idle_match_result_hint':
          '10 saniye hareketsiz kalırsanız 10 saniyelik geri sayım başlar ve lobiye dönersiniz.',
      'room_simple_desc':
          'Giriş: Ücretsiz · Bot-only eğitim\nÖdüller +3 · +2 · +1 · Yutulma kayıp yok · büyük asteroidler',
      'room_normal_title': 'Normal Evrenler',
      'room_normal_desc':
          'En az 25\nÖdüller +5 · +3 · +2 · Yutulma -1',
      'room_elite_title': 'Elit Evrenler',
      'room_elite_desc':
          'En az 100\nÖdüller +10 · +6 · +4 · Yutulma -2',
      'room_unique_title': 'Eşsiz Evrenler',
      'room_unique_desc':
          'En az 200\nÖdüller +15 · +10 · +5 · Yutulma -3',
      'room_requires_100': 'En az 100',
      'room_requires_300': 'En az 200',
      'room_requires_diamonds': 'En az {count}',
      'profile_stats_tab': 'İstatistikler',
      'profile_store_tab': 'Mağaza',
      'feature_coming_soon_badge': 'Yakında',
      'feature_coming_soon_title': 'Yapım aşamasında',
      'feature_coming_soon_body':
          'Bu bölüm derin uzayda şekilleniyor. Görünümler ve mağaza yakında açılacak.',
      'profile_games_won': 'Kazanılan Maç',
      'profile_global_rank': 'Global Dünya Sıralaması',
      'profile_rank_system': 'Rütbe sistemi',
      'rank_system_intro':
          'İsim yanındaki yıldızlar rütbeni gösterir. Rütbe galibiyet puanına göre yükselir (ağırlıklı 1.’lik) — elmasa göre değil.',
      'rank_system_your_rank': 'SENİN RÜTBEN',
      'rank_system_your_points': '{points} galibiyet puanı',
      'rank_system_next': 'Sonraki: {tier} · {points}+',
      'rank_system_ladder_title': 'YILDIZ MERDİVENİ',
      'rank_system_current_badge': 'Buradasın',
      'rank_system_earn_title': '1.’LİK BAŞINA PUAN',
      'rank_system_points_per_win': '+{n}',
      'rank_system_points_none': 'Sayılmaz',
      'rank_system_note':
          'Sadece Normal / Elite / Unique\'de 1. olmak galibiyet puanı ve galibiyet sayısına ekler. Eğitim hiç sayılmaz. Rütbe listesi galibiyet puanına, Zenginlik listesi elmasa göre sıralanır.',
      'rank_system_close': 'Anladım',
      'global_rank_player': 'Oyuncu',
      'global_rank_wins': 'Galibiyet',
      'global_rank_points': 'Puan',
      'global_rank_tab_rank': 'Rütbe',
      'global_rank_tab_wealth': 'Zenginlik',
      'global_rank_blurb':
          'Rütbe: galibiyet puanı. Zenginlik: elmas. Galibiyet = rekabetçi 1.’lik (Eğitim hariç).',
      'global_rank_blurb_rank':
          'Sıra galibiyet puanına göredir (sonra galibiyet). Sadece Normal / Elite / Unique 1.’liği sayılır — Eğitim asla sayılmaz.',
      'global_rank_blurb_wealth':
          'Sıra elmasa göredir (sonra galibiyet). İsim yanındaki yıldızlar yine galibiyet puanından gelen rütbendir.',
      'global_rank_your_position': 'SENİN SIRAN',
      'global_rank_empty': 'Henüz sıralama yok.',
      'global_rank_error': 'Sıralama yüklenemedi.',
      'global_rank_retry': 'Tekrar Dene',
      'profile_legendary_skins': 'Efsanevi Görünümler',
      'skin_default': 'Güneş Parlaması',
      'skin_frost': 'Buz Perdesi',
      'skin_ember': 'Kor Çekirdeği',
      'skin_pulsar': 'Mavi Pulsar',
      'skin_nebula': 'Mor Nebula',
      'skin_plasma': 'RGB Plazma',
      'skin_void': 'Karanlık Boşluk',
      'skin_quasar': 'Yeşil Kuasar',
      'skin_eclipse': 'Güneş Tutulması',
      'skin_supernova': 'Kırmızı Süpernova',
      'skin_aurora': 'Kuzey Işıkları',
      'skin_binary': 'İkili Yıldız',
      'skin_singularity': 'Tekillik Prime',
      'skin_celestial': 'Göksel Taç',
      'skin_picker_title': 'Kara Delik Görünümleri',
      'skin_picker_subtitle': 'Akresyon diski görünümünü seç',
      'skin_picker_equipped': 'Kuşanıldı',
      'skin_picker_locked': 'Kilitli',
      'skin_picker_free': 'Ücretsiz',
      'trail_comet': 'Plazma Jeti',
      'trail_nebula': 'Lensleme İzi',
      'trail_quantum': 'Yerçekimi Dalgası',
      'trail_picker_section': 'Hareket İzleri',
      'trail_picker_subtitle': 'Sahip olduğun izlere dokunarak kuşan',
      'trail_picker_empty':
          'Mağazadan iz aldıktan sonra buradan kuşanabilirsin.',
      'trail_picker_owned': 'Sahip',
      'store_trail_equip_hint': 'Bu izi Görünüm sekmesinden kuşan.',
      'store_trail_claim_success':
          'İz açıldı! Görünüm sekmesinden kuşanabilirsin.',
      'emote_wave': 'Kozmik Dalga',
      'emote_burst': 'Süpernova Patlaması',
      'emote_void': 'Boşluk Kahkahası',
      'store_purchase_success': 'Satın alım başarılı!',
      'store_equip_success': 'Kuşanıldı!',
      'store_error': 'Bir hata oluştu',
      'error_generic': 'Bir hata oluştu. Lütfen tekrar deneyin.',
      'sign_in_error': 'Giriş başarısız. Lütfen tekrar deneyin.',
      'profile_edit': 'Profili Düzenle',
      'profile_edit_name': 'Görünen İsim',
      'profile_edit_avatar': 'Fotoğrafı değiştirmek için dokunun',
      'profile_edit_save': 'Kaydet',
      'profile_edit_cancel': 'İptal',
      'profile_username_taken': 'Bu isim zaten kullanılıyor',
      'profile_username_invalid':
          'İsim 3–12 karakter olmalı (harf, rakam, boşluk)',
      'profile_update_success': 'Profil güncellendi!',
      'profile_update_error': 'Profil güncellenemedi',
      'lobby_how_to_play': 'Hayatta Kal',
      'lobby_skill_tree': 'Güç Matrisi',
      'lobby_version_notes_hint': 'İletişim kaydı',
      'skill_tree_title': 'Yetenek Ağacı',
      'skill_sp_available': 'Kullanılabilir SP',
      'skill_sp_earned': 'Harcanan / Kazanılan',
      'skill_sp_rules':
          'Her {n} zirve elmas 1 SP açar. Elmas harcanmaz. Sonraki SP için {next} ♦.',
      'skill_branch_boost': 'Boost',
      'skill_branch_teleport': 'Işınlanma',
      'skill_branch_shield': 'Kalkan',
      'skill_branch_shockwave': 'Şok Dalgası',
      'skill_level': 'Sv',
      'skill_upgrade': '+1 SP',
      'skill_maxed': 'MAX',
      'skill_value_now': 'Şu an',
      'skill_error_no_sp': 'Yetenek puanı yok',
      'skill_error_max': 'Bu yetenek zaten maksimumda',
      'skill_error_generic': 'Yetenek yükseltilemedi',
      'skill_node_boost_speed': 'Boost Hızı',
      'skill_node_boost_speed_desc': 'Boost sırasında daha yüksek hız',
      'skill_node_boost_duration': 'Boost Süresi',
      'skill_node_boost_duration_desc': 'Boost daha uzun aktif kalır',
      'skill_node_boost_charge': 'Boost Dolumu',
      'skill_node_boost_charge_desc': 'Boostlar arası daha hızlı şarj',
      'skill_node_teleport_cd': 'Işınlanma Bekleme',
      'skill_node_teleport_cd_desc': 'Işınlanmalar arası daha kısa bekleme',
      'skill_node_teleport_shield': 'Varış Kalkanı',
      'skill_node_teleport_shield_desc': 'Işınlanma sonrası daha uzun koruma',
      'skill_node_shield_cd': 'Kalkan Bekleme',
      'skill_node_shield_cd_desc': 'Kalkanlar arası daha kısa bekleme',
      'skill_node_shield_duration': 'Kalkan Süresi',
      'skill_node_shield_duration_desc': 'Aktif kalkan daha uzun sürer',
      'skill_node_shockwave_cd': 'Şok Bekleme',
      'skill_node_shockwave_cd_desc': 'Şok dalgaları arası daha kısa bekleme',
      'skill_node_shockwave_range': 'Şok Menzili',
      'skill_node_shockwave_range_desc': 'Daha uzaktan iter',
      'skill_node_shockwave_power': 'Şok Gücü',
      'skill_node_shockwave_power_desc': 'Küçük delik ve maddeye daha güçlü itiş',
      'settings_title': 'Ayarlar',
      'settings_sound_title': 'Ses',
      'settings_language_section': 'Dil',
      'settings_audio_section': 'Ses',
      'settings_music': 'Müzik',
      'settings_music_desc': 'Quasar Orbit teması',
      'settings_music_volume': 'Müzik sesi',
      'settings_haptics': 'Titreşim',
      'settings_haptics_desc': 'Vuruş ve büyük olaylarda titreşim',
      'settings_audio_missing': 'Ses dosyası yüklenemedi.',
      'settings_display_section': 'Görünüm',
      'settings_show_own_name': 'Kendi ismim',
      'settings_show_own_name_desc': 'Karadeliğinin üzerinde ismini göster',
      'settings_show_other_names': 'Diğer isimler',
      'settings_show_other_names_desc':
          'Diğer oyuncu ve bot isimlerini göster',
      'settings_show_profile_pictures': 'Avatarlar',
      'settings_show_profile_pictures_desc':
          'Karadeliklerde profil resimlerini göster',
      'settings_match_section': 'Maç',
      'settings_show_kill_feed': 'Yutma listesi',
      'settings_show_kill_feed_desc':
          'Sol üstte kimin kimi yuttuğunu göster',
      'settings_absorb_bubble': 'Yutma yazısı',
      'settings_absorb_bubble_desc':
          'Birini yutunca karadeliğinin üstünde çıkacak cümleyi seç.',
      'settings_absorb_bubble_hint': 'örn. Yuttum!',
      'settings_absorb_bubble_save': 'Kaydet',
      'settings_absorb_bubble_clear': 'Temizle',
      'settings_support_section': 'Destek',
      'how_to_play_title': 'Nasıl Oynanır',
      'how_to_play_close': 'Anladım',
      'how_to_play_move_title': 'Hareket',
      'how_to_play_move_desc':
          'Ekranın herhangi bir yerine dokunup parmağınızı sürükleyerek kara deliğinizi yönlendirin.',
      'how_to_play_absorb_title': 'Kütlenizi Büyütün',
      'how_to_play_absorb_desc':
          'Asteroidleri, gezegenleri ve daha küçük oyuncuları yutarak büyüyün. Daha büyük kara deliklerden kaçının, yoksa yutulursunuz!',
      'how_to_play_boost_title': 'Hızlanma',
      'how_to_play_boost_desc':
          'Enerji 10 saniyede dolar. Dolunca bir kez basın: 5 saniye hızlanırsınız, kütle kaybetmezsiniz.',
      'how_to_play_link_title': 'İkili Bağ',
      'how_to_play_link_desc':
          'Başka bir oyuncuya yaklaştığınızda Bağ düğmesine basarak yerçekimsel bağ kurun ve taktik avantaj kazanın.',
      'how_to_play_shield_title': 'Kalkan',
      'how_to_play_shield_desc':
          'Kalkan güçlendirmelerini toplayarak büyük kara deliklerin yerçekiminden geçici olarak korunun.',
      'how_to_play_victory_title': 'Zafer',
      'how_to_play_victory_desc':
          'Yarıçap 500\'e ulaşınca maç biter (Eşsiz evrenlerde 550) ve evren herkes için kapanır. Normal: 1. +5, 2. +3, 3. +2 (yutulma −1). Elit: 1. +10, 2. +6, 3. +4 (yutulma −2). Eşsiz: 1. +15, 2. +10, 3. +5 (yutulma −3). Elmas 0\'ın altına inmez. Yeni oyuncular 20 Elmas ile başlar.',
      'how_to_play_ranks_title': 'Rütbe sistemi',
      'how_to_play_ranks_desc':
          'Yıldız rütben (Nebula → Tekillik) elmasa değil, galibiyet puanına göre yükselir.\n'
          'Sadece 1. olmak puan ekler. Eğitim galibiyeti sayılmaz.\n'
          '1.’lik puanı: Normal +{normal}, Elite +{elite}, Unique +{unique}.\n'
          'Eşikler: Yıldız {stellar}+ · Nova {nova}+ · Kuasar {quasar}+ · Tekillik {singularity}+.\n'
          'Galibiyet sayısı da Eğitimi saymaz. Dünya sıralaması varsayılan olarak galibiyet puanına göredir (Rütbe); Zenginlik sekmesi elmasa göre sıralar.',
      'how_to_play_currencies_title': 'Para Birimleri',
      'how_to_play_currencies_desc':
          'Yeni hesaplar 20 Elmas ile başlar. Eğitim Evreni ücretsizdir. Normal evren için en az 25 Elmas gerekir. Elmaslar Elit (100) ve Eşsiz (200) evrenleri açar.',
      'how_to_play_events_title': 'Kozmik Olaylar',
      'how_to_play_events_desc':
          'Kuasar Fırtınası, Süpernova, Meteor Yağmuru ve daha fazlasına dikkat edin — savaş alanını dramatik şekilde değiştirirler.',
      'version_notes_title': 'Yenilikler',
      'version_current': 'Güncel sürüm: {version}',
      'version_notes_close': 'Kapat',
      'version_notes_dont_show': 'Bir daha gösterme',
      'lobby_version_notes': 'v2.1',
      'v21_section_title': 'Sürüm 2.1',
      'v21_section_subtitle':
          'Galibiyet puanlı yıldız rütbeleri, daha adil Kazanılan Maç (Eğitim hariç), önce eğitim kilidi, sıralamada Galibiyetler, lobi sohbeti, gelen kutusu duyuruları ve canlı yönetici duyuruları.',
      'v21_change_rank_points':
          'Yıldız rütbeleri (Nebula → Singularity) artık galibiyet puanından geliyor — ağırlıklı 1.’likler. Varsayılan: Normal +1, Elite +2, Unique +3. Eğitim 0 verir.',
      'v21_change_training_excluded':
          'Eğitimde 1. olmak artık Kazanılan Maç veya galibiyet puanı eklemiyor — yalnızca Normal, Elite ve Unique sayılır.',
      'v21_change_tutorial_lock':
          'Yeni hesaplar diğer odaları açmadan önce Eğitim evrenini tamamlamalı (sonrasında elmas kapıları yine geçerli).',
      'v21_change_leaderboard_wins':
          'Küresel Dünya Sıralamasında Rütbe (galibiyet puanı) ve Zenginlik (elmas) sekmeleri var. Galibiyet = rekabetçi 1.’lik; Eğitim asla sayılmaz.',
      'v21_change_rank_dialog':
          'Profilde Rütbe sistemi ekranı — kademenizi, bir sonraki eşiği ve evren başına puanları görün.',
      'v21_change_lobby_chat':
          'Lobi sohbeti — lobide beklerken diğer oyuncularla gerçek zamanlı yazışın.',
      'v21_change_broadcast':
          'Genel duyuru sistemi — ekip duyuruları her oyuncunun Mesajlar gelen kutusuna düşer ve okuyana kadar kalır.',
      'v21_change_live_announce':
          'Canlı duyuru balonları — ekip kısa bir bildirim gönderince online herkes anında ekranda görür.',
      'v21_change_idle':
          'AFK / idle sistemi güncellendi — lobi ve maç uyarıları daha işlevsel, geri sayım akışı netleştirildi ve idle-kick hataları giderildi.',
      'v21_change_menus':
          'Lobi ve profil menüleri yenilendi — daha net düzen, güncel istatistik ve rütbe bilgisi, lobi aksiyonları arasında daha akıcı gezinme.',
      'v21_change_version_notes':
          'Yenilikler ekranı v2.1 için güncellendi — rütbeler, sohbet, duyurular ve adil galibiyetler üstte. Lobide bir kez çıkar; kapatana veya “bir daha gösterme”ye kadar.',
      'v20_section_title': 'Sürüm 2.0',
      'v20_section_subtitle':
          'Daha sıkı rekabetçi odalar, adil koltuk ve lobi sayıları, her maçta elmas ödülleri, paylaşılan evren olayları ve gerçek ilk 100 sıralama.',
      'v20_change_room_capacity':
          'Rekabetçi odalar artık 10 oyuncu + 10 bot — doluyken daha dolu savaşlar; yalnızken yine 20 varlıklı maç (1 + 19 bot). Eğitim 1 + 19 bot olarak kalır.',
      'v20_change_ghost_cleanup':
          'Çöken sekme veya zorla kapatmadan kalan hayalet koltuklar otomatik temizleniyor — lobi sayıları sahte dolu oda göstermiyor.',
      'v20_change_seat_free':
          'Ölünce veya çıkınca koltuğunuz boşalır; lider yarıçapı 280’nin altındayken başkası katılabilir. Yeniden doğunca oda müsaitse koltuk geri alınır.',
      'v20_change_match_rewards':
          'Elmas ödülleri her maçta yeniden çalışıyor — evren yeniden açılınca yeni maç nesli başlar; podyum ve yutulma elmasları ilk claim’den sonra kilitlenmiyor.',
      'v20_change_cosmic_sync':
          'Süpernova, meteor yağmuru ve uyarıları artık sunucu saatine bağlı — aynı evrendeki her oyuncu olayı aynı yerde ve aynı anda görür.',
      'v20_change_real_matchmaking':
          'Eşleştirme ve lobi istatistikleri yalnızca gerçek oyuncuları sayıyor — daha temiz odalar ve doğru evren sayıları.',
      'v20_change_smarter_bots':
          'Botlar yeni 10+10 doluma göre ayarlandı — farm, savaş ve kaçış daha insan gibi; yarı bot odalar da rekabetçi hissediyor.',
      'v20_change_leaderboard_100':
          'Küresel sıralama artık gerçekten ilk 100’ü elmasa göre döndürüyor — profilin vaat ettiği gibi.',
      'v20_change_unique_theme':
          'Eşsiz Evren artık kendi altın/amber temasına sahip — lobide ve maçta Normal (cyan) ile Elit (mor) evrenlerden daha net ayrılıyor.',
      'v20_change_version_notes':
          'Yenilikler ekranı v2.0 için güncellendi — rekabetçi odalar, adil koltuklar, senkron cosmic olaylar ve maç ödülleri üstte.',
      'v19_section_title': 'Sürüm 1.9',
      'v19_section_subtitle':
          'Yetenek Ağacı ilerlemesi, yükseltilebilir dört savaş yeteneği, oyuncu–yönetici mesajları, boşta oturum koruması ve sunucu taraflı daha güvenli ekonomi.',
      'v19_change_skill_tree':
          'Lobide Yetenek Ağacı — zirve elmas bakiyenizden Yetenek Puanı kazanın (her 20 zirve ♦ = 1 SP). Elmas harcanmaz; yükseltmeler hesabınıza senkronlanır.',
      'v19_change_boost_upgrades':
          'Boost dalı — azami hız, aktif süre ve şarj hızını düğüm başına 10. seviyeye kadar yükseltin; yumuşak ama hissedilir güç artışı.',
      'v19_change_teleport':
          'Işınlanma yeteneği — rastgele güvenli bir noktaya zıplayın ve kısa bir varış kalkanı alın. Yetenekler bekleme süresini kısaltır, kalkanı uzatır.',
      'v19_change_shield':
          'İsteğe bağlı Kalkan yeteneği — yerden alınan kalkanlardan ayrı, süreli yerçekimi koruması. Yetenekler bekleme süresini kısaltır, süreyi uzatır.',
      'v19_change_shockwave':
          'Şok Dalgası yeteneği — daha küçük botları ve yakındaki maddeyi savurun. Yetenekler bekleme süresi, menzil ve itme gücünü geliştirir.',
      'v19_change_messages':
          'Lobide Mesajlar kutusu — geri bildirim, öneri veya hata raporu gönderin; ekipten yanıt alın. Okunmamış rozeti dahil.',
      'v19_change_idle_protect':
          'Boşta oturum koruması — hareketsizlikten sonra “Hâlâ orada mısın?” kontrolü çıkar; oturumda kalın veya çıkış yapılır, terk edilmiş oturumlar temizlenir.',
      'v19_change_economy_security':
          'Ekonomi sunucuda güçlendirildi — elmas, galibiyet ve yetenek yükseltmeleri yalnızca güvenilir sunucu işlemleriyle değişir.',
      'v19_change_version_notes':
          'Yenilikler ekranı v1.9 için güncellendi — Yetenek Ağacı, savaş yetenekleri ve mesajlar üstte.',
      'v18_section_title': 'Sürüm 1.8',
      'v18_section_subtitle':
          'Yeni nesil karadelik grafikleri, daha uzun maç temposu, akıllı eşleştirme, sinematik yutma animasyonları ve web ile mobilde büyük performans düzeltmeleri.',
      'v18_change_blackhole_shader':
          'Karadelikler GPU\'da sıfırdan yeniden yapıldı — eğik akresyon diski, türbülanslı plazma filamentleri, beyaz-sıcak foton halkası, simsiyah olay ufku ve çift kutuplu rölativistik jetler; gerçek bilimsel görüntüler referans alındı.',
      'v18_change_swallow_visuals':
          'Yutma artık gerçek bir astrofizik olayı — av gelgit kuvvetleriyle uzuyor (spagettileşme), Roche sınırında parçalanıyor ve spiral çizerek akresyon diskine karışıyor.',
      'v18_change_merger_rework':
          'Karadelik birleşmeleri referans görsele göre yeniden tasarlandı — yörünge dansı, madde köprüsü ve nihai çöküş; oyun donmadan.',
      'v18_change_merger_ripples':
          'Birleşme kütleçekim dalgaları sadeleştirildi — daha az halka, daha kısa menzil; büyük çarpışmalarda ekran okunabilir kalıyor.',
      'v18_change_space_background':
          'Üst seviye evrenler için derin uzay arka planı yeniden inşa edildi — bulutsular, Samanyolu bandı, uzak galaksiler ve kuyruklu yıldızlarla gerçekten derin, ürkütücü bir boşluk.',
      'v18_change_web_performance':
          'Web\'deki yavaşlama giderildi — arka plan shader\'ları artık her karede yeniden oluşturulmak yerine bir kez üretilip önbelleğe alınıyor; maçlar zamanla yavaşlamıyor.',
      'v18_change_meteor_perf':
          'Meteor yağmuru olayları artık kare hızını düşürmüyor.',
      'v18_change_mobile_fixes':
          'Mobil düzeltmeler — telefonda karadeliğin çeyrek çizilmesi (Impeller) ve kurulum sonrası açılışta kapanma sorunları çözüldü.',
      'v18_change_big_hole_clarity':
          'Dev karadelikler artık net çiziliyor — büyük boyutlarda oluşan keskin "kapsayıcı daire" kenarı ve gölge üzerindeki gri pus kaldırıldı; her boyutta tam detay korunuyor.',
      'v18_change_match_pacing':
          'Maç süreleri yeniden ayarlandı — yiyecek büyümesi yavaşlatıldı; oyunlar hedefe daha yakın sürüyor: Eğitim ~1,5–2,5 dk, Normal ~4–6, Elit ~5–7, Eşsiz ~7–9.',
      'v18_change_smarter_bots':
          'Botlar artık gerçek oyuncular gibi kazanmak için oynuyor — evren hakimiyetine koşuyor, boyutuna göre lideri avlıyor ya da ondan kaçıyor, süpernovadan kaçmak ve maçı kapatmak için boost kullanıyor, büyüdükçe daha kararlı davranıyor.',
      'v18_change_supernova_events':
          'Süpernova patlamaları geri döndü ve Normal, Elit ile Eşsiz\'de ilk patlama daha erken geliyor — eğitim evreni dışında hafif bir ek zorluk.',
      'v18_change_event_warnings':
          'Olay uyarıları sadeleştirildi — yalnızca meteor yağmuru ve süpernova 5 saniye önceden haber veriyor; diğer ara uyarılar kaldırıldı.',
      'v18_change_leader_threshold':
          'Odaya katılım eşiği yarıçap 300\'den 250\'ye indirildi — lider bu boyuta ulaşınca yeni oyuncular taze bir evren örneğine yönlendirilir.',
      'v18_change_empty_close':
          'Son gerçek oyuncu çıkınca evren hemen kapanıyor; yalnızca botların kaldığı boş odalar artık çalışmaya devam etmiyor.',
      'v18_change_avatar_hud_only':
          'Profil resmi artık karadeliğin ortasında gösterilmiyor — portre yalnızca üstteki isim etiketinin yanında kalıyor.',
      'v18_change_rewarded_ads':
          'Yeniden doğma için ödüllü video reklamlar Google Mobile Ads ile entegre edildi.',
      'v18_change_version_notes':
          'Yenilikler ekranı v1.8 için güncellendi — grafik yenilemesi, maç temposu ve eşleştirme üstte.',
      'v17_section_title': 'Sürüm 1.7',
      'v17_section_subtitle':
          'Elmas ekonomisi, oyuncu profilleri, tek cihaz oturumu, canlı lobi istatistikleri ve yeni kozmos gezginleri için rehberlik.',
      'v17_change_match_rewards':
          'Maç sonuçlarına göre elmas kazanın veya kaybedin — Eşsiz evrende podyum +15/+10/+5, yutulmada evren tipine göre −1/−2/−3 ceza. Sonuçlar sunucuda kaydedilir.',
      'v17_change_diamond_gates':
          'Yeni hesaplar 20 elmasla başlar. Eğitim ücretsiz; Normal 25, Elit 100, Eşsiz 200 elmas ister. Lobi kartları giriş, ödül ve ceza tablolarını gösterir.',
      'v17_change_profile_hub':
          'Lobide avatara dokunarak 3 sekmeli profil menüsünü açın: İstatistikler, Görünümler ve Mağaza. Galibiyet, global sıra ve canlı profil senkronu.',
      'v17_change_edit_profile':
          '3–12 karakter görünen adınızı değiştirin ve galeriden profil fotoğrafı yükleyin (en fazla 5 MB). Avatarlar Supabase Storage\'da saklanır.',
      'v17_change_ingame_avatars':
          'Yüklediğiniz avatar maçta kara deliğinizin içinde görünür. Ayarlar → Profil Fotoğrafları ile açıp kapatabilirsiniz.',
      'v17_change_cosmetic_store':
          'Mağazada altın harcayarak efsanevi akresyon diski görünümlerini açın. Profil menüsünden kuşanın — aktif görünüm maçta uygulanır.',
      'v17_change_global_leaderboard':
          'Profilden dünya genelinde elmasa göre ilk 100 oyuncuyu görün. İlk 100 dışındaysanız kendi sıranızı da görürsünüz.',
      'v17_change_single_session':
          'Her hesap aynı anda yalnızca bir aktif maçta olabilir. Başka cihazda çıkana kadar "Oyuncu Zaten Aktif" uyarısı gösterilir.',
      'v17_change_live_lobby_stats':
          'Lobi evren kartları anlık sayıları gösterir: aktif evren, oyuncu ve bot — Supabase Realtime ile güncellenir.',
      'v17_change_onboarding':
          'Yeni oyuncular önce Eğitim Evrenini tamamlamalı. İlk maçta zamanlı ipuçları gösterilir.',
      'v17_change_native_splash':
          'Uygulama açılışında markalı splash ekranı anında görünür; dil, kimlik doğrulama ve ayarlar arka planda yüklenir.',
      'v17_change_hud_podium_rewards':
          'Maç içi liderlik podyumu artık 1., 2. ve 3. sıra için elmas ödüllerini ve rakip rütbe kademelerini gösterir.',
      'v17_change_swallow_vfx':
          'Av görselleri güçlendirildi — kara delikler arası gelgit köprüsü artık sıcak filamentler ve ufuk kıvılcımlarıyla katmanlı Flame parçacık efekti.',
      'v17_change_victory_fix':
          'Maçlar yarıçap 500\'e (Eşsiz\'de 550) ulaştığı anda biter — ekranda tam sayı görünmemesi nedeniyle donma sorunu giderildi.',
      'v17_change_login_fix':
          'Google girişinden sonra kısa süreli "not authenticated" hatası giderildi. Oturum kontrolü JWT otururken yeniden dener.',
      'v17_change_hud_loading':
          'Maç HUD\'u ve liderlik tablosu daha erken görünür — maç başındaki siyah yükleme ekranı kısalır.',
      'v17_change_version_notes':
          'Yenilikler ekranı v1.7 için yenilendi — elmas ekonomisi, profiller ve oturum yönetimi üstte.',
      'v16_section_title': 'Sürüm 1.6',
      'v16_section_subtitle':
          'Teleskop ilhamlı kara delikler, sunucu tarafı evren eşleştirmesi, akıllı oda bölünmesi ve adil rastgele doğumlar.',
      'v16_change_server_matchmaking':
          'Normal, Elit ve Eşsiz evrenler artık sunucu tarafında otomatik odaya atanıyor — lobiden girince doğru evrene yerleşiyorsunuz.',
      'v16_change_universe_instances':
          'HUD\'da hangi evrende olduğunuz görünüyor: Normal Evren 1, Elit Evren 2 gibi numaralı sunucu örnekleri.',
      'v16_change_leader_radius_split':
          'Odadaki lider yarıçapı 300\'e ulaştığında veya oda doluyken yeni oyuncular bir sonraki evren örneğine yönlendiriliyor.',
      'v16_change_room_lifecycle':
          'Maç bitince evren kapanıyor; çökme veya ani çıkış sonrası hayalet üyeler temizleniyor — boş Evren 1 atlanmıyor.',
      'v16_change_abandoned_universe':
          'Tüm gerçek oyuncular yutulduğunda veya çıktığında evren otomatik kapanıyor; sadece botlar kalsa bile oda sonlanıyor.',
      'v16_change_black_hole_graphics':
          'Kara delikler yeniden tasarlandı — kütleyle büyüyen yerçekimsel gölge, parlak foton halkası ve eğik akresyon diski.',
      'v16_change_star_lensing':
          'Arka plandaki yıldızlar gölgenizde bükülüyor, parlayıp kayboluyor — evrende yerçekimsel merceklenme.',
      'v16_change_swallow_animations':
          'Yeni av görselleri: delikler arası gelgit madde akışları, foton halkasında yakalama patlamaları ve kapanırken av kıvılcımları.',
      'v16_change_food_spaghettify':
          'Asteroitler ve gezegenler yalnızca gerçekten yakalama menzilindeyken şeritlere uzanıyor — daha fiziksel bir infall.',
      'v16_change_gravity_physics':
          'Newton tipi ters kare yerçekimi ve foton halkası yakalama mesafesi — kütle ve çekim daha fiziksel hissediliyor.',
      'v16_change_universe_tiers':
          'Dört evren katmanı farklı oynanıyor — eğitim kum havuzu, normal, elit ve eşsiz odalar kendi temposu ve riskiyle.',
      'v16_change_cosmic_events':
          'Süpernova, meteor yağmuru ve kuasar fırtınaları maç ortasında savaş alanını yeniden şekillendiriyor.',
      'v16_change_hole_merger':
          'İki baskın kara delik galaktik birleşme tetikleyebilir — ekran sarsıntısı, uzay dokusu yırtılması ve birleşik kütle.',
      'v16_change_random_spawn':
          'Oyuncular ve botlar artık evrenin içinde rastgele bir noktada doğuyor — herkesin merkezden başlaması kaldırıldı.',
      'v16_change_revive_spawn':
          'Yeniden doğma da sizi rastgele güvenli bir noktaya alır; diğer oyuncu ve botlardan uzak tutulur.',
      'v16_change_prey_bot_spawn':
          'Basit odadaki av botları artık ekranınızın yakınında değil — diğerleri gibi haritanın rastgele bir yerinde doğuyor.',
      'v16_change_spawn_spacing':
          'Doğum noktaları diğer oyuncu ve botlardan minimum mesafe bırakır; üst üste binme azalır.',
      'v16_change_version_notes':
          'Yenilikler ekranı v1.6 için yenilendi — sunucu eşleştirmesi ve evren yaşam döngüsü dahil tüm güncellemeler üstte.',
      'v15_section_title': 'Sürüm 1.5',
      'v15_section_subtitle':
          'Daha adil botlar, rütbe rozetleri, başlangıç koruması ve yeniden tasarlanan hız sistemiyle büyük bir güncelleme.',
      'v15_change_match_end':
          'Biri kazandığında maç herkes için durur — kazanan, süre gösterilir ve otomatik lobiye dönülür.',
      'v15_change_bot_victory':
          'Botlar 500 kütlede evreni fethederek kazanabilir. Yutulduktan sonra botlar zafer için oynamaya devam eder.',
      'v15_change_rank_system':
          'Elmas sayısına göre rütbe rozetleri (I–V) artık oyuncu isimlerinin başında — oyunda, skor tablosunda ve maç sonuçlarında.',
      'v15_change_spawn_shield':
          'Evrene girişte 3 saniyelik başlangıç koruma kalkanı — ekranda geri sayım ve tam dokunulmazlık.',
      'v15_change_boost':
          'Hız sistemi yenilendi: enerji 10 sn\'de dolar, dolunca bir kez basarak 5 sn hızlanırsınız — kütle kaybı yok.',
      'v15_change_spectator':
          'İzleme moduna ekranın altında İzlemeyi Bırak butonu eklendi.',
      'v15_change_bot_badge':
          'Bot rozeti hızlı tanıma için ismin başına taşındı.',
      'v15_change_global_rank':
          'Dünya sıralamasında da rütbe rozetleri gösteriliyor.',
      'v15_change_audio':
          'Yalnızca resmi Quasar Orbit teması çalıyor — döngüsel ambient müzik, diğer tüm sesler kaldırıldı.',
      'v15_change_bot_fixes':
          'Botlar artık ~140 kütlede takılmıyor ve 500\'de maçı doğru şekilde bitiriyor.',
      'lobby_chat_title': 'Lobi sohbeti',
      'lobby_chat_hint': 'Selam yaz…',
      'lobby_chat_empty': 'Henüz mesaj yok',
      'match_chat_hint': 'Kısa mesaj…',
      'match_react_gg': 'GG',
      'match_react_nice': 'Güzel',
      'match_react_run': 'Kaç!',
      'match_react_help': 'Yardım',
      'match_react_lol': 'Lol',
      'match_react_wow': 'Vay',
      'match_absorb_flex': 'Yuttum!',
      'match_absorb_bye': 'Güle güle',
      'match_absorb_small': 'Çok küçüktün',
      'match_absorb_yummy': 'Afiyet olsun',
      'match_absorb_gone': 'Yok oldu.',
      'match_absorb_mine': 'Benim.',
      'match_absorb_void': 'Boşluğa.',
      'match_absorb_next': 'Sıradaki!',
      'match_absorb_crushed': 'Ezildin.',
      'match_absorb_random': 'Rastgele',
    },
    'de': {
      'app_title': 'Quasar.io',
      'sign_in_google': 'Mit Google anmelden',
      'signing_in': 'Anmeldung läuft...',
      'sign_out': 'Abmelden',
      'admin_badge': 'OWNER',
      'admin_title': 'Admin-Panel',
      'admin_subtitle': 'Live-Übersicht zu Universen, Spielern und Bots',
      'admin_refresh': 'Aktualisieren',
      'admin_enter_lobby': 'Zur Lobby',
      'admin_open_panel': 'Kontrollpanel',
      'admin_total_players': 'Live-Spieler',
      'admin_total_bots': 'Live-Bots',
      'admin_total_universes': 'Aktive Universen',
      'admin_active_sessions': 'Aktive Sitzungen',
      'admin_universes_section': 'Universen & Schwierigkeit',
      'admin_players_section': 'Spieler- & Bot-Statistiken',
      'admin_difficulty': 'Schwierigkeit',
      'admin_difficulty_relaxed': 'Entspannt',
      'admin_difficulty_standard': 'Standard',
      'admin_difficulty_elite': 'Elite',
      'admin_difficulty_unique': 'Einzigartig',
      'admin_hunt_priority': 'Bot-Schwierigkeit: {pct}%',
      'admin_hunt_priority_short': 'Bots',
      'admin_hunt_priority_howto':
          'Bot-Schwierigkeit (0–100%) steuert, wie aggressiv Bots Spieler jagen statt zu farmen. Höher = weniger Flucht, ruhigeres Zielen, höhere Beute-Scores, früherer Boost. Beim ersten Match gilt ×0.85.',
      'admin_hunt_priority_formula':
          'Beute-Score ≈ Größenvorteil × Schwierigkeit / (1 + Distanz/Radius). Standard dieser Stufe: {default}%. Schieberegler ändern; neue Matches nutzen den gespeicherten Wert.',
      'admin_hunt_priority_reset': 'Bot-Schwierigkeit zurücksetzen',
      'admin_room_tuning_howto':
          'Universum wählen, dann nach Kategorie einstellen. Gilt nur für neue Matches.',
      'admin_room_tuning_reset': 'Alle Universum-Einstellungen zurücksetzen',
      'admin_room_tuning_reset_one': 'Dieses Universum zurücksetzen',
      'admin_tune_saving': 'Speichern…',
      'admin_tune_default': 'Standard {value}',
      'admin_tune_tab_world': 'Welt',
      'admin_tune_tab_tempo': 'Tempo',
      'admin_tune_tab_objects': 'Objekte',
      'admin_tune_tab_events': 'Events',
      'admin_tune_tab_radiation': 'Strahlung',
      'admin_tune_tab_bots': 'Bots',
      'admin_tune_tab_live': 'Live',
      'admin_live_instances': 'Live-Instanzen',
      'admin_tune_world': 'Welt & Radien',
      'admin_tune_world_hint':
          'Matchdauer und Siegtempo: größere Welt / höherer Sieg-Radius = längere Matches.',
      'admin_tune_gravity': 'Nahrungs-Anziehung',
      'admin_tune_tempo_hint':
          'Zielminuten leiten die Balance. Früher Boost hilft neuen Spielern; niedriger Respawn = dichtere Nahrung.',
      'admin_tune_target_min': 'Ziel-Matchdauer (min)',
      'admin_tune_target_max': 'Ziel-Matchdauer (max)',
      'admin_tune_early_duration': 'Early-Game-Dauer',
      'admin_tune_early_growth': 'Früher Spieler-Wachstumsboost',
      'admin_tune_respawn_delay': 'Nahrungs-Respawn-Faktor',
      'admin_tune_objects': 'Verschluckbare Objekte',
      'admin_tune_objects_hint': 'Anzahl 0 = Objekttyp entfernen.',
      'admin_tune_events': 'Kosmische Events',
      'admin_tune_events_short': 'Events',
      'admin_tune_events_enabled': 'Supernova & Meteorschauer',
      'admin_tune_events_enabled_hint': 'Aus = keine Supernova/Meteor.',
      'admin_tune_radiation_hint':
          'Anti-Camp-Druck. Höherer Radius / kürzerer Idle = härtere Strafe. Late-Game-Shrink zieht das Ende zu.',
      'admin_tune_radiation_radius': 'Strahlungs-Start-Radius',
      'admin_tune_radiation_idle': 'Strahlungs-Idle-Zeit',
      'admin_tune_late_radiation_radius': 'Late-Game-Strahlungsradius',
      'admin_tune_late_radiation_idle': 'Late-Game-Idle-Zeit',
      'admin_tune_late_radiation_shrink': 'Late-Game-Schrumpfgeschwindigkeit',
      'admin_tune_bots': 'Bots',
      'admin_tune_bots_human_intro':
          'Wettkampf-Räume füllen mit 10 Spielern + 10 Bots. Presets lassen Bots farmen, kämpfen und fliehen wie echte Spieler.',
      'admin_tune_universe_presets': 'Universums-Schwierigkeit',
      'admin_tune_universe_presets_hint':
          'Leiter aus den Defaults dieses Universums — Nahrung, Tempo, Events, Strahlung und Bots zusammen. Ranked = Compile-Balance.',
      'admin_tune_universe_preset_training': 'Training',
      'admin_tune_universe_preset_casual': 'Casual',
      'admin_tune_universe_preset_ranked': 'Ranked',
      'admin_tune_universe_preset_predator': 'Predator',
      'admin_tune_universe_preset_apex': 'Apex',
      'admin_tune_universe_balanced_distribute': 'Ausgewogene Leiter auf alle',
      'admin_tune_universe_balanced_distribute_hint':
          'Simple→Training · Normal→Ranked · Elite→Predator · Unique→Apex',
      'admin_tune_bot_presets': 'Bot-Schwierigkeit',
      'admin_tune_bot_presets_hint':
          'Fünf Stufen. Ranked ist die Wettbewerbs-Basis. Der aktive Chip zeigt das aktuelle Profil.',
      'admin_tune_bot_preset_training': 'Training',
      'admin_tune_bot_preset_casual': 'Casual',
      'admin_tune_bot_preset_ranked': 'Ranked',
      'admin_tune_bot_preset_predator': 'Predator',
      'admin_tune_bot_preset_apex': 'Apex',
      'admin_tune_bot_preset_soft': 'Training',
      'admin_tune_bot_preset_human': 'Ranked',
      'admin_tune_bot_preset_aggressive': 'Apex',
      'admin_tune_bot_ai': 'KI-Verhalten',
      'admin_tune_bot_ai_hint':
          'Niedrigere Entscheidungsintervalle = schnellere (menschlichere) Reaktionen. Beute-Ratio ~0.92–0.95. Spieler-Bias ~1.1–1.3 halten.',
      'admin_tune_decision_min': 'Entscheidungsintervall (min)',
      'admin_tune_decision_max': 'Entscheidungsintervall (max)',
      'admin_tune_prey_ratio': 'Beute-Größenverhältnis',
      'admin_tune_threat_ratio': 'Bedrohungs-Verhältnis (Flucht)',
      'admin_tune_prey_search': 'Beute-Suchreichweite',
      'admin_tune_food_search': 'Nahrungs-Suchreichweite',
      'admin_tune_event_awareness': 'Event-Bewusstsein',
      'admin_tune_mine_avoidance': 'Minen-Vermeidung',
      'admin_tune_min_hunt_radius': 'Min. Radius vor Jagd',
      'admin_tune_player_bias': 'Spieler-Ziel-Bias',
      'admin_tune_intercept_prey': 'Bewegte Beute abfangen',
      'admin_tune_personality': 'Persönlichkeitsmix',
      'admin_tune_personality_hint':
          'Relative Gewichte der Bot-Persönlichkeiten. Summe muss nicht 100 sein.',
      'admin_tune_personality_coward': 'Feigling',
      'admin_tune_personality_aggressive': 'Aggressiv',
      'admin_tune_personality_opportunist': 'Opportunist',
      'admin_tune_on': 'An',
      'admin_tune_off': 'Aus',
      'admin_tune_victory_radius': 'Sieg-Radius',
      'admin_tune_player_start_radius': 'Spieler-Start-Radius',
      'admin_tune_world_size': 'Weltgröße',
      'admin_tune_food_growth': 'Nahrungs-Wachstumsfaktor',
      'admin_tune_asteroids': 'Kleine/mittlere Asteroiden',
      'admin_tune_meteorites': 'Meteoriten',
      'admin_tune_planets': 'Planeten',
      'admin_tune_quasar_fragments': 'Quasar-Fragmente',
      'admin_tune_large_asteroids': 'Große Asteroiden',
      'admin_tune_xlarge_asteroids': 'Sehr große Asteroiden',
      'admin_tune_giant_asteroids': 'Riesenasteroiden',
      'admin_tune_mines': 'Minen',
      'admin_tune_supernova_interval': 'Supernova-Intervall',
      'admin_tune_supernova_first': 'Erste Supernova-Verzögerung',
      'admin_tune_meteor_cooldown': 'Erste Meteor-Verzögerung',
      'admin_tune_event_growth_cap': 'Max. Wachstum pro Event',
      'admin_tune_supernova_planets': 'Supernova-Planeten',
      'admin_tune_bot_start_min': 'Bot-Start-Radius (min)',
      'admin_tune_bot_start_max': 'Bot-Start-Radius (max)',
      'admin_no_active_universes': 'Derzeit keine aktiven Universen',
      'admin_registered_players': 'Registrierte Spieler',
      'admin_total_games_won': 'Siege gesamt',
      'admin_live_entities': 'Live-Spieler + Bots',
      'admin_bot_share': 'Bot-Anteil live',
      'admin_top_winners': 'Top-Gewinner',
      'admin_no_players_yet': 'Noch keine registrierten Spieler',
      'admin_last_updated': 'Aktualisiert {time}',
      'select_language': 'Sprache',
      'welcome_cosmic': 'Überschreite den Ereignishorizont',
      'login_atmosphere':
          'Absorbiere Materie. Besiege Rivalen. Beherrsche die Tiefraum-Arena.',
      'lobby_brand_eyebrow': 'Tiefraum-Arena',
      'lobby_choose_universe': 'Wähle dein Universum',
      'store_tab_skins': 'Skins',
      'store_tab_trails': 'Spuren',
      'store_tab_emotes': 'Emotes',
      'store_buy': 'Kaufen',
      'store_equip': 'Ausrüsten',
      'store_owned': 'Besessen',
      'store_insufficient_gold': 'Nicht genug Gold',
      'event_quasar_storm': 'Quasar-Sturm!',
      'event_supernova': 'Supernova-Ausbruch!',
      'event_supernova_warning': 'Warnung: Supernova in {s}s!',
      'event_meteor_shower': 'Meteorschauer!',
      'event_meteor_warning': 'Warnung: Meteorschauer in {s}s!',
      'event_black_hole_merge': 'Schwarzes-Loch-Verschmelzung!',
      'merge_stage_tidal': 'Gezeitenverformung & Massentransfer!',
      'merge_stage_dance': 'Der Tanz — gewaltige Gravitationswellen!',
      'merge_stage_ringdown': 'Verschmelzung & Ringdown — ein Quasar!',
      'event_cosmic_mine': 'Kosmische Minen-Detonation!',
      'event_cosmic_dust_welcome': 'Kosmischer Staubregen — gratis Wachstum!',
      'first_match_hint_move':
          'Ziehe irgendwo, um dein schwarzes Loch zu steuern',
      'first_match_hint_absorb':
          'Absorbiere Asteroiden und kleinere Löcher zum Wachsen',
      'first_match_hint_grow':
          'Wachse schnell — Startschild ist noch aktiv!',
      'lobby_recommended_room': 'EMPFOHLEN',
      'spawn_protection_label': 'Start-Schutzschild',
      'game_over_title': 'Ereignishorizont-Kollaps',
      'game_over_subtitle': 'Deine Masse wurde von einer größeren Leere verschlungen',
      'game_over_watch_ad_revive': 'Werbung ansehen & wiederbeleben',
      'game_over_quit': 'Beenden',
      'game_over_watch_match': 'Zuschauen',
      'spectator_stop_watching': 'Zuschauen beenden',
      'game_over_peak_mass': 'Spitzenmasse',
      'game_over_diamond_penalty':
          '−{diamonds} Diamant beim Verlassen (nie unter 0)',
      'game_over_play_again': 'Nochmal spielen',
      'game_over_return_lobby': 'Zur Lobby',
      'match_quit_confirm_title': 'Spiel verlassen?',
      'match_quit_confirm_message':
          'Möchtest du wirklich aussteigen? Du verlierst {diamonds} Diamant(en).',
      'match_quit_confirm_stay': 'Bleiben',
      'match_quit_confirm_leave': 'Verlassen',
      'leaderboard_title': 'RANGLISTE',
      'hud_population_players': 'Spieler',
      'hud_population_bots': 'Bots',
      'leaderboard_you': 'Du',
      'leaderboard_name': 'Name',
      'leaderboard_mass': 'Masse',
      'victory_title': 'Du hast das Universum erobert!',
      'victory_subtitle': 'Der Kosmos beugt sich vor deiner Schwerkraft',
      'victory_time': 'Siegzeit: {time}',
      'victory_reward': '+{diamonds} Diamanten · +1 Sieg',
      'victory_return_lobby': 'Triumphierend zur Lobby',
      'reward_double_cta': 'Belohnung verdoppeln',
      'reward_double_micro': '+{extra} extra Diamanten (gesamt {total})',
      'reward_double_done': '2× erhalten · +{total} Diamanten',
      'reward_double_loading': 'Werbung wird geladen…',
      'reward_double_claiming': 'Bonus wird gutgeschrieben…',
      'reward_double_claim_wait': 'Belohnung wird gespeichert… gleich erneut versuchen',
      'reward_double_ad_failed': 'Keine Werbung. Basisbelohnung ist sicher.',
      'reward_double_grant_failed': 'Bonus ausstehend — tippen zum erneuten Versuch',
      'reward_double_retry_grant': 'Bonus abholen',
      'reward_double_unavailable': 'Werbung auf diesem Gerät nicht verfügbar',
      'frozen_title': 'Universum erobert',
      'frozen_champion': '{name} hat das Universum in {time} erobert',
      'match_champion_result': '{name} hat das Match in {time} gewonnen',
      'frozen_placement_reward': 'Platz #{place}: +{diamonds} Diamanten',
      'frozen_room_closed': 'Das Universum wurde geschlossen.',
      'match_returning_lobby': 'Zurück zur Lobby in {seconds} s…',
      'lobby_diamonds': 'Diamanten',
      'rank_tier_nebula': 'Nebel',
      'rank_tier_stellar': 'Stellar',
      'rank_tier_nova': 'Nova',
      'rank_tier_quasar': 'Quasar',
      'rank_tier_singularity': 'Singularität',
      'lobby_gold': 'Gold',
      'lobby_play': 'Spielen',
      'lobby_stat_universes': '{count} Universen',
      'lobby_stat_players': '{count} Spieler',
      'lobby_stat_bots': '{count} Bots',
      'lobby_stat_universes_short': 'Universen',
      'lobby_stat_players_short': 'Spieler',
      'lobby_stat_bots_short': 'Bots',
      'lobby_room_fill_hint':
          'Jedes offene Universum: max. 10 echte Spieler, mit Bots auf 20 aufgefüllt.',
      'lobby_low_population_hint':
          'Wenige echte Spieler online — Bots füllen den Rest des Matches.',
      'lobby_stat_solo_players': 'Solo',
      'room_entry_free': 'Eintritt: Kostenlos',
      'room_entry_cost': 'Du brauchst mindestens {count}',
      'room_entry_cost_prefix': 'Du brauchst mindestens {count} ',
      'room_entry_cost_suffix': '',
      'room_rewards_label': 'Belohnungen',
      'room_elimination_label': 'Elimination',
      'room_elimination_none': 'kein Verlust',
      'room_simple_title': 'Tutorial-Universum',
      'lobby_first_login_lock': 'Schließe zuerst das Tutorial ab',
      'room_instance_normal': 'Normales Universum {number}',
      'room_instance_elite': 'Elite-Universum {number}',
      'room_instance_unique': 'Einzigartiges Universum {number}',
      'matchmaking_error': 'Raumbeitritt fehlgeschlagen. Bitte erneut versuchen.',
      'player_already_active_title': 'Spieler bereits aktiv',
      'player_already_active_message':
          'Dieses Konto ist bereits auf einem anderen Gerät im Spiel. Beende zuerst dieses Match.',
      'player_already_active_ok': 'OK',
      'idle_session_title': 'Noch da?',
      'idle_session_message':
          'Keine Aktivität. Abmeldung in {seconds} Sekunden.',
      'idle_session_stay': 'Angemeldet bleiben',
      'idle_match_result_title': 'Zurück zur Lobby',
      'idle_match_result_message':
          'Keine Aktion auf dem Ergebnisbildschirm. Rückkehr zur Lobby in {seconds} Sekunden.',
      'idle_match_result_stay': 'Auf diesem Bildschirm bleiben',
      'idle_match_result_hint':
          'Nach 10 Sekunden Untätigkeit startet ein 10-Sekunden-Countdown und du kehrst zur Lobby zurück.',
      'room_simple_desc':
          'Eintritt: Kostenlos · Nur-Bot-Tutorial\nBelohnungen +3 · +2 · +1 · Keine Elimination · große Asteroiden',
      'room_normal_title': 'Normale Universen',
      'room_normal_desc':
          'Du brauchst mindestens 25\nBelohnungen +5 · +3 · +2 · Elimination -1',
      'room_elite_title': 'Elite-Universen',
      'room_elite_desc':
          'Du brauchst mindestens 100\nBelohnungen +10 · +6 · +4 · Elimination -2',
      'room_unique_title': 'Einzigartige Universen',
      'room_unique_desc':
          'Du brauchst mindestens 200\nBelohnungen +15 · +10 · +5 · Elimination -3',
      'room_requires_100': 'Du brauchst mindestens 100',
      'room_requires_300': 'Du brauchst mindestens 200',
      'room_requires_diamonds': 'Du brauchst mindestens {count}',
      'profile_stats_tab': 'Statistiken',
      'profile_store_tab': 'Shop',
      'feature_coming_soon_badge': 'Demnächst',
      'feature_coming_soon_title': 'Im Aufbau',
      'feature_coming_soon_body':
          'Dieser Bereich entsteht im tiefen Weltraum. Skins und Shop öffnen bald.',
      'profile_games_won': 'Gewonnene Spiele',
      'profile_global_rank': 'Globale Weltrangliste',
      'profile_rank_system': 'Rangsystem',
      'rank_system_intro':
          'Sterne neben Namen zeigen deinen Rang. Rang kommt von Sieg-Punkten (gewichtete 1. Plätze) — nicht von Diamanten.',
      'rank_system_your_rank': 'DEIN RANG',
      'rank_system_your_points': '{points} Sieg-Punkte',
      'rank_system_next': 'Nächster: {tier} ab {points}+',
      'rank_system_ladder_title': 'STERNENLEITER',
      'rank_system_current_badge': 'Du bist hier',
      'rank_system_earn_title': 'PUNKTE PRO 1. PLATZ',
      'rank_system_points_per_win': '+{n}',
      'rank_system_points_none': 'Zählt nicht',
      'rank_system_note':
          'Nur 1. Platz in Normal / Elite / Unique gibt Sieg-Punkte und Siege. Training zählt nicht. Rang sortiert nach Sieg-Punkten; Reichtum nach Diamanten.',
      'rank_system_close': 'Verstanden',
      'global_rank_player': 'Spieler',
      'global_rank_wins': 'Siege',
      'global_rank_points': 'Pkt',
      'global_rank_tab_rank': 'Rang',
      'global_rank_tab_wealth': 'Reichtum',
      'global_rank_blurb':
          'Rang: Sieg-Punkte. Reichtum: Diamanten. Siege = kompetitive 1. Plätze (ohne Training).',
      'global_rank_blurb_rank':
          'Sortiert nach Sieg-Punkten (dann Siege). Nur 1. Platz in Normal / Elite / Unique zählt — Training nie.',
      'global_rank_blurb_wealth':
          'Sortiert nach Diamanten (dann Siege). Sterne neben dem Namen zeigen weiterhin deinen Rang aus Sieg-Punkten.',
      'global_rank_your_position': 'DEINE POSITION',
      'global_rank_empty': 'Noch keine Rangliste.',
      'global_rank_error': 'Rangliste konnte nicht geladen werden.',
      'global_rank_retry': 'Erneut versuchen',
      'profile_legendary_skins': 'Legendäre Skins',
      'skin_default': 'Solarflare',
      'skin_frost': 'Frostschleier',
      'skin_ember': 'Glutkern',
      'skin_pulsar': 'Blauer Pulsar',
      'skin_nebula': 'Lila Nebel',
      'skin_plasma': 'RGB-Plasma',
      'skin_void': 'Dunkle Leere',
      'skin_quasar': 'Grüner Quasar',
      'skin_eclipse': 'Sonnenfinsternis',
      'skin_supernova': 'Rote Supernova',
      'skin_aurora': 'Polarlicht',
      'skin_binary': 'Doppelstern',
      'skin_singularity': 'Singularität Prime',
      'skin_celestial': 'Himmlische Krone',
      'skin_picker_title': 'Schwarze-Loch-Skins',
      'skin_picker_subtitle': 'Wähle dein Akkretionsscheiben-Design',
      'skin_picker_equipped': 'Ausgerüstet',
      'skin_picker_locked': 'Gesperrt',
      'skin_picker_free': 'Kostenlos',
      'trail_comet': 'Plasmastrahl',
      'trail_nebula': 'Linseneffekt',
      'trail_quantum': 'Gravitationswelle',
      'trail_picker_section': 'Bewegungsspuren',
      'trail_picker_subtitle': 'Tippe auf eine Spur, um sie auszurüsten',
      'trail_picker_empty':
          'Erwerbe Spuren im Shop, um sie hier auszurüsten.',
      'trail_picker_owned': 'Besessen',
      'store_trail_equip_hint': 'Rüste diese Spur im Erscheinungsbild-Tab aus.',
      'store_trail_claim_success':
          'Spur freigeschaltet! Rüste sie im Erscheinungsbild-Tab aus.',
      'emote_wave': 'Kosmische Welle',
      'emote_burst': 'Supernova-Ausbruch',
      'emote_void': 'Leeren-Lachen',
      'store_purchase_success': 'Kauf erfolgreich!',
      'store_equip_success': 'Ausgerüstet!',
      'store_error': 'Etwas ist schiefgelaufen',
      'error_generic': 'Etwas ist schiefgelaufen. Bitte erneut versuchen.',
      'sign_in_error': 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.',
      'profile_edit': 'Profil bearbeiten',
      'profile_edit_name': 'Anzeigename',
      'profile_edit_avatar': 'Tippen zum Foto ändern',
      'profile_edit_save': 'Speichern',
      'profile_edit_cancel': 'Abbrechen',
      'profile_username_taken': 'Dieser Name ist bereits vergeben',
      'profile_username_invalid':
          'Name muss 3–12 Zeichen haben (Buchstaben, Zahlen, Leerzeichen)',
      'profile_update_success': 'Profil aktualisiert!',
      'profile_update_error': 'Profil konnte nicht aktualisiert werden',
      'lobby_how_to_play': 'Überleben',
      'lobby_skill_tree': 'Kraftmatrix',
      'lobby_version_notes_hint': 'Sendungsprotokoll',
      'skill_tree_title': 'Fähigkeitsbaum',
      'skill_sp_available': 'Verfügbare SP',
      'skill_sp_earned': 'Ausgegeben / Verdient',
      'skill_sp_rules':
          'Alle {n} Peak-Diamanten freischalten 1 SP. Diamanten werden nicht ausgegeben. Nächster SP in {next} ♦.',
      'skill_branch_boost': 'Boost',
      'skill_branch_teleport': 'Teleport',
      'skill_branch_shield': 'Schild',
      'skill_branch_shockwave': 'Schockwelle',
      'skill_level': 'Lv',
      'skill_upgrade': '+1 SP',
      'skill_maxed': 'MAX',
      'skill_value_now': 'Jetzt',
      'skill_error_no_sp': 'Keine Fähigkeitspunkte verfügbar',
      'skill_error_max': 'Diese Fähigkeit ist bereits maximal',
      'skill_error_generic': 'Fähigkeit konnte nicht verbessert werden',
      'skill_node_boost_speed': 'Boost-Geschwindigkeit',
      'skill_node_boost_speed_desc': 'Höhere Höchstgeschwindigkeit beim Boost',
      'skill_node_boost_duration': 'Boost-Dauer',
      'skill_node_boost_duration_desc': 'Boost bleibt länger aktiv',
      'skill_node_boost_charge': 'Boost-Aufladung',
      'skill_node_boost_charge_desc': 'Schnellere Aufladung zwischen Boosts',
      'skill_node_teleport_cd': 'Teleport-Abklingzeit',
      'skill_node_teleport_cd_desc': 'Kürzere Wartezeit zwischen Teleports',
      'skill_node_teleport_shield': 'Ankunftsschild',
      'skill_node_teleport_shield_desc': 'Längerer Schutz nach dem Teleport',
      'skill_node_shield_cd': 'Schild-Abklingzeit',
      'skill_node_shield_cd_desc': 'Kürzere Wartezeit zwischen Schilden',
      'skill_node_shield_duration': 'Schilddauer',
      'skill_node_shield_duration_desc': 'Aktives Schild hält länger',
      'skill_node_shockwave_cd': 'Schockwellen-Abklingzeit',
      'skill_node_shockwave_cd_desc': 'Kürzere Wartezeit zwischen Schockwellen',
      'skill_node_shockwave_range': 'Schockwellen-Reichweite',
      'skill_node_shockwave_range_desc': 'Stößt Gegner aus größerer Distanz',
      'skill_node_shockwave_power': 'Schockwellen-Stärke',
      'skill_node_shockwave_power_desc':
          'Stärkerer Stoß auf kleinere Löcher & Materie',
      'settings_title': 'Einstellungen',
      'settings_sound_title': 'Ton',
      'settings_music': 'Quasar Orbit Theme',
      'settings_music_desc': 'Offizielle Quasar.io-Themenmusik',
      'settings_music_volume': 'Musiklautstärke',
      'settings_haptics': 'Vibration',
      'settings_haptics_desc': 'Haptisches Feedback bei Kollisionen und Ereignissen',
      'settings_audio_missing': 'Audiodatei konnte nicht geladen werden.',
      'settings_display_section': 'Anzeige',
      'settings_show_own_name': 'Mein Name',
      'settings_show_own_name_desc': 'Zeige deinen Namen über deinem Schwarzen Loch',
      'settings_show_other_names': 'Andere Namen',
      'settings_show_other_names_desc':
          'Zeige Namen anderer Spieler und Bots über Schwarzen Löchern',
      'settings_show_profile_pictures': 'Profilbilder',
      'settings_show_profile_pictures_desc':
          'Zeige Profilbilder in Schwarzen Löchern',
      'settings_support_section': 'Support',
      'admin_nav_messages': 'Nachrichten',
      'admin_page_messages_title': 'Nachrichten',
      'admin_page_messages_desc':
          'Feedback lesen, einzeln antworten oder an alle senden.',
      'msg_player_title': 'Nachrichten',
      'msg_tab_inbox': 'Posteingang',
      'msg_tab_compose': 'Schreiben',
      'msg_open_inbox': 'Posteingang',
      'msg_write_to_admin': 'An Admin schreiben',
      'msg_category_feedback': 'Feedback',
      'msg_category_suggestion': 'Vorschlag',
      'msg_category_bug': 'Fehler',
      'msg_category_direct': 'Direkt',
      'msg_category_broadcast': 'Broadcast',
      'msg_filter_open': 'Offen',
      'msg_filter_closed': 'Geschlossen',
      'msg_filter_all': 'Alle',
      'msg_filter_category_all': 'Alle Typen',
      'msg_broadcast': 'Broadcast',
      'msg_send_direct': 'Spieler schreiben',
      'msg_search_player': 'Spieler suchen…',
      'msg_to_player': 'An: {name}',
      'msg_subject_hint': 'Betreff',
      'msg_body_hint': 'Nachricht schreiben…',
      'msg_reply_hint': 'Antwort schreiben…',
      'msg_send': 'Senden',
      'msg_send_to_admin': 'An Admin senden',
      'msg_empty_inbox': 'Noch keine Nachrichten.',
      'msg_empty_player_inbox':
          'Noch keine Nachrichten. Schreib jederzeit dem Admin.',
      'msg_migration_hint':
          'Nachrichten noch nicht verfügbar. migration_admin_messaging.sql in Supabase ausführen.',
      'msg_close_thread': 'Schließen',
      'msg_reopen_thread': 'Wieder öffnen',
      'msg_from_admin': 'Admin',
      'msg_from_player': 'Spieler',
      'msg_from_you': 'Du',
      'msg_compose_hint':
          'Feedback, Vorschläge oder Fehler melden. Der Admin antwortet hier.',
      'msg_sent_ok': 'Nachricht gesendet.',
      'msg_broadcast_sent': 'Broadcast an {count} Spieler gesendet.',
      'msg_broadcast_readonly': 'Auf Broadcasts kann nicht geantwortet werden.',
      'how_to_play_title': 'Spielanleitung',
      'how_to_play_close': 'Verstanden',
      'how_to_play_move_title': 'Bewegung',
      'how_to_play_move_desc':
          'Tippe irgendwo auf den Bildschirm und ziehe, um dein schwarzes Loch zu steuern.',
      'how_to_play_absorb_title': 'Masse wachsen lassen',
      'how_to_play_absorb_desc':
          'Verschlinge Asteroiden, Planeten und kleinere Spieler. Meide größere schwarze Löcher!',
      'how_to_play_boost_title': 'Boost',
      'how_to_play_boost_desc':
          'Energie lädt in 10 Sekunden. Bei voller Ladung tippen: 5 Sekunden Tempo ohne Massenverlust.',
      'how_to_play_link_title': 'Binäre Verbindung',
      'how_to_play_link_desc':
          'Tippe auf Verbinden, wenn du einem anderen Spieler nahe bist, für taktische Vorteile.',
      'how_to_play_shield_title': 'Schild',
      'how_to_play_shield_desc':
          'Sammle Schild-Power-ups, um Schwerkraft größerer Löcher kurzzeitig zu ignorieren.',
      'how_to_play_victory_title': 'Sieg',
      'how_to_play_victory_desc':
          'Erreiche Radius 500 (550 in einzigartigen Universen) — das Universum schließt für alle. Normal: 1. +5, 2. +3, 3. +2 (Elimination −1). Elite: 1. +10, 2. +6, 3. +4 (Elimination −2). Einzigartig: 1. +15, 2. +10, 3. +5 (Elimination −3). Diamanten nie unter 0. Neue Spieler starten mit 20 Diamanten.',
      'how_to_play_ranks_title': 'Rangsystem',
      'how_to_play_ranks_desc':
          'Dein Sternenrang (Nebel → Singularität) basiert auf Sieg-Punkten, nicht auf Diamanten.\n'
          'Nur der 1. Platz gibt Sieg-Punkte. Trainings-Siege zählen nicht.\n'
          'Punkte pro 1. Platz: Normal +{normal}, Elite +{elite}, Unique +{unique}.\n'
          'Schwellen: Stellar {stellar}+ · Nova {nova}+ · Quasar {quasar}+ · Singularität {singularity}+.\n'
          'Siege schließen Training ebenfalls aus. Weltrangliste standardmäßig nach Sieg-Punkten (Rang); Reichtum sortiert nach Diamanten.',
      'how_to_play_currencies_title': 'Währungen',
      'how_to_play_currencies_desc':
          'Neue Konten starten mit 20 Diamanten. Tutorial-Universum ist kostenlos. Normale Universen brauchen mindestens 25 Diamanten. Diamanten schalten Elite (100) und Einzigartig (200) frei.',
      'how_to_play_events_title': 'Kosmische Ereignisse',
      'how_to_play_events_desc':
          'Achte auf Quasar-Stürme, Supernovas und Meteorschauer — sie verändern das Schlachtfeld.',
      'version_notes_title': 'Neuigkeiten',
      'version_current': 'Aktuelle Version: {version}',
      'version_notes_close': 'Schließen',
      'version_notes_dont_show': 'Nicht mehr anzeigen',
      'lobby_version_notes': 'v2.1',
      'v21_section_title': 'Version 2.1',
      'v21_section_subtitle':
          'Siegpunkt-Sternränge, fairere Siege (Training ausgenommen), Tutorial-Sperre, Siege in der Weltrangliste, Lobby-Chat, Posteingangs-Ankündigungen und Live-Admin-Banner.',
      'v21_change_rank_points':
          'Sternränge (Nebula → Singularity) kommen jetzt aus Siegpunkten — gewichtete 1. Plätze. Standard: Normal +1, Elite +2, Unique +3. Training gibt 0.',
      'v21_change_training_excluded':
          'Ein 1. Platz im Training zählt nicht mehr für Siege oder Siegpunkte — nur Normal, Elite und Unique.',
      'v21_change_tutorial_lock':
          'Neue Konten müssen zuerst das Training-Universum abschließen, bevor andere Räume freischalten (Diamant-Tore gelten danach weiter).',
      'v21_change_leaderboard_wins':
          'Die Weltrangliste hat Rang (Siegpunkte) und Reichtum (Diamanten). Siege = kompetitive 1. Plätze; Training zählt nie.',
      'v21_change_rank_dialog':
          'Rangsystem-Bildschirm im Profil — Stufe, nächste Schwelle und Punkte pro Universum.',
      'v21_change_lobby_chat':
          'Lobby-Chat — chatte in Echtzeit mit anderen Spielern, während du in der Lobby wartest.',
      'v21_change_broadcast':
          'Allgemeine Ankündigungen — Team-Hinweise landen im Nachrichten-Posteingang jedes Spielers und bleiben dort, bis du sie liest.',
      'v21_change_live_announce':
          'Live-Ankündigungsbanner — kurze Team-Hinweise erscheinen sofort bei allen Online-Spielern.',
      'v21_change_idle':
          'AFK-/Idle-Schutz aktualisiert — zuverlässigere Lobby- und Match-Warnungen, klarerer Countdown und mehrere Idle-Kick-Fehler behoben.',
      'v21_change_menus':
          'Lobby- und Profilmenüs überarbeitet — klareres Layout, aktualisierte Stats und Ranginfos sowie flüssigere Navigation zwischen Lobby-Aktionen.',
      'v21_change_version_notes':
          'Neuigkeiten für v2.1 erneuert — Ränge, Chat, Ankündigungen und faire Siege oben. Erscheint einmal in der Lobby, bis du es schließt.',
      'v20_section_title': 'Version 2.0',
      'v20_section_subtitle':
          'Kompaktere Wettbewerbsräume, fairere Sitz- und Lobby-Zähler, Diamantenbelohnungen in jedem Match, gemeinsame Universums-Events und ein echtes Top-100-Leaderboard.',
      'v20_change_room_capacity':
          'Wettbewerbsräume sind jetzt 10 Spieler + 10 Bots — vollere Kämpfe bei vollem Raum; allein bleibst du bei einem 20-Einheiten-Match (1 + 19 Bots). Training bleibt 1 + 19 Bots.',
      'v20_change_ghost_cleanup':
          'Geisterplätze von abgestürzten Tabs oder erzwungenem Beenden werden automatisch geleert — Lobby-Zahlen bleiben ehrlich statt gefälschter voller Räume.',
      'v20_change_seat_free':
          'Sterben oder Verlassen gibt deinen Platz frei, damit andere beitreten können, solange der Leader unter Radius 280 liegt. Wiederbeleben holt einen Platz zurück, wenn noch Platz ist.',
      'v20_change_match_rewards':
          'Diamantenbelohnungen funktionieren wieder jedes Match — das Wiederöffnen eines Universums startet eine neue Match-Generation, damit Podium und Eliminierung nicht nach dem ersten Claim blockiert werden.',
      'v20_change_cosmic_sync':
          'Supernovas, Meteorschauer und ihre Warnungen laufen jetzt serverseitig getaktet — jeder Spieler im Universum sieht dasselbe Event am selben Ort zur selben Zeit.',
      'v20_change_real_matchmaking':
          'Matchmaking und Lobby-Statistiken zählen nur echte Spieler — sauberere Räume und korrekte Universumszahlen.',
      'v20_change_smarter_bots':
          'Bots für die neue 10+10-Füllung neu abgestimmt — farmen, kämpfen und fliehen menschlicher, damit halb-botte Räume wettbewerbsfähig bleiben.',
      'v20_change_leaderboard_100':
          'Globales Leaderboard liefert jetzt ein echtes Top 100 nach Diamanten — wie im Profil versprochen.',
      'v20_change_unique_theme':
          'Das Unique-Universum hat jetzt ein eigenes Gold-/Bernsteindesign — in Lobby und Match klarer von Normal (Cyan) und Elite (Lila) zu unterscheiden.',
      'v20_change_version_notes':
          'Neuigkeiten für v2.0 erneuert — Wettbewerbsräume, faire Sitze, synchrone Cosmic-Events und Match-Belohnungen oben.',
      'v19_section_title': 'Version 1.9',
      'v19_section_subtitle':
          'Fähigkeitsbaum-Fortschritt, vier aufrüstbare Kampffähigkeiten, Spieler–Admin-Nachrichten, Idle-Sitzungsschutz und eine härtere serverseitige Wirtschaft.',
      'v19_change_skill_tree':
          'Fähigkeitsbaum in der Lobby — verdiene Fähigkeitspunkte aus deinem Peak-Diamantenstand (1 SP pro 20 Peak ♦). Diamanten werden nicht ausgegeben; Upgrades synchronisieren mit deinem Konto.',
      'v19_change_boost_upgrades':
          'Boost-Zweig — erhöhe Höchstgeschwindigkeit, aktive Dauer und Aufladung bis Stufe 10 pro Knoten für spürbare, aber faire Vorteile.',
      'v19_change_teleport':
          'Teleport-Fähigkeit — springe an einen zufälligen sicheren Ort mit kurzem Ankunftsschild. Skills verkürzen die Abklingzeit und verlängern den Schild.',
      'v19_change_shield':
          'Schild auf Abruf — zeitlich begrenzter Schwerkraftschutz getrennt von Pickup-Schilden. Skills verkürzen die Abklingzeit und verlängern die Dauer.',
      'v19_change_shockwave':
          'Schockwellen-Fähigkeit — stoße kleinere Bots und nahe Materie weg. Skills verbessern Abklingzeit, Reichweite und Stoßkraft.',
      'v19_change_messages':
          'Nachrichten-Posteingang in der Lobby — sende Feedback, Vorschläge oder Fehlerberichte und erhalte Antworten vom Team; inkl. Ungelesen-Badge.',
      'v19_change_idle_protect':
          'Idle-Sitzungsschutz — nach Inaktivität erscheint „Noch da?“; bleib angemeldet oder wirst abgemeldet, damit verlassene Sitzungen enden.',
      'v19_change_economy_security':
          'Wirtschaft serverseitig gehärtet — Diamanten, Siege und Skill-Upgrades ändern sich nur über vertrauenswürdige Serveraktionen.',
      'v19_change_version_notes':
          'Neuigkeiten für v1.9 erneuert — Fähigkeitsbaum, Kampffähigkeiten und Nachrichten oben.',
      'v18_section_title': 'Version 1.8',
      'v18_section_subtitle':
          'Schwarze-Loch-Grafik der nächsten Generation, längeres Match-Tempo, smarteres Matchmaking, filmreife Verschlingungs-Animationen und große Performance-Fixes für Web und Mobil.',
      'v18_change_blackhole_shader':
          'Schwarze Löcher komplett neu auf der GPU — geneigte Akkretionsscheibe mit turbulenten Plasmafilamenten, weißglühender Photonenring, tiefschwarzer Ereignishorizont und relativistische Zwillingsjets, nach echten wissenschaftlichen Aufnahmen modelliert.',
      'v18_change_swallow_visuals':
          'Verschlingen als echtes astrophysikalisches Ereignis — Beute wird durch Gezeitenkräfte gestreckt (Spaghettisierung), an der Roche-Grenze zerrissen und spiralt in die Akkretionsscheibe.',
      'v18_change_merger_rework':
          'Verschmelzungen Schwarzer Löcher nach Referenzbild neu gestaltet — Orbitaltanz, Materiebrücke und finaler Kollaps, ohne dass das Spiel einfriert.',
      'v18_change_merger_ripples':
          'Gravitationswellen bei Verschmelzungen reduziert — weniger Ringe, kürzere Reichweite; der Bildschirm bleibt bei großen Kollisionen lesbar.',
      'v18_change_space_background':
          'Weltraum-Hintergrund für hohe Universen neu gebaut — Nebel, Milchstraßenband, ferne Galaxien und Kometen für eine wirklich tiefe, unheimliche Leere.',
      'v18_change_web_performance':
          'Web-Verlangsamung behoben — Hintergrund-Shader werden einmal erstellt und gecacht statt jeden Frame neu; Matches werden nicht mehr mit der Zeit langsamer.',
      'v18_change_meteor_perf':
          'Meteorschauer-Events drücken die Framerate nicht mehr.',
      'v18_change_mobile_fixes':
          'Mobile Fixes — das viertelgerenderte Schwarze Loch auf Telefonen (Impeller) und der Absturz beim Start nach der Installation sind behoben.',
      'v18_change_big_hole_clarity':
          'Riesige Schwarze Löcher rendern scharf — die harte Kreiskante und der graue Schleier über dem Schatten bei großen Größen sind weg; volle Details in jeder Größe.',
      'v18_change_match_pacing':
          'Matchdauer neu abgestimmt — Nahrungs-Wachstum verlangsamt, damit Spiele näher an den Zielen bleiben: Training ~1,5–2,5 Min., Normal ~4–6, Elite ~5–7, Einzigartig ~7–9.',
      'v18_change_smarter_bots':
          'Bots spielen jetzt auf Sieg wie echte Spieler — sie streben nach Universums-Dominanz, jagen den Anführer oder weichen ihm je nach Größe aus, nutzen Boost zur Flucht vor Supernovas und zum Abschluss des Matches und zögern weniger, je größer sie werden.',
      'v18_change_supernova_events':
          'Supernova-Explosionen sind zurück und der erste Knall kommt in Normal, Elite und Einzigartig früher — eine leichte Zusatzherausforderung außerhalb des Trainingsuniversums.',
      'v18_change_event_warnings':
          'Event-Warnungen aufgeräumt — nur Meteorschauer und Supernovas warnen 5 Sekunden vorher; andere Zwischen-Banner sind weg.',
      'v18_change_leader_threshold':
          'Beitrittsschwelle von Radius 300 auf 250 gesenkt — wächst der Anführer so groß, werden neue Spieler in eine frische Universums-Instanz geleitet.',
      'v18_change_empty_close':
          'Verlässt der letzte echte Spieler die Runde, schließt sich das Universum sofort — Bot-only-Räume laufen nicht mehr leer weiter.',
      'v18_change_avatar_hud_only':
          'Profilfotos sitzen nicht mehr in der Mitte des Schwarzen Lochs — das Porträt bleibt neben dem Namensschild darüber.',
      'v18_change_rewarded_ads':
          'Belohnungsvideos für Wiederbelebungen über Google Mobile Ads integriert.',
      'v18_change_version_notes':
          'Neuigkeiten für v1.8 erneuert — Grafik-Überarbeitung, Match-Tempo und Matchmaking oben.',
      'v17_section_title': 'Version 1.7',
      'v17_section_subtitle':
          'Diamant-Ökonomie, Spielerprofile, Einzelgerät-Sitzungen, Live-Lobby-Statistiken und Onboarding für neue Kosmos-Reisende.',
      'v17_change_match_rewards':
          'Verdiene und verliere Diamanten nach Match-Ergebnis — Podiumsbelohnungen bis +15/+10/+5 in Einzigartigen Universen, Eliminierungsstrafen −1/−2/−3 je Stufe. Ergebnisse werden serverseitig gespeichert.',
      'v17_change_diamond_gates':
          'Neue Konten starten mit 20 Diamanten. Training ist kostenlos; Normal 25, Elite 100, Einzigartig 200. Lobby-Karten zeigen Eintritt, Belohnungen und Strafen.',
      'v17_change_profile_hub':
          'Tippe im Lobby auf deinen Avatar für ein 3-Tab-Profil: Statistiken, Skins und Shop. Siege, Weltrang und Live-Sync via Supabase.',
      'v17_change_edit_profile':
          'Ändere deinen 3–12 Zeichen Anzeigenamen und lade ein Profilfoto aus der Galerie hoch (max. 5 MB). Avatare in Supabase Storage.',
      'v17_change_ingame_avatars':
          'Dein hochgeladenes Avatar erscheint im Match im Schwarzen Loch. In Einstellungen → Profilbilder ein-/ausschalten.',
      'v17_change_cosmetic_store':
          'Gib Gold im Shop aus, um legendäre Akkretionsscheiben-Skins freizuschalten. Im Profilmenü ausrüsten — aktiver Skin gilt im Spiel.',
      'v17_change_global_leaderboard':
          'Sieh die Top 100 Spieler weltweit nach Diamanten im Profil. Deine eigene Position auch außerhalb der Top 100.',
      'v17_change_single_session':
          'Jedes Konto kann nur in einem aktiven Match sein. Ein anderes Gerät zeigt „Spieler bereits aktiv“, bis du gehst.',
      'v17_change_live_lobby_stats':
          'Universumskarten in der Lobby zeigen Live-Zahlen: aktive Universen, Spieler und Bots — per Supabase Realtime.',
      'v17_change_onboarding':
          'Neue Spieler müssen zuerst das Trainings-Universum abschließen. Das erste Match zeigt zeitgesteuerte Hinweise.',
      'v17_change_native_splash':
          'Marken-Splashscreen erscheint sofort beim Start, während Sprache, Auth und Einstellungen im Hintergrund laden.',
      'v17_change_hud_podium_rewards':
          'Das Match-Podium zeigt jetzt Diamant-Belohnungen für Platz 1–3 und Rangstufen der Gegner.',
      'v17_change_swallow_vfx':
          'Jagd-Visuals verbessert — die Gezeitenbrücke zwischen Schwarzen Löchern ist jetzt ein mehrschichtiger Flame-Partikeleffekt.',
      'v17_change_victory_fix':
          'Matches enden sofort bei Radius 500 (550 in Einzigartig) — kein Einfrieren mehr bei gerundeter Anzeigemasse.',
      'v17_change_login_fix':
          'Kurzer „not authenticated“-Fehler nach Google-Login behoben. Sitzungsprüfung wiederholt, bis das JWT steht.',
      'v17_change_hud_loading':
          'Match-HUD und Bestenliste erscheinen früher — weniger schwarzer Ladebildschirm zu Matchbeginn.',
      'v17_change_version_notes':
          'Neuigkeiten für v1.7 erneuert — Diamant-Ökonomie, Profile und Sitzungsverwaltung oben.',
      'v16_section_title': 'Version 1.6',
      'v16_section_subtitle':
          'Teleskop-inspirierte Schwarze Löcher, serverseitiges Universums-Matchmaking, intelligente Raumaufteilung und faire Zufallsspawns.',
      'v16_change_server_matchmaking':
          'Normale, Elite- und Einzigartige Universen nutzen jetzt serverseitige Raumzuweisung — aus der Lobby landest du im richtigen Universum.',
      'v16_change_universe_instances':
          'Im HUD siehst du, in welchem Universum du bist — nummerierte Server-Instanzen wie Normales Universum 1.',
      'v16_change_leader_radius_split':
          'Erreicht der Raumführer Radius 300 oder ist der Raum voll, werden neue Spieler zur nächsten Universums-Instanz geleitet.',
      'v16_change_room_lifecycle':
          'Universen schließen nach dem Match; Geister-Mitglieder nach Absturz oder Force-Quit werden bereinigt — leeres Universum 1 wird nicht mehr übersprungen.',
      'v16_change_abandoned_universe':
          'Sind alle echten Spieler eliminiert oder weg, schließt das Universum automatisch — auch wenn nur Bots übrig sind.',
      'v16_change_black_hole_graphics':
          'Schwarze Löcher neu gestaltet — Gravitationsschatten, heller Photonring und geneigte Akkretionsscheibe skalieren mit Masse.',
      'v16_change_star_lensing':
          'Hintergrundsterne biegen sich, leuchten auf und verschwinden in deinem Schatten — Gravitationslinsen im Universum.',
      'v16_change_swallow_animations':
          'Neue Jagd-Visuals: Gezeiten-Materieströme zwischen Löchern, Photonring-Blitze beim Fangen und Jagdfunken beim Annähern.',
      'v16_change_food_spaghettify':
          'Asteroiden und Planeten dehnen sich nur in echter Fangreichweite zu Bändern — näher, physikalischerer Infall.',
      'v16_change_gravity_physics':
          'Newtonsche 1/r²-Gravitation und Photonring-Fangdistanz — Masse und Zug wirken physischer.',
      'v16_change_universe_tiers':
          'Vier Universumsstufen spielen sich unterschiedlich — Training, Normal, Elite und Einzigartig mit eigenem Tempo und Einsatz.',
      'v16_change_cosmic_events':
          'Supernovas, Meteorschauer und Quasarstürme formen das Schlachtfeld mitten im Match neu.',
      'v16_change_hole_merger':
          'Zwei dominante Schwarze Löcher können eine galaktische Verschmelzung auslösen — Erschütterung, Raumriss und kombinierte Masse.',
      'v16_change_random_spawn':
          'Spieler und Bots spawnen jetzt an zufälligen Positionen im Universum — kein gemeinsamer Start im Zentrum mehr.',
      'v16_change_revive_spawn':
          'Wiederbelebung bringt dich ebenfalls an einen zufälligen sicheren Ort, fern von anderen Spielern und Bots.',
      'v16_change_prey_bot_spawn':
          'Beute-Bots im Einfach-Raum spawnen nicht mehr nahe deinem Bildschirm — sie erscheinen zufällig auf der ganzen Karte.',
      'v16_change_spawn_spacing':
          'Spawn-Positionen halten Mindestabstand zu anderen Spielern und Bots, damit ihr nicht übereinander startet.',
      'v16_change_version_notes':
          'Neuigkeiten für v1.6 erneuert — serverseitiges Matchmaking und Universums-Lebenszyklus oben aufgeführt.',
      'v15_section_title': 'Version 1.5',
      'v15_section_subtitle':
          'Großes Update mit faireren Bots, Rang-Abzeichen, Spawn-Schutz und neuem Boost-System.',
      'v15_change_match_end':
          'Bei einem Sieg friert das Match für alle ein — Sieger, Zeit und automatische Rückkehr zur Lobby.',
      'v15_change_bot_victory':
          'Bots können bei Masse 500 das Universum erobern. Nach deiner Eliminierung kämpfen Bots weiter.',
      'v15_change_rank_system':
          'Diamant-Rang-Abzeichen (I–V) vor Spielernamen — im Spiel, HUD und Match-Ergebnissen.',
      'v15_change_spawn_shield':
          '3-Sekunden-Spawn-Schutz beim Universumseintritt — vollständige Unverwundbarkeit mit Countdown.',
      'v15_change_boost':
          'Boost überarbeitet: Energie lädt in 10 s, ein Tipp für 5 s Tempo — kein Massenverlust.',
      'v15_change_spectator':
          'Zuschauermodus hat jetzt einen Beenden-Button am unteren Bildschirmrand.',
      'v15_change_bot_badge':
          'Bot-Abzeichen steht jetzt am Anfang des Namens.',
      'v15_change_global_rank':
          'Rang-Abzeichen auch in der globalen Weltrangliste.',
      'v15_change_audio':
          'Nur das offizielle Quasar-Orbit-Theme — Schleifenmusik, alle anderen Sounds entfernt.',
      'v15_change_bot_fixes':
          'Bots bleiben nicht mehr bei ~140 Masse hängen und beenden bei 500 korrekt.',
    },
    'ru': {
      'app_title': 'Quasar.io',
      'sign_in_google': 'Войти через Google',
      'signing_in': 'Вход...',
      'sign_out': 'Выйти',
      'admin_badge': 'ВЛАДЕЛЕЦ',
      'admin_title': 'Панель админа',
      'admin_subtitle': 'Живой обзор вселенных, игроков и ботов',
      'admin_refresh': 'Обновить',
      'admin_enter_lobby': 'В лобби',
      'admin_open_panel': 'Панель управления',
      'admin_total_players': 'Игроки онлайн',
      'admin_total_bots': 'Боты онлайн',
      'admin_total_universes': 'Активные вселенные',
      'admin_active_sessions': 'Активные сессии',
      'admin_universes_section': 'Вселенные и сложность',
      'admin_players_section': 'Статистика игроков и ботов',
      'admin_difficulty': 'Сложность',
      'admin_difficulty_relaxed': 'Лёгкая',
      'admin_difficulty_standard': 'Стандарт',
      'admin_difficulty_elite': 'Элита',
      'admin_difficulty_unique': 'Уникальная',
      'admin_hunt_priority': 'Сложность ботов: {pct}%',
      'admin_hunt_priority_short': 'Боты',
      'admin_hunt_priority_howto':
          'Сложность ботов (0–100%) задаёт, насколько агрессивно боты охотятся на игроков вместо фарма. Выше = меньше бегства, точнее прицел, выше счёт добычи, раньше буст. В первом матче ×0.85.',
      'admin_hunt_priority_formula':
          'Счёт добычи ≈ преимуществоРазмера × сложность / (1 + дистанция/радиус). По умолчанию для уровня: {default}%. Ползунок меняет значение; новые матчи используют сохранённое.',
      'admin_hunt_priority_reset': 'Сбросить сложность ботов',
      'admin_room_tuning_howto':
          'Выберите вселенную, затем настройте по категориям. Только для новых матчей.',
      'admin_room_tuning_reset': 'Сбросить настройки всех вселенных',
      'admin_room_tuning_reset_one': 'Сбросить эту вселенную',
      'admin_tune_saving': 'Сохранение…',
      'admin_tune_default': 'По умолч. {value}',
      'admin_tune_tab_world': 'Мир',
      'admin_tune_tab_tempo': 'Темп',
      'admin_tune_tab_objects': 'Объекты',
      'admin_tune_tab_events': 'События',
      'admin_tune_tab_radiation': 'Радиация',
      'admin_tune_tab_bots': 'Боты',
      'admin_tune_tab_live': 'Онлайн',
      'admin_live_instances': 'Активные экземпляры',
      'admin_tune_world': 'Мир и радиусы',
      'admin_tune_world_hint':
          'Длительность матча: больший мир / выше радиус победы = дольше игра.',
      'admin_tune_gravity': 'Притяжение еды',
      'admin_tune_tempo_hint':
          'Целевые минуты задают баланс. Ранний буст помогает новичкам; низкий респаун = больше еды.',
      'admin_tune_target_min': 'Цель длительности (мин)',
      'admin_tune_target_max': 'Цель длительности (макс)',
      'admin_tune_early_duration': 'Длительность ранней игры',
      'admin_tune_early_growth': 'Ранний буст роста игрока',
      'admin_tune_respawn_delay': 'Множитель респауна еды',
      'admin_tune_objects': 'Поглощаемые объекты',
      'admin_tune_objects_hint': '0 = убрать тип объекта.',
      'admin_tune_events': 'Космические события',
      'admin_tune_events_short': 'События',
      'admin_tune_events_enabled': 'Сверхновая и метеоры',
      'admin_tune_events_enabled_hint': 'Выкл. = без сверхновой/метеоров.',
      'admin_tune_radiation_hint':
          'Анти-кемп давление. Больше радиус / меньше idle = жёстче штраф. Late-game shrink сжимает финал.',
      'admin_tune_radiation_radius': 'Стартовый радиус радиации',
      'admin_tune_radiation_idle': 'Idle до радиации',
      'admin_tune_late_radiation_radius': 'Радиус радиации в конце',
      'admin_tune_late_radiation_idle': 'Idle в конце',
      'admin_tune_late_radiation_shrink': 'Скорость сжатия в конце',
      'admin_tune_bots': 'Боты',
      'admin_tune_bots_human_intro':
          'Соревновательные комнаты: 10 игроков + 10 ботов. Пресеты делают ботов похожими на людей — фарм, бой, побег.',
      'admin_tune_universe_presets': 'Сложность вселенной',
      'admin_tune_universe_presets_hint':
          'Лестница от дефолтов этой вселенной — еда, темп, события, радиация и боты вместе. Ranked = баланс компиляции.',
      'admin_tune_universe_preset_training': 'Тренировка',
      'admin_tune_universe_preset_casual': 'Лёгкий',
      'admin_tune_universe_preset_ranked': 'Рейтинг',
      'admin_tune_universe_preset_predator': 'Хищник',
      'admin_tune_universe_preset_apex': 'Апекс',
      'admin_tune_universe_balanced_distribute': 'Сбалансированную лестницу на все',
      'admin_tune_universe_balanced_distribute_hint':
          'Simple→Тренировка · Normal→Рейтинг · Elite→Хищник · Unique→Апекс',
      'admin_tune_bot_presets': 'Сложность ботов',
      'admin_tune_bot_presets_hint':
          'Пять уровней. Ranked — соревновательная база. Активный чип показывает текущий профиль.',
      'admin_tune_bot_preset_training': 'Тренировка',
      'admin_tune_bot_preset_casual': 'Лёгкий',
      'admin_tune_bot_preset_ranked': 'Рейтинг',
      'admin_tune_bot_preset_predator': 'Хищник',
      'admin_tune_bot_preset_apex': 'Апекс',
      'admin_tune_bot_preset_soft': 'Тренировка',
      'admin_tune_bot_preset_human': 'Рейтинг',
      'admin_tune_bot_preset_aggressive': 'Апекс',
      'admin_tune_bot_ai': 'Поведение ИИ',
      'admin_tune_bot_ai_hint':
          'Меньший интервал = быстрее (человечнее). Prey ~0.92–0.95. Фокус на игроков держите ~1.1–1.3.',
      'admin_tune_decision_min': 'Интервал решений (мин)',
      'admin_tune_decision_max': 'Интервал решений (макс)',
      'admin_tune_prey_ratio': 'Соотношение размера добычи',
      'admin_tune_threat_ratio': 'Соотношение угрозы (бегство)',
      'admin_tune_prey_search': 'Дальность поиска добычи',
      'admin_tune_food_search': 'Дальность поиска еды',
      'admin_tune_event_awareness': 'Осведомлённость о событиях',
      'admin_tune_mine_avoidance': 'Избегание мин',
      'admin_tune_min_hunt_radius': 'Мин. радиус для охоты',
      'admin_tune_player_bias': 'Приоритет игроков',
      'admin_tune_intercept_prey': 'Перехват движущейся добычи',
      'admin_tune_personality': 'Смесь личностей',
      'admin_tune_personality_hint':
          'Относительные веса личностей ботов. Сумма не обязана быть 100.',
      'admin_tune_personality_coward': 'Трус',
      'admin_tune_personality_aggressive': 'Агрессивный',
      'admin_tune_personality_opportunist': 'Оппортунист',
      'admin_tune_on': 'Вкл.',
      'admin_tune_off': 'Выкл.',
      'admin_tune_victory_radius': 'Радиус победы',
      'admin_tune_player_start_radius': 'Стартовый радиус игрока',
      'admin_tune_world_size': 'Размер мира',
      'admin_tune_food_growth': 'Множитель роста еды',
      'admin_tune_asteroids': 'Малые/средние астероиды',
      'admin_tune_meteorites': 'Метеориты',
      'admin_tune_planets': 'Планеты',
      'admin_tune_quasar_fragments': 'Фрагменты квазара',
      'admin_tune_large_asteroids': 'Крупные астероиды',
      'admin_tune_xlarge_asteroids': 'Очень крупные астероиды',
      'admin_tune_giant_asteroids': 'Гигантские астероиды',
      'admin_tune_mines': 'Мины',
      'admin_tune_supernova_interval': 'Интервал сверхновой',
      'admin_tune_supernova_first': 'Задержка первой сверхновой',
      'admin_tune_meteor_cooldown': 'Задержка первого метеора',
      'admin_tune_event_growth_cap': 'Макс. рост за событие',
      'admin_tune_supernova_planets': 'Планеты сверхновой',
      'admin_tune_bot_start_min': 'Старт. радиус бота (мин)',
      'admin_tune_bot_start_max': 'Старт. радиус бота (макс)',
      'admin_no_active_universes': 'Сейчас нет активных вселенных',
      'admin_registered_players': 'Зарегистрированные игроки',
      'admin_total_games_won': 'Всего побед',
      'admin_live_entities': 'Игроки + боты онлайн',
      'admin_bot_share': 'Доля ботов онлайн',
      'admin_top_winners': 'Лучшие победители',
      'admin_no_players_yet': 'Пока нет зарегистрированных игроков',
      'admin_last_updated': 'Обновлено {time}',
      'select_language': 'Язык',
      'welcome_cosmic': 'Пересеки горизонт событий',
      'login_atmosphere':
          'Поглощай материю. Обходи соперников. Правь ареной глубокого космоса.',
      'lobby_brand_eyebrow': 'Арена глубокого космоса',
      'lobby_choose_universe': 'Выбери вселенную',
      'store_tab_skins': 'Скины',
      'store_tab_trails': 'Следы',
      'store_tab_emotes': 'Эмоции',
      'store_buy': 'Купить',
      'store_equip': 'Надеть',
      'store_owned': 'Куплено',
      'store_insufficient_gold': 'Недостаточно золота',
      'event_quasar_storm': 'Квазарный шторм!',
      'event_supernova': 'Вспышка сверхновой!',
      'event_supernova_warning': 'Внимание: сверхновая через {s} с!',
      'event_meteor_shower': 'Метеорный дождь!',
      'event_meteor_warning': 'Внимание: метеорный дождь через {s} с!',
      'event_black_hole_merge': 'Слияние чёрных дыр!',
      'merge_stage_tidal': 'Приливная деформация и перенос массы!',
      'merge_stage_dance': 'Танец — мощные гравитационные волны!',
      'merge_stage_ringdown': 'Слияние и затухание — один квазар!',
      'event_cosmic_mine': 'Детонация космической мины!',
      'event_cosmic_dust_welcome': 'Космическая пыль — бесплатный рост!',
      'first_match_hint_move':
          'Проведите пальцем, чтобы направить чёрную дыру',
      'first_match_hint_absorb':
          'Поглощайте астероиды и меньшие дыры, чтобы расти',
      'first_match_hint_grow':
          'Растите быстро — стартовый щит ещё активен!',
      'lobby_recommended_room': 'РЕКОМЕНДУЕМ',
      'spawn_protection_label': 'Стартовый защитный щит',
      'game_over_title': 'Коллапс горизонта событий',
      'game_over_subtitle': 'Ваша масса была поглощена большей пустотой',
      'game_over_watch_ad_revive': 'Смотреть рекламу и возродиться',
      'game_over_quit': 'Выйти',
      'game_over_watch_match': 'Смотреть',
      'spectator_stop_watching': 'Прекратить просмотр',
      'game_over_peak_mass': 'Пиковая масса',
      'game_over_diamond_penalty':
          '−{diamonds} алмаз при выходе (не ниже 0)',
      'game_over_play_again': 'Играть снова',
      'game_over_return_lobby': 'В лобби',
      'match_quit_confirm_title': 'Выйти из матча?',
      'match_quit_confirm_message':
          'Вы уверены, что хотите выйти? Вы потеряете {diamonds} алмаз(ов).',
      'match_quit_confirm_stay': 'Остаться',
      'match_quit_confirm_leave': 'Выйти',
      'leaderboard_title': 'РЕЙТИНГ',
      'hud_population_players': 'Игроки',
      'hud_population_bots': 'Боты',
      'leaderboard_you': 'Вы',
      'leaderboard_name': 'Имя',
      'leaderboard_mass': 'Масса',
      'victory_title': 'Вы покорили Вселенную!',
      'victory_subtitle': 'Космос склоняется перед вашей гравитацией',
      'victory_time': 'Время победы: {time}',
      'victory_reward': '+{diamonds} алмазов · +1 победа',
      'victory_return_lobby': 'Вернуться в лобби с триумфом',
      'reward_double_cta': 'Удвоить награду',
      'reward_double_micro': '+{extra} алмазов дополнительно (итого {total})',
      'reward_double_done': '2× получено · +{total} алмазов',
      'reward_double_loading': 'Загрузка рекламы…',
      'reward_double_claiming': 'Начисление бонуса…',
      'reward_double_claim_wait': 'Сохранение награды… попробуйте снова',
      'reward_double_ad_failed': 'Реклама недоступна. Базовая награда сохранена.',
      'reward_double_grant_failed': 'Бонус ожидает — нажмите ещё раз (без новой рекламы)',
      'reward_double_retry_grant': 'Забрать бонус',
      'reward_double_unavailable': 'Реклама недоступна на этом устройстве',
      'frozen_title': 'Вселенная покорена',
      'frozen_champion': '{name} покорил(а) вселенную за {time}',
      'match_champion_result': '{name} выиграл(а) матч за {time}',
      'frozen_placement_reward': 'Место #{place}: +{diamonds} алмазов',
      'frozen_room_closed': 'Вселенная закрыта.',
      'match_returning_lobby': 'Возврат в лобби через {seconds} с…',
      'lobby_diamonds': 'Алмазы',
      'rank_tier_nebula': 'Туманность',
      'rank_tier_stellar': 'Звёздный',
      'rank_tier_nova': 'Нова',
      'rank_tier_quasar': 'Квазар',
      'rank_tier_singularity': 'Сингулярность',
      'lobby_gold': 'Золото',
      'lobby_play': 'Играть',
      'lobby_stat_universes': '{count} вселенных',
      'lobby_stat_players': '{count} игроков',
      'lobby_stat_bots': '{count} ботов',
      'lobby_stat_universes_short': 'Вселенные',
      'lobby_stat_players_short': 'Игроки',
      'lobby_stat_bots_short': 'Боты',
      'lobby_room_fill_hint':
          'Каждая открытая вселенная: до 10 реальных игроков, боты дополняют до 20.',
      'lobby_low_population_hint':
          'Мало реальных игроков — остальное матча заполняют боты.',
      'lobby_stat_solo_players': 'Соло',
      'room_entry_free': 'Вход: Бесплатно',
      'room_entry_cost': 'Нужно минимум {count}',
      'room_entry_cost_prefix': 'Нужно минимум {count} ',
      'room_entry_cost_suffix': '',
      'room_rewards_label': 'Награды',
      'room_elimination_label': 'Поглощение',
      'room_elimination_none': 'без потерь',
      'room_simple_title': 'Учебная вселенная',
      'lobby_first_login_lock': 'Сначала пройдите обучение',
      'room_instance_normal': 'Обычная вселенная {number}',
      'room_instance_elite': 'Элитная вселенная {number}',
      'room_instance_unique': 'Уникальная вселенная {number}',
      'matchmaking_error': 'Не удалось войти в комнату. Попробуйте снова.',
      'player_already_active_title': 'Игрок уже активен',
      'player_already_active_message':
          'Этот аккаунт уже в матче на другом устройстве. Завершите ту игру, чтобы играть здесь.',
      'player_already_active_ok': 'ОК',
      'idle_session_title': 'Вы ещё здесь?',
      'idle_session_message':
          'Нет активности. Выход через {seconds} сек.',
      'idle_session_stay': 'Остаться в системе',
      'idle_match_result_title': 'Возврат в лобби',
      'idle_match_result_message':
          'Нет действий на экране результатов. Возврат в лобби через {seconds} с.',
      'idle_match_result_stay': 'Остаться на этом экране',
      'idle_match_result_hint':
          'Если 10 секунд ничего не делать, начнётся обратный отсчёт 10 с и вы вернётесь в лобби.',
      'room_simple_desc':
          'Вход: Бесплатно · Только боты\nНаграды +3 · +2 · +1 · Без штрафа · крупные астероиды',
      'room_normal_title': 'Обычные вселенные',
      'room_normal_desc':
          'Нужно минимум 25\nНаграды +5 · +3 · +2 · Поглощение -1',
      'room_elite_title': 'Элитные вселенные',
      'room_elite_desc':
          'Нужно минимум 100\nНаграды +10 · +6 · +4 · Поглощение -2',
      'room_unique_title': 'Уникальные вселенные',
      'room_unique_desc':
          'Нужно минимум 200\nНаграды +15 · +10 · +5 · Поглощение -3',
      'room_requires_100': 'Нужно минимум 100',
      'room_requires_300': 'Нужно минимум 200',
      'room_requires_diamonds': 'Нужно минимум {count}',
      'profile_stats_tab': 'Статистика',
      'profile_store_tab': 'Магазин',
      'feature_coming_soon_badge': 'Скоро',
      'feature_coming_soon_title': 'В разработке',
      'feature_coming_soon_body':
          'Этот раздел куётся в глубоком космосе. Скины и магазин скоро откроются.',
      'profile_games_won': 'Побед',
      'profile_global_rank': 'Мировой рейтинг',
      'profile_rank_system': 'Система рангов',
      'rank_system_intro':
          'Звёзды у имени — ваш ранг. Ранг растёт от очков побед (взвешенные 1-е места), а не от алмазов.',
      'rank_system_your_rank': 'ВАШ РАНГ',
      'rank_system_your_points': '{points} очков побед',
      'rank_system_next': 'Далее: {tier} от {points}+',
      'rank_system_ladder_title': 'ЗВЁЗДНАЯ ЛЕСТНИЦА',
      'rank_system_current_badge': 'Вы здесь',
      'rank_system_earn_title': 'ОЧКИ ЗА 1-Е МЕСТО',
      'rank_system_points_per_win': '+{n}',
      'rank_system_points_none': 'Не считается',
      'rank_system_note':
          'Очки и победы даёт только 1-е место в Обычной / Элите / Уникальной. Обучение не считается. Ранг — по очкам побед; Богатство — по алмазам.',
      'rank_system_close': 'Понятно',
      'global_rank_player': 'Игрок',
      'global_rank_wins': 'Победы',
      'global_rank_points': 'Очки',
      'global_rank_tab_rank': 'Ранг',
      'global_rank_tab_wealth': 'Богатство',
      'global_rank_blurb':
          'Ранг: очки побед. Богатство: алмазы. Победы = соревновательные 1-е (без обучения).',
      'global_rank_blurb_rank':
          'Сортировка по очкам побед (затем по победам). Считается только 1-е в Обычной / Элите / Уникальной — обучение никогда.',
      'global_rank_blurb_wealth':
          'Сортировка по алмазам (затем по победам). Звёзды у имени по-прежнему показывают ранг по очкам побед.',
      'global_rank_your_position': 'ВАША ПОЗИЦИЯ',
      'global_rank_empty': 'Рейтинг пока пуст.',
      'global_rank_error': 'Не удалось загрузить рейтинг.',
      'global_rank_retry': 'Повторить',
      'profile_legendary_skins': 'Легендарные скины',
      'skin_default': 'Солнечная вспышка',
      'skin_frost': 'Ледяная вуаль',
      'skin_ember': 'Угольное ядро',
      'skin_pulsar': 'Синий пульсар',
      'skin_nebula': 'Фиолетовая туманность',
      'skin_plasma': 'RGB-плазма',
      'skin_void': 'Тёмная пустота',
      'skin_quasar': 'Зелёный квазар',
      'skin_eclipse': 'Солнечное затмение',
      'skin_supernova': 'Красная сверхновая',
      'skin_aurora': 'Северное сияние',
      'skin_binary': 'Двойная звезда',
      'skin_singularity': 'Сингулярность Prime',
      'skin_celestial': 'Небесная корона',
      'skin_picker_title': 'Скины чёрных дыр',
      'skin_picker_subtitle': 'Выберите вид аккреционного диска',
      'skin_picker_equipped': 'Надето',
      'skin_picker_locked': 'Заблокировано',
      'skin_picker_free': 'Бесплатно',
      'trail_comet': 'Плазменный джет',
      'trail_nebula': 'Линзовый след',
      'trail_quantum': 'Гравитационная волна',
      'trail_picker_section': 'Следы движения',
      'trail_picker_subtitle': 'Нажмите на след, чтобы надеть',
      'trail_picker_empty': 'Получите следы в магазине, чтобы надеть их здесь.',
      'trail_picker_owned': 'Куплено',
      'store_trail_equip_hint': 'Наденьте этот след во вкладке «Внешний вид».',
      'store_trail_claim_success':
          'След разблокирован! Наденьте его во вкладке «Внешний вид».',
      'emote_wave': 'Космическая волна',
      'emote_burst': 'Вспышка сверхновой',
      'emote_void': 'Смех пустоты',
      'store_purchase_success': 'Покупка успешна!',
      'store_equip_success': 'Надето!',
      'store_error': 'Что-то пошло не так',
      'error_generic': 'Что-то пошло не так. Попробуйте ещё раз.',
      'sign_in_error': 'Не удалось войти. Попробуйте ещё раз.',
      'profile_edit': 'Редактировать профиль',
      'profile_edit_name': 'Отображаемое имя',
      'profile_edit_avatar': 'Нажмите, чтобы сменить фото',
      'profile_edit_save': 'Сохранить',
      'profile_edit_cancel': 'Отмена',
      'profile_username_taken': 'Это имя уже занято',
      'profile_username_invalid':
          'Имя: 3–12 символов (буквы, цифры, пробелы)',
      'profile_update_success': 'Профиль обновлён!',
      'profile_update_error': 'Не удалось обновить профиль',
      'lobby_how_to_play': 'Выжить',
      'lobby_skill_tree': 'Матрица силы',
      'lobby_version_notes_hint': 'Журнал передачи',
      'skill_tree_title': 'Дерево навыков',
      'skill_sp_available': 'Доступно SP',
      'skill_sp_earned': 'Потрачено / Получено',
      'skill_sp_rules':
          'Каждые {n} пиковых алмазов дают 1 SP. Алмазы не тратятся. До следующего SP: {next} ♦.',
      'skill_branch_boost': 'Ускорение',
      'skill_branch_teleport': 'Телепорт',
      'skill_branch_shield': 'Щит',
      'skill_branch_shockwave': 'Ударная волна',
      'skill_level': 'Ур',
      'skill_upgrade': '+1 SP',
      'skill_maxed': 'MAX',
      'skill_value_now': 'Сейчас',
      'skill_error_no_sp': 'Нет очков навыков',
      'skill_error_max': 'Навык уже на максимуме',
      'skill_error_generic': 'Не удалось улучшить навык',
      'skill_node_boost_speed': 'Скорость ускорения',
      'skill_node_boost_speed_desc': 'Выше макс. скорость во время ускорения',
      'skill_node_boost_duration': 'Длительность ускорения',
      'skill_node_boost_duration_desc': 'Ускорение действует дольше',
      'skill_node_boost_charge': 'Заряд ускорения',
      'skill_node_boost_charge_desc': 'Быстрее перезарядка между ускорениями',
      'skill_node_teleport_cd': 'Перезарядка телепорта',
      'skill_node_teleport_cd_desc': 'Короче ожидание между телепортами',
      'skill_node_teleport_shield': 'Щит прибытия',
      'skill_node_teleport_shield_desc': 'Дольше защита после телепорта',
      'skill_node_shield_cd': 'Перезарядка щита',
      'skill_node_shield_cd_desc': 'Короче ожидание между щитами',
      'skill_node_shield_duration': 'Длительность щита',
      'skill_node_shield_duration_desc': 'Активный щит держится дольше',
      'skill_node_shockwave_cd': 'Перезарядка волны',
      'skill_node_shockwave_cd_desc': 'Короче ожидание между волнами',
      'skill_node_shockwave_range': 'Дальность волны',
      'skill_node_shockwave_range_desc': 'Отталкивает с большей дистанции',
      'skill_node_shockwave_power': 'Сила волны',
      'skill_node_shockwave_power_desc':
          'Сильнее толкает меньшие дыры и материю',
      'settings_title': 'Настройки',
      'settings_sound_title': 'Звук',
      'settings_music': 'Quasar Orbit Theme',
      'settings_music_desc': 'Официальная тема Quasar.io',
      'settings_music_volume': 'Громкость музыки',
      'settings_haptics': 'Вибрация',
      'settings_haptics_desc': 'Тактильная отдача при столкновениях и событиях',
      'settings_audio_missing': 'Не удалось загрузить аудиофайл.',
      'settings_display_section': 'Отображение',
      'settings_show_own_name': 'Моё имя',
      'settings_show_own_name_desc': 'Показывать ваше имя над вашей чёрной дырой',
      'settings_show_other_names': 'Другие имена',
      'settings_show_other_names_desc':
          'Показывать имена других игроков и ботов над чёрными дырами',
      'settings_show_profile_pictures': 'Аватары',
      'settings_show_profile_pictures_desc':
          'Показывать аватары внутри чёрных дыр',
      'settings_support_section': 'Поддержка',
      'admin_nav_messages': 'Сообщения',
      'admin_page_messages_title': 'Сообщения',
      'admin_page_messages_desc':
          'Читайте отзывы, отвечайте лично или рассылайте всем.',
      'msg_player_title': 'Сообщения',
      'msg_tab_inbox': 'Входящие',
      'msg_tab_compose': 'Написать',
      'msg_open_inbox': 'Входящие',
      'msg_write_to_admin': 'Написать админу',
      'msg_category_feedback': 'Отзыв',
      'msg_category_suggestion': 'Предложение',
      'msg_category_bug': 'Ошибка',
      'msg_category_direct': 'Личное',
      'msg_category_broadcast': 'Рассылка',
      'msg_filter_open': 'Открытые',
      'msg_filter_closed': 'Закрытые',
      'msg_filter_all': 'Все',
      'msg_filter_category_all': 'Все типы',
      'msg_broadcast': 'Рассылка',
      'msg_send_direct': 'Игроку',
      'msg_search_player': 'Поиск игрока…',
      'msg_to_player': 'Кому: {name}',
      'msg_subject_hint': 'Тема',
      'msg_body_hint': 'Напишите сообщение…',
      'msg_reply_hint': 'Напишите ответ…',
      'msg_send': 'Отправить',
      'msg_send_to_admin': 'Отправить админу',
      'msg_empty_inbox': 'Пока нет сообщений.',
      'msg_empty_player_inbox':
          'Пока нет сообщений. Можете написать админу в любое время.',
      'msg_migration_hint':
          'Сообщения ещё недоступны. Выполните migration_admin_messaging.sql в Supabase.',
      'msg_close_thread': 'Закрыть',
      'msg_reopen_thread': 'Открыть снова',
      'msg_from_admin': 'Админ',
      'msg_from_player': 'Игрок',
      'msg_from_you': 'Вы',
      'msg_compose_hint':
          'Отзыв, предложение или сообщение об ошибке. Админ ответит здесь.',
      'msg_sent_ok': 'Сообщение отправлено.',
      'msg_broadcast_sent': 'Рассылка отправлена {count} игрокам.',
      'msg_broadcast_readonly': 'На рассылки нельзя отвечать.',
      'how_to_play_title': 'Как играть',
      'how_to_play_close': 'Понятно',
      'how_to_play_move_title': 'Движение',
      'how_to_play_move_desc':
          'Коснитесь любого места на экране и ведите пальцем, чтобы управлять чёрной дырой.',
      'how_to_play_absorb_title': 'Рост массы',
      'how_to_play_absorb_desc':
          'Поглощайте астероиды, планеты и меньших игроков. Избегайте больших чёрных дыр!',
      'how_to_play_boost_title': 'Ускорение',
      'how_to_play_boost_desc':
          'Энергия заряжается 10 секунд. Нажмите при полном заряде — 5 секунд скорости без потери массы.',
      'how_to_play_link_title': 'Бинарная связь',
      'how_to_play_link_desc':
          'Нажмите «Связь» рядом с другим игроком для тактического преимущества.',
      'how_to_play_shield_title': 'Щит',
      'how_to_play_shield_desc':
          'Собирайте щиты, чтобы временно игнорировать гравитацию больших дыр.',
      'how_to_play_victory_title': 'Победа',
      'how_to_play_victory_desc':
          'Достигните радиуса 500 (550 в уникальных вселенных) — вселенная закрывается для всех. Обычная: 1-е +5, 2-е +3, 3-е +2 (поглощение −1). Элитная: 1-е +10, 2-е +6, 3-е +4 (поглощение −2). Уникальная: 1-е +15, 2-е +10, 3-е +5 (поглощение −3). Алмазы не ниже 0. Новые игроки начинают с 20 алмазов.',
      'how_to_play_ranks_title': 'Система рангов',
      'how_to_play_ranks_desc':
          'Звёздный ранг (Туманность → Сингулярность) зависит от очков побед, а не от алмазов.\n'
          'Очки даёт только 1-е место. Победы в обучении не считаются.\n'
          'Очки за 1-е место: Обычная +{normal}, Элита +{elite}, Уникальная +{unique}.\n'
          'Пороги: Звёздный {stellar}+ · Нова {nova}+ · Квазар {quasar}+ · Сингулярность {singularity}+.\n'
          'Счётчик побед тоже без обучения. Мировой рейтинг по умолчанию — по очкам побед (Ранг); вкладка Богатство — по алмазам.',
      'how_to_play_currencies_title': 'Валюты',
      'how_to_play_currencies_desc':
          'Новые аккаунты начинают с 20 алмазов. Учебная вселенная бесплатна. Для обычной вселенной нужно минимум 25 алмазов. Алмазы открывают Элитную (100) и Уникальную (200).',
      'how_to_play_events_title': 'Космические события',
      'how_to_play_events_desc':
          'Следите за квазарными штормами, сверхновыми и метеорными дождями.',
      'version_notes_title': 'Что нового',
      'version_current': 'Текущая версия: {version}',
      'version_notes_close': 'Закрыть',
      'version_notes_dont_show': 'Больше не показывать',
      'lobby_version_notes': 'v2.1',
      'v21_section_title': 'Версия 2.1',
      'v21_section_subtitle':
          'Звёздные ранги за очки побед, честный счёт побед (тренировка не считается), сначала обучение, колонка побед, чат лобби, объявления во входящие и живые баннеры.',
      'v21_change_rank_points':
          'Звёздные ранги (Nebula → Singularity) теперь от очков побед — взвешенные 1-е места. По умолчанию: Normal +1, Elite +2, Unique +3. Тренировка даёт 0.',
      'v21_change_training_excluded':
          '1-е место в тренировке больше не добавляет Games Won и очки побед — только Normal, Elite и Unique.',
      'v21_change_tutorial_lock':
          'Новые аккаунты должны завершить тренировочную вселенную, прежде чем откроются другие комнаты (алмазные пороги после этого остаются).',
      'v21_change_leaderboard_wins':
          'В мировом рейтинге есть вкладки Ранг (очки побед) и Богатство (алмазы). Победы = соревновательные 1-е; обучение не считается.',
      'v21_change_rank_dialog':
          'Экран системы рангов в профиле — ваш тир, следующий порог и очки за вселенную.',
      'v21_change_lobby_chat':
          'Чат лобби — переписывайтесь с другими игроками в реальном времени, пока ждёте в лобби.',
      'v21_change_broadcast':
          'Общие объявления — сообщения команды попадают во входящие «Сообщения» каждого игрока и остаются там, пока вы их не прочитаете.',
      'v21_change_live_announce':
          'Живые баннеры объявлений — короткое сообщение команды сразу видят все онлайн.',
      'v21_change_idle':
          'Система AFK / idle обновлена — надёжнее предупреждения в лобби и матче, понятнее обратный отсчёт и исправлены ошибки idle-kick.',
      'v21_change_menus':
          'Меню лобби и профиля обновлены — понятнее раскладка, актуальная статистика и ранг, удобнее переходы между действиями лобби.',
      'v21_change_version_notes':
          'Экран новинок обновлён для v2.1 — ранги, чат, объявления и честные победы сверху. Показывается в лобби, пока не закроете.',
      'v20_section_title': 'Версия 2.0',
      'v20_section_subtitle':
          'Более плотные соревновательные комнаты, честные места и счётчики лобби, алмазы за каждый матч, общие события вселенной и настоящий топ-100.',
      'v20_change_room_capacity':
          'Соревновательные комнаты теперь 10 игроков + 10 ботов — плотнее бои при полной комнате; в одиночку всё ещё полный матч на 20 сущностей (1 + 19 ботов). Обучение остаётся 1 + 19 ботов.',
      'v20_change_ghost_cleanup':
          'Призрачные места от упавших вкладок или принудительного закрытия очищаются автоматически — счётчики лобби остаются честными, без фальшивых полных комнат.',
      'v20_change_seat_free':
          'Смерть или выход освобождают место, чтобы другие могли войти, пока лидер ниже радиуса 280. Возрождение возвращает место, если в комнате ещё есть место.',
      'v20_change_match_rewards':
          'Алмазные награды снова работают каждый матч — повторное открытие вселенной начинает новое поколение матча, поэтому подиум и штрафы за выбытие больше не блокируются после первого claim.',
      'v20_change_cosmic_sync':
          'Сверхновые, метеоритные дожди и их предупреждения теперь синхронизированы сервером — каждый игрок во вселенной видит одно и то же событие в одном месте и в одно время.',
      'v20_change_real_matchmaking':
          'Матчмейкинг и статистика лобби считают только реальных игроков — чище комнаты и точные счётчики вселенных.',
      'v20_change_smarter_bots':
          'Боты перенастроены под новое заполнение 10+10 — более человечный фарм, бой и бегство, чтобы полуботовые комнаты оставались соревновательными.',
      'v20_change_leaderboard_100':
          'Глобальный рейтинг теперь возвращает настоящий топ-100 по алмазам — как уже обещал профиль.',
      'v20_change_unique_theme':
          'Уникальная вселенная получила свой золотисто-янтарный стиль — в лобби и в матче её проще отличить от Обычной (голубой) и Элитной (фиолетовой).',
      'v20_change_version_notes':
          'Экран новинок обновлён для v2.0 — соревновательные комнаты, честные места, синхронные космические события и награды матча сверху.',
      'v19_section_title': 'Версия 1.9',
      'v19_section_subtitle':
          'Дерево навыков, четыре улучшаемые боевые способности, переписка с командой, защита от простоя и более жёсткая серверная экономика.',
      'v19_change_skill_tree':
          'Дерево навыков в лобби — очки навыков с пикового баланса алмазов (1 SP за каждые 20 пиковых ♦). Алмазы не тратятся; улучшения синхронизируются с аккаунтом.',
      'v19_change_boost_upgrades':
          'Ветка ускорения — повышайте макс. скорость, длительность и зарядку до 10 уровня на узел для мягкого, но заметного усиления.',
      'v19_change_teleport':
          'Способность телепорта — прыжок в случайную безопасную точку с коротким щитом по прибытии. Навыки сокращают откат и удлиняют щит.',
      'v19_change_shield':
          'Щит по запросу — временная гравитационная защита отдельно от подбираемых щитов. Навыки сокращают откат и увеличивают длительность.',
      'v19_change_shockwave':
          'Ударная волна — отталкивает меньших ботов и ближайшую материю. Навыки улучшают откат, радиус и силу толчка.',
      'v19_change_messages':
          'Входящие сообщения в лобби — отправляйте отзывы, предложения или баг-репорты и получайте ответы команды; есть значок непрочитанного.',
      'v19_change_idle_protect':
          'Защита от простоя — после бездействия появляется «Вы ещё здесь?»; останьтесь в сети или выйдете, чтобы брошенные сессии очищались.',
      'v19_change_economy_security':
          'Экономика усилена на сервере — алмазы, победы и навыки меняются только через доверенные серверные действия.',
      'v19_change_version_notes':
          'Экран новинок обновлён для v1.9 — дерево навыков, боевые способности и сообщения сверху.',
      'v18_section_title': 'Версия 1.8',
      'v18_section_subtitle':
          'Графика чёрных дыр нового поколения, более длинный темп матчей, умный матчмейкинг, кинематографичные анимации поглощения и крупные исправления производительности в вебе и на мобильных.',
      'v18_change_blackhole_shader':
          'Чёрные дыры полностью переработаны на GPU — наклонный аккреционный диск с турбулентными плазменными нитями, раскалённое фотонное кольцо, абсолютно чёрный горизонт событий и парные релятивистские джеты по реальным научным снимкам.',
      'v18_change_swallow_visuals':
          'Поглощение стало настоящим астрофизическим событием — добычу растягивают приливные силы (спагеттификация), она разрывается на пределе Роша и по спирали уходит в аккреционный диск.',
      'v18_change_merger_rework':
          'Слияния чёрных дыр переработаны по референсу — орбитальный танец, мост материи и финальный коллапс, без зависаний игры.',
      'v18_change_merger_ripples':
          'Гравитационные волны при слиянии смягчены — меньше колец и короче радиус; экран остаётся читаемым при крупных столкновениях.',
      'v18_change_space_background':
          'Космический фон для старших вселенных построен заново — туманности, полоса Млечного Пути, далёкие галактики и кометы для по-настоящему глубокой, пугающей пустоты.',
      'v18_change_web_performance':
          'Исправлено замедление в вебе — фоновые шейдеры теперь создаются один раз и кэшируются, а не пересоздаются каждый кадр; матчи больше не тормозят со временем.',
      'v18_change_meteor_perf':
          'События метеорного дождя больше не роняют частоту кадров.',
      'v18_change_mobile_fixes':
          'Мобильные исправления — устранены отрисовка четверти чёрной дыры на телефонах (Impeller) и вылет при запуске после установки.',
      'v18_change_big_hole_clarity':
          'Гигантские чёрные дыры рисуются чётко — жёсткая круговая кромка и серая дымка над тенью при больших размерах убраны; полная детализация на любом размере.',
      'v18_change_match_pacing':
          'Длительность матчей перенастроена — рост от еды замедлен, чтобы игры ближе к целям: Обучение ~1,5–2,5 мин, Обычная ~4–6, Элита ~5–7, Уникальная ~7–9.',
      'v18_change_smarter_bots':
          'Боты теперь играют на победу как настоящие игроки — рвутся к господству во вселенной, охотятся на лидера или избегают его в зависимости от размера, используют ускорение для побега от сверхновых и завершения матча и меньше колеблются по мере роста.',
      'v18_change_supernova_events':
          'Взрывы сверхновых вернулись, и первый взрыв в Обычной, Элите и Уникальной приходит раньше — лёгкий дополнительный вызов вне тренировочной вселенной.',
      'v18_change_event_warnings':
          'Предупреждения о событиях упрощены — только метеорный дождь и сверхновая предупреждают за 5 секунд; остальные промежуточные баннеры убраны.',
      'v18_change_leader_threshold':
          'Порог входа в комнату снижен с радиуса 300 до 250 — когда лидер вырастает до этого размера, новых игроков направляют в свежий экземпляр вселенной.',
      'v18_change_empty_close':
          'Когда последний реальный игрок уходит, вселенная закрывается сразу — комнаты только с ботами больше не продолжают пустую игру.',
      'v18_change_avatar_hud_only':
          'Фото профиля больше не в центре чёрной дыры — портрет остаётся рядом с именем над ней.',
      'v18_change_rewarded_ads':
          'Видеореклама с наградой за возрождение интегрирована через Google Mobile Ads.',
      'v18_change_version_notes':
          'Экран новинок обновлён для v1.8 — графика, темп матчей и матчмейкинг сверху.',
      'v17_section_title': 'Версия 1.7',
      'v17_section_subtitle':
          'Экономика алмазов, профили игроков, одна активная сессия, живая статистика лобби и обучение для новых космических путешественников.',
      'v17_change_match_rewards':
          'Зарабатывайте и теряйте алмазы по итогам матча — награды до +15/+10/+5 в уникальных вселенных и штрафы −1/−2/−3 за вылет. Результаты сохраняются на сервере.',
      'v17_change_diamond_gates':
          'Новые аккаунты начинают с 20 алмазами. Обучение бесплатно; обычная — 25, элитная — 100, уникальная — 200. Карточки лобби показывают вход, награды и штрафы.',
      'v17_change_profile_hub':
          'Нажмите на аватар в лобби — профиль из 3 вкладок: статистика, скины и магазин. Победы, мировой рейтинг и синхронизация через Supabase.',
      'v17_change_edit_profile':
          'Смените отображаемое имя (3–12 символов) и загрузите фото из галереи (до 5 МБ). Аватары хранятся в Supabase Storage.',
      'v17_change_ingame_avatars':
          'Загруженный аватар виден внутри чёрной дыры в матче. Включение в Настройки → Фото профиля.',
      'v17_change_cosmetic_store':
          'Тратьте золото в магазине на легендарные скины аккреционного диска. Наденьте в профиле — активный скин применяется в игре.',
      'v17_change_global_leaderboard':
          'Топ-100 игроков мира по алмазам в профиле. Своя позиция видна даже вне топ-100.',
      'v17_change_single_session':
          'Один аккаунт — один активный матч. На другом устройстве предупреждение «Игрок уже активен», пока вы не выйдете.',
      'v17_change_live_lobby_stats':
          'Карточки вселенных в лобби показывают живые счётчики: активные вселенные, игроки и боты — через Supabase Realtime.',
      'v17_change_onboarding':
          'Новички сначала проходят обучающую вселенную. В первом матче показываются подсказки по времени.',
      'v17_change_native_splash':
          'Фирменный экран загрузки сразу при запуске, пока язык, авторизация и настройки грузятся в фоне.',
      'v17_change_hud_podium_rewards':
          'Подиум в матче показывает алмазные награды за 1–3 места и ранги соперников.',
      'v17_change_swallow_vfx':
          'Улучшена охота — приливный мост между дырами теперь многослойный Flame-эффект с горячими нитями и искрами у горизонта.',
      'v17_change_victory_fix':
          'Матч заканчивается при радиусе 500 (550 в уникальной) — больше нет зависания при округлении массы на экране.',
      'v17_change_login_fix':
          'Убрана краткая ошибка «not authenticated» после входа через Google. Проверка сессии повторяется, пока JWT не установится.',
      'v17_change_hud_loading':
          'HUD и таблица лидеров появляются раньше — меньше чёрного экрана в начале матча.',
      'v17_change_version_notes':
          'Экран новинок обновлён для v1.7 — экономика алмазов, профили и управление сессиями сверху.',
      'v16_section_title': 'Версия 1.6',
      'v16_section_subtitle':
          'Чёрные дыры в стиле телескопа, серверный матчмейкинг вселенных, умное разделение комнат и честный случайный спавн.',
      'v16_change_server_matchmaking':
          'Обычные, элитные и уникальные вселенные теперь назначаются сервером — из лобби вы попадаете в нужную вселенную.',
      'v16_change_universe_instances':
          'В HUD видно, в какой вселенной вы находитесь — нумерованные серверы вроде Обычная вселенная 1.',
      'v16_change_leader_radius_split':
          'Когда лидер комнаты достигает радиуса 300 или комната полна, новых игроков направляют в следующий экземпляр вселенной.',
      'v16_change_room_lifecycle':
          'Вселенные закрываются после матча; призрачные участники очищаются после сбоев — пустая Вселенная 1 больше не пропускается.',
      'v16_change_abandoned_universe':
          'Если все реальные игроки погибли или вышли, вселенная закрывается автоматически — даже если остались только боты.',
      'v16_change_black_hole_graphics':
          'Чёрные дыры переработаны — теневой силуэт, яркое фотонное кольцо и наклонённый аккреционный диск растут с массой.',
      'v16_change_star_lensing':
          'Звёзды на фоне искривляются, ярче светят и исчезают в вашей тени — гравитационное линзирование.',
      'v16_change_swallow_animations':
          'Новая охота: приливные потоки между дырами, вспышки захвата у фотонного кольца и искры при сближении.',
      'v16_change_food_spaghettify':
          'Астероиды и планеты вытягиваются в ленты только в реальной зоне захвата — ближе и физичнее.',
      'v16_change_gravity_physics':
          'Ньютоновская гравитация 1/r² и дистанция захвата у фотонного кольца — масса и притяжение ощущаются реальнее.',
      'v16_change_universe_tiers':
          'Четыре уровня вселенной играются по-разному — тренировка, обычная, элитная и уникальная со своим темпом.',
      'v16_change_cosmic_events':
          'Сверхновые, метеорные дожди и квазарные штормы меняют поле боя прямо во время матча.',
      'v16_change_hole_merger':
          'Две доминирующие чёрные дыры могут вызвать галактическое слияние — тряска, разрыв ткани и общая масса.',
      'v16_change_random_spawn':
          'Игроки и боты теперь появляются в случайных точках вселенной — больше нет старта всех в центре.',
      'v16_change_revive_spawn':
          'Возрождение тоже переносит вас в случайную безопасную точку, подальше от других игроков и ботов.',
      'v16_change_prey_bot_spawn':
          'Боты-жертвы в простой комнате больше не появляются рядом с экраном — как все, в случайной точке карты.',
      'v16_change_spawn_spacing':
          'Точки появления держат минимальную дистанцию от других игроков и ботов — меньше наложений.',
      'v16_change_version_notes':
          'Экран новинок обновлён для v1.6 — серверный матчмейкинг и жизненный цикл вселенных сверху.',
      'v15_section_title': 'Версия 1.5',
      'v15_section_subtitle':
          'Крупное обновление: честные боты, ранги, защита при спавне и новая система ускорения.',
      'v15_change_match_end':
          'При победе матч останавливается для всех — имя победителя, время и автовозврат в лобби.',
      'v15_change_bot_victory':
          'Боты могут победить при массе 500. После вашего поглощения боты продолжают борьбу.',
      'v15_change_rank_system':
          'Ранговые значки (I–V) по алмазам перед именами — в игре, HUD и итогах матча.',
      'v15_change_spawn_shield':
          '3-секундная защита при входе во вселенную — полная неуязвимость с обратным отсчётом.',
      'v15_change_boost':
          'Ускорение переработано: заряд 10 с, одно нажатие — 5 с скорости без потери массы.',
      'v15_change_spectator':
          'В режиме наблюдения добавлена кнопка прекращения просмотра внизу экрана.',
      'v15_change_bot_badge':
          'Значок бота перенесён в начало имени.',
      'v15_change_global_rank':
          'Ранги отображаются в мировом рейтинге.',
      'v15_change_audio':
          'Играет только официальная тема Quasar Orbit — фоновая музыка по кругу, остальные звуки убраны.',
      'v15_change_bot_fixes':
          'Боты больше не застревают на ~140 массе и корректно завершают матч на 500.',
    },
    'es': {
      'app_title': 'Quasar.io',
      'sign_in_google': 'Iniciar sesión con Google',
      'signing_in': 'Iniciando sesión...',
      'sign_out': 'Cerrar sesión',
      'admin_badge': 'DUEÑO',
      'admin_title': 'Panel de admin',
      'admin_subtitle': 'Resumen en vivo de universos, jugadores y bots',
      'admin_refresh': 'Actualizar',
      'admin_enter_lobby': 'Volver al lobby',
      'admin_open_panel': 'Panel de control',
      'admin_total_players': 'Jugadores en vivo',
      'admin_total_bots': 'Bots en vivo',
      'admin_total_universes': 'Universos activos',
      'admin_active_sessions': 'Sesiones activas',
      'admin_universes_section': 'Universos y dificultad',
      'admin_players_section': 'Estadísticas de jugadores y bots',
      'admin_difficulty': 'Dificultad',
      'admin_difficulty_relaxed': 'Relajada',
      'admin_difficulty_standard': 'Estándar',
      'admin_difficulty_elite': 'Élite',
      'admin_difficulty_unique': 'Única',
      'admin_hunt_priority': 'Dificultad de bots: {pct}%',
      'admin_hunt_priority_short': 'Bots',
      'admin_hunt_priority_howto':
          'La dificultad de bots (0–100%) controla cuán agresivamente cazan a jugadores en lugar de farmear. Más alto = menos huida, mejor puntería, mayor puntuación de presa, boost antes. En la primera partida se aplica ×0.85.',
      'admin_hunt_priority_formula':
          'Puntuación de presa ≈ ventajaTamaño × dificultad / (1 + distancia/radio). Predeterminado de este nivel: {default}%. El control cambia el valor; las nuevas partidas usan el guardado.',
      'admin_hunt_priority_reset': 'Restablecer dificultad de bots',
      'admin_room_tuning_howto':
          'Elige un universo y ajústalo por categoría. Solo afecta a partidas nuevas.',
      'admin_room_tuning_reset': 'Restablecer ajuste de todos los universos',
      'admin_room_tuning_reset_one': 'Restablecer este universo',
      'admin_tune_saving': 'Guardando…',
      'admin_tune_default': 'Predet. {value}',
      'admin_tune_tab_world': 'Mundo',
      'admin_tune_tab_tempo': 'Tempo',
      'admin_tune_tab_objects': 'Objetos',
      'admin_tune_tab_events': 'Eventos',
      'admin_tune_tab_radiation': 'Radiación',
      'admin_tune_tab_bots': 'Bots',
      'admin_tune_tab_live': 'En vivo',
      'admin_live_instances': 'Instancias en vivo',
      'admin_tune_world': 'Mundo y radios',
      'admin_tune_world_hint':
          'Duración y ritmo: mundo más grande / radio de victoria más alto = partidas más largas.',
      'admin_tune_gravity': 'Gravedad de comida',
      'admin_tune_tempo_hint':
          'Los minutos objetivo guían el balance. El boost temprano ayuda a novatos; respawn bajo = más comida.',
      'admin_tune_target_min': 'Duración objetivo (mín)',
      'admin_tune_target_max': 'Duración objetivo (máx)',
      'admin_tune_early_duration': 'Duración early-game',
      'admin_tune_early_growth': 'Boost de crecimiento temprano',
      'admin_tune_respawn_delay': 'Multiplicador de respawn',
      'admin_tune_objects': 'Objetos absorbibles',
      'admin_tune_objects_hint': 'Cantidad 0 = quitar ese tipo.',
      'admin_tune_events': 'Eventos cósmicos',
      'admin_tune_events_short': 'Eventos',
      'admin_tune_events_enabled': 'Supernova y lluvia de meteoros',
      'admin_tune_events_enabled_hint': 'Off = sin supernova/meteoros.',
      'admin_tune_radiation_hint':
          'Presión anti-camp. Más radio / menos idle = sanción más dura. El shrink final aprieta el final.',
      'admin_tune_radiation_radius': 'Radio inicial de radiación',
      'admin_tune_radiation_idle': 'Tiempo idle de radiación',
      'admin_tune_late_radiation_radius': 'Radio de radiación late-game',
      'admin_tune_late_radiation_idle': 'Idle late-game',
      'admin_tune_late_radiation_shrink': 'Velocidad de shrink late-game',
      'admin_tune_bots': 'Bots',
      'admin_tune_bots_human_intro':
          'Salas competitivas: 10 jugadores + 10 bots. Los presets hacen que farmeen, peleen y huyan como jugadores reales.',
      'admin_tune_universe_presets': 'Dificultad del universo',
      'admin_tune_universe_presets_hint':
          'Escalera desde los defaults de este universo — comida, tempo, eventos, radiación y bots juntos. Ranked = balance de compilación.',
      'admin_tune_universe_preset_training': 'Entrenamiento',
      'admin_tune_universe_preset_casual': 'Casual',
      'admin_tune_universe_preset_ranked': 'Ranked',
      'admin_tune_universe_preset_predator': 'Depredador',
      'admin_tune_universe_preset_apex': 'Ápex',
      'admin_tune_universe_balanced_distribute': 'Aplicar escalera equilibrada a todos',
      'admin_tune_universe_balanced_distribute_hint':
          'Simple→Entrenamiento · Normal→Ranked · Elite→Depredador · Unique→Ápex',
      'admin_tune_bot_presets': 'Dificultad de bots',
      'admin_tune_bot_presets_hint':
          'Cinco niveles. Ranked es la base competitiva. El chip activo muestra el perfil actual.',
      'admin_tune_bot_preset_training': 'Entrenamiento',
      'admin_tune_bot_preset_casual': 'Casual',
      'admin_tune_bot_preset_ranked': 'Ranked',
      'admin_tune_bot_preset_predator': 'Depredador',
      'admin_tune_bot_preset_apex': 'Ápex',
      'admin_tune_bot_preset_soft': 'Entrenamiento',
      'admin_tune_bot_preset_human': 'Ranked',
      'admin_tune_bot_preset_aggressive': 'Ápex',
      'admin_tune_bot_ai': 'Comportamiento IA',
      'admin_tune_bot_ai_hint':
          'Menor intervalo = reacciones más humanas. Ratio de presa ~0.92–0.95. Mantén el sesgo humano ~1.1–1.3.',
      'admin_tune_decision_min': 'Intervalo de decisión (mín)',
      'admin_tune_decision_max': 'Intervalo de decisión (máx)',
      'admin_tune_prey_ratio': 'Ratio de tamaño de presa',
      'admin_tune_threat_ratio': 'Ratio de amenaza (huida)',
      'admin_tune_prey_search': 'Rango de búsqueda de presa',
      'admin_tune_food_search': 'Rango de búsqueda de comida',
      'admin_tune_event_awareness': 'Conciencia de eventos',
      'admin_tune_mine_avoidance': 'Evitación de minas',
      'admin_tune_min_hunt_radius': 'Radio mín. antes de cazar',
      'admin_tune_player_bias': 'Sesgo hacia jugadores',
      'admin_tune_intercept_prey': 'Interceptar presa en movimiento',
      'admin_tune_personality': 'Mezcla de personalidades',
      'admin_tune_personality_hint':
          'Pesos relativos de personalidades. No necesitan sumar 100.',
      'admin_tune_personality_coward': 'Cobarde',
      'admin_tune_personality_aggressive': 'Agresivo',
      'admin_tune_personality_opportunist': 'Oportunista',
      'admin_tune_on': 'On',
      'admin_tune_off': 'Off',
      'admin_tune_victory_radius': 'Radio de victoria',
      'admin_tune_player_start_radius': 'Radio inicial del jugador',
      'admin_tune_world_size': 'Tamaño del mundo',
      'admin_tune_food_growth': 'Multiplicador de crecimiento',
      'admin_tune_asteroids': 'Asteroides pequeños/medios',
      'admin_tune_meteorites': 'Meteoritos',
      'admin_tune_planets': 'Planetas',
      'admin_tune_quasar_fragments': 'Fragmentos de quasar',
      'admin_tune_large_asteroids': 'Asteroides grandes',
      'admin_tune_xlarge_asteroids': 'Asteroides muy grandes',
      'admin_tune_giant_asteroids': 'Asteroides gigantes',
      'admin_tune_mines': 'Minas',
      'admin_tune_supernova_interval': 'Intervalo de supernova',
      'admin_tune_supernova_first': 'Retraso primera supernova',
      'admin_tune_meteor_cooldown': 'Retraso primer meteoro',
      'admin_tune_event_growth_cap': 'Crecimiento máx. por evento',
      'admin_tune_supernova_planets': 'Planetas de supernova',
      'admin_tune_bot_start_min': 'Radio inicial bot (mín)',
      'admin_tune_bot_start_max': 'Radio inicial bot (máx)',
      'admin_no_active_universes': 'No hay universos activos ahora',
      'admin_registered_players': 'Jugadores registrados',
      'admin_total_games_won': 'Victorias totales',
      'admin_live_entities': 'Jugadores + bots en vivo',
      'admin_bot_share': 'Cuota de bots en vivo',
      'admin_top_winners': 'Mejores ganadores',
      'admin_no_players_yet': 'Aún no hay jugadores registrados',
      'admin_last_updated': 'Actualizado {time}',
      'select_language': 'Idioma',
      'welcome_cosmic': 'Cruza el horizonte de eventos',
      'login_atmosphere':
          'Absorbe materia. Supera rivales. Domina la arena del espacio profundo.',
      'lobby_brand_eyebrow': 'Arena del espacio profundo',
      'lobby_choose_universe': 'Elige tu universo',
      'store_tab_skins': 'Aspectos',
      'store_tab_trails': 'Rastros',
      'store_tab_emotes': 'Emotes',
      'store_buy': 'Comprar',
      'store_equip': 'Equipar',
      'store_owned': 'Adquirido',
      'store_insufficient_gold': 'Oro insuficiente',
      'event_quasar_storm': '¡Tormenta de cuásar!',
      'event_supernova': '¡Erupción de supernova!',
      'event_supernova_warning': '¡Alerta: supernova en {s}s!',
      'event_meteor_shower': '¡Lluvia de meteoros!',
      'event_meteor_warning': '¡Alerta: lluvia de meteoros en {s}s!',
      'event_black_hole_merge': '¡Fusión de agujeros negros!',
      'merge_stage_tidal': '¡Deformación de marea y transferencia de masa!',
      'merge_stage_dance': '¡La danza — ondas gravitacionales masivas!',
      'merge_stage_ringdown': '¡Fusión y ringdown — un solo cuásar!',
      'event_cosmic_mine': '¡Detonación de mina cósmica!',
      'event_cosmic_dust_welcome': 'Lluvia de polvo cósmico — ¡crecimiento gratis!',
      'first_match_hint_move':
          'Arrastra en cualquier lugar para dirigir tu agujero negro',
      'first_match_hint_absorb':
          'Absorbe asteroides y agujeros más pequeños para crecer',
      'first_match_hint_grow':
          'Crece rápido — ¡el escudo inicial sigue activo!',
      'lobby_recommended_room': 'RECOMENDADO',
      'spawn_protection_label': 'Escudo de protección inicial',
      'game_over_title': 'Colapso del horizonte de eventos',
      'game_over_subtitle': 'Tu masa fue consumida por un vacío mayor',
      'game_over_watch_ad_revive': 'Ver anuncio para revivir',
      'game_over_quit': 'Salir',
      'game_over_watch_match': 'Ver partida',
      'spectator_stop_watching': 'Dejar de ver',
      'game_over_peak_mass': 'Masa máxima',
      'game_over_diamond_penalty':
          '−{diamonds} diamante al salir (nunca bajo 0)',
      'game_over_play_again': 'Jugar de nuevo',
      'game_over_return_lobby': 'Volver al lobby',
      'match_quit_confirm_title': '¿Salir del partido?',
      'match_quit_confirm_message':
          '¿Seguro que quieres salir? Perderás {diamonds} diamante(s).',
      'match_quit_confirm_stay': 'Quedarme',
      'match_quit_confirm_leave': 'Salir',
      'leaderboard_title': 'CLASIFICACIÓN',
      'hud_population_players': 'Jugadores',
      'hud_population_bots': 'Bots',
      'leaderboard_you': 'Tú',
      'leaderboard_name': 'Nombre',
      'leaderboard_mass': 'Masa',
      'victory_title': '¡Conquistaste el Universo!',
      'victory_subtitle': 'El cosmos se inclina ante tu gravedad',
      'victory_time': 'Tiempo de victoria: {time}',
      'victory_reward': '+{diamonds} diamantes · +1 victoria',
      'victory_return_lobby': 'Volver al lobby con gloria',
      'reward_double_cta': 'Duplicar recompensa',
      'reward_double_micro': '+{extra} diamantes extra (total {total})',
      'reward_double_done': '2× reclamado · +{total} diamantes',
      'reward_double_loading': 'Cargando anuncio…',
      'reward_double_claiming': 'Reclamando bonificación…',
      'reward_double_claim_wait': 'Guardando recompensa… inténtalo de nuevo',
      'reward_double_ad_failed': 'Anuncio no disponible. Tu recompensa base está segura.',
      'reward_double_grant_failed': 'Bonus pendiente — toca para reintentar (sin nuevo anuncio)',
      'reward_double_retry_grant': 'Reclamar bonus',
      'reward_double_unavailable': 'Anuncios no disponibles en este dispositivo',
      'frozen_title': 'Universo conquistado',
      'frozen_champion': '{name} conquistó el universo en {time}',
      'match_champion_result': '{name} ganó la partida en {time}',
      'frozen_placement_reward': 'Puesto #{place}: +{diamonds} diamantes',
      'frozen_room_closed': 'El universo se ha cerrado.',
      'match_returning_lobby': 'Volviendo al lobby en {seconds} s…',
      'lobby_diamonds': 'Diamantes',
      'rank_tier_nebula': 'Nebulosa',
      'rank_tier_stellar': 'Estelar',
      'rank_tier_nova': 'Nova',
      'rank_tier_quasar': 'Cuásar',
      'rank_tier_singularity': 'Singularidad',
      'lobby_gold': 'Oro',
      'lobby_play': 'Jugar',
      'lobby_stat_universes': '{count} universos',
      'lobby_stat_players': '{count} jugadores',
      'lobby_stat_bots': '{count} bots',
      'lobby_stat_universes_short': 'Universos',
      'lobby_stat_players_short': 'Jugadores',
      'lobby_stat_bots_short': 'Bots',
      'lobby_room_fill_hint':
          'Cada universo abierto: hasta 10 jugadores reales, bots hasta 20.',
      'lobby_low_population_hint':
          'Pocos jugadores reales — los bots completan el resto de la partida.',
      'lobby_stat_solo_players': 'Solo',
      'room_entry_free': 'Entrada: Gratis',
      'room_entry_cost': 'Necesitas al menos {count}',
      'room_entry_cost_prefix': 'Necesitas al menos {count} ',
      'room_entry_cost_suffix': '',
      'room_rewards_label': 'Premios',
      'room_elimination_label': 'Eliminación',
      'room_elimination_none': 'sin pérdida',
      'room_simple_title': 'Universo Tutorial',
      'lobby_first_login_lock': 'Completa el tutorial primero',
      'room_instance_normal': 'Universo Normal {number}',
      'room_instance_elite': 'Universo Élite {number}',
      'room_instance_unique': 'Universo Único {number}',
      'matchmaking_error': 'No se pudo unir a la sala. Inténtalo de nuevo.',
      'player_already_active_title': 'Jugador ya activo',
      'player_already_active_message':
          'Esta cuenta ya está en una partida en otro dispositivo. Termina o sal de esa partida primero.',
      'player_already_active_ok': 'Aceptar',
      'idle_session_title': '¿Sigues ahí?',
      'idle_session_message':
          'Sin actividad. Cierre de sesión en {seconds} segundos.',
      'idle_session_stay': 'Seguir conectado',
      'idle_match_result_title': 'Volviendo al lobby',
      'idle_match_result_message':
          'Sin acción en la pantalla de resultados. Vuelves al lobby en {seconds} segundos.',
      'idle_match_result_stay': 'Quedarse en esta pantalla',
      'idle_match_result_hint':
          'Si estás inactivo 10 segundos, empieza una cuenta atrás de 10 s y vuelves al lobby.',
      'room_simple_desc':
          'Entrada: Gratis · Solo bots tutorial\nPremios +3 · +2 · +1 · Sin penalización · asteroides grandes',
      'room_normal_title': 'Universos Normales',
      'room_normal_desc':
          'Necesitas al menos 25\nPremios +5 · +3 · +2 · Eliminación -1',
      'room_elite_title': 'Universos Élite',
      'room_elite_desc':
          'Necesitas al menos 100\nPremios +10 · +6 · +4 · Eliminación -2',
      'room_unique_title': 'Universos Únicos',
      'room_unique_desc':
          'Necesitas al menos 200\nPremios +15 · +10 · +5 · Eliminación -3',
      'room_requires_100': 'Necesitas al menos 100',
      'room_requires_300': 'Necesitas al menos 200',
      'room_requires_diamonds': 'Necesitas al menos {count}',
      'profile_stats_tab': 'Estadísticas',
      'profile_store_tab': 'Tienda',
      'feature_coming_soon_badge': 'Próximamente',
      'feature_coming_soon_title': 'En construcción',
      'feature_coming_soon_body':
          'Esta sección se forja en el espacio profundo. Cosméticos y tienda abrirán pronto.',
      'profile_games_won': 'Partidas ganadas',
      'profile_global_rank': 'Ranking mundial',
      'profile_rank_system': 'Sistema de rangos',
      'rank_system_intro':
          'Las estrellas junto al nombre son tu rango. Sube con puntos de victoria (1.ºs ponderados), no con diamantes.',
      'rank_system_your_rank': 'TU RANGO',
      'rank_system_your_points': '{points} puntos de victoria',
      'rank_system_next': 'Siguiente: {tier} desde {points}+',
      'rank_system_ladder_title': 'ESCALERA DE ESTRELLAS',
      'rank_system_current_badge': 'Estás aquí',
      'rank_system_earn_title': 'PUNTOS POR 1.º LUGAR',
      'rank_system_points_per_win': '+{n}',
      'rank_system_points_none': 'No cuenta',
      'rank_system_note':
          'Solo el 1.º en Normal / Élite / Única suma puntos y victorias. El tutorial no cuenta. Rango ordena por puntos; Riqueza por diamantes.',
      'rank_system_close': 'Entendido',
      'global_rank_player': 'Jugador',
      'global_rank_wins': 'Victorias',
      'global_rank_points': 'Pts',
      'global_rank_tab_rank': 'Rango',
      'global_rank_tab_wealth': 'Riqueza',
      'global_rank_blurb':
          'Rango: puntos de victoria. Riqueza: diamantes. Victorias = 1.ºs competitivos (sin Tutorial).',
      'global_rank_blurb_rank':
          'Ordenado por puntos de victoria (luego victorias). Solo cuenta el 1.º en Normal / Élite / Única — el Tutorial nunca.',
      'global_rank_blurb_wealth':
          'Ordenado por diamantes (luego victorias). Las estrellas junto al nombre siguen mostrando tu rango competitivo.',
      'global_rank_your_position': 'TU POSICIÓN',
      'global_rank_empty': 'Aún no hay clasificación.',
      'global_rank_error': 'No se pudo cargar la clasificación.',
      'global_rank_retry': 'Reintentar',
      'profile_legendary_skins': 'Aspectos legendarios',
      'skin_default': 'Destello solar',
      'skin_frost': 'Velo helado',
      'skin_ember': 'Núcleo de brasa',
      'skin_pulsar': 'Púlsar azul',
      'skin_nebula': 'Nebulosa púrpura',
      'skin_plasma': 'Plasma RGB',
      'skin_void': 'Vacío oscuro',
      'skin_quasar': 'Cuásar verde',
      'skin_eclipse': 'Eclipse solar',
      'skin_supernova': 'Supernova roja',
      'skin_aurora': 'Aurora boreal',
      'skin_binary': 'Estrella binaria',
      'skin_singularity': 'Singularidad Prime',
      'skin_celestial': 'Corona celestial',
      'skin_picker_title': 'Aspectos de agujero negro',
      'skin_picker_subtitle': 'Elige la apariencia de tu disco de acreción',
      'skin_picker_equipped': 'Equipado',
      'skin_picker_locked': 'Bloqueado',
      'skin_picker_free': 'Gratis',
      'trail_comet': 'Chorro de plasma',
      'trail_nebula': 'Estela de lente',
      'trail_quantum': 'Onda gravitacional',
      'trail_picker_section': 'Rastros de movimiento',
      'trail_picker_subtitle': 'Toca un rastro adquirido para equiparlo',
      'trail_picker_empty':
          'Obtén rastros en la tienda para equiparlos aquí.',
      'trail_picker_owned': 'Adquirido',
      'store_trail_equip_hint': 'Equipa este rastro desde la pestaña Apariencia.',
      'store_trail_claim_success':
          '¡Rastro desbloqueado! Equípalo desde la pestaña Apariencia.',
      'emote_wave': 'Ola cósmica',
      'emote_burst': 'Explosión de supernova',
      'emote_void': 'Risa del vacío',
      'store_purchase_success': '¡Compra exitosa!',
      'store_equip_success': '¡Equipado!',
      'store_error': 'Algo salió mal',
      'error_generic': 'Algo salió mal. Inténtalo de nuevo.',
      'sign_in_error': 'Error al iniciar sesión. Inténtalo de nuevo.',
      'profile_edit': 'Editar perfil',
      'profile_edit_name': 'Nombre visible',
      'profile_edit_avatar': 'Toca para cambiar la foto',
      'profile_edit_save': 'Guardar',
      'profile_edit_cancel': 'Cancelar',
      'profile_username_taken': 'Este nombre ya está en uso',
      'profile_username_invalid':
          'El nombre debe tener 3–12 caracteres (letras, números, espacios)',
      'profile_update_success': '¡Perfil actualizado!',
      'profile_update_error': 'No se pudo actualizar el perfil',
      'lobby_how_to_play': 'Sobrevive',
      'lobby_skill_tree': 'Matriz de poder',
      'lobby_version_notes_hint': 'Registro de transmisión',
      'skill_tree_title': 'Árbol de habilidades',
      'skill_sp_available': 'SP disponibles',
      'skill_sp_earned': 'Gastados / Ganados',
      'skill_sp_rules':
          'Cada {n} diamantes pico desbloquean 1 SP. Los diamantes no se gastan. Siguiente SP en {next} ♦.',
      'skill_branch_boost': 'Impulso',
      'skill_branch_teleport': 'Teletransporte',
      'skill_branch_shield': 'Escudo',
      'skill_branch_shockwave': 'Onda de choque',
      'skill_level': 'Nv',
      'skill_upgrade': '+1 SP',
      'skill_maxed': 'MAX',
      'skill_value_now': 'Ahora',
      'skill_error_no_sp': 'No hay puntos de habilidad',
      'skill_error_max': 'Esta habilidad ya está al máximo',
      'skill_error_generic': 'No se pudo mejorar la habilidad',
      'skill_node_boost_speed': 'Velocidad de impulso',
      'skill_node_boost_speed_desc': 'Mayor velocidad máxima al impulsar',
      'skill_node_boost_duration': 'Duración del impulso',
      'skill_node_boost_duration_desc': 'El impulso dura más',
      'skill_node_boost_charge': 'Carga del impulso',
      'skill_node_boost_charge_desc': 'Recarga más rápida entre impulsos',
      'skill_node_teleport_cd': 'Enfriamiento de teletransporte',
      'skill_node_teleport_cd_desc': 'Menos espera entre teletransportes',
      'skill_node_teleport_shield': 'Escudo de llegada',
      'skill_node_teleport_shield_desc': 'Más protección tras teletransportar',
      'skill_node_shield_cd': 'Enfriamiento de escudo',
      'skill_node_shield_cd_desc': 'Menos espera entre escudos',
      'skill_node_shield_duration': 'Duración del escudo',
      'skill_node_shield_duration_desc': 'El escudo activo dura más',
      'skill_node_shockwave_cd': 'Enfriamiento de onda',
      'skill_node_shockwave_cd_desc': 'Menos espera entre ondas',
      'skill_node_shockwave_range': 'Alcance de onda',
      'skill_node_shockwave_range_desc': 'Empuja desde más lejos',
      'skill_node_shockwave_power': 'Potencia de onda',
      'skill_node_shockwave_power_desc':
          'Empuje más fuerte a agujeros pequeños y materia',
      'settings_title': 'Configuración',
      'settings_sound_title': 'Sonido',
      'settings_music': 'Quasar Orbit Theme',
      'settings_music_desc': 'Música temática oficial de Quasar.io',
      'settings_music_volume': 'Volumen de música',
      'settings_haptics': 'Vibración',
      'settings_haptics_desc': 'Retroalimentación háptica en colisiones y eventos',
      'settings_audio_missing': 'No se pudo cargar el archivo de audio.',
      'settings_display_section': 'Pantalla',
      'settings_show_own_name': 'Mi nombre',
      'settings_show_own_name_desc': 'Mostrar tu nombre sobre tu agujero negro',
      'settings_show_other_names': 'Otros nombres',
      'settings_show_other_names_desc':
          'Mostrar nombres de otros jugadores y bots sobre agujeros negros',
      'settings_show_profile_pictures': 'Fotos de perfil',
      'settings_show_profile_pictures_desc':
          'Mostrar fotos de perfil dentro de los agujeros negros',
      'settings_support_section': 'Soporte',
      'admin_nav_messages': 'Mensajes',
      'admin_page_messages_title': 'Mensajes',
      'admin_page_messages_desc':
          'Lee opiniones, responde uno a uno o envía a todos.',
      'msg_player_title': 'Mensajes',
      'msg_tab_inbox': 'Bandeja',
      'msg_tab_compose': 'Escribir',
      'msg_open_inbox': 'Bandeja',
      'msg_write_to_admin': 'Escribir al admin',
      'msg_category_feedback': 'Opinión',
      'msg_category_suggestion': 'Sugerencia',
      'msg_category_bug': 'Error',
      'msg_category_direct': 'Directo',
      'msg_category_broadcast': 'Difusión',
      'msg_filter_open': 'Abiertos',
      'msg_filter_closed': 'Cerrados',
      'msg_filter_all': 'Todos',
      'msg_filter_category_all': 'Todos los tipos',
      'msg_broadcast': 'Difusión',
      'msg_send_direct': 'Mensaje a jugador',
      'msg_search_player': 'Buscar jugador…',
      'msg_to_player': 'Para: {name}',
      'msg_subject_hint': 'Asunto',
      'msg_body_hint': 'Escribe tu mensaje…',
      'msg_reply_hint': 'Escribe una respuesta…',
      'msg_send': 'Enviar',
      'msg_send_to_admin': 'Enviar al admin',
      'msg_empty_inbox': 'Aún no hay mensajes.',
      'msg_empty_player_inbox':
          'Aún no hay mensajes. Puedes escribir al admin cuando quieras.',
      'msg_migration_hint':
          'Mensajes aún no disponibles. Ejecuta migration_admin_messaging.sql en Supabase.',
      'msg_close_thread': 'Cerrar',
      'msg_reopen_thread': 'Reabrir',
      'msg_from_admin': 'Admin',
      'msg_from_player': 'Jugador',
      'msg_from_you': 'Tú',
      'msg_compose_hint':
          'Opinión, sugerencia o error. El admin responderá aquí.',
      'msg_sent_ok': 'Mensaje enviado.',
      'msg_broadcast_sent': 'Difusión enviada a {count} jugadores.',
      'msg_broadcast_readonly': 'No se puede responder a las difusiones.',
      'how_to_play_title': 'Cómo jugar',
      'how_to_play_close': 'Entendido',
      'how_to_play_move_title': 'Movimiento',
      'how_to_play_move_desc':
          'Toca cualquier parte de la pantalla y arrastra para dirigir tu agujero negro.',
      'how_to_play_absorb_title': 'Crece tu masa',
      'how_to_play_absorb_desc':
          'Absorbe asteroides, planetas y jugadores más pequeños. ¡Evita agujeros negros mayores!',
      'how_to_play_boost_title': 'Impulso',
      'how_to_play_boost_desc':
          'La energía carga en 10 s. Toca cuando esté llena: 5 s de velocidad sin perder masa.',
      'how_to_play_link_title': 'Enlace binario',
      'how_to_play_link_desc':
          'Toca Enlace cerca de otro jugador para formar un vínculo gravitacional.',
      'how_to_play_shield_title': 'Escudo',
      'how_to_play_shield_desc':
          'Recoge escudos para ignorar temporalmente la gravedad de agujeros mayores.',
      'how_to_play_victory_title': 'Victoria',
      'how_to_play_victory_desc':
          'Alcanza radio 500 (550 en universos Únicos) — el universo se cierra para todos. Normal: 1.º +5, 2.º +3, 3.º +2 (eliminación −1). Élite: 1.º +10, 2.º +6, 3.º +4 (eliminación −2). Única: 1.º +15, 2.º +10, 3.º +5 (eliminación −3). Diamantes nunca bajo 0. Nuevos jugadores empiezan con 20 diamantes.',
      'how_to_play_ranks_title': 'Sistema de rangos',
      'how_to_play_ranks_desc':
          'Tu rango de estrellas (Nebulosa → Singularidad) se basa en puntos de victoria, no en diamantes.\n'
          'Solo el 1.º lugar suma puntos. Las victorias del tutorial no cuentan.\n'
          'Puntos por 1.º: Normal +{normal}, Élite +{elite}, Única +{unique}.\n'
          'Umbrales: Estelar {stellar}+ · Nova {nova}+ · Cuásar {quasar}+ · Singularidad {singularity}+.\n'
          'Victorias también excluye el Tutorial. El ranking mundial ordena por puntos (Rango) por defecto; Riqueza ordena por diamantes.',
      'how_to_play_currencies_title': 'Monedas',
      'how_to_play_currencies_desc':
          'Las cuentas nuevas empiezan con 20 diamantes. Universo Tutorial es gratis. Universos normales: al menos 25 diamantes. Los diamantes desbloquean Élite (100) y Única (200).',
      'how_to_play_events_title': 'Eventos cósmicos',
      'how_to_play_events_desc':
          'Atento a tormentas de cuásar, supernovas y lluvias de meteoros.',
      'version_notes_title': 'Novedades',
      'version_current': 'Versión actual: {version}',
      'version_notes_close': 'Cerrar',
      'version_notes_dont_show': 'No volver a mostrar',
      'lobby_version_notes': 'v2.1',
      'v21_section_title': 'Versión 2.1',
      'v21_section_subtitle':
          'Rangos con estrellas por puntos de victoria, victorias más justas (entrenamiento excluido), bloqueo de tutorial, victorias en el ranking, chat del lobby, anuncios en bandeja y banners en vivo.',
      'v21_change_rank_points':
          'Los rangos con estrellas (Nebula → Singularity) ahora vienen de puntos de victoria — 1.º lugares ponderados. Por defecto: Normal +1, Elite +2, Unique +3. El entrenamiento da 0.',
      'v21_change_training_excluded':
          'Quedar 1.º en entrenamiento ya no suma Games Won ni puntos de victoria — solo cuentan Normal, Elite y Unique.',
      'v21_change_tutorial_lock':
          'Las cuentas nuevas deben completar el universo de entrenamiento antes de desbloquear otras salas (los requisitos de diamantes siguen después).',
      'v21_change_leaderboard_wins':
          'El ranking mundial tiene pestañas Rango (puntos) y Riqueza (diamantes). Victorias = 1.º competitivos; el Tutorial nunca cuenta.',
      'v21_change_rank_dialog':
          'Pantalla del sistema de rangos en el perfil — tu nivel, el siguiente umbral y puntos por universo.',
      'v21_change_lobby_chat':
          'Chat del lobby — habla en tiempo real con otros jugadores mientras esperas en el lobby.',
      'v21_change_broadcast':
          'Anuncios generales — los avisos del equipo llegan a la bandeja de Mensajes de cada jugador y permanecen hasta que los leas.',
      'v21_change_live_announce':
          'Banners de anuncio en vivo — cuando el equipo envía un aviso corto, todos online lo ven al instante.',
      'v21_change_idle':
          'Sistema AFK / idle actualizado — avisos de lobby y partida más fiables, cuenta atrás más clara y varios fallos de idle-kick corregidos.',
      'v21_change_menus':
          'Menús del lobby y del perfil renovados — diseño más claro, stats y rango actualizados, y navegación más fluida entre acciones del lobby.',
      'v21_change_version_notes':
          'Novedades renovadas para la v2.1 — rangos, chat, anuncios y victorias justas arriba. Aparece en el lobby hasta que lo cierres.',
      'v20_section_title': 'Versión 2.0',
      'v20_section_subtitle':
          'Salas competitivas más densas, asientos y contadores de lobby más justos, diamantes en cada partida, eventos de universo compartidos y un top 100 real.',
      'v20_change_room_capacity':
          'Las salas competitivas son ahora 10 jugadores + 10 bots — combates más llenos a sala completa; solo sigues con un partido de 20 entidades (1 + 19 bots). El entrenamiento sigue en 1 + 19 bots.',
      'v20_change_ghost_cleanup':
          'Los asientos fantasma de pestañas caídas o cierres forzados se limpian solos — los contadores del lobby se mantienen honestos sin salas llenas falsas.',
      'v20_change_seat_free':
          'Morir o salir libera tu asiento para que otros entren mientras el líder esté bajo radio 280. Revivir recupera un asiento si aún hay sitio.',
      'v20_change_match_rewards':
          'Las recompensas de diamantes vuelven a funcionar en cada partida — reabrir un universo inicia una nueva generación de match, así que podio y eliminaciones ya no se bloquean tras el primer claim.',
      'v20_change_cosmic_sync':
          'Las supernovas, lluvias de meteoros y sus avisos ahora van sincronizados por el servidor — todos en el universo ven el mismo evento en el mismo sitio y a la misma hora.',
      'v20_change_real_matchmaking':
          'El matchmaking y las estadísticas del lobby solo cuentan jugadores reales — salas más limpias y conteos de universos correctos.',
      'v20_change_smarter_bots':
          'Bots retocados para el nuevo llenado 10+10 — farmeo, pelea y huida más humanos para que las salas a medias de bots sigan sintiéndose competitivas.',
      'v20_change_leaderboard_100':
          'El ranking global ahora devuelve un top 100 real por diamantes — como ya prometía el perfil.',
      'v20_change_unique_theme':
          'El Universo Único tiene ahora su propio estilo dorado/ámbar — más fácil de distinguir del Normal (cian) y el Élite (púrpura) en el lobby y en partida.',
      'v20_change_version_notes':
          'Pantalla de novedades renovada para la v2.0 — salas competitivas, asientos justos, eventos cósmicos sincronizados y recompensas de partida arriba.',
      'v19_section_title': 'Versión 1.9',
      'v19_section_subtitle':
          'Árbol de habilidades, cuatro habilidades de combate mejorables, mensajes con el equipo, protección ante inactividad y una economía más segura en el servidor.',
      'v19_change_skill_tree':
          'Árbol de habilidades en el lobby — gana puntos de habilidad con tu pico de diamantes (1 SP por cada 20 ♦ pico). Los diamantes no se gastan; las mejoras se sincronizan con tu cuenta.',
      'v19_change_boost_upgrades':
          'Rama de impulso — sube velocidad máxima, duración activa y recarga hasta nivel 10 por nodo, con mejoras suaves pero notables.',
      'v19_change_teleport':
          'Habilidad de teletransporte — salta a un punto seguro aleatorio con un escudo breve al llegar. Las skills reducen la recarga y alargan el escudo.',
      'v19_change_shield':
          'Escudo a demanda — protección gravitatoria temporizada aparte de los escudos recogibles. Las skills acortan la recarga y alargan la duración.',
      'v19_change_shockwave':
          'Habilidad de onda de choque — empuja bots más pequeños y materia cercana. Las skills mejoran recarga, alcance y fuerza del empujón.',
      'v19_change_messages':
          'Bandeja de mensajes en el lobby — envía opiniones, sugerencias o reportes de errores y recibe respuestas del equipo; incluye badge de no leídos.',
      'v19_change_idle_protect':
          'Protección ante inactividad — tras estar idle aparece «¿Sigues ahí?»; permanece conectado o se cierra la sesión para limpiar sesiones abandonadas.',
      'v19_change_economy_security':
          'Economía reforzada en el servidor — diamantes, victorias y upgrades solo cambian mediante acciones de servidor de confianza.',
      'v19_change_version_notes':
          'Pantalla de novedades renovada para la v1.9 — árbol de habilidades, combate y mensajes arriba.',
      'v18_section_title': 'Versión 1.8',
      'v18_section_subtitle':
          'Gráficos de agujero negro de nueva generación, partidas más largas, matchmaking más inteligente, animaciones de engullida cinematográficas y grandes mejoras de rendimiento en web y móvil.',
      'v18_change_blackhole_shader':
          'Agujeros negros reconstruidos desde cero en la GPU — disco de acreción inclinado con filamentos de plasma turbulentos, anillo de fotones al rojo blanco, horizonte de sucesos completamente negro y jets relativistas gemelos, basados en imágenes científicas reales.',
      'v18_change_swallow_visuals':
          'Engullir es ahora un evento astrofísico real — la presa se estira por fuerzas de marea (espaguetización), se desgarra en el límite de Roche y cae en espiral al disco de acreción.',
      'v18_change_merger_rework':
          'Fusiones de agujeros negros rediseñadas según la referencia — danza orbital, puente de materia y colapso final, sin congelar el juego.',
      'v18_change_merger_ripples':
          'Ondas gravitacionales de fusión suavizadas — menos anillos y menor alcance; la pantalla sigue legible en colisiones grandes.',
      'v18_change_space_background':
          'Fondo de espacio profundo reconstruido para universos superiores — nebulosas, la banda de la Vía Láctea, galaxias lejanas y cometas para un vacío realmente profundo y sobrecogedor.',
      'v18_change_web_performance':
          'Corregida la ralentización en web — los shaders de fondo se crean una vez y se cachean en lugar de recrearse cada fotograma; las partidas ya no se vuelven lentas con el tiempo.',
      'v18_change_meteor_perf':
          'Los eventos de lluvia de meteoros ya no hunden la tasa de fotogramas.',
      'v18_change_mobile_fixes':
          'Correcciones móviles — resueltos el agujero negro renderizado a un cuarto en teléfonos (Impeller) y el cierre al abrir tras instalar.',
      'v18_change_big_hole_clarity':
          'Los agujeros negros gigantes se dibujan nítidos — eliminados el borde circular duro y la neblina gris sobre la sombra en tamaños grandes; detalle completo en todos los tamaños.',
      'v18_change_match_pacing':
          'Duración de partida reajustada — el crecimiento por comida se ralentizó para acercarse a los objetivos: Entrenamiento ~1,5–2,5 min, Normal ~4–6, Élite ~5–7, Único ~7–9.',
      'v18_change_smarter_bots':
          'Los bots ahora juegan para ganar como jugadores reales — buscan dominar el universo, cazan al líder o lo evitan según su tamaño, usan el impulso para escapar de supernovas y cerrar partidas, y dudan menos a medida que crecen.',
      'v18_change_supernova_events':
          'Las explosiones de supernova han vuelto y el primer estallido llega antes en Normal, Élite y Único — un desafío extra suave fuera del universo de entrenamiento.',
      'v18_change_event_warnings':
          'Avisos de eventos simplificados — solo lluvia de meteoros y supernovas avisan 5 segundos antes; el resto de banners intermedios se eliminó.',
      'v18_change_leader_threshold':
          'Umbral de entrada a la sala bajado de radio 300 a 250 — cuando el líder crece tanto, los nuevos jugadores van a una instancia fresca del universo.',
      'v18_change_empty_close':
          'Cuando se va el último jugador real, el universo se cierra al instante; las salas solo con bots ya no siguen vacías.',
      'v18_change_avatar_hud_only':
          'Las fotos de perfil ya no aparecen en el centro del agujero negro — el retrato se queda junto a la etiqueta del nombre encima.',
      'v18_change_rewarded_ads':
          'Anuncios de video con recompensa para revivir integrados con Google Mobile Ads.',
      'v18_change_version_notes':
          'Pantalla de novedades renovada para la v1.8 — gráficos, ritmo de partida y matchmaking arriba.',
      'v17_section_title': 'Versión 1.7',
      'v17_section_subtitle':
          'Economía de diamantes, perfiles de jugador, una sesión por dispositivo, estadísticas en vivo del lobby y guía para nuevos viajeros cósmicos.',
      'v17_change_match_rewards':
          'Gana y pierde Diamantes según el resultado — recompensas de podio hasta +15/+10/+5 en universos Únicos y penalizaciones de −1/−2/−3 al ser eliminado. Resultados guardados en servidor.',
      'v17_change_diamond_gates':
          'Cuentas nuevas empiezan con 20 Diamantes. Tutorial gratis; Normal 25, Élite 100, Único 200. Las tarjetas del lobby muestran entrada, recompensas y penalizaciones.',
      'v17_change_profile_hub':
          'Toca tu avatar en el lobby para un perfil de 3 pestañas: Estadísticas, Aspectos y Tienda. Victorias, rango global y sincronización en vivo vía Supabase.',
      'v17_change_edit_profile':
          'Cambia tu nombre visible (3–12 caracteres) y sube una foto de perfil desde la galería (máx. 5 MB). Avatares en Supabase Storage.',
      'v17_change_ingame_avatars':
          'Tu avatar subido aparece dentro de tu agujero negro en partida. Actívalo en Ajustes → Fotos de perfil.',
      'v17_change_cosmetic_store':
          'Gasta Oro en la Tienda para desbloquear aspectos legendarios del disco de acreción. Equípalos desde el perfil — el activo se aplica en juego.',
      'v17_change_global_leaderboard':
          'Ve el top 100 mundial por Diamantes desde tu perfil. Tu posición también si estás fuera del top 100.',
      'v17_change_single_session':
          'Cada cuenta solo puede estar en una partida activa. Otro dispositivo muestra «Jugador ya activo» hasta que salgas.',
      'v17_change_live_lobby_stats':
          'Las tarjetas de universo en el lobby muestran conteos en tiempo real: universos activos, jugadores y bots — vía Supabase Realtime.',
      'v17_change_onboarding':
          'Los nuevos deben completar el Universo Tutorial primero. La primera partida muestra pistas temporizadas.',
      'v17_change_native_splash':
          'Pantalla de inicio con marca al abrir, mientras idioma, auth y ajustes cargan en segundo plano.',
      'v17_change_hud_podium_rewards':
          'El podio en partida muestra recompensas de Diamante para 1.º, 2.º y 3.º y rangos de rivales.',
      'v17_change_swallow_vfx':
          'Visuales de caza mejorados — el puente de marea entre agujeros negros es ahora un efecto Flame en capas con filamentos calientes.',
      'v17_change_victory_fix':
          'La partida termina al alcanzar radio 500 (550 en Único) — sin congelarse cuando la masa mostrada redondea al límite.',
      'v17_change_login_fix':
          'Corregido un breve error «not authenticated» tras Google. La sesión reintenta mientras el JWT se estabiliza.',
      'v17_change_hud_loading':
          'El HUD y la tabla de líderes aparecen antes — menos pantalla negra al inicio de partida.',
      'v17_change_version_notes':
          'Pantalla de novedades renovada para v1.7 — economía de diamantes, perfiles y sesiones arriba.',
      'v16_section_title': 'Versión 1.6',
      'v16_section_subtitle':
          'Agujeros negros al estilo telescopio, emparejamiento de universos en servidor, división inteligente de salas y spawns aleatorios justos.',
      'v16_change_server_matchmaking':
          'Los universos Normal, Élite y Único usan ahora asignación de sala en servidor — entras al universo correcto desde el lobby.',
      'v16_change_universe_instances':
          'El HUD muestra en qué universo estás — instancias numeradas como Universo Normal 1 o Universo Élite 2.',
      'v16_change_leader_radius_split':
          'Cuando el líder de la sala alcanza radio 300 o la sala está llena, los nuevos jugadores van a la siguiente instancia.',
      'v16_change_room_lifecycle':
          'Los universos se cierran al terminar la partida; miembros fantasma se limpian tras cierres forzados — ya no se salta Universo 1 vacío.',
      'v16_change_abandoned_universe':
          'Si todos los jugadores reales son eliminados o salen, el universo se cierra automáticamente — incluso si solo quedan bots.',
      'v16_change_black_hole_graphics':
          'Agujeros negros rediseñados — sombra gravitacional, anillo de fotones brillante y disco de acreción inclinado que escala con tu masa.',
      'v16_change_star_lensing':
          'Las estrellas de fondo se curvan, brillan y desaparecen en tu sombra — lente gravitacional en el universo.',
      'v16_change_swallow_animations':
          'Nueva caza visual: corrientes de materia entre agujeros, destellos de captura en el anillo de fotones y chispas al acercarte.',
      'v16_change_food_spaghettify':
          'Asteroides y planetas se estiran en cintas solo en rango real de captura — caída más física y cercana.',
      'v16_change_gravity_physics':
          'Gravedad newtoniana inversa al cuadrado y distancia de captura en el anillo de fotones — masa y atracción más físicas.',
      'v16_change_universe_tiers':
          'Cuatro niveles de universo juegan distinto — entrenamiento, normal, élite y único con su propio ritmo y riesgo.',
      'v16_change_cosmic_events':
          'Supernovas, lluvias de meteoros y tormentas de cuásar reconfiguran el campo de batalla a mitad de partida.',
      'v16_change_hole_merger':
          'Dos agujeros negros dominantes pueden provocar una fusión galáctica — sacudida, rasgadura del espacio y masa combinada.',
      'v16_change_random_spawn':
          'Jugadores y bots aparecen ahora en posiciones aleatorias del universo — ya no todos empiezan en el centro.',
      'v16_change_revive_spawn':
          'El renacimiento también te coloca en un punto seguro aleatorio, lejos de otros jugadores y bots.',
      'v16_change_prey_bot_spawn':
          'Los bots presa de la sala simple ya no aparecen cerca de tu pantalla — nacen al azar en todo el mapa.',
      'v16_change_spawn_spacing':
          'Las posiciones de aparición mantienen distancia mínima de otros jugadores y bots para evitar solaparse.',
      'v16_change_version_notes':
          'Pantalla de novedades renovada para v1.6 — emparejamiento en servidor y ciclo de vida del universo arriba.',
      'v15_section_title': 'Versión 1.5',
      'v15_section_subtitle':
          'Gran actualización con bots más justos, rangos, protección inicial y nuevo sistema de impulso.',
      'v15_change_match_end':
          'Al ganar alguien, la partida se detiene para todos — ganador, tiempo y vuelta automática al lobby.',
      'v15_change_bot_victory':
          'Los bots pueden conquistar el universo con masa 500. Tras tu eliminación, los bots siguen luchando.',
      'v15_change_rank_system':
          'Insignias de rango (I–V) por diamantes antes del nombre — en juego, HUD y resultados.',
      'v15_change_spawn_shield':
          'Escudo de protección de 3 s al entrar al universo — invulnerabilidad total con cuenta atrás.',
      'v15_change_boost':
          'Impulso renovado: energía en 10 s, un toque para 5 s de velocidad sin perder masa.',
      'v15_change_spectator':
          'Modo espectador con botón Dejar de ver en la parte inferior.',
      'v15_change_bot_badge':
          'La insignia de bot ahora está al inicio del nombre.',
      'v15_change_global_rank':
          'Insignias de rango también en el ranking mundial.',
      'v15_change_audio':
          'Solo suena el tema oficial Quasar Orbit — música en bucle, demás sonidos eliminados.',
      'v15_change_bot_fixes':
          'Los bots ya no se quedan en ~140 de masa y terminan correctamente en 500.',
    },
    'fr': {
      'app_title': 'Quasar.io',
      'sign_in_google': 'Se connecter avec Google',
      'signing_in': 'Connexion...',
      'sign_out': 'Se déconnecter',
      'admin_badge': 'PROPRIÉTAIRE',
      'admin_title': 'Panneau admin',
      'admin_subtitle': 'Aperçu en direct des univers, joueurs et bots',
      'admin_refresh': 'Actualiser',
      'admin_enter_lobby': 'Retour au lobby',
      'admin_open_panel': 'Panneau de contrôle',
      'admin_total_players': 'Joueurs en direct',
      'admin_total_bots': 'Bots en direct',
      'admin_total_universes': 'Univers actifs',
      'admin_active_sessions': 'Sessions actives',
      'admin_universes_section': 'Univers et difficulté',
      'admin_players_section': 'Statistiques joueurs et bots',
      'admin_difficulty': 'Difficulté',
      'admin_difficulty_relaxed': 'Détendue',
      'admin_difficulty_standard': 'Standard',
      'admin_difficulty_elite': 'Élite',
      'admin_difficulty_unique': 'Unique',
      'admin_hunt_priority': 'Difficulté des bots : {pct}%',
      'admin_hunt_priority_short': 'Bots',
      'admin_hunt_priority_howto':
          'La difficulté des bots (0–100 %) règle à quel point ils chassent les joueurs plutôt que de farmer. Plus haut = moins de fuite, vise plus stable, scores de proie plus élevés, boost plus tôt. Première partie : ×0,85.',
      'admin_hunt_priority_formula':
          'Score de proie ≈ avantageTaille × difficulté / (1 + distance/rayon). Défaut de ce palier : {default} %. Le curseur modifie la valeur ; les nouvelles parties utilisent la valeur enregistrée.',
      'admin_hunt_priority_reset': 'Réinitialiser la difficulté des bots',
      'admin_room_tuning_howto':
          'Choisissez un univers, puis réglez par catégorie. Uniquement pour les nouvelles parties.',
      'admin_room_tuning_reset': 'Réinitialiser tous les réglages d’univers',
      'admin_room_tuning_reset_one': 'Réinitialiser cet univers',
      'admin_tune_saving': 'Enregistrement…',
      'admin_tune_default': 'Défaut {value}',
      'admin_tune_tab_world': 'Monde',
      'admin_tune_tab_tempo': 'Tempo',
      'admin_tune_tab_objects': 'Objets',
      'admin_tune_tab_events': 'Événements',
      'admin_tune_tab_radiation': 'Radiation',
      'admin_tune_tab_bots': 'Bots',
      'admin_tune_tab_live': 'Live',
      'admin_live_instances': 'Instances en direct',
      'admin_tune_world': 'Monde et rayons',
      'admin_tune_world_hint':
          'Durée et rythme : monde plus grand / rayon de victoire plus élevé = parties plus longues.',
      'admin_tune_gravity': 'Gravité alimentaire',
      'admin_tune_tempo_hint':
          'Les minutes cibles guident l’équilibre. Le boost tôt aide les nouveaux ; respawn bas = plus de nourriture.',
      'admin_tune_target_min': 'Durée cible (min)',
      'admin_tune_target_max': 'Durée cible (max)',
      'admin_tune_early_duration': 'Durée early-game',
      'admin_tune_early_growth': 'Boost de croissance précoce',
      'admin_tune_respawn_delay': 'Multiplicateur de respawn',
      'admin_tune_objects': 'Objets absorbables',
      'admin_tune_objects_hint': 'Quantité 0 = retirer ce type.',
      'admin_tune_events': 'Événements cosmiques',
      'admin_tune_events_short': 'Événements',
      'admin_tune_events_enabled': 'Supernova et pluie de météores',
      'admin_tune_events_enabled_hint': 'Off = pas de supernova/météores.',
      'admin_tune_radiation_hint':
          'Pression anti-camp. Rayon plus grand / idle plus court = sanction plus dure. Le shrink late-game serre la fin.',
      'admin_tune_radiation_radius': 'Rayon de radiation initial',
      'admin_tune_radiation_idle': 'Temps idle radiation',
      'admin_tune_late_radiation_radius': 'Rayon radiation late-game',
      'admin_tune_late_radiation_idle': 'Idle late-game',
      'admin_tune_late_radiation_shrink': 'Vitesse de shrink late-game',
      'admin_tune_bots': 'Bots',
      'admin_tune_bots_human_intro':
          'Salles compétitives : 10 joueurs + 10 bots. Les presets font farmer, combattre et fuir comme de vrais joueurs.',
      'admin_tune_universe_presets': 'Difficulté de l\'univers',
      'admin_tune_universe_presets_hint':
          'Échelle depuis les defaults de cet univers — nourriture, tempo, événements, radiation et bots ensemble. Ranked = équilibre de compilation.',
      'admin_tune_universe_preset_training': 'Entraînement',
      'admin_tune_universe_preset_casual': 'Casual',
      'admin_tune_universe_preset_ranked': 'Ranked',
      'admin_tune_universe_preset_predator': 'Prédateur',
      'admin_tune_universe_preset_apex': 'Apex',
      'admin_tune_universe_balanced_distribute': 'Appliquer l\'échelle équilibrée à tous',
      'admin_tune_universe_balanced_distribute_hint':
          'Simple→Entraînement · Normal→Ranked · Elite→Prédateur · Unique→Apex',
      'admin_tune_bot_presets': 'Difficulté des bots',
      'admin_tune_bot_presets_hint':
          'Cinq niveaux. Ranked est la base compétitive. La puce active montre le profil actuel.',
      'admin_tune_bot_preset_training': 'Entraînement',
      'admin_tune_bot_preset_casual': 'Casual',
      'admin_tune_bot_preset_ranked': 'Ranked',
      'admin_tune_bot_preset_predator': 'Prédateur',
      'admin_tune_bot_preset_apex': 'Apex',
      'admin_tune_bot_preset_soft': 'Entraînement',
      'admin_tune_bot_preset_human': 'Ranked',
      'admin_tune_bot_preset_aggressive': 'Apex',
      'admin_tune_bot_ai': 'Comportement IA',
      'admin_tune_bot_ai_hint':
          'Intervalle plus bas = réactions plus humaines. Ratio proie ~0.92–0.95. Gardez le biais joueur ~1.1–1.3.',
      'admin_tune_decision_min': 'Intervalle de décision (min)',
      'admin_tune_decision_max': 'Intervalle de décision (max)',
      'admin_tune_prey_ratio': 'Ratio de taille de proie',
      'admin_tune_threat_ratio': 'Ratio de menace (fuite)',
      'admin_tune_prey_search': 'Portée de recherche de proie',
      'admin_tune_food_search': 'Portée de recherche de nourriture',
      'admin_tune_event_awareness': 'Conscience des événements',
      'admin_tune_mine_avoidance': 'Évitement des mines',
      'admin_tune_min_hunt_radius': 'Rayon min avant chasse',
      'admin_tune_player_bias': 'Biais vers les joueurs',
      'admin_tune_intercept_prey': 'Intercepter les proies en mouvement',
      'admin_tune_personality': 'Mélange de personnalités',
      'admin_tune_personality_hint':
          'Poids relatifs des personnalités. La somme n’a pas besoin d’être 100.',
      'admin_tune_personality_coward': 'Lâche',
      'admin_tune_personality_aggressive': 'Agressif',
      'admin_tune_personality_opportunist': 'Opportuniste',
      'admin_tune_on': 'On',
      'admin_tune_off': 'Off',
      'admin_tune_victory_radius': 'Rayon de victoire',
      'admin_tune_player_start_radius': 'Rayon de départ joueur',
      'admin_tune_world_size': 'Taille du monde',
      'admin_tune_food_growth': 'Multiplicateur de croissance',
      'admin_tune_asteroids': 'Astéroïdes petits/moyens',
      'admin_tune_meteorites': 'Météorites',
      'admin_tune_planets': 'Planètes',
      'admin_tune_quasar_fragments': 'Fragments de quasar',
      'admin_tune_large_asteroids': 'Gros astéroïdes',
      'admin_tune_xlarge_asteroids': 'Très gros astéroïdes',
      'admin_tune_giant_asteroids': 'Astéroïdes géants',
      'admin_tune_mines': 'Mines',
      'admin_tune_supernova_interval': 'Intervalle supernova',
      'admin_tune_supernova_first': 'Délai première supernova',
      'admin_tune_meteor_cooldown': 'Délai premier météore',
      'admin_tune_event_growth_cap': 'Croissance max par événement',
      'admin_tune_supernova_planets': 'Planètes supernova',
      'admin_tune_bot_start_min': 'Rayon départ bot (min)',
      'admin_tune_bot_start_max': 'Rayon départ bot (max)',
      'admin_no_active_universes': 'Aucun univers actif pour le moment',
      'admin_registered_players': 'Joueurs inscrits',
      'admin_total_games_won': 'Victoires totales',
      'admin_live_entities': 'Joueurs + bots en direct',
      'admin_bot_share': 'Part des bots en direct',
      'admin_top_winners': 'Meilleurs vainqueurs',
      'admin_no_players_yet': 'Pas encore de joueurs inscrits',
      'admin_last_updated': 'Mis à jour {time}',
      'select_language': 'Langue',
      'welcome_cosmic': "Franchissez l'horizon des événements",
      'login_atmosphere':
          "Absorbez la matière. Surpassez vos rivaux. Dominez l'arène spatiale.",
      'lobby_brand_eyebrow': "Arène de l'espace profond",
      'lobby_choose_universe': 'Choisissez votre univers',
      'store_tab_skins': 'Skins',
      'store_tab_trails': 'Traces',
      'store_tab_emotes': 'Emotes',
      'store_buy': 'Acheter',
      'store_equip': 'Équiper',
      'store_owned': 'Possédé',
      'store_insufficient_gold': 'Or insuffisant',
      'event_quasar_storm': 'Tempête de quasar !',
      'event_supernova': 'Éruption de supernova !',
      'event_supernova_warning': 'Alerte : supernova dans {s}s !',
      'event_meteor_shower': 'Pluie de météores !',
      'event_meteor_warning': 'Alerte : pluie de météores dans {s}s !',
      'event_black_hole_merge': 'Fusion de trous noirs !',
      'merge_stage_tidal': 'Déformation de marée et transfert de masse !',
      'merge_stage_dance': 'La danse — ondes gravitationnelles massives !',
      'merge_stage_ringdown': 'Fusion et ringdown — un seul quasar !',
      'event_cosmic_mine': 'Détonation de mine cosmique !',
      'event_cosmic_dust_welcome': 'Pluie de poussière cosmique — croissance gratuite !',
      'first_match_hint_move':
          'Faites glisser n\'importe où pour diriger votre trou noir',
      'first_match_hint_absorb':
          'Absorbez astéroïdes et trous plus petits pour grandir',
      'first_match_hint_grow':
          'Grandissez vite — le bouclier de départ est encore actif !',
      'lobby_recommended_room': 'RECOMMANDÉ',
      'spawn_protection_label': 'Bouclier de protection initial',
      'game_over_title': 'Effondrement de l\'horizon des événements',
      'game_over_subtitle': 'Votre masse a été consumée par un vide plus grand',
      'game_over_watch_ad_revive': 'Regarder une pub pour revivre',
      'game_over_quit': 'Quitter',
      'game_over_watch_match': 'Regarder',
      'spectator_stop_watching': 'Arrêter de regarder',
      'game_over_peak_mass': 'Masse maximale',
      'game_over_diamond_penalty':
          '−{diamonds} diamant en quittant (jamais sous 0)',
      'game_over_play_again': 'Rejouer',
      'game_over_return_lobby': 'Retour au lobby',
      'match_quit_confirm_title': 'Quitter la partie ?',
      'match_quit_confirm_message':
          'Voulez-vous vraiment quitter ? Vous perdrez {diamonds} diamant(s).',
      'match_quit_confirm_stay': 'Rester',
      'match_quit_confirm_leave': 'Quitter',
      'leaderboard_title': 'CLASSEMENT',
      'hud_population_players': 'Joueurs',
      'hud_population_bots': 'Bots',
      'leaderboard_you': 'Vous',
      'leaderboard_name': 'Nom',
      'leaderboard_mass': 'Masse',
      'victory_title': 'Vous avez conquis l\'Univers !',
      'victory_subtitle': 'Le cosmos s\'incline devant votre gravité',
      'victory_time': 'Temps de victoire : {time}',
      'victory_reward': '+{diamonds} diamants · +1 victoire',
      'victory_return_lobby': 'Retour triomphal au lobby',
      'reward_double_cta': 'Doubler la récompense',
      'reward_double_micro': '+{extra} diamants en plus (total {total})',
      'reward_double_done': '2× obtenu · +{total} diamants',
      'reward_double_loading': 'Chargement de la pub…',
      'reward_double_claiming': 'Attribution du bonus…',
      'reward_double_claim_wait': 'Enregistrement de la récompense… réessayez',
      'reward_double_ad_failed': 'Pub indisponible. Votre récompense de base est en sécurité.',
      'reward_double_grant_failed': 'Bonus en attente — appuyez pour réessayer (pas de nouvelle pub)',
      'reward_double_retry_grant': 'Récupérer le bonus',
      'reward_double_unavailable': 'Pubs indisponibles sur cet appareil',
      'frozen_title': 'Univers conquis',
      'frozen_champion': '{name} a conquis l\'univers en {time}',
      'match_champion_result': '{name} a remporté la partie en {time}',
      'frozen_placement_reward': 'Place #{place} : +{diamonds} diamants',
      'frozen_room_closed': 'L\'univers est fermé.',
      'match_returning_lobby': 'Retour au lobby dans {seconds} s…',
      'lobby_diamonds': 'Diamants',
      'rank_tier_nebula': 'Nébuleuse',
      'rank_tier_stellar': 'Stellaire',
      'rank_tier_nova': 'Nova',
      'rank_tier_quasar': 'Quasar',
      'rank_tier_singularity': 'Singularité',
      'lobby_gold': 'Or',
      'lobby_play': 'Jouer',
      'lobby_stat_universes': '{count} univers',
      'lobby_stat_players': '{count} joueurs',
      'lobby_stat_bots': '{count} bots',
      'lobby_stat_universes_short': 'Univers',
      'lobby_stat_players_short': 'Joueurs',
      'lobby_stat_bots_short': 'Bots',
      'lobby_room_fill_hint':
          'Chaque univers ouvert : jusqu\'à 10 joueurs réels, bots jusqu\'à 20.',
      'lobby_low_population_hint':
          'Peu de joueurs réels — les bots complètent le reste du match.',
      'lobby_stat_solo_players': 'Solo',
      'room_entry_free': 'Entrée : Gratuite',
      'room_entry_cost': 'Il vous faut au moins {count}',
      'room_entry_cost_prefix': 'Il vous faut au moins {count} ',
      'room_entry_cost_suffix': '',
      'room_rewards_label': 'Récompenses',
      'room_elimination_label': 'Élimination',
      'room_elimination_none': 'sans perte',
      'room_simple_title': 'Univers Tutoriel',
      'lobby_first_login_lock': "Terminez d'abord le tutoriel",
      'room_instance_normal': 'Univers Normal {number}',
      'room_instance_elite': 'Univers Élite {number}',
      'room_instance_unique': 'Univers Unique {number}',
      'matchmaking_error': "Impossible de rejoindre la salle. Réessayez.",
      'player_already_active_title': 'Joueur déjà actif',
      'player_already_active_message':
          'Ce compte est déjà en partie sur un autre appareil. Terminez ou quittez cette partie d\'abord.',
      'player_already_active_ok': 'OK',
      'idle_session_title': 'Toujours là ?',
      'idle_session_message':
          'Aucune activité. Déconnexion dans {seconds} secondes.',
      'idle_session_stay': 'Rester connecté',
      'idle_match_result_title': 'Retour au lobby',
      'idle_match_result_message':
          'Aucune action sur l\'écran de résultats. Retour au lobby dans {seconds} secondes.',
      'idle_match_result_stay': 'Rester sur cet écran',
      'idle_match_result_hint':
          'Sans action pendant 10 secondes, un compte à rebours de 10 s démarre et vous retournez au lobby.',
      'room_simple_desc':
          'Entrée : Gratuite · Tutoriel bots seuls\nRécompenses +3 · +2 · +1 · Pas de pénalité · gros astéroïdes',
      'room_normal_title': 'Univers Normaux',
      'room_normal_desc':
          'Il vous faut au moins 25\nRécompenses +5 · +3 · +2 · Élimination -1',
      'room_elite_title': 'Univers Élite',
      'room_elite_desc':
          'Il vous faut au moins 100\nRécompenses +10 · +6 · +4 · Élimination -2',
      'room_unique_title': 'Univers Uniques',
      'room_unique_desc':
          'Il vous faut au moins 200\nRécompenses +15 · +10 · +5 · Élimination -3',
      'room_requires_100': 'Il vous faut au moins 100',
      'room_requires_300': 'Il vous faut au moins 200',
      'room_requires_diamonds': 'Il vous faut au moins {count}',
      'profile_stats_tab': 'Statistiques',
      'profile_store_tab': 'Boutique',
      'feature_coming_soon_badge': 'Bientôt',
      'feature_coming_soon_title': 'En construction',
      'feature_coming_soon_body':
          'Cette section se forge dans l’espace profond. Cosmétiques et boutique bientôt.',
      'profile_games_won': 'Parties gagnées',
      'profile_global_rank': 'Classement mondial',
      'profile_rank_system': 'Système de rang',
      'rank_system_intro':
          'Les étoiles à côté du nom montrent votre rang. Le rang monte avec les points de victoire (1res places pondérées), pas les diamants.',
      'rank_system_your_rank': 'VOTRE RANG',
      'rank_system_your_points': '{points} points de victoire',
      'rank_system_next': 'Suivant : {tier} à {points}+',
      'rank_system_ladder_title': 'ÉCHELLE D\'ÉTOILES',
      'rank_system_current_badge': 'Vous êtes ici',
      'rank_system_earn_title': 'POINTS PAR 1RE PLACE',
      'rank_system_points_per_win': '+{n}',
      'rank_system_points_none': 'Ne compte pas',
      'rank_system_note':
          'Seule la 1re place en Normal / Élite / Unique ajoute points et victoires. L\'entraînement ne compte pas. Rang trie par points; Richesse par diamants.',
      'rank_system_close': 'Compris',
      'global_rank_player': 'Joueur',
      'global_rank_wins': 'Victoires',
      'global_rank_points': 'Pts',
      'global_rank_tab_rank': 'Rang',
      'global_rank_tab_wealth': 'Richesse',
      'global_rank_blurb':
          'Rang : points de victoire. Richesse : diamants. Victoires = 1res compétitives (sans entraînement).',
      'global_rank_blurb_rank':
          'Classé par points de victoire (puis victoires). Seule la 1re en Normal / Élite / Unique compte — jamais l\'entraînement.',
      'global_rank_blurb_wealth':
          'Classé par diamants (puis victoires). Les étoiles à côté du nom montrent toujours votre rang compétitif.',
      'global_rank_your_position': 'VOTRE POSITION',
      'global_rank_empty': 'Pas encore de classement.',
      'global_rank_error': 'Impossible de charger le classement.',
      'global_rank_retry': 'Réessayer',
      'profile_legendary_skins': 'Skins légendaires',
      'skin_default': 'Éruption solaire',
      'skin_frost': 'Voile de givre',
      'skin_ember': 'Noyau de braise',
      'skin_pulsar': 'Pulsar bleu',
      'skin_nebula': 'Nébuleuse violette',
      'skin_plasma': 'Plasma RGB',
      'skin_void': 'Vide obscur',
      'skin_quasar': 'Quasar vert',
      'skin_eclipse': 'Éclipse solaire',
      'skin_supernova': 'Supernova rouge',
      'skin_aurora': 'Aurore boréale',
      'skin_binary': 'Étoile binaire',
      'skin_singularity': 'Singularité Prime',
      'skin_celestial': 'Couronne céleste',
      'skin_picker_title': 'Skins de trou noir',
      'skin_picker_subtitle': 'Choisissez l\'apparence de votre disque d\'accrétion',
      'skin_picker_equipped': 'Équipé',
      'skin_picker_locked': 'Verrouillé',
      'skin_picker_free': 'Gratuit',
      'trail_comet': 'Jet de plasma',
      'trail_nebula': 'Traînée de lentille',
      'trail_quantum': 'Onde gravitationnelle',
      'trail_picker_section': 'Traînées de mouvement',
      'trail_picker_subtitle': 'Appuyez sur une traînée possédée pour l\'équiper',
      'trail_picker_empty':
          'Obtenez des traînées dans la boutique pour les équiper ici.',
      'trail_picker_owned': 'Possédé',
      'store_trail_equip_hint':
          'Équipez cette traînée depuis l\'onglet Apparence.',
      'store_trail_claim_success':
          'Traînée débloquée ! Équipez-la depuis l\'onglet Apparence.',
      'emote_wave': 'Vague cosmique',
      'emote_burst': 'Éruption de supernova',
      'emote_void': 'Rire du vide',
      'store_purchase_success': 'Achat réussi !',
      'store_equip_success': 'Équipé !',
      'store_error': 'Une erreur est survenue',
      'error_generic': 'Une erreur est survenue. Veuillez réessayer.',
      'sign_in_error': 'Échec de la connexion. Veuillez réessayer.',
      'profile_edit': 'Modifier le profil',
      'profile_edit_name': 'Nom affiché',
      'profile_edit_avatar': 'Appuyez pour changer la photo',
      'profile_edit_save': 'Enregistrer',
      'profile_edit_cancel': 'Annuler',
      'profile_username_taken': 'Ce nom est déjà pris',
      'profile_username_invalid':
          'Le nom doit faire 3–12 caractères (lettres, chiffres, espaces)',
      'profile_update_success': 'Profil mis à jour !',
      'profile_update_error': 'Échec de la mise à jour du profil',
      'lobby_how_to_play': 'Survivre',
      'lobby_skill_tree': 'Matrice de puissance',
      'lobby_version_notes_hint': 'Journal de transmission',
      'skill_tree_title': 'Arbre de compétences',
      'skill_sp_available': 'SP disponibles',
      'skill_sp_earned': 'Dépensés / Gagnés',
      'skill_sp_rules':
          'Tous les {n} diamants pic débloquent 1 SP. Les diamants ne sont pas dépensés. Prochain SP dans {next} ♦.',
      'skill_branch_boost': 'Boost',
      'skill_branch_teleport': 'Téléportation',
      'skill_branch_shield': 'Bouclier',
      'skill_branch_shockwave': 'Onde de choc',
      'skill_level': 'Niv',
      'skill_upgrade': '+1 SP',
      'skill_maxed': 'MAX',
      'skill_value_now': 'Maintenant',
      'skill_error_no_sp': 'Aucun point de compétence',
      'skill_error_max': 'Cette compétence est déjà au maximum',
      'skill_error_generic': 'Impossible d\'améliorer la compétence',
      'skill_node_boost_speed': 'Vitesse du boost',
      'skill_node_boost_speed_desc': 'Vitesse max plus élevée en boost',
      'skill_node_boost_duration': 'Durée du boost',
      'skill_node_boost_duration_desc': 'Le boost reste actif plus longtemps',
      'skill_node_boost_charge': 'Charge du boost',
      'skill_node_boost_charge_desc': 'Recharge plus rapide entre les boosts',
      'skill_node_teleport_cd': 'Recharge téléport',
      'skill_node_teleport_cd_desc': 'Attente plus courte entre téléports',
      'skill_node_teleport_shield': 'Bouclier d\'arrivée',
      'skill_node_teleport_shield_desc':
          'Protection plus longue après téléport',
      'skill_node_shield_cd': 'Recharge bouclier',
      'skill_node_shield_cd_desc': 'Attente plus courte entre boucliers',
      'skill_node_shield_duration': 'Durée du bouclier',
      'skill_node_shield_duration_desc': 'Le bouclier actif dure plus longtemps',
      'skill_node_shockwave_cd': 'Recharge onde',
      'skill_node_shockwave_cd_desc': 'Attente plus courte entre ondes',
      'skill_node_shockwave_range': 'Portée de l\'onde',
      'skill_node_shockwave_range_desc': 'Repousse de plus loin',
      'skill_node_shockwave_power': 'Puissance de l\'onde',
      'skill_node_shockwave_power_desc':
          'Poussée plus forte sur petits trous et matière',
      'settings_title': 'Paramètres',
      'settings_sound_title': 'Son',
      'settings_music': 'Quasar Orbit Theme',
      'settings_music_desc': 'Musique thématique officielle de Quasar.io',
      'settings_music_volume': 'Volume de la musique',
      'settings_haptics': 'Vibration',
      'settings_haptics_desc': 'Retour haptique lors des collisions et événements',
      'settings_audio_missing': 'Impossible de charger le fichier audio.',
      'settings_display_section': 'Affichage',
      'settings_show_own_name': 'Mon nom',
      'settings_show_own_name_desc': 'Afficher votre nom au-dessus de votre trou noir',
      'settings_show_other_names': 'Autres noms',
      'settings_show_other_names_desc':
          'Afficher les noms des autres joueurs et bots au-dessus des trous noirs',
      'settings_show_profile_pictures': 'Photos de profil',
      'settings_show_profile_pictures_desc':
          'Afficher les photos de profil dans les trous noirs',
      'settings_support_section': 'Assistance',
      'admin_nav_messages': 'Messages',
      'admin_page_messages_title': 'Messages',
      'admin_page_messages_desc':
          'Lisez les avis, répondez un par un ou envoyez à tous.',
      'msg_player_title': 'Messages',
      'msg_tab_inbox': 'Boîte de réception',
      'msg_tab_compose': 'Écrire',
      'msg_open_inbox': 'Boîte de réception',
      'msg_write_to_admin': 'Écrire à l\'admin',
      'msg_category_feedback': 'Avis',
      'msg_category_suggestion': 'Suggestion',
      'msg_category_bug': 'Bug',
      'msg_category_direct': 'Direct',
      'msg_category_broadcast': 'Annonce',
      'msg_filter_open': 'Ouverts',
      'msg_filter_closed': 'Fermés',
      'msg_filter_all': 'Tous',
      'msg_filter_category_all': 'Tous les types',
      'msg_broadcast': 'Annonce',
      'msg_send_direct': 'Message joueur',
      'msg_search_player': 'Rechercher un joueur…',
      'msg_to_player': 'À : {name}',
      'msg_subject_hint': 'Objet',
      'msg_body_hint': 'Écrivez votre message…',
      'msg_reply_hint': 'Écrire une réponse…',
      'msg_send': 'Envoyer',
      'msg_send_to_admin': 'Envoyer à l\'admin',
      'msg_empty_inbox': 'Pas encore de messages.',
      'msg_empty_player_inbox':
          'Pas encore de messages. Écrivez à l\'admin quand vous voulez.',
      'msg_migration_hint':
          'Messagerie indisponible. Exécutez migration_admin_messaging.sql dans Supabase.',
      'msg_close_thread': 'Fermer',
      'msg_reopen_thread': 'Rouvrir',
      'msg_from_admin': 'Admin',
      'msg_from_player': 'Joueur',
      'msg_from_you': 'Vous',
      'msg_compose_hint':
          'Avis, suggestion ou bug. L\'admin répondra ici.',
      'msg_sent_ok': 'Message envoyé.',
      'msg_broadcast_sent': 'Annonce envoyée à {count} joueurs.',
      'msg_broadcast_readonly': 'Les annonces ne peuvent pas recevoir de réponse.',
      'how_to_play_title': 'Comment jouer',
      'how_to_play_close': 'Compris',
      'how_to_play_move_title': 'Mouvement',
      'how_to_play_move_desc':
          'Touchez n\'importe où sur l\'écran et faites glisser pour diriger votre trou noir.',
      'how_to_play_absorb_title': 'Augmenter votre masse',
      'how_to_play_absorb_desc':
          'Absorbez astéroïdes, planètes et joueurs plus petits. Évitez les trous noirs plus grands !',
      'how_to_play_boost_title': 'Boost',
      'how_to_play_boost_desc':
          'L\'énergie se charge en 10 s. Appuyez une fois à pleine charge : 5 s de vitesse sans perte de masse.',
      'how_to_play_link_title': 'Lien binaire',
      'how_to_play_link_desc':
          'Appuyez sur Lier près d\'un autre joueur pour un avantage tactique.',
      'how_to_play_shield_title': 'Bouclier',
      'how_to_play_shield_desc':
          'Collectez des boucliers pour ignorer temporairement la gravité des grands trous.',
      'how_to_play_victory_title': 'Victoire',
      'how_to_play_victory_desc':
          'Atteignez le rayon 500 (550 en univers Uniques) — l\'univers se ferme pour tous. Normal : 1er +5, 2e +3, 3e +2 (élimination −1). Élite : 1er +10, 2e +6, 3e +4 (élimination −2). Unique : 1er +15, 2e +10, 3e +5 (élimination −3). Diamants jamais sous 0. Les nouveaux joueurs commencent avec 20 diamants.',
      'how_to_play_ranks_title': 'Système de rang',
      'how_to_play_ranks_desc':
          'Votre rang d\'étoiles (Nébuleuse → Singularité) dépend des points de victoire, pas des diamants.\n'
          'Seul la 1re place ajoute des points. Les victoires d\'entraînement ne comptent pas.\n'
          'Points par 1re place : Normal +{normal}, Élite +{elite}, Unique +{unique}.\n'
          'Seuils : Stellaire {stellar}+ · Nova {nova}+ · Quasar {quasar}+ · Singularité {singularity}+.\n'
          'Victoires exclut aussi l\'entraînement. Le classement mondial trie par points (Rang) par défaut ; Richesse trie par diamants.',
      'how_to_play_currencies_title': 'Monnaies',
      'how_to_play_currencies_desc':
          'Les nouveaux comptes commencent avec 20 diamants. Univers Tutoriel gratuit. Univers normaux : au moins 25 diamants. Les diamants débloquent Élite (100) et Unique (200).',
      'how_to_play_events_title': 'Événements cosmiques',
      'how_to_play_events_desc':
          'Surveillez tempêtes de quasar, supernovas et pluies de météores.',
      'version_notes_title': 'Nouveautés',
      'version_current': 'Version actuelle : {version}',
      'version_notes_close': 'Fermer',
      'version_notes_dont_show': 'Ne plus afficher',
      'lobby_version_notes': 'v2.1',
      'v21_section_title': 'Version 2.1',
      'v21_section_subtitle':
          'Rangs étoiles par points de victoire, victoires plus justes (entraînement exclu), verrou tutoriel, victoires au classement, chat du lobby, annonces en boîte de réception et bannières live.',
      'v21_change_rank_points':
          'Les rangs étoiles (Nebula → Singularity) viennent désormais des points de victoire — 1ères places pondérées. Par défaut : Normal +1, Elite +2, Unique +3. L\'entraînement donne 0.',
      'v21_change_training_excluded':
          'Finir 1er en entraînement n\'ajoute plus Games Won ni points de victoire — seuls Normal, Elite et Unique comptent.',
      'v21_change_tutorial_lock':
          'Les nouveaux comptes doivent terminer l\'univers d\'entraînement avant d\'ouvrir les autres salles (les seuils diamants restent ensuite).',
      'v21_change_leaderboard_wins':
          'Le classement mondial a Rang (points) et Richesse (diamants). Victoires = 1ères compétitives ; l\'entraînement ne compte jamais.',
      'v21_change_rank_dialog':
          'Écran système de rang dans le profil — votre palier, le prochain seuil et les points par univers.',
      'v21_change_lobby_chat':
          'Chat du lobby — discutez en temps réel avec les autres joueurs en attendant dans le lobby.',
      'v21_change_broadcast':
          'Annonces générales — les avis de l\'équipe arrivent dans la boîte Messages de chaque joueur et y restent jusqu\'à lecture.',
      'v21_change_live_announce':
          'Bannières d\'annonce live — un court message de l\'équipe apparaît aussitôt chez tous les joueurs en ligne.',
      'v21_change_idle':
          'Système AFK / idle mis à jour — alertes lobby et match plus fiables, compte à rebours plus clair et plusieurs bugs d\'idle-kick corrigés.',
      'v21_change_menus':
          'Menus lobby et profil mis à jour — mise en page plus claire, stats et rang actualisés, navigation plus fluide entre les actions du lobby.',
      'v21_change_version_notes':
          'Écran Nouveautés rafraîchi pour la v2.1 — rangs, chat, annonces et victoires justes en tête. S\'affiche dans le lobby jusqu\'à fermeture.',
      'v20_section_title': 'Version 2.0',
      'v20_section_subtitle':
          'Salles compétitives plus denses, places et compteurs de lobby plus justes, diamants à chaque match, événements d\'univers partagés et un vrai top 100.',
      'v20_change_room_capacity':
          'Les salles compétitives sont désormais 10 joueurs + 10 bots — combats plus remplis à salle pleine ; seul, tu gardes un match à 20 entités (1 + 19 bots). L\'entraînement reste 1 + 19 bots.',
      'v20_change_ghost_cleanup':
          'Les places fantômes des onglets plantés ou fermetures forcées sont nettoyées automatiquement — les compteurs du lobby restent honnêtes, sans fausses salles pleines.',
      'v20_change_seat_free':
          'Mourir ou quitter libère ta place pour que d\'autres rejoignent tant que le leader est sous le rayon 280. Revivre récupère une place s\'il en reste.',
      'v20_change_match_rewards':
          'Les récompenses en diamants marchent à nouveau à chaque match — rouvrir un univers démarre une nouvelle génération de match, donc podium et éliminations ne sont plus bloqués après le premier claim.',
      'v20_change_cosmic_sync':
          'Supernovas, pluies de météores et leurs alertes sont désormais synchronisées côté serveur — chaque joueur de l\'univers voit le même événement au même endroit et au même moment.',
      'v20_change_real_matchmaking':
          'Le matchmaking et les stats du lobby ne comptent que les vrais joueurs — salles plus propres et comptes d\'univers exacts.',
      'v20_change_smarter_bots':
          'Bots retunés pour le remplissage 10+10 — farm, combat et fuite plus humains pour que les salles mi-bots restent compétitives.',
      'v20_change_leaderboard_100':
          'Le classement mondial renvoie maintenant un vrai top 100 par diamants — comme le profil le promettait déjà.',
      'v20_change_unique_theme':
          'L\'Univers Unique a désormais son propre look or/ambre — plus facile à distinguer du Normal (cyan) et de l\'Élite (violet) dans le lobby et en match.',
      'v20_change_version_notes':
          'Écran Nouveautés rafraîchi pour la v2.0 — salles compétitives, places justes, événements cosmiques synchronisés et récompenses de match en tête.',
      'v19_section_title': 'Version 1.9',
      'v19_section_subtitle':
          'Arbre de compétences, quatre capacités de combat améliorables, messagerie avec l\'équipe, protection anti-inactivité et économie serveur renforcée.',
      'v19_change_skill_tree':
          'Arbre de compétences dans le lobby — gagnez des points de compétence avec votre pic de diamants (1 SP pour 20 ♦ de pic). Les diamants ne sont pas dépensés ; les améliorations se synchronisent avec le compte.',
      'v19_change_boost_upgrades':
          'Branche Boost — augmentez vitesse max, durée active et recharge jusqu\'au niveau 10 par nœud, pour des gains doux mais perceptibles.',
      'v19_change_teleport':
          'Capacité Téléportation — sautez vers un point sûr aléatoire avec un court bouclier à l\'arrivée. Les skills réduisent le délai et prolongent le bouclier.',
      'v19_change_shield':
          'Bouclier à la demande — protection gravitationnelle temporisée distincte des boucliers ramassés. Les skills réduisent le délai et allongent la durée.',
      'v19_change_shockwave':
          'Capacité Onde de choc — repousse les bots plus petits et la matière proche. Les skills améliorent délai, portée et force de poussée.',
      'v19_change_messages':
          'Boîte de messages dans le lobby — envoyez retours, suggestions ou rapports de bugs et recevez les réponses de l\'équipe ; badge non lu inclus.',
      'v19_change_idle_protect':
          'Protection anti-inactivité — après inactivité, « Toujours là ? » apparaît ; restez connecté ou déconnexion pour nettoyer les sessions abandonnées.',
      'v19_change_economy_security':
          'Économie durcie côté serveur — diamants, victoires et compétences ne changent que via des actions serveur de confiance.',
      'v19_change_version_notes':
          'Écran Nouveautés rafraîchi pour la v1.9 — arbre de compétences, capacités de combat et messagerie en tête.',
      'v18_section_title': 'Version 1.8',
      'v18_section_subtitle':
          'Graphismes de trou noir nouvelle génération, matchs plus longs, matchmaking plus malin, animations d\'engloutissement cinématographiques et gros correctifs de performance sur web et mobile.',
      'v18_change_blackhole_shader':
          'Trous noirs entièrement refaits sur le GPU — disque d\'accrétion incliné aux filaments de plasma turbulents, anneau de photons chauffé à blanc, horizon des événements d\'un noir absolu et jets relativistes jumeaux, d\'après de vraies images scientifiques.',
      'v18_change_swallow_visuals':
          'L\'engloutissement devient un vrai événement astrophysique — la proie est étirée par les forces de marée (spaghettification), déchirée à la limite de Roche et spirale dans le disque d\'accrétion.',
      'v18_change_merger_rework':
          'Fusions de trous noirs repensées d\'après la référence — danse orbitale, pont de matière et effondrement final, sans figer le jeu.',
      'v18_change_merger_ripples':
          'Ondes gravitationnelles de fusion adoucies — moins d\'anneaux, portée réduite ; l\'écran reste lisible lors des grosses collisions.',
      'v18_change_space_background':
          'Fond spatial reconstruit pour les univers supérieurs — nébuleuses, bande de la Voie lactée, galaxies lointaines et comètes pour un vide vraiment profond et angoissant.',
      'v18_change_web_performance':
          'Ralentissement web corrigé — les shaders d\'arrière-plan sont créés une fois et mis en cache au lieu d\'être recréés à chaque image ; les parties ne ralentissent plus avec le temps.',
      'v18_change_meteor_perf':
          'Les pluies de météores ne font plus chuter la fréquence d\'images.',
      'v18_change_mobile_fixes':
          'Correctifs mobiles — le trou noir rendu au quart sur téléphone (Impeller) et le plantage au lancement après installation sont résolus.',
      'v18_change_big_hole_clarity':
          'Les trous noirs géants s\'affichent nettement — le bord circulaire dur et le voile gris sur l\'ombre aux grandes tailles ont disparu ; détail complet à toutes les tailles.',
      'v18_change_match_pacing':
          'Durée des matchs réajustée — la croissance via la nourriture est ralentie pour viser : Entraînement ~1,5–2,5 min, Normal ~4–6, Élite ~5–7, Unique ~7–9.',
      'v18_change_smarter_bots':
          'Les bots jouent désormais pour gagner comme de vrais joueurs — ils visent la domination de l\'univers, chassent le leader ou l\'évitent selon leur taille, utilisent le boost pour fuir les supernovas et conclure le match, et hésitent moins en grandissant.',
      'v18_change_supernova_events':
          'Les explosions de supernova sont de retour et le premier souffle arrive plus tôt en Normal, Élite et Unique — un léger défi hors de l\'univers d\'entraînement.',
      'v18_change_event_warnings':
          'Alertes d\'événements allégées — seules les pluies de météores et les supernovas préviennent 5 secondes à l\'avance ; les autres bannières intermédiaires ont disparu.',
      'v18_change_leader_threshold':
          'Seuil d\'entrée dans la salle abaissé de rayon 300 à 250 — quand le leader atteint cette taille, les nouveaux joueurs partent vers une instance d\'univers fraîche.',
      'v18_change_empty_close':
          'Quand le dernier joueur réel quitte, l\'univers se ferme aussitôt — les salles bots seuls ne tournent plus à vide.',
      'v18_change_avatar_hud_only':
          'Les photos de profil ne s\'affichent plus au centre du trou noir — le portrait reste à côté du nom au-dessus.',
      'v18_change_rewarded_ads':
          'Publicités vidéo récompensées pour la réanimation intégrées via Google Mobile Ads.',
      'v18_change_version_notes':
          'Écran Nouveautés rafraîchi pour la v1.8 — graphismes, rythme de match et matchmaking en tête.',
      'v17_section_title': 'Version 1.7',
      'v17_section_subtitle':
          'Économie de diamants, profils joueur, une session par appareil, stats live du lobby et accompagnement des nouveaux voyageurs cosmiques.',
      'v17_change_match_rewards':
          'Gagnez et perdez des Diamants selon le résultat — récompenses de podium jusqu\'à +15/+10/+5 en univers Unique et pénalités −1/−2/−3 à l\'élimination. Résultats enregistrés côté serveur.',
      'v17_change_diamond_gates':
          'Les nouveaux comptes démarrent avec 20 Diamants. Tutoriel gratuit ; Normal 25, Élite 100, Unique 200. Les cartes du lobby affichent entrée, récompenses et pénalités.',
      'v17_change_profile_hub':
          'Touchez votre avatar dans le lobby pour un profil à 3 onglets : Stats, Skins et Boutique. Victoires, rang mondial et sync live via Supabase.',
      'v17_change_edit_profile':
          'Changez votre nom affiché (3–12 caractères) et téléversez une photo depuis la galerie (max 5 Mo). Avatars dans Supabase Storage.',
      'v17_change_ingame_avatars':
          'Votre avatar apparaît dans votre trou noir en match. Réglages → Photos de profil pour activer/désactiver.',
      'v17_change_cosmetic_store':
          'Dépensez de l\'Or en Boutique pour débloquer des skins légendaires de disque d\'accrétion. Équipez depuis le profil — le skin actif s\'applique en jeu.',
      'v17_change_global_leaderboard':
          'Top 100 mondial par Diamants depuis votre profil. Votre position même hors du top 100.',
      'v17_change_single_session':
          'Un compte, un match actif à la fois. Un autre appareil affiche « Joueur déjà actif » jusqu\'à votre départ.',
      'v17_change_live_lobby_stats':
          'Les cartes d\'univers du lobby affichent des compteurs en direct : univers actifs, joueurs et bots — via Supabase Realtime.',
      'v17_change_onboarding':
          'Les nouveaux doivent d\'abord terminer l\'Univers Tutoriel. Le premier match affiche des indices minutés.',
      'v17_change_native_splash':
          'Écran de démarrage brandé dès l\'ouverture pendant le chargement langue, auth et réglages en arrière-plan.',
      'v17_change_hud_podium_rewards':
          'Le podium en match affiche les récompenses Diamant pour les 1er, 2e et 3e places et les rangs des adversaires.',
      'v17_change_swallow_vfx':
          'Visuels de chasse améliorés — le pont de marée entre trous noirs est un effet Flame multicouche avec filaments chauds.',
      'v17_change_victory_fix':
          'Le match se termine dès le rayon 500 (550 en Unique) — plus de gel quand la masse affichée arrondit au plafond.',
      'v17_change_login_fix':
          'Correction d\'un bref « not authenticated » après Google. La session réessaie pendant la stabilisation du JWT.',
      'v17_change_hud_loading':
          'HUD et classement apparaissent plus tôt — moins d\'écran noir au début du match.',
      'v17_change_version_notes':
          'Écran Nouveautés rafraîchi pour la v1.7 — économie de diamants, profils et sessions en tête.',
      'v16_section_title': 'Version 1.6',
      'v16_section_subtitle':
          'Trous noirs inspirés du télescope, matchmaking d\'univers côté serveur, répartition intelligente des salles et spawns aléatoires équitables.',
      'v16_change_server_matchmaking':
          'Les univers Normal, Élite et Unique utilisent désormais l\'attribution de salle côté serveur — vous rejoignez le bon univers depuis le lobby.',
      'v16_change_universe_instances':
          'Le HUD indique dans quel univers vous êtes — instances numérotées comme Univers Normal 1 ou Univers Élite 2.',
      'v16_change_leader_radius_split':
          'Quand le leader de la salle atteint le rayon 300 ou que la salle est pleine, les nouveaux joueurs sont dirigés vers l\'instance suivante.',
      'v16_change_room_lifecycle':
          'Les univers se ferment à la fin du match ; les membres fantômes sont nettoyés après un crash — l\'Univers 1 vide n\'est plus ignoré.',
      'v16_change_abandoned_universe':
          'Si tous les vrais joueurs sont éliminés ou partent, l\'univers se ferme automatiquement — même s\'il ne reste que des bots.',
      'v16_change_black_hole_graphics':
          'Trous noirs refaits — ombre gravitationnelle, anneau de photons lumineux et disque d\'accrétion incliné selon votre masse.',
      'v16_change_star_lensing':
          'Les étoiles de fond se courbent, brillent et disparaissent dans votre ombre — lentille gravitationnelle.',
      'v16_change_swallow_animations':
          'Nouvelle chasse visuelle : flux de matière entre trous, éclairs de capture à l\'anneau de photons et étincelles en approche.',
      'v16_change_food_spaghettify':
          'Astéroïdes et planètes s\'étirent en rubans seulement à portée réelle de capture — chute plus physique.',
      'v16_change_gravity_physics':
          'Gravité newtonienne en 1/r² et distance de capture à l\'anneau de photons — masse et attraction plus physiques.',
      'v16_change_universe_tiers':
          'Quatre niveaux d\'univers se jouent différemment — entraînement, normal, élite et unique avec leur propre rythme.',
      'v16_change_cosmic_events':
          'Supernovas, pluies de météores et tempêtes de quasar remodèlent le champ de bataille en cours de partie.',
      'v16_change_hole_merger':
          'Deux trous noirs dominants peuvent déclencher une fusion galactique — secousse, déchirure de l\'espace et masse combinée.',
      'v16_change_random_spawn':
          'Joueurs et bots apparaissent désormais à des positions aléatoires dans l\'univers — fini le départ au centre pour tous.',
      'v16_change_revive_spawn':
          'La résurrection vous replace aussi à un endroit sûr aléatoire, loin des autres joueurs et bots.',
      'v16_change_prey_bot_spawn':
          'Les bots proies en salle simple n\'apparaissent plus près de votre écran — ils naissent aléatoirement sur toute la carte.',
      'v16_change_spawn_spacing':
          'Les positions de spawn gardent une distance minimale des autres joueurs et bots pour éviter les chevauchements.',
      'v16_change_version_notes':
          'Écran Nouveautés rafraîchi pour la v1.6 — matchmaking serveur et cycle de vie des univers en tête.',
      'v15_section_title': 'Version 1.5',
      'v15_section_subtitle':
          'Grande mise à jour : bots plus justes, rangs, protection au spawn et nouveau boost.',
      'v15_change_match_end':
          'Quand quelqu\'un gagne, la partie s\'arrête pour tous — vainqueur, temps et retour auto au lobby.',
      'v15_change_bot_victory':
          'Les bots peuvent conquérir l\'univers à masse 500. Après votre élimination, ils continuent.',
      'v15_change_rank_system':
          'Badges de rang (I–V) selon les diamants avant les noms — en jeu, HUD et résultats.',
      'v15_change_spawn_shield':
          'Bouclier de protection de 3 s à l\'entrée dans l\'univers — invulnérabilité totale avec compte à rebours.',
      'v15_change_boost':
          'Boost refait : énergie en 10 s, un appui pour 5 s de vitesse sans perte de masse.',
      'v15_change_spectator':
          'Mode spectateur avec bouton Arrêter de regarder en bas de l\'écran.',
      'v15_change_bot_badge':
          'Le badge bot est maintenant au début du nom.',
      'v15_change_global_rank':
          'Badges de rang aussi dans le classement mondial.',
      'v15_change_audio':
          'Seul le thème officiel Quasar Orbit — musique en boucle, autres sons supprimés.',
      'v15_change_bot_fixes':
          'Les bots ne restent plus bloqués à ~140 de masse et terminent correctement à 500.',
    },
  };

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await _preferences;
    final saved = prefs.getString(_prefKey);
    if (saved != null && supportedLanguages.contains(saved)) {
      _currentLanguage = saved;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.contains(code)) return;
    _currentLanguage = code;
    final prefs = await _preferences;
    await prefs.setString(_prefKey, code);
    notifyListeners();
  }

  String t(String key) {
    return _translations[_currentLanguage]?[key] ??
        _translations[defaultLanguage]![key] ??
        key;
  }

  Map<String, String> get loginTexts => {
        'sign_in_google': t('sign_in_google'),
        'signing_in': t('signing_in'),
        'welcome_cosmic': t('welcome_cosmic'),
        'select_language': t('select_language'),
      };

  Map<String, String> get cosmicEvents => {
        'quasar_storm': t('event_quasar_storm'),
        'supernova': t('event_supernova'),
        'meteor_shower': t('event_meteor_shower'),
        'black_hole_merge': t('event_black_hole_merge'),
        'cosmic_mine': t('event_cosmic_mine'),
      };

  String supernovaWarning(int seconds) =>
      t('event_supernova_warning').replaceAll('{s}', '$seconds');

  String meteorWarning(int seconds) =>
      t('event_meteor_warning').replaceAll('{s}', '$seconds');

  Map<String, String> get gameOverTexts => {
        'title': t('game_over_title'),
        'subtitle': t('game_over_subtitle'),
        'watch_ad_revive': t('game_over_watch_ad_revive'),
        'quit': t('game_over_quit'),
        'watch_match': t('game_over_watch_match'),
        'play_again': t('game_over_play_again'),
        'return_lobby': t('game_over_return_lobby'),
      };
}
