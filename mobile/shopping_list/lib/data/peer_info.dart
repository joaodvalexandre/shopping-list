import '../core/time.dart';
import 'me.dart';

/// Who a phone nearby says it belongs to, and what its person may do: the contents of a
/// credential the server signed (see docs/api.md, "Nearby sync"). Only ever built from a
/// credential whose signature has been checked.
class PeerInfo {
  const PeerInfo({
    required this.userId,
    required this.familyId,
    required this.name,
    required this.role,
    required this.publicKey,
    required this.permissions,
    required this.expiresAt,
  });

  final int userId;
  final int familyId;
  final String name;
  final String role;

  /// The phone's own Ed25519 public key, which it proves it holds.
  final List<int> publicKey;
  final Map<int, Map<Ability, bool>> permissions;

  /// Unix seconds.
  final int expiresAt;

  /// Same rule as the app's own: any ability implies viewing.
  bool can(int listTypeId, Ability ability) {
    final abilities = permissions[listTypeId];
    if (abilities == null) return false;
    if (ability == Ability.view) return abilities.values.any((granted) => granted);
    return abilities[ability] ?? false;
  }

  static PeerInfo fromJson(Map<String, dynamic> json, List<int> publicKey) {
    final permissions = <int, Map<Ability, bool>>{};
    asMap(json['permissions']).forEach((typeId, abilities) {
      final map = asMap(abilities);
      permissions[int.parse(typeId)] = {for (final entry in abilityKeys.entries) entry.key: map[entry.value] == true};
    });

    return PeerInfo(
      userId: (json['user_id'] as num).toInt(),
      familyId: (json['family_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      publicKey: publicKey,
      permissions: permissions,
      expiresAt: (json['exp'] as num).toInt(),
    );
  }
}

/// How many lists and items a phone nearby changed here.
class PeerApplied {
  int lists = 0;
  int items = 0;

  int get total => lists + items;
}
