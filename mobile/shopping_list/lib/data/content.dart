import 'dart:convert';

import '../core/time.dart';

/// A language the server offers.
class ContentLanguage {
  const ContentLanguage({required this.code, required this.name, required this.nativeName, required this.isDefault});

  final String code;
  final String name;
  final String nativeName;
  final bool isDefault;

  static ContentLanguage fromJson(Map<String, dynamic> json) => ContentLanguage(
        code: json['code'] as String,
        name: json['name'] as String? ?? json['code'] as String,
        nativeName: json['native_name'] as String? ?? json['name'] as String? ?? json['code'] as String,
        isDefault: json['is_default'] == true,
      );
}

/// A content page (About, Privacy, Terms...) with its title and HTML text per language.
class ContentPage {
  const ContentPage({required this.slug, required this.title, required this.content});

  final String slug;
  final Map<String, String> title;
  final Map<String, String> content;

  static ContentPage fromJson(Map<String, dynamic> json) => ContentPage(
        slug: json['slug'] as String,
        title: _texts(json['title']),
        content: _texts(json['content']),
      );
}

/// One link of the navbar, account menu or footer, with who it is meant for.
class MenuEntry {
  const MenuEntry({
    required this.id,
    required this.parentId,
    required this.location,
    required this.audience,
    required this.label,
    required this.page,
    required this.url,
    required this.newTab,
  });

  final int id;
  final int? parentId;
  final String location;
  final String audience;
  final Map<String, String> label;

  /// The slug of a content page, which opens inside the app...
  final String? page;

  /// ...or an address, which opens in the browser. Both null: a heading.
  final String? url;
  final bool newTab;

  static MenuEntry fromJson(Map<String, dynamic> json) => MenuEntry(
        id: (json['id'] as num).toInt(),
        parentId: (json['parent_id'] as num?)?.toInt(),
        location: json['location'] as String,
        audience: json['audience'] as String? ?? 'everyone',
        label: _texts(json['label']),
        page: json['page'] as String?,
        url: json['url'] as String?,
        newTab: json['new_tab'] == true,
      );
}

/// What a person sees in a menu, after audience and language are applied.
class MenuLink {
  const MenuLink({required this.label, this.page, this.url, this.children = const []});

  final String label;
  final String? page;
  final String? url;
  final List<MenuLink> children;

  bool get goesSomewhere => page != null || url != null;
}

/// Everything the app keeps besides the family's lists, as the server sends it
/// (`GET /content`): languages, every text in each language, content pages and menu links.
class ContentSnapshot {
  const ContentSnapshot({
    required this.version,
    required this.languages,
    required this.texts,
    required this.pages,
    required this.menu,
  });

  final String version;
  final List<ContentLanguage> languages;
  final Map<String, Map<String, String>> texts;
  final List<ContentPage> pages;
  final List<MenuEntry> menu;

  static const empty = ContentSnapshot(version: '', languages: [], texts: {}, pages: [], menu: []);

  static ContentSnapshot fromJson(Map<String, dynamic> json) => ContentSnapshot(
        version: json['version'] as String? ?? '',
        languages: [for (final l in (json['languages'] as List? ?? const [])) ContentLanguage.fromJson(asMap(l))],
        texts: {for (final e in asMap(json['texts']).entries) e.key: _texts(e.value)},
        pages: [for (final p in (json['pages'] as List? ?? const [])) ContentPage.fromJson(asMap(p))],
        menu: [for (final m in (json['menu'] as List? ?? const [])) MenuEntry.fromJson(asMap(m))],
      );

  static ContentSnapshot parse(String raw) => fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

Map<String, String> _texts(Object? value) => {
      for (final e in asMap(value).entries)
        if (e.value != null) e.key: e.value.toString(),
    };
