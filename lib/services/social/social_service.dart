import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/following.dart';
import '../../shared/models/user.dart';
import '../analytics/analytics_service.dart';

/// Service for handling social features like following/unfollowing users
class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;

  SocialService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsService _analytics = AnalyticsService();

  /// Follow a user
  Future<void> followUser(String followerId, String followingId) async {
    if (followerId == followingId) {
      throw Exception('Cannot follow yourself');
    }

    final relationshipId = Following.createId(followerId, followingId);

    // Check if already following
    final existingDoc =
        await _firestore.collection('followings').doc(relationshipId).get();

    if (existingDoc.exists) {
      throw Exception('Already following this user');
    }

    // Create following relationship
    final following = Following(
      id: relationshipId,
      followerId: followerId,
      followingId: followingId,
      createdAt: DateTime.now(),
    );

    // Use batch write to ensure atomicity
    final batch = _firestore.batch();

    // Add following relationship
    batch.set(
      _firestore.collection('followings').doc(relationshipId),
      following.toMap(),
    );

    // Increment follower's following count
    batch.update(
      _firestore.collection('users').doc(followerId),
      {'followingCount': FieldValue.increment(1)},
    );

    // Increment following's follower count
    batch.update(
      _firestore.collection('users').doc(followingId),
      {'followersCount': FieldValue.increment(1)},
    );

    await batch.commit();

    // Track analytics
    _analytics.trackEngagement('user_followed', parameters: {
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  /// Unfollow a user
  Future<void> unfollowUser(String followerId, String followingId) async {
    final relationshipId = Following.createId(followerId, followingId);

    // Check if following exists
    final doc =
        await _firestore.collection('followings').doc(relationshipId).get();

    if (!doc.exists) {
      throw Exception('Not following this user');
    }

    // Use batch write to ensure atomicity
    final batch = _firestore.batch();

    // Remove following relationship
    batch.delete(_firestore.collection('followings').doc(relationshipId));

    // Decrement follower's following count
    batch.update(
      _firestore.collection('users').doc(followerId),
      {'followingCount': FieldValue.increment(-1)},
    );

    // Decrement following's follower count
    batch.update(
      _firestore.collection('users').doc(followingId),
      {'followersCount': FieldValue.increment(-1)},
    );

    await batch.commit();

    // Track analytics
    _analytics.trackEngagement('user_unfollowed', parameters: {
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  /// Check if user A is following user B
  Future<bool> isFollowing(String followerId, String followingId) async {
    final relationshipId = Following.createId(followerId, followingId);
    final doc =
        await _firestore.collection('followings').doc(relationshipId).get();
    return doc.exists;
  }

  /// Get followers of a user
  Future<List<User>> getFollowers(String userId) async {
    final querySnapshot = await _firestore
        .collection('followings')
        .where('followingId', isEqualTo: userId)
        .get();

    final followerIds = querySnapshot.docs
        .map((doc) => doc.data()['followerId'] as String)
        .toList();

    if (followerIds.isEmpty) return [];

    // Get user details for followers
    final usersQuery = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: followerIds)
        .get();

    return usersQuery.docs.map((doc) => User.fromMap(doc.data())).toList();
  }

  /// Get users that a user is following
  Future<List<User>> getFollowing(String userId) async {
    final querySnapshot = await _firestore
        .collection('followings')
        .where('followerId', isEqualTo: userId)
        .get();

    final followingIds = querySnapshot.docs
        .map((doc) => doc.data()['followingId'] as String)
        .toList();

    if (followingIds.isEmpty) return [];

    // Get user details for following
    final usersQuery = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: followingIds)
        .get();

    return usersQuery.docs.map((doc) => User.fromMap(doc.data())).toList();
  }

  /// Get mutual followers (users who follow each other)
  Future<List<User>> getMutualFollowers(String userId) async {
    final followers = await getFollowers(userId);
    final following = await getFollowing(userId);

    final followingIds = following.map((user) => user.id).toSet();
    return followers
        .where((follower) => followingIds.contains(follower.id))
        .toList();
  }

  /// Get follower count for a user
  Future<int> getFollowerCount(String userId) async {
    final querySnapshot = await _firestore
        .collection('followings')
        .where('followingId', isEqualTo: userId)
        .count()
        .get();
    return querySnapshot.count ?? 0;
  }

  /// Get following count for a user
  Future<int> getFollowingCount(String userId) async {
    final querySnapshot = await _firestore
        .collection('followings')
        .where('followerId', isEqualTo: userId)
        .count()
        .get();
    return querySnapshot.count ?? 0;
  }

  /// Get stream of followers for real-time updates
  Stream<List<User>> getFollowersStream(String userId) {
    return _firestore
        .collection('followings')
        .where('followingId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final followerIds = snapshot.docs
          .map((doc) => doc.data()['followerId'] as String)
          .toList();

      if (followerIds.isEmpty) return [];

      final usersQuery = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: followerIds)
          .get();

      return usersQuery.docs.map((doc) => User.fromMap(doc.data())).toList();
    });
  }

  /// Get stream of following for real-time updates
  Stream<List<User>> getFollowingStream(String userId) {
    return _firestore
        .collection('followings')
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final followingIds = snapshot.docs
          .map((doc) => doc.data()['followingId'] as String)
          .toList();

      if (followingIds.isEmpty) return [];

      final usersQuery = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: followingIds)
          .get();

      return usersQuery.docs.map((doc) => User.fromMap(doc.data())).toList();
    });
  }
}
