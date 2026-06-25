// lib/services/social/friend_service.dart
//
// Full Firestore-backed Friend System
//
// Firestore layout:
//   /friendRequests/{requestId}        — top-level for cross-user queries
//   /users/{uid}/friendRequests/{requestId}  — per-user inbox / outbox
//   /users/{uid}/friends/{friendUid}   — accepted friend list
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/friend_request.dart';

class FriendService {
  FriendService._();
  static final FriendService instance = FriendService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ── Private helpers ────────────────────────────────────────────────────────

  DocumentReference _globalReqRef(String requestId) =>
      _db.collection('friendRequests').doc(requestId);

  CollectionReference _userReqCol(String uid) =>
      _db.collection('users').doc(uid).collection('friendRequests');

  CollectionReference _friendsCol(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  // ── Send ───────────────────────────────────────────────────────────────────

  /// Sends a friend request TO [receiverId].
  /// No-ops if a pending request already exists in either direction.
  Future<void> sendFriendRequest({
    required String receiverId,
    String? receiverName,
    String? receiverAvatarUrl,
  }) async {
    if (_uid.isEmpty || _uid == receiverId) return;

    // De-duplicate guard —  check existing pending in both directions
    final existing = await _db
        .collection('friendRequests')
        .where('senderId', isEqualTo: _uid)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final alreadyFriend = await _friendsCol(_uid).doc(receiverId).get();
    if (alreadyFriend.exists) return;

    final me = _auth.currentUser;
    final newRef = _db.collection('friendRequests').doc();

    final payload = FriendRequest(
      requestId: newRef.id,
      senderId: _uid,
      receiverId: receiverId,
      status: FriendRequestStatus.pending,
      timestamp: DateTime.now(),
      senderName: me?.displayName,
      senderAvatarUrl: me?.photoURL,
      receiverName: receiverName,
      receiverAvatarUrl: receiverAvatarUrl,
    ).toMap();

    final batch = _db.batch();
    // Global doc
    batch.set(newRef, payload);
    // Sender's outbox
    batch.set(_userReqCol(_uid).doc(newRef.id), payload);
    // Receiver's inbox
    batch.set(_userReqCol(receiverId).doc(newRef.id), payload);

    await batch.commit();
    debugPrint('[FriendService] sendFriendRequest → $receiverId (${newRef.id})');
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────

  Future<void> cancelFriendRequest(String requestId,
      {required String receiverId}) async {
    final batch = _db.batch();
    batch.delete(_globalReqRef(requestId));
    batch.delete(_userReqCol(_uid).doc(requestId));
    batch.delete(_userReqCol(receiverId).doc(requestId));
    await batch.commit();
    debugPrint('[FriendService] cancelled request $requestId');
  }

  // ── Accept ─────────────────────────────────────────────────────────────────

  Future<void> acceptFriendRequest(String requestId,
      {required String senderId}) async {
    final me = _auth.currentUser;
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();

    // Update status on all copies
    final update = {'status': 'accepted', 'acceptedAt': now};
    batch.update(_globalReqRef(requestId), update);
    batch.update(_userReqCol(_uid).doc(requestId), update);
    batch.update(_userReqCol(senderId).doc(requestId), update);

    // Add bidirectional friend entries
    batch.set(_friendsCol(_uid).doc(senderId), {
      'since': now,
      'displayName': null, // UI can update from user profile
      'avatarUrl': null,
    });
    batch.set(_friendsCol(senderId).doc(_uid), {
      'since': now,
      'displayName': me?.displayName,
      'avatarUrl': me?.photoURL,
    });

    await batch.commit();
    debugPrint('[FriendService] accepted request $requestId from $senderId');
  }

  // ── Decline ────────────────────────────────────────────────────────────────

  Future<void> declineFriendRequest(String requestId,
      {required String senderId}) async {
    final update = {'status': 'declined', 'declinedAt': FieldValue.serverTimestamp()};
    final batch = _db.batch();
    batch.update(_globalReqRef(requestId), update);
    batch.update(_userReqCol(_uid).doc(requestId), update);
    batch.update(_userReqCol(senderId).doc(requestId), update);
    await batch.commit();
    debugPrint('[FriendService] declined request $requestId');
  }

  // ── Unfriend ───────────────────────────────────────────────────────────────

  Future<void> unfriend(String targetUid) async {
    final batch = _db.batch();
    batch.delete(_friendsCol(_uid).doc(targetUid));
    batch.delete(_friendsCol(targetUid).doc(_uid));
    await batch.commit();
    debugPrint('[FriendService] unfriended $targetUid');
  }

  /// Alias for [unfriend] — removes a friend from current user's friend list.
  /// Used by UI when user clicks "remove friend" button.
  Future<void> removeFriend(String friendUid) async {
    return unfriend(friendUid);
  }

  /// Accept a friend request from [senderId] by finding the pending request.
  /// Simplification of [acceptFriendRequest] that doesn't require requestId.
  /// Used by UI when user clicks "Accept" on incoming friend request.
  Future<void> acceptFriendRequestFromUser(String senderId) async {
    final reqId = await incomingRequestId(senderId);
    if (reqId == null) {
      debugPrint('[FriendService] No pending request from $senderId');
      return;
    }
    // Call the full accept flow with the found requestId
    final me = _auth.currentUser;
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();

    // Update status on all copies
    final update = {'status': 'accepted', 'acceptedAt': now};
    batch.update(_globalReqRef(reqId), update);
    batch.update(_userReqCol(_uid).doc(reqId), update);
    batch.update(_userReqCol(senderId).doc(reqId), update);

    // Add bidirectional friend entries
    batch.set(_friendsCol(_uid).doc(senderId), {
      'since': now,
      'displayName': null,
      'avatarUrl': null,
    });
    batch.set(_friendsCol(senderId).doc(_uid), {
      'since': now,
      'displayName': me?.displayName,
      'avatarUrl': me?.photoURL,
    });

    await batch.commit();
    debugPrint('[FriendService] accepted request $reqId from $senderId');
  }

  /// Reject/decline a friend request from [senderId] by finding the pending request.
  /// Simplification of [declineFriendRequest] that doesn't require requestId.
  /// Used by UI when user clicks "Decline" on incoming friend request.
  Future<void> rejectFriendRequestFromUser(String senderId) async {
    final reqId = await incomingRequestId(senderId);
    if (reqId == null) {
      debugPrint('[FriendService] No pending request from $senderId');
      return;
    }
    final update = {'status': 'declined', 'declinedAt': FieldValue.serverTimestamp()};
    final batch = _db.batch();
    batch.update(_globalReqRef(reqId), update);
    batch.update(_userReqCol(_uid).doc(reqId), update);
    batch.update(_userReqCol(senderId).doc(reqId), update);
    await batch.commit();
    debugPrint('[FriendService] rejected request $reqId from $senderId');
  }

  // ── Auto-friend (e.g. speed dating mutual match) ───────────────────────────

  /// Silently auto-friends two users without going through request flow.
  Future<void> autoFriend(String userAUid, String userBUid) async {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.set(_friendsCol(userAUid).doc(userBUid), {'since': now});
    batch.set(_friendsCol(userBUid).doc(userAUid), {'since': now});
    await batch.commit();
    debugPrint('[FriendService] auto-friended $userAUid ↔ $userBUid');
  }

  // ── Blocking ───────────────────────────────────────────────────────────────

  /// Block a user from interactions
  Future<void> blockUser(String blockedUserId) async {
    if (_uid.isEmpty || blockedUserId.isEmpty || _uid == blockedUserId) {
      return;
    }

    // Create a block record at the top level
    final blockId = '${_uid}_$blockedUserId';
    await _db.collection('blocks').doc(blockId).set({
      'blockerUserId': _uid,
      'blockedUserId': blockedUserId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update blocker's blockedUserIds in user document
    await _db.collection('users').doc(_uid).update({
      'blockedUserIds': FieldValue.arrayUnion([blockedUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update blocked user's blockedByUserIds in user document
    await _db.collection('users').doc(blockedUserId).update({
      'blockedByUserIds': FieldValue.arrayUnion([_uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[FriendService] blocked user $blockedUserId');
  }

  /// Unblock a previously blocked user
  Future<void> unblockUser(String unblockedUserId) async {
    if (_uid.isEmpty || unblockedUserId.isEmpty) {
      return;
    }

    // Remove block record
    final blockId = '${_uid}_$unblockedUserId';
    await _db.collection('blocks').doc(blockId).delete();

    // Update blocker's blockedUserIds in user document
    await _db.collection('users').doc(_uid).update({
      'blockedUserIds': FieldValue.arrayRemove([unblockedUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update unblocked user's blockedByUserIds in user document
    await _db.collection('users').doc(unblockedUserId).update({
      'blockedByUserIds': FieldValue.arrayRemove([_uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[FriendService] unblocked user $unblockedUserId');
  }

  /// Check if current user has blocked another user
  Future<bool> isUserBlocked(String targetUserId) async {
    if (_uid.isEmpty || targetUserId.isEmpty) {
      return false;
    }

    final blockId = '${_uid}_$targetUserId';
    final snapshot = await _db.collection('blocks').doc(blockId).get();
    return snapshot.exists;
  }

  /// Get list of users blocked by current user
  Future<List<String>> getBlockedUsers() async {
    if (_uid.isEmpty) return [];

    final snapshot = await _db.collection('users').doc(_uid).get();
    if (!snapshot.exists) return [];

    final data = snapshot.data() ?? {};
    return (data['blockedUserIds'] as List?)?.cast<String>() ?? [];
  }

  /// Get list of users who have blocked current user
  Future<List<String>> getBlockedByUsers() async {
    if (_uid.isEmpty) return [];

    final snapshot = await _db.collection('users').doc(_uid).get();
    if (!snapshot.exists) return [];

    final data = snapshot.data() ?? {};
    return (data['blockedByUserIds'] as List?)?.cast<String>() ?? [];
  }

  /// Stream blocked users (real-time) for current user
  Stream<List<String>> streamBlockedUsers() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db.collection('users').doc(_uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data() ?? {};
      return (data['blockedUserIds'] as List?)?.cast<String>() ?? [];
    });
  }

  /// Stream users who have blocked current user (real-time)
  Stream<List<String>> streamBlockedByUsers() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db.collection('users').doc(_uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data() ?? {};
      return (data['blockedByUserIds'] as List?)?.cast<String>() ?? [];
    });
  }

  // ── State helpers ──────────────────────────────────────────────────────────

  Future<bool> isFriend(String targetUid) async {
    if (_uid.isEmpty) return false;
    final snap = await _friendsCol(_uid).doc(targetUid).get();
    return snap.exists;
  }

  Future<bool> isPending(String targetUid) async {
    if (_uid.isEmpty) return false;
    final snap = await _db
        .collection('friendRequests')
        .where('senderId', isEqualTo: _uid)
        .where('receiverId', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<bool> hasIncomingRequest(String targetUid) async {
    if (_uid.isEmpty) return false;
    final snap = await _db
        .collection('friendRequests')
        .where('senderId', isEqualTo: targetUid)
        .where('receiverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Returns the requestId if a pending request TO [targetUid] exists,
  /// else null.
  Future<String?> pendingRequestId(String targetUid) async {
    if (_uid.isEmpty) return null;
    final snap = await _db
        .collection('friendRequests')
        .where('senderId', isEqualTo: _uid)
        .where('receiverId', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  Future<String?> incomingRequestId(String targetUid) async {
    if (_uid.isEmpty) return null;
    final snap = await _db
        .collection('friendRequests')
        .where('senderId', isEqualTo: targetUid)
        .where('receiverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Real-time stream of current user's **incoming** pending requests.
  Stream<List<FriendRequest>> streamIncomingRequests() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db
        .collection('friendRequests')
        .where('receiverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FriendRequest.fromDoc(d)).toList());
  }

  /// Real-time stream of current user's **sent** pending requests.
  Stream<List<FriendRequest>> streamSentRequests() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db
        .collection('friendRequests')
        .where('senderId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FriendRequest.fromDoc(d)).toList());
  }

  /// Real-time stream of current user's friends.
  Stream<List<FriendEntry>> streamFriends([String? uid]) {
    final targetUid = uid ?? _uid;
    if (targetUid.isEmpty) return Stream.value([]);
    return _friendsCol(targetUid)
        .orderBy('since', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FriendEntry.fromDoc(d)).toList());
  }

  /// Live count of incoming pending friend requests (for badge).
  Stream<int> streamPendingCount() {
    if (_uid.isEmpty) return Stream.value(0);
    return _db
        .collection('friendRequests')
        .where('receiverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
