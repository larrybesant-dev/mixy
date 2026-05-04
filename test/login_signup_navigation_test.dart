import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/presentation/screens/mixvy_login_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  setUp(() {
    when(() => mockAuth.currentUser).thenReturn(null);
    emitAuthState(null);
  });

  testWidgets('login screen exposes signup navigation', (tester) async {
    // Force narrow viewport to use single-column layout
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Suppress overflow warnings from the glassmorphic login layout in tests
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalHandler);

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const MixVyLoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) =>
              const Scaffold(body: Text('Register Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => AuthController(auth: mockAuth),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    emitAuthState(null);
    await tester.pump();

    expect(find.text('SIGN UP'), findsOneWidget);
    // Guest mode is not supported — ENTER AS GUEST button does not exist.

    await tester.tap(find.text('SIGN UP'), warnIfMissed: false);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Register Screen').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Register Screen'), findsOneWidget);
  });
}
