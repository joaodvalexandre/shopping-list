import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
}
