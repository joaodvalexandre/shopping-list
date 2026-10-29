import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/family.dart';
import 'package:shopping_list/data/me.dart';

void main() {
  test('reads the family as the API sends it', () {
    final data = FamilyData.fromJson({
      'members': [
        {
          'id': 2,
          'name': 'Bia',
          'email': 'bia@example.com',
          'role': 'member',
          'must_change_password': true,
          'permissions': {
            '7': {'can_view': true, 'can_add_items': true, 'can_edit_items': false, 'can_change_status': true, 'can_manage_lists': false},
          },
        },
        {'id': 1, 'name': 'Joana', 'email': 'joana@example.com', 'role': 'admin', 'must_change_password': false, 'permissions': []},
      ],
      'list_types': [
        {'id': 7, 'name': 'Groceries', 'lists_count': 3},
      ],
    });

    final bia = data.members.first;
    expect(bia.isAdmin, isFalse);
    expect(bia.mustChangePassword, isTrue);
    expect(bia.can(7, Ability.addItems), isTrue);
    expect(bia.can(7, Ability.editItems), isFalse);
    expect(bia.can(8, Ability.view), isFalse);   // a type she has nothing on

    // PHP encodes "no permissions" as an empty list, not an object
    expect(data.members.last.isAdmin, isTrue);
    expect(data.members.last.permissions, isEmpty);

    expect(data.listTypes.single.name, 'Groceries');
    expect(data.listTypes.single.listsCount, 3);
  });

  test('a member form sends each list type its abilities, and an admin none', () {
    final member = memberPayload(
      name: ' Bia ',
      email: ' bia@example.com ',
      role: 'member',
      permissions: {
        7: {for (final ability in Ability.values) ability: ability == Ability.view || ability == Ability.addItems},
      },
    );

    expect(member['name'], 'Bia');
    expect(member['email'], 'bia@example.com');
    expect(member['permissions'], {
      '7': {'can_view': true, 'can_add_items': true, 'can_edit_items': false, 'can_change_status': false, 'can_manage_lists': false},
    });

    final admin = memberPayload(name: 'Joana', email: 'j@example.com', role: 'admin', permissions: {7: {Ability.view: true}});
    expect(admin.containsKey('permissions'), isFalse);
  });
}
