import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../core/time.dart';
import '../data/peer_info.dart';
import '../data/repository.dart';
import 'identity.dart';
import 'local_family.dart';

/// A line to a phone nearby that carries whole messages. Nearby Connections in the app (which
/// cuts them into pieces); a pair of in-memory channels in tests.
abstract class PeerChannel {
  Stream<Map<String, dynamic>> get messages;

  Future<void> send(Map<String, dynamic> message);

  Future<void> close();
}

enum PeerStatus { done, versionMismatch, differentFamily, differentServer, invalidCredential, expired, noCredential, protocol, disconnected, timeout }

/// How a meeting with a phone nearby went.
class PeerResult {
  PeerResult(this.status, {this.peerName, this.theirVersion, this.sent = 0, PeerApplied? applied}) : applied = applied ?? _none;

  final PeerStatus status;
  final String? peerName;

  /// The other phone's app version, when it is not ours.
  final String? theirVersion;

  /// How many lists and items were offered to the other phone.
  final int sent;
  final PeerApplied applied;

  bool get ok => status == PeerStatus.done;

  static final _none = PeerApplied();
}

/// What two phones of one family say to each other when they meet with no server in reach.
///
/// 1. hello: each shows its app version and the server's signed credential. **Different
///    versions end it here**: only identical apps exchange data.
/// 2. proof: each proves it holds the key its credential names, by signing the other's challenge.
/// 3. ready: each tells which lists it holds.
/// 4. offer: each sends what it has not yet sent to the server, and only what the other's
///    person may see.
/// 5. done.
///
/// Both sides run the same steps and send before they wait, so neither waits for the other to speak first.
class PeerSession {
  PeerSession({
    required this.identity,
    required this.repository,
    required this.appVersion,
    required this.channel,
    this.displayName = '',
    this.timeout = const Duration(seconds: 20),
  });

  final PeerIdentity identity;
  final Repository repository;
  final String appVersion;
  final PeerChannel channel;
  final String displayName;
  final Duration timeout;

  static const protocol = 1;
  static const _proofPrefix = 'cestou-peer-v1';

  Future<PeerResult> run() async {
    final inbox = _Inbox();
    final subscription = channel.messages.listen(inbox.add, onDone: inbox.close, onError: (_) => inbox.close());

    try {
      return await _meet(inbox);
    } on _Bye catch (bye) {
      return PeerResult(_statusOf(bye.reason), theirVersion: bye.detail);
    } on TimeoutException {
      return PeerResult(PeerStatus.timeout);
    } on _Disconnected {
      return PeerResult(PeerStatus.disconnected);
    } on _Unexpected {
      return PeerResult(PeerStatus.protocol);
    } finally {
      await subscription.cancel();
    }
  }

  Future<PeerResult> _meet(_Inbox inbox) async {
    final mine = await identity.credential();
    if (mine == null) {
      await _bye('no_credential');
      return PeerResult(PeerStatus.noCredential);
    }

    // 1. hello
    final random = Random.secure();
    final myNonce = base64.encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);

    await channel.send({
      't': 'hello',
      'protocol': protocol,
      'version': appVersion,
      'name': displayName,
      'credential': mine.credential,
      'signature': mine.signature,
      'server_key': mine.serverKey,
      'nonce': myNonce,
    });

    final hello = await inbox.receive('hello', timeout);
    final theirVersion = hello['version']?.toString();

    if (theirVersion != appVersion || hello['protocol'] != protocol) {
      await _bye('version', theirVersion);
      return PeerResult(PeerStatus.versionMismatch, theirVersion: theirVersion);
    }

    final PeerInfo peer;
    try {
      peer = await identity.verify(
        credential: hello['credential'] as String? ?? '',
        signature: hello['signature'] as String? ?? '',
        serverKey: hello['server_key'] as String? ?? '',
      );
    } on PeerException catch (e) {
      await _bye(e.failure.name);
      return PeerResult(_statusOfFailure(e.failure));
    }

    final theirNonce = hello['nonce'] as String? ?? '';

    // 2. proof: each signs "the other's challenge, then its own"
    final proof = await identity.sign(utf8.encode('$_proofPrefix|$theirNonce|$myNonce'));
    await channel.send({'t': 'proof', 'signature': base64.encode(proof)});

    final theirProof = await inbox.receive('proof', timeout);
    final proven = await identity.verifyProof(peer, utf8.encode('$_proofPrefix|$myNonce|$theirNonce'), theirProof['signature'] as String? ?? '');
    if (!proven) {
      await _bye('badProof');
      return PeerResult(PeerStatus.invalidCredential);
    }

    // 3. ready
    await channel.send({'t': 'ready', 'holds': repository.heldListUuids});
    final ready = await inbox.receive('ready', timeout);
    final holds = {for (final uuid in (ready['holds'] as List? ?? const [])) uuid.toString()};

    // 4. offer
    final offer = repository.buildPeerOffer(peer, holds);
    await channel.send({'t': 'offer', ...offer});
    final sent = (offer['lists'] as List).length + (offer['items'] as List).length;

    final theirOffer = await inbox.receive('offer', timeout);
    final applied = await repository.applyPeerOffer(theirOffer, peer);

    // 5. done (the other may already have gone: that is fine)
    await channel.send({'t': 'done'});
    try {
      await inbox.receive('done', const Duration(seconds: 3));
    } catch (_) {}

    return PeerResult(PeerStatus.done, peerName: peer.name, sent: sent, applied: applied);
  }

  Future<void> _bye(String reason, [String? detail]) async {
    try {
      await channel.send({'t': 'bye', 'reason': reason, 'detail': ?detail});
    } catch (_) {}
  }

  static PeerStatus _statusOf(String reason) => switch (reason) {
        'version' => PeerStatus.versionMismatch,
        'differentFamily' => PeerStatus.differentFamily,
        'differentServer' => PeerStatus.differentServer,
        'expired' => PeerStatus.expired,
        'no_credential' => PeerStatus.noCredential,
        _ => PeerStatus.invalidCredential,
      };

  static PeerStatus _statusOfFailure(PeerFailure failure) => switch (failure) {
        PeerFailure.differentFamily => PeerStatus.differentFamily,
        PeerFailure.differentServer => PeerStatus.differentServer,
        PeerFailure.expired => PeerStatus.expired,
        _ => PeerStatus.invalidCredential,
      };
}

class _Bye implements Exception {
  _Bye(this.reason, this.detail);

  final String reason;
  final String? detail;
}

class _Disconnected implements Exception {}

class _Unexpected implements Exception {}

/// Messages that arrived, handed out in order to whoever waits for them.
class _Inbox {
  final _queue = <Map<String, dynamic>>[];
  final _waiting = <Completer<Map<String, dynamic>>>[];
  bool _closed = false;

  void add(Map<String, dynamic> message) {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete(message);
    } else {
      _queue.add(message);
    }
  }

  void close() {
    _closed = true;
    for (final waiter in _waiting) {
      waiter.completeError(_Disconnected());
    }
    _waiting.clear();
  }

  /// The next message, which must be of [type] (a "bye" from the other side ends everything).
  Future<Map<String, dynamic>> receive(String type, Duration timeout) async {
    final Map<String, dynamic> message;

    if (_queue.isNotEmpty) {
      message = _queue.removeAt(0);
    } else if (_closed) {
      throw _Disconnected();
    } else {
      final waiter = Completer<Map<String, dynamic>>();
      _waiting.add(waiter);
      message = await waiter.future.timeout(timeout, onTimeout: () {
        _waiting.remove(waiter);
        throw TimeoutException('no $type');
      });
    }

    if (message['t'] == 'bye') throw _Bye(message['reason']?.toString() ?? '', message['detail']?.toString());
    if (message['t'] != type) throw _Unexpected();

    return message;
  }
}

/// The meeting of two phones of a **local** family: no server, so no credential. What proves a
/// phone belongs is that it knows the connect code, shown without being told: each side answers
/// the other's challenge with a proof only the code makes. Then they compare what each holds and
/// swap only what the other lacks or has older (the same hello / proof / ready / offer / done).
///
/// Everyone in a local family may do everything: there are no rights to check.
class LocalPeerSession {
  LocalPeerSession({
    required this.key,
    required this.repository,
    required this.appVersion,
    required this.channel,
    this.displayName = '',
    this.familyName = '',
    this.onFamilyName,
    this.timeout = const Duration(seconds: 20),
  });

  final LocalFamilyKey key;
  final Repository repository;
  final String appVersion;
  final PeerChannel channel;
  final String displayName;
  final String familyName;

  /// Told the family's name when the other phone has one and this one does not yet.
  final Future<void> Function(String name)? onFamilyName;
  final Duration timeout;

  static const protocol = 1;

  Future<PeerResult> run() async {
    final inbox = _Inbox();
    final subscription = channel.messages.listen(inbox.add, onDone: inbox.close, onError: (_) => inbox.close());

    try {
      return await _meet(inbox);
    } on _Bye catch (bye) {
      return PeerResult(PeerSession._statusOf(bye.reason), theirVersion: bye.detail);
    } on TimeoutException {
      return PeerResult(PeerStatus.timeout);
    } on _Disconnected {
      return PeerResult(PeerStatus.disconnected);
    } on _Unexpected {
      return PeerResult(PeerStatus.protocol);
    } finally {
      await subscription.cancel();
    }
  }

  Future<PeerResult> _meet(_Inbox inbox) async {
    final random = Random.secure();
    final myNonce = base64.encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);

    // 1. hello
    await channel.send({
      't': 'hello',
      'protocol': protocol,
      'mode': 'local',
      'version': appVersion,
      'name': displayName,
      'family': familyName,
      'nonce': myNonce,
    });

    final hello = await inbox.receive('hello', timeout);
    final theirVersion = hello['version']?.toString();

    if (theirVersion != appVersion || hello['protocol'] != protocol) {
      await _bye('version', theirVersion);
      return PeerResult(PeerStatus.versionMismatch, theirVersion: theirVersion);
    }
    if (hello['mode'] != 'local') {
      await _bye('differentFamily');
      return PeerResult(PeerStatus.differentFamily);
    }

    final theirNonce = hello['nonce'] as String? ?? '';

    // 2. proof: each answers the other's challenge, which only the code makes possible
    await channel.send({'t': 'proof', 'mac': await key.prove('$theirNonce|$myNonce')});

    final theirProof = await inbox.receive('proof', timeout);
    if (theirProof['mac'] != await key.prove('$myNonce|$theirNonce')) {
      await _bye('badProof');
      return PeerResult(PeerStatus.invalidCredential);
    }

    // 3. ready: what each holds, in a few numbers
    await channel.send({'t': 'ready', 'digest': repository.buildLocalDigest()});
    final ready = await inbox.receive('ready', timeout);

    // 4. offer: only what the other lacks or has older
    final offer = repository.buildLocalDelta(asMap(ready['digest']));
    await channel.send({'t': 'offer', ...offer});
    final sent = (offer['lists'] as List).length + (offer['items'] as List).length + (offer['gone'] as List).length;

    final theirOffer = await inbox.receive('offer', timeout);
    final applied = await repository.applyLocalDelta(theirOffer);

    final theirFamily = hello['family']?.toString() ?? '';
    if (familyName.isEmpty && theirFamily.isNotEmpty) await onFamilyName?.call(theirFamily);

    // 5. done (the other may already have gone: that is fine)
    await channel.send({'t': 'done'});
    try {
      await inbox.receive('done', const Duration(seconds: 3));
    } catch (_) {}

    return PeerResult(PeerStatus.done, peerName: hello['name']?.toString(), sent: sent, applied: applied);
  }

  Future<void> _bye(String reason, [String? detail]) async {
    try {
      await channel.send({'t': 'bye', 'reason': reason, 'detail': ?detail});
    } catch (_) {}
  }
}
