import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/discovery/models/discovery_preferences.dart';
import 'package:mixvy/features/discovery/providers/discovery_provider.dart';
import 'package:mixvy/features/discovery/screens/persistent_discovery_screen.dart';
import 'package:mixvy/features/friends/providers/friends_providers.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

void main() {
  UserModel candidate({
    int? age,
    List<String> interests = const <String>[],
  }) {
    return UserModel(
      id: 'candidate-1',
      email: '',
      username: 'Candidate',
      age: age,
      interests: interests,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('Discovery filters candidates by age range', () {
    const preferences = DiscoveryPreferences(
      userId: 'viewer-1',
      minAge: 25,
      maxAge: 35,
    );

    expect(
      matchesDiscoveryPreferences(candidate(age: 30), preferences),
      isTrue,
    );
    expect(
      matchesDiscoveryPreferences(candidate(age: 40), preferences),
      isFalse,
    );
  });

  test('Discovery matches interests case-insensitively', () {
    const preferences = DiscoveryPreferences(
      userId: 'viewer-1',
      interestTags: ['Music'],
    );

    expect(
      matchesDiscoveryPreferences(
        candidate(interests: ['music', 'Travel']),
        preferences,
      ),
      isTrue,
    );
    expect(
      matchesDiscoveryPreferences(
        candidate(interests: ['Gaming']),
        preferences,
      ),
      isFalse,
    );
  });

  test('Discovery keeps profiles with private age when interests match', () {
    const preferences = DiscoveryPreferences(
      userId: 'viewer-1',
      minAge: 25,
      maxAge: 35,
      interestTags: ['Art'],
    );

    expect(
      matchesDiscoveryPreferences(
        candidate(interests: ['Art']),
        preferences,
      ),
      isTrue,
    );
  });

  testWidgets('Discovery renders browse and connect candidates',
      (tester) async {
    final viewer = UserModel(
      id: 'viewer-1',
      email: '',
      username: 'Viewer',
      createdAt: DateTime(2026, 1, 1),
    );
    final suggestion = candidate(age: 30, interests: ['Music']);
    final router = GoRouter(
      initialLocation: '/discover',
      routes: [
        GoRoute(
          path: '/discover',
          builder: (_, __) => const PersistentDiscoveryScreen(),
        ),
        GoRoute(
          path: '/profile/:id',
          builder: (_, state) => Text(state.pathParameters['id'] ?? ''),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProvider.overrideWithValue(viewer),
          discoveryPreferencesProvider(viewer.id).overrideWith(
            (ref) => Stream.value(
              DiscoveryPreferences(
                userId: viewer.id,
                interestTags: const ['Music'],
              ),
            ),
          ),
          friendSuggestionsProvider.overrideWith(
            (ref) async => [suggestion],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discovery Coming Soon'), findsNothing);
    expect(find.text('Candidate'), findsOneWidget);
    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
