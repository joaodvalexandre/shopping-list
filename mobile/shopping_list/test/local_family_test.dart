import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/models.dart';
import 'package:shopping_list/data/repository.dart';
import 'package:shopping_list/peer/local_family.dart';
import 'package:shopping_list/peer/session.dart';

import 'support/memory_store.dart';
import 'support/peer_support.dart';

/// A phone of a local family: its own database, the family's code, and a name.
class LocalPhone {
  LocalPhone(this.name, this.store, this.repo, this.family, this.key, this.keyStore);

  final String name;
  final MemoryStore store;
  final Repository repo;
  final LocalFamilyStore keyStore;
  LocalFamily family;
  final LocalFamilyKey key;

  static Future<LocalPhone> start(String name, {String? code, String familyName = ''}) async {
    final store = MemoryStore();
    final repo = Repository(store);
    final keyStore = LocalFamilyStore(store);

    await repo.startLocal(myName: name, familyName: familyName);
    final family = code == null
        ? await keyStore.create(myName: name, familyName: familyName)
        : await keyStore.join(myName: name, code: code);

    return LocalPhone(name, store, repo, family, await LocalFamilyKey.derive(family.code), keyStore);
  }

  LocalPeerSession session(PeerChannel channel, {String version = '1.1.0+7'}) => LocalPeerSession(
        key: key,
        repository: repo,
        appVersion: version,
        channel: channel,
        displayName: name,
        familyName: family.familyName,
        timeout: const Duration(seconds: 3),
        onFamilyName: (familyName) async {
          final adopted = await keyStore.adoptFamilyName(familyName);
          if (adopted != null) family = adopted;
          await repo.setFamilyName(familyName);
        },
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
      expect(bia.family.familyName, isEmpty);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 2);
      ana.repo.addItem(shop.uuid, name: 'Bread', quantity: 1);

      final (forAna, forBia) = await meetLocal(ana, bia);

      expect(forAna.ok, isTrue);
      expect(forBia.ok, isTrue);
      expect(bia.items('Shop'), ['Bread', 'Milk']);
      expect(bia.family.familyName, 'Silva');
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
