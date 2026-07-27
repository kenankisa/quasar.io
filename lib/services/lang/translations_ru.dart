/// ru locale strings for [LanguageService].
const Map<String, String> kRuTranslations = {
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
      'lobby_version_notes': 'v2.4',
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
};
