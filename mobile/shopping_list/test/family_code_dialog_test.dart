import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/data/content.dart';
import 'package:shopping_list/state/content_service.dart';
import 'package:shopping_list/state/settings_state.dart';
import 'package:shopping_list/ui/screens/offline_start_screen.dart';

import 'support/memory_store.dart';

void main() {
  testWidgets('the family code dialog draws the QR code and the code', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final content = ContentService(
      MemoryStore(),
      ContentSnapshot.fromJson({
        'version': 'v1',
        'languages': [
          {'code': 'en', 'name': 'English', 'native_name': 'English', 'is_default': true},
        ],
        'texts': {'en': {'app_offline_code_title': 'Family code', 'app_offline_done': 'Done'}},
      }),
    );
    final settings = SettingsState(prefs, content);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => showFamilyCode(context, 'ABCDEFGHJKLM', 'Silva'), child: const Text('open')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Family code'), findsOneWidget);
    expect(find.textContaining('ABCD'), findsOneWidget);
  });
}
