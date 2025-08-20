// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopping_list/main.dart';
import 'package:shopping_list/services/shopping_lists_service.dart';

void main() {
  testWidgets('Shopping lists app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => ShoppingListsService(),
        child: const ShoppingListApp(),
      ),
    );

    // Verify that the app title is displayed
    expect(find.text('Shopping Lists'), findsOneWidget);
    
    // Verify that the add button is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
