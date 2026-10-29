import '../core/time.dart';

/// What the signed-in person may do with a list type (the API's `permissions`).
enum Ability { view, addItems, editItems, changeStatus, manageLists }

/// The API's name for each ability, in the order the screens show them.
const abilityKeys = {
  Ability.view: 'can_view',
  Ability.addItems: 'can_add_items',
  Ability.editItems: 'can_edit_items',
  Ability.changeStatus: 'can_change_status',
  Ability.manageLists: 'can_manage_lists',
};

class Me {
  Me({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.mustChangePassword,
    required this.familyName,
    required this.listTypes,
    required this.permissions,
    required this.members,
  });

  final int userId;
  final String name;
  final String email;
  final String role;
  final bool mustChangePassword;
  final String familyName;
  final Map<int, String> listTypes;
  final Map<int, Map<Ability, bool>> permissions;

  /// Other family members (id and name); only filled for people who manage lists.
  final List<({int id, String name})> members;

  bool get isAdmin => role == 'admin';

  /// Same rule as the web app: any ability implies viewing.
  bool can(int listTypeId, Ability ability) {
    final abilities = permissions[listTypeId];
    if (abilities == null) return false;
    if (ability == Ability.view) return abilities.values.any((granted) => granted);
    return abilities[ability] ?? false;
  }

  /// List types in which this person may create and manage lists.
  List<int> get manageableTypeIds =>
      listTypes.keys.where((id) => can(id, Ability.manageLists)).toList()..sort();

  bool get canCreateLists => manageableTypeIds.isNotEmpty;

  static Me fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    final family = asMap(json['family']);

    final types = <int, String>{
      for (final type in (json['list_types'] as List? ?? const []))
        (type['id'] as num).toInt(): type['name'] as String,
    };

    final permissions = <int, Map<Ability, bool>>{};
    asMap(json['permissions']).forEach((typeId, abilities) {
      final map = asMap(abilities);
      permissions[int.parse(typeId)] = {
        for (final entry in abilityKeys.entries) entry.key: map[entry.value] == true,
      };
    });

    return Me(
      userId: (user['id'] as num).toInt(),
      name: user['name'] as String,
      email: user['email'] as String,
      role: user['role'] as String? ?? 'member',
      mustChangePassword: user['must_change_password'] == true,
      familyName: family['name'] as String? ?? '',
      listTypes: types,
      permissions: permissions,
      members: [
        for (final member in (json['members'] as List? ?? const []))
          (id: (member['id'] as num).toInt(), name: member['name'] as String),
      ],
    );
  }
}
