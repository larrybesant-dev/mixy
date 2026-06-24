import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/models/room_role.dart';
import 'package:mixmingle/shared/models/room_event.dart';
import 'package:mixmingle/shared/models/chat_message.dart';
import 'package:mixmingle/features/room/providers/room_subcollection_providers.dart';

/// Service for room moderation actions (kick, ban, mute, role changes)
class RoomModerationService {
  final RoomSubcollectionRepository _repository;
  final FirebaseFirestore _firestore;

  RoomModerationService(this._repository, this._firestore);

  /// Check if a user can moderate (owner or admin)
  Future<bool> canModerate({
    required String roomId,
    required String userId,
  }) async {
    final room = await _firestore.collection('rooms').doc(roomId).get();
    if (!room.exists) return false;

    final data = room.data()!;
    final hostId = data['hostId'] as String;
    final admins = (data['admins'] as List<dynamic>?)?.cast<String>() ?? [];

    return userId == hostId || admins.contains(userId);
  }

  /// Check if a user is the room owner
  Future<bool> isOwner({
    required String roomId,
    required String userId,
  }) async {
    final room = await _firestore.collection('rooms').doc(roomId).get();
    if (!room.exists) return false;

    final data = room.data()!;
    final hostId = data['hostId'] as String;

    return userId == hostId;
  }

  /// Kick a user from the room
  Future<void> kickUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    String? reason,
  }) async {
    // Verify moderator permissions
    final canMod = await canModerate(roomId: roomId, userId: moderatorId);
    if (!canMod) {
      throw Exception('Insufficient permissions to kick users');
    }

    // Remove participant
    await _repository.removeParticipant(roomId: roomId, userId: targetUserId);

    // Log event
    await _repository.logEvent(
      roomId: roomId,
      event: RoomEvent.kicked(
        moderatorId: moderatorId,
        userId: targetUserId,
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );

    // Add system message
    final participantDoc = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(targetUserId)
        .get();

    final targetName = participantDoc.exists
        ? (participantDoc.data()?['displayName'] as String? ?? 'User')
        : 'User';

    await _repository.sendMessage(
      roomId: roomId,
      message: ChatMessage.system(
        content: '$targetName was kicked${reason != null ? ": $reason" : ""}',
        roomId: roomId,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Ban a user from the room
  Future<void> banUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    String? reason,
  }) async {
    // Verify moderator permissions
    final canMod = await canModerate(roomId: roomId, userId: moderatorId);
    if (!canMod) {
      throw Exception('Insufficient permissions to ban users');
    }

    // Get target name before removal
    final participantDoc = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(targetUserId)
        .get();

    final targetName = participantDoc.exists
        ? (participantDoc.data()?['displayName'] as String? ?? 'User')
        : 'User';

    // Update participant role to banned (keeps record)
    await _repository.updateParticipant(
      roomId: roomId,
      userId: targetUserId,
      updates: {'role': RoomRole.banned.name},
    );

    // Log event
    await _repository.logEvent(
      roomId: roomId,
      event: RoomEvent.banned(
        moderatorId: moderatorId,
        userId: targetUserId,
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );

    // Add system message
    await _repository.sendMessage(
      roomId: roomId,
      message: ChatMessage.system(
        content: '$targetName was banned${reason != null ? ": $reason" : ""}',
        roomId: roomId,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Mute a user in the room
  Future<void> muteUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    String? reason,
  }) async {
    // Verify moderator permissions
    final canMod = await canModerate(roomId: roomId, userId: moderatorId);
    if (!canMod) {
      throw Exception('Insufficient permissions to mute users');
    }

    // Update participant
    await _repository.updateParticipant(
      roomId: roomId,
      userId: targetUserId,
      updates: {
        'role': RoomRole.muted.name,
        'isMuted': true,
      },
    );

    // Log event
    await _repository.logEvent(
      roomId: roomId,
      event: RoomEvent.muted(
        moderatorId: moderatorId,
        userId: targetUserId,
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );
  }

  /// Unmute a user in the room
  Future<void> unmuteUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
  }) async {
    // Verify moderator permissions
    final canMod = await canModerate(roomId: roomId, userId: moderatorId);
    if (!canMod) {
      throw Exception('Insufficient permissions to unmute users');
    }

    // Update participant
    await _repository.updateParticipant(
      roomId: roomId,
      userId: targetUserId,
      updates: {
        'role': RoomRole.member.name,
        'isMuted': false,
      },
    );

    // Log event
    await _repository.logEvent(
      roomId: roomId,
      event: RoomEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: RoomEventType.unmuted,
        actorId: moderatorId,
        targetId: targetUserId,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Change a user's role
  Future<void> changeUserRole({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
    required RoomRole newRole,
  }) async {
    // Verify moderator permissions (must be owner to change roles)
    final isRoomOwner = await isOwner(roomId: roomId, userId: moderatorId);
    if (!isRoomOwner) {
      throw Exception('Only room owner can change user roles');
    }

    // Cannot change owner's own role
    if (moderatorId == targetUserId) {
      throw Exception('Cannot change your own role');
    }

    // Get current role
    final participantDoc = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(targetUserId)
        .get();

    final oldRole = participantDoc.exists
        ? (participantDoc.data()?['role'] as String? ?? 'member')
        : 'member';

    // Update participant role
    await _repository.updateParticipant(
      roomId: roomId,
      userId: targetUserId,
      updates: {'role': newRole.name},
    );

    // If promoting to admin, add to room admins list
    if (newRole == RoomRole.admin) {
      await _firestore.collection('rooms').doc(roomId).update({
        'admins': FieldValue.arrayUnion([targetUserId]),
      });
    } else {
      // If demoting from admin, remove from room admins list
      await _firestore.collection('rooms').doc(roomId).update({
        'admins': FieldValue.arrayRemove([targetUserId]),
      });
    }

    // Log event
    await _repository.logEvent(
      roomId: roomId,
      event: RoomEvent.roleChanged(
        moderatorId: moderatorId,
        userId: targetUserId,
        oldRole: oldRole,
        newRole: newRole.name,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Check if user is banned from room
  Future<bool> isUserBanned({
    required String roomId,
    required String userId,
  }) async {
    final participantDoc = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userId)
        .get();

    if (!participantDoc.exists) return false;

    final role = participantDoc.data()?['role'] as String?;
    return role == RoomRole.banned.name;
  }

  /// Unban a user (owner only)
  Future<void> unbanUser({
    required String roomId,
    required String moderatorId,
    required String targetUserId,
  }) async {
    // Verify owner permissions
    final isRoomOwner = await isOwner(roomId: roomId, userId: moderatorId);
    if (!isRoomOwner) {
      throw Exception('Only room owner can unban users');
    }

    // Update participant role back to member
    await _repository.updateParticipant(
      roomId: roomId,
      userId: targetUserId,
      updates: {'role': RoomRole.member.name},
    );
  }
}

/// Moderation service provider
final roomModerationServiceProvider = Provider<RoomModerationService>((ref) {
  final repository = ref.watch(roomSubcollectionRepositoryProvider);
  final firestore = FirebaseFirestore.instance;
  return RoomModerationService(repository, firestore);
});

// ---------------------------------------------------------------------------
// Types required by voice_room_moderation_widget.dart
// ---------------------------------------------------------------------------

/// Moderation action enum
enum ModerationAction {
  warn,
  mute,
  kick,
  ban,
  unban,
}

/// Moderation log model (lightweight, Firestore-backed)
class ModerationLog {
  final String id;
  final String roomId;
  final String moderatorId;
  final String targetUserId;
  final ModerationAction action;
  final String reason;
  final DateTime timestamp;
  final Duration? duration;

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

  Map<String, dynamic> toFirestore() => {
        'roomId': roomId,
        'moderatorId': moderatorId,
        'targetUserId': targetUserId,
        'action': action.index,
        'reason': reason,
        'timestamp': Timestamp.fromDate(timestamp),
        if (duration != null) 'duration': duration!.inSeconds,
      };
}

/// Stream of moderation logs for a room
final moderationLogsProvider =
    StreamProvider.family<List<ModerationLog>, String>((ref, roomId) {
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('rooms')
      .doc(roomId)
      .collection('moderation_logs')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(ModerationLog.fromFirestore).toList());
});

/// Stream of muted user IDs for a room
final mutedUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('rooms')
      .doc(roomId)
      .collection('muted_users')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toList());
});

/// Stream of banned user IDs for a room
final bannedUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('rooms')
      .doc(roomId)
      .collection('banned_users')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toList());
});
