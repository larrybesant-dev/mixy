import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';

import '../../../services/notification_service.dart';
import '../controllers/room_state.dart';
import '../models/room_theme_model.dart';
import 'room_firestore_provider.dart';

class HostControls {
  HostControls(this._db);

  final FirebaseFirestore _db;

  bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) {
    return _db.collection('rooms').doc(roomId);
  }

  DocumentReference<Map<String, dynamic>> _policyRef(String roomId) {
    return _roomRef(roomId).collection('policies').doc('settings');
  }

  Future<void> toggleSlowMode(String roomId, int seconds) {
    return _roomRef(roomId).update({'slowModeSeconds': seconds});
  }

  Future<void> toggleLockRoom(String roomId) async {
    final roomRef = _roomRef(roomId);
    final snapshot = await roomRef.get();
    final currentValue = _asBool(snapshot.data()?['isLocked'], fallback: false);
    await roomRef.update({'isLocked': !currentValue});
  }

  Future<void> toggleAllowChat(String roomId) async {
    final policyRef = _policyRef(roomId);
    final snapshot = await policyRef.get();
    final currentValue = _asBool(snapshot.data()?['allowChat'], fallback: true);
    await policyRef.set({'allowChat': !currentValue}, SetOptions(merge: true));
  }

  Future<void> toggleAllowCamRequests(String roomId) async {
    final policyRef = _policyRef(roomId);
    final snapshot = await policyRef.get();
    final currentValue = _asBool(
      snapshot.data()?['allowCamRequests'],
      fallback: true,
    );
    await policyRef.set({
      'allowCamRequests': !currentValue,
    }, SetOptions(merge: true));
  }

  Future<void> toggleAllowMicRequests(String roomId) async {
    final policyRef = _policyRef(roomId);
    final snapshot = await policyRef.get();
    final currentValue = _asBool(
      snapshot.data()?['allowMicRequests'],
      fallback: true,
    );
    await policyRef.set({
      'allowMicRequests': !currentValue,
    }, SetOptions(merge: true));
  }

  Future<void> toggleAllowGifts(String roomId) async {
    final policyRef = _policyRef(roomId);
    final snapshot = await policyRef.get();
    final currentValue = _asBool(
      snapshot.data()?['allowGifts'],
      fallback: true,
    );
    await policyRef.set({'allowGifts': !currentValue}, SetOptions(merge: true));
  }

  Future<void> muteUser(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'isMuted': true});
    _modLog(roomId, action: 'mute', actorId: actorId, targetId: userId);
  }

  Future<void> unmuteUser(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'isMuted': false});
    _modLog(roomId, action: 'unmute', actorId: actorId, targetId: userId);
  }

  Future<void> banUser(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'isBanned': true});
    _modLog(roomId, action: 'ban', actorId: actorId, targetId: userId);
  }

  Future<void> unbanUser(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'isBanned': false});
    _modLog(roomId, action: 'unban', actorId: actorId, targetId: userId);
  }

  Future<void> promoteToCohost(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'role': 'cohost'});
    _modLog(
      roomId,
      action: 'promote_cohost',
      actorId: actorId,
      targetId: userId,
    );
  }

  Future<void> promoteToModerator(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'role': 'moderator'});
    AppTelemetry.logAction(
      domain: 'ownership',
      action: 'promote_moderator',
      message: 'Moderator promotion applied.',
      roomId: roomId,
      userId: actorId,
      result: 'success',
      metadata: <String, Object?>{'targetUserId': userId},
    );
    _modLog(
      roomId,
      action: 'promote_moderator',
      actorId: actorId,
      targetId: userId,
    );
  }

  Future<void> promoteToTrustedSpeaker(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'role': 'trusted_speaker'});
    _modLog(
      roomId,
      action: 'promote_trusted_speaker',
      actorId: actorId,
      targetId: userId,
    );
  }

  Future<void> demoteToAudience(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).update({'role': 'audience'});
    _modLog(
      roomId,
      action: 'demote_audience',
      actorId: actorId,
      targetId: userId,
    );
  }

  /// Pushes [userId] onto the shared speaker list for the room.
  Future<void> inviteToMic(String roomId, String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError('A valid user is required to invite to mic.');
    }

    final roomSnapshot = await _roomRef(roomId).get();
    final rawMaxSpeakers = roomSnapshot.data()?['maxSpeakers'];
    final maxSpeakers = rawMaxSpeakers is num
        ? rawMaxSpeakers.toInt().clamp(1, 4)
        : 4;
    final speakersSnapshot = await _roomRef(
      roomId,
    ).collection('speakers').get();
    final alreadySpeaker = speakersSnapshot.docs.any(
      (doc) => doc.id == normalizedUserId,
    );
    if (!alreadySpeaker && speakersSnapshot.docs.length >= maxSpeakers) {
      throw StateError('The stage already has $maxSpeakers speakers.');
    }

    final participantSnapshot = await _participantRef(
      roomId,
      normalizedUserId,
    ).get();
    final role = normalizeRoomRole(
      _asString(participantSnapshot.data()?['role'], fallback: roomRoleStage),
      fallbackRole: roomRoleStage,
    );
    final participantRole = canManageStageRole(role) ? role : roomRoleStage;

    final batch = _db.batch();
    batch.set(_roomRef(roomId), {
      'maxSpeakers': maxSpeakers,
      'speakerSyncVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // NOTE: speakers subcollection is server-only (Cloud Function: inviteToMic).
    // Client writes are explicitly denied by Firestore rules.
    batch.set(_participantRef(roomId, normalizedUserId), {
      'userId': normalizedUserId,
      'role': participantRole,
      'micOn': true,
      'isMuted': false,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Force-releases [userId] from the stage mic while preserving staff roles.
  Future<void> forceReleaseMic(String roomId, String userId) async {
    final normalizedUserId = userId.trim();
    final participantSnapshot = await _participantRef(
      roomId,
      normalizedUserId,
    ).get();
    final currentRole = normalizeRoomRole(
      _asString(
        participantSnapshot.data()?['role'],
        fallback: roomRoleAudience,
      ),
      fallbackRole: roomRoleAudience,
    );
    final nextRole = canModerateRole(currentRole) ? currentRole : 'member';

    final batch = _db.batch();
    // NOTE: speakers subcollection is server-only (Cloud Function: grabMic).
    // Client writes are explicitly denied by Firestore rules.
    batch.set(_roomRef(roomId), {
      'maxSpeakers': 4,
      'speakerSyncVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_participantRef(roomId, normalizedUserId), {
      'userId': normalizedUserId,
      'role': nextRole,
      'micOn': false,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    _modLog(
      roomId,
      action: 'force_release_mic',
      actorId: '',
      targetId: normalizedUserId,
    );
  }

  Future<void> removeUser(
    String roomId,
    String userId, {
    String actorId = '',
  }) async {
    await _participantRef(roomId, userId).delete();
    _modLog(roomId, action: 'kick', actorId: actorId, targetId: userId);
  }

  Future<void> transferHost({
    required String roomId,
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId.trim().isEmpty || toUserId.trim().isEmpty) {
      throw ArgumentError('Host transfer requires valid user IDs.');
    }
    if (fromUserId == toUserId) {
      throw ArgumentError('Host transfer target must be a different user.');
    }

    final roomSnapshot = await _roomRef(roomId).get();
    if (!roomSnapshot.exists) {
      throw StateError('Room not found.');
    }
    final currentHostId = _asString(roomSnapshot.data()?['hostId']);
    if (currentHostId != fromUserId) {
      throw StateError('Only the current room host can transfer ownership.');
    }

    final targetParticipantSnapshot = await _participantRef(
      roomId,
      toUserId,
    ).get();
    final targetIsBanned = _asBool(
      targetParticipantSnapshot.data()?['isBanned'],
      fallback: false,
    );
    if (targetIsBanned) {
      throw StateError(
        'Cannot transfer host ownership to a banned participant.',
      );
    }

    final batch = _db.batch();
    final roomRef = _roomRef(roomId);
    batch.update(roomRef, {
      'hostId': toUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_participantRef(roomId, toUserId), {
      'userId': toUserId,
      'role': 'host',
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_participantRef(roomId, fromUserId), {
      'userId': fromUserId,
      'role': 'cohost',
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    AppTelemetry.logAction(
      level: 'warning',
      domain: 'ownership',
      action: 'host_transfer',
      message: 'Room host ownership transferred.',
      roomId: roomId,
      userId: fromUserId,
      result: 'success',
      metadata: <String, Object?>{'toUserId': toUserId},
    );

    final notifier = NotificationService(firestore: _db);
    await notifier.inAppNotification(
      toUserId,
      'You are now the room host for room $roomId.',
    );
    await notifier.inAppNotification(
      fromUserId,
      'You transferred room ownership to $toUserId.',
    );
  }

  DocumentReference<Map<String, dynamic>> _participantRef(
    String roomId,
    String userId,
  ) {
    return _roomRef(roomId).collection('participants').doc(userId);
  }

  /// Writes a single mod-action entry to `rooms/{roomId}/mod_log`.
  /// Fire-and-forget — failures are silently swallowed so they never
  /// interrupt the primary moderation write.
  void _modLog(
    String roomId, {
    required String action,
    required String actorId,
    String? targetId,
    Map<String, dynamic>? meta,
  }) {
    final entry = <String, dynamic>{
      'action': action,
      'actorId': actorId,
      'targetId': ?targetId,
      'ts': FieldValue.serverTimestamp(),
      if (meta != null) ...meta,
    };
    _roomRef(roomId)
        .collection('mod_log')
        .add(entry)
        // ignore: avoid_types_on_closure_parameters
        .catchError((Object _) => _roomRef(roomId).collection('mod_log').doc());
  }

  // ── Stage / mic-seat controls ──────────────────────────────────────────────

  /// Sets how many broadcasters (mic seats) can be on stage simultaneously.
  ///
  /// Updates both the room doc (`maxBroadcasters`) and the policy doc
  /// (`micLimit`) so the slot service and mic-queue logic stay in sync.
  Future<void> setMaxBroadcasters(String roomId, int max) async {
    if (max < 1 || max > 4) {
      throw ArgumentError('maxBroadcasters must be between 1 and 4.');
    }
    final batch = _db.batch();
    batch.update(_roomRef(roomId), {
      'maxBroadcasters': max,
      'maxSpeakers': max,
      'speakerSyncVersion': 1,
    });
    batch.set(_policyRef(roomId), {
      'micLimit': max,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Force-clears a specific broadcaster slot by removing the participant's
  /// active broadcaster slot document so the seat becomes available immediately.
  Future<void> clearBroadcasterSlot(String roomId, String userId) async {
    await _roomRef(roomId).collection('slots').doc(userId).delete();
  }

  /// Fetch current participants ordered by lastActiveAt descending.
  Future<List<Map<String, dynamic>>> getParticipants(String roomId) async {
    final snap = await _roomRef(roomId)
        .collection('participants')
        .orderBy('lastActiveAt', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Marks the room as ended (isLive: false). Only the room owner should call
  /// this; access control is enforced by Firestore rules.
  Future<void> endRoom(String roomId) async {
    await _roomRef(roomId).update({
      'isLive': false,
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates editable room metadata (name, description, category). Null fields
  /// are left unchanged. Empty strings clear the field.
  Future<void> setRoomInfo(
    String roomId, {
    String? name,
    String? description,
    String? category,
  }) async {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) {
      throw ArgumentError('Room name cannot be blank.');
    }
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (trimmedName != null) updates['name'] = trimmedName;
    if (description != null) updates['description'] = description.trim();
    if (category != null) {
      final c = category.trim().toLowerCase();
      if (c.isEmpty) {
        updates['category'] = FieldValue.delete();
      } else {
        updates['category'] = c;
      }
    }
    await _roomRef(roomId).update(updates);
  }

  /// Applies a new [RoomTheme] to the room document. The UI merges the
  /// `theme` sub-map so other top-level fields are not touched.
  Future<void> updateRoomTheme(String roomId, RoomTheme theme) async {
    await _roomRef(roomId).update({
      'theme': theme.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resets the room theme to the application default by clearing the stored
  /// theme sub-map.
  Future<void> resetRoomTheme(String roomId) async {
    await _roomRef(roomId).update({
      'theme': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final hostControlsProvider = Provider<HostControls>(
  (ref) => HostControls(ref.watch(roomFirestoreProvider)),
);
