/// tr locale strings for [LanguageService].
const Map<String, String> kTrTranslations = {
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
          'Yarıçap 500\'e ulaşınca maç biter (Eşsiz evrenlerde 550) ve evren herkes için kapanır. Normal: 1. +5, 2. +3, 3. +2 (yutulma −1). Elit: 1. +10, 2. +6, 3. +4 (yutulma −2). Eşsiz: 1. +15, 2. +10, 3. +5 (yutulma −3). Elmas 0\'ın altına inmez. Yeni oyuncular 25 Elmas ile başlar.',
      'how_to_play_ranks_title': 'Rütbe sistemi',
      'how_to_play_ranks_desc':
          'Yıldız rütben (Nebula → Tekillik) elmasa değil, galibiyet puanına göre yükselir.\n'
          'Sadece 1. olmak puan ekler. Eğitim galibiyeti sayılmaz.\n'
          '1.’lik puanı: Normal +{normal}, Elite +{elite}, Unique +{unique}.\n'
          'Eşikler: Yıldız {stellar}+ · Nova {nova}+ · Kuasar {quasar}+ · Tekillik {singularity}+.\n'
          'Galibiyet sayısı da Eğitimi saymaz. Dünya sıralaması varsayılan olarak galibiyet puanına göredir (Rütbe); Zenginlik sekmesi elmasa göre sıralar.',
      'how_to_play_currencies_title': 'Para Birimleri',
      'how_to_play_currencies_desc':
          'Yeni hesaplar 25 Elmas ile başlar. Eğitim Evreni ücretsizdir. Normal evren 25 Elmas ile açılır. Elmaslar Elit (100) ve Eşsiz (200) evrenleri açar.',
      'how_to_play_events_title': 'Kozmik Olaylar',
      'how_to_play_events_desc':
          'Kuasar Fırtınası, Süpernova, Meteor Yağmuru ve daha fazlasına dikkat edin — savaş alanını dramatik şekilde değiştirirler.',
      'version_notes_title': 'Yenilikler',
      'version_current': 'Güncel sürüm: {version}',
      'version_notes_close': 'Kapat',
      'version_notes_dont_show': 'Bir daha gösterme',
      'lobby_version_notes': 'v2.3',
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
          'Yeni hesaplar 25 elmasla başlar. Eğitim ücretsiz; Normal 25, Elit 100, Eşsiz 200 elmas ister. Lobi kartları giriş, ödül ve ceza tablolarını gösterir.',
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
};
