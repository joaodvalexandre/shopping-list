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
    _remember();
    // New texts, or a language added or removed, change what is on screen
    content.addListener(_contentChanged);
  }

  final SharedPreferences _prefs;
  final ContentService content;

  /// Flags next to the language names; any other language gets a globe.
  static const _flags = {'pt': '🇵🇹', 'en': '🇬🇧', 'es': '🇪🇸', 'fr': '🇫🇷', 'de': '🇩🇪', 'it': '🇮🇹', 'nl': '🇳🇱'};

  /// Where the language in use is remembered for code that runs without the app (notifications).
  static const effectiveLanguageKey = 'language_effective';

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

  /// The notifier that runs without the app words its messages in this language.
  void _remember() => _prefs.setString(effectiveLanguageKey, _language);

  void _contentChanged() {
    // The language the person chose was taken off the server
    if (!content.hasLanguage(_language)) _language = content.defaultLanguage;
    _remember();
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
    return content.translate(_language, key, params);
  }

  Future<void> setLanguage(String code) async {
    if (!content.hasLanguage(code) || code == _language) return;
    _language = code;
    await _prefs.setString('language', code);
    _remember();
    notifyListeners();
  }

  /// Light and dark only, like the web's toggle; "system" until the person picks.
  Future<void> setDark(bool dark) async {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setString('theme', dark ? 'dark' : 'light');
    notifyListeners();
  }

  /// Light, dark, or what the phone is set to.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString('theme', switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  /// A server family can ask for the app to keep running with the screen off or closed (a
  /// notification stays), so what others do reaches the phone at once and not every quarter of an
  /// hour. An offline family always does (its phones can only talk through the app).
  bool get keepRunning => _prefs.getBool('keep_running') ?? false;

  Future<void> setKeepRunning(bool on) async {
    await _prefs.setBool('keep_running', on);
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    await _prefs.setString('server', url);
    notifyListeners();
  }
}
