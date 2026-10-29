import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'content.dart';
import 'models.dart';

/// Where the phone keeps the family's lists and items, plus a few settings of the
/// sync (the cursor, the last `/me`). An interface so tests can use memory.
abstract class LocalStore {
  Future<List<ShoppingListRecord>> loadAll();

  Future<void> apply({
    Iterable<ShoppingListRecord> saveLists = const [],
    Iterable<ItemRecord> saveItems = const [],
    Iterable<String> removeLists = const [],
    Iterable<String> removeItems = const [],
  });

  Future<String?> getMeta(String key);

  Future<void> setMeta(String key, String? value);

  /// The languages, texts, pages and menu links last fetched (or shipped), or null on a fresh install.
  /// Public content: signing out does not clear it.
  Future<ContentSnapshot?> loadContent();

  Future<void> saveContent(ContentSnapshot content);

  Future<void> wipe();
}

/// The SQLite implementation. Everything the person does is written here first,
/// so the app works with no connection at all.
class LocalDb implements LocalStore {
  LocalDb._(this._db);

  final Database _db;

  static Future<LocalDb> open({String? path}) async {
    final db = await openDatabase(
      path ?? p.join(await getDatabasesPath(), 'shopping_list.db'),
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createContentTables(db);
        if (oldVersion < 3) {
          // who last changed each list and item (an offline family tells who did what)
          await db.execute('ALTER TABLE lists ADD COLUMN author TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN author TEXT');
        }
      },
      onCreate: (db, version) async {
        await _createContentTables(db);
        await db.execute('''
          CREATE TABLE lists (
            uuid TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            name_changed_at INTEGER NOT NULL,
            list_type_id INTEGER NOT NULL,
            hidden_from TEXT NOT NULL DEFAULT '[]',
            pending TEXT NOT NULL DEFAULT '{}',
            author TEXT
          )''');
        await db.execute('''
          CREATE TABLE items (
            uuid TEXT PRIMARY KEY,
            list_uuid TEXT NOT NULL,
            name TEXT NOT NULL,
            name_changed_at INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            quantity_changed_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            status_changed_at INTEGER NOT NULL,
            pending TEXT NOT NULL DEFAULT '{}',
            author TEXT
          )''');
        await db.execute('CREATE INDEX items_list ON items (list_uuid)');
        await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      },
    );

    return LocalDb._(db);
  }

  static Future<void> _createContentTables(Database db) async {
    await db.execute('CREATE TABLE languages (code TEXT PRIMARY KEY, name TEXT NOT NULL, native_name TEXT NOT NULL, is_default INTEGER NOT NULL, sort INTEGER NOT NULL)');
    await db.execute('CREATE TABLE texts (locale TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (locale, key))');
    await db.execute('CREATE TABLE pages (slug TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL, sort INTEGER NOT NULL)');
    await db.execute('''
      CREATE TABLE menu_items (
        id INTEGER PRIMARY KEY,
        parent_id INTEGER,
        location TEXT NOT NULL,
        audience TEXT NOT NULL,
        label TEXT NOT NULL,
        page TEXT,
        url TEXT,
        new_tab INTEGER NOT NULL,
        sort INTEGER NOT NULL
      )''');
    await db.execute('CREATE TABLE content_meta (key TEXT PRIMARY KEY, value TEXT)');
  }

  Future<void> close() => _db.close();

  @override
  Future<ContentSnapshot?> loadContent() async {
    final version = await _db.query('content_meta', where: 'key = ?', whereArgs: ['version']);
    if (version.isEmpty) return null;

    final texts = <String, Map<String, String>>{};
    for (final row in await _db.query('texts')) {
      (texts[row['locale'] as String] ??= {})[row['key'] as String] = row['value'] as String;
    }

    return ContentSnapshot(
      version: version.first['value'] as String,
      languages: [
        for (final row in await _db.query('languages', orderBy: 'sort'))
          ContentLanguage(
            code: row['code'] as String,
            name: row['name'] as String,
            nativeName: row['native_name'] as String,
            isDefault: row['is_default'] == 1,
          ),
      ],
      texts: texts,
      pages: [
        for (final row in await _db.query('pages', orderBy: 'sort'))
          ContentPage(
            slug: row['slug'] as String,
            title: _decodeTexts(row['title']),
            content: _decodeTexts(row['content']),
          ),
      ],
      menu: [
        for (final row in await _db.query('menu_items', orderBy: 'sort'))
          MenuEntry(
            id: row['id'] as int,
            parentId: row['parent_id'] as int?,
            location: row['location'] as String,
            audience: row['audience'] as String,
            label: _decodeTexts(row['label']),
            page: row['page'] as String?,
            url: row['url'] as String?,
            newTab: row['new_tab'] == 1,
          ),
      ],
    );
  }

  /// Replaces all the content at once, all or nothing.
  @override
  Future<void> saveContent(ContentSnapshot content) async {
    await _db.transaction((txn) async {
      for (final table in ['languages', 'texts', 'pages', 'menu_items', 'content_meta']) {
        await txn.delete(table);
      }

      final batch = txn.batch();
      var sort = 0;
      for (final language in content.languages) {
        batch.insert('languages', {
          'code': language.code,
          'name': language.name,
          'native_name': language.nativeName,
          'is_default': language.isDefault ? 1 : 0,
          'sort': sort++,
        });
      }
      for (final locale in content.texts.entries) {
        for (final text in locale.value.entries) {
          batch.insert('texts', {'locale': locale.key, 'key': text.key, 'value': text.value});
        }
      }
      sort = 0;
      for (final page in content.pages) {
        batch.insert('pages', {'slug': page.slug, 'title': jsonEncode(page.title), 'content': jsonEncode(page.content), 'sort': sort++});
      }
      sort = 0;
      for (final entry in content.menu) {
        batch.insert('menu_items', {
          'id': entry.id,
          'parent_id': entry.parentId,
          'location': entry.location,
          'audience': entry.audience,
          'label': jsonEncode(entry.label),
          'page': entry.page,
          'url': entry.url,
          'new_tab': entry.newTab ? 1 : 0,
          'sort': sort++,
        });
      }
      batch.insert('content_meta', {'key': 'version', 'value': content.version});
      await batch.commit(noResult: true);
    });
  }

  static Map<String, String> _decodeTexts(Object? raw) =>
      (jsonDecode(raw as String) as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));

  /// Every list with its items.
  @override
  Future<List<ShoppingListRecord>> loadAll() async {
    final lists = (await _db.query('lists')).map(ShoppingListRecord.fromRow).toList();
    final byUuid = {for (final list in lists) list.uuid: list};

    for (final row in await _db.query('items')) {
      final item = ItemRecord.fromRow(row);
      byUuid[item.listUuid]?.items.add(item);
    }

    return lists;
  }

  /// Several changes at once, all or nothing.
  @override
  Future<void> apply({
    Iterable<ShoppingListRecord> saveLists = const [],
    Iterable<ItemRecord> saveItems = const [],
    Iterable<String> removeLists = const [],
    Iterable<String> removeItems = const [],
  }) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();

      for (final uuid in removeLists) {
        batch.delete('items', where: 'list_uuid = ?', whereArgs: [uuid]);
        batch.delete('lists', where: 'uuid = ?', whereArgs: [uuid]);
      }
      for (final uuid in removeItems) {
        batch.delete('items', where: 'uuid = ?', whereArgs: [uuid]);
      }
      for (final list in saveLists) {
        batch.insert('lists', list.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final item in saveItems) {
        batch.insert('items', item.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
    });
  }

  @override
  Future<String?> getMeta(String key) async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      await _db.delete('meta', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Forget everything (signing out: the next person must not see this family's data).
  @override
  Future<void> wipe() async {
    await _db.transaction((txn) async {
      await txn.delete('items');
      await txn.delete('lists');
      await txn.delete('meta');
    });
  }
}
