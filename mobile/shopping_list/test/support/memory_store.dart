import 'package:shopping_list/data/local_db.dart';
import 'package:shopping_list/data/models.dart';

/// A [LocalStore] in memory, for tests.
class MemoryStore implements LocalStore {
  final lists = <String, ShoppingListRecord>{};
  final items = <String, ItemRecord>{};
  final meta = <String, String>{};

  @override
  Future<List<ShoppingListRecord>> loadAll() async {
    final copies = lists.values.map((l) => ShoppingListRecord.fromRow(l.toRow())).toList();
    final byUuid = {for (final l in copies) l.uuid: l};
    for (final item in items.values) {
      byUuid[item.listUuid]?.items.add(ItemRecord.fromRow(item.toRow()));
    }
    return copies;
  }

  @override
  Future<void> apply({
    Iterable<ShoppingListRecord> saveLists = const [],
    Iterable<ItemRecord> saveItems = const [],
    Iterable<String> removeLists = const [],
    Iterable<String> removeItems = const [],
  }) async {
    for (final uuid in removeLists) {
      lists.remove(uuid);
      items.removeWhere((_, item) => item.listUuid == uuid);
    }
    for (final uuid in removeItems) {
      items.remove(uuid);
    }
    for (final list in saveLists) {
      lists[list.uuid] = ShoppingListRecord.fromRow(list.toRow());
    }
    for (final item in saveItems) {
      items[item.uuid] = ItemRecord.fromRow(item.toRow());
    }
  }

  @override
  Future<String?> getMeta(String key) async => meta[key];

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      meta.remove(key);
    } else {
      meta[key] = value;
    }
  }

  @override
  Future<void> wipe() async {
    lists.clear();
    items.clear();
    meta.clear();
  }
}
