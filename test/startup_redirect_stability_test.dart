import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/routing/redirect_logic.dart';

enum _TestAuthBootstrapPhase { authenticatedStable, unauthenticatedStable }

extension on _TestAuthBootstrapPhase {
  bool get isRoutingStable =>
      this == _TestAuthBootstrapPhase.authenticatedStable ||
      this == _TestAuthBootstrapPhase.unauthenticatedStable;
}

class _RedirectHarness extends ChangeNotifier {
  _RedirectHarness({
    required this.uid,
    required this.phase,
    required this.legalStateResolved,
    required this.hasAcceptedLegal,
  });

  String? uid;
  _TestAuthBootstrapPhase phase;
  bool legalStateResolved;
  bool hasAcceptedLegal;

  bool get isRoutingStable => phase.isRoutingStable;

  void setState({
    String? uid,
    _TestAuthBootstrapPhase? phase,
    bool? legalStateResolved,
    bool? hasAcceptedLegal,
  }) {
    this.uid = uid ?? this.uid;
    this.phase = phase ?? this.phase;
    this.legalStateResolved = legalStateResolved ?? this.legalStateResolved;
    this.hasAcceptedLegal = hasAcceptedLegal ?? this.hasAcceptedLegal;
    notifyListeners();
  }
}

Future<void> _waitForAuthStable(
  WidgetTester tester,
  _RedirectHarness state,
) async {
  while (!state.isRoutingStable) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  group('startup redirect stability', () {
    testWidgets(
      'holds current route while legal state is unknown for signed-in users',
      (tester) async {
        final state = _RedirectHarness(
          uid: 'user-1',
          phase: _TestAuthBootstrapPhase.authenticatedStable,
          legalStateResolved: false,
          hasAcceptedLegal: false,
        );

        final router = GoRouter(
          initialLocation: '/home',
          refreshListenable: state,
          redirect: (context, routerState) {
            return evaluateAppRedirect(
              matchedLocation: routerState.matchedLocation,
              uid: state.uid,
              authLoading: !state.isRoutingStable,
              legalStateResolved: state.legalStateResolved,
              hasAcceptedLegal: state.hasAcceptedLegal,
            );
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home Screen')),
            ),
            GoRoute(
              path: '/onboarding',
              builder: (_, _) =>
                  const Scaffold(body: Text('Onboarding Screen')),
            ),
            GoRoute(
              path: '/auth',
              builder: (_, _) => const Scaffold(body: Text('Auth Screen')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _waitForAuthStable(tester, state);

        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Onboarding Screen'), findsNothing);

        state.setState(legalStateResolved: true, hasAcceptedLegal: true);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Onboarding Screen'), findsNothing);

        router.dispose();
        state.dispose();
      },
    );

    testWidgets(
      'authenticated user stays on current route when legal state is not accepted (legal enforced in feature flows, not startup routing)',
      (tester) async {
        final state = _RedirectHarness(
          uid: 'user-1',
          phase: _TestAuthBootstrapPhase.authenticatedStable,
          legalStateResolved: false,
          hasAcceptedLegal: false,
        );

        final router = GoRouter(
          initialLocation: '/speed-dating',
          refreshListenable: state,
          redirect: (context, routerState) {
            return evaluateAppRedirect(
              matchedLocation: routerState.matchedLocation,
              uid: state.uid,
              authLoading: !state.isRoutingStable,
              legalStateResolved: state.legalStateResolved,
              hasAcceptedLegal: state.hasAcceptedLegal,
            );
          },
          routes: [
            GoRoute(
              path: '/speed-dating',
              builder: (_, _) =>
                  const Scaffold(body: Text('Speed Dating Screen')),
            ),
            GoRoute(
              path: '/onboarding',
              builder: (_, _) =>
                  const Scaffold(body: Text('Onboarding Screen')),
            ),
            GoRoute(
              path: '/auth',
              builder: (_, _) => const Scaffold(body: Text('Auth Screen')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _waitForAuthStable(tester, state);

        expect(find.text('Speed Dating Screen'), findsOneWidget);
        expect(find.text('Onboarding Screen'), findsNothing);

        // Legal state resolves but user has not accepted — startup routing
        // ignores legal state. User stays on /speed-dating.
        state.setState(legalStateResolved: true, hasAcceptedLegal: false);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.text('Speed Dating Screen'), findsOneWidget);
        expect(find.text('Onboarding Screen'), findsNothing);

        router.dispose();
        state.dispose();
      },
    );

    testWidgets(
      'redirects to auth when auth state flips signed-out after first stable route',
      (tester) async {
        final state = _RedirectHarness(
          uid: 'user-1',
          phase: _TestAuthBootstrapPhase.authenticatedStable,
          legalStateResolved: true,
          hasAcceptedLegal: true,
        );

        final router = GoRouter(
          initialLocation: '/home',
          refreshListenable: state,
          redirect: (context, routerState) {
            return evaluateAppRedirect(
              matchedLocation: routerState.matchedLocation,
              uid: state.uid,
              authLoading: !state.isRoutingStable,
              legalStateResolved: state.legalStateResolved,
              hasAcceptedLegal: state.hasAcceptedLegal,
            );
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home Screen')),
            ),
            GoRoute(
              path: '/onboarding',
              builder: (_, _) =>
                  const Scaffold(body: Text('Onboarding Screen')),
            ),
            GoRoute(
              path: '/auth',
              builder: (_, _) => const Scaffold(body: Text('Auth Screen')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _waitForAuthStable(tester, state);

        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Auth Screen'), findsNothing);
        expect(find.text('Onboarding Screen'), findsNothing);

        state.setState(
          uid: '',
          legalStateResolved: true,
          hasAcceptedLegal: true,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(find.text('Auth Screen'), findsOneWidget);
        expect(find.text('Onboarding Screen'), findsNothing);

        router.dispose();
        state.dispose();
      },
    );
  });
}
