import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lang/translations_en.dart';
import 'lang/translations_supplement_en.dart';
import 'lang/translations_tr.dart' deferred as lang_tr;
import 'lang/translations_supplement_tr.dart' deferred as lang_tr_sup;
import 'lang/translations_de.dart' deferred as lang_de;
import 'lang/translations_ru.dart' deferred as lang_ru;
import 'lang/translations_es.dart' deferred as lang_es;
import 'lang/translations_fr.dart' deferred as lang_fr;

/// Desteklenen diller ve yerelleştirilmiş metin haritası.
///
/// Varsayılan dil ([defaultLanguage]) senkron yüklenir; diğer diller
/// [deferred] import ile ilk kullanımda lazy-load edilir.
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

  static Map<String, String> _merged(
    Map<String, String> base,
    Map<String, String> supplement,
  ) =>
      {...base, ...supplement};

  final Map<String, Map<String, String>> _loaded = {
    defaultLanguage:
        _merged(kEnTranslations, kEnTranslationsSupplement),
  };

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _ensureLocaleLoaded(String code) async {
    if (_loaded.containsKey(code)) return;
    switch (code) {
      case 'tr':
        await lang_tr.loadLibrary();
        await lang_tr_sup.loadLibrary();
        _loaded['tr'] = _merged(
          _merged(lang_tr.kTrTranslations, kEnTranslationsSupplement),
          lang_tr_sup.kTrTranslationsSupplement,
        );
      case 'de':
        await lang_de.loadLibrary();
        _loaded['de'] =
            _merged(lang_de.kDeTranslations, kEnTranslationsSupplement);
      case 'ru':
        await lang_ru.loadLibrary();
        _loaded['ru'] =
            _merged(lang_ru.kRuTranslations, kEnTranslationsSupplement);
      case 'es':
        await lang_es.loadLibrary();
        _loaded['es'] =
            _merged(lang_es.kEsTranslations, kEnTranslationsSupplement);
      case 'fr':
        await lang_fr.loadLibrary();
        _loaded['fr'] =
            _merged(lang_fr.kFrTranslations, kEnTranslationsSupplement);
      case defaultLanguage:
        _loaded[defaultLanguage] =
            _merged(kEnTranslations, kEnTranslationsSupplement);
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await _preferences;
    final saved = prefs.getString(_prefKey);
    if (saved != null && supportedLanguages.contains(saved)) {
      _currentLanguage = saved;
    }
    await _ensureLocaleLoaded(_currentLanguage);
    if (_currentLanguage != defaultLanguage) {
      await _ensureLocaleLoaded(defaultLanguage);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.contains(code)) return;
    if (_currentLanguage == code) return;
    await _ensureLocaleLoaded(code);
    _currentLanguage = code;
    notifyListeners();
    final prefs = await _preferences;
    await prefs.setString(_prefKey, code);
  }

  String t(String key) {
    return _loaded[_currentLanguage]?[key] ??
        _loaded[defaultLanguage]?[key] ??
        kEnTranslationsSupplement[key] ??
        kEnTranslations[key] ??
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
        // Revive ad not productized — omit until shipped.
        'quit': t('game_over_quit'),
        'watch_match': t('game_over_watch_match'),
        'play_again': t('game_over_play_again'),
        'return_lobby': t('game_over_return_lobby'),
      };
}
