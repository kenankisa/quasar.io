/// es locale strings for [LanguageService].
const Map<String, String> kEsTranslations = {
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
      'lobby_version_notes': 'v2.4',
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
};
