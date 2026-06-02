import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/bookmarks/providers/bookmark_provider.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('BookmarkController', () {
    late FakeFirebaseFirestore firestore;
    late BookmarkController controller;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      controller = BookmarkController();
    });

    test('isBookmarked returns false when no bookmark exists', () async {
      final result = await controller.isBookmarked(
        userId: 'user-1',
        postId: 'post-1');
      expect(result, isFalse);
    });

    test('savePost creates bookmark document', () async {
      await controller.savePost(userId: 'user-1', postId: 'post-abc');
      final doc = await firestore
          .collection('users')
          .doc('user-1')
          .collection('bookmarks')
          .doc('post-abc')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['postId'], 'post-abc');
    });

    test('isBookmarked returns true after savePost', () async {
      await controller.savePost(userId: 'user-1', postId: 'post-xyz');
      final result = await controller.isBookmarked(
        userId: 'user-1',
        postId: 'post-xyz');
      expect(result, isTrue);
    });

    test('removeBookmark deletes the document', () async {
      await controller.savePost(userId: 'user-1', postId: 'post-del');
      await controller.removeBookmark(userId: 'user-1', bookmarkId: 'post-del');
      final result = await controller.isBookmarked(
        userId: 'user-1',
        postId: 'post-del');
      expect(result, isFalse);
    });

    test(
      'bookmarks are user-scoped: user-2 cannot see user-1 bookmark',
      () async {
        await controller.savePost(userId: 'user-1', postId: 'post-1');
        final result = await controller.isBookmarked(
          userId: 'user-2',
          postId: 'post-1');
        expect(result, isFalse);
      });
  });

  group('bookmarkedPostsProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)]);
    });

    tearDown(() {
      container.dispose();
    });

    test('returns empty list when user has no bookmarks', () async {
      final result = await container.read(
        bookmarkedPostsProvider('user-1').future);
      expect(result, isEmpty);
    });

    test('returns post data for existing bookmarks', () async {
      // Create the post
      await firestore.collection('posts').doc('post-1').set({
        'title': 'Test Post',
        'content': 'Hello world',
        'authorId': 'author-1',
      });
      // Bookmark it
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('bookmarks')
          .doc('post-1')
          .set({
            'postId': 'post-1',
            'savedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      final result = await container.read(
        bookmarkedPostsProvider('user-1').future);
      expect(result.length, 1);
      expect(result.first['id'], 'post-1');
      expect(result.first['content'], 'Hello world');
    });

    test('skips bookmarks whose post no longer exists', () async {
      // Bookmark a non-existent post
      await firestore
          .collection('users')
          .doc('user-1')
          .collection('bookmarks')
          .doc('ghost-post')
          .set({
            'postId': 'ghost-post',
            'savedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      final result = await container.read(
        bookmarkedPostsProvider('user-1').future);
      expect(result, isEmpty);
    });
  });
}










