import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app talks to, unless the person types another server. Override
/// per build with --dart-define=API_BASE_URL=https://my.server
const defaultServerUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

/// The app's own settings: language, appearance and server. Also the source of
/// every text, loaded from the same JSON files as the web app (assets/lang)
/// so the wording is identical on both.
class SettingsState extends ChangeNotifier {
  SettingsState(this._prefs);

  final SharedPreferences _prefs;

  static const supportedLanguages = {'pt': 'Português', 'en': 'English'};
  static const fallbackLanguage = 'en';

  final Map<String, Map<String, String>> _texts = {};

  String _language = 'pt';
  ThemeMode _themeMode = ThemeMode.system;
  String _serverUrl = defaultServerUrl;

  String get language => _language;
  Locale get locale => Locale(_language);
  ThemeMode get themeMode => _themeMode;
  String get serverUrl => _serverUrl;

  static Future<SettingsState> load() async {
    final state = SettingsState(await SharedPreferences.getInstance());

    for (final code in supportedLanguages.keys) {
      final raw = await rootBundle.loadString('assets/lang/$code.json');
      state._texts[code] = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
    }

    final saved = state._prefs.getString('language');
    final device = ui.PlatformDispatcher.instance.locale.languageCode;
    state._language = supportedLanguages.containsKey(saved)
        ? saved!
        : (supportedLanguages.containsKey(device) ? device : 'pt');

    state._themeMode = switch (state._prefs.getString('theme')) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    state._serverUrl = state._prefs.getString('server') ?? defaultServerUrl;

    return state;
  }

  /// A text of the app in the chosen language ("Pending", "Entrar"...).
  /// `:name` placeholders are replaced from [params].
  String t(String key, [Map<String, Object> params = const {}]) {
    var text = _texts[_language]?[key] ?? _texts[fallbackLanguage]?[key] ?? key;
    params.forEach((name, value) => text = text.replaceAll(':$name', value.toString()));
    return text;
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.containsKey(code) || code == _language) return;
    _language = code;
    await _prefs.setString('language', code);
    notifyListeners();
  }

  /// Light and dark only, like the web's toggle; "system" until the person picks.
  Future<void> setDark(bool dark) async {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setString('theme', dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    await _prefs.setString('server', url);
    notifyListeners();
  }
}
