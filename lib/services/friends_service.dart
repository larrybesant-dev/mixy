import '../models/friend_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsService {
  final _usersRef = FirebaseFirestore.instance.collection('users');

  Future<void> addFriend(String userId, Friend friend) async {
    await _usersRef.doc(userId).collection('friends').doc(friend.friendId).set(friend.toMap());
  }

  Future<void> removeFriend(String userId, String friendId) async {
    await _usersRef.doc(userId).collection('friends').doc(friendId).delete();
  }

  Stream<List<Friend>> streamFriends(String userId) {
    return _usersRef.doc(userId).collection('friends').snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => Friend.fromMap(doc.data())).toList());
  }

  /// Block a user from interactions
  Future<void> blockUser(String userId, String blockedUserId) async {
    if (userId.isEmpty || blockedUserId.isEmpty || userId == blockedUserId) {
      return;
    }

    // Update blocker's blockedUserIds
    await _usersRef.doc(userId).update({
      'blockedUserIds': FieldValue.arrayUnion([blockedUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update blocked user's blockedByUserIds
    await _usersRef.doc(blockedUserId).update({
      'blockedByUserIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unblock a previously blocked user
  Future<void> unblockUser(String userId, String unblockedUserId) async {
    if (userId.isEmpty || unblockedUserId.isEmpty) {
      return;
    }

    // Update blocker's blockedUserIds
    await _usersRef.doc(userId).update({
      'blockedUserIds': FieldValue.arrayRemove([unblockedUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update unblocked user's blockedByUserIds
    await _usersRef.doc(unblockedUserId).update({
      'blockedByUserIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check if a user has blocked another user
  Future<bool> isUserBlocked(String userId, String targetUserId) async {
    if (userId.isEmpty || targetUserId.isEmpty) {
      return false;
    }

    final snapshot = await _usersRef.doc(userId).get();
    if (!snapshot.exists) return false;

    final data = snapshot.data() ?? {};
    final blockedIds = (data['blockedUserIds'] as List?)?.cast<String>() ?? [];
    return blockedIds.contains(targetUserId);
  }

  /// Get list of users blocked by a user
  Future<List<String>> getBlockedUsers(String userId) async {
    if (userId.isEmpty) return [];

    final snapshot = await _usersRef.doc(userId).get();
    if (!snapshot.exists) return [];

    final data = snapshot.data() ?? {};
    return (data['blockedUserIds'] as List?)?.cast<String>() ?? [];
  }

  /// Get list of users who have blocked a user
  Future<List<String>> getBlockedByUsers(String userId) async {
    if (userId.isEmpty) return [];

    final snapshot = await _usersRef.doc(userId).get();
    if (!snapshot.exists) return [];

    final data = snapshot.data() ?? {};
    return (data['blockedByUserIds'] as List?)?.cast<String>() ?? [];
  }

  /// Stream blocked users (real-time)
  Stream<List<String>> streamBlockedUsers(String userId) {
    return _usersRef.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data() ?? {};
      return (data['blockedUserIds'] as List?)?.cast<String>() ?? [];
    });
  }

  /// Stream users who have blocked a user (real-time)
  Stream<List<String>> streamBlockedByUsers(String userId) {
    return _usersRef.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data() ?? {};
      return (data['blockedByUserIds'] as List?)?.cast<String>() ?? [];
    });
  }
}
