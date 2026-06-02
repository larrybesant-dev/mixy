import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import 'package:mixvy/models/models.dart';
import 'package:mixvy/core/firestore/firestore_error_utils.dart';

class FeedRepository {
  final FirebaseFirestore _db;

  FeedRepository(this._db);

  Future<List<PostModel>> getPostsFeed() async {
    try {
      final snap = await _db
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snap.docs
          .map((d) => PostModel.fromDoc(d.id, d.data()))
          .toList(growable: false);
    } catch (error, stackTrace) {
      logFirestoreError(
        context: 'dashboard.posts fetch',
        error: error,
        stackTrace: stackTrace,
      );
      return const <PostModel>[];
    }
  }

  Future<List<EventModel>> getEventsFeed() async {
    try {
      final snap =
          await _db.collection('events').orderBy('date').limit(50).get();
      return snap.docs
          .map((d) => EventModel.fromDoc(d.id, d.data()))
          .toList(growable: false);
    } catch (error, stackTrace) {
      logFirestoreError(
        context: 'dashboard.events fetch',
        error: error,
        stackTrace: stackTrace,
      );
      return const <EventModel>[];
    }
  }

  Future<void> toggleLike(
    String postId,
    String userId,
    bool currentlyLiked,
  ) async {
    final ref = _db.collection('posts').doc(postId);
    if (currentlyLiked) {
      await ref.update({
        'likes': FieldValue.arrayRemove([userId]),
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([userId]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }
}
