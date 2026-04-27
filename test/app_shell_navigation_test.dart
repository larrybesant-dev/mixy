import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/messaging/providers/messaging_provider.dart';
import 'package:mixvy/shared/widgets/app_shell.dart';
import 'package:mixvy/shared/widgets/messenger_shell_route.dart';

void main() {
  testWidgets('AppShell renders simplified shell with bottom nav', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unreadmessageCountProvider.overrideWith((ref) => 0)],
        child: const MaterialApp(
          home: AppShell(selectedIndex: 0, child: SizedBox.expand()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Live Rooms'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('AppShell switches selected tab via bottom nav taps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unreadmessageCountProvider.overrideWith((ref) => 0)],
        child: const MaterialApp(
          home: AppShell(selectedIndex: 0, child: SizedBox.expand()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsWidgets);

    await tester.tap(find.text('Live Rooms'));
    await tester.pumpAndSettle();
    expect(find.text('Live Rooms'), findsWidgets);
  });

  testWidgets('Messenger routes accept concrete conversation URLs', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/messages/conversation-123',
      routes: [
        GoRoute(
          path: '/messages/:conversationId',
          builder: (context, state) {
            final routeState = MessengerRouteState.fromGoRouterState(state);
            return Material(
              child: Text(routeState.conversationId ?? 'missing'),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('conversation-123'), findsOneWidget);
  });
}
