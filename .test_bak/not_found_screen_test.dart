import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/presentation/screens/not_found_screen.dart';

Widget _buildApp({required String path}) {
  final router = GoRouter(
    initialLocation: '/missing',
    routes: [
      GoRoute(
        path: '/missing',
        builder: (__, _) => NotFoundScreen(path: path)),
      GoRoute(
        path: '/',
        builder: (__, _) => const Scaffold(body: Text('Home'))),
    ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('NotFoundScreen', () {
    testWidgets('renders page-not-found title and unknown path', (
      tester) async {
      await tester.pumpWidget(_buildApp(path: '/some/unknown/path'));
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);
      expect(find.text('This page does not exist.'), findsOneWidget);
      expect(find.text('/some/unknown/path'), findsOneWidget);
    });

    testWidgets('shows Go to home button', (tester) async {
      await tester.pumpWidget(_buildApp(path: '/bad'));
      await tester.pumpAndSettle();

      expect(find.text('Go to home'), findsOneWidget);
    });

    testWidgets('Go to home button navigates to /', (tester) async {
      await tester.pumpWidget(_buildApp(path: '/bad'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to home'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('This page does not exist.'), findsNothing);
    });

    testWidgets('renders explore-off icon', (tester) async {
      await tester.pumpWidget(_buildApp(path: '/nope'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.explore_off_outlined), findsOneWidget);
    });
  });
}










