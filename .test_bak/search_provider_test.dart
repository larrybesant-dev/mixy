import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/search/providers/search_provider.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('searchUsersProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)]);
    });

    tearDown(() => container.dispose());

    test('returns empty list for empty query', () async {
      final results = await container.read(searchUsersProvider('').future);
      expect(results, isEmpty);
    });

    test('returns empty list when no users match', () async {
      // No users seeded — query should return empty
      final results = await container.read(searchUsersProvider('xyz').future);
      expect(results, isEmpty);
    });

    test('search only returns public users', () async {
      await firestore.collection('users').doc('public-1').set({
        'username': 'velvetqueen',
        'usernameLower': 'velvetqueen',
        'isPrivate': false,
      });
      await firestore.collection('users').doc('private-1').set({
        'username': 'velvethidden',
        'usernameLower': 'velvethidden',
        'isPrivate': true,
      });

      final results = await container.read(
        searchUsersProvider('velvet').future);

      expect(results.map((user) => user.id), contains('public-1'));
      expect(results.map((user) => user.id), isNot(contains('private-1')));
    });

    test('SearchUser.fromJson maps fields correctly', () {
      final user = SearchUser.fromJson({
        'username': 'jazzqueen',
        'avatarUrl': 'https://example.com/avatar.png',
        'isVerified': true,
        'followerCount': 42,
      }, 'user-1');

      expect(user.id, 'user-1');
      expect(user.username, 'jazzqueen');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.isVerified, isTrue);
      expect(user.followerCount, 42);
    });

    test('SearchUser.fromJson handles missing fields with defaults', () {
      final user = SearchUser.fromJson({}, 'user-2');
      expect(user.username, '');
      expect(user.isVerified, isFalse);
      expect(user.followerCount, 0);
      expect(user.avatarUrl, isNull);
    });
  });

  group('searchPostsProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)]);
    });

    tearDown(() => container.dispose());

    test('returns empty list for empty query', () async {
      final results = await container.read(searchPostsProvider('').future);
      expect(results, isEmpty);
    });

    test('returns empty list when no posts match', () async {
      final results = await container.read(searchPostsProvider('jazz').future);
      expect(results, isEmpty);
    });

    test('SearchPost.fromJson maps fields correctly', () {
      final now = DateTime(2026, 4, 1);
      final post = SearchPost.fromJson({
        'authorId': 'user-1',
        'authorName': 'Jazz Queen',
        'content': 'Late night vibes',
        'hashtags': ['jazz', 'vibes'],
        'createdAt': now.toIso8601String(),
        'likeCount': 10,
      }, 'post-1');

      expect(post.id, 'post-1');
      expect(post.authorId, 'user-1');
      expect(post.authorName, 'Jazz Queen');
      expect(post.content, 'Late night vibes');
      expect(post.hashtags, containsAll(['jazz', 'vibes']));
      expect(post.likeCount, 10);
    });
  });

  group('SearchHashtag.fromJson', () {
    test('maps postCount and falls back gracefully', () {
      final tag = SearchHashtag.fromJson({'postCount': 99}, '#velvet');
      expect(tag.hashtag, '#velvet');
      expect(tag.postCount, 99);
    });
  });
}










