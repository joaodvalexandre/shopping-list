import 'dart:convert';

/// Statuses an item moves through (the API's `to_buy`, `in_cart`, `purchased`).
enum ItemStatus {
  toBuy('to_buy'),
  inCart('in_cart'),
  purchased('purchased');

  const ItemStatus(this.code);
  final String code;

  static ItemStatus fromCode(String? code) =>
      ItemStatus.values.firstWhere((s) => s.code == code, orElse: () => ItemStatus.toBuy);
}

/// What was changed on this phone and has not reached the server yet.
///
/// A map from field name to the time (ms) the change was made. A new record is
/// `new`, a deletion is `deleted`; anything else is a field of the record.
class Pending {
  Pending([Map<String, int>? fields]) : fields = fields ?? {};

  final Map<String, int> fields;

  static const created = 'new';
  static const deleted = 'deleted';

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => fields.isNotEmpty;
  bool get isNew => fields.containsKey(created);
  bool get isDeleted => fields.containsKey(deleted);
  bool has(String field) => fields.containsKey(field);

  void mark(String field, int atMs) => fields[field] = atMs;

  /// Forget what was sent, but only the changes that were not touched again
  /// while the request was in flight.
  void clearSent(Map<String, int> sent) {
    sent.forEach((field, at) {
      if (fields[field] == at) fields.remove(field);
    });
  }

  String encode() => jsonEncode(fields);

  static Pending decode(String? raw) {
    if (raw == null || raw.isEmpty) return Pending();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return Pending(decoded.map((k, v) => MapEntry(k, (v as num).toInt())));
  }

  Pending copy() => Pending(Map.of(fields));
}

class ShoppingListRecord {
  ShoppingListRecord({
    required this.uuid,
    required this.name,
    required this.nameChangedAt,
    required this.listTypeId,
    this.hiddenFrom = const [],
    Pending? pending,
    this.author,
  }) : pending = pending ?? Pending();

  final String uuid;

  /// Who last changed it (a name), for a family that has no server to say: told with the change, so that a
  /// phone that hears of it from a third one still knows whose doing it was.
  String? author;
  String name;
  int nameChangedAt;
  final int listTypeId;
  List<int> hiddenFrom;
  Pending pending;

  /// Items of this list, filled in by the repository.
  List<ItemRecord> items = [];

  int get toBuy => items.where((i) => i.status == ItemStatus.toBuy).length;
  int get inCart => items.where((i) => i.status == ItemStatus.inCart).length;
  int get purchased => items.where((i) => i.status == ItemStatus.purchased).length;
  int get total => items.length;

  Map<String, Object?> toRow() => {
        'uuid': uuid,
        'name': name,
        'name_changed_at': nameChangedAt,
        'list_type_id': listTypeId,
        'hidden_from': jsonEncode(hiddenFrom),
        'pending': pending.encode(),
        'author': author,
      };

  static ShoppingListRecord fromRow(Map<String, Object?> row) => ShoppingListRecord(
        uuid: row['uuid'] as String,
        name: row['name'] as String,
        nameChangedAt: row['name_changed_at'] as int,
        listTypeId: row['list_type_id'] as int,
        hiddenFrom: (jsonDecode(row['hidden_from'] as String? ?? '[]') as List).map((e) => (e as num).toInt()).toList(),
        pending: Pending.decode(row['pending'] as String?),
        author: row['author'] as String?,
      );
}

class ItemRecord {
  ItemRecord({
    required this.uuid,
    required this.listUuid,
    required this.name,
    required this.nameChangedAt,
    required this.quantity,
    required this.quantityChangedAt,
    required this.status,
    required this.statusChangedAt,
    Pending? pending,
    this.author,
  }) : pending = pending ?? Pending();

  /// Who last changed it (a name): see [ShoppingListRecord.author].
  String? author;

  final String uuid;
  final String listUuid;
  String name;
  int nameChangedAt;
  int quantity;
  int quantityChangedAt;
  ItemStatus status;
  int statusChangedAt;
  Pending pending;

  Map<String, Object?> toRow() => {
        'uuid': uuid,
        'list_uuid': listUuid,
        'name': name,
        'name_changed_at': nameChangedAt,
        'quantity': quantity,
        'quantity_changed_at': quantityChangedAt,
        'status': status.code,
        'status_changed_at': statusChangedAt,
        'pending': pending.encode(),
        'author': author,
      };

  static ItemRecord fromRow(Map<String, Object?> row) => ItemRecord(
        uuid: row['uuid'] as String,
        listUuid: row['list_uuid'] as String,
        name: row['name'] as String,
        nameChangedAt: row['name_changed_at'] as int,
        quantity: row['quantity'] as int,
        quantityChangedAt: row['quantity_changed_at'] as int,
        status: ItemStatus.fromCode(row['status'] as String?),
        statusChangedAt: row['status_changed_at'] as int,
        pending: Pending.decode(row['pending'] as String?),
        author: row['author'] as String?,
      );
}

/// The kind of a list's overall state, as the web app's dashboard shows it.
enum ListState {
  noItems('no_items', 'gray'),
  finished('finished', 'green'),
  allInCart('all_in_cart', 'blue'),
  shopping('shopping', 'orange'),
  pending('pending', 'yellow'),
  mixed('mixed', 'purple');

  const ListState(this.textKey, this.color);
  final String textKey;
  final String color;

  /// Same rules as `ShoppingList::calculateStatus()` on the server.
  static ListState of(ShoppingListRecord list) {
    final total = list.total;
    if (total == 0) return noItems;
    if (list.purchased == total) return finished;
    if (list.inCart == total) return allInCart;
    if (list.inCart > 0) return shopping;
    if (list.toBuy == total) return pending;
    return mixed;
  }
}
