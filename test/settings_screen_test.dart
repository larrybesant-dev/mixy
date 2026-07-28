import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  testWidgets('SettingsScreen renders persisted preferences', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app.theme_mode': 'dark',
      'app.notifications_enabled': false,
      'app.analytics_enabled': true,
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.text('Settings'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Appearance'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Anonymous analytics'), findsNothing);

    expect(find.text('Dark'), findsOneWidget);
  });
}
