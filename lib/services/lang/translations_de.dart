/// de locale strings for [LanguageService].
const Map<String, String> kDeTranslations = {
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
      'lobby_version_notes': 'v2.3',
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
};
