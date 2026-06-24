import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for room moderation actions
/// Handles kicking, muting, banning, and role management
class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Toggle participant audio (mute/unmute)
  Future<void> toggleParticipantAudio({
    required String roomId,
    required String participantId,
    required bool mute,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(participantId)
        .update({
      'hasAudio': !mute,
      'forceMuted': mute,
      'mutedAt': mute ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Toggle participant video (enable/disable)
  Future<void> toggleParticipantVideo({
    required String roomId,
    required String participantId,
    required bool disable,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(participantId)
        .update({
      'hasVideo': !disable,
      'forceVideoOff': disable,
      'videoDisabledAt': disable ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Kick participant from room (can rejoin)
  Future<void> kickParticipant({
    required String roomId,
    required String participantId,
  }) async {
    final batch = _firestore.batch();

    // Remove from active participants
    final participantRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(participantId);
    batch.delete(participantRef);

    // Add kick record
    final kickRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_log')
        .doc();
    batch.set(kickRef, {
      'action': 'kick',
      'participantId': participantId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Decrement participant count
    final roomRef = _firestore.collection('rooms').doc(roomId);
    batch.update(roomRef, {
      'participantCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  /// Ban participant from room (cannot rejoin)
  Future<void> banParticipant({
    required String roomId,
    required String participantId,
  }) async {
    final batch = _firestore.batch();

    // Remove from active participants
    final participantRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(participantId);
    batch.delete(participantRef);

    // Add to banned list
    final bannedRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('banned_users')
        .doc(participantId);
    batch.set(bannedRef, {
      'bannedAt': FieldValue.serverTimestamp(),
      'reason': 'Banned by moderator',
    });

    // Add ban record
    final banLogRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_log')
        .doc();
    batch.set(banLogRef, {
      'action': 'ban',
      'participantId': participantId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Decrement participant count
    final roomRef = _firestore.collection('rooms').doc(roomId);
    batch.update(roomRef, {
      'participantCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  /// Promote participant to co-host
  Future<void> promoteToCoHost({
    required String roomId,
    required String participantId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(participantId)
        .update({
      'role': 'coHost',
      'promotedAt': FieldValue.serverTimestamp(),
    });

    // Add promotion record
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_log')
        .add({
      'action': 'promote',
      'participantId': participantId,
      'newRole': 'coHost',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Demote co-host to listener
  Future<void> demoteToListener({
    required String roomId,
    required String participantId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(participantId)
        .update({
      'role': 'listener',
      'demotedAt': FieldValue.serverTimestamp(),
    });

    // Add demotion record
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_log')
        .add({
      'action': 'demote',
      'participantId': participantId,
      'newRole': 'listener',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Check if user is banned from room
  Future<bool> isUserBanned({
    required String roomId,
    required String userId,
  }) async {
    final doc = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('banned_users')
        .doc(userId)
        .get();
    return doc.exists;
  }

  /// Unban user from room
  Future<void> unbanUser({
    required String roomId,
    required String userId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('banned_users')
        .doc(userId)
        .delete();

    // Add unban record
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_log')
        .add({
      'action': 'unban',
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get moderation log for room
  Stream<List<Map<String, dynamic>>> getModerationLog(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moderation_log')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Get banned users list
  Stream<List<String>> getBannedUsers(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('banned_users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}

/// Provider for room-level moderation service (participant controls)
final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService();
});
