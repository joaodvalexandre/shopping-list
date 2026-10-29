import '../core/time.dart';
import 'me.dart';

/// A member of the family, as a family admin sees them.
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.mustChangePassword,
    required this.permissions,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final bool mustChangePassword;

  /// What they may do per list type; a type they have nothing on is absent.
  final Map<int, Map<Ability, bool>> permissions;

  bool get isAdmin => role == 'admin';

  bool can(int listTypeId, Ability ability) => permissions[listTypeId]?[ability] ?? false;

  static FamilyMember fromJson(Map<String, dynamic> json) {
    final permissions = <int, Map<Ability, bool>>{};
    asMap(json['permissions']).forEach((typeId, abilities) {
      final map = asMap(abilities);
      permissions[int.parse(typeId)] = {for (final entry in abilityKeys.entries) entry.key: map[entry.value] == true};
    });

    return FamilyMember(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'member',
      mustChangePassword: json['must_change_password'] == true,
      permissions: permissions,
    );
  }
}

class FamilyListType {
  const FamilyListType({required this.id, required this.name, required this.listsCount});

  final int id;
  final String name;
  final int listsCount;

  static FamilyListType fromJson(Map<String, dynamic> json) => FamilyListType(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        listsCount: (json['lists_count'] as num?)?.toInt() ?? 0,
      );
}

/// The family's members and list types.
class FamilyData {
  const FamilyData({required this.members, required this.listTypes});

  final List<FamilyMember> members;
  final List<FamilyListType> listTypes;

  static FamilyData fromJson(Map<String, dynamic> json) => FamilyData(
        members: [for (final m in (json['members'] as List? ?? const [])) FamilyMember.fromJson(asMap(m))],
        listTypes: [for (final t in (json['list_types'] as List? ?? const [])) FamilyListType.fromJson(asMap(t))],
      );
}

/// What a member form sends: the name, email, role and, for a plain member, each list type's abilities.
Map<String, dynamic> memberPayload({
  required String name,
  required String email,
  required String role,
  required Map<int, Map<Ability, bool>> permissions,
}) =>
    {
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      if (role != 'admin')
        'permissions': {
          for (final type in permissions.entries)
            '${type.key}': {for (final ability in type.value.entries) abilityKeys[ability.key]!: ability.value},
        },
    };
