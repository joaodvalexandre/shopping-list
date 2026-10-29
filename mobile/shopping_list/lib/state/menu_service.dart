import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';

class MenuLink {
  MenuLink({required this.label, required this.url, required this.newTab, required this.children});

  final String label;

  /// Null for a heading that only holds its children.
  final String? url;
  final bool newTab;
  final List<MenuLink> children;

  static MenuLink fromJson(Map<String, dynamic> json) => MenuLink(
        label: json['label'] as String,
        url: json['url'] as String?,
        newTab: json['new_tab'] == true,
        children: [for (final child in (json['children'] as List? ?? const [])) fromJson(child as Map<String, dynamic>)],
      );
}

/// The footer and account-menu links the owner arranged in the backoffice
/// (About, Privacy policy, Terms...). Fetched in the app's language, and the
/// last answer is kept so they are there even with no connection.
class MenuService extends ChangeNotifier {
  MenuService({required this.api, required SharedPreferences prefs}) : _prefs = prefs;

  final ApiClient api;
  final SharedPreferences _prefs;

  List<MenuLink> _footer = [];
  List<MenuLink> _userMenu = [];
  String? _loadedFor;

  List<MenuLink> get footer => _footer;
  List<MenuLink> get userMenu => _userMenu;

  /// Show what was fetched last time for this language, at once.
  void loadCached(String locale) {
    final raw = _prefs.getString('menus_$locale');
    if (raw != null) _apply(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Ask the server. Quiet when it cannot be reached: the cached links stay.
  Future<void> refresh(String locale, {bool force = false}) async {
    if (!force && _loadedFor == locale) return;

    try {
      final json = await api.menus(locale);
      await _prefs.setString('menus_$locale', jsonEncode(json));
      _loadedFor = locale;
      _apply(json);
    } on ApiException {
      // offline: keep what is shown
    }
  }

  void _apply(Map<String, dynamic> json) {
    List<MenuLink> read(String key) => [
          for (final item in (json[key] as List? ?? const [])) MenuLink.fromJson(item as Map<String, dynamic>),
        ];

    _footer = read('footer');
    // The web's navbar and the account menu both end up in the app's account menu
    _userMenu = [...read('navbar'), ...read('user_menu')];
    notifyListeners();
  }
}
