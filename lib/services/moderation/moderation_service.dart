import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/report.dart';
import '../../shared/models/moderation.dart';

/// Service for user blocking and reporting
class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ BLOCKING ============

  /// Block a user
  Future<void> blockUser(String blockerId, String blockedUserId,
      {String? reason}) async {
    try {
      final blockId = '${blockerId}_$blockedUserId';

      await _firestore.collection('blocks').doc(blockId).set({
        'blockerId': blockerId,
        'blockedUserId': blockedUserId,
        'blockedAt': FieldValue.serverTimestamp(),
        'reason': reason,
      });

      // Update user's blocked list
      await _firestore.collection('users').doc(blockerId).update({
        'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
      });
    } catch (e) {
      debugPrint('Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String blockerId, String blockedUserId) async {
    try {
      final blockId = '${blockerId}_$blockedUserId';

      await _firestore.collection('blocks').doc(blockId).delete();

      // Update user's blocked list
      await _firestore.collection('users').doc(blockerId).update({
        'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
      });
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Check if user is blocked
  Future<bool> isUserBlocked(String blockerId, String blockedUserId) async {
    try {
      final blockId = '${blockerId}_$blockedUserId';
      final doc = await _firestore.collection('blocks').doc(blockId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Get blocked users list
  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      return List<String>.from(data?['blockedUsers'] ?? []);
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  // ============ REPORTING ============

  /// Report a user
  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    String? messageId,
    String? roomId,
    required ReportType type,
    required String description,
  }) async {
    try {
      final reportRef = _firestore.collection('reports').doc();

      final report = UserReport(
        id: reportRef.id,
        reporterId: reporterId,
        reportedUserId: reportedUserId,
        reportedMessageId: messageId,
        reportedRoomId: roomId,
        type: type,
        description: description,
        createdAt: DateTime.now(),
      );

      await reportRef.set(report.toMap());
    } catch (e) {
      debugPrint('Error reporting user: $e');
      rethrow;
    }
  }

  /// Get pending reports (for moderators)
  Future<List<UserReport>> getPendingReports({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => UserReport.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending reports: $e');
      return [];
    }
  }

  /// Review a report (for moderators)
  Future<void> reviewReport(
      String reportId, String reviewerId, String action) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'reviewed',
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'action': action,
      });
    } catch (e) {
      debugPrint('Error reviewing report: $e');
      rethrow;
    }
  }

  // ============ READ RECEIPTS ============

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId, String userId) async {
    try {
      await _firestore
          .collection('read_receipts')
          .doc('${messageId}_$userId')
          .set({
        'messageId': messageId,
        'userId': userId,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  /// Get read receipts for a message
  Future<List<ReadReceipt>> getReadReceipts(String messageId) async {
    try {
      final snapshot = await _firestore
          .collection('read_receipts')
          .where('messageId', isEqualTo: messageId)
          .get();

      return snapshot.docs
          .map((doc) => ReadReceipt.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting read receipts: $e');
      return [];
    }
  }

  /// Check if message was read by user
  Future<bool> isMessageRead(String messageId, String userId) async {
    try {
      final doc = await _firestore
          .collection('read_receipts')
          .doc('${messageId}_$userId')
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if message is read: $e');
      return false;
    }
  }

  // ============ PROVIDER-EXPECTED METHODS ============

  /// Ban user (admin action)
  Future<void> banUser(String moderatorId, String userId, String reason,
      Duration duration) async {
    try {
      final banUntil = DateTime.now().add(duration);

      await _firestore.collection('bans').add({
        'moderatorId': moderatorId,
        'userId': userId,
        'reason': reason,
        'bannedAt': FieldValue.serverTimestamp(),
        'banUntil': Timestamp.fromDate(banUntil),
        'isActive': true,
      });

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'isBanned': true,
        'banReason': reason,
        'banUntil': Timestamp.fromDate(banUntil),
      });

      debugPrint('User banned: $userId');
    } catch (e) {
      debugPrint('Error banning user: $e');
      rethrow;
    }
  }

  /// Unban user
  Future<void> unbanUser(String moderatorId, String userId) async {
    try {
      // Update ban documents
      final bansQuery = await _firestore
          .collection('bans')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in bansQuery.docs) {
        await doc.reference.update({
          'isActive': false,
          'unbannedBy': moderatorId,
          'unbannedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'isBanned': false,
        'banReason': FieldValue.delete(),
        'banUntil': FieldValue.delete(),
      });

      debugPrint('User unbanned: $userId');
    } catch (e) {
      debugPrint('Error unbanning user: $e');
      rethrow;
    }
  }

  /// Submit report (alias for reportUser)
  /// Submit report
  Future<void> submitReport(Report report) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': report.reporterId,
        'reportedUserId': report.reportedUserId,
        'reportedMessageId': report.reportedMessageId,
        'reportedRoomId': report.reportedRoomId,
        'type': report.type,
        'description': report.description,
        'status': report.status.toString().split('.').last,
        'createdAt': report.createdAt,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error submitting report: $e');
      rethrow;
    }
  }

  // ============ ROOM MODERATION (AUDIO/VIDEO) ============

  /// Lock or unlock all microphones in a room
  Future<void> lockAllMics({required String roomId, required bool locked}) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'allMicsLocked': locked,
        'micLockedAt': locked ? FieldValue.serverTimestamp() : null,
      });
      debugPrint('All mics ${locked ? 'locked' : 'unlocked'} in room: $roomId');
    } catch (e) {
      debugPrint('Error managing mic locks: $e');
      rethrow;
    }
  }

  /// Lock or unlock all cameras in a room
  Future<void> lockAllCameras({required String roomId, required bool locked}) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'allCamerasLocked': locked,
        'cameraLockedAt': locked ? FieldValue.serverTimestamp() : null,
      });
      debugPrint('All cameras ${locked ? 'locked' : 'unlocked'} in room: $roomId');
    } catch (e) {
      debugPrint('Error managing camera locks: $e');
      rethrow;
    }
  }

  /// Mute all participants in a room
  Future<void> muteAllParticipants({required String roomId}) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'allParticipantsMuted': true,
        'mutedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('All participants muted in room: $roomId');
    } catch (e) {
      debugPrint('Error muting all participants: $e');
      rethrow;
    }
  }

  /// Unmute all participants in a room
  Future<void> unmuteAllParticipants({required String roomId}) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'allParticipantsMuted': false,
      });
      debugPrint('All participants unmuted in room: $roomId');
    } catch (e) {
      debugPrint('Error unmuting all participants: $e');
      rethrow;
    }
  }
}
