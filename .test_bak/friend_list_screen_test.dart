import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/friends/models/friend_roster_entry.dart';
import 'package:mixvy/features/friends/models/friendship_model.dart';
import 'package:mixvy/features/friends/panes/friends_pane_view.dart';
import 'package:mixvy/features/friends/providers/friends_providers.dart';
import 'package:mixvy/features/schema_messenger/core/schema_engine/schema_module_health_provider.dart';
import 'package:mixvy/models/presence_model.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  testWidgets('FriendListScreen renders online, in-room, and offline sections', (
    tester) async {
    final now = DateTime.now();
    final roster = <FriendRosterEntry>[
      FriendRosterEntry(
        friendship: FriendshipModel(
          id: 'user-1_user-2',
          userA: 'user-1',
          userB: 'user-2',
          status: 'accepted',
          requestedBy: 'user-1',
          createdAt: DateTime(2026, 1, 2)),
        user: UserModel(
          id: 'user-2',
          email: 'user2@mixvy.dev',
          username: 'User Two',
          createdAt: DateTime(2026, 1, 2)),
        presence: PresenceModel(
          userId: 'user-2',
          isOnline: true,
          inRoom: null,
          lastSeen: now,
          status: UserStatus.online)),
      FriendRosterEntry(
        friendship: FriendshipModel(
          id: 'user-1_user-3',
          userA: 'user-1',
          userB: 'user-3',
          status: 'accepted',
          requestedBy: 'user-1',
          createdAt: DateTime(2026, 1, 3)),
        user: UserModel(
          id: 'user-3',
          email: 'user3@mixvy.dev',
          username: 'Room Friend',
          createdAt: DateTime(2026, 1, 3)),
        presence: PresenceModel(
          userId: 'user-3',
          isOnline: true,
          inRoom: 'room-123',
          lastSeen: now,
          status: UserStatus.online)),
      FriendRosterEntry(
        friendship: FriendshipModel(
          id: 'user-1_user-4',
          userA: 'user-1',
          userB: 'user-4',
          status: 'accepted',
          requestedBy: 'user-1',
          createdAt: DateTime(2026, 1, 4)),
        user: UserModel(
          id: 'user-4',
          email: 'user4@mixvy.dev',
          username: 'Offline Friend',
          createdAt: DateTime(2026, 1, 4)),
        presence: PresenceModel(
          userId: 'user-4',
          isOnline: false,
          inRoom: null,
          lastSeen: now.subtract(const Duration(hours: 2)),
          status: UserStatus.offline)),
    ];

    final container = ProviderContainer(
      overrides: [
        schemaModuleHealthProvider('friends').overrideWith(
          (ref) => const SchemaModuleHealth(
            moduleId: 'friends',
            compositeScore: 100,
            structuralScore: 100,
            parityScore: 100,
            enforcementScore: 100,
            trend: MigrationHealthTrend.stable,
            comparable: false,
            parityMatch: true,
            mismatchCount: 0,
            reasons: [])),
        schemaModuleHealthProvider('message').overrideWith(
          (ref) => const SchemaModuleHealth(
            moduleId: 'message',
            compositeScore: 100,
            structuralScore: 100,
            parityScore: 100,
            enforcementScore: 100,
            trend: MigrationHealthTrend.stable,
            comparable: false,
            parityMatch: true,
            mismatchCount: 0,
            reasons: [])),
        friendRosterProvider.overrideWith((ref) => Stream.value(roster)),
        currentUserPresenceProvider.overrideWith(
          (ref) => Stream.value(
            PresenceModel(
              userId: 'user-1',
              isOnline: true,
              inRoom: 'my-room',
              lastSeen: now,
              status: UserStatus.online))),
        userProvider.overrideWithValue(
          UserModel(
            id: 'user-1',
            email: 'user1@mixvy.dev',
            username: 'User One',
            createdAt: DateTime(2026, 1, 1))),
      ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FriendsPaneView()))));

    await tester.pumpAndSettle();

    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('IN ROOMS'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('2 active now'), findsOneWidget);
    expect(find.text('1 in rooms'), findsOneWidget);
    expect(find.text('Back to my room'), findsOneWidget);
    expect(find.text('User Two'), findsOneWidget);
    expect(find.text('Room Friend'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);

    await tester.tap(find.text('OFFLINE'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Friend'), findsOneWidget);
    expect(find.textContaining('Last seen'), findsOneWidget);
    // Dispose container inside test body and pump to drain stream cancellation
    // callbacks before the test completes, preventing "failed after completed".
    container.dispose();
    await tester.pump();
  });
}










