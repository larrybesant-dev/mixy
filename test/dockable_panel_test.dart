import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/widgets/dockable_panel.dart';

void main() {
  group('DockablePanel Widget Tests', () {
    testWidgets('minimizes and restores on double tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DockablePanel(
              title: 'Test Panel',
              child: Text('Panel Content'),
            ),
          ),
        ),
      );

      expect(find.text('Panel Content'), findsOneWidget);

      // Double tap title bar
      await tester.tap(find.text('Test Panel'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Test Panel'));
      await tester.pumpAndSettle();

      expect(find.text('Panel Content'), findsNothing);

      // Restore
      await tester.tap(find.text('Test Panel'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Test Panel'));
      await tester.pumpAndSettle();

      expect(find.text('Panel Content'), findsOneWidget);
    });
  });

  group('FloatingDockablePanel Widget Tests', () {
    testWidgets('can be dragged to new position', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingDockablePanel(
                  title: 'Floating Panel',
                  initialOffset: const Offset(10, 10),
                  child: Container(),
                ),
              ],
            ),
          ),
        ),
      );

      final initialPos = tester.getTopLeft(find.text('Floating Panel'));
      expect(initialPos.dx, closeTo(10 + 24, 1.0)); // +24 for drag handle/icon spacing

      // Drag title bar
      await tester.drag(find.text('Floating Panel'), const Offset(50, 50));
      await tester.pump();

      final newPos = tester.getTopLeft(find.text('Floating Panel'));
      expect(newPos.dx, closeTo(60 + 24, 1.0));
    });

    testWidgets('can be resized via handle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingDockablePanel(
                  title: 'Resizable Panel',
                  width: 300,
                  height: 200,
                  child: Container(),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(FloatingDockablePanel)).width, 300);

      // Find resize handle (bottom-right)
      final handleFinder = find.byIcon(Icons.south_east);
      await tester.drag(handleFinder, const Offset(100, 100));
      await tester.pump();

      expect(tester.getSize(find.byType(FloatingDockablePanel)).width, 400);
      expect(tester.getSize(find.byType(FloatingDockablePanel)).height, 300);
    });

    testWidgets('guards against non-finite dimensions', (WidgetTester tester) async {
       // This test confirms that my hardening logic prevents crashes 
       // even if someone tries to pass crazy values.
       await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingDockablePanel(
                  title: 'Ghost Panel',
                  width: double.infinity,
                  height: double.nan,
                  child: Container(),
                ),
              ],
            ),
          ),
        ),
      );

      // Should render fallback size rather than crashing
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FloatingDockablePanel)).width, 320.0); // Fallback in code
    });
  });
}
