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

    test('social lists resolve empty while no user is available', () async {
      final signedOutContainer = ProviderContainer(
        overrides: [
          friendFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(null),
        ],
      );
      addTearDown(signedOutContainer.dispose);

      expect(
        await signedOutContainer.read(friendRosterProvider.future),
        isEmpty,
      );
      expect(
        await signedOutContainer.read(incomingFriendRequestsProvider.future),
        isEmpty,
      );
      expect(
        await signedOutContainer.read(outgoingFriendRequestsProvider.future),
        isEmpty,
      );
      expect(
        await signedOutContainer.read(currentUserPresenceProvider.future),
        isNull,
      );
    });

    test(
      'friendSuggestionsProvider discovers public users without friendships',
      () async {
        final newUserFirestore = FakeFirebaseFirestore();
        await newUserFirestore.collection('users').doc('new-user').set({
          'uid': 'new-user',
          'email': 'new@mixvy.dev',
          'username': 'New User',
          'usernameLower': 'new user',
          'isPrivate': false,
          'createdAt': DateTime(2026, 1, 1),
        });
        await newUserFirestore.collection('users').doc('other-user').set({
          'uid': 'other-user',
          'email': 'other@mixvy.dev',
          'username': 'Other User',
          'usernameLower': 'other user',
          'isPrivate': false,
          'createdAt': DateTime(2026, 1, 2),
        });

        final newUserContainer = ProviderContainer(
          overrides: [
            friendFirestoreProvider.overrideWithValue(newUserFirestore),
            userProvider.overrideWithValue(
              UserModel(
                id: 'new-user',
                email: 'new@mixvy.dev',
                username: 'New User',
                createdAt: DateTime(2026, 1, 1),
              ),
            ),
          ],
        );
        addTearDown(newUserContainer.dispose);

        final suggestions = await newUserContainer.read(
          friendSuggestionsProvider.future,
        );

        expect(suggestions.map((user) => user.id), ['other-user']);
      },
    );

    test('friendPresenceBatchProvider reports online and offline users', () async {
      final now = DateTime.now();
      await firestore.collection('presence').doc('user-2').set({
        'userId': 'user-2',
        'isOnline': true,
        'status': 'online',
        'lastSeen': now,
      });
      await firestore.collection('presence').doc('user-3').set({
        'userId': 'user-3',
        'isOnline': false,
        'status': 'offline',
        'lastSeen': now,
      });

      final batchKey = buildFriendPresenceBatchKey(['user-3', 'user-2']);
      final presence = await container.read(
        friendPresenceBatchProvider(batchKey).future,
      );

      expect(presence['user-2']?.online, isTrue);
      expect(presence['user-3']?.online, isFalse);
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
      'outgoingFriendRequestsProvider resolves recipient user details',
      () async {
        final requests = await container.read(
          outgoingFriendRequestsProvider.future,
        );

        expect(requests, hasLength(1));
        expect(requests.single.friendship.id, 'user-1_user-4');
        expect(requests.single.toUser?.id, 'user-4');
        expect(requests.single.toUser?.username, 'Pending Person');
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

    test('acceptFriendRequest accepts a schema-only pending link', () async {
      await firestore.collection('friend_links').doc('user-1_user-3').set({
        'users': ['user-1', 'user-3'],
        'status': 'pending',
        'requestedBy': 'user-3',
        'createdAt': DateTime(2026, 1, 3),
      });

      await container
          .read(friendServiceProvider)
          .acceptFriendRequest('user-1_user-3');

      final legacy =
          await firestore.collection('friendships').doc('user-1_user-3').get();
      final schema =
          await firestore.collection('friend_links').doc('user-1_user-3').get();
      expect(legacy.data()?['status'], 'accepted');
      expect(schema.data()?['status'], 'accepted');
    });

    test('declineFriendRequest deletes a schema-only pending link', () async {
      await firestore.collection('friend_links').doc('user-1_user-5').set({
        'users': ['user-1', 'user-5'],
        'status': 'pending',
        'requestedBy': 'user-5',
        'createdAt': DateTime(2026, 1, 5),
      });

      await container
          .read(friendServiceProvider)
          .declineFriendRequest('user-1_user-5');

      final schema =
          await firestore.collection('friend_links').doc('user-1_user-5').get();
      expect(schema.exists, isFalse);
    });

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
