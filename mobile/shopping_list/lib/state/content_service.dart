import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/api_client.dart';
import '../data/content.dart';
import '../data/local_db.dart';

/// Who is looking at a menu, for the audience each link was given in the backoffice.
enum Viewer { guest, member, familyAdmin }

/// The app's own copy of what the web app serves besides the lists: languages, every
/// text, content pages (About, Privacy, Terms...) and menu links. Read from the local
/// database, so it all works with no connection; a fresh install starts from the copy
/// shipped in the app, and `refresh` brings whatever the owner changed in the backoffice.
class ContentService extends ChangeNotifier {
  ContentService(this._store, [ContentSnapshot initial = ContentSnapshot.empty]) : _data = initial;

  final LocalStore _store;
  ContentSnapshot _data;
  bool _refreshing = false;

  /// What the app ships with (`php artisan mobile:export-content` writes it).
  static const bundledAsset = 'assets/content.json';

  /// Open the local copy, putting the shipped one in place on a fresh install.
  static Future<ContentService> load(LocalStore store, {Future<String> Function()? bundled}) async {
    var snapshot = await store.loadContent();

    if (snapshot == null) {
      snapshot = ContentSnapshot.parse(await (bundled ?? () => rootBundle.loadString(bundledAsset))());
      await store.saveContent(snapshot);
    }

    return ContentService(store, snapshot);
  }

  String get version => _data.version;
  List<ContentLanguage> get languages => _data.languages;

  String get defaultLanguage =>
      _data.languages.where((l) => l.isDefault).firstOrNull?.code ?? _data.languages.firstOrNull?.code ?? 'en';

  bool hasLanguage(String? code) => code != null && _data.languages.any((l) => l.code == code);

  /// A text in a language, else null (the caller falls back).
  String? text(String language, String key) => _data.texts[language]?[key];

  ContentPage? page(String slug) => _data.pages.where((p) => p.slug == slug).firstOrNull;

  List<ContentPage> get pages => _data.pages;

  String titleOf(ContentPage page, String language) => _inLanguage(page.title, language) ?? page.slug;

  String contentOf(ContentPage page, String language) => _inLanguage(page.content, language) ?? '';

  /// The links of a menu ('navbar', 'user_menu' or 'footer') this viewer may see, in their
  /// language: headings with the links under them, headings left empty dropped.
  List<MenuLink> links(String location, {required String language, required Viewer viewer}) {
    final entries = _data.menu.where((e) => e.location == location && _isFor(e.audience, viewer)).toList();

    MenuLink link(MenuEntry entry, List<MenuLink> children) => MenuLink(
          label: _inLanguage(entry.label, language) ?? entry.page ?? entry.url ?? '',
          page: entry.page,
          url: entry.url,
          children: children,
        );

    return [
      for (final top in entries.where((e) => e.parentId == null))
        if (_build(top, entries, link) case final built? when built.goesSomewhere || built.children.isNotEmpty) built,
    ];
  }

  MenuLink? _build(MenuEntry top, List<MenuEntry> entries, MenuLink Function(MenuEntry, List<MenuLink>) link) {
    final children = [
      for (final child in entries.where((e) => e.parentId == top.id)) link(child, const []),
    ].where((child) => child.goesSomewhere).toList();

    return link(top, children);
  }

  bool _isFor(String audience, Viewer viewer) => switch (audience) {
        'guests' => viewer == Viewer.guest,
        'members' => viewer != Viewer.guest,
        'family_admins' => viewer == Viewer.familyAdmin,
        _ => true,
      };

  /// The text in the language, else in the default language, else any that has one.
  String? _inLanguage(Map<String, String> texts, String language) {
    for (final code in [language, defaultLanguage]) {
      final text = texts[code];
      if (text != null && text.isNotEmpty) return text;
    }
    return texts.values.where((t) => t.isNotEmpty).firstOrNull;
  }

  /// Ask the server for anything new. Quiet when it cannot be reached: the local copy stays.
  /// Returns true when something changed.
  Future<bool> refresh(ApiClient api) async {
    if (_refreshing) return false;
    _refreshing = true;

    try {
      final json = await api.content(version: _data.version);
      if (json['unchanged'] == true) return false;

      final fresh = ContentSnapshot.fromJson(json);
      // Never swap a working copy for an empty one
      if (fresh.languages.isEmpty || fresh.version == _data.version) return false;

      await _store.saveContent(fresh);
      _data = fresh;
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
