import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/friends/models/friend_roster_entry.dart';
import 'package:mixvy/features/friends/models/friendship_model.dart';
import 'package:mixvy/features/friends/providers/friends_providers.dart';
import 'package:mixvy/models/presence_model.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

void main() {
  group('Friend providers', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('user-1').set({
        'uid': 'user-1',
        'email': 'user1@mixvy.dev',
        'username': 'User One',
        'usernameLower': 'user one',
        'createdAt': DateTime(2026, 1, 1),
      });
      await firestore.collection('users').doc('user-2').set({
        'uid': 'user-2',
        'email': 'user2@mixvy.dev',
        'username': 'User Two',
        'usernameLower': 'user two',
        'createdAt': DateTime(2026, 1, 2),
      });
      await firestore.collection('users').doc('user-3').set({
        'uid': 'user-3',
        'email': 'search@mixvy.dev',
        'username': 'Searchable Person',
        'usernameLower': 'searchable person',
        'createdAt': DateTime(2026, 1, 3),
      });
      await firestore.collection('users').doc('user-4').set({
        'uid': 'user-4',
        'email': 'pending@mixvy.dev',
        'username': 'Pending Person',
        'usernameLower': 'pending person',
        'createdAt': DateTime(2026, 1, 4),
      });
      await firestore.collection('users').doc('user-5').set({
        'uid': 'user-5',
        'email': 'search-candidate@mixvy.dev',
        'username': 'Search Candidate',
        'usernameLower': 'search candidate',
        'createdAt': DateTime(2026, 1, 5),
      });

      await firestore.collection('friendships').doc('user-1_user-2').set({
        'userA': 'user-1',
        'userB': 'user-2',
        'status': 'accepted',
        'requestedBy': 'user-1',
        'createdAt': DateTime(2026, 1, 2),
      });
      await firestore.collection('friendships').doc('user-1_user-3').set({
        'userA': 'user-1',
        'userB': 'user-3',
        'status': 'pending',
        'requestedBy': 'user-3',
        'createdAt': DateTime(2026, 1, 3),
      });
      await firestore.collection('friendships').doc('user-1_user-4').set({
        'userA': 'user-1',
        'userB': 'user-4',
        'status': 'pending',
        'requestedBy': 'user-1',
        'createdAt': DateTime(2026, 1, 4),
      });

      container = ProviderContainer(
        overrides: [
          friendFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1',
              email: 'user1@mixvy.dev',
              username: 'User One',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'friendsListProvider resolves accepted friends from friendships',
      () async {
        final friends = await container.read(friendsListProvider.future);

        expect(friends, hasLength(1));
        expect(friends.single.id, 'user-2');
        expect(friends.single.username, 'User Two');
      },
    );

    test(
      'friendCandidateSearchProvider excludes friends and pending requests',
      () async {
        container.read(friendSearchQueryProvider.notifier).state = 'search';

        final users = await container.read(
          friendCandidateSearchProvider.future,
        );

        expect(users, hasLength(1));
        expect(users.single.id, 'user-5');
      },
    );

    test(
      'incomingFriendRequestsProvider resolves sender user details from friendships',
      () async {
        final requests = await container.read(
          incomingFriendRequestsProvider.future,
        );

        expect(requests, hasLength(1));
        expect(requests.single.request.id, 'user-1_user-3');
        expect(requests.single.fromUser?.id, 'user-3');
        expect(requests.single.fromUser?.username, 'Searchable Person');
      },
    );

    test(
      'friendsListProvider resolves accepted friends from schema friend_links when legacy docs are absent',
      () async {
        final schemaOnlyFirestore = FakeFirebaseFirestore();
        await schemaOnlyFirestore.collection('users').doc('user-1').set({
          'uid': 'user-1',
          'email': 'user1@mixvy.dev',
          'username': 'User One',
          'usernameLower': 'user one',
          'createdAt': DateTime(2026, 1, 1),
        });
        await schemaOnlyFirestore.collection('users').doc('user-2').set({
          'uid': 'user-2',
          'email': 'user2@mixvy.dev',
          'username': 'User Two',
          'usernameLower': 'user two',
          'createdAt': DateTime(2026, 1, 2),
        });
        await schemaOnlyFirestore
            .collection('friend_links')
            .doc('user-1_user-2')
            .set({
              'users': ['user-1', 'user-2'],
              'status': 'accepted',
              'requestedBy': 'user-1',
              'createdAt': DateTime(2026, 1, 2),
              'updatedAt': DateTime(2026, 1, 2),
            });

        final schemaContainer = ProviderContainer(
          overrides: [
            friendFirestoreProvider.overrideWithValue(schemaOnlyFirestore),
            userProvider.overrideWithValue(
              UserModel(
                id: 'user-1',
                email: 'user1@mixvy.dev',
                username: 'User One',
                createdAt: DateTime(2026, 1, 1),
              ),
            ),
          ],
        );
        addTearDown(schemaContainer.dispose);

        final friends = await schemaContainer.read(friendsListProvider.future);

        expect(friends, hasLength(1));
        expect(friends.single.id, 'user-2');
      },
    );

    test(
      'incomingFriendRequestsProvider resolves schema pending friend links when legacy docs are absent',
      () async {
        final schemaOnlyFirestore = FakeFirebaseFirestore();
        await schemaOnlyFirestore.collection('users').doc('user-1').set({
          'uid': 'user-1',
          'email': 'user1@mixvy.dev',
          'username': 'User One',
          'usernameLower': 'user one',
          'createdAt': DateTime(2026, 1, 1),
        });
        await schemaOnlyFirestore.collection('users').doc('user-3').set({
          'uid': 'user-3',
          'email': 'search@mixvy.dev',
          'username': 'Searchable Person',
          'usernameLower': 'searchable person',
          'createdAt': DateTime(2026, 1, 3),
        });
        await schemaOnlyFirestore
            .collection('friend_links')
            .doc('user-1_user-3')
            .set({
              'users': ['user-1', 'user-3'],
              'status': 'pending',
              'requestedBy': 'user-3',
              'createdAt': DateTime(2026, 1, 3),
              'updatedAt': DateTime(2026, 1, 3),
            });

        final schemaContainer = ProviderContainer(
          overrides: [
            friendFirestoreProvider.overrideWithValue(schemaOnlyFirestore),
            userProvider.overrideWithValue(
              UserModel(
                id: 'user-1',
                email: 'user1@mixvy.dev',
                username: 'User One',
                createdAt: DateTime(2026, 1, 1),
              ),
            ),
          ],
        );
        addTearDown(schemaContainer.dispose);

        final requests = await schemaContainer.read(
          incomingFriendRequestsProvider.future,
        );

        expect(requests, hasLength(1));
        expect(requests.single.request.id, 'user-1_user-3');
        expect(requests.single.fromUser?.id, 'user-3');
      },
    );

    test(
      'sendFriendRequest mirrors pending links into schema collection',
      () async {
        final service = container.read(friendServiceProvider);

        await service.sendFriendRequest('user-1', 'user-5');

        final legacyLink = await firestore
            .collection('friendships')
            .doc('user-1_user-5')
            .get();
        final schemaLink = await firestore
            .collection('friend_links')
            .doc('user-1_user-5')
            .get();

        expect(legacyLink.exists, isTrue);
        expect(legacyLink.data()?['status'], 'pending');
        expect(legacyLink.data()?['requestedBy'], 'user-1');

        expect(schemaLink.exists, isTrue);
        expect(schemaLink.data()?['status'], 'pending');
        expect(schemaLink.data()?['requestedBy'], 'user-1');
        expect(
          schemaLink.data()?['users'],
          containsAll(<String>['user-1', 'user-5']),
        );
      },
    );

    test(
      'sendFriendRequest still creates a pending link when the target profile doc is not readable yet',
      () async {
        await firestore.collection('users').doc('user-5').delete();
        final service = container.read(friendServiceProvider);

        await service.sendFriendRequest('user-1', 'user-5');

        final legacyLink = await firestore
            .collection('friendships')
            .doc('user-1_user-5')
            .get();
        final schemaLink = await firestore
            .collection('friend_links')
            .doc('user-1_user-5')
            .get();

        expect(legacyLink.exists, isTrue);
        expect(legacyLink.data()?['status'], 'pending');
        expect(schemaLink.exists, isTrue);
        expect(schemaLink.data()?['status'], 'pending');
      },
    );

    test('onlineFriendsProvider filters live online friends', () async {
      final rosterContainer = ProviderContainer(
        overrides: [
          friendRosterProvider.overrideWith(
            (ref) => Stream.value([
              FriendRosterEntry(
                friendship: FriendshipModel(
                  id: 'user-1_user-2',
                  userA: 'user-1',
                  userB: 'user-2',
                  status: 'accepted',
                  createdAt: DateTime(2026, 1, 2),
                ),
                user: UserModel(
                  id: 'user-2',
                  email: 'user2@mixvy.dev',
                  username: 'User Two',
                  createdAt: DateTime(2026, 1, 2),
                ),
                presence: PresenceModel(
                  userId: 'user-2',
                  isOnline: true,
                  online: true,
                  status: UserStatus.online,
                  lastSeen: DateTime.now(),
                ),
              ),
            ]),
          ),
        ],
      );

      addTearDown(rosterContainer.dispose);

      await rosterContainer.read(friendRosterProvider.future);
      final onlineFriends = rosterContainer.read(onlineFriendsProvider).value;

      expect(onlineFriends, hasLength(1));
      expect(onlineFriends!.single.user.id, 'user-2');
      expect(onlineFriends.single.isOnline, isTrue);
    });

    test(
      'sendFriendRequest reconciles reciprocal pending friendships',
      () async {
        final service = container.read(friendServiceProvider);

        await service.sendFriendRequest('user-1', 'user-3');

        final friendship = await firestore
            .collection('friendships')
            .doc('user-1_user-3')
            .get();
        final schemaLink = await firestore
            .collection('friend_links')
            .doc('user-1_user-3')
            .get();
        expect(friendship.data()?['status'], 'accepted');
        expect(schemaLink.exists, isTrue);
        expect(schemaLink.data()?['status'], 'accepted');

        final notifications = await firestore
            .collection('notifications')
            .where('userId', isEqualTo: 'user-3')
            .get();

        expect(notifications.docs, isNotEmpty);
        expect(notifications.docs.last.data()['type'], 'friend_accept');
        expect(notifications.docs.last.data()['actorId'], 'user-1');
      },
    );
  });
}
