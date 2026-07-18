import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_history_models.dart';

class MatchHistoryService {
  MatchHistoryService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Record a profile view
  Future<void> recordProfileView({
    required String viewerId,
    required String viewedUserId,
    String? context,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(viewedUserId)
          .collection('profileViews')
          .add({
            'viewerId': viewerId,
            'viewedUserId': viewedUserId,
            'createdAt': FieldValue.serverTimestamp(),
            'context': context,
          });
    } catch (e) {
      // Silently fail - not critical
    }
  }

  /// Get profile views for current user (who viewed your profile)
  Stream<List<ProfileView>> getProfileViewsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('profileViews')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ProfileView.fromFirestore(doc))
              .toList();
        });
  }

  /// Get swipe history (all likes and passes)
  Stream<List<SwipeHistory>> getSwipeHistoryStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('discovery')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final isLike = doc['isLike'] as bool? ?? false;
            final candidateId = doc.id;
            final createdAt =
                (doc['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return SwipeHistory(
              id: doc.id,
              userId: userId,
              candidateId: candidateId,
              isLike: isLike,
              createdAt: createdAt,
              isMutual: doc['isMutual'] as bool? ?? false,
            );
          }).toList();
        });
  }

  /// Get mutual matches (people who liked you back)
  Stream<List<String>> getMutualMatchesStream(String userId) {
    // Derive from the canonical swipe stream to avoid duplicate discovery listeners.
    return getSwipeHistoryStream(userId).map((entries) {
      return entries
          .where((entry) => entry.isMutual)
          .map((entry) => entry.candidateId)
          .toList(growable: false);
    });
  }

  /// Get people who liked you but you haven't responded to
  Future<List<String>> getWhoLikedYou(String userId) async {
    try {
      // Query all swipes where candidateId is userId and isLike is true
      final snapshot = await _firestore
          .collectionGroup('discovery')
          .where('candidateId', isEqualTo: userId)
          .where('isLike', isEqualTo: true)
          .get();

      final likerIds = <String>{};
      for (final doc in snapshot.docs) {
        final userId = doc.reference.parent.parent?.id;
        if (userId != null && userId.isNotEmpty) {
          likerIds.add(userId);
        }
      }

      return likerIds.toList();
    } catch (e) {
      return [];
    }
  }

  /// Get count of people who liked you
  Future<int> getLikeCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('discovery')
          .where('candidateId', isEqualTo: userId)
          .where('isLike', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Mark a like as "viewed" (seen the profile)
  Future<void> markLikeAsViewed(
    String userId,
    String likerId,
  ) async {
    try {
      // This would be implemented if you add a viewed flag to track
      // which "who liked you" profiles the user has seen
    } catch (e) {
      // Silently fail
    }
  }
}
