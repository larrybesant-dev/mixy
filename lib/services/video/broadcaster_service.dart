import 'package:mixvy/core/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/broadcaster_queue.dart';
import '../user/profile_service.dart';

/// Service to manage broadcaster queue and recording
class BroadcasterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();

  /// Request to become a broadcaster
  /// Returns queue entry with position in queue
  Future<BroadcasterQueue> requestBroadcast(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      // Get current user profile for name and photo
      final profile = await _profileService.getUserProfile(user.uid);

      // Check current queue status for this user
      final existingDoc = await _firestore
          .collection(AppConstants.roomsCollection)
          .doc(roomId)
          .collection('broadcasterQueue')
          .doc(user.uid)
          .get();

      // If already in queue, return existing
      if (existingDoc.exists) {
        final data = existingDoc.data()!;
        final position = await _getQueuePosition(roomId, user.uid);
        return BroadcasterQueue(
          id: user.uid,
          userId: user.uid,
          userName: profile?.displayName ?? user.email ?? 'User',
          userPhotoUrl: profile?.photoUrl,
          requestedAt: (data['requestedAt'] as Timestamp).toDate(),
          status: data['status'] ?? 'pending',
          queuePosition: position,
        );
      }

      // Get current queue length
      final queueSnapshot = await _firestore
          .collection(AppConstants.roomsCollection)
          .doc(roomId)
          .collection('broadcasterQueue')
          .where('status', whereIn: ['pending', 'approved']).get();

      final queuePosition = queueSnapshot.docs.length;

      // Create new queue entry
      final queueEntry = BroadcasterQueue(
        id: user.uid,
        userId: user.uid,
        userName: profile?.displayName ?? user.email ?? 'User',
        userPhotoUrl: profile?.photoUrl,
        requestedAt: DateTime.now(),
        status: 'pending',
        queuePosition: queuePosition,
      );

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .doc(user.uid)
          .set(queueEntry.toFirestore());

      debugPrint(
          'ðŸ“¡ Broadcaster request submitted. Queue position: $queuePosition');

      return queueEntry;
    } catch (e) {
      debugPrint('âŒ Failed to request broadcast: $e');
      rethrow;
    }
  }

  /// Cancel broadcaster request
  Future<void> cancelBroadcastRequest(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .doc(user.uid)
          .delete();

      debugPrint('âŒ Broadcast request cancelled');
    } catch (e) {
      debugPrint('âŒ Failed to cancel request: $e');
      rethrow;
    }
  }

  /// Get queue position for a user
  Future<int> _getQueuePosition(String roomId, String userId) async {
    final snapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('broadcasterQueue')
        .orderBy('requestedAt', descending: false)
        .get();

    return snapshot.docs.indexWhere((doc) => doc.id == userId) + 1;
  }

  /// Get broadcaster queue for a room
  Future<List<BroadcasterQueue>> getBroadcasterQueue(String roomId) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .orderBy('requestedAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => BroadcasterQueue.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      debugPrint('âŒ Failed to get broadcaster queue: $e');
      return [];
    }
  }

  /// Stream broadcaster queue changes
  Stream<List<BroadcasterQueue>> streamBroadcasterQueue(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('broadcasterQueue')
        .orderBy('requestedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BroadcasterQueue.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    });
  }

  /// Get current user's queue status
  Future<BroadcasterQueue?> getCurrentUserQueueStatus(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;

      return BroadcasterQueue.fromJson({
        'id': user.uid,
        ...doc.data()!,
      });
    } catch (e) {
      debugPrint('âŒ Failed to get queue status: $e');
      return null;
    }
  }

  /// Update broadcaster status (called by Cloud Function or admin)
  Future<void> updateBroadcasterStatus(
    String roomId,
    String userId,
    String newStatus,
  ) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .doc(userId)
          .update({
        'status': newStatus,
        if (newStatus == 'approved') 'approvedAt': Timestamp.now(),
        if (newStatus == 'broadcasting') 'broadcastStartedAt': Timestamp.now(),
        if (newStatus == 'pending') 'broadcastEndedAt': Timestamp.now(),
      });

      debugPrint('âœ… Broadcaster status updated: $newStatus');
    } catch (e) {
      debugPrint('âŒ Failed to update status: $e');
      rethrow;
    }
  }

  /// Approve next in queue (called when broadcaster goes offline)
  Future<BroadcasterQueue?> approveNextInQueue(String roomId) async {
    try {
      final queue = await getBroadcasterQueue(roomId);

      // Find first pending
      final nextPending = queue.firstWhere(
        (item) => item.status == 'pending',
        orElse: () => null as dynamic,
      ) as BroadcasterQueue?;

      if (nextPending == null) {
        debugPrint('ðŸ“­ No pending broadcasts in queue');
        return null;
      }

      await updateBroadcasterStatus(
        roomId,
        nextPending.userId,
        'approved',
      );

      debugPrint('âœ… Approved broadcaster: ${nextPending.userName}');
      return nextPending;
    } catch (e) {
      debugPrint('âŒ Failed to approve next: $e');
      return null;
    }
  }

  /// Get count of active broadcasters
  Future<int> getActiveBroadcasterCount(String roomId) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .where('status', whereIn: ['approved', 'broadcasting']).get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('âŒ Failed to get broadcaster count: $e');
      return 0;
    }
  }

  /// Start recording broadcast (requires Agora Composite Recording)
  /// Call this when user starts broadcasting
  Future<void> startRecording(String roomId, String userId) async {
    try {
      // This would be called via Cloud Function in production
      // The function uses Agora REST API to start composite recording

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .doc(userId)
          .update({
        'broadcastStartedAt': Timestamp.now(),
        'isRecording': true,
        'recordingStartedAt': Timestamp.now(),
      });

      debugPrint('ðŸŽ¥ Recording started for broadcast: $userId');
    } catch (e) {
      debugPrint('âŒ Failed to start recording: $e');
      rethrow;
    }
  }

  /// Stop recording broadcast
  /// Call this when user stops broadcasting
  Future<void> stopRecording(String roomId, String userId) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .doc(userId)
          .update({
        'broadcastEndedAt': Timestamp.now(),
        'isRecording': false,
        'recordingEndedAt': Timestamp.now(),
      });

      debugPrint('â¹ï¸ Recording stopped for broadcast: $userId');
    } catch (e) {
      debugPrint('âŒ Failed to stop recording: $e');
      rethrow;
    }
  }

  /// Get count of pending broadcasts in queue
  Future<int> getPendingBroadcastCount(String roomId) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('broadcasterQueue')
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('âŒ Failed to get pending count: $e');
      return 0;
    }
  }
}

