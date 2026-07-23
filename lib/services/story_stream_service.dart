import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/query_policy.dart';

class StoryStreamService {
  StoryStreamService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFollowingStories({
    required String userId,
    required List<String> followingIds,
  }) {
    return _firestore
        .collectionGroup('stories')
        .where(
          'userId',
          whereIn: followingIds.isNotEmpty ? followingIds : <String>[userId],
        )
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt', descending: true)
        .limit(QueryPolicy.trendingPostsLimit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserStories(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}
