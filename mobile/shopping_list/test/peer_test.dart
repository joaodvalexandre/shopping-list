import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/models.dart';
import 'package:shopping_list/peer/identity.dart';
import 'package:shopping_list/peer/session.dart';

import 'support/peer_support.dart';

void main() {
  setUpAll(setUpServerKeys);

  final shopping = [listJson('L1', 'Barbecue')];
  final basics = [itemJson('I1', 'L1', 'Beer'), itemJson('I2', 'L1', 'Bread')];

  group('who may exchange', () {
    test('phones of one family on the same version swap what they have not sent', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      ana.repo.addItem('L1', name: 'Sausages', quantity: 4);
      rui.repo.setStatus('L1', 'I1', ItemStatus.inCart);

      final (forAna, forRui) = await meet(ana, rui);

      expect(forAna.ok, isTrue);
      expect(forRui.ok, isTrue);
      expect(forAna.peerName, 'Rui');
      expect(forAna.sent, 1);      // the sausages
      expect(forAna.applied.items, 1); // the beer in the cart

      // each has both changes
      expect(ana.item('L1', 'I1').status, ItemStatus.inCart);
      expect(rui.repo.itemsOf('L1').map((i) => i.name), contains('Sausages'));
      expect(rui.repo.itemsOf('L1').firstWhere((i) => i.name == 'Sausages').quantity, 4);

      // and each keeps them as its own unsent changes, so whoever reaches the server first sends them
      expect(ana.item('L1', 'I1').pending.has('status'), isTrue);
      expect(rui.repo.itemsOf('L1').firstWhere((i) => i.name == 'Sausages').pending.isNew, isTrue);
      expect(ana.repo.buildPush(null).payload['changes'], isNotNull);
    });

    test('different app versions go no further than saying so', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics, version: '1.1.0+3');
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics, version: '1.1.0+4');

      ana.repo.addItem('L1', name: 'Sausages', quantity: 4);
      rui.repo.setStatus('L1', 'I1', ItemStatus.inCart);

      final (forAna, forRui) = await meet(ana, rui);

      expect(forAna.status, PeerStatus.versionMismatch);
      expect(forAna.theirVersion, '1.1.0+4');
      expect(forRui.status, PeerStatus.versionMismatch);
      expect(forRui.theirVersion, '1.1.0+3');

      expect(ana.item('L1', 'I1').status, ItemStatus.toBuy);
      expect(rui.repo.itemsOf('L1').map((i) => i.name), isNot(contains('Sausages')));
    });

    test('a phone of another family is turned away', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final stranger = await makePhone(userId: 9, name: 'Zé', familyId: 2, lists: shopping, items: basics);

      ana.repo.addItem('L1', name: 'Sausages', quantity: 4);
      final (forAna, forStranger) = await meet(ana, stranger);

      expect(forAna.status, PeerStatus.differentFamily);
      expect(forStranger.status, PeerStatus.differentFamily);
      expect(stranger.repo.itemsOf('L1').map((i) => i.name), isNot(contains('Sausages')));
    });

    test('an expired credential is not accepted, from either side', () async {
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      // Ana's clock says it is 8 days later: Rui's credential (valid for 7) has run out, hers (30) has not
      int later() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + 8 * 86400;
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics, expiresIn: 30 * 86400, clock: later);
      final (forAna, _) = await meet(ana, rui);
      expect(forAna.status, PeerStatus.expired);

      // and a phone whose own credential ran out has nothing to show
      final stale = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics, expiresIn: -10);
      final (_, forStale) = await meet(await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics), stale);
      expect(forStale.status, PeerStatus.noCredential);
    });

    test('a credential the server did not sign is not accepted', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      // Rui forges a credential that says he is an admin of everything, signed with his own key
      final forgedClaims = jsonEncode({
        'v': 1, 'user_id': 3, 'family_id': 1, 'name': 'Rui', 'role': 'admin', 'key': base64.encode(await rui.identity.publicKey()),
        'permissions': {'1': all, '2': all}, 'iat': 0, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1000,
      });
      final ruiKeys = await serverAlgorithm.newKeyPair();
      final forgedSignature = await serverAlgorithm.sign(utf8.encode(forgedClaims), keyPair: ruiKeys);
      await rui.store.setMeta('peer_credential', jsonEncode(PeerCredential(credential: forgedClaims, signature: base64.encode(forgedSignature.bytes), serverKey: serverKeyText, fetchedAt: 0).toJson()));

      final (forAna, _) = await meet(ana, rui);
      expect(forAna.status, PeerStatus.invalidCredential);
    });

    test('a phone cannot pass itself off as another person with their credential', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);
      final joana = await makePhone(userId: 1, name: 'Joana', lists: shopping, items: basics);

      // Rui copies Joana's credential (it is just text) but cannot sign with her key
      await rui.store.setMeta('peer_credential', (await joana.store.getMeta('peer_credential'))!);

      final (forAna, _) = await meet(ana, rui);
      expect(forAna.status, PeerStatus.invalidCredential);
    });

    test('a phone with no credential cannot take part', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);
      rui.store.meta.remove('peer_credential');

      final (forAna, forRui) = await meet(ana, rui);
      expect(forRui.status, PeerStatus.noCredential);
      expect(forAna.ok, isFalse);
    });
  });

  group('what is exchanged', () {
    test('only changes both people may make are taken in', () async {
      // Rui may only put things in the cart; Ana may do everything
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', rights: cartOnly, lists: shopping, items: basics);

      ana.repo.addItem('L1', name: 'Sausages', quantity: 4);
      ana.repo.updateItem('L1', 'I2', name: 'Rye bread', quantity: 1);
      rui.repo.setStatus('L1', 'I1', ItemStatus.inCart);

      await meet(ana, rui);

      // Ana takes the cart change; Rui cannot add or rename, so he does not take Ana's changes
      expect(ana.item('L1', 'I1').status, ItemStatus.inCart);
      expect(rui.repo.itemsOf('L1').map((i) => i.name), unorderedEquals(['Beer', 'Bread']));
    });

    test('what a credential says counts, not what the other phone claims for itself', () async {
      // Rui's own phone allows him to rename, but the server's credential says he may only view
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', rights: all, credentialRights: viewOnly, lists: shopping, items: basics);

      rui.repo.updateItem('L1', 'I2', name: 'Rye bread', quantity: 1);
      await meet(ana, rui);

      expect(ana.item('L1', 'I2').name, 'Bread');
    });

    test('a list is never offered to someone it is hidden from', () async {
      final secret = [listJson('L1', 'Barbecue'), listJson('L2', 'Surprise', hiddenFrom: [3])];
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      // Ana makes a list on her phone which she hides from Rui (user 3), and one that is not hidden
      final hidden = ana.repo.createList(name: 'Rui birthday', listTypeId: 1, hiddenFrom: [3]);
      ana.repo.addItem(hidden.uuid, name: 'Cake', quantity: 1);
      final open = ana.repo.createList(name: 'Weekly', listTypeId: 1);
      expect(secret, isNotEmpty);

      final (_, forRui) = await meet(ana, rui);

      expect(forRui.applied.lists, 1);
      expect(rui.repo.lists.map((l) => l.name), unorderedEquals(['Barbecue', 'Weekly']));
      expect(rui.repo.list(open.uuid)!.pending.isNew, isTrue);
      expect(rui.repo.list(hidden.uuid), isNull);
    });

    test('a list type a person may not see is not offered either', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      // the server never gave Rui this list: his person may not see this type
      final rui = await makePhone(userId: 3, name: 'Rui', rights: none, credentialRights: none);

      final fresh = ana.repo.createList(name: 'Weekly', listTypeId: 1);
      ana.repo.addItem('L1', name: 'Sausages', quantity: 1);
      final (_, forRui) = await meet(ana, rui);

      expect(forRui.applied.total, 0);
      expect(rui.repo.lists, isEmpty);
      expect(rui.repo.list(fresh.uuid), isNull);
    });

    test('a list that only its managers know the hidden-from of is only passed on to a phone that holds it', () async {
      // Bia cannot manage lists, so she does not know who a list is hidden from
      final bia = await makePhone(userId: 2, name: 'Bia', rights: cartOnly, lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: const [], items: const []);   // never got the list

      bia.repo.setStatus('L1', 'I1', ItemStatus.inCart);
      await meet(bia, rui);

      expect(rui.repo.lists, isEmpty);

      // a phone which does hold it gets the change
      final joana = await makePhone(userId: 1, name: 'Joana', lists: shopping, items: basics);
      await meet(bia, joana);
      expect(joana.item('L1', 'I1').status, ItemStatus.inCart);
    });

    test('a change that is older than what the phone already has is left out', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      ana.repo.setStatus('L1', 'I1', ItemStatus.inCart);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      rui.repo.setStatus('L1', 'I1', ItemStatus.purchased);   // later

      await meet(ana, rui);

      expect(ana.item('L1', 'I1').status, ItemStatus.purchased);   // the later one wins on both
      expect(rui.item('L1', 'I1').status, ItemStatus.purchased);
    });

    test('a deletion passes on, and cannot be undone by a phone that still has the item as a new one', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      ana.repo.deleteItem('L1', 'I2');
      await meet(ana, rui);
      expect(rui.repo.itemsOf('L1').map((i) => i.name), ['Beer']);

      // An item Ana made and Rui got, which Rui then deletes, is not brought back by Ana meeting him again
      final extra = ana.repo.addItem('L1', name: 'Wine', quantity: 1);
      await meet(ana, rui);
      expect(rui.repo.itemsOf('L1').map((i) => i.name), contains('Wine'));

      rui.repo.deleteItem('L1', extra.uuid);
      await meet(ana, rui);

      expect(rui.repo.itemsOf('L1').map((i) => i.name), isNot(contains('Wine')));
      expect(ana.repo.itemsOf('L1').map((i) => i.name), isNot(contains('Wine')));   // and the deletion reached Ana
    });

    test('an item in the cart is not deleted, here nor by a phone that deleted it first', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      // Ana deletes the bread; meanwhile Rui puts it in the cart
      ana.repo.deleteItem('L1', 'I2');
      rui.repo.setStatus('L1', 'I2', ItemStatus.inCart);
      rui.repo.deleteItem('L1', 'I2');   // and cannot delete it from there

      await meet(ana, rui);

      expect(rui.repo.itemsOf('L1').map((i) => i.name), contains('Bread'));   // Rui keeps it: it is in his cart
    });

    test('meeting again changes nothing', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      ana.repo.addItem('L1', name: 'Sausages', quantity: 4);
      rui.repo.setStatus('L1', 'I1', ItemStatus.inCart);

      await meet(ana, rui);
      final (again, _) = await meet(ana, rui);

      expect(again.ok, isTrue);
      expect(again.applied.total, 0);
      expect(ana.repo.itemsOf('L1'), hasLength(3));
    });

    test('what arrives is sent to the server by whichever phone reaches it, as an ordinary change', () async {
      final ana = await makePhone(userId: 2, name: 'Ana', lists: shopping, items: basics);
      final rui = await makePhone(userId: 3, name: 'Rui', lists: shopping, items: basics);

      rui.repo.setStatus('L1', 'I1', ItemStatus.inCart);
      await meet(ana, rui);

      // Ana reaches the server first and sends Rui's change as her own
      final push = ana.repo.buildPush(null);
      final items = (push.payload['changes'] as Map)['items'] as List;
      expect(items.single['uuid'], 'I1');
      expect(items.single['status'], 'in_cart');
      expect(items.single.containsKey('name'), isFalse);

      // the server accepts it; Ana's copy is no longer waiting
      await ana.repo.applyResponse({
        ...serverState(lists: shopping, items: [itemJson('I1', 'L1', 'Beer', status: 'in_cart'), itemJson('I2', 'L1', 'Bread')]),
        'results': {'lists': {}, 'items': {'I1': {'status': 'applied'}}},
        'me': jsonDecode(await ana.store.getMeta('me') ?? '{}'),
      }, push.sent);
      expect(ana.item('L1', 'I1').pending.isEmpty, isTrue);

      // Rui's own phone still has it as unsent: later it sends the same change and the server finds nothing to change
      expect(rui.item('L1', 'I1').pending.has('status'), isTrue);
    });
  });
}
