import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/follow/providers/follow_provider.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('FollowController', () {
    late FakeFirebaseFirestore firestore;
    late FollowController controller;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      controller = FollowController(firestore: firestore);
    });

    test('followUser writes to both following and followers subcollections', () async {
      await controller.followUser(
        currentUserId: 'alice',
        targetUserId: 'bob',
        targetUsername: 'bob_user',
      );

      final followingDoc = await firestore
          .collection('users')
          .doc('alice')
          .collection('following')
          .doc('bob')
          .get();
      final followerDoc = await firestore
          .collection('users')
          .doc('bob')
          .collection('followers')
          .doc('alice')
          .get();

      expect(followingDoc.exists, isTrue);
      expect(followerDoc.exists, isTrue);
    });

    test('unfollowUser removes from both subcollections', () async {
      await controller.followUser(
        currentUserId: 'alice',
        targetUserId: 'bob',
        targetUsername: 'bob_user',
      );
      await controller.unfollowUser(
        currentUserId: 'alice',
        targetUserId: 'bob',
      );

      final followingDoc = await firestore
          .collection('users')
          .doc('alice')
          .collection('following')
          .doc('bob')
          .get();
      final followerDoc = await firestore
          .collection('users')
          .doc('bob')
          .collection('followers')
          .doc('alice')
          .get();

      expect(followingDoc.exists, isFalse);
      expect(followerDoc.exists, isFalse);
    });
  });

  group('isFollowingProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
      );
    });

    tearDown(() => container.dispose());

    test('returns false when not following', () async {
      final result = await container.read(
        isFollowingProvider(
          (currentUserId: 'alice', targetUserId: 'bob'),
        ).future,
      );
      expect(result, isFalse);
    });

    test('returns true after following', () async {
      await firestore.collection('follows').doc('alice_bob').set({
        'followerUserId': 'alice',
        'followedUserId': 'bob',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      final result = await container.read(
        isFollowingProvider(
          (currentUserId: 'alice', targetUserId: 'bob'),
        ).future,
      );
      expect(result, isTrue);
    });
  });

  group('followCountProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
      );
    });

    tearDown(() => container.dispose());

    test('returns zero counts when no follows exist', () async {
      final counts = await container.read(followCountProvider('user-1').future);
      expect(counts.followers, 0);
      expect(counts.following, 0);
    });

    test('counts followers and following correctly', () async {
      final now = Timestamp.fromDate(DateTime.now());
      // alice has 2 followers and follows 1 user
      await firestore.collection('follows').doc('carol_alice').set({
        'followerUserId': 'carol',
        'followedUserId': 'alice',
        'createdAt': now,
      });
      await firestore.collection('follows').doc('dave_alice').set({
        'followerUserId': 'dave',
        'followedUserId': 'alice',
        'createdAt': now,
      });
      await firestore.collection('follows').doc('alice_bob').set({
        'followerUserId': 'alice',
        'followedUserId': 'bob',
        'createdAt': now,
      });

      final counts = await container.read(followCountProvider('alice').future);
      expect(counts.followers, 2);
      expect(counts.following, 1);
    });
  });
}
