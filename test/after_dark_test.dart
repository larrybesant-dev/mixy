import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/after_dark/providers/after_dark_provider.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_age_gate_screen.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_pin_screen.dart';
import 'package:mixvy/features/after_dark/widgets/after_dark_shell.dart';
import 'package:mixvy/features/messaging/providers/messaging_provider.dart';

import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _ageGateApp() {
  final router = GoRouter(
    initialLocation: '/after-dark/age-gate',
    routes: [
      GoRoute(
        path: '/after-dark/age-gate',
        builder: (_, __) => const AfterDarkAgeGateScreen(),
      ),
      GoRoute(
        path: '/after-dark/pin-setup',
        builder: (_, __) => const Scaffold(body: Text('Pin Setup')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

Widget _pinSetupApp() {
  final router = GoRouter(
    initialLocation: '/after-dark/pin-setup',
    routes: [
      GoRoute(
        path: '/after-dark/pin-setup',
        builder: (_, __) => const AfterDarkPinScreen.setup(),
      ),
      GoRoute(
        path: '/after-dark',
        builder: (_, __) => const Scaffold(body: Text('After Dark Home')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

Widget _pinUnlockApp() {
  final router = GoRouter(
    initialLocation: '/after-dark/unlock',
    routes: [
      GoRoute(
        path: '/after-dark/unlock',
        builder: (_, __) => const AfterDarkPinScreen.unlock(),
      ),
      GoRoute(
        path: '/after-dark',
        builder: (_, __) => const Scaffold(body: Text('After Dark Home')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

Widget _shellApp({required bool sessionActive}) {
  final router = GoRouter(
    initialLocation: '/after-dark',
    routes: [
      ShellRoute(
        builder: (_, __, child) => AfterDarkShell(child: child),
        routes: [
          GoRoute(
            path: '/after-dark',
            builder: (_, __) => const Scaffold(body: Text('After Dark Home')),
          ),
          GoRoute(
            path: '/after-dark/lounges',
            builder: (_, __) => const Scaffold(body: Text('Lounges')),
          ),
          GoRoute(
            path: '/after-dark/profile',
            builder: (_, __) => const Scaffold(body: Text('AD Profile')),
          ),
        ],
      ),
      GoRoute(
        path: '/after-dark/unlock',
        builder: (_, __) => const Scaffold(body: Text('Unlock')),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Main App')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      afterDarkSessionProvider.overrideWith((ref) => sessionActive),
      // Prevent Firebase access in the shell test environment.
      unreadMessageCountProvider.overrideWith((ref) => 0),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await testSetup();
  });

  // ── Age Gate ──────────────────────────────────────────────────────────────
  group('AfterDarkAgeGateScreen', () {
    testWidgets('renders title and input', (tester) async {
      await tester.pumpWidget(_ageGateApp());
      await tester.pumpAndSettle();

      expect(find.text('MixVy After Dark'), findsOneWidget);
      // DOB input field
      expect(find.byType(TextField), findsOneWidget);
      // Consent checkbox inside CheckboxListTile
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('shows error for invalid date format', (tester) async {
      await tester.pumpWidget(_ageGateApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not-a-date');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.textContaining('valid date'), findsOneWidget);
    });

    testWidgets('shows under-18 error for young DOB', (tester) async {
      await tester.pumpWidget(_ageGateApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '2015-01-01');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.textContaining('18 or older'), findsOneWidget);
    });

    testWidgets('shows consent error when checkbox not ticked', (tester) async {
      await tester.pumpWidget(_ageGateApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1990-01-01');
      // Do NOT tick the checkbox.
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.textContaining('must agree'), findsOneWidget);
    });

    testWidgets('valid adult + consent navigates to pin-setup', (tester) async {
      await tester.pumpWidget(_ageGateApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1990-06-15');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Pin Setup'), findsOneWidget);
    });
  });

  // ── AfterDarkController unit tests ────────────────────────────────────────
  group('AfterDarkController', () {
    test('unlock returns false when no PIN has been stored', () async {
      // Fresh container — SharedPreferences is empty via testSetup mock.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(afterDarkControllerProvider);

      final result = await controller.unlock('1234');
      expect(result, isFalse);
    });

    test('session is false by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(afterDarkSessionProvider), isFalse);
    });

    test('lock() sets session to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(afterDarkSessionProvider.notifier).state = true;
      container.read(afterDarkControllerProvider).lock();
      expect(container.read(afterDarkSessionProvider), isFalse);
    });
  });

  // ── PIN Screen (setup) ────────────────────────────────────────────────────
  group('AfterDarkPinScreen setup mode', () {
    testWidgets('renders create PIN title', (tester) async {
      await tester.pumpWidget(_pinSetupApp());
      await tester.pumpAndSettle();

      expect(find.text('Create a PIN'), findsOneWidget);
    });

    testWidgets('entering 4 digits advances to confirm step', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_pinSetupApp());
      await tester.pumpAndSettle();

      // Tap digit buttons 1, 2, 3, 4
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d).first);
        await tester.pump();
      }

      await tester.pumpAndSettle();
      expect(find.text('Confirm PIN'), findsOneWidget);
    });

    testWidgets('mismatch PIN shows error and resets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_pinSetupApp());
      await tester.pumpAndSettle();

      // First PIN: 1234
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d).first);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Confirm with different PIN: 4321
      for (final d in ['4', '3', '2', '1']) {
        await tester.tap(find.text(d).first);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('do not match'), findsOneWidget);
      // Resets to first-entry mode
      expect(find.text('Create a PIN'), findsOneWidget);
    });
  });

  // ── PIN Screen (unlock) ───────────────────────────────────────────────────
  group('AfterDarkPinScreen unlock mode', () {
    testWidgets('renders enter PIN title', (tester) async {
      await tester.pumpWidget(_pinUnlockApp());
      await tester.pumpAndSettle();

      expect(find.text('Enter PIN'), findsOneWidget);
    });

    testWidgets('delete button (backspace icon) is present', (tester) async {
      await tester.pumpWidget(_pinUnlockApp());
      await tester.pumpAndSettle();

      // The keypad renders the delete key as an Icon widget
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('entering a digit keeps title as Enter PIN before 4 digits', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_pinUnlockApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();

      // Only 1 digit — should not navigate away
      expect(find.text('Enter PIN'), findsOneWidget);
    });
  });

  // ── AfterDarkShell guard ──────────────────────────────────────────────────
  group('AfterDarkShell', () {
    testWidgets('redirects to unlock when session is inactive', (tester) async {
      await tester.pumpWidget(_shellApp(sessionActive: false));
      await tester.pumpAndSettle();

      // Should redirect to the unlock screen
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('After Dark Home'), findsNothing);
    });

    testWidgets('renders content when session is active', (tester) async {
      await tester.pumpWidget(_shellApp(sessionActive: true));
      await tester.pumpAndSettle();

      expect(find.text('After Dark Home'), findsOneWidget);
    });

    testWidgets('shows After Dark branding in app bar', (tester) async {
      await tester.pumpWidget(_shellApp(sessionActive: true));
      await tester.pumpAndSettle();

      expect(find.text('After Dark'), findsOneWidget);
    });

    testWidgets('Exit button is present in app bar', (tester) async {
      await tester.pumpWidget(_shellApp(sessionActive: true));
      await tester.pumpAndSettle();

      // The exit control is a TextButton.icon; verify via the icon or
      // the tooltip message attached to the wrapping Tooltip widget.
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    });
  });
}
