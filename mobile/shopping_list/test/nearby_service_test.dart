import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/data/models.dart';
import 'package:shopping_list/data/repository.dart';
import 'package:shopping_list/peer/identity.dart';
import 'package:shopping_list/peer/local_family.dart';
import 'package:shopping_list/peer/frames.dart';
import 'package:shopping_list/peer/nearby_service.dart';
import 'package:shopping_list/peer/radio.dart';

import 'support/fakes.dart';
import 'support/memory_store.dart';
import 'support/peer_support.dart';

/// The air between phones: radios in range of each other find and call each other.
class FakeAir {
  final radios = <FakeRadio>[];

  FakeRadio? byId(String id) => radios.where((r) => r.id == id).firstOrNull;
}

class FakeRadio implements NearbyRadio {
  FakeRadio(this.air, this.id) {
    air.radios.add(this);
  }

  final FakeAir air;
  final String id;
  RadioEvents? events;
  String name = '';
  bool started = false;
  bool refuses = false;

  /// Calls to this phone vanish in the air: neither a connection nor an error comes back.
  bool stalls = false;
  int starts = 0;
  final calledTo = <String>[];
  final accepted = <String>{};

  void _later(void Function() action) => Future<void>.delayed(Duration.zero, action);

  @override
  Future<bool> start({required String name, required RadioEvents events}) async {
    starts++;
    if (refuses) return false;

    this.name = name;
    this.events = events;
    started = true;

    for (final other in air.radios.where((r) => r != this && r.started)) {
      _later(() => events.found(other.id, other.name));
      _later(() => other.events?.found(id, name));
    }
    return true;
  }

  @override
  Future<void> stop() async {
    started = false;
    for (final other in air.radios.where((r) => r != this && r.started)) {
      _later(() => other.events?.lost(id));
    }
  }

  @override
  Future<void> connect(String endpointId, {required String name}) async {
    calledTo.add(endpointId);
    final other = air.byId(endpointId);
    if (other == null || !other.started || stalls) return;

    _later(() {
      events?.initiated(endpointId, other.name);
      other.events?.initiated(id, this.name);
    });
  }

  @override
  Future<void> accept(String endpointId) async {
    accepted.add(endpointId);
    final other = air.byId(endpointId);

    if (other != null && other.accepted.contains(id)) {
      _later(() {
        events?.result(endpointId, true);
        other.events?.result(id, true);
      });
    }
  }

  @override
  Future<void> reject(String endpointId) async {
    final other = air.byId(endpointId);
    _later(() {
      events?.result(endpointId, false);
      other?.events?.result(id, false);
    });
  }

  @override
  Future<void> send(String endpointId, Uint8List bytes) async {
    final other = air.byId(endpointId);
    // Nearby carries at most about 32 KB at a time
    expect(bytes.length, lessThan(32 * 1024));
    _later(() => other?.events?.received(id, bytes));
  }

  @override
  Future<void> disconnect(String endpointId) async {
    final other = air.byId(endpointId);
    accepted.remove(endpointId);
    _later(() => other?.events?.disconnected(id));
  }
}

class Trigger extends ChangeNotifier {
  void fire() => notifyListeners();
}

Future<void> until(bool Function() condition, {int seconds = 5}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  setUpAll(setUpServerKeys);

  final shopping = [listJson('L1', 'Barbecue')];
  final basics = [itemJson('I1', 'L1', 'Beer'), itemJson('I2', 'L1', 'Bread')];

  late FakeAir air;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    air = FakeAir();
  });

  /// A phone with its radio and the service that drives it.
  Future<({Phone phone, FakeRadio radio, NearbyService service, Trigger trigger})> phoneWithService(
    String device,
    int userId,
    String name, {
    String version = '1.1.0+3',
    bool Function()? offline,
    Future<bool> Function()? permissions,
    Duration meetAgainAfter = const Duration(hours: 1),
    Duration linkTimeout = const Duration(seconds: 45),
    int familyId = 1,
  }) async {
    final phone = await makePhone(userId: userId, name: name, version: version, familyId: familyId, lists: shopping, items: basics);
    final radio = FakeRadio(air, 'ep-$device');
    final trigger = Trigger();

    final service = NearbyService(
      radio: radio,
      identity: phone.identity,
      repository: phone.repo,
      prefs: prefs,
      appVersion: version,
      deviceId: device,
      trigger: trigger,
      offline: offline ?? () => true,
      signedIn: () => true,
      personName: () => name,
      hasPermissions: () async => permissions == null,
      ensurePermissions: permissions ?? () async => true,
      meetAgainAfter: meetAgainAfter,
      callAfterWaiting: const Duration(milliseconds: 100),
      retryAfter: const Duration(milliseconds: 50),
      linkTimeout: linkTimeout,
    );

    return (phone: phone, radio: radio, service: service, trigger: trigger);
  }

  test('two offline family phones find each other and swap what they have not sent', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana');
    final rui = await phoneWithService('bbbb', 3, 'Rui');

    ana.phone.repo.addItem('L1', name: 'Sausages', quantity: 4);
    rui.phone.repo.setStatus('L1', 'I1', ItemStatus.inCart);

    ana.service.setForeground(true);
    rui.service.setForeground(true);

    await until(() => ana.service.lastResult != null && rui.service.lastResult != null);

    expect(ana.service.lastResult!.ok, isTrue);
    expect(ana.service.lastResult!.peerName, 'Rui');
    expect(rui.service.lastResult!.peerName, 'Ana');
    expect(ana.phone.item('L1', 'I1').status, ItemStatus.inCart);
    expect(rui.phone.repo.itemsOf('L1').map((i) => i.name), contains('Sausages'));

    // and they stay connected, for the next time something changes
    await until(() => ana.service.state == NearbyState.connected && rui.service.state == NearbyState.connected);
    expect(ana.service.currentPeer, 'Rui');
    expect(rui.service.currentPeer, 'Ana');
  });

  test('they meet again when something changed here, and not before', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana');
    final rui = await phoneWithService('bbbb', 3, 'Rui');
    ana.service.setForeground(true);
    rui.service.setForeground(true);

    await until(() => ana.service.lastResult != null && rui.service.lastResult != null);
    final first = ana.service.lastMeetingAt;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(ana.service.lastMeetingAt, first);   // an hour has not passed and nothing changed

    ana.phone.repo.addItem('L1', name: 'Ribs', quantity: 2);
    ana.trigger.fire();
    // (the call is made when it next looks; a found event prompts it)
    ana.radio.events!.lost('ep-bbbb');
    ana.radio.events!.found('ep-bbbb', rui.radio.name);

    await until(() => rui.phone.repo.itemsOf('L1').any((i) => i.name == 'Ribs'));
  });

  test('they meet again soon after something changed here, without waiting for the next round', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana');
    final rui = await phoneWithService('bbbb', 3, 'Rui');
    ana.service.setForeground(true);
    rui.service.setForeground(true);

    await until(() => ana.service.lastResult != null && rui.service.lastResult != null);
    await until(() => ana.service.state == NearbyState.connected);
    final connections = ana.radio.calledTo.length + rui.radio.calledTo.length;

    ana.phone.repo.addItem('L1', name: 'Ribs', quantity: 2);
    ana.trigger.fire();
    await until(() => rui.phone.repo.itemsOf('L1').any((i) => i.name == 'Ribs'));

    // and the other way round, with no new connection for either
    rui.phone.repo.addItem('L1', name: 'Wine', quantity: 1);
    rui.trigger.fire();
    await until(() => ana.phone.repo.itemsOf('L1').any((i) => i.name == 'Wine'));

    expect(ana.radio.calledTo.length + rui.radio.calledTo.length, connections);
  });

  test('connected phones let go when another phone of the family needs its turn, and meet again later', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana');
    final rui = await phoneWithService('bbbb', 3, 'Rui');
    ana.service.setForeground(true);
    rui.service.setForeground(true);
    await until(() => ana.service.state == NearbyState.connected && rui.service.state == NearbyState.connected);

    // a third phone turns up
    final bia = await phoneWithService('cccc', 4, 'Bia');
    bia.service.setForeground(true);

    await until(() => bia.service.lastResult?.ok == true);
    expect(bia.service.lastResult!.ok, isTrue);
  });

  test('a call that never gets an answer is dropped and tried again, and then works', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana', linkTimeout: const Duration(milliseconds: 200));
    final rui = await phoneWithService('bbbb', 3, 'Rui', linkTimeout: const Duration(milliseconds: 200));
    rui.radio.stalls = true;
    ana.radio.stalls = true;

    ana.service.setForeground(true);
    rui.service.setForeground(true);

    // nothing comes back: the link is given up on, and does not block the next one
    await until(() => ana.service.lastResult?.status.name == 'timeout');
    await until(() => ana.service.state == NearbyState.searching);

    ana.radio.stalls = false;
    rui.radio.stalls = false;

    await until(() => ana.service.lastResult?.ok == true && rui.service.lastResult?.ok == true);
  });

  test('a phone of another family is not even connected to, while family phones still meet', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana');
    final stranger = await phoneWithService('bbbb', 7, 'Marta', familyId: 2);
    final rui = await phoneWithService('cccc', 3, 'Rui');

    ana.phone.repo.addItem('L1', name: 'Sausages', quantity: 4);
    stranger.phone.repo.addItem('L1', name: 'Secret', quantity: 1);

    for (final phone in [ana, stranger, rui]) {
      phone.service.setForeground(true);
    }

    await until(() => rui.phone.repo.itemsOf('L1').any((i) => i.name == 'Sausages'));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // nobody called the stranger, and the stranger called nobody
    expect(ana.radio.calledTo, isNot(contains('ep-bbbb')));
    expect(rui.radio.calledTo, isNot(contains('ep-bbbb')));
    expect(stranger.radio.calledTo, isEmpty);
    expect(stranger.service.lastResult, isNull);

    // and nothing was exchanged with them
    expect(ana.phone.repo.itemsOf('L1').map((i) => i.name), isNot(contains('Secret')));
    expect(stranger.phone.repo.itemsOf('L1').map((i) => i.name), isNot(contains('Sausages')));
  });

  test('a phone on another version is never connected to, and the person is told', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana', version: '1.1.0+3');
    final rui = await phoneWithService('bbbb', 3, 'Rui', version: '1.1.0+4');

    ana.phone.repo.addItem('L1', name: 'Sausages', quantity: 4);
    ana.service.setForeground(true);
    rui.service.setForeground(true);

    await until(() => ana.service.otherVersionSeen != null && rui.service.otherVersionSeen != null);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(ana.service.otherVersionSeen, '1.1.0+4');
    expect(rui.service.otherVersionSeen, '1.1.0+3');
    expect(ana.service.lastResult, isNull);
    expect(rui.phone.repo.itemsOf('L1').map((i) => i.name), isNot(contains('Sausages')));
  });

  test('it only looks for phones when the server cannot be reached', () async {
    var reachable = true;
    final ana = await phoneWithService('aaaa', 2, 'Ana', offline: () => !reachable);

    ana.service.setForeground(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ana.radio.started, isFalse);   // the server is there: it syncs with that

    reachable = false;
    ana.trigger.fire();
    await until(() => ana.radio.started);
    expect(ana.service.state, NearbyState.searching);

    reachable = true;                      // the connection is back: the radio goes off
    ana.trigger.fire();
    await until(() => !ana.radio.started);
    expect(ana.service.state, NearbyState.off);
  });

  test('it stays off in the background, when switched off, with no permission, or with no credential', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana');

    ana.service.setForeground(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ana.radio.started, isFalse);

    ana.service.setForeground(true);
    await until(() => ana.radio.started);

    ana.service.setForeground(false);
    await until(() => !ana.radio.started);

    await ana.service.setEnabled(false);
    ana.service.setForeground(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ana.radio.started, isFalse);

    await ana.service.setEnabled(true);
    await until(() => ana.radio.started);

    final denied = await phoneWithService('cccc', 4, 'Teo', permissions: () async => false);
    denied.service.setForeground(true);
    await until(() => denied.service.permissionDenied);
    expect(denied.radio.started, isFalse);

    final noCredential = await phoneWithService('dddd', 5, 'Zé');
    noCredential.phone.store.meta.remove('peer_credential');
    noCredential.service.setForeground(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(noCredential.radio.started, isFalse);
  });

  test('the phone refusing to start the radio is reported', () async {
    final ana = await phoneWithService('aaaa', 2, 'Ana');
    ana.radio.refuses = true;

    ana.service.setForeground(true);
    await until(() => ana.service.radioFailed);

    expect(ana.service.state, NearbyState.off);
  });

  test('of two phones, the one whose id sorts first makes the call', () {
    expect(NearbyService.shouldCall('aaaa', 'bbbb'), isTrue);
    expect(NearbyService.shouldCall('bbbb', 'aaaa'), isFalse);
  });

  test('a long message is cut into frames the radio can carry, and put back together', () {
    final big = {
      't': 'offer',
      'items': [for (var i = 0; i < 2000; i++) {'uuid': 'item-$i', 'name': 'Something with a long name $i', 'quantity': i}],
    };

    final frames = Frames.split(big, 7);
    expect(frames.length, greaterThan(3));
    expect(frames.every((f) => f.length < 32 * 1024), isTrue);

    final assembler = FrameAssembler();
    Map<String, dynamic>? whole;
    for (final frame in frames.reversed) {
      whole = assembler.add(frame) ?? whole;     // in any order
    }

    expect(whole, big);
    expect(assembler.add(Uint8List.fromList([1, 2, 3])), isNull);   // noise is ignored
  });

  group('a local family', () {
    /// A phone of a local family with its radio and service: no server, no credential.
    Future<({Repository repo, NearbyService service, FakeRadio radio, Trigger trigger})> localPhone(
      String device,
      String name, {
      String? code,
      String familyName = '',
    }) async {
      final store = MemoryStore();
      final repo = Repository(store);
      final family = LocalFamilyStore(store);

      await repo.startLocal(myName: name, familyName: familyName);
      if (code == null) {
        await family.create(myName: name, familyName: familyName);
      } else {
        await family.join(myName: name, code: code);
      }

      final radio = FakeRadio(air, 'ep-$device');
      final trigger = Trigger();
      final service = NearbyService(
        radio: radio,
        identity: PeerIdentity(secrets: MemorySecrets(), store: store),
        repository: repo,
        prefs: prefs,
        appVersion: '1.1.0+7',
        deviceId: device,
        trigger: trigger,
        offline: () => true,
        signedIn: () => true,
        personName: () => name,
        hasPermissions: () async => true,
        localFamily: family,
        meetAgainAfter: const Duration(hours: 1),
        callAfterWaiting: const Duration(milliseconds: 100),
        retryAfter: const Duration(milliseconds: 50),
      );

      return (repo: repo, service: service, radio: radio, trigger: trigger);
    }

    test('phones with the same code find each other, sync, and stay connected for the next change', () async {
      final ana = await localPhone('aaaa', 'Ana', familyName: 'Silva');
      final code = (await ana.service.localFamily!.current())!.code;
      final bia = await localPhone('bbbb', 'Bia', code: code);

      final shop = ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);
      ana.repo.addItem(shop.uuid, name: 'Milk', quantity: 2);

      ana.service.setForeground(true);
      bia.service.setForeground(true);

      await until(() => bia.repo.lists.length == 1 && bia.repo.itemsOf(shop.uuid).length == 1);
      await until(() => ana.service.state == NearbyState.connected && bia.service.state == NearbyState.connected);
      expect(bia.repo.me!.familyName, 'Silva');

      // a later change goes over the same connection, either way
      final connections = ana.radio.calledTo.length + bia.radio.calledTo.length;
      bia.repo.addItem(shop.uuid, name: 'Eggs', quantity: 6);
      bia.trigger.fire();
      await until(() => ana.repo.itemsOf(shop.uuid).any((i) => i.name == 'Eggs'));

      expect(ana.radio.calledTo.length + bia.radio.calledTo.length, connections);
    });

    test('a phone with another code is not even connected to', () async {
      final ana = await localPhone('aaaa', 'Ana', familyName: 'Silva');
      final stranger = await localPhone('bbbb', 'Eve', familyName: 'Costa');
      ana.repo.createList(name: 'Shop', listTypeId: Repository.localTypeId);

      ana.service.setForeground(true);
      stranger.service.setForeground(true);
      await until(() => ana.radio.started && stranger.radio.started);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(ana.radio.calledTo, isEmpty);
      expect(stranger.radio.calledTo, isEmpty);
      expect(stranger.repo.lists, isEmpty);
    });
  });
}
