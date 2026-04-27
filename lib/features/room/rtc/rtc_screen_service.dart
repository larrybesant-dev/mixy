import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import '../../../services/agora_service.dart';
import '../../../services/friend_service.dart';
import '../../../services/notification_service.dart';
import '../../../core/providers/firebase_providers.dart';
import '../controllers/room_state.dart';
import '../providers/room_firestore_provider.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  FirebaseFunctions? functions;
  try {
    functions = ref.watch(firebaseFunctionsProvider);
  } catch (_) {
    functions = null;
  }

  return RoomRepository(
    firestore: ref.watch(roomFirestoreProvider),
    functions: functions,
  );
});

class RoomUserLookup {
  const RoomUserLookup({
    this.profileUsername,
    this.avatarUrl,
    this.vipLevel = 0,
    this.gender,
  });

  final String? profileUsername;
  final String? avatarUrl;
  final int vipLevel;
  final String? gender;
}

class RoomRepository {
  RoomRepository({
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;

  static const List<Map<String, dynamic>> _fallbackIceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
    },
  ];

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) {
    return _firestore.collection('rooms').doc(roomId);
  }

  DocumentReference<Map<String, dynamic>> _participantRef(
    String roomId,
    String userId,
  ) {
    return _roomRef(roomId).collection('participants').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> _memberRef(
    String roomId,
    String userId,
  ) {
    return _roomRef(roomId).collection('members').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _speakerCollection(String roomId) {
    return _roomRef(roomId).collection('speakers');
  }

  DocumentReference<Map<String, dynamic>> _speakerRef(
    String roomId,
    String userId,
  ) {
    return _speakerCollection(roomId).doc(userId);
  }

  Future<List<Map<String, dynamic>>> fetchIceServers() async {
    final functions = _functions;
    if (functions == null) {
      return _fallbackIceServers;
    }

    try {
      final callable = functions.httpsCallable('generateTurnCredentials');
      final result = await callable.call<Map<String, dynamic>>({});
      final raw = result.data['iceServers'];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map<dynamic, dynamic>>()
            .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
    } catch (_) {
      // Cloud Function unavailable (offline / test env) — STUN only.
    }
    return _fallbackIceServers;
  }

  Future<({String token, String appId})> fetchAgoraToken({
    required String channelName,
    required int rtcUid,
    required String fallbackAppId,
  }) async {
    final functions = _functions;
    if (functions == null) {
      throw const AgoraServiceException(
        code: 'firebase-unavailable',
        message:
            'Live media backend is unavailable in this environment. Please try again in the app.',
      );
    }

    try {
      final callable = functions.httpsCallable('generateAgoraToken');
      final result = await callable.call<Map<String, dynamic>>({
        'channelName': channelName,
        'rtcUid': rtcUid,
      });
      final data = Map<String, dynamic>.from(result.data);
      final token = _asString(data['token']);
      final serverAppId = _asString(data['appId']);
      if (token.isEmpty) {
        throw const AgoraServiceException(
          code: 'agora-token-missing',
          message: 'Live media token is missing from backend response.',
        );
      }

      final resolvedAppId = serverAppId.isNotEmpty
          ? serverAppId
          : fallbackAppId.trim();
      if (resolvedAppId.length != 32) {
        throw const AgoraServiceException(
          code: 'agora-appid-invalid',
          message: 'AGORA_APP_ID is missing or invalid (expected 32 chars).',
        );
      }

      return (token: token, appId: resolvedAppId);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw AgoraServiceException(
          code: 'agora-backend-misconfigured',
          message:
              'Live media backend is not configured. Please set AGORA_APP_ID and AGORA_APP_CERTIFICATE in Cloud Functions.',
          cause: e,
        );
      }
      if (e.code == 'resource-exhausted') {
        throw AgoraServiceException(
          code: 'agora-rate-limited',
          message:
              'Too many live-media attempts. Please wait a moment and retry.',
          cause: e,
        );
      }
      if (e.code == 'unauthenticated' || e.code == 'permission-denied') {
        throw AgoraServiceException(
          code: 'permission-denied',
          message:
              'Your session is not authorized for live media. Please sign in again.',
          cause: e,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, RoomUserLookup>> loadUserLookup(
    Iterable<String> userIds,
  ) async {
    final normalizedIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) {
      return const <String, RoomUserLookup>{};
    }

    final results = <String, RoomUserLookup>{};
    for (var i = 0; i < normalizedIds.length; i += 10) {
      final upperBound = (i + 10 > normalizedIds.length)
          ? normalizedIds.length
          : i + 10;
      final batchIds = normalizedIds.sublist(i, upperBound);
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final user = UserModel.fromJson({...data, 'id': doc.id});
        final vip = data['vipLevel'];
        final gender = _asString(data['gender']);
        final resolvedDisplayName = user.username.trim();
        results[doc.id] = RoomUserLookup(
          profileUsername: resolvedDisplayName.isEmpty
              ? null
              : resolvedDisplayName,
          avatarUrl: user.avatarUrl,
          vipLevel: vip is int ? vip : (vip is num ? vip.toInt() : 0),
          gender: gender.isEmpty ? null : gender,
        );
      }
    }

    return results;
  }

  Stream<List<String>> watchSpeakerUserIds(String roomId) {
    return _speakerCollection(roomId).snapshots().map((snapshot) {
      final userIds = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final rawUserId = data['userId'];
            if (rawUserId is String && rawUserId.trim().isNotEmpty) {
              return rawUserId.trim();
            }
            return doc.id.trim();
          })
          .where((userId) => userId.isNotEmpty)
          .toSet()
          .toList(growable: false);
      return userIds;
    });
  }

  Future<void> requestMic({
    required String roomId,
    required String userId,
    String? displayName,
    String? role,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw StateError('A valid user is required to take the mic.');
    }

    final roomSnapshot = await _roomRef(roomId).get();
    if (!roomSnapshot.exists) {
      throw StateError('Room not found.');
    }

    final participantSnapshot = await _participantRef(
      roomId,
      normalizedUserId,
    ).get();
    final memberSnapshot = await _memberRef(roomId, normalizedUserId).get();
    if (!participantSnapshot.exists && !memberSnapshot.exists) {
      throw StateError('Only joined users can take the mic.');
    }

    final participantData =
        participantSnapshot.data() ?? const <String, dynamic>{};
    if (participantData['isBanned'] == true) {
      throw StateError('Banned users cannot take the mic.');
    }

    final maxSpeakers = _asInt(
      roomSnapshot.data()?['maxSpeakers'],
      fallback: 4,
    ).clamp(1, 4);
    final existingSpeakerDoc = await _speakerRef(
      roomId,
      normalizedUserId,
    ).get();
    if (!existingSpeakerDoc.exists) {
      final speakersSnapshot = await _speakerCollection(roomId).get();
      if (speakersSnapshot.docs.length >= maxSpeakers) {
        throw StateError('The stage already has $maxSpeakers speakers.');
      }
    }

    // Route all mic state mutations through the guarded grabMic callable.
    // This ensures rate limiting, policy enforcement, and transaction isolation.
    final functions = _functions;
    if (functions == null) {
      throw StateError(
        'Live media backend is unavailable. Please try again.',
      );
    }

    try {
      final callable = functions.httpsCallable('grabMic');
      await callable.call<Map<String, dynamic>>({
        'roomId': roomId,
      });
    } catch (e) {
      throw StateError(
        'Failed to take the mic: ${e.toString()}',
      );
    }
  }

  Future<void> releaseMic({
    required String roomId,
    required String userId,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    final participantSnapshot = await _participantRef(
      roomId,
      normalizedUserId,
    ).get();
    final participantData =
        participantSnapshot.data() ?? const <String, dynamic>{};
    final currentRole = normalizeRoomRole(
      _asString(participantData['role'], fallback: roomRoleAudience),
      fallbackRole: roomRoleAudience,
    );
    final nextRole = canModerateRole(currentRole)
        ? currentRole
        : roomRoleAudience;

    // Demote from stage to audience. This is a safe operation (user releasing their own mic).
    // Direct update is acceptable here; caller is the one being demoted.
    try {
      await _participantRef(roomId, normalizedUserId).set({
        'userId': normalizedUserId,
        'role': nextRole,
        'micOn': false,
        'isMuted': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Best effort; if update fails, user remains in current state
      // but can try again or refresh room state.
    }
  }

  Future<void> forceRemoveSpeaker({
    required String roomId,
    required String userId,
  }) {
    return releaseMic(roomId: roomId, userId: userId);
  }

  Future<List<UserModel>> getFriends(String userId) {
    return FriendService(firestore: _firestore).getFriends(userId);
  }

  Future<void> sendRoomInviteToFriends({
    required List<String> friendIds,
    required String inviterId,
    required String inviterName,
    required String roomId,
    required String roomName,
  }) {
    return NotificationService(firestore: _firestore).sendRoomInviteToFriends(
      friendIds: friendIds,
      inviterId: inviterId,
      inviterName: inviterName,
      roomId: roomId,
      roomName: roomName,
    );
  }
}
