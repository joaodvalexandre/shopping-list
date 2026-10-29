import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/data/api_client.dart';
import 'package:shopping_list/data/repository.dart';
import 'package:shopping_list/state/auth_state.dart';
import 'package:shopping_list/state/sync_service.dart';

import 'repository_test.dart' show response;
import 'support/fakes.dart';
import 'support/memory_store.dart';

class _SignedIn implements AuthState {
  @override
  AuthStatus get status => AuthStatus.signedIn;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late String marker;
  late int syncs;
  late bool online;
  late SyncService service;

  setUp(() {
    marker = 'a';
    syncs = 0;
    online = true;

    final api = apiAnswering((uri) {
      if (!online) return null;
      if (uri.path.endsWith('/watch')) return {'version': marker};

      syncs++;
      return response(visible: []);
    });

    service = SyncService(
      api: api,
      repository: Repository(MemoryStore()),
      auth: _SignedIn(),
      watchEvery: const Duration(milliseconds: 20),
      connectivityChanges: const Stream.empty(),
    );
  });

  tearDown(() => service.dispose());

  test('it syncs when the server says something changed, and not otherwise', () async {
    service.start();
    await until(() => syncs == 1);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(syncs, 1);                 // many looks, nothing changed, no sync

    marker = 'b';                     // another phone, or the web, changed something
    await until(() => syncs == 2);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(syncs, 2);                 // and the new marker is the one remembered
  });

  test('it leaves the phone alone in the background and catches up on coming back', () async {
    service.start();
    await until(() => syncs == 1);

    service.setForeground(false);
    marker = 'b';
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(syncs, 1);

    service.setForeground(true);
    await until(() => syncs == 2);
  });

  test('being offline is no reason to sync, nor to complain', () async {
    service.start();
    await until(() => syncs == 1);

    online = false;
    marker = 'b';
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(syncs, 1);
    expect(service.status, isNot(SyncStatus.error));
  });

  test('a server that is down counts as unreachable even when it answers, and is noticed when it is back', () async {
    var down = false;
    var syncCount = 0;

    final api = ApiClient(
      baseUrl: 'http://server',
      client: MockClient((request) async {
        if (down) return http.Response('{"message":"Service Unavailable"}', 503);
        if (request.url.path.endsWith('/watch')) return http.Response(jsonEncode({'version': 'a'}), 200);

        syncCount++;
        return http.Response(jsonEncode(response(visible: [])), 200);
      }),
    );

    final watched = SyncService(
      api: api,
      repository: Repository(MemoryStore()),
      auth: _SignedIn(),
      watchEvery: const Duration(milliseconds: 20),
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(watched.dispose);

    watched.start();
    await until(() => syncCount == 1);
    expect(watched.serverUnreachable, isFalse);

    // the network is up, the server is not: phones nearby are looked for
    down = true;
    await until(() => watched.serverUnreachable);
    expect(watched.status, SyncStatus.offline);

    // and when it is back, everything is sent and brought up to date at once
    down = false;
    await until(() => syncCount == 2 && !watched.serverUnreachable);
  });
}
