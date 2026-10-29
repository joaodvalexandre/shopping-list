import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/data/names.dart';

void main() {
  test('a person is shown with the family name after their own', () {
    expect(withFamilyName('João', 'Alexandre'), 'João Alexandre');
    expect(withFamilyName('  Ana ', ' Silva '), 'Ana Silva');
  });

  test('nothing is added when there is no family name, or it is already there', () {
    expect(withFamilyName('João', ''), 'João');
    expect(withFamilyName('João Alexandre', 'Alexandre'), 'João Alexandre');
    expect(withFamilyName('alexandre', 'Alexandre'), 'alexandre');
    expect(withFamilyName('', 'Alexandre'), '');
  });
}
