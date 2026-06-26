import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/search/screens/search_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  testWidgets('SearchScreen renders search tabs without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SearchScreen())),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Hashtags'), findsOneWidget);
  });
}
