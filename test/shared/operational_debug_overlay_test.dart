import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/shared/widgets/operational_debug_overlay.dart';

void main() {
  testWidgets('operational overlay opens via hidden tap sequence', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OperationalDebugOverlay(
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final trigger = find.byType(GestureDetector).first;

    for (var i = 0; i < 6; i += 1) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('Operational Debug'), findsOneWidget);
    expect(find.textContaining('Version:'), findsOneWidget);
    expect(find.textContaining('Environment:'), findsOneWidget);
    expect(find.textContaining('User:'), findsOneWidget);
    expect(find.text('Last Error'), findsOneWidget);
  });
}
