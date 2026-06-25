import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/trending/providers/trending_provider.dart';

import 'test_helpers.dart';

/// A local fake to bypass the singleton lifecycle manager in tests.
/// This prevents "StreamLifecycleManager used after being disposed" errors
/// caused by the production singleton being marked as disposed between tests.
class _FakeLifecycleManager extends ChangeNotifier implements StreamLifecycleManager {
  @override
  String get currentRoutePath => '/';

  @override
  void updateRoute(String routePath) {}

  @override
  bool isRouteActive(List<String> routePrefixes) => true;

  @override
  Stream<T> bind<T>({
    required String key,
    required Stream<T> Function() create,
    List<String> routePrefixes = const <String>[],
  }) => create();

  @override
  String buildDedupeKey({
    required String domain,
    String? userId,
    String? route,
    String? queryHash,
  }) => '';
}

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('trendingPostsProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          // Override the manager so each test gets a fresh, non-disposed instance.
          streamLifecycleManagerProvider.overrideWith((ref) => _FakeLifecycleManager()),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('returns empty list when no posts exist', () async {
      // Listen to keep the provider alive during the test
      container.listen(trendingPostsProvider, (_, __) {});

      // Wait for initial stream emission
      await container.read(postsFeedProvider.future);
      
      final postsAsync = container.read(trendingPostsProvider);
      final posts = postsAsync.value ?? [];
      expect(posts, isEmpty);
    });

    test('returns posts created within last 7 days', () async {
      // 1. Seed the data BEFORE reading the provider
      final recent = DateTime.now().subtract(const Duration(days: 2));
      await firestore.collection('posts').doc('recent-post').set({
        'authorId': 'user-1',
        'authorName': 'DJ Silk',
        'content': 'Velvet night 🎶',
        'hashtags': ['jazz'],
        'createdAt': Timestamp.fromDate(recent),
        'likeCount': 10,
        'commentCount': 5,
      });

      // 2. Listen to keep the provider alive
      container.listen(trendingPostsProvider, (_, __) {});

      // 3. Wait for the stream to emit the initial snapshot containing our seeded data
      await container.read(postsFeedProvider.future);
      
      // 4. Assert
      final postsAsync = container.read(trendingPostsProvider);
      final posts = postsAsync.value ?? [];
      
      expect(posts.length, 1);
      expect(posts.first.id, 'recent-post');
      expect(posts.first.authorName, 'DJ Silk');
    });

    test('sorts by engagement score (likeCount + commentCount)', () async {
      final now = DateTime.now().subtract(const Duration(hours: 1));
      
      // 1. Seed all data first
      await firestore.collection('posts').doc('low-engage').set({
        'authorId': 'user-1',
        'authorName': 'User A',
        'content': 'Quiet post',
        'hashtags': <String>[],
        'createdAt': Timestamp.fromDate(now),
        'likeCount': 2,
        'commentCount': 1,
      });
      await firestore.collection('posts').doc('high-engage').set({
        'authorId': 'user-2',
        'authorName': 'User B',
        'content': 'Popular post',
        'hashtags': <String>[],
        'createdAt': Timestamp.fromDate(now),
        'likeCount': 50,
        'commentCount': 20,
      });

      // 2. Attach listener to keep alive
      container.listen(trendingPostsProvider, (_, __) {});

      // 3. Wait for the stream to process the seeded data
      await container.read(postsFeedProvider.future);
      
      // 4. Assert sorting logic
      final postsAsync = container.read(trendingPostsProvider);
      final posts = postsAsync.value ?? [];
      
      expect(posts.isNotEmpty, true);
      expect(posts.first.id, 'high-engage');
    });
  });

  group('TrendingPost.fromJson', () {
    test('maps all fields correctly', () {
      final now = DateTime(2026, 4, 1, 22, 0);
      final post = TrendingPost.fromJson({
        'authorId': 'u1',
        'authorName': 'DJ Noir',
        'authorAvatarUrl': 'https://example.com/dj.jpg',
        'content': 'Smooth vibes only',
        'hashtags': ['velvet', 'noir'],
        'createdAt': now.toIso8601String(),
        'likeCount': 88,
        'commentCount': 22,
      }, 'post-1');

      expect(post.id, 'post-1');
      expect(post.authorId, 'u1');
      expect(post.authorName, 'DJ Noir');
      expect(post.content, 'Smooth vibes only');
      expect(post.hashtags, containsAll(['velvet', 'noir']));
      expect(post.likeCount, 88);
      expect(post.commentCount, 22);
    });

    test('uses fallback values for missing fields', () {
      final post = TrendingPost.fromJson({}, 'post-empty');
      expect(post.authorName, '');
      expect(post.likeCount, 0);
      expect(post.commentCount, 0);
      expect(post.hashtags, isEmpty);
    });
  });

  group('trendingHashtagsProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          streamLifecycleManagerProvider.overrideWith((ref) => _FakeLifecycleManager()),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('returns empty list when no hashtags seeded', () async {
      final tags = await container.read(
        trendingHashtagsProvider(DateTime.now()).future,
      );
      expect(tags, isEmpty);
    });

    test('returns hashtags ordered by postCount', () async {
      // Seed data before reading the provider
      await firestore.collection('hashtags').doc('#jazz').set({
        'postCount': 5,
        'trendScore': 0.3,
      });
      await firestore.collection('hashtags').doc('#velvet').set({
        'postCount': 30,
        'trendScore': 0.9,
      });

      final tags = await container.read(
        trendingHashtagsProvider(DateTime.now()).future,
      );

      expect(tags.length, 2);
      expect(tags.first['hashtag'], '#velvet');
      expect(tags.first['postCount'], 30);
    });
  });
}
