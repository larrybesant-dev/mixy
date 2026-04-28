import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/routing/redirect_logic.dart';

class _RedirectHarness extends ChangeNotifier {
  _RedirectHarness({
    required this.uid,
    required this.authLoading,
    required this.legalStateResolved,
    required this.hasAcceptedLegal,
  });

  String? uid;
  bool authLoading;
  bool legalStateResolved;
  bool hasAcceptedLegal;

  void setState({
    String? uid,
    bool? authLoading,
    bool? legalStateResolved,
    bool? hasAcceptedLegal,
  }) {
    this.uid = uid ?? this.uid;
    this.authLoading = authLoading ?? this.authLoading;
    this.legalStateResolved = legalStateResolved ?? this.legalStateResolved;
    this.hasAcceptedLegal = hasAcceptedLegal ?? this.hasAcceptedLegal;
    notifyListeners();
  }
}

void main() {
  group('startup redirect stability', () {
    testWidgets('holds current route while legal state is unknown for signed-in users', (
      tester,
    ) async {
      final state = _RedirectHarness(
        uid: 'user-1',
        authLoading: false,
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
            authLoading: state.authLoading,
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
            builder: (_, _) => const Scaffold(body: Text('Onboarding Screen')),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, _) => const Scaffold(body: Text('Auth Screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Onboarding Screen'), findsNothing);

      state.setState(legalStateResolved: true, hasAcceptedLegal: true);
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Onboarding Screen'), findsNothing);

      router.dispose();
      state.dispose();
    });

    testWidgets('redirects to onboarding only after legal state resolves as not accepted', (
      tester,
    ) async {
      final state = _RedirectHarness(
        uid: 'user-1',
        authLoading: false,
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
            authLoading: state.authLoading,
            legalStateResolved: state.legalStateResolved,
            hasAcceptedLegal: state.hasAcceptedLegal,
          );
        },
        routes: [
          GoRoute(
            path: '/speed-dating',
            builder: (_, _) => const Scaffold(body: Text('Speed Dating Screen')),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const Scaffold(body: Text('Onboarding Screen')),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, _) => const Scaffold(body: Text('Auth Screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Speed Dating Screen'), findsOneWidget);
      expect(find.text('Onboarding Screen'), findsNothing);

      state.setState(legalStateResolved: true, hasAcceptedLegal: false);
      await tester.pumpAndSettle();

      expect(find.text('Onboarding Screen'), findsOneWidget);

      router.dispose();
      state.dispose();
    });

    testWidgets('redirects to auth when auth state flips signed-out after first stable route', (
      tester,
    ) async {
      final state = _RedirectHarness(
        uid: 'user-1',
        authLoading: false,
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
            authLoading: state.authLoading,
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
            builder: (_, _) => const Scaffold(body: Text('Onboarding Screen')),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, _) => const Scaffold(body: Text('Auth Screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Auth Screen'), findsNothing);
      expect(find.text('Onboarding Screen'), findsNothing);

      state.setState(uid: '', legalStateResolved: true, hasAcceptedLegal: true);
      await tester.pumpAndSettle();

      expect(find.text('Auth Screen'), findsOneWidget);
      expect(find.text('Onboarding Screen'), findsNothing);

      router.dispose();
      state.dispose();
    });
  });
}