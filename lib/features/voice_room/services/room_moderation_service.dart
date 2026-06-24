import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Moderation action enum
enum ModerationAction {
  warn,
  mute,
  kick,
  ban,
  unban,
}

/// Moderation log model
class ModerationLog {
  final String id;
  final String roomId;
  final String moderatorId;
  final String targetUserId;
  final ModerationAction action;
  final String reason;
  final DateTime timestamp;
  final Duration? duration; // For temporary actions

  ModerationLog({
    required this.id,
    required this.roomId,
    required this.moderatorId,
    required this.targetUserId,
    required this.action,
    required this.reason,
    required this.timestamp,
    this.duration,
  });

  factory ModerationLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ModerationLog(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      moderatorId: data['moderatorId'] ?? '',
      targetUserId: data['targetUserId'] ?? '',
      action: ModerationAction.values[data['action'] ?? 0],
      reason: data['reason'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: data['duration'] != null
          ? Duration(seconds: data['duration'] as int)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'moderatorId': moderatorId,
      'targetUserId': targetUserId,
      'action': action.index,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
      'duration': duration?.inSeconds,
    };
  }
}

/// Room Moderation Service
class RoomModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Warn a user
  Future<void> warnUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    required String reason,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_logs')
        .add({
      'roomId': roomId,
      'moderatorId': moderatorId,
      'targetUserId': targetUserId,
      'action': ModerationAction.warn.index,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Mute a user
  Future<void> muteUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    required String reason,
    Duration? duration,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_logs')
        .add({
      'roomId': roomId,
      'moderatorId': moderatorId,
      'targetUserId': targetUserId,
      'action': ModerationAction.mute.index,
      'reason': reason,
      'duration': duration?.inSeconds,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update user's mute status in room
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('muted_users')
        .doc(targetUserId)
        .set({
      'muteTime': FieldValue.serverTimestamp(),
      'duration': duration?.inSeconds,
      'reason': reason,
    });
  }

  /// Unmute a user
  Future<void> unmuteUser(String roomId, String targetUserId) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('muted_users')
        .doc(targetUserId)
        .delete();
  }

  /// Kick a user from room
  Future<void> kickUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    required String reason,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_logs')
        .add({
      'roomId': roomId,
      'moderatorId': moderatorId,
      'targetUserId': targetUserId,
      'action': ModerationAction.kick.index,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Remove user from room
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(targetUserId)
        .delete();
  }

  /// Ban a user from room
  Future<void> banUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    required String reason,
    Duration? duration,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_logs')
        .add({
      'roomId': roomId,
      'moderatorId': moderatorId,
      'targetUserId': targetUserId,
      'action': ModerationAction.ban.index,
      'reason': reason,
      'duration': duration?.inSeconds,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Add to banned list
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('banned_users')
        .doc(targetUserId)
        .set({
      'banTime': FieldValue.serverTimestamp(),
      'duration': duration?.inSeconds,
      'reason': reason,
    });
  }

  /// Unban a user
  Future<void> unbanUser(String roomId, String targetUserId) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('banned_users')
        .doc(targetUserId)
        .delete();
  }

  /// Get moderation logs for a room
  Stream<List<ModerationLog>> getModerationLogsStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ModerationLog.fromFirestore(doc))
          .toList();
    });
  }

  /// Check if user is muted
  Future<bool> isUserMuted(String roomId, String userId) async {
    try {
      final doc = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('muted_users')
          .doc(userId)
          .get();

      if (!doc.exists) return false;

      final duration = doc['duration'] as int?;
      if (duration == null) return true; // Permanent mute

      final muteTime = (doc['muteTime'] as Timestamp).toDate();
      final muteExpiry = muteTime.add(Duration(seconds: duration));

      return DateTime.now().isBefore(muteExpiry);
    } catch (e) {
      return false;
    }
  }

  /// Check if user is banned
  Future<bool> isUserBanned(String roomId, String userId) async {
    try {
      final doc = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('banned_users')
          .doc(userId)
          .get();

      if (!doc.exists) return false;

      final duration = doc['duration'] as int?;
      if (duration == null) return true; // Permanent ban

      final banTime = (doc['banTime'] as Timestamp).toDate();
      final banExpiry = banTime.add(Duration(seconds: duration));

      return DateTime.now().isBefore(banExpiry);
    } catch (e) {
      return false;
    }
  }

  /// Get muted users in room
  Stream<List<String>> getMutedUsersStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('muted_users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  /// Get banned users in room
  Stream<List<String>> getBannedUsersStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('banned_users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }
}

/// Provider for Room Moderation Service
final roomModerationServiceProvider = Provider<RoomModerationService>((ref) {
  return RoomModerationService();
});

/// Provider for moderation logs
final moderationLogsProvider =
    StreamProvider.family<List<ModerationLog>, String>((ref, roomId) {
  final service = ref.watch(roomModerationServiceProvider);
  return service.getModerationLogsStream(roomId);
});

/// Provider for muted users
final mutedUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  final service = ref.watch(roomModerationServiceProvider);
  return service.getMutedUsersStream(roomId);
});

/// Provider for banned users
final bannedUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  final service = ref.watch(roomModerationServiceProvider);
  return service.getBannedUsersStream(roomId);
});
