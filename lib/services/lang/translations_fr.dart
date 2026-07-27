/// fr locale strings for [LanguageService].
const Map<String, String> kFrTranslations = {
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
      'lobby_version_notes': 'v2.3',
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
};
