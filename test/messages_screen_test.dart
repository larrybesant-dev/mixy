import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/messaging/screens/messages_screen.dart';
import 'test_helpers.dart';

Widget _buildApp({
  required FirebaseFirestore firestore,
  String userId = 'user-1',
  String username = 'TestUser',
}) {
  final router = GoRouter(
    initialLocation: '/messages',
    routes: [
      GoRoute(
        path: '/messages',
        builder: (_, __) => MessagesScreen(userId: userId, username: username),
      ),
      GoRoute(
        path: '/messages/new',
        builder: (_, __) => const Scaffold(body: Text('New message')),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (_, __) => const Scaffold(body: Text('Chat')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [firestoreProvider.overrideWithValue(firestore)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('messagescreen', () {
    testWidgets('renders Inbox AppBar and request action', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(_buildApp(firestore: firestore));
      await tester.pump();

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('shows empty Chats state when no conversations exist', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(_buildApp(firestore: firestore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('shows conversations when they exist', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('conversations').doc('conv-1').set({
        'participantIds': ['user-1', 'user-2'],
        'lastMessagePreview': 'Hey there!',
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
        'isArchived': false,
        'status': 'active',
        'participantNames': {'user-2': 'Alice'},
        'type': 'direct',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      await tester.pumpWidget(_buildApp(firestore: firestore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Hey there!'), findsOneWidget);
    });

    testWidgets(
      'shows pinned conversations before newer unpinned conversations',
      (tester) async {
        final firestore = FakeFirebaseFirestore();
        final now = DateTime.now();

        await firestore
            .collection('conversations')
            .doc('conv-older-pinned')
            .set({
              'participantIds': ['user-1', 'user-2'],
              'lastMessagePreview': 'Pinned hello',
              'lastMessageAt': Timestamp.fromDate(
                now.subtract(const Duration(minutes: 5)),
              ),
              'isArchived': false,
              'status': 'active',
              'participantNames': {'user-2': 'Alice'},
              'pinnedBy': ['user-1'],
              'type': 'direct',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(days: 1)),
              ),
            });
        await firestore.collection('conversations').doc('conv-newer').set({
          'participantIds': ['user-1', 'user-3'],
          'lastMessagePreview': 'Fresh message',
          'lastMessageAt': Timestamp.fromDate(now),
          'isArchived': false,
          'status': 'active',
          'participantNames': {'user-3': 'Bianca'},
          'type': 'direct',
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 3)),
          ),
        });

        await tester.pumpWidget(_buildApp(firestore: firestore));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final aliceTop = tester.getTopLeft(find.text('Alice')).dy;
        final biancaTop = tester.getTopLeft(find.text('Bianca')).dy;
        expect(aliceTop, lessThan(biancaTop));
      },
    );

    testWidgets('add message button is shown in AppBar actions', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(_buildApp(firestore: firestore));
      await tester.pump();

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('requests sheet shows empty state when no pending requests', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(_buildApp(firestore: firestore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('message Requests'), findsOneWidget);
      expect(find.text('No pending message requests.'), findsOneWidget);
    });
  });
}
