/// en locale strings for [LanguageService].
const Map<String, String> kEnTranslations = {
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
          'Grow to radius 500 to finish the match (550 in Unique universes) — the universe closes for everyone. Normal: 1st +5, 2nd +3, 3rd +2 (−1 on elimination). Elite: 1st +10, 2nd +6, 3rd +4 (−2 on elimination). Unique: 1st +15, 2nd +10, 3rd +5 (−3 on elimination). Diamonds never go below 0. New players start with 25 Diamonds.',
      'how_to_play_ranks_title': 'Rank system',
      'how_to_play_ranks_desc':
          'Your star rank (Nebula → Singularity) is based on win points, not Diamonds.\n'
          'Only finishing 1st adds win points. Training wins do not count.\n'
          'Points per 1st place: Normal +{normal}, Elite +{elite}, Unique +{unique}.\n'
          'Thresholds: Stellar {stellar}+ · Nova {nova}+ · Quasar {quasar}+ · Singularity {singularity}+.\n'
          'Games Won also excludes Training. World Rank defaults to win points (Rank tab); Wealth tab sorts by Diamonds.',
      'how_to_play_currencies_title': 'Currencies',
      'how_to_play_currencies_desc':
          'New accounts start with 25 Diamonds. Tutorial Universe is free. Normal universes unlock at 25 Diamonds. Diamonds unlock Elite (100) and Unique (200) universes.',
      'how_to_play_events_title': 'Cosmic Events',
      'how_to_play_events_desc':
          'Watch for Quasar Storms, Supernovas, Meteor Showers, and more — they change the battlefield dramatically.',
      'version_notes_title': 'What\'s New',
      'version_current': 'Current version: {version}',
      'version_notes_close': 'Close',
      'version_notes_dont_show': 'Don\'t show again',
      'lobby_version_notes': 'v2.4',
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
          'New accounts start with 25 Diamonds. Tutorial is free; Normal unlocks at 25, Elite 100, Unique 200. Lobby cards show entry costs, rewards, and penalties.',
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
};
