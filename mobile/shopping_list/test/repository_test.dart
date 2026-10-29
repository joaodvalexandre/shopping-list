import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/core/time.dart';
import 'package:shopping_list/data/me.dart';
import 'package:shopping_list/data/models.dart';
import 'package:shopping_list/data/repository.dart';

import 'support/memory_store.dart';

Map<String, dynamic> meJson({
  Map<String, Map<String, bool>>? permissions,
  List<Map<String, dynamic>> members = const [],
  String role = 'member',
}) =>
    {
      'user': {'id': 3, 'name': 'Bia', 'email': 'bia@example.com', 'role': role, 'locale': 'pt', 'must_change_password': false},
      'family': {'id': 1, 'name': 'Silva'},
      'list_types': [
        {'id': 1, 'name': 'Groceries'},
        {'id': 2, 'name': 'Party'},
      ],
      'permissions': permissions ??
          {
            '1': {'can_view': true, 'can_add_items': true, 'can_edit_items': true, 'can_change_status': true, 'can_manage_lists': true},
            '2': {'can_view': false, 'can_add_items': false, 'can_edit_items': false, 'can_change_status': false, 'can_manage_lists': false},
          },
      'members': members,
    };

String iso(int ms) => isoFromMs(ms);

Map<String, dynamic> serverList(String uuid, String name, {int type = 1, String? deletedAt, List<int>? hiddenFrom}) => {
      'uuid': uuid,
      'name': name,
      'name_changed_at': iso(1000),
      'list_type_id': type,
      'updated_at': iso(1000),
      'deleted_at': deletedAt,
      'hidden_from': ?hiddenFrom,
    };

Map<String, dynamic> serverItem(String uuid, String listUuid, String name, {int quantity = 1, String status = 'to_buy'}) => {
      'uuid': uuid,
      'list_uuid': listUuid,
      'name': name,
      'name_changed_at': iso(1000),
      'quantity': quantity,
      'quantity_changed_at': iso(1000),
      'status': status,
      'status_changed_at': iso(1000),
      'updated_at': iso(1000),
      'deleted_at': null,
    };

Map<String, dynamic> response({
  List<Map<String, dynamic>> lists = const [],
  List<Map<String, dynamic>> items = const [],
  required List<String> visible,
  Map<String, dynamic> listResults = const {},
  Map<String, dynamic> itemResults = const {},
  String serverTime = '2026-10-28T21:00:00.000Z',
}) =>
    {
      'server_time': serverTime,
      'results': {'lists': listResults, 'items': itemResults},
      'lists': lists,
      'items': items,
      'visible_list_uuids': visible,
      'me': meJson(),
    };

void main() {
  late MemoryStore store;
  late Repository repo;

  setUp(() async {
    store = MemoryStore();
    repo = Repository(store);
    await repo.load();
  });

  group('editing offline', () {
    test('a new list and item are sent in full, and the list is not yet "known"', () {
      final list = repo.createList(name: ' Weekly shop ', listTypeId: 1, hiddenFrom: [7]);
      repo.addItem(list.uuid, name: 'Milk', quantity: 2);

      final push = repo.buildPush(null);
      final changes = push.payload['changes'] as Map<String, dynamic>;
      final sentList = (changes['lists'] as List).single as Map<String, dynamic>;
      final sentItem = (changes['items'] as List).single as Map<String, dynamic>;

      expect(sentList['uuid'], list.uuid);
      expect(sentList['name'], 'Weekly shop');
      expect(sentList['list_type_id'], 1);
      expect(sentList['hidden_from'], [7]);
      expect(sentItem['list_uuid'], list.uuid);
      expect(sentItem['name'], 'Milk');
      expect(sentItem['quantity'], 2);
      expect(sentItem['status'], 'to_buy');
      expect(push.payload['known_lists'], isEmpty);
      expect(push.payload.containsKey('since'), isFalse);
      expect(repo.pendingCount, 2);
    });

    test('an edit of one field sends only that field', () async {
      await repo.applyResponse(
        response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk', quantity: 1)], visible: ['l1']),
        {},
      );
      expect(repo.pendingCount, 0);

      repo.updateItem('l1', 'i1', name: 'Milk', quantity: 3);

      final push = repo.buildPush('2026-10-28T21:00:00.000Z');
      final sent = ((push.payload['changes'] as Map)['items'] as List).single as Map<String, dynamic>;

      expect(sent.keys.toSet(), {'uuid', 'list_uuid', 'quantity', 'quantity_changed_at'});
      expect(sent['quantity'], 3);
      expect(push.payload['since'], '2026-10-28T21:00:00.000Z');
      expect(push.payload['known_lists'], ['l1']);
    });

    test('changing the cart status touches only the status', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk')], visible: ['l1']), {});

      repo.setStatus('l1', 'i1', ItemStatus.inCart);

      final sent = ((repo.buildPush(null).payload['changes'] as Map)['items'] as List).single as Map<String, dynamic>;
      expect(sent['status'], 'in_cart');
      expect(sent.containsKey('name'), isFalse);
      expect(sent.containsKey('quantity'), isFalse);
    });

    test('finishing a list marks only what is in the cart', () async {
      await repo.applyResponse(
        response(
          lists: [serverList('l1', 'Shop')],
          items: [serverItem('a', 'l1', 'A', status: 'in_cart'), serverItem('b', 'l1', 'B'), serverItem('c', 'l1', 'C', status: 'in_cart')],
          visible: ['l1'],
        ),
        {},
      );

      repo.markPurchased('l1');

      final byName = {for (final item in repo.itemsOf('l1')) item.name: item.status};
      expect(byName, {'A': ItemStatus.purchased, 'B': ItemStatus.toBuy, 'C': ItemStatus.purchased});
    });

    test('deleting something never sent leaves no trace; deleting a synced one is sent as a deletion', () async {
      final local = repo.createList(name: 'Draft', listTypeId: 1);
      repo.deleteList(local.uuid);
      expect(repo.lists, isEmpty);
      expect(repo.buildPush(null).payload.containsKey('changes'), isFalse);

      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk')], visible: ['l1']), {});
      repo.deleteItem('l1', 'i1');

      expect(repo.itemsOf('l1'), isEmpty);
      final sent = ((repo.buildPush(null).payload['changes'] as Map)['items'] as List).single as Map<String, dynamic>;
      expect(sent['deleted_at'], isNotNull);
    });
  });

  group('merging the server\'s answer', () {
    test('what was applied is no longer pending, and the cursor is kept', () async {
      final list = repo.createList(name: 'Shop', listTypeId: 1);
      final push = repo.buildPush(null);

      final outcome = await repo.applyResponse(
        response(
          lists: [serverList(list.uuid, 'Shop')],
          visible: [list.uuid],
          listResults: {list.uuid: {'status': 'applied'}},
          serverTime: '2026-10-28T21:05:00.000Z',
        ),
        push.sent,
      );

      expect(outcome.rejections, isEmpty);
      expect(repo.pendingCount, 0);
      expect(await repo.since, '2026-10-28T21:05:00.000Z');
      expect(store.lists.keys, [list.uuid]);
    });

    test('a field edited meanwhile is not overwritten by the server, the others are', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk', quantity: 1)], visible: ['l1']), {});

      repo.updateItem('l1', 'i1', name: 'Oat milk', quantity: 1); // pending, not sent yet

      await repo.applyResponse(
        response(items: [serverItem('i1', 'l1', 'Milk', quantity: 5)], visible: ['l1']),
        {},
      );

      final item = repo.itemsOf('l1').single;
      expect(item.name, 'Oat milk'); // my pending change stays
      expect(item.quantity, 5); // the server's newer quantity arrives
    });

    test('an edit made while the request was in flight stays pending', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk')], visible: ['l1']), {});

      repo.updateItem('l1', 'i1', name: 'Milk', quantity: 2);
      final push = repo.buildPush(null);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      repo.updateItem('l1', 'i1', name: 'Milk', quantity: 4); // edited again before the answer

      await repo.applyResponse(
        response(visible: ['l1'], itemResults: {'i1': {'status': 'applied'}}),
        push.sent,
      );

      expect(repo.pendingCount, 1); // the second edit still has to go
      expect(repo.itemsOf('l1').single.quantity, 4);
    });

    test('a list that is no longer visible disappears, but one just created here does not', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Surprise'), serverList('l2', 'Shop')], visible: ['l1', 'l2']), {});
      final mine = repo.createList(name: 'New', listTypeId: 1);

      await repo.applyResponse(response(visible: ['l2']), {});

      expect(repo.lists.map((l) => l.name), unorderedEquals(['New', 'Shop']));
      expect(repo.list(mine.uuid), isNotNull);
      expect(store.lists.containsKey('l1'), isFalse);
    });

    test('tombstones remove lists and items', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk')], visible: ['l1']), {});

      await repo.applyResponse(
        response(
          lists: [serverList('l1', 'Shop')],
          items: [serverItem('i1', 'l1', 'Milk')..['deleted_at'] = iso(2000)],
          visible: ['l1'],
        ),
        {},
      );
      expect(repo.itemsOf('l1'), isEmpty);

      await repo.applyResponse(response(lists: [serverList('l1', 'Shop', deletedAt: iso(3000))], visible: []), {});
      expect(repo.lists, isEmpty);
      expect(store.items, isEmpty);
    });

    test('a deletion that was accepted is forgotten', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], visible: ['l1']), {});
      repo.deleteList('l1');
      final push = repo.buildPush(null);

      await repo.applyResponse(response(visible: [], listResults: {'l1': {'status': 'applied'}}), push.sent);

      expect(repo.pendingCount, 0);
      expect(store.lists, isEmpty);
    });

    test('the hidden-from list is filled in for those who manage the list, left alone otherwise', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Party', hiddenFrom: [5, 7])], visible: ['l1']), {});
      expect(repo.list('l1')!.hiddenFrom, [5, 7]);

      await repo.applyResponse(response(lists: [serverList('l1', 'Party')], visible: ['l1']), {});
      expect(repo.list('l1')!.hiddenFrom, [5, 7]); // not in the answer: unchanged
    });
  });

  group('what PHP does to empty things', () {
    test('an answer with no results (an empty JSON list, not a map) and no permissions is understood', () async {
      final answer = response(visible: []);
      answer['results'] = {'lists': [], 'items': []}; // PHP writes [] for an empty object
      (answer['me'] as Map<String, dynamic>)['permissions'] = [];

      final outcome = await repo.applyResponse(answer, {});

      expect(outcome.rejections, isEmpty);
      expect(repo.me!.manageableTypeIds, isEmpty);
      expect(repo.me!.canCreateLists, isFalse);
    });
  });

  group('what the server refuses', () {
    test('a new item that is refused is removed and reported, and the next sync starts over', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], visible: ['l1']), {});
      final item = repo.addItem('l1', name: 'Candy', quantity: 1);
      final push = repo.buildPush('2026-10-28T21:00:00.000Z');

      final outcome = await repo.applyResponse(
        response(visible: ['l1'], itemResults: {item.uuid: {'status': 'rejected', 'reason': 'forbidden'}}),
        push.sent,
      );

      expect(outcome.rejections.single.name, 'Candy');
      expect(outcome.rejections.single.reason, 'forbidden');
      expect(outcome.needsFullPull, isTrue);
      expect(repo.itemsOf('l1'), isEmpty);
      expect(await repo.since, isNull); // everything is fetched again
    });

    test('a refused edit is undone by what the server sends next', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk', status: 'to_buy')], visible: ['l1']), {});
      repo.setStatus('l1', 'i1', ItemStatus.inCart);
      final push = repo.buildPush(null);

      await repo.applyResponse(
        response(visible: ['l1'], itemResults: {'i1': {'status': 'rejected', 'reason': 'forbidden', 'fields': ['status']}}),
        push.sent,
      );
      expect(repo.pendingCount, 0);

      // the full pull that follows
      await repo.applyResponse(response(items: [serverItem('i1', 'l1', 'Milk', status: 'to_buy')], visible: ['l1']), {});
      expect(repo.itemsOf('l1').single.status, ItemStatus.toBuy);
    });

    test('a new list that is refused is removed with its items', () async {
      final list = repo.createList(name: 'Nope', listTypeId: 2);
      repo.addItem(list.uuid, name: 'x', quantity: 1);
      final push = repo.buildPush(null);

      final outcome = await repo.applyResponse(
        response(visible: [], listResults: {list.uuid: {'status': 'rejected', 'reason': 'forbidden'}}),
        push.sent,
      );

      expect(outcome.rejections.single.isList, isTrue);
      expect(repo.lists, isEmpty);
      expect(store.lists, isEmpty);
      expect(store.items, isEmpty);
    });

    test('something already deleted on the server is dropped quietly', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], items: [serverItem('i1', 'l1', 'Milk')], visible: ['l1']), {});
      repo.updateItem('l1', 'i1', name: 'Milk 2', quantity: 1);
      final push = repo.buildPush(null);

      final outcome = await repo.applyResponse(
        response(visible: ['l1'], itemResults: {'i1': {'status': 'ignored', 'reason': 'deleted'}}),
        push.sent,
      );

      expect(outcome.rejections, isEmpty);
      expect(repo.itemsOf('l1'), isEmpty);
    });
  });

  group('who I am', () {
    test('permissions come from the answer, and sign-out wipes everything', () async {
      await repo.applyResponse(response(lists: [serverList('l1', 'Shop')], visible: ['l1']), {});

      expect(repo.me!.can(1, Ability.manageLists), isTrue);
      expect(repo.me!.can(2, Ability.view), isFalse);
      expect(repo.me!.canCreateLists, isTrue);
      expect(repo.me!.manageableTypeIds, [1]);
      expect(jsonDecode(store.meta['me']!)['user']['name'], 'Bia');

      await repo.wipe();
      expect(repo.me, isNull);
      expect(repo.lists, isEmpty);
      expect(store.meta, isEmpty);
    });

    test('any ability implies viewing, but not the other abilities', () {
      final me = Me.fromJson(meJson(permissions: {
        '1': {'can_view': false, 'can_add_items': true, 'can_edit_items': false, 'can_change_status': false, 'can_manage_lists': false},
      }));

      expect(me.can(1, Ability.view), isTrue);
      expect(me.can(1, Ability.addItems), isTrue);
      expect(me.can(1, Ability.editItems), isFalse);
      expect(me.can(1, Ability.manageLists), isFalse);
      expect(me.can(9, Ability.view), isFalse); // a type I know nothing about
    });

    test('a list that survives a restart is read back from the store', () async {
      final list = repo.createList(name: 'Shop', listTypeId: 1);
      repo.addItem(list.uuid, name: 'Milk', quantity: 2);
      await Future<void>.delayed(Duration.zero);

      final again = Repository(store);
      await again.load();

      expect(again.lists.single.name, 'Shop');
      expect(again.itemsOf(list.uuid).single.quantity, 2);
      expect(again.pendingCount, 2); // still waiting for the server
    });
  });

  group('the state of a list', () {
    ShoppingListRecord listWith(List<ItemStatus> statuses) {
      final list = ShoppingListRecord(uuid: 'l', name: 'L', nameChangedAt: 0, listTypeId: 1);
      for (var i = 0; i < statuses.length; i++) {
        list.items.add(ItemRecord(
          uuid: 'i$i',
          listUuid: 'l',
          name: 'x',
          nameChangedAt: 0,
          quantity: 1,
          quantityChangedAt: 0,
          status: statuses[i],
          statusChangedAt: 0,
        ));
      }
      return list;
    }

    test('follows the same rules as the web app', () {
      expect(ListState.of(listWith([])), ListState.noItems);
      expect(ListState.of(listWith([ItemStatus.purchased, ItemStatus.purchased])), ListState.finished);
      expect(ListState.of(listWith([ItemStatus.inCart, ItemStatus.inCart])), ListState.allInCart);
      expect(ListState.of(listWith([ItemStatus.inCart, ItemStatus.toBuy])), ListState.shopping);
      expect(ListState.of(listWith([ItemStatus.toBuy, ItemStatus.toBuy])), ListState.pending);
      expect(ListState.of(listWith([ItemStatus.toBuy, ItemStatus.purchased])), ListState.mixed);
    });
  });
}
