import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/content.dart';
import 'content_service.dart';

/// Where the app talks to, unless the person types another server. Override
/// per build with --dart-define=API_BASE_URL=https://my.server
const defaultServerUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

/// The app's own settings: language, appearance and server. Also the source of every
/// text, taken from the local copy of the web app's own texts ([ContentService]) so the
/// wording is identical on both, and edits made in the backoffice reach the phone.
class SettingsState extends ChangeNotifier {
  SettingsState(this._prefs, this.content) {
    _language = _initialLanguage();
    // New texts, or a language added or removed, change what is on screen
    content.addListener(_contentChanged);
  }

  final SharedPreferences _prefs;
  final ContentService content;

  static const fallbackLanguage = 'en';

  /// Flags next to the language names; any other language gets a globe.
  static const _flags = {'pt': '🇵🇹', 'en': '🇬🇧', 'es': '🇪🇸', 'fr': '🇫🇷', 'de': '🇩🇪', 'it': '🇮🇹', 'nl': '🇳🇱'};

  late String _language;
  ThemeMode _themeMode = ThemeMode.system;
  String _serverUrl = defaultServerUrl;

  String get language => _language;
  Locale get locale => Locale(_language);
  ThemeMode get themeMode => _themeMode;
  String get serverUrl => _serverUrl;

  /// The languages the server offers.
  List<ContentLanguage> get languages => content.languages;

  static String flagOf(String code) => _flags[code] ?? '🌐';

  static Future<SettingsState> load(ContentService content) async {
    final state = SettingsState(await SharedPreferences.getInstance(), content);

    state._themeMode = switch (state._prefs.getString('theme')) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    state._serverUrl = state._prefs.getString('server') ?? defaultServerUrl;

    return state;
  }

  String _initialLanguage() {
    final saved = _prefs.getString('language');
    final device = ui.PlatformDispatcher.instance.locale.languageCode;

    return content.hasLanguage(saved) ? saved! : (content.hasLanguage(device) ? device : content.defaultLanguage);
  }

  void _contentChanged() {
    // The language the person chose was taken off the server
    if (!content.hasLanguage(_language)) _language = content.defaultLanguage;
    notifyListeners();
  }

  @override
  void dispose() {
    content.removeListener(_contentChanged);
    super.dispose();
  }

  /// A text of the app in the chosen language ("Pending", "Entrar"...).
  /// `:name` placeholders are replaced from [params].
  String t(String key, [Map<String, Object> params = const {}]) {
    var text = content.text(_language, key) ?? content.text(fallbackLanguage, key) ?? key;
    params.forEach((name, value) => text = text.replaceAll(':$name', value.toString()));
    return text;
  }

  Future<void> setLanguage(String code) async {
    if (!content.hasLanguage(code) || code == _language) return;
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
