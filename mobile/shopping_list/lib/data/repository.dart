import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/time.dart';
import 'local_db.dart';
import 'me.dart';
import 'models.dart';
import 'peer_info.dart';

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

  /// Lists and items deleted here (or by a phone nearby): when, and which list or type they
  /// were in. A phone nearby which still has one among its unsent changes cannot bring it
  /// back, and a phone which still has it is told it is gone, even if the server never knew.
  final Map<String, Map<String, dynamic>> _tombstones = {};
  static const _tombstoneMetaKey = 'peer_tombstones';
  static const _tombstoneKeepMs = 14 * 24 * 3600 * 1000;

  /// A local family has no server to settle a late phone: deletions are remembered much longer.
  static const _localTombstoneKeepMs = 90 * 24 * 3600 * 1000;

  /// Called after every local edit, so the app can sync soon.
  VoidCallback? onLocalChange;

  Me? get me => _me;

  /// A local family (no server, ever): its changes are never "waiting for the server", and what
  /// the phones of the family hold is compared and completed between them (see [buildLocalDigest]).
  bool _local = false;
  bool get isLocal => _local;

  /// The one list type of a local family, whose people may do everything in it.
  static const localTypeId = 1;

  /// Goes up with every change here, whoever made it (a local edit or what a phone nearby brought).
  /// It tells the phones of a local family that there is news.
  int _revision = 0;
  int get revision => _revision;

  Future<void> load() async {
    _lists
      ..clear()
      ..addEntries((await _db.loadAll()).map((list) => MapEntry(list.uuid, list)));

    final rawMe = await _db.getMeta('me');
    _me = rawMe == null ? null : Me.fromJson(jsonDecode(rawMe) as Map<String, dynamic>);
    _local = await _db.getMeta('local_family') != null;

    _tombstones
      ..clear()
      ..addAll(asMap(jsonDecode(await _db.getMeta(_tombstoneMetaKey) ?? '{}')).map((uuid, entry) => MapEntry(uuid, asMap(entry))));
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

    _remember(uuid, list: true, type: list.listTypeId);

    if (list.pending.isNew || _local) {
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

  /// Not while the item is in the cart: it is about to be bought, so it has to come out of the cart first.
  void deleteItem(String listUuid, String uuid) {
    final list = _lists[listUuid];
    final item = _item(listUuid, uuid);
    if (list == null || item == null || item.status == ItemStatus.inCart) return;

    _remember(uuid, list: false, listUuid: listUuid);

    if (item.pending.isNew || _local) {
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
    _revision++;

    if (_local) {
      // Nothing waits for a server here: the changes are simply the family's state
      for (final list in saveLists) {
        list.pending.fields.clear();
      }
      for (final item in saveItems) {
        item.pending.fields.clear();
      }
    }

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

  // ------------------------------------------------------------ nearby phones
  //
  // With no way to the server, two phones of the same family nearby swap what they have not
  // yet sent to it. What arrives is kept as this phone's own unsent change, so whichever phone
  // reaches the server first passes it on, and the server settles any clash field by field,
  // as it does for every sync.

  /// The lists this phone holds: told to a phone nearby, which may then pass on changes to a
  /// list whose "hidden from" only managers can see.
  List<String> get heldListUuids => [
        for (final list in _lists.values)
          if (!list.pending.isDeleted) list.uuid,
      ];

  /// What this phone has not yet sent to the server, for a phone nearby: only the lists that
  /// phone's person may see, and no more than is theirs to know.
  Map<String, dynamic> buildPeerOffer(PeerInfo peer, Set<String> peerHolds) {
    final lists = <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[];

    // Who a list is hidden from is only known to those who manage it; for any other
    // list the phone nearby must already hold it, which the server only allowed if it may.
    bool mayShow(ShoppingListRecord list) {
      if (!peer.can(list.listTypeId, Ability.view)) return false;
      return can(list, Ability.manageLists) ? !list.hiddenFrom.contains(peer.userId) : peerHolds.contains(list.uuid);
    }

    for (final list in _lists.values) {
      if (!mayShow(list)) continue;

      final pending = list.pending;

      if (pending.isDeleted) {
        lists.add({'uuid': list.uuid, 'kind': 'delete', 'at': pending.fields[Pending.deleted]});
        continue;
      }

      if (pending.isNew) {
        lists.add({
          'uuid': list.uuid,
          'kind': 'new',
          'name': list.name,
          'name_at': list.nameChangedAt,
          'type': list.listTypeId,
          'hidden_from': list.hiddenFrom,
        });
      } else if (pending.has('name')) {
        lists.add({'uuid': list.uuid, 'kind': 'update', 'name': list.name, 'name_at': list.nameChangedAt});
      }

      for (final item in list.items) {
        final itemPending = item.pending;
        if (itemPending.isEmpty) continue;

        if (itemPending.isDeleted) {
          items.add({'uuid': item.uuid, 'list': list.uuid, 'kind': 'delete', 'at': itemPending.fields[Pending.deleted]});
        } else if (itemPending.isNew) {
          items.add({
            'uuid': item.uuid,
            'list': list.uuid,
            'kind': 'new',
            'name': item.name,
            'name_at': item.nameChangedAt,
            'quantity': item.quantity,
            'quantity_at': item.quantityChangedAt,
            'status': item.status.code,
            'status_at': item.statusChangedAt,
          });
        } else {
          items.add({
            'uuid': item.uuid,
            'list': list.uuid,
            'kind': 'update',
            if (itemPending.has('name')) ...{'name': item.name, 'name_at': item.nameChangedAt},
            if (itemPending.has('quantity')) ...{'quantity': item.quantity, 'quantity_at': item.quantityChangedAt},
            if (itemPending.has('status')) ...{'status': item.status.code, 'status_at': item.statusChangedAt},
          });
        }
      }
    }

    // What was deleted here and the other phone may still have (including what never reached the server)
    _tombstones.forEach((uuid, entry) {
      final at = entry['at'];

      if (entry['kind'] == 'list') {
        final type = (entry['type'] as num?)?.toInt();
        if (_lists.containsKey(uuid) || type == null || !peer.can(type, Ability.view) || !peerHolds.contains(uuid)) return;
        lists.add({'uuid': uuid, 'kind': 'delete', 'at': at});
      } else {
        final list = _lists[entry['list']];
        if (list == null || !mayShow(list) || _item(list.uuid, uuid) != null) return;
        items.add({'uuid': uuid, 'list': list.uuid, 'kind': 'delete', 'at': at});
      }
    });

    return {'lists': lists, 'items': items};
  }

  /// Take in what a phone nearby offered. Each change is only accepted when **both** people
  /// may make it (the other phone's rights come from its signed credential), the list is one
  /// this phone holds, it is not hidden from this person, and nothing newer has happened to
  /// that field here. Accepted changes become this phone's unsent changes.
  Future<PeerApplied> applyPeerOffer(Map<String, dynamic> offer, PeerInfo peer) async {
    final applied = PeerApplied();
    final me = _me;
    if (me == null) return applied;

    bool both(int typeId, Ability ability) =>
        peer.can(typeId, Ability.view) && peer.can(typeId, ability) && me.can(typeId, ability);

    bool newer(Object? theirs, int mine) => theirs is num && theirs.toInt() > mine;

    final saveLists = <ShoppingListRecord>{};
    final saveItems = <ItemRecord>{};
    final removeLists = <String>{};
    final removeItems = <String>{};

    for (final raw in (offer['lists'] as List? ?? const [])) {
      final entry = asMap(raw);
      final uuid = entry['uuid'];
      if (uuid is! String) continue;

      final existing = _lists[uuid];

      switch (entry['kind']) {
        case 'new':
          final type = (entry['type'] as num?)?.toInt();
          final hidden = [for (final id in (entry['hidden_from'] as List? ?? const [])) (id as num).toInt()];
          final nameAt = (entry['name_at'] as num?)?.toInt() ?? nowMs();

          if (existing != null || _tombstones.containsKey(uuid) || type == null || entry['name'] is! String) continue;
          if (!me.listTypes.containsKey(type) || !both(type, Ability.manageLists) || hidden.contains(me.userId)) continue;

          final list = ShoppingListRecord(
            uuid: uuid,
            name: (entry['name'] as String).trim(),
            nameChangedAt: nameAt,
            listTypeId: type,
            hiddenFrom: hidden,
            pending: Pending({Pending.created: nameAt}),
          );
          _lists[uuid] = list;
          saveLists.add(list);
          applied.lists++;

        case 'update':
          if (existing == null || existing.pending.isDeleted || !both(existing.listTypeId, Ability.manageLists)) continue;

          if (entry['name'] is String && newer(entry['name_at'], existing.nameChangedAt)) {
            existing.name = (entry['name'] as String).trim();
            existing.nameChangedAt = (entry['name_at'] as num).toInt();
            existing.pending.mark('name', existing.nameChangedAt);
            saveLists.add(existing);
            applied.lists++;
          }

        case 'delete':
          if (existing == null || !both(existing.listTypeId, Ability.manageLists)) continue;

          _remember(uuid, list: true, type: existing.listTypeId, at: (entry['at'] as num?)?.toInt());
          if (existing.pending.isNew) {
            _lists.remove(uuid);
            removeLists.add(uuid);
          } else {
            existing.pending.mark(Pending.deleted, (entry['at'] as num?)?.toInt() ?? nowMs());
            saveLists.add(existing);
          }
          applied.lists++;
      }
    }

    for (final raw in (offer['items'] as List? ?? const [])) {
      final entry = asMap(raw);
      final uuid = entry['uuid'];
      final list = _lists[entry['list']];
      if (uuid is! String || list == null || list.pending.isDeleted) continue;

      final type = list.listTypeId;
      final item = _item(list.uuid, uuid);

      // "new" for an item this phone has is just its latest fields, like an update
      final action = (entry['kind'] == 'new' && item == null) ? 'create' : entry['kind'];

      switch (action) {
        case 'create':
          // A new item: unless it was deleted here, or they may not add items to this list
          if (_tombstones.containsKey(uuid) || !both(type, Ability.addItems)) continue;
          if (entry['name'] is! String || entry['quantity'] is! num) continue;

          final created = ItemRecord(
            uuid: uuid,
            listUuid: list.uuid,
            name: (entry['name'] as String).trim(),
            nameChangedAt: (entry['name_at'] as num?)?.toInt() ?? nowMs(),
            quantity: (entry['quantity'] as num).toInt().clamp(1, 9999),
            quantityChangedAt: (entry['quantity_at'] as num?)?.toInt() ?? nowMs(),
            status: ItemStatus.fromCode(entry['status'] as String?),
            statusChangedAt: (entry['status_at'] as num?)?.toInt() ?? nowMs(),
          );
          created.pending.mark(Pending.created, created.nameChangedAt);
          list.items.add(created);
          saveItems.add(created);
          applied.items++;

        case 'new' || 'update':
          if (item == null || item.pending.isDeleted) continue;

          var changed = false;
          if (entry['name'] is String && both(type, Ability.editItems) && newer(entry['name_at'], item.nameChangedAt)) {
            item.name = (entry['name'] as String).trim();
            item.nameChangedAt = (entry['name_at'] as num).toInt();
            item.pending.mark('name', item.nameChangedAt);
            changed = true;
          }
          if (entry['quantity'] is num && both(type, Ability.editItems) && newer(entry['quantity_at'], item.quantityChangedAt)) {
            item.quantity = (entry['quantity'] as num).toInt().clamp(1, 9999);
            item.quantityChangedAt = (entry['quantity_at'] as num).toInt();
            item.pending.mark('quantity', item.quantityChangedAt);
            changed = true;
          }
          if (entry['status'] is String && both(type, Ability.changeStatus) && newer(entry['status_at'], item.statusChangedAt)) {
            item.status = ItemStatus.fromCode(entry['status'] as String);
            item.statusChangedAt = (entry['status_at'] as num).toInt();
            item.pending.mark('status', item.statusChangedAt);
            changed = true;
          }

          if (changed) {
            saveItems.add(item);
            applied.items++;
          }

        case 'delete':
          if (item == null || !both(type, Ability.editItems) || item.status == ItemStatus.inCart) continue;

          _remember(uuid, list: false, listUuid: list.uuid, at: (entry['at'] as num?)?.toInt());
          if (item.pending.isNew) {
            list.items.remove(item);
            removeItems.add(uuid);
          } else {
            item.pending.mark(Pending.deleted, (entry['at'] as num?)?.toInt() ?? nowMs());
            saveItems.add(item);
          }
          applied.items++;
      }
    }

    if (applied.total > 0) {
      saveLists.removeWhere((list) => removeLists.contains(list.uuid));
      saveItems.removeWhere((item) => removeItems.contains(item.uuid) || removeLists.contains(item.listUuid));
      await _db.apply(saveLists: saveLists, saveItems: saveItems, removeLists: removeLists, removeItems: removeItems);

      notifyListeners();
      onLocalChange?.call();
    }

    return applied;
  }

  /// Note that something was deleted, so that a phone nearby cannot bring it back.
  void _remember(String uuid, {required bool list, int? type, String? listUuid, int? at}) {
    final now = nowMs();
    _tombstones[uuid] = {'at': at ?? now, 'kind': list ? 'list' : 'item', 'type': ?type, 'list': ?listUuid};
    final keep = _local ? _localTombstoneKeepMs : _tombstoneKeepMs;
    _tombstones.removeWhere((_, entry) => now - ((entry['at'] as num?)?.toInt() ?? 0) > keep);
    _db.setMeta(_tombstoneMetaKey, jsonEncode(_tombstones));
  }

  // -------------------------------------------------------------- local family
  //
  // A local family has no server. Its phones keep each other up to date by comparing what each
  // holds (a digest: one number or three per list and item) and sending only what the other lacks
  // or has older, field by field, the newest change of each field winning. Deletions are
  // remembered and passed on, and win over later edits. Whoever is in the family may do anything.

  /// Make this phone a member of a local family: the person, and the one list type it has.
  Future<void> startLocal({required String myName, required String familyName}) async {
    _lists.clear();
    _tombstones.clear();
    _local = true;
    _revision = 0;

    await _db.wipe();
    await _saveLocalMe(myName, familyName);
    notifyListeners();
  }

  /// The family's name, once a phone nearby has told it to a phone that joined by code.
  Future<void> setFamilyName(String familyName) async {
    final me = _me;
    if (!_local || me == null) return;

    await _saveLocalMe(me.name, familyName);
    notifyListeners();
  }

  Future<void> _saveLocalMe(String name, String familyName) async {
    final json = {
      'user': {'id': 1, 'name': name, 'email': '', 'role': 'member'},
      'family': {'name': familyName},
      'list_types': [
        {'id': localTypeId, 'name': ''},
      ],
      'permissions': {
        '$localTypeId': {for (final key in abilityKeys.values) key: true},
      },
      'members': const [],
    };

    await _db.setMeta('me', jsonEncode(json));
    _me = Me.fromJson(json);
  }

  /// What this phone holds, for the other phone to compare with its own: when each list's name
  /// and each item's fields were last changed, and what was deleted.
  Map<String, dynamic> buildLocalDigest() => {
        'lists': {for (final list in _lists.values) list.uuid: list.nameChangedAt},
        'items': {
          for (final list in _lists.values)
            for (final item in list.items) item.uuid: [item.nameChangedAt, item.quantityChangedAt, item.statusChangedAt],
        },
        'gone': {for (final entry in _tombstones.entries) entry.key: entry.value['at']},
      };

  /// What the phone that sent [digest] lacks or has older than this phone, and what this phone
  /// deleted that it still holds.
  Map<String, dynamic> buildLocalDelta(Map<String, dynamic> digest) {
    final theirLists = asMap(digest['lists']);
    final theirItems = asMap(digest['items']);
    final theirGone = asMap(digest['gone']);

    final lists = <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[];
    final gone = <Map<String, dynamic>>[];

    for (final list in _lists.values) {
      if (theirGone.containsKey(list.uuid)) continue; // deleted over there: they will say so

      final theirs = theirLists[list.uuid];
      if (theirs == null || (theirs as num).toInt() < list.nameChangedAt) {
        lists.add({'uuid': list.uuid, 'name': list.name, 'name_at': list.nameChangedAt});
      }

      for (final item in list.items) {
        if (theirGone.containsKey(item.uuid)) continue;

        final stamps = theirItems[item.uuid] as List?;
        final newer = stamps == null ||
            (stamps[0] as num).toInt() < item.nameChangedAt ||
            (stamps[1] as num).toInt() < item.quantityChangedAt ||
            (stamps[2] as num).toInt() < item.statusChangedAt;

        if (newer) {
          items.add({
            'uuid': item.uuid,
            'list': list.uuid,
            'name': item.name,
            'name_at': item.nameChangedAt,
            'quantity': item.quantity,
            'quantity_at': item.quantityChangedAt,
            'status': item.status.code,
            'status_at': item.statusChangedAt,
          });
        }
      }
    }

    _tombstones.forEach((uuid, entry) {
      final isList = entry['kind'] == 'list';
      if ((isList ? theirLists : theirItems).containsKey(uuid)) {
        gone.add({'uuid': uuid, 'kind': entry['kind'], 'at': entry['at'], 'list': entry['list']});
      }
    });

    return {'lists': lists, 'items': items, 'gone': gone};
  }

  /// Take in what another phone of the family sent: deletions first (they win), then lists and
  /// items, each field only when it is newer than what is held.
  Future<PeerApplied> applyLocalDelta(Map<String, dynamic> delta) async {
    final applied = PeerApplied();
    if (!_local || _me == null) return applied;

    final saveLists = <ShoppingListRecord>{};
    final saveItems = <ItemRecord>{};
    final removeLists = <String>{};
    final removeItems = <String>{};

    bool newer(Object? at, int held) => at is num && at.toInt() > held;

    for (final entry in (delta['gone'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uuid = entry['uuid'] as String?;
      if (uuid == null) continue;
      final at = (entry['at'] as num?)?.toInt();

      if (entry['kind'] == 'list') {
        final list = _lists[uuid];
        _remember(uuid, list: true, type: list?.listTypeId ?? localTypeId, at: at);
        if (list == null) continue;

        _lists.remove(uuid);
        removeLists.add(uuid);
        for (final item in list.items) {
          removeItems.add(item.uuid);
        }
        applied.lists++;
      } else {
        final listUuid = entry['list'] as String?;
        final item = listUuid == null ? null : _item(listUuid, uuid);

        // What is in the cart is about to be bought: it stays, here
        if (item != null && item.status == ItemStatus.inCart) continue;

        _remember(uuid, list: false, listUuid: listUuid, at: at);
        if (item == null) continue;

        _lists[listUuid]!.items.remove(item);
        removeItems.add(uuid);
        applied.items++;
      }
    }

    for (final entry in (delta['lists'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uuid = entry['uuid'] as String?;
      final name = (entry['name'] as String?)?.trim();
      if (uuid == null || name == null || name.isEmpty || _tombstones.containsKey(uuid)) continue;

      final existing = _lists[uuid];
      if (existing == null) {
        final created = ShoppingListRecord(
          uuid: uuid,
          name: name,
          nameChangedAt: (entry['name_at'] as num?)?.toInt() ?? nowMs(),
          listTypeId: localTypeId,
        );
        _lists[uuid] = created;
        saveLists.add(created);
        applied.lists++;
      } else if (newer(entry['name_at'], existing.nameChangedAt)) {
        existing.name = name;
        existing.nameChangedAt = (entry['name_at'] as num).toInt();
        saveLists.add(existing);
        applied.lists++;
      }
    }

    for (final entry in (delta['items'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uuid = entry['uuid'] as String?;
      final list = _lists[entry['list']];
      final name = (entry['name'] as String?)?.trim();
      if (uuid == null || list == null || name == null || name.isEmpty || _tombstones.containsKey(uuid)) continue;

      final existing = _item(list.uuid, uuid);
      if (existing == null) {
        final created = ItemRecord(
          uuid: uuid,
          listUuid: list.uuid,
          name: name,
          nameChangedAt: (entry['name_at'] as num?)?.toInt() ?? nowMs(),
          quantity: ((entry['quantity'] as num?)?.toInt() ?? 1).clamp(1, 9999),
          quantityChangedAt: (entry['quantity_at'] as num?)?.toInt() ?? nowMs(),
          status: ItemStatus.fromCode(entry['status'] as String? ?? 'to_buy'),
          statusChangedAt: (entry['status_at'] as num?)?.toInt() ?? nowMs(),
        );
        list.items.add(created);
        saveItems.add(created);
        applied.items++;
        continue;
      }

      var changed = false;
      if (newer(entry['name_at'], existing.nameChangedAt)) {
        existing.name = name;
        existing.nameChangedAt = (entry['name_at'] as num).toInt();
        changed = true;
      }
      if (entry['quantity'] is num && newer(entry['quantity_at'], existing.quantityChangedAt)) {
        existing.quantity = (entry['quantity'] as num).toInt().clamp(1, 9999);
        existing.quantityChangedAt = (entry['quantity_at'] as num).toInt();
        changed = true;
      }
      if (entry['status'] is String && newer(entry['status_at'], existing.statusChangedAt)) {
        existing.status = ItemStatus.fromCode(entry['status'] as String);
        existing.statusChangedAt = (entry['status_at'] as num).toInt();
        changed = true;
      }
      if (changed) {
        saveItems.add(existing);
        applied.items++;
      }
    }

    if (applied.total > 0 || removeLists.isNotEmpty || removeItems.isNotEmpty) {
      _changedByPeer(saveLists: saveLists, saveItems: saveItems, removeLists: removeLists, removeItems: removeItems);
    }
    return applied;
  }

  /// What a phone nearby brought is stored like a local edit, without telling the sync about it.
  void _changedByPeer({
    required Set<ShoppingListRecord> saveLists,
    required Set<ItemRecord> saveItems,
    required Set<String> removeLists,
    required Set<String> removeItems,
  }) {
    _revision++;
    _db.apply(saveLists: saveLists, saveItems: saveItems, removeLists: removeLists, removeItems: removeItems);
    notifyListeners();
  }

  /// Sign-out: nothing of this family stays on the phone.
  Future<void> wipe() async {
    _lists.clear();
    _tombstones.clear();
    _me = null;
    _local = false;
    _revision = 0;
    await _db.wipe();
    notifyListeners();
  }
}
