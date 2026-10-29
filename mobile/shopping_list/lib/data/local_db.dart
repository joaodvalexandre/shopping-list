import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE lists (
            uuid TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            name_changed_at INTEGER NOT NULL,
            list_type_id INTEGER NOT NULL,
            hidden_from TEXT NOT NULL DEFAULT '[]',
            pending TEXT NOT NULL DEFAULT '{}'
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
            pending TEXT NOT NULL DEFAULT '{}'
          )''');
        await db.execute('CREATE INDEX items_list ON items (list_uuid)');
        await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      },
    );

    return LocalDb._(db);
  }

  Future<void> close() => _db.close();

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
