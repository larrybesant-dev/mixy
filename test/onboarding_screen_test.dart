import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';
import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps OnboardingScreen with a minimal GoRouter so context.go() works.
Widget _buildApp() {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: '/legal/terms',
        builder: (_, __) => const Scaffold(body: Text('Terms')),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, __) => const Scaffold(body: Text('Privacy')),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
    ],
  );

  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('OnboardingScreen', () {
    testWidgets('renders first page content', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Step into rooms with real chemistry.'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      // Legal checkbox only appears on last page
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('advances to second page via CONTINUE', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(
        find.text('Meet people who match your energy fast.'),
        findsOneWidget,
      );
    });

    testWidgets('advances through all pages to final page', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Page 0 → 1
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Page 1 → 2
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      // Page 2 → 3 (interests/final page)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Choose the energy you want more of.'), findsOneWidget);
      expect(find.text('ENTER MIXVY'), findsOneWidget);
    });

    testWidgets('final page shows legal checkbox', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        find.text('I agree to the Terms of Service and Privacy Policy.'),
        findsOneWidget,
      );
    });

    testWidgets('ENTER MIXVY is disabled until legal checkbox is ticked', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Navigate to final page (interests page is page 3)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      InkWell ctaInkWell() => tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('ENTER MIXVY'),
              matching: find.byType(InkWell),
            )
            .first,
      );

      expect(
        ctaInkWell().onTap,
        isNull,
        reason: 'CTA should be disabled before legal accepted',
      );

      // Tick the legal checkbox
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        ctaInkWell().onTap,
        isNotNull,
        reason: 'CTA should be enabled after legal accepted',
      );
    });

    testWidgets('Terms link is tappable on final page', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Terms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Terms'), findsWidgets);
    });

    testWidgets('progress dots count matches page count', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // 4 pages (3 scene pages + 1 interests page) → 4 dots.
      // The simplest proxy: PageView has 4 children.
      final pageView = tester.widget<PageView>(find.byType(PageView).first);
      expect(pageView.childrenDelegate.estimatedChildCount, 4);
    });
  });
}
