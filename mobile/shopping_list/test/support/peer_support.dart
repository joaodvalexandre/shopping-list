import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shopping_list/core/time.dart';
import 'package:shopping_list/data/models.dart';
import 'package:shopping_list/data/repository.dart';
import 'package:shopping_list/peer/identity.dart';
import 'package:shopping_list/peer/session.dart';

import 'fakes.dart';
import 'memory_store.dart';

/// Two ends of a line that hand messages over as JSON, as the radio does.
class MemoryChannel implements PeerChannel {
  MemoryChannel._();

  final _incoming = StreamController<Map<String, dynamic>>();
  late final MemoryChannel _other;

  static (MemoryChannel, MemoryChannel) pair() {
    final a = MemoryChannel._();
    final b = MemoryChannel._();
    a._other = b;
    b._other = a;
    return (a, b);
  }

  @override
  Stream<Map<String, dynamic>> get messages => _incoming.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    final copy = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
    if (!_other._incoming.isClosed) _other._incoming.add(copy);
  }

  @override
  Future<void> close() async => _incoming.close();
}

const all = {'can_view': true, 'can_add_items': true, 'can_edit_items': true, 'can_change_status': true, 'can_manage_lists': true};
const none = {'can_view': false, 'can_add_items': false, 'can_edit_items': false, 'can_change_status': false, 'can_manage_lists': false};
const viewOnly = {'can_view': true, 'can_add_items': false, 'can_edit_items': false, 'can_change_status': false, 'can_manage_lists': false};
const cartOnly = {'can_view': true, 'can_add_items': false, 'can_edit_items': false, 'can_change_status': true, 'can_manage_lists': false};

/// The server: signs credentials. One for the whole test.
final serverAlgorithm = Ed25519();
late SimpleKeyPair serverKeys;
late String serverKeyText;

class Phone {
  Phone(this.userId, this.name, this.store, this.repo, this.identity, this.version);

  final int userId;
  final String name;
  final MemoryStore store;
  final Repository repo;
  final PeerIdentity identity;
  final String version;

  ShoppingListRecord list(String uuid) => repo.list(uuid)!;

  ItemRecord item(String listUuid, String uuid) => list(listUuid).items.firstWhere((i) => i.uuid == uuid);
}

Map<String, dynamic> serverState({required List<Map<String, dynamic>> lists, required List<Map<String, dynamic>> items}) => {
      'server_time': '2026-10-29T10:00:00.000Z',
      'results': {'lists': {}, 'items': {}},
      'lists': lists,
      'items': items,
      'visible_list_uuids': [for (final list in lists) list['uuid']],
    };

Map<String, dynamic> listJson(String uuid, String name, {int type = 1, List<int>? hiddenFrom}) => {
      'uuid': uuid,
      'name': name,
      'name_changed_at': isoFromMs(1000),
      'list_type_id': type,
      'updated_at': isoFromMs(1000),
      'deleted_at': null,
      'hidden_from': ?hiddenFrom,
    };

Map<String, dynamic> itemJson(String uuid, String listUuid, String name, {String status = 'to_buy', int quantity = 1}) => {
      'uuid': uuid,
      'list_uuid': listUuid,
      'name': name,
      'name_changed_at': isoFromMs(1000),
      'quantity': quantity,
      'quantity_changed_at': isoFromMs(1000),
      'status': status,
      'status_changed_at': isoFromMs(1000),
      'updated_at': isoFromMs(1000),
      'deleted_at': null,
    };

/// A phone of a family, signed in, holding what the server last said, with a credential the server signed.
Future<Phone> makePhone({
  required int userId,
  required String name,
  Map<String, bool> rights = all,
  Map<String, bool>? credentialRights,
  int familyId = 1,
  String version = '1.1.0+3',
  List<Map<String, dynamic>> lists = const [],
  List<Map<String, dynamic>> items = const [],
  int expiresIn = 7 * 86400,
  int Function()? clock,
}) async {
  final store = MemoryStore();
  final repo = Repository(store);
  await repo.load();

  await repo.applyResponse({
    ...serverState(lists: lists, items: items),
    'me': {
      'user': {'id': userId, 'name': name, 'email': '$name@example.com', 'role': 'member', 'locale': 'pt', 'must_change_password': false},
      'family': {'id': familyId, 'name': 'Silva'},
      'list_types': [
        {'id': 1, 'name': 'Groceries'},
        {'id': 2, 'name': 'Party'},
      ],
      'permissions': {'1': rights, '2': rights},
      'members': [
        {'id': 1, 'name': 'Joana'},
        {'id': 2, 'name': 'Bia'},
        {'id': 3, 'name': 'Rui'},
      ],
    },
  }, {});

  final identity = PeerIdentity(secrets: MemorySecrets(), store: store, clock: clock);

  final claims = jsonEncode({
    'v': 1,
    'user_id': userId,
    'family_id': familyId,
    'name': name,
    'role': 'member',
    'key': base64.encode(await identity.publicKey()),
    'permissions': {'1': credentialRights ?? rights, '2': credentialRights ?? rights},
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn,
  });
  final signature = await serverAlgorithm.sign(utf8.encode(claims), keyPair: serverKeys);

  await store.setMeta(
    'peer_credential',
    jsonEncode(PeerCredential(credential: claims, signature: base64.encode(signature.bytes), serverKey: serverKeyText, fetchedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000).toJson()),
  );

  return Phone(userId, name, store, repo, identity, version);
}

/// Two phones meet.
Future<(PeerResult, PeerResult)> meet(Phone a, Phone b) async {
  final (lineA, lineB) = MemoryChannel.pair();

  final results = await Future.wait([
    PeerSession(identity: a.identity, repository: a.repo, appVersion: a.version, channel: lineA, displayName: a.name, timeout: const Duration(seconds: 3)).run(),
    PeerSession(identity: b.identity, repository: b.repo, appVersion: b.version, channel: lineB, displayName: b.name, timeout: const Duration(seconds: 3)).run(),
  ]);

  return (results[0], results[1]);
}

/// Make the server's signing key (once per test file).
Future<void> setUpServerKeys() async {
  serverKeys = await serverAlgorithm.newKeyPair();
  serverKeyText = base64.encode((await serverKeys.extractPublicKey()).bytes);
}
