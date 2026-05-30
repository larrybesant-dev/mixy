import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

// Stream of all bookmarked posts for current user
final bookmarkedPostsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .orderBy('savedAt', descending: true)
          .limit(50)
          .snapshots()
          .asyncMap((snapshot) async {
            final bookmarks = <Map<String, dynamic>>[];
            for (final doc in snapshot.docs) {
              final postId = _asString(doc.data()['postId']);
              if (postId.isEmpty) {
                continue;
              }
              try {
                final postDoc = await firestore
                    .collection('posts')
                    .doc(postId)
                    .get();
                if (postDoc.exists) {
                  final postData = postDoc.data();
                  if (postData == null) {
                    continue;
                  }
                  bookmarks.add({
                    ...postData,
                    'id': postDoc.id,
                    'bookmarkId': doc.id,
                  });
                }
              } catch (e) {
                // Silently skip posts that can't be loaded
              }
            }
            return bookmarks;
          });
    });

// Controller for bookmark operations
final bookmarkControllerProvider = Provider<BookmarkController>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return BookmarkController(firestore: firestore);
});

class BookmarkController {
  final FirebaseFirestore _firestore;

  BookmarkController({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Future<void> savePost({
    required String userId,
    required String postId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc(postId)
        .set({'postId': postId, 'savedAt': Timestamp.fromDate(DateTime.now())});
  }

  Future<void> removeBookmark({
    required String userId,
    required String bookmarkId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc(bookmarkId)
        .delete();
  }

  Future<bool> isBookmarked({
    required String userId,
    required String postId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc(postId)
        .get();
    return doc.exists;
  }
}




