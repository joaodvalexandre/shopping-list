import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/time.dart';
import 'local_db.dart';
import 'me.dart';
import 'models.dart';

/// A change the server refused (the person lacked the permission, the list was
/// removed...). The app shows these instead of retrying forever.
class Rejection {
  Rejection({required this.isList, required this.name, required this.reason, this.fields = const []});

  final bool isList;
  final String name;
  final String reason;
  final List<String> fields;
}

/// What a sync round brought back, for the app to react to.
class SyncOutcome {
  final List<Rejection> rejections = [];
  bool needsFullPull = false;
}

/// The family's lists and items on this phone.
///
/// Every edit is applied here at once and written to the local database; what
/// has not reached the server yet is remembered per field in `pending`, and is
/// sent with the next sync. The server's answer is merged back field by field.
class Repository extends ChangeNotifier {
  Repository(this._db);

  final LocalStore _db;
  final _uuid = const Uuid();

  final Map<String, ShoppingListRecord> _lists = {};
  Me? _me;

  /// Called after every local edit, so the app can sync soon.
  VoidCallback? onLocalChange;

  Me? get me => _me;

  Future<void> load() async {
    _lists
      ..clear()
      ..addEntries((await _db.loadAll()).map((list) => MapEntry(list.uuid, list)));

    final rawMe = await _db.getMeta('me');
    _me = rawMe == null ? null : Me.fromJson(jsonDecode(rawMe) as Map<String, dynamic>);
    notifyListeners();
  }

  // ---------------------------------------------------------------- reading

  /// Lists to show, by name. Lists deleted on this phone but not yet on the server are hidden.
  List<ShoppingListRecord> get lists {
    final visible = _lists.values.where((list) => !list.pending.isDeleted).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return visible;
  }

  ShoppingListRecord? list(String uuid) {
    final list = _lists[uuid];
    return (list == null || list.pending.isDeleted) ? null : list;
  }

  /// Items of a list to show: to buy first, then in the cart, then purchased (like the web).
  List<ItemRecord> itemsOf(String listUuid) {
    final items = (list(listUuid)?.items ?? const <ItemRecord>[]).where((item) => !item.pending.isDeleted).toList();
    items.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      return byStatus != 0 ? byStatus : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  String listTypeName(int id) => _me?.listTypes[id] ?? '';

  bool can(ShoppingListRecord list, Ability ability) => _me?.can(list.listTypeId, ability) ?? false;

  /// How many local changes still wait for the server.
  int get pendingCount {
    var count = 0;
    for (final list in _lists.values) {
      if (list.pending.isNotEmpty) count++;
      count += list.items.where((item) => item.pending.isNotEmpty).length;
    }
    return count;
  }

  // ---------------------------------------------------------------- editing

  ShoppingListRecord createList({required String name, required int listTypeId, List<int> hiddenFrom = const []}) {
    final at = nowMs();
    final list = ShoppingListRecord(
      uuid: _uuid.v4(),
      name: name.trim(),
      nameChangedAt: at,
      listTypeId: listTypeId,
      hiddenFrom: List.of(hiddenFrom),
      pending: Pending({Pending.created: at}),
    );

    _lists[list.uuid] = list;
    _changed(saveLists: [list]);
    return list;
  }

  void updateList(String uuid, {required String name, List<int>? hiddenFrom}) {
    final list = _lists[uuid];
    if (list == null) return;

    final at = nowMs();
    if (name.trim() != list.name) {
      list.name = name.trim();
      list.nameChangedAt = at;
      list.pending.mark('name', at);
    }
    if (hiddenFrom != null && !_sameIds(hiddenFrom, list.hiddenFrom)) {
      list.hiddenFrom = List.of(hiddenFrom);
      list.pending.mark('hidden_from', at);
    }

    _changed(saveLists: [list]);
  }

  void deleteList(String uuid) {
    final list = _lists[uuid];
    if (list == null) return;

    if (list.pending.isNew) {
      // Never reached the server: nothing to tell it
      _lists.remove(uuid);
      _changed(removeLists: [uuid]);
      return;
    }

    list.pending.mark(Pending.deleted, nowMs());
    _changed(saveLists: [list]);
  }

  ItemRecord addItem(String listUuid, {required String name, required int quantity}) {
    final list = _lists[listUuid]!;
    final at = nowMs();
    final item = ItemRecord(
      uuid: _uuid.v4(),
      listUuid: listUuid,
      name: name.trim(),
      nameChangedAt: at,
      quantity: quantity,
      quantityChangedAt: at,
      status: ItemStatus.toBuy,
      statusChangedAt: at,
      pending: Pending({Pending.created: at}),
    );

    list.items.add(item);
    _changed(saveItems: [item]);
    return item;
  }

  void updateItem(String listUuid, String uuid, {required String name, required int quantity}) {
    final item = _item(listUuid, uuid);
    if (item == null) return;

    final at = nowMs();
    if (name.trim() != item.name) {
      item.name = name.trim();
      item.nameChangedAt = at;
      item.pending.mark('name', at);
    }
    if (quantity != item.quantity) {
      item.quantity = quantity;
      item.quantityChangedAt = at;
      item.pending.mark('quantity', at);
    }

    _changed(saveItems: [item]);
  }

  void setStatus(String listUuid, String uuid, ItemStatus status) {
    final item = _item(listUuid, uuid);
    if (item == null || item.status == status) return;

    final at = nowMs();
    item.status = status;
    item.statusChangedAt = at;
    item.pending.mark('status', at);
    _changed(saveItems: [item]);
  }

  /// "Finish list": everything in the cart becomes purchased.
  void markPurchased(String listUuid) {
    final list = _lists[listUuid];
    if (list == null) return;

    final at = nowMs();
    final changed = <ItemRecord>[];
    for (final item in list.items.where((i) => i.status == ItemStatus.inCart && !i.pending.isDeleted)) {
      item.status = ItemStatus.purchased;
      item.statusChangedAt = at;
      item.pending.mark('status', at);
      changed.add(item);
    }

    if (changed.isNotEmpty) _changed(saveItems: changed);
  }

  void deleteItem(String listUuid, String uuid) {
    final list = _lists[listUuid];
    final item = _item(listUuid, uuid);
    if (list == null || item == null) return;

    if (item.pending.isNew) {
      list.items.remove(item);
      _changed(removeItems: [uuid]);
      return;
    }

    item.pending.mark(Pending.deleted, nowMs());
    _changed(saveItems: [item]);
  }

  ItemRecord? _item(String listUuid, String uuid) {
    final items = _lists[listUuid]?.items ?? const <ItemRecord>[];
    for (final item in items) {
      if (item.uuid == uuid) return item;
    }
    return null;
  }

  bool _sameIds(List<int> a, List<int> b) => setEquals(a.toSet(), b.toSet());

  void _changed({
    Iterable<ShoppingListRecord> saveLists = const [],
    Iterable<ItemRecord> saveItems = const [],
    Iterable<String> removeLists = const [],
    Iterable<String> removeItems = const [],
  }) {
    _db.apply(saveLists: saveLists, saveItems: saveItems, removeLists: removeLists, removeItems: removeItems);
    notifyListeners();
    onLocalChange?.call();
  }

  // ------------------------------------------------------------------- sync

  /// The cursor to send as `since` (null: ask for everything).
  Future<String?> get since => _db.getMeta('since');

  /// The request body: only what changed on this phone, and every list it holds.
  ({Map<String, dynamic> payload, Map<String, Map<String, int>> sent}) buildPush(String? since) {
    final sent = <String, Map<String, int>>{};
    final lists = <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[];

    for (final list in _lists.values) {
      final pending = list.pending;

      if (pending.isNotEmpty) {
        sent[list.uuid] = Map.of(pending.fields);

        if (pending.isDeleted) {
          lists.add({'uuid': list.uuid, 'deleted_at': isoFromMs(pending.fields[Pending.deleted]!)});
        } else if (pending.isNew) {
          lists.add({
            'uuid': list.uuid,
            'name': list.name,
            'name_changed_at': isoFromMs(list.nameChangedAt),
            'list_type_id': list.listTypeId,
            'hidden_from': list.hiddenFrom,
          });
        } else {
          lists.add({
            'uuid': list.uuid,
            if (pending.has('name')) ...{'name': list.name, 'name_changed_at': isoFromMs(list.nameChangedAt)},
            if (pending.has('hidden_from')) 'hidden_from': list.hiddenFrom,
          });
        }
      }

      for (final item in list.items) {
        final itemPending = item.pending;
        if (itemPending.isEmpty || pending.isDeleted) continue;
        sent[item.uuid] = Map.of(itemPending.fields);

        if (itemPending.isDeleted) {
          items.add({'uuid': item.uuid, 'list_uuid': list.uuid, 'deleted_at': isoFromMs(itemPending.fields[Pending.deleted]!)});
        } else if (itemPending.isNew) {
          items.add({
            'uuid': item.uuid,
            'list_uuid': list.uuid,
            'name': item.name,
            'name_changed_at': isoFromMs(item.nameChangedAt),
            'quantity': item.quantity,
            'quantity_changed_at': isoFromMs(item.quantityChangedAt),
            'status': item.status.code,
            'status_changed_at': isoFromMs(item.statusChangedAt),
          });
        } else {
          items.add({
            'uuid': item.uuid,
            'list_uuid': list.uuid,
            if (itemPending.has('name')) ...{'name': item.name, 'name_changed_at': isoFromMs(item.nameChangedAt)},
            if (itemPending.has('quantity')) ...{'quantity': item.quantity, 'quantity_changed_at': isoFromMs(item.quantityChangedAt)},
            if (itemPending.has('status')) ...{'status': item.status.code, 'status_changed_at': isoFromMs(item.statusChangedAt)},
          });
        }
      }
    }

    final payload = <String, dynamic>{
      'since': ?since,
      // Lists the server already knows; one created offline is not known yet
      'known_lists': [for (final list in _lists.values) if (!list.pending.isNew) list.uuid],
      if (lists.isNotEmpty || items.isNotEmpty) 'changes': {'lists': lists, 'items': items},
    };

    return (payload: payload, sent: sent);
  }

  /// Merge the server's answer into the local copy (see docs/api.md, "What the phone must do").
  Future<SyncOutcome> applyResponse(Map<String, dynamic> response, Map<String, Map<String, int>> sent) async {
    final outcome = SyncOutcome();
    final saveLists = <ShoppingListRecord>{};
    final saveItems = <ItemRecord>{};
    final removeLists = <String>{};
    final removeItems = <String>{};

    // (PHP encodes an empty object as [], so these are read leniently)
    final results = asMap(response['results']);
    final listResults = asMap(results['lists']);
    final itemResults = asMap(results['items']);

    // 1. What happened to the changes this phone sent
    for (final list in _lists.values.toList()) {
      final result = listResults[list.uuid] as Map<String, dynamic>?;
      if (result == null || !sent.containsKey(list.uuid)) continue;

      final wasNew = sent[list.uuid]!.containsKey(Pending.created);
      final wasDeleted = sent[list.uuid]!.containsKey(Pending.deleted);

      switch (result['status']) {
        case 'applied':
          list.pending.clearSent(sent[list.uuid]!);
          if (wasDeleted && list.pending.isEmpty) {
            _lists.remove(list.uuid);
            removeLists.add(list.uuid);
          } else {
            saveLists.add(list);
          }
        case 'ignored':
          _lists.remove(list.uuid);
          removeLists.add(list.uuid);
        default:
          outcome.rejections.add(Rejection(
            isList: true,
            name: list.name,
            reason: result['reason']?.toString() ?? 'rejected',
            fields: ((result['fields'] as List?) ?? const []).map((f) => f.toString()).toList(),
          ));
          outcome.needsFullPull = true;
          if (wasNew) {
            _lists.remove(list.uuid);
            removeLists.add(list.uuid);
          } else {
            list.pending.clearSent(sent[list.uuid]!);
            saveLists.add(list);
          }
      }
    }

    for (final list in _lists.values.toList()) {
      for (final item in list.items.toList()) {
        final result = itemResults[item.uuid] as Map<String, dynamic>?;
        if (result == null || !sent.containsKey(item.uuid)) continue;

        final wasNew = sent[item.uuid]!.containsKey(Pending.created);
        final wasDeleted = sent[item.uuid]!.containsKey(Pending.deleted);

        switch (result['status']) {
          case 'applied':
            item.pending.clearSent(sent[item.uuid]!);
            if (wasDeleted && item.pending.isEmpty) {
              list.items.remove(item);
              removeItems.add(item.uuid);
            } else {
              saveItems.add(item);
            }
          case 'ignored':
            list.items.remove(item);
            removeItems.add(item.uuid);
          default:
            outcome.rejections.add(Rejection(
              isList: false,
              name: item.name,
              reason: result['reason']?.toString() ?? 'rejected',
              fields: ((result['fields'] as List?) ?? const []).map((f) => f.toString()).toList(),
            ));
            outcome.needsFullPull = true;
            if (wasNew) {
              list.items.remove(item);
              removeItems.add(item.uuid);
            } else {
              item.pending.clearSent(sent[item.uuid]!);
              saveItems.add(item);
            }
        }
      }
    }

    // 2. What the server has: replace our copy field by field (but never a field changed since)
    for (final json in (response['lists'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uuid = json['uuid'] as String;

      if (json['deleted_at'] != null) {
        if (_lists.remove(uuid) != null) removeLists.add(uuid);
        continue;
      }

      final local = _lists[uuid];
      final list = local ?? ShoppingListRecord(
        uuid: uuid,
        name: json['name'] as String,
        nameChangedAt: msFromIso(json['name_changed_at']) ?? nowMs(),
        listTypeId: (json['list_type_id'] as num).toInt(),
      );

      if (local != null && !local.pending.has('name')) {
        local.name = json['name'] as String;
        local.nameChangedAt = msFromIso(json['name_changed_at']) ?? local.nameChangedAt;
      }
      if (json.containsKey('hidden_from') && !list.pending.has('hidden_from')) {
        list.hiddenFrom = (json['hidden_from'] as List).map((id) => (id as num).toInt()).toList();
      }

      _lists[uuid] = list;
      saveLists.add(list);
    }

    for (final json in (response['items'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uuid = json['uuid'] as String;
      final list = _lists[json['list_uuid'] as String];
      if (list == null) continue;

      if (json['deleted_at'] != null) {
        list.items.removeWhere((item) => item.uuid == uuid);
        removeItems.add(uuid);
        continue;
      }

      ItemRecord? item;
      for (final candidate in list.items) {
        if (candidate.uuid == uuid) item = candidate;
      }

      if (item == null) {
        item = ItemRecord(
          uuid: uuid,
          listUuid: list.uuid,
          name: json['name'] as String,
          nameChangedAt: msFromIso(json['name_changed_at']) ?? nowMs(),
          quantity: (json['quantity'] as num).toInt(),
          quantityChangedAt: msFromIso(json['quantity_changed_at']) ?? nowMs(),
          status: ItemStatus.fromCode(json['status'] as String?),
          statusChangedAt: msFromIso(json['status_changed_at']) ?? nowMs(),
        );
        list.items.add(item);
      } else {
        if (!item.pending.has('name')) {
          item.name = json['name'] as String;
          item.nameChangedAt = msFromIso(json['name_changed_at']) ?? item.nameChangedAt;
        }
        if (!item.pending.has('quantity')) {
          item.quantity = (json['quantity'] as num).toInt();
          item.quantityChangedAt = msFromIso(json['quantity_changed_at']) ?? item.quantityChangedAt;
        }
        if (!item.pending.has('status')) {
          item.status = ItemStatus.fromCode(json['status'] as String?);
          item.statusChangedAt = msFromIso(json['status_changed_at']) ?? item.statusChangedAt;
        }
      }

      saveItems.add(item);
    }

    // 3. A list that is not in the visible set is gone for this person (hidden, or permission withdrawn)
    final visible = (response['visible_list_uuids'] as List?)?.map((u) => u.toString()).toSet();
    if (visible != null) {
      for (final list in _lists.values.toList()) {
        if (!visible.contains(list.uuid) && !list.pending.isNew) {
          _lists.remove(list.uuid);
          removeLists.add(list.uuid);
        }
      }
    }

    saveLists.removeWhere((list) => removeLists.contains(list.uuid));
    saveItems.removeWhere((item) => removeItems.contains(item.uuid) || removeLists.contains(item.listUuid));

    await _db.apply(saveLists: saveLists, saveItems: saveItems, removeLists: removeLists, removeItems: removeItems);

    // 4. The cursor, and who I am and what I may do
    if (outcome.needsFullPull) {
      await _db.setMeta('since', null); // start over so the server's version of the refused things comes back
    } else if (response['server_time'] is String) {
      await _db.setMeta('since', response['server_time'] as String);
    }

    if (response['me'] is Map<String, dynamic>) {
      await _db.setMeta('me', jsonEncode(response['me']));
      _me = Me.fromJson(response['me'] as Map<String, dynamic>);
    }

    notifyListeners();
    return outcome;
  }

  /// Sign-out: nothing of this family stays on the phone.
  Future<void> wipe() async {
    _lists.clear();
    _me = null;
    await _db.wipe();
    notifyListeners();
  }
}
