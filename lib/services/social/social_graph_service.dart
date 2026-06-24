import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/user_profile.dart';

class SocialGraphService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Follow a user
  Future<void> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');
    if (currentUser.uid == targetUserId) {
      throw Exception('Cannot follow yourself');
    }

    final batch = _firestore.batch();

    // Add to current user's following
    batch.set(
      _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId),
      {
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    // Add to target user's followers
    batch.set(
      _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.uid),
      {
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    // Update counters
    batch.update(
      _firestore.collection('users').doc(currentUser.uid),
      {'followingCount': FieldValue.increment(1)},
    );

    batch.update(
      _firestore.collection('users').doc(targetUserId),
      {'followersCount': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  /// Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final batch = _firestore.batch();

    // Remove from current user's following
    batch.delete(
      _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(targetUserId),
    );

    // Remove from target user's followers
    batch.delete(
      _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUser.uid),
    );

    // Update counters
    batch.update(
      _firestore.collection('users').doc(currentUser.uid),
      {'followingCount': FieldValue.increment(-1)},
    );

    batch.update(
      _firestore.collection('users').doc(targetUserId),
      {'followersCount': FieldValue.increment(-1)},
    );

    await batch.commit();
  }

  /// Check if current user is following a target user
  Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .get();

    return doc.exists;
  }

  /// Stream to watch if current user is following a target user
  Stream<bool> watchIsFollowing(String targetUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Get list of follower user IDs
  Future<List<String>> getFollowers(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Stream follower user IDs
  Stream<List<String>> watchFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Get list of following user IDs
  Future<List<String>> getFollowing(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Stream following user IDs
  Stream<List<String>> watchFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Get mutual friends (users who follow each other)
  Future<List<String>> getMutualFriends(String userId) async {
    final followers = await getFollowers(userId);
    final following = await getFollowing(userId);

    return followers.where((id) => following.contains(id)).toList();
  }

  /// Stream mutual friends
  Stream<List<String>> watchMutualFriends(String userId) {
    return watchFollowers(userId).asyncMap((followers) async {
      final following = await getFollowing(userId);
      return followers.where((id) => following.contains(id)).toList();
    });
  }

  /// Get follower count
  Future<int> getFollowerCount(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return (doc.data()?['followersCount'] as int?) ?? 0;
  }

  /// Get following count
  Future<int> getFollowingCount(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return (doc.data()?['followingCount'] as int?) ?? 0;
  }

  /// Get suggested users (users with similar interests, not followed by current user)
  Future<List<UserProfile>> getSuggestedUsers({int limit = 20}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get current user's profile
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!currentUserDoc.exists) return [];

      final currentUserData = currentUserDoc.data()!;
      final currentUserInterests =
          (currentUserData['interests'] as List<dynamic>?)?.cast<String>() ??
              [];

      // Get users current user is following
      final following = await getFollowing(currentUser.uid);

      // Query users with similar interests
      final usersSnapshot = await _firestore
          .collection('users')
          .where('id', isNotEqualTo: currentUser.uid)
          .limit(100)
          .get();

      final suggestions = <UserProfile>[];

      for (final doc in usersSnapshot.docs) {
        final userId = doc.id;

        // Skip if already following
        if (following.contains(userId)) continue;

        final data = doc.data();
        data['id'] = userId;

        final profile = UserProfile.fromMap(data);

        // Calculate similarity score based on interests
        final userInterests = profile.interests ?? [];
        final commonInterests =
            currentUserInterests.where((i) => userInterests.contains(i)).length;

        // Only include users with at least one common interest or nearby location
        if (commonInterests > 0 || _isNearby(currentUserData, data)) {
          suggestions.add(profile);
        }

        if (suggestions.length >= limit) break;
      }

      // Sort by number of common interests (descending)
      suggestions.sort((a, b) {
        final aCommon = currentUserInterests
            .where((i) => (a.interests ?? []).contains(i))
            .length;
        final bCommon = currentUserInterests
            .where((i) => (b.interests ?? []).contains(i))
            .length;
        return bCommon.compareTo(aCommon);
      });

      return suggestions.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Helper to check if users are nearby
  bool _isNearby(
      Map<String, dynamic> user1Data, Map<String, dynamic> user2Data) {
    final lat1 = user1Data['latitude'] as double?;
    final lon1 = user1Data['longitude'] as double?;
    final lat2 = user2Data['latitude'] as double?;
    final lon2 = user2Data['longitude'] as double?;

    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return false;
    }

    // Simple distance check (approximately 50km)
    final latDiff = (lat1 - lat2).abs();
    final lonDiff = (lon1 - lon2).abs();

    return latDiff < 0.5 && lonDiff < 0.5;
  }
}
