import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../data/local_db.dart';

/// A family that exists only on its phones: never created on the server, never talked about
/// to it. What makes phones one family is a connect code that is told from one person to another.
class LocalFamily {
  const LocalFamily({required this.code, required this.familyName, required this.myName, required this.memberId});

  /// Twelve letters and digits, as written by [LocalFamilyCodes.normalise].
  final String code;

  /// Empty on a phone that joined by code, until a phone nearby tells it.
  final String familyName;
  final String myName;
  final String memberId;

  LocalFamily copyWith({String? familyName}) =>
      LocalFamily(code: code, familyName: familyName ?? this.familyName, myName: myName, memberId: memberId);

  Map<String, dynamic> toJson() => {'code': code, 'family_name': familyName, 'my_name': myName, 'member_id': memberId};

  static LocalFamily fromJson(Map<String, dynamic> json) => LocalFamily(
        code: json['code'] as String,
        familyName: json['family_name'] as String? ?? '',
        myName: json['my_name'] as String? ?? '',
        memberId: json['member_id'] as String? ?? '',
      );
}

class LocalFamilyCodes {
  /// No I, O, 0 or 1: they are mistaken for each other when a code is read out or typed.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 12;

  /// 60 bits of randomness: nobody guesses it, even trying all day with a phone next door.
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    return [for (var i = 0; i < length; i++) _alphabet[rng.nextInt(_alphabet.length)]].join();
  }

  /// What the person typed (any case, with spaces or dashes) as a code, or null when it cannot be one.
  static String? normalise(String input) {
    final code = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (code.length != length) return null;
    if (code.split('').any((c) => !_alphabet.contains(c))) return null;
    return code;
  }

  /// `ABCD-EFGH-JKLM`, for reading and telling.
  static String format(String code) => [for (var i = 0; i < code.length; i += 4) code.substring(i, min(i + 4, code.length))].join('-');
}

/// What a connect code turns into: the key behind the short tag phones show each other, and
/// the proof that a phone knows the code without telling it.
class LocalFamilyKey {
  LocalFamilyKey._(this._key);

  final SecretKey _key;

  static final _hmac = Hmac.sha256();

  /// Slowed down on purpose, so that the tag (which any phone nearby can read) is no help in finding the code.
  static Future<LocalFamilyKey> derive(String code) async {
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 20000, bits: 256)
        .deriveKeyFromPassword(password: code, nonce: utf8.encode('cestou-local-family-v1'));
    return LocalFamilyKey._(key);
  }

  Future<List<int>> _mac(String message) async => (await _hmac.calculateMac(utf8.encode(message), secretKey: _key)).bytes;

  /// Four bytes, hex: phones with another one are not even connected to.
  Future<String> tag() async => (await _mac('tag')).take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Future<String> prove(String message) async => base64.encode(await _mac('proof|$message'));
}

/// Where this phone keeps which local family it belongs to (nothing, for a phone that uses the server).
class LocalFamilyStore {
  LocalFamilyStore(this._db);

  final LocalStore _db;

  static const metaKey = 'local_family';

  LocalFamily? _current;
  bool _loaded = false;

  /// What [current] found, for screens that cannot wait for it (it is loaded when the app starts).
  LocalFamily? get currentSync => _current;

  Future<LocalFamily?> current() async {
    if (!_loaded) {
      final raw = await _db.getMeta(metaKey);
      _current = raw == null ? null : LocalFamily.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _loaded = true;
    }
    return _current;
  }

  /// A new family, with a code of its own to give to the others.
  Future<LocalFamily> create({required String myName, required String familyName}) =>
      _save(LocalFamily(code: LocalFamilyCodes.generate(), familyName: familyName.trim(), myName: myName.trim(), memberId: const Uuid().v4()));

  /// An existing family, by its code. Throws [FormatException] when [code] cannot be one.
  Future<LocalFamily> join({required String myName, required String code}) {
    final normalised = LocalFamilyCodes.normalise(code);
    if (normalised == null) throw const FormatException('not a connect code');

    return _save(LocalFamily(code: normalised, familyName: '', myName: myName.trim(), memberId: const Uuid().v4()));
  }

  /// A phone that joined learns the family's name from the first phone it meets.
  Future<LocalFamily?> adoptFamilyName(String name) async {
    final family = await current();
    if (family == null || family.familyName.isNotEmpty || name.trim().isEmpty) return family;

    return _save(family.copyWith(familyName: name.trim()));
  }

  Future<void> clear() async {
    _current = null;
    _loaded = true;
    await _db.setMeta(metaKey, null);
  }

  Future<LocalFamily> _save(LocalFamily family) async {
    await _db.setMeta(metaKey, jsonEncode(family.toJson()));
    _current = family;
    _loaded = true;
    return family;
  }
}
