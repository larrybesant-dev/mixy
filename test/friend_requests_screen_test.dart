import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/connections/pending_requests_screen.dart';
import 'package:mixvy/features/friends/providers/friends_providers.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

void main() {
  testWidgets('shows empty requests instead of loading without a user', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FriendRequestsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incoming (0)'), findsOneWidget);
    expect(find.text('Sent (0)'), findsOneWidget);
    expect(find.text('No incoming requests'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('accepts a real incoming friend request', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('user-1').set({
      'uid': 'user-1',
      'email': 'one@mixvy.dev',
      'username': 'User One',
      'createdAt': DateTime(2026, 1, 1),
    });
    await firestore.collection('users').doc('user-2').set({
      'uid': 'user-2',
      'email': 'two@mixvy.dev',
      'username': 'User Two',
      'createdAt': DateTime(2026, 1, 2),
    });
    await firestore.collection('friendships').doc('user-1_user-2').set({
      'userA': 'user-1',
      'userB': 'user-2',
      'status': 'pending',
      'requestedBy': 'user-2',
      'createdAt': DateTime(2026, 1, 2),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1',
              email: 'one@mixvy.dev',
              username: 'User One',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FriendRequestsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('User Two'), findsOneWidget);
    expect(find.byTooltip('Accept request'), findsOneWidget);

    await tester.tap(find.byTooltip('Accept request'));
    await tester.pumpAndSettle();

    final legacy =
        await firestore.collection('friendships').doc('user-1_user-2').get();
    final schema =
        await firestore.collection('friend_links').doc('user-1_user-2').get();
    expect(legacy.data()?['status'], 'accepted');
    expect(schema.data()?['status'], 'accepted');
    expect(find.text('Incoming (0)'), findsOneWidget);
    expect(find.text('No incoming requests'), findsOneWidget);
    expect(find.text('User Two'), findsNothing);
    expect(find.byTooltip('Accept request'), findsNothing);
  });
}
