import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/time.dart';
import '../data/api_client.dart';
import '../data/local_db.dart';
import '../data/peer_info.dart';

/// Where the phone keeps its private key. The Android keystore in the app; memory in tests.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SecureSecretStore implements SecretStore {
  const SecureSecretStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null; // an unreadable keystore: start with a new key
    }
  }

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

/// Why a phone nearby could not be trusted.
enum PeerFailure { invalidCredential, expired, differentServer, differentFamily, badProof }

class PeerException implements Exception {
  PeerException(this.failure);

  final PeerFailure failure;

  @override
  String toString() => 'PeerException($failure)';
}

/// What a phone shows another: the server's signed statement about its person.
class PeerCredential {
  const PeerCredential({required this.credential, required this.signature, required this.serverKey, required this.fetchedAt});

  /// The exact text the server signed (JSON).
  final String credential;
  final String signature;
  final String serverKey;
  final int fetchedAt;

  Map<String, dynamic> toJson() => {'credential': credential, 'signature': signature, 'server_key': serverKey, 'fetched_at': fetchedAt};

  static PeerCredential fromJson(Map<String, dynamic> json) => PeerCredential(
        credential: json['credential'] as String,
        signature: json['signature'] as String,
        serverKey: json['server_key'] as String,
        fetchedAt: (json['fetched_at'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> get claims => jsonDecode(credential) as Map<String, dynamic>;
}

/// This phone's key pair and the credential the server signed for it, so that a family phone
/// nearby can tell who it is talking to without any help from the server.
///
/// The key pair never leaves the phone: the server only ever sees the public half, signs it into
/// a credential together with who the person is and what they may do, and the phone proves
/// it holds the private half by signing a challenge from the other side.
class PeerIdentity {
  PeerIdentity({required SecretStore secrets, required LocalStore store, int Function()? clock})
      : _secrets = secrets,
        _store = store,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  final SecretStore _secrets;
  final LocalStore _store;
  final int Function() _clock;
  final _algorithm = Ed25519();

  static const _seedKey = 'peer_key_seed';
  static const _credentialKey = 'peer_credential';

  /// A credential older than this is asked for again whenever the server can be reached.
  static const refreshAfter = Duration(hours: 6);

  SimpleKeyPair? _pair;

  Future<SimpleKeyPair> _keys() async {
    if (_pair != null) return _pair!;

    var seed = await _secrets.read(_seedKey);
    if (seed == null) {
      final random = Random.secure();
      seed = base64.encode([for (var i = 0; i < 32; i++) random.nextInt(256)]);
      await _secrets.write(_seedKey, seed);
    }

    return _pair = await _algorithm.newKeyPairFromSeed(base64.decode(seed));
  }

  Future<List<int>> publicKey() async => (await (await _keys()).extractPublicKey()).bytes;

  Future<List<int>> sign(List<int> message) async => (await _algorithm.sign(message, keyPair: await _keys())).bytes;

  /// The credential this phone shows, if it has one that is still valid.
  Future<PeerCredential?> credential() async {
    final raw = await _store.getMeta(_credentialKey);
    if (raw == null) return null;

    final stored = PeerCredential.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return (stored.claims['exp'] as num).toInt() > _clock() ? stored : null;
  }

  /// A short tag of this phone's family, shown in the name the phone advertises so that phones of
  /// other families are not even connected to. Not a secret (anyone can tell who is in the same
  /// group) and not a proof: the signed credential still decides who is trusted.
  Future<String?> familyTag() async {
    final mine = await credential();
    if (mine == null) return null;

    final digest = await Sha256().hash(utf8.encode('cestou-family|${mine.serverKey}|${mine.claims['family_id']}'));
    return digest.bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Ask the server for a fresh credential (when it is missing, expiring or stale). Quiet
  /// when the server cannot be reached: the one held, if any, stays in use.
  Future<void> refresh(ApiClient api, {bool force = false}) async {
    final held = await _store.getMeta(_credentialKey);
    if (!force && held != null) {
      final fetchedAt = PeerCredential.fromJson(jsonDecode(held) as Map<String, dynamic>).fetchedAt;
      if (_clock() - fetchedAt < refreshAfter.inSeconds) return;
    }

    try {
      final json = await api.peerCredential(base64.encode(await publicKey()));
      final fresh = PeerCredential(
        credential: json['credential'] as String,
        signature: json['signature'] as String,
        serverKey: json['server_key'] as String,
        fetchedAt: _clock(),
      );
      await _store.setMeta(_credentialKey, jsonEncode(fresh.toJson()));
    } on ApiException {
      // offline, or not allowed yet: keep what there is
    }
  }

  /// Check a credential another phone showed: signed by this phone's own server, still
  /// valid, and for a person of the same family. Returns who it says they are.
  Future<PeerInfo> verify({required String credential, required String signature, required String serverKey}) async {
    final mine = await this.credential();
    if (mine == null) throw PeerException(PeerFailure.invalidCredential);
    if (serverKey != mine.serverKey) throw PeerException(PeerFailure.differentServer);

    final bool signedByServer;
    try {
      signedByServer = await _algorithm.verify(
        utf8.encode(credential),
        signature: Signature(base64.decode(signature), publicKey: SimplePublicKey(base64.decode(serverKey), type: KeyPairType.ed25519)),
      );
    } catch (_) {
      throw PeerException(PeerFailure.invalidCredential);
    }
    if (!signedByServer) throw PeerException(PeerFailure.invalidCredential);

    final Map<String, dynamic> claims;
    try {
      claims = asMap(jsonDecode(credential));
    } catch (_) {
      throw PeerException(PeerFailure.invalidCredential);
    }

    if (claims['v'] != 1 || claims['key'] is! String) throw PeerException(PeerFailure.invalidCredential);
    if ((claims['exp'] as num?)?.toInt() == null || (claims['exp'] as num).toInt() <= _clock()) throw PeerException(PeerFailure.expired);
    if (claims['family_id'] != mine.claims['family_id']) throw PeerException(PeerFailure.differentFamily);

    return PeerInfo.fromJson(claims, base64.decode(claims['key'] as String));
  }

  /// Check that the phone holds the key its credential names: it signed [message].
  Future<bool> verifyProof(PeerInfo peer, List<int> message, String signature) async {
    try {
      return await _algorithm.verify(
        message,
        signature: Signature(base64.decode(signature), publicKey: SimplePublicKey(peer.publicKey, type: KeyPairType.ed25519)),
      );
    } catch (_) {
      return false;
    }
  }
}
