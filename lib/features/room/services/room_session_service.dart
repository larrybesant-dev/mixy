import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_debug_tracing.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../../../services/moderation_service.dart';
import '../../../services/presence_controller.dart';
import '../providers/room_firestore_provider.dart';

class RoomJoinResult {
  const RoomJoinResult._({
    required this.isSuccess,
    this.errormessage,
    this.joinedAt,
    this.excludedUserIds = const <String>{},
  });

  const RoomJoinResult.success({
    required DateTime joinedAt,
    Set<String> excludedUserIds = const <String>{},
  }) : this._(
         isSuccess: true,
         joinedAt: joinedAt,
         excludedUserIds: excludedUserIds,
       );

  const RoomJoinResult.failure(
    String errormessage, {
    Set<String> excludedUserIds = const <String>{},
  }) : this._(
         isSuccess: false,
         errormessage: errormessage,
         excludedUserIds: excludedUserIds,
       );

  final bool isSuccess;
  final String? errormessage;
  final DateTime? joinedAt;
  final Set<String> excludedUserIds;
}

final roomSessionServiceProvider = Provider<RoomSessionService>((ref) {
  return RoomSessionService(
    firestore: ref.watch(roomFirestoreProvider),
    presenceController: ref.read(presenceControllerProvider.notifier),
  );
});

class RoomSessionService {
  RoomSessionService({
    required FirebaseFirestore firestore,
    required PresenceController presenceController,
  }) : _firestore = firestore,
       _presenceController = presenceController;

  static const Duration participantSyncInterval = Duration(seconds: 30);

  final FirebaseFirestore _firestore;
  final PresenceController _presenceController;

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
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

  Future<RoomJoinResult> joinRoom({
    required String roomId,
    required String userId,
    String? displayName,
    String? photoUrl,
    Transaction? transaction,
  }) async {
    final normalizedRoomId = roomId.trim();
    final normalizedUserId = userId.trim();
    final normalizedDisplayName = displayName?.trim() ?? '';
    final normalizedPhotoUrl = photoUrl?.trim() ?? '';
    if (normalizedRoomId.isEmpty || normalizedUserId.isEmpty) {
      return const RoomJoinResult.failure(
        'Could not join room. Please try again.',
      );
    }

    AppTelemetry.updateRoomState(
      roomId: normalizedRoomId,
      joinedUserId: normalizedUserId,
      roomPhase: 'joining',
      roomError: null,
    );
    AppTelemetry.logAction(
      domain: 'room',
      action: 'join',
      message: 'Attempting room join.',
      roomId: normalizedRoomId,
      userId: normalizedUserId,
      result: 'start',
    );

    final now = DateTime.now();
    final roomDoc = await traceFirestoreRead(
      path: 'rooms/$normalizedRoomId',
      operation: 'get_room_for_join',
      roomId: normalizedRoomId,
      userId: normalizedUserId,
      action: () => _firestore.collection('rooms').doc(normalizedRoomId).get(),
    );
    if (!roomDoc.exists) {
      AppTelemetry.updateRoomState(
        roomId: normalizedRoomId,
        joinedUserId: null,
        roomPhase: 'error',
        roomError: 'This room no longer exists.',
      );
      return const RoomJoinResult.failure('This room no longer exists.');
    }

    final ownerId = _asString(
      roomDoc.data()?['ownerId'],
      fallback: _asString(roomDoc.data()?['hostId']),
    );
    final moderationService = ModerationService(firestore: _firestore);
    final excludedUserIds = await moderationService.getExcludedUserIds(
      normalizedUserId,
    );

    if (ownerId.isNotEmpty) {
      final hasBlockingRelationship = await moderationService
          .hasBlockingRelationship(normalizedUserId, ownerId);
      if (hasBlockingRelationship) {
        return RoomJoinResult.failure(
          'You cannot join this room.',
          excludedUserIds: excludedUserIds,
        );
      }
    }

    if (excludedUserIds.isNotEmpty) {
      final participantsRef = _firestore
          .collection('rooms')
          .doc(normalizedRoomId)
          .collection('participants');
      final participantsSnapshot = await traceFirestoreRead(
        path: 'rooms/$normalizedRoomId/participants',
        operation: 'get_room_participants_for_join',
        roomId: normalizedRoomId,
        userId: normalizedUserId,
        action: participantsRef.get,
      );
      final hasBlockedParticipant = participantsSnapshot.docs.any((doc) {
        final participantData = doc.data();
        final participantId = _asString(
          participantData['userId'],
          fallback: doc.id,
        );
        return participantId.isNotEmpty &&
            participantId != normalizedUserId &&
            excludedUserIds.contains(participantId);
      });
      if (hasBlockedParticipant) {
        return RoomJoinResult.failure(
          'You cannot join while a blocked user is in this room.',
          excludedUserIds: excludedUserIds,
        );
      }
    }

    final isLocked = _asBool(roomDoc.data()?['isLocked']);
    if (isLocked) {
      return RoomJoinResult.failure(
        'Room is locked by host.',
        excludedUserIds: excludedUserIds,
      );
    }

    final participantRef = _firestore
        .collection('rooms')
        .doc(normalizedRoomId)
        .collection('participants')
        .doc(normalizedUserId);
    final memberRef = _firestore
        .collection('rooms')
        .doc(normalizedRoomId)
        .collection('members')
        .doc(normalizedUserId);
    await traceFirestoreRead(
      path: 'rooms/$normalizedRoomId/participants/$normalizedUserId',
      operation: 'get_current_participant',
      roomId: normalizedRoomId,
      userId: normalizedUserId,
      action: participantRef.get,
    );

    final isHostUser = ownerId == normalizedUserId;

    try {
      Future<void> executeJoin(Transaction tx) async {
        final roomSnap = await tx.get(
          _firestore.collection('rooms').doc(normalizedRoomId),
        );
        if (!roomSnap.exists) {
          throw StateError('Room no longer exists');
        }

        final roomData = roomSnap.data()!;
        final audienceIds = List<String>.from(roomData['audienceUserIds'] ?? []);
        final stageIds = List<String>.from(roomData['stageUserIds'] ?? []);

        if (!audienceIds.contains(normalizedUserId) &&
            !stageIds.contains(normalizedUserId)) {
          audienceIds.add(normalizedUserId);
        }

        final currentParticipantSnap = await tx.get(participantRef);

        if (currentParticipantSnap.exists) {
          final pData = currentParticipantSnap.data()!;
          if (pData['isBanned'] == true) {
            throw StateError('You are banned from this room.');
          }

          tx.set(participantRef, {
            'userId': normalizedUserId,
            'camOn': false,
            'lastActiveAt': now,
            'userStatus': 'online',
            if (normalizedDisplayName.isNotEmpty)
              'displayName': normalizedDisplayName,
            if (normalizedPhotoUrl.isNotEmpty) 'photoUrl': normalizedPhotoUrl,
          }, SetOptions(merge: true));
        } else {
          final participantRole = isHostUser ? 'host' : 'audience';
          tx.set(participantRef, {
            'userId': normalizedUserId,
            'role': participantRole,
            'isMuted': false,
            'isBanned': false,
            'camOn': false,
            'userStatus': 'online',
            if (normalizedDisplayName.isNotEmpty)
              'displayName': normalizedDisplayName,
            if (normalizedPhotoUrl.isNotEmpty) 'photoUrl': normalizedPhotoUrl,
            'joinedAt': now,
            'lastActiveAt': now,
          });
        }

        tx.set(memberRef, {
          'userId': normalizedUserId,
          'role': isHostUser ? 'owner' : 'member',
          'joinedAt': currentParticipantSnap.exists
              ? (currentParticipantSnap.data()!['joinedAt'] ?? now)
              : now,
          'lastActiveAt': now,
          if (normalizedDisplayName.isNotEmpty)
            'displayName': normalizedDisplayName,
          if (normalizedPhotoUrl.isNotEmpty) 'photoUrl': normalizedPhotoUrl,
        }, SetOptions(merge: true));

        tx.update(_firestore.collection('rooms').doc(normalizedRoomId), {
          'audienceUserIds': audienceIds,
          'memberCount': audienceIds.length + stageIds.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (transaction != null) {
        await executeJoin(transaction);
      } else {
        await _firestore.runTransaction(executeJoin);
      }
    } catch (e, _) {
      AppTelemetry.logAction(
        domain: 'room',
        action: 'join_transaction_failed',
        message: 'Transaction failed: $e',
        roomId: normalizedRoomId,
        userId: normalizedUserId,
        result: 'error',
      );
      AppTelemetry.updateRoomState(
        roomId: normalizedRoomId,
        joinedUserId: normalizedUserId,
        roomPhase: 'error',
        roomError: 'Failed to join room: ${e.toString()}',
      );
      return RoomJoinResult.failure('Failed to join room. Please try again.');
    }

    await _presenceController.setInRoom(normalizedUserId, normalizedRoomId);
    AppTelemetry.updateRoomState(
      roomId: normalizedRoomId,
      joinedUserId: normalizedUserId,
      roomPhase: 'joined',
      roomError: null,
      inRoom: normalizedRoomId,
    );
    AppTelemetry.logAction(
      domain: 'room',
      action: 'join',
      message: 'Room join completed.',
      roomId: normalizedRoomId,
      userId: normalizedUserId,
      result: 'success',
    );
    return RoomJoinResult.success(
      joinedAt: now,
      excludedUserIds: excludedUserIds,
    );
  }

  Future<void> leaveRoom({
    required String roomId,
    required String userId,
    Transaction? transaction,
  }) async {
    final normalizedRoomId = roomId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedRoomId.isEmpty || normalizedUserId.isEmpty) {
      return;
    }

    final roomRef = _firestore.collection('rooms').doc(normalizedRoomId);
    final participantRef = roomRef.collection('participants').doc(normalizedUserId);
    final memberRef = roomRef.collection('members').doc(normalizedUserId);

    Future<void> executeLeave(Transaction tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) return;

      final roomData = roomSnap.data()!;
      final audienceIds = List<String>.from(roomData['audienceUserIds'] ?? []);
      final stageIds = List<String>.from(roomData['stageUserIds'] ?? []);

      audienceIds.remove(normalizedUserId);
      stageIds.remove(normalizedUserId);

      tx.delete(participantRef);
      tx.delete(memberRef);

      tx.update(roomRef, {
        'audienceUserIds': audienceIds,
        'stageUserIds': stageIds,
        'memberCount': audienceIds.length + stageIds.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      if (transaction != null) {
        await executeLeave(transaction);
      } else {
        await _firestore.runTransaction(executeLeave);
      }
    } finally {
      await _presenceController.clearInRoom(normalizedUserId);
      AppTelemetry.logAction(
        domain: 'room',
        action: 'leave',
        message: 'Room leave cleanup completed.',
        roomId: normalizedRoomId,
        userId: normalizedUserId,
        result: 'success',
      );
    }
  }

  Future<DateTime> heartbeat({
    required String roomId,
    required String userId,
    DateTime? lastParticipantSyncAt,
    bool forceParticipantSync = false,
  }) async {
    final now = DateTime.now();

    // Throttle heartbeat writes to avoid overwhelming the write channel.
    if (!forceParticipantSync &&
        lastParticipantSyncAt != null &&
        now.difference(lastParticipantSyncAt) < participantSyncInterval) {
      return lastParticipantSyncAt;
    }

    await traceFirestoreWrite<void>(
      path: 'rooms/$roomId/participants/$userId',
      operation: 'room_heartbeat',
      roomId: roomId,
      userId: userId,
      action: () => _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(userId)
          .update({'lastActiveAt': now}),
    );

    return now;
  }

  Future<void> setCustomStatus({
    required String roomId,
    required String userId,
    required String? status,
  }) {
    return Future<void>.value();
  }

  Future<void> postSystemEvent({
    required String roomId,
    required String content,
  }) {
    return Future<void>.value();
  }

  Future<void> setTyping({
    required String roomId,
    required String userId,
    required bool isTyping,
  }) async {
    final typingRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('typing')
        .doc(userId);

    if (isTyping) {
      await typingRef.set({
        'isTyping': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await typingRef.delete();
    }
  }

  Future<void> setSpotlightUser({
    required String roomId,
    required String? userId,
  }) async {
    await traceFirestoreWrite<void>(
      path: 'rooms/$roomId',
      operation: 'set_spotlight_user',
      roomId: roomId,
      userId: userId,
      metadata: <String, Object?>{'spotlightUserId': userId},
      action: () => _firestore.collection('rooms').doc(roomId).update({
        'spotlightUserId': userId == null || userId.trim().isEmpty
            ? FieldValue.delete()
            : userId.trim(),
      }),
    );
  }
}

