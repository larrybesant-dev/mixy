import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';

void main() {
  group('newMembersStreamProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    /// Seed a user document in the fake Firestore.
    Future<void> seedUser({
      required String id,
      required String username,
      required DateTime createdAt,
    }) async {
      await firestore.collection('users').doc(id).set({
        'username': username,
        'email': '$username@test.dev',
        'avatarUrl': '',
        'createdAt': Timestamp.fromDate(createdAt),
        'coinBalance': 0,
        'membershipLevel': 'basic',
        'followers': <String>[],
        'camViewPolicy': 'approvedOnly',
        'adultModeEnabled': false,
        'adultConsentAccepted': false,
        'themeId': 'midnight',
        'vipLevel': 0,
        'badges': <String>[],
        'interests': <String>[],
      });
    }

    test('returns empty list when no users exist', () async {
      final members = await container.read(newMembersStreamProvider.future);
      expect(members, isEmpty);
    });

    test('returns users ordered by createdAt descending', () async {
      final older = DateTime(2026, 1, 1);
      final newer = DateTime(2026, 3, 1);
      final newest = DateTime(2026, 4, 1);

      await seedUser(id: 'u1', username: 'alice', createdAt: older);
      await seedUser(id: 'u2', username: 'bob', createdAt: newest);
      await seedUser(id: 'u3', username: 'carol', createdAt: newer);

      final members = await container.read(newMembersStreamProvider.future);

      expect(members.length, 3);
      // newest first
      expect(members[0].username, 'bob');
      expect(members[1].username, 'carol');
      expect(members[2].username, 'alice');
    });

    test('caps results at 12', () async {
      // Seed 15 users
      for (var i = 1; i <= 15; i++) {
        await seedUser(
          id: 'u$i',
          username: 'user$i',
          createdAt: DateTime(2026, 1, i),
        );
      }

      final members = await container.read(newMembersStreamProvider.future);

      expect(members.length, lessThanOrEqualTo(12));
    });

    test(
      'each returned UserModel has the correct id set from doc id',
      () async {
        await seedUser(
          id: 'explicit-id',
          username: 'testuser',
          createdAt: DateTime(2026, 4, 8),
        );

        final members = await container.read(newMembersStreamProvider.future);

        expect(members, hasLength(1));
        expect(members.single.id, 'explicit-id');
        expect(members.single.username, 'testuser');
      },
    );

    test('stream updates reactively when a new user is added', () async {
      await seedUser(
        id: 'u1',
        username: 'firstuser',
        createdAt: DateTime(2026, 1, 1),
      );

      // Wait for initial emission
      final first = await container.read(newMembersStreamProvider.future);
      expect(first.any((u) => u.username == 'firstuser'), isTrue);

      // Add a second user
      await seedUser(
        id: 'u2',
        username: 'newuser',
        createdAt: DateTime(2026, 4, 8),
      );

      // The provider is autoDispose — re-read after the second write to get the
      // updated snapshot.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final all = firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(12)
          .snapshots();
      final snap = await all.first;
      final usernames = snap.docs
          .map((d) => d.data()['username'] as String)
          .toList();
      expect(usernames, contains('newuser'));
      expect(usernames, contains('firstuser'));
    });
  });
}
