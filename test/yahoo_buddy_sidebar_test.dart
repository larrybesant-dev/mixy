import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/features/friends/models/friend_roster_entry.dart';
import 'package:mixvy/features/friends/models/friendship_model.dart';
import 'package:mixvy/features/friends/providers/friends_providers.dart';
import 'package:mixvy/features/room/widgets/yahoo_buddy_sidebar.dart';
import 'package:mixvy/models/presence_model.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

void main() {
  FriendRosterEntry entry({
    required String id,
    required String name,
    required bool online,
    DateTime? lastSeen,
  }) {
    return FriendRosterEntry(
      friendship: FriendshipModel(
        id: 'self_$id',
        userA: 'self',
        userB: id,
        status: 'accepted',
        createdAt: DateTime(2026, 7, 25),
      ),
      user: UserModel(
        id: id,
        email: '$id@mixvy.dev',
        username: name,
        createdAt: DateTime(2026, 7, 25),
      ),
      presence: PresenceModel(
        userId: id,
        isOnline: online,
        online: online,
        status: online ? UserStatus.online : UserStatus.offline,
        lastSeen: lastSeen,
      ),
    );
  }

  Widget buildUnderTest({required List<FriendRosterEntry> roster}) {
    return ProviderScope(
      overrides: [
        userProvider.overrideWith(
          (ref) => UserModel(
            id: 'self',
            email: 'self@mixvy.dev',
            username: 'Self',
            createdAt: DateTime(2026, 7, 25),
          ),
        ),
        friendRosterProvider.overrideWith((ref) => Stream.value(roster)),
        favoriteFriendIdsProvider.overrideWith((ref) async => {'u1'}),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: YahooBuddySidebar(roomId: 'room-1'),
        ),
      ),
    );
  }

  testWidgets('renders grouped Yahoo-style sections', (tester) async {
    final roster = <FriendRosterEntry>[
      entry(id: 'u1', name: 'Amber', online: true),
      entry(
        id: 'u2',
        name: 'Lex',
        online: false,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      entry(
        id: 'u3',
        name: 'Nova',
        online: false,
        lastSeen: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    await tester.pumpWidget(buildUnderTest(roster: roster));
    await tester.pumpAndSettle();

    expect(find.text('Buddy List'), findsOneWidget);
    expect(find.text('Favorites (1)'), findsOneWidget);
    expect(find.text('Online (0)'), findsOneWidget);
    expect(find.text('Away (1)'), findsOneWidget);
    expect(find.text('Offline (1)'), findsOneWidget);
  });

  testWidgets('filters list from search query', (tester) async {
    final roster = <FriendRosterEntry>[
      entry(id: 'u1', name: 'Amber', online: true),
      entry(id: 'u2', name: 'Lex', online: true),
      entry(id: 'u3', name: 'Nova', online: false),
    ];

    await tester.pumpWidget(buildUnderTest(roster: roster));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'lex');
    await tester.pumpAndSettle();

    expect(find.text('Lex'), findsOneWidget);
    expect(find.text('Amber'), findsNothing);
    expect(find.text('Nova'), findsNothing);
  });
}
