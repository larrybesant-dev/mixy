import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/widgets/room_panel_layout.dart';

void main() {
  group('RoomPanelLayout Widget Tests', () {
    testWidgets('renders desktop layout for wide screens', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RoomPanelLayout(
                camPanel: Text('Cam Panel'),
                chatPanel: Text('Chat Panel'),
                usersPanel: Text('Users Panel'),
                overlays: [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Camera Windows'), findsOneWidget);
      expect(find.text('Room Chat'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      
      // Reset physical size for other tests
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('renders mobile layout for narrow screens', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RoomPanelLayout(
                camPanel: Text('Cam Panel'),
                chatPanel: Text('Chat Panel'),
                usersPanel: Text('Users Panel'),
                overlays: [],
              ),
            ),
          ),
        ),
      );

      // In mobile, we use IndexedStack, so panels might be present but only one visible.
      // But we check for the bottom nav labels.
      expect(find.text('Cams'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('handles extreme small screen size', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(10, 10);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RoomPanelLayout(
                camPanel: Text('C'),
                chatPanel: Text('Ch'),
                usersPanel: Text('U'),
                overlays: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
