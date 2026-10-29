import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/time.dart';
import 'activity.dart';
import 'local_db.dart';
import 'me.dart';
import 'models.dart';
import '../peer/local_family.dart';
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

/// A list type of a local family.
class LocalType {
  LocalType(this.name, this.nameAt);

  String name;
  int nameAt;
}

/// A person of a local family, as this phone knows them.
class LocalMember {
  LocalMember({
    required this.id,
    required this.number,
    required this.name,
    required this.nameAt,
    required this.joinedAt,
    this.seenAt,
    this.key,
    this.founder = false,
    this.role = 'member',
    this.rights,
    this.permAt = 0,
    this.permSig,
    this.permBy,
  });

  final String id;

  /// A whole number of their own, which is what a list's "hidden from" holds (as on the server).
  final int number;
  String name;
  int nameAt;
  final int joinedAt;

  /// When this phone last talked to theirs (told to nobody: only this phone's own knowledge).
  int? seenAt;

  /// Their phone's public key (the first one seen for them is kept): what proves, when phones
  /// connect, that a phone is who it says.
  String? key;

  /// The person who started the family: always an admin, and one nobody else can change.
  bool founder;

  /// `admin` or `member`, as an admin set it (signed). Admins change what the others may do.
  String role;

  /// What the admin allowed them, per list type (ability names such as `can_view`), signed by the
  /// admin. Null when nothing was set: then they may do everything.
  Map<int, List<String>>? rights;
  int permAt;
  String? permSig;

  /// Which admin signed it.
  String? permBy;

  bool get isAdmin => founder || role == 'admin';
}

/// Signs for this phone (the key it proves itself with to the family's other phones).
class LocalSigner {
  LocalSigner({required this.publicKey, required this.sign});

  final Future<String> Function() publicKey;
  final Future<String> Function(String message) sign;
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

  /// This phone's person, for putting a name to what they change.
  String get _myName => _me?.name ?? '';

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

  /// Goes up only with what was done on this phone, not with what a phone nearby brought: it tells
  /// a connection that is open that this phone has news for the other one.
  int _editMark = 0;
  int get editMark => _editMark;

  Future<void> load() async {
    _lists
      ..clear()
      ..addEntries((await _db.loadAll()).map((list) => MapEntry(list.uuid, list)));

    final rawMe = await _db.getMeta('me');
    _me = rawMe == null ? null : Me.fromJson(jsonDecode(rawMe) as Map<String, dynamic>);
    _local = await _db.getMeta('local_family') != null;
    if (_local) {
      await _loadLocalState();
      await _saveLocalState(); // what an older version did not have (numbers, who started it) is kept from now on
    }

    _tombstones
      ..clear()
      ..addAll(asMap(jsonDecode(await _db.getMeta(_tombstoneMetaKey) ?? '{}')).map((uuid, entry) => MapEntry(uuid, asMap(entry))));
    notifyListeners();
  }

  // ---------------------------------------------------------------- reading

  /// Lists to show, by name. Lists deleted on this phone but not yet on the server are hidden.
  List<ShoppingListRecord> get lists {
    final visible = _lists.values.where((list) => !list.pending.isDeleted && _visibleToMe(list)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return visible;
  }

  ShoppingListRecord? list(String uuid) {
    final list = _lists[uuid];
    return (list == null || list.pending.isDeleted || !_visibleToMe(list)) ? null : list;
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
      author: _myName,
    );

    _lists[list.uuid] = list;
    _changed(saveLists: [list]);
    return list;
  }

  void updateList(String uuid, {required String name, List<int>? hiddenFrom}) {
    final list = _lists[uuid];
    if (list == null) return;

    final at = nowMs();
    list.author = _myName;
    if (name.trim() != list.name) {
      list.name = name.trim();
      list.nameChangedAt = at;
      list.pending.mark('name', at);
    }
    if (hiddenFrom != null && !_sameIds(hiddenFrom, list.hiddenFrom)) {
      list.hiddenFrom = List.of(hiddenFrom);
      list.pending.mark('hidden_from', at);
      if (_local) list.nameChangedAt = at; // the name and who it is hidden from travel under one stamp
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
      author: _myName,
    );

    list.items.add(item);
    _changed(saveItems: [item]);
    return item;
  }

  void updateItem(String listUuid, String uuid, {required String name, required int quantity}) {
    final item = _item(listUuid, uuid);
    if (item == null) return;

    final at = nowMs();
    item.author = _myName;
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
    item.author = _myName;
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
      item.author = _myName;
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
    _editMark++;

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
  void _remember(String uuid, {required bool list, int? type, String? listUuid, int? at, String? by}) {
    final now = nowMs();
    _tombstones[uuid] = {'at': at ?? now, 'kind': list ? 'list' : 'item', 'type': ?type, 'list': ?listUuid, 'by': ?(by ?? (_local ? _myName : null))};
    final keep = _local ? _localTombstoneKeepMs : _tombstoneKeepMs;
    _tombstones.removeWhere((_, entry) => now - ((entry['at'] as num?)?.toInt() ?? 0) > keep);
    _db.setMeta(_tombstoneMetaKey, jsonEncode(_tombstones));
  }

  // -------------------------------------------------------------- local family
  //
  // A local family has no server. Its phones keep each other up to date by comparing what each
  // holds (a digest: one number or three per list, item, list type and member) and sending only
  // what the other lacks or has older, field by field, the newest change of each field winning.
  // Deletions are remembered and passed on, and win over later edits. Whoever is in the family
  // may do anything: the connect code is what lets a phone in.

  /// The default list type's name, until someone renames it.
  static const defaultTypeName = 'Shopping';

  final Map<int, LocalType> _localTypes = {};
  final Map<String, LocalMember> _localMembers = {};
  String _localMyId = '';
  String _familyName = '';
  int _familyNameAt = 0;

  /// The last time the family was handed over (an admin leaving): to whom, when, and the old
  /// admin's signature that makes it believable. Nothing until it happens.
  String? _ownerTo;
  int _ownerAt = 0;
  String? _ownerSig;

  /// Who this phone is in the local family (an id of its own, told to the others).
  String get localMyId => _localMyId;

  /// The family's people as far as this phone knows, this phone's person first.
  List<LocalMember> get localMembers {
    final members = _localMembers.values.toList()
      ..sort((a, b) {
        if (a.id == _localMyId) return -1;
        if (b.id == _localMyId) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return members;
  }

  /// The family's list types, by name.
  List<MapEntry<int, String>> get localTypes =>
      _localTypes.entries.map((e) => MapEntry(e.key, e.value.name)).toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

  /// How many lists are of a type (a type in use cannot be deleted).
  int listsOfType(int typeId) => _lists.values.where((list) => list.listTypeId == typeId).length;

  /// Make this phone a member of a local family: the person, and the default list type.
  /// [creating] is the phone that starts the family; one that joins takes the family's name and
  /// list types from the phones it meets, whatever they say being newer than its own blanks.
  Future<void> startLocal({
    required String myName,
    required String familyName,
    required String memberId,
    String typeName = defaultTypeName,
    bool creating = true,
  }) async {
    _lists.clear();
    _tombstones.clear();
    _local = true;
    _revision = 0;
    await _db.wipe();

    final now = nowMs();
    _localMyId = memberId;
    _localTypes
      ..clear()
      ..[localTypeId] = LocalType(typeName, creating ? now : 0);
    _localMembers
      ..clear()
      ..[memberId] = LocalMember(
        id: memberId,
        number: _newMemberNumber(),
        name: myName.trim(),
        nameAt: now,
        joinedAt: now,
        key: await _signer?.publicKey(),
        founder: creating, // whoever starts the family is its admin
      );
    _familyName = familyName.trim();
    _familyNameAt = creating ? now : 0;
    _ownerTo = null;
    _ownerAt = 0;
    _ownerSig = null;

    await _saveLocalState();
    notifyListeners();
  }

  /// Read what was saved (or, for a family started before this existed, make it up from `me`).
  Future<void> _loadLocalState() async {
    final raw = await _db.getMeta('local_state');
    final identity = await _db.getMeta('local_family');
    final mine = identity == null ? <String, dynamic>{} : asMap(jsonDecode(identity));

    _localTypes.clear();
    _localMembers.clear();

    if (raw == null) {
      _localMyId = mine['member_id'] as String? ?? '';
      _familyName = _me?.familyName ?? mine['family_name'] as String? ?? '';
      _familyNameAt = 0;
      _localTypes[localTypeId] = LocalType(defaultTypeName, 0);
      if (_localMyId.isNotEmpty) {
        _localMembers[_localMyId] =
            LocalMember(id: _localMyId, number: _newMemberNumber(), name: _me?.name ?? mine['my_name'] as String? ?? '', nameAt: nowMs(), joinedAt: nowMs());
      }
      _adoptFounderRole(mine);
      return;
    }

    final state = asMap(jsonDecode(raw));
    _localMyId = state['my_id'] as String? ?? '';
    _familyName = asMap(state['family'])['name'] as String? ?? '';
    _familyNameAt = (asMap(state['family'])['at'] as num?)?.toInt() ?? 0;
    final owner = asMap(state['owner']);
    _ownerTo = owner['to'] as String?;
    _ownerAt = (owner['at'] as num?)?.toInt() ?? 0;
    _ownerSig = owner['sig'] as String?;
    asMap(state['types']).forEach((id, type) {
      final map = asMap(type);
      _localTypes[int.parse(id)] = LocalType(map['name'] as String? ?? '', (map['at'] as num?)?.toInt() ?? 0);
    });
    asMap(state['members']).forEach((id, member) {
      final map = asMap(member);
      _localMembers[id] = LocalMember(
        id: id,
        number: (map['number'] as num?)?.toInt() ?? _newMemberNumber(),
        name: map['name'] as String? ?? '',
        nameAt: (map['at'] as num?)?.toInt() ?? 0,
        joinedAt: (map['joined'] as num?)?.toInt() ?? 0,
        seenAt: (map['seen'] as num?)?.toInt(),
        key: map['key'] as String?,
        founder: map['founder'] == true,
        role: map['role'] as String? ?? 'member',
        rights: _rightsFromJson(map['rights']),
        permAt: (map['perm_at'] as num?)?.toInt() ?? 0,
        permSig: map['perm_sig'] as String?,
        permBy: map['perm_by'] as String?,
      );
    });
    _adoptFounderRole(mine);
  }

  /// A family made before there were admins: the phone that was given the family's name when it
  /// started it (a phone that joined had none) is the one that started it.
  void _adoptFounderRole(Map<String, dynamic> identity) {
    if (_localMembers.values.any((m) => m.founder)) return;

    final started = (identity['family_name'] as String? ?? '').isNotEmpty;
    final me = _localMembers[_localMyId];
    if (started && me != null) me.founder = true;
  }

  static Map<int, List<String>>? _rightsFromJson(Object? json) {
    if (json == null) return null;

    return {
      for (final entry in asMap(json).entries) int.parse(entry.key): [for (final code in (entry.value as List? ?? const [])) code.toString()],
    };
  }

  static Map<String, dynamic>? _rightsToJson(Map<int, List<String>>? rights) =>
      rights == null ? null : {for (final entry in rights.entries) '${entry.key}': entry.value};

  int _newMemberNumber() {
    final random = Random.secure();
    var number = 1 + random.nextInt(0x7fffffff - 1);
    while (_localMembers.values.any((m) => m.number == number)) {
      number = 1 + random.nextInt(0x7fffffff - 1);
    }
    return number;
  }

  Future<void> _saveLocalState() async {
    await _db.setMeta(
      'local_state',
      jsonEncode({
        'my_id': _localMyId,
        'family': {'name': _familyName, 'at': _familyNameAt},
        'owner': {'to': _ownerTo, 'at': _ownerAt, 'sig': _ownerSig},
        'types': {for (final e in _localTypes.entries) '${e.key}': {'name': e.value.name, 'at': e.value.nameAt}},
        'members': {
          for (final m in _localMembers.values)
            m.id: {
              'number': m.number,
              'name': m.name,
              'at': m.nameAt,
              'joined': m.joinedAt,
              'seen': m.seenAt,
              'key': m.key,
              'founder': m.founder,
              'role': m.role,
              'rights': _rightsToJson(m.rights),
              'perm_at': m.permAt,
              'perm_sig': m.permSig,
              'perm_by': m.permBy,
            },
        },
      }),
    );
    await _rebuildLocalMe();
  }

  /// `me` is what the rest of the app reads: this person, the family's name and its list types.
  Future<void> _rebuildLocalMe() async {
    final mine = _localMembers[_localMyId];
    final canManageSomething = _localTypes.keys.any((id) => _memberCan(_localMyId, id, Ability.manageLists));

    final json = {
      'user': {'id': mine?.number ?? 1, 'name': mine?.name ?? '', 'email': '', 'role': mine?.isAdmin == true ? 'admin' : 'member'},
      'family': {'name': _familyName},
      'list_types': [
        for (final e in _localTypes.entries) {'id': e.key, 'name': e.value.name},
      ],
      'permissions': {
        for (final id in _localTypes.keys) '$id': {for (final ability in Ability.values) abilityKeys[ability]!: _memberCan(_localMyId, id, ability)},
      },
      // those who manage lists may hide them from others (as on the server)
      'members': [
        if (canManageSomething)
          for (final m in _localMembers.values)
            if (m.id != _localMyId) {'id': m.number, 'name': m.name},
      ],
    };

    await _db.setMeta('me', jsonEncode(json));
    _me = Me.fromJson(json);
  }

  /// A change to the family itself (its people, types or name): saved, counted, and told to the phones nearby.
  void _familyChanged() {
    _revision++;
    _editMark++;
    _saveLocalState();
    notifyListeners();
    onLocalChange?.call();
  }

  void renameMe(String name) {
    final me = _localMembers[_localMyId];
    if (me == null || name.trim().isEmpty) return;

    me.name = name.trim();
    me.nameAt = nowMs();
    _familyChanged();
  }

  void renameFamily(String name) {
    if (name.trim().isEmpty) return;

    _familyName = name.trim();
    _familyNameAt = nowMs();
    _familyChanged();
  }

  /// A new list type, with an id of its own that no other phone will pick.
  int addLocalType(String name) {
    final random = Random.secure();
    var id = 1 + random.nextInt(0x7fffffff - 1);
    while (_localTypes.containsKey(id) || id == localTypeId) {
      id = 1 + random.nextInt(0x7fffffff - 1);
    }

    _localTypes[id] = LocalType(name.trim(), nowMs());
    _familyChanged();
    return id;
  }

  void renameLocalType(int id, String name) {
    final type = _localTypes[id];
    if (type == null || name.trim().isEmpty) return;

    type.name = name.trim();
    type.nameAt = nowMs();
    _familyChanged();
  }

  /// False when it cannot go: the default type stays, and a type with lists in it too.
  bool deleteLocalType(int id) {
    if (id == localTypeId || !_localTypes.containsKey(id) || listsOfType(id) > 0) return false;

    _localTypes.remove(id);
    _rememberKey('type:$id', 'type');
    _familyChanged();
    return true;
  }

  /// Take someone off the family's list (a phone that left, or a name that is no longer there).
  void removeLocalMember(String id) {
    if (id == _localMyId || !_localMembers.containsKey(id)) return;

    _localMembers.remove(id);
    _rememberKey('member:$id', 'member');
    _familyChanged();
  }

  /// The person who would take over the family if its admin left: the one who has been in it longest.
  LocalMember? get localHeir {
    final others = _localMembers.values.where((m) => m.id != _localMyId && m.key != null).toList()
      ..sort((a, b) {
        final byJoined = a.joinedAt.compareTo(b.joinedAt);
        return byJoined != 0 ? byJoined : a.id.compareTo(b.id);
      });
    return others.firstOrNull;
  }

  /// What leaving takes: this phone's person is struck off the others' list, and an admin hands the
  /// family to the oldest member (signed with the admin's key, so every phone believes it).
  /// The phone then has to tell another one, before it forgets the family. False when it cannot be done.
  Future<bool> prepareLeaving() async {
    final me = _localMembers[_localMyId];
    if (!_local || me == null) return false;

    if (me.founder && _localMembers.length > 1) {
      final heir = localHeir;
      final signer = _signer;
      if (heir == null || signer == null) return false;

      final at = nowMs() > _ownerAt ? nowMs() : _ownerAt + 1;
      _ownerTo = heir.id;
      _ownerAt = at;
      _ownerSig = await signer.sign(_ownerMessage(heir.id, at));
    }

    _rememberKey('member:${me.id}', 'member');
    _familyChanged();
    return true;
  }

  static String _ownerMessage(String toMemberId, int at) => 'owner|$toMemberId|$at';

  /// The family has a new admin: their own phone signs again what the old admin had signed (what each person may do),
  /// since it is the new admin's word that counts from now on.
  Future<void> _signRightsAgain() async {
    final signer = _signer;
    if (signer == null) return;

    for (final member in _localMembers.values) {
      if (member.permSig == null || member.founder) continue;

      member.permAt = nowMs() > member.permAt ? nowMs() : member.permAt + 1;
      member.permBy = _localMyId;
      member.permSig = await signer.sign(_permMessage(member.id, member.permAt, member.role, member.rights ?? const {}));
    }
  }

  /// This phone just talked to the phone of [memberId].
  void noteSeen(String memberId) {
    final member = _localMembers[memberId];
    if (member == null) return;

    member.seenAt = nowMs();
    _saveLocalState();
    notifyListeners();
  }

  void _rememberKey(String key, String kind, {int? at}) {
    _tombstones[key] = {'at': at ?? nowMs(), 'kind': kind};
    _db.setMeta(_tombstoneMetaKey, jsonEncode(_tombstones));
  }

  // ------------------------------------------------------ who may do what (local)
  //
  // The person who started the family is its admin. What each of the others may do (per list
  // type) is set by the admin and signed with the admin's key, so every phone can tell it is the
  // admin's word and nobody can give themselves more. When two phones meet each proves its
  // identity with its own key; the one receiving a change checks that the sender may make it, and a
  // list is never sent to someone it is hidden from or who may not see its type. (A phone that is
  // changed to ignore this cannot be stopped by the others; this is a family, not a bank.)

  LocalSigner? _signer;
  LocalSigner? get localSigner => _signer;

  /// Tell the family which key this phone proves itself with, and make sure it is on the list.
  Future<void> attachSigner(LocalSigner signer) async {
    _signer = signer;

    final me = _localMembers[_localMyId];
    if (!_local || me == null) return;

    final key = await signer.publicKey();
    if (me.key != key) {
      me.key = key;
      await _saveLocalState();
    }
  }

  bool get isLocalAdmin => _localMembers[_localMyId]?.isAdmin ?? false;

  /// The key a person of the family is known by (null: not seen yet).
  String? localMemberKey(String memberId) => _localMembers[memberId]?.key;

  /// What a person may do in a list type. The admin may do everything; so may anyone the admin
  /// has said nothing about, and anyone this phone does not know yet; a person the admin set
  /// rights for may do what was set. With no [memberId] there are no limits (tests, old paths).
  bool _memberCan(String? memberId, int typeId, Ability ability) {
    if (memberId == null) return true;

    final member = _localMembers[memberId];
    if (member == null || member.isAdmin || member.rights == null) return true;

    final granted = member.rights![typeId];
    if (granted == null) return false;
    return ability == Ability.view ? granted.isNotEmpty : granted.contains(abilityKeys[ability]);
  }

  /// What a person may do in each list type, for the screens.
  Map<int, Map<Ability, bool>> localRightsOf(String memberId) => {
        for (final typeId in _localTypes.keys) typeId: {for (final ability in Ability.values) ability: _memberCan(memberId, typeId, ability)},
      };

  bool _visibleToMe(ShoppingListRecord list) => !_local || _visibleTo(_localMyId, list);

  /// A list is for someone when they may see its type and it is not hidden from them.
  bool _visibleTo(String? memberId, ShoppingListRecord list) {
    if (memberId == null) return true;

    final member = _localMembers[memberId];
    return _memberCan(memberId, list.listTypeId, Ability.view) && (member == null || !list.hiddenFrom.contains(member.number));
  }

  /// An admin sets what a person is (admin or member) and what they may do, per list type.
  /// Returns false when it is not allowed: not an admin, or about the person who started the
  /// family, or about oneself.
  Future<bool> setLocalAccess(String memberId, {required bool admin, required Map<int, Map<Ability, bool>> rights}) async {
    final member = _localMembers[memberId];
    final signer = _signer;
    if (!isLocalAdmin || signer == null || member == null || member.founder || memberId == _localMyId) return false;

    final normal = <int, List<String>>{};
    rights.forEach((typeId, abilities) {
      final others = [for (final a in Ability.values) if (a != Ability.view && abilities[a] == true) abilityKeys[a]!];
      if (abilities[Ability.view] == true || others.isNotEmpty) normal[typeId] = [abilityKeys[Ability.view]!, ...others];
    });

    final now = nowMs();
    member.role = admin ? 'admin' : 'member';
    member.rights = normal;
    member.permAt = now > member.permAt ? now : member.permAt + 1;
    member.permBy = _localMyId;
    member.permSig = await signer.sign(_permMessage(member.id, member.permAt, member.role, normal));

    _familyChanged();
    return true;
  }

  /// What a person may do, with their role as it is.
  Future<bool> setLocalRights(String memberId, Map<int, Map<Ability, bool>> rights) =>
      setLocalAccess(memberId, admin: _localMembers[memberId]?.role == 'admin', rights: rights);

  /// What an admin signs: who, when, what they are and what they may do, in one fixed spelling.
  static String _permMessage(String memberId, int at, String role, Map<int, List<String>> rights) {
    final types = rights.keys.toList()..sort();
    return 'perm|$memberId|$at|$role|${types.map((t) => '$t:${([...rights[t]!]..sort()).join(',')}').join(';')}';
  }

  /// A record is believed when an admin (known to this phone as one) signed it, and not about themselves.
  Future<bool> _permIsFromAdmin(String memberId, int at, String role, Map<int, List<String>> rights, String? by, String signature) async {
    final signer = by == null ? null : _localMembers[by];
    if (signer == null || by == memberId || !signer.isAdmin || signer.key == null) return false;

    return LocalFamilyCrypto.verify(signer.key!, _permMessage(memberId, at, role, rights), signature);
  }

  // ------------------------------------------------------------ sync (local)

  /// What this phone holds, for the other phone to compare with its own: when each list's name
  /// and each item's fields were last changed, the family's types, people and name, and what was deleted.
  Map<String, dynamic> buildLocalDigest() => {
        'lists': {for (final list in _lists.values) list.uuid: list.nameChangedAt},
        'items': {
          for (final list in _lists.values)
            for (final item in list.items) item.uuid: [item.nameChangedAt, item.quantityChangedAt, item.statusChangedAt],
        },
        'types': {for (final e in _localTypes.entries) '${e.key}': e.value.nameAt},
        'members': {for (final m in _localMembers.values) m.id: [m.nameAt, m.permAt]},
        'family': _familyNameAt,
        'owner': _ownerAt,
        'gone': {for (final entry in _tombstones.entries) entry.key: entry.value['at']},
      };

  /// What the phone that sent [digest] lacks or has older than this phone, and what this phone
  /// deleted that it still holds. Only what [peerId] may see: lists hidden from them, or of a
  /// type they may not view, are not even mentioned.
  Map<String, dynamic> buildLocalDelta(Map<String, dynamic> digest, {String? peerId}) {
    final theirLists = asMap(digest['lists']);
    final theirItems = asMap(digest['items']);
    final theirTypes = asMap(digest['types']);
    final theirMembers = asMap(digest['members']);
    final theirGone = asMap(digest['gone']);

    final lists = <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[];
    final types = <Map<String, dynamic>>[];
    final members = <Map<String, dynamic>>[];
    final gone = <Map<String, dynamic>>[];

    bool older(Object? theirs, int mine) => theirs == null || (theirs as num).toInt() < mine;

    for (final e in _localTypes.entries) {
      if (theirGone.containsKey('type:${e.key}')) continue;
      if (older(theirTypes['${e.key}'], e.value.nameAt)) types.add({'id': e.key, 'name': e.value.name, 'at': e.value.nameAt});
    }

    for (final m in _localMembers.values) {
      if (theirGone.containsKey('member:${m.id}')) continue;

      final theirs = theirMembers[m.id] as List?;
      if (theirs == null || (theirs[0] as num).toInt() < m.nameAt || (theirs[1] as num).toInt() < m.permAt) {
        members.add({
          'id': m.id,
          'number': m.number,
          'name': m.name,
          'at': m.nameAt,
          'joined': m.joinedAt,
          'key': m.key,
          'founder': m.founder,
          if (m.permSig != null) 'perm': {'at': m.permAt, 'role': m.role, 'by': m.permBy, 'rights': _rightsToJson(m.rights), 'sig': m.permSig},
        });
      }
    }

    for (final list in _lists.values) {
      if (theirGone.containsKey(list.uuid)) continue; // deleted over there: they will say so

      if (!_visibleTo(peerId, list)) {
        // Not for them to know about. If they hold it and it has just been hidden from them, they
        // are told to let it go (with nothing of it: no name, no items).
        final theirs = theirLists[list.uuid];
        final theirNumber = peerId == null ? null : _localMembers[peerId]?.number;
        if (theirs != null && theirNumber != null && list.hiddenFrom.contains(theirNumber) && older(theirs, list.nameChangedAt)) {
          lists.add({'uuid': list.uuid, 'name': '-', 'name_at': list.nameChangedAt, 'type': list.listTypeId, 'hidden': list.hiddenFrom});
        }
        continue;
      }

      if (older(theirLists[list.uuid], list.nameChangedAt)) {
        lists.add({'uuid': list.uuid, 'name': list.name, 'name_at': list.nameChangedAt, 'type': list.listTypeId, 'hidden': list.hiddenFrom, 'by': list.author});
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
            'by': item.author,
          });
        }
      }
    }

    _tombstones.forEach((key, entry) {
      final kind = entry['kind'];

      if (kind == 'item') {
        final list = _lists[entry['list']];
        if (list != null && !_visibleTo(peerId, list)) return;
      } else if (kind == 'list') {
        final type = (entry['type'] as num?)?.toInt();
        if (type != null && !_memberCan(peerId, type, Ability.view)) return;
      }

      final held = switch (kind) {
        'list' => theirLists.containsKey(key),
        'type' => theirTypes.containsKey(key.substring('type:'.length)),
        'member' => theirMembers.containsKey(key.substring('member:'.length)),
        _ => theirItems.containsKey(key),
      };
      if (held) gone.add({'uuid': key, 'kind': kind, 'at': entry['at'], 'list': entry['list'], 'type': entry['type'], 'by': entry['by']});
    });

    return {
      'lists': lists,
      'items': items,
      'types': types,
      'members': members,
      'gone': gone,
      if (_familyNameAt > ((digest['family'] as num?)?.toInt() ?? 0)) 'family': {'name': _familyName, 'at': _familyNameAt},
      if (_ownerSig != null && _ownerAt > ((digest['owner'] as num?)?.toInt() ?? 0)) 'owner': {'to': _ownerTo, 'at': _ownerAt, 'sig': _ownerSig},
    };
  }

  /// Take in what another phone of the family sent: deletions first (they win), then the family
  /// itself, lists and items, each field only when it is newer than what is held, and only what
  /// [peerId] may do (a change they have no right to is left out, and never passed on).
  Future<PeerApplied> applyLocalDelta(Map<String, dynamic> delta, {String? peerId, String? peerName}) async {
    final applied = PeerApplied();
    if (!_local || _me == null) return applied;

    final saveLists = <ShoppingListRecord>{};
    final saveItems = <ItemRecord>{};
    final removeLists = <String>{};
    final removeItems = <String>{};
    var familyChanged = false;

    bool newer(Object? at, int held) => at is num && at.toInt() > held;
    bool can(int typeId, Ability ability) => _memberCan(peerId, typeId, ability);
    final myNumber = _localMembers[_localMyId]?.number;

    // Who did it: told with the change; failing that, the phone it came from
    String? who(Map<String, dynamic> entry) {
      final by = entry['by'];
      return by is String && by.trim().isNotEmpty ? by.trim() : peerName;
    }

    void happened(String kind, Map<String, dynamic> entry, String listUuid, String listName, {String? item, int? quantity}) {
      applied.events.add(ActivityEvent(id: 0, kind: kind, actor: who(entry), listUuid: listUuid, list: listName, item: item, quantity: quantity));
    }

    final records = <({LocalMember member, Map<String, dynamic> perm})>[];

    for (final entry in (delta['members'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final id = entry['id'] as String?;
      final name = (entry['name'] as String?)?.trim();
      if (id == null || name == null || name.isEmpty || _tombstones.containsKey('member:$id')) continue;

      var member = _localMembers[id];
      if (member == null) {
        member = _localMembers[id] = LocalMember(
          id: id,
          number: (entry['number'] as num?)?.toInt() ?? _newMemberNumber(),
          name: name,
          nameAt: (entry['at'] as num?)?.toInt() ?? nowMs(),
          joinedAt: (entry['joined'] as num?)?.toInt() ?? nowMs(),
        );
        familyChanged = true;
      } else if (newer(entry['at'], member.nameAt)) {
        member.name = name;
        member.nameAt = (entry['at'] as num).toInt();
        familyChanged = true;
      }

      // Their key: the first one seen is the one kept
      if (member.key == null && entry['key'] is String) {
        member.key = entry['key'] as String;
        familyChanged = true;
      }
      // Who started the family: learned once, from the first phone that says
      if (entry['founder'] == true && !member.founder && !_localMembers.values.any((m) => m.founder)) {
        member.founder = true;
        familyChanged = true;
      }

      // What an admin set for them: believed later, once it is known who is an admin
      final perm = asMap(entry['perm']);
      if (perm['sig'] is String) records.add((member: member, perm: perm));
    }

    // Only an admin's signed word counts. An admin made by an admin may vouch for the next, so go
    // round until nothing more can be believed.
    var believed = true;
    while (believed && records.isNotEmpty) {
      believed = false;

      for (final record in List.of(records)) {
        final member = record.member;
        final perm = record.perm;
        final at = (perm['at'] as num?)?.toInt() ?? 0;

        if (member.founder || at <= member.permAt) {
          records.remove(record);
          continue;
        }

        final role = perm['role'] == 'admin' ? 'admin' : 'member';
        final rights = _rightsFromJson(perm['rights']) ?? const <int, List<String>>{};

        if (await _permIsFromAdmin(member.id, at, role, rights, perm['by'] as String?, perm['sig'] as String)) {
          member.role = role;
          member.rights = rights;
          member.permAt = at;
          member.permBy = perm['by'] as String?;
          member.permSig = perm['sig'] as String;
          records.remove(record);
          familyChanged = true;
          believed = true;
        }
      }
    }

    // The family changing hands (its admin leaving): only the old admin's signature counts
    var becameAdmin = false;
    final handOver = asMap(delta['owner']);
    if (handOver['sig'] is String && handOver['to'] is String && newer(handOver['at'], _ownerAt)) {
      final oldAdmin = _localMembers.values.where((m) => m.founder).firstOrNull;
      final heir = _localMembers[handOver['to']];
      final at = (handOver['at'] as num).toInt();

      if (oldAdmin?.key != null && heir != null && await LocalFamilyCrypto.verify(oldAdmin!.key!, _ownerMessage(heir.id, at), handOver['sig'] as String)) {
        oldAdmin.founder = false;
        heir.founder = true;
        _ownerTo = heir.id;
        _ownerAt = at;
        _ownerSig = handOver['sig'] as String;
        familyChanged = true;
        becameAdmin = heir.id == _localMyId;
      }
    }

    for (final entry in (delta['gone'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uuid = entry['uuid'] as String?;
      if (uuid == null) continue;
      final at = (entry['at'] as num?)?.toInt();

      switch (entry['kind']) {
        case 'type':
          final id = int.tryParse(uuid.substring('type:'.length));
          // The default type stays, and so does one that has lists here
          if (id == null || id == localTypeId || listsOfType(id) > 0) continue;
          _rememberKey(uuid, 'type', at: at);
          familyChanged = _localTypes.remove(id) != null || familyChanged;
        case 'member':
          final id = uuid.substring('member:'.length);
          if (id == _localMyId) continue; // this phone is still here
          _rememberKey(uuid, 'member', at: at);
          familyChanged = _localMembers.remove(id) != null || familyChanged;
        case 'list':
          final list = _lists[uuid];
          final type = list?.listTypeId ?? (entry['type'] as num?)?.toInt() ?? localTypeId;
          if (!can(type, Ability.manageLists)) continue;

          _remember(uuid, list: true, type: type, at: at, by: entry['by'] as String?);
          if (list == null) continue;

          happened('list_removed', entry, uuid, list.name);
          _lists.remove(uuid);
          removeLists.add(uuid);
          for (final item in list.items) {
            removeItems.add(item.uuid);
          }
          applied.lists++;
        default:
          final listUuid = entry['list'] as String?;
          final item = listUuid == null ? null : _item(listUuid, uuid);
          final type = listUuid == null ? null : _lists[listUuid]?.listTypeId;
          if (type != null && !can(type, Ability.editItems)) continue;

          // What is in the cart is about to be bought: it stays, here
          if (item != null && item.status == ItemStatus.inCart) continue;

          _remember(uuid, list: false, listUuid: listUuid, at: at, by: entry['by'] as String?);
          if (item == null) continue;

          happened('item_removed', entry, listUuid!, _lists[listUuid]!.name, item: item.name, quantity: item.quantity);
          _lists[listUuid]!.items.remove(item);
          removeItems.add(uuid);
          applied.items++;
      }
    }

    // The family itself: its name, list types and people
    final family = asMap(delta['family']);
    if (family['name'] is String && newer(family['at'], _familyNameAt) && (family['name'] as String).trim().isNotEmpty) {
      _familyName = (family['name'] as String).trim();
      _familyNameAt = (family['at'] as num).toInt();
      familyChanged = true;
    }

    for (final entry in (delta['types'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final id = (entry['id'] as num?)?.toInt();
      final name = (entry['name'] as String?)?.trim();
      if (id == null || name == null || name.isEmpty || _tombstones.containsKey('type:$id')) continue;

      final existing = _localTypes[id];
      if (existing == null) {
        _localTypes[id] = LocalType(name, (entry['at'] as num?)?.toInt() ?? nowMs());
        familyChanged = true;
      } else if (newer(entry['at'], existing.nameAt)) {
        existing.name = name;
        existing.nameAt = (entry['at'] as num).toInt();
        familyChanged = true;
      }
    }

    for (final entry in (delta['lists'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final uuid = entry['uuid'] as String?;
      final name = (entry['name'] as String?)?.trim();
      if (uuid == null || name == null || name.isEmpty || _tombstones.containsKey(uuid)) continue;

      final hidden = [for (final n in (entry['hidden'] as List? ?? const [])) (n as num).toInt()];
      final existing = _lists[uuid];

      if (existing == null) {
        final type = (entry['type'] as num?)?.toInt();
        final typeId = type != null && _localTypes.containsKey(type) ? type : localTypeId;
        if (!can(typeId, Ability.manageLists)) continue;
        if (myNumber != null && hidden.contains(myNumber)) continue; // not for this phone's person

        final created = ShoppingListRecord(
          uuid: uuid,
          name: name,
          nameChangedAt: (entry['name_at'] as num?)?.toInt() ?? nowMs(),
          listTypeId: typeId,
          hiddenFrom: hidden,
        );
        created.author = who(entry);
        _lists[uuid] = created;
        saveLists.add(created);
        applied.lists++;
        applied.added.add(name);
        happened('list_created', entry, uuid, name);
      } else if (newer(entry['name_at'], existing.nameChangedAt) && can(existing.listTypeId, Ability.manageLists)) {
        if (myNumber != null && hidden.contains(myNumber)) {
          // it was hidden from this phone's person: it is not theirs to hold any more
          _lists.remove(uuid);
          removeLists.add(uuid);
          for (final item in existing.items) {
            removeItems.add(item.uuid);
          }
          continue;
        }

        existing.name = name;
        existing.hiddenFrom = hidden;
        existing.author = who(entry);
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

      final type = list.listTypeId;
      final existing = _item(list.uuid, uuid);

      if (existing == null) {
        if (!can(type, Ability.addItems)) continue;

        // Moving through the cart needs its own right: without it an item is simply added
        final status = can(type, Ability.changeStatus) ? ItemStatus.fromCode(entry['status'] as String? ?? 'to_buy') : ItemStatus.toBuy;

        final created = ItemRecord(
          uuid: uuid,
          listUuid: list.uuid,
          name: name,
          nameChangedAt: (entry['name_at'] as num?)?.toInt() ?? nowMs(),
          quantity: ((entry['quantity'] as num?)?.toInt() ?? 1).clamp(1, 9999),
          quantityChangedAt: (entry['quantity_at'] as num?)?.toInt() ?? nowMs(),
          status: status,
          statusChangedAt: (entry['status_at'] as num?)?.toInt() ?? nowMs(),
        );
        created.author = who(entry);
        list.items.add(created);
        saveItems.add(created);
        applied.items++;
        applied.added.add(name);
        happened('item_added', entry, list.uuid, list.name, item: name, quantity: created.quantity);
        continue;
      }

      var edited = false;
      ItemStatus? movedTo;
      if (can(type, Ability.editItems) && newer(entry['name_at'], existing.nameChangedAt)) {
        existing.name = name;
        existing.nameChangedAt = (entry['name_at'] as num).toInt();
        edited = true;
      }
      if (can(type, Ability.editItems) && entry['quantity'] is num && newer(entry['quantity_at'], existing.quantityChangedAt)) {
        existing.quantity = (entry['quantity'] as num).toInt().clamp(1, 9999);
        existing.quantityChangedAt = (entry['quantity_at'] as num).toInt();
        edited = true;
      }
      if (can(type, Ability.changeStatus) && entry['status'] is String && newer(entry['status_at'], existing.statusChangedAt)) {
        final status = ItemStatus.fromCode(entry['status'] as String);
        if (status != existing.status) movedTo = status;
        existing.status = status;
        existing.statusChangedAt = (entry['status_at'] as num).toInt();
        edited = true;
      }
      if (edited) {
        existing.author = who(entry);
        saveItems.add(existing);
        applied.items++;

        // What was done: moved through the cart, or renamed / changed in quantity
        if (movedTo != null) {
          final kind = switch (movedTo) {
            ItemStatus.inCart => 'item_in_cart',
            ItemStatus.purchased => 'item_purchased',
            ItemStatus.toBuy => 'item_returned',
          };
          happened(kind, entry, list.uuid, list.name, item: existing.name, quantity: existing.quantity);
        } else {
          happened('item_changed', entry, list.uuid, list.name, item: existing.name, quantity: existing.quantity);
        }
      }
    }

    if (becameAdmin) await _signRightsAgain();
    if (familyChanged) {
      applied.family = true;
      await _saveLocalState();
    }

    if (applied.total > 0 || familyChanged || removeLists.isNotEmpty || removeItems.isNotEmpty) {
      _revision++;
      _db.apply(saveLists: saveLists, saveItems: saveItems, removeLists: removeLists, removeItems: removeItems);
      notifyListeners();
    }
    return applied;
  }

  /// Sign-out: nothing of this family stays on the phone.
  Future<void> wipe() async {
    _lists.clear();
    _tombstones.clear();
    _me = null;
    _local = false;
    _revision = 0;
    _localTypes.clear();
    _localMembers.clear();
    _localMyId = '';
    _familyName = '';
    _ownerTo = null;
    _ownerAt = 0;
    _ownerSig = null;
    await _db.wipe();
    notifyListeners();
  }
}
