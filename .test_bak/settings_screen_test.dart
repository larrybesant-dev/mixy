import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SettingsScreen renders persisted preferences', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app.theme_mode': 'dark',
      'app.notifications_enabled': false,
      'app.analytics_enabled': true,
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Anonymous analytics'), findsNothing);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(1));
    expect(switches[0].value, isFalse);
    expect(find.text('Dark'), findsOneWidget);
  });
}










