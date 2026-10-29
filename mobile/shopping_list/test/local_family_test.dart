import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/me.dart';
import 'package:shopping_list/peer/identity.dart';
import 'package:shopping_list/data/models.dart';
import 'package:shopping_list/data/repository.dart';
import 'package:shopping_list/peer/local_family.dart';
import 'package:shopping_list/peer/session.dart';

import 'support/fakes.dart';
import 'support/memory_store.dart';
import 'support/peer_support.dart';

/// A phone of a local family: its own database, the family's code, and a name.
class LocalPhone {
  LocalPhone(this.name, this.store, this.repo, this.family, this.key, this.keyStore);

  final String name;
  final MemoryStore store;
  final Repository repo;
  final LocalFamilyStore keyStore;
  final LocalFamily family;
  final LocalFamilyKey key;

  static Future<LocalPhone> start(String name, {String? code, String familyName = '', String? memberId}) async {
    final store = MemoryStore();
    final repo = Repository(store);
    final keyStore = LocalFamilyStore(store);

    await repo.attachSigner(localSignerFor(PeerIdentity(secrets: MemorySecrets(), store: store)));
    memberId ??= LocalFamilyStore.newMemberId();
    await repo.startLocal(myName: name, familyName: familyName, memberId: memberId, creating: code == null);
    final family = code == null
        ? await keyStore.create(myName: name, familyName: familyName, memberId: memberId)
        : await keyStore.join(myName: name, code: code, memberId: memberId);

    return LocalPhone(name, store, repo, family, await LocalFamilyKey.derive(family.code), keyStore);
  }

  LocalPeerSession session(PeerChannel channel, {String version = '1.1.0+7'}) => LocalPeerSession(
        key: key,
        repository: repo,
        appVersion: version,
        channel: channel,
        displayName: name,
        timeout: const Duration(seconds: 3),
      );

  List<String> items(String listName) => repo.itemsOf(repo.lists.firstWhere((l) => l.name == listName).uuid).map((i) => i.name).toList();
}

Future<(PeerResult, PeerResult)> meetLocal(LocalPhone a, LocalPhone b, {String? versionB}) async {
  final (lineA, lineB) = MemoryChannel.pair();
  final results = await Future.wait([a.session(lineA).run(), b.session(lineB, version: versionB ?? '1.1.0+7').run()]);
  return (results[0], results[1]);
}

void main() {
  group('connect codes', () {
    test('are twelve letters and digits that cannot be mistaken for each other', () {
      for (var i = 0; i < 50; i++) {
        final code = LocalFamilyCodes.generate();
        expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{12}$')));
        expect(LocalFamilyCodes.normalise(code), code);
      }
    });

    test('are read the way people type them', () {
      expect(LocalFamilyCodes.normalise('abcd-efgh-jklm'), 'ABCDEFGHJKLM');
      expect(LocalFamilyCodes.normalise(' ABCD EFGH JKLM '), 'ABCDEFGHJKLM');
      expect(LocalFamilyCodes.format('ABCDEFGHJKLM'), 'ABCD-EFGH-JKLM');
    });

    test('that cannot be one are refused', () {
      expect(LocalFamilyCodes.normalise('ABCD'), isNull);
      expect(LocalFamilyCodes.normalise('ABCD-EFGH-JKL0'), isNull);   // 0 is not in the alphabet
      expect(LocalFamilyCodes.normalise('ABCD-EFGH-JKLMN'), isNull);
    });

    test('give the same key to whoever knows them, and another one to another code', () async {
      final a = await LocalFamilyKey.derive('ABCDEFGHJKLM');
      final b = await LocalFamilyKey.derive('ABCDEFGHJKLM');
      final other = await LocalFamilyKey.derive('ABCDEFGHJKLN');

      expect(await a.tag(), await b.tag());
      expect(await a.tag(), isNot(await other.tag()));
      expect(await a.prove('x'), await b.prove('x'));
      expect(await a.prove('x'), isNot(await other.prove('x')));
    });
  });

  group('a local family on a phone', () {
    test('starts with the person and one list type they can do everything in, and no server', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');

      expect(ana.repo.isLocal, isTrue);
      expect(ana.repo.me!.name, 'Ana');
      expect(ana.repo.me!.familyName, 'Silva');
      expect(ana.repo.me!.canCreateLists, isTrue);
      expect(ana.family.code, hasLength(12));
    });

    test('keeps nothing waiting for a server, and still counts every change', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final before = ana.repo.revision;

      final list = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      ana.repo.addItem(list.uuid, name: 'Milk', quantity: 2);

      expect(ana.repo.pendingCount, 0);
      expect(ana.repo.revision, before + 2);
      expect(ana.items('Shop'), ['Milk']);
    });

    test('is found again after the app restarts', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);

      final again = Repository(ana.store);
      await again.load();

      expect(again.isLocal, isTrue);
      expect(again.lists.map((l) => l.name), ['Shop']);
      expect((await LocalFamilyStore(ana.store).current())!.code, ana.family.code);
    });
  });

  group('two phones of a local family', () {
    test('swap what each has, the other way round too, and the joining phone learns the family name', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      expect(bia.repo.me!.familyName, isEmpty);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 2);
      ana.repo.addItem(shop.uuid, name: 'Bread', quantity: 1);

      final (forAna, forBia) = await meetLocal(ana, bia);

      expect(forAna.ok, isTrue);
      expect(forBia.ok, isTrue);
      expect(bia.items('Shop'), ['Bread', 'Milk']);
      expect(bia.repo.me!.familyName, 'Silva');
      expect(forBia.peerName, 'Ana');

      // and from Bia back to Ana
      bia.repo.addItem(bia.repo.lists.single.uuid, name: 'Eggs', quantity: 12);
      await meetLocal(ana, bia);
      expect(ana.items('Shop'), ['Bread', 'Eggs', 'Milk']);
    });

    test('settle clashes field by field, the newest change of each field winning', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      final milk = ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 2);
      await meetLocal(ana, bia);

      ana.repo.updateItem(shop.uuid, milk.uuid, name: 'Milk', quantity: 5);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bia.repo.setStatus(shop.uuid, milk.uuid, ItemStatus.inCart);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      ana.repo.updateItem(shop.uuid, milk.uuid, name: 'Oat milk', quantity: 5);

      await meetLocal(ana, bia);

      for (final phone in [ana, bia]) {
        final item = phone.repo.itemsOf(shop.uuid).single;
        expect(item.name, 'Oat milk');
        expect(item.quantity, 5);
        expect(item.status, ItemStatus.inCart);
      }
    });

    test('pass deletions on, and a deleted item is not brought back by a phone that still has it', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final cai = await LocalPhone.start('Cai', code: ana.family.code);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      final milk = ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 1);
      ana.repo.addItem(shop.uuid, name: 'Bread', quantity: 1);
      await meetLocal(ana, bia);
      await meetLocal(ana, cai);

      ana.repo.deleteItem(shop.uuid, milk.uuid);
      await meetLocal(ana, bia);
      expect(bia.items('Shop'), ['Bread']);

      // Cai, who still has the milk, meets Bia and then Ana: it is gone everywhere, and stays gone
      await meetLocal(bia, cai);
      await meetLocal(cai, ana);
      for (final phone in [ana, bia, cai]) {
        expect(phone.items('Shop'), ['Bread'], reason: phone.name);
      }
    });

    test('pass a deleted list on, with its items', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 1);
      await meetLocal(ana, bia);

      bia.repo.deleteList(shop.uuid);
      await meetLocal(ana, bia);

      expect(ana.repo.lists, isEmpty);
      expect(bia.repo.lists, isEmpty);
    });

    test('keep an item that is in the cart, even when another phone deleted it', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      final milk = ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 1);
      await meetLocal(ana, bia);

      bia.repo.deleteItem(shop.uuid, milk.uuid);
      ana.repo.setStatus(shop.uuid, milk.uuid, ItemStatus.inCart);
      await meetLocal(ana, bia);

      expect(ana.items('Shop'), ['Milk']);
    });

    test('do not send what the other already has', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      for (var i = 0; i < 40; i++) {
        ana.repo.addItem(shop.uuid, name: 'Item $i', quantity: 1);
      }
      await meetLocal(ana, bia);

      final (again, _) = await meetLocal(ana, bia);
      expect(again.sent, 0);
      expect(again.applied.total, 0);
    });
  });

  group('the family itself', () {
    test('everyone ends up knowing everyone, and who they are', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final cai = await LocalPhone.start('Cai', code: ana.family.code);

      await meetLocal(ana, bia);
      await meetLocal(bia, cai); // Ana and Cai never meet: Bia tells each about the other
      await meetLocal(ana, bia);

      expect(ana.repo.localMembers.map((m) => m.name), ['Ana', 'Bia', 'Cai']);
      expect(cai.repo.localMembers.map((m) => m.name), ['Cai', 'Ana', 'Bia']); // this phone's person first

      expect(ana.repo.localMembers.firstWhere((m) => m.name == 'Bia').seenAt, isNotNull); // met her
      expect(ana.repo.localMembers.firstWhere((m) => m.name == 'Cai').seenAt, isNull); // heard of him
    });

    test('share the family name, its list types and a person changing their name', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      await meetLocal(ana, bia);

      ana.repo.renameFamily('Os Silva');
      final party = ana.repo.addLocalType('Party');
      ana.repo.renameLocalType(Repository.localTypeId, 'Groceries');
      bia.repo.renameMe('Beatriz');
      await meetLocal(ana, bia);

      for (final phone in [ana, bia]) {
        expect(phone.repo.me!.familyName, 'Os Silva', reason: phone.name);
        expect(phone.repo.localTypes.map((t) => t.value), ['Groceries', 'Party'], reason: phone.name);
        expect(phone.repo.localMembers.map((m) => m.name).toSet(), {'Ana', 'Beatriz'}, reason: phone.name);
      }

      // a list of the new type made on one phone is of that type on the other
      final shop = bia.repo.createList(name: 'Birthday', listTypeId: party);
      await meetLocal(ana, bia);
      expect(ana.repo.list(shop.uuid)!.listTypeId, party);
    });

    test('keep a list type that has lists, and pass on the deletion of one that has none', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final party = ana.repo.addLocalType('Party');
      final spare = ana.repo.addLocalType('Spare');
      ana.repo.createList(name: 'Birthday', listTypeId: party);
      await meetLocal(ana, bia);

      expect(ana.repo.deleteLocalType(party), isFalse); // in use
      expect(ana.repo.deleteLocalType(Repository.localTypeId), isFalse); // the default one stays
      expect(ana.repo.deleteLocalType(spare), isTrue);

      await meetLocal(ana, bia);
      expect(bia.repo.localTypes.map((t) => t.key), isNot(contains(spare)));
      expect(bia.repo.localTypes.map((t) => t.key), contains(party));
    });

    test('take someone off the list, but never the phone\'s own person', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      await meetLocal(ana, bia);

      final biaId = ana.repo.localMembers.firstWhere((m) => m.name == 'Bia').id;
      ana.repo.removeLocalMember(ana.repo.localMyId); // not allowed
      ana.repo.removeLocalMember(biaId);
      expect(ana.repo.localMembers.map((m) => m.name), ['Ana']);

      await meetLocal(ana, bia);

      // Bia is still Bia on her own phone, but is not brought back on Ana's
      expect(bia.repo.localMembers.map((m) => m.name), contains('Bia'));
      expect(ana.repo.localMembers.map((m) => m.name), ['Ana']);
    });

    test('a connection that is already trusted starts at "ready", with no hello or proof', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      await meetLocal(ana, bia);

      ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 1);

      final (lineA, lineB) = MemoryChannel.pair();
      final results = await Future.wait([
        LocalPeerSession(key: ana.key, repository: ana.repo, appVersion: '1.1.0+7', channel: lineA, displayName: 'Ana', knownPeer: (name: 'Bia', id: null)).run(),
        LocalPeerSession(key: bia.key, repository: bia.repo, appVersion: '1.1.0+7', channel: lineB, displayName: 'Bia', knownPeer: (name: 'Ana', id: null)).run(),
      ]);

      expect(results.every((r) => r.ok), isTrue);
      expect(bia.items('Shop'), ['Milk']);
      expect(results[1].applied.added, ['Milk']);
    });
  });

  group('who may do what', () {
    Map<int, Map<Ability, bool>> only(Set<Ability> abilities) => {
          Repository.localTypeId: {for (final a in Ability.values) a: a == Ability.view ? abilities.isNotEmpty : abilities.contains(a)},
        };

    Future<(LocalPhone, LocalPhone, String)> twoPhonesWithAList() async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 2);
      await meetLocal(ana, bia);
      return (ana, bia, shop.uuid);
    }

    test('the person who started the family is its admin, and the others learn it', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);

      expect(ana.repo.isLocalAdmin, isTrue);
      expect(bia.repo.isLocalAdmin, isFalse);
      expect(ana.repo.me!.isAdmin, isTrue);

      await meetLocal(ana, bia);

      expect(bia.repo.localMembers.firstWhere((m) => m.name == 'Ana').founder, isTrue);
      expect(bia.repo.localMembers.firstWhere((m) => m.name == 'Bia').founder, isFalse);
    });

    test('everyone may do everything until the admin says otherwise', () async {
      final (ana, bia, _) = await twoPhonesWithAList();
      final typeId = Repository.localTypeId;

      for (final ability in Ability.values) {
        expect(bia.repo.me!.can(typeId, ability), isTrue, reason: ability.name);
      }
      expect(ana.repo.me!.canCreateLists, isTrue);
    });

    test('the admin sets what a person may do, and that person\'s phone learns it', () async {
      final (ana, bia, _) = await twoPhonesWithAList();
      final biaId = bia.repo.localMyId;

      expect(await ana.repo.setLocalRights(biaId, only({Ability.view, Ability.addItems})), isTrue);
      await meetLocal(ana, bia);

      final me = bia.repo.me!;
      expect(me.can(Repository.localTypeId, Ability.view), isTrue);
      expect(me.can(Repository.localTypeId, Ability.addItems), isTrue);
      expect(me.can(Repository.localTypeId, Ability.editItems), isFalse);
      expect(me.can(Repository.localTypeId, Ability.manageLists), isFalse);
      expect(bia.repo.localRightsOf(biaId)[Repository.localTypeId]![Ability.changeStatus], isFalse);
    });

    test('only the admin can set rights', () async {
      final (ana, bia, _) = await twoPhonesWithAList();

      expect(await bia.repo.setLocalRights(ana.repo.localMyId, only({})), isFalse);
      expect(await bia.repo.setLocalRights(bia.repo.localMyId, only(Ability.values.toSet())), isFalse);
      expect(await ana.repo.setLocalRights(ana.repo.localMyId, only({})), isFalse); // nor the admin's own
    });

    test('a change by someone without the right is not taken in, and the right ones are', () async {
      final (ana, bia, listUuid) = await twoPhonesWithAList();
      await ana.repo.setLocalRights(bia.repo.localMyId, only({Ability.view, Ability.addItems})); // may add, not edit
      await meetLocal(ana, bia);

      final milk = bia.repo.itemsOf(listUuid).single;
      bia.repo.addItem(listUuid, name: 'Bread', quantity: 1); // allowed
      bia.repo.updateItem(listUuid, milk.uuid, name: 'Milk', quantity: 50); // not allowed
      bia.repo.setStatus(listUuid, milk.uuid, ItemStatus.inCart); // not allowed
      bia.repo.createList(name: 'Sneaky', listTypeId: Repository.localTypeId); // not allowed

      await meetLocal(ana, bia);

      expect(ana.items('Shop'), ['Bread', 'Milk']);
      final theirMilk = ana.repo.itemsOf(listUuid).firstWhere((i) => i.name == 'Milk');
      expect(theirMilk.quantity, 2);
      expect(theirMilk.status, ItemStatus.toBuy);
      expect(ana.repo.lists.map((l) => l.name), ['Shop']);
    });

    test('an item added by someone who may not use the cart arrives as to buy', () async {
      final (ana, bia, listUuid) = await twoPhonesWithAList();
      await ana.repo.setLocalRights(bia.repo.localMyId, only({Ability.view, Ability.addItems}));
      await meetLocal(ana, bia);

      final item = bia.repo.addItem(listUuid, name: 'Cheat', quantity: 1);
      bia.repo.setStatus(listUuid, item.uuid, ItemStatus.purchased);
      await meetLocal(ana, bia);

      expect(ana.repo.itemsOf(listUuid).firstWhere((i) => i.name == 'Cheat').status, ItemStatus.toBuy);
    });

    test('someone who may only look can still receive everything', () async {
      final (ana, bia, listUuid) = await twoPhonesWithAList();
      await ana.repo.setLocalRights(bia.repo.localMyId, only({Ability.view}));
      await meetLocal(ana, bia);

      ana.repo.addItem(listUuid, name: 'Eggs', quantity: 6);
      await meetLocal(ana, bia);

      expect(bia.items('Shop'), ['Eggs', 'Milk']);
    });

    test('someone may not give themselves more rights: only the admin\'s signature counts', () async {
      final (ana, bia, _) = await twoPhonesWithAList();
      final biaId = bia.repo.localMyId;
      await ana.repo.setLocalRights(biaId, only({Ability.view}));
      await meetLocal(ana, bia);

      // Bia writes herself a record with all the rights, signed with her own key
      const at = 9999999999999;
      final message = 'perm|$biaId|$at|${Repository.localTypeId}:can_add_items,can_change_status,can_edit_items,can_manage_lists,can_view';
      final forged = {
        'lists': const [],
        'items': const [],
        'types': const [],
        'gone': const [],
        'members': [
          {
            'id': biaId,
            'number': 1,
            'name': 'Bia',
            'at': 1,
            'joined': 1,
            'perm': {
              'at': at,
              'rights': {'${Repository.localTypeId}': ['can_view', 'can_add_items', 'can_edit_items', 'can_change_status', 'can_manage_lists']},
              'sig': await bia.repo.localSigner!.sign(message),
            },
          },
        ],
      };

      await ana.repo.applyLocalDelta(forged);
      expect(ana.repo.localRightsOf(biaId)[Repository.localTypeId]![Ability.editItems], isFalse);
    });

    test('a list hidden from someone is never sent to them, and goes from them when hidden later', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      await meetLocal(ana, bia);
      final biaNumber = ana.repo.localMembers.firstWhere((m) => m.name == 'Bia').number;

      ana.repo.createList(name: 'Birthday', listTypeId: Repository.localTypeId, hiddenFrom: [biaNumber]);
      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 1);
      await meetLocal(ana, bia);

      expect(bia.repo.lists.map((l) => l.name), ['Shop']);

      // hidden afterwards: the phone drops it
      ana.repo.updateList(shop.uuid, name: 'Shop', hiddenFrom: [biaNumber]);
      await meetLocal(ana, bia);

      expect(bia.repo.lists, isEmpty);
      expect(ana.repo.lists.map((l) => l.name), ['Birthday', 'Shop']);
    });

    test('lists of a type someone may not see are not sent to them', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final party = ana.repo.addLocalType('Party');
      await meetLocal(ana, bia);

      await ana.repo.setLocalRights(bia.repo.localMyId, {
        Repository.localTypeId: {for (final a in Ability.values) a: a == Ability.view},
        party: {for (final a in Ability.values) a: false},
      });
      ana.repo.createList(name: 'Birthday', listTypeId: party);
      ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      await meetLocal(ana, bia);

      expect(bia.repo.lists.map((l) => l.name), ['Shop']);
    });

    test('a phone that claims to be someone else, with another key, is turned away', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      await meetLocal(ana, bia); // Ana now knows Bia by her key

      // somebody with the code, and Bia's id, but not her key
      final impostor = await LocalPhone.start('Not Bia', code: ana.family.code, memberId: bia.repo.localMyId);
      final (forAna, forImpostor) = await meetLocal(ana, impostor);

      expect(forAna.ok, isFalse);
      expect(forImpostor.ok, isFalse);
      expect(forAna.status, PeerStatus.invalidCredential);
    });
  });

  group('leaving the family', () {
    Future<void> later() => Future<void>.delayed(const Duration(milliseconds: 3));

    test('someone who leaves is struck off the others\' lists', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final cai = await LocalPhone.start('Cai', code: ana.family.code);
      await meetLocal(ana, bia);
      await meetLocal(ana, cai);
      await meetLocal(bia, cai);

      expect(await bia.repo.prepareLeaving(), isTrue);
      await meetLocal(bia, ana); // she tells the one phone near her, and goes
      await meetLocal(ana, cai); // and it passes on

      expect(ana.repo.localMembers.map((m) => m.name), ['Ana', 'Cai']);
      expect(cai.repo.localMembers.map((m) => m.name), ['Cai', 'Ana']);
    });

    test('the admin who leaves hands the family to the oldest member, who is believed by everyone', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      await later();
      final bia = await LocalPhone.start('Bia', code: ana.family.code); // the oldest after Ana
      await later();
      final cai = await LocalPhone.start('Cai', code: ana.family.code);
      await meetLocal(ana, bia);
      await meetLocal(ana, cai);
      await meetLocal(bia, cai);

      expect(ana.repo.localHeir!.name, 'Bia');
      await ana.repo.setLocalRights(cai.repo.localMyId, {
        Repository.localTypeId: {for (final a in Ability.values) a: a == Ability.view},
      });
      await meetLocal(ana, cai);
      await meetLocal(ana, bia);

      expect(await ana.repo.prepareLeaving(), isTrue);
      await meetLocal(ana, cai); // the only phone Ana meets before she goes is Cai's
      await meetLocal(cai, bia); // and Cai tells Bia

      expect(bia.repo.isLocalAdmin, isTrue);
      expect(bia.repo.me!.isAdmin, isTrue);
      expect(cai.repo.isLocalAdmin, isFalse);
      expect(cai.repo.localMembers.firstWhere((m) => m.name == 'Bia').founder, isTrue);
      expect(cai.repo.localMembers.map((m) => m.name), isNot(contains('Ana')));
      expect(bia.repo.localMembers.map((m) => m.name), isNot(contains('Ana')));
      expect(bia.repo.localMembers.every((m) => m.founder == (m.name == 'Bia')), isTrue);

      // the new admin's word is the one that counts now
      expect(await bia.repo.setLocalRights(cai.repo.localMyId, {
        Repository.localTypeId: {for (final a in Ability.values) a: true},
      }), isTrue);
      await meetLocal(bia, cai);
      expect(cai.repo.me!.can(Repository.localTypeId, Ability.editItems), isTrue);

      // what Ana had set for people was signed again by the new admin, so a phone that only ever meets the new admin believes it
      final dan = await LocalPhone.start('Dan', code: ana.family.code);
      await ana.repo.setLocalRights(bia.repo.localMyId, {}); // (a leftover of the old admin must not matter)
      await meetLocal(bia, dan);
      expect(dan.repo.localMembers.firstWhere((m) => m.name == 'Bia').founder, isTrue);
    });

    test('the admin who is alone just leaves, and nobody else can take the family over from a forged hand-over', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      expect(await ana.repo.prepareLeaving(), isTrue);

      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      final cai = await LocalPhone.start('Cai', code: ana.family.code);
      await meetLocal(ana, bia);
      await meetLocal(ana, cai);

      // Cai writes himself a hand-over, signed with his own key
      final signature = await cai.repo.localSigner!.sign('owner|${cai.repo.localMyId}|99999999999999');
      await bia.repo.applyLocalDelta({
        'lists': const [],
        'items': const [],
        'types': const [],
        'members': const [],
        'gone': const [],
        'owner': {'to': cai.repo.localMyId, 'at': 99999999999999, 'sig': signature},
      });

      expect(bia.repo.localMembers.where((m) => m.name == 'Cai').every((m) => !m.founder), isTrue);
    });
  });

  group('phones that are not of the family', () {
    test('with another code never get anything, and are told nothing', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final stranger = await LocalPhone.start('Eve', familyName: 'Costa');
      ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);

      final (forAna, forEve) = await meetLocal(ana, stranger);

      expect(forAna.ok, isFalse);
      expect(forEve.ok, isFalse);
      expect(forAna.status, PeerStatus.invalidCredential);
      expect(stranger.repo.lists, isEmpty);
      expect(ana.repo.lists.map((l) => l.name), ['Shop']);
    });

    test('on another version of the app do not exchange either', () async {
      final ana = await LocalPhone.start('Ana', familyName: 'Silva');
      final bia = await LocalPhone.start('Bia', code: ana.family.code);
      ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);

      final (forAna, _) = await meetLocal(ana, bia, versionB: '1.1.0+8');

      expect(forAna.status, PeerStatus.versionMismatch);
      expect(bia.repo.lists, isEmpty);
    });
  });
}
