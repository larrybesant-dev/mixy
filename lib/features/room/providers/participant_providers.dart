import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_debug_tracing.dart';
import '../../../models/room_participant_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../controllers/room_state.dart';
import '../repository/room_repository.dart';
import 'room_firestore_provider.dart';
import '../../../core/constants/query_policy.dart';

/// ============================================================================
/// HARDENING FIX #1: Self-Participant Cache
/// 
/// When multiple users join a room simultaneously, participantsStreamProvider
/// may lag 2-3 seconds for some users. During that window, chat/camera gating
/// logic checks the stale participant stream and incorrectly denies permissions.
/// 
/// This provider caches the current user's participant document immediately
/// after it's written during joinRoom(), bypassing stream lag. UI falls back to
/// this cache when participantsStreamProvider is still lagging.
/// ============================================================================

/// Cached current-user participant for a specific room.
/// Set by RoomController.joinRoom() immediately after participant doc write.
/// Expires when the room session ends (leaveRoom called or session invalidated).
final selfParticipantCacheProvider = StateNotifierProvider.autoDispose
    .family<SelfParticipantCacheNotifier, RoomParticipantModel?, String>(
      (ref, roomId) => SelfParticipantCacheNotifier(),
    );

class SelfParticipantCacheNotifier
    extends StateNotifier<RoomParticipantModel?> {
  SelfParticipantCacheNotifier() : super(null);

  /// Called by RoomController immediately after joining a room.
  /// Caches the participant doc so permission checks don't wait for the stream.
  void cacheParticipant(RoomParticipantModel participant) {
    state = participant;
  }

  /// Clear cache when leaving the room or session ends.
  void clear() {
    state = null;
  }
}

/// Streams the raw room document map. Used outside of `currentParticipantAsync`
/// so the host check resolves even before the participant document is written.
final roomDocStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, roomId) {
      final firestore = ref.watch(roomFirestoreProvider);
      return traceFirestoreStream<Map<String, dynamic>?>(
        key: 'room_doc/$roomId',
        query: 'rooms/$roomId',
        roomId: roomId,
        itemCount: (value) => value == null ? 0 : 1,
        stream: firestore
            .collection('rooms')
            .doc(
              roomId,
            ) // Single-document read — .limit(1) not applicable for document snapshots.
            .snapshots()
            .map((snap) => snap.data()),
      );
    });

final roomMemberUserIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, roomId) {
      // Guard: do not attempt to stream members until the room metadata is ready.
      final roomDocValue = ref.watch(roomDocStreamProvider(roomId));
      if (!roomDocValue.hasValue || roomDocValue.value == null) {
        return Stream.value(const <String>[]);
      }

      final firestore = ref.watch(roomFirestoreProvider);
      return traceFirestoreStream<List<String>>(
        key: 'room_members/$roomId',
        query: 'rooms/$roomId/members',
        roomId: roomId,
        itemCount: (value) => value.length,
        stream: firestore
            .collection('rooms')
            .doc(roomId)
            .collection('members')
            .limit(QueryPolicy.roomMembersLimit)
            .snapshots()
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) {
                    final data = doc.data();
                    final userId = data['userId'];
                    if (userId is String && userId.trim().isNotEmpty) {
                      return userId.trim();
                    }
                    return doc.id.trim();
                  })
                  .where((userId) => userId.isNotEmpty)
                  .toSet()
                  .toList(growable: false);
            }),
      );
    });

final roomSpeakerUserIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, roomId) {
      final currentUserId = ref.watch(userProvider)?.id.trim() ?? '';

      // Speakers subcollection requires isRoomParticipant() which reads the
      // participant doc via get(). Gate the stream until the current user's
      // participant doc exists to avoid a permission-denied on screen load.
      if (currentUserId.isNotEmpty) {
        final participantValue = ref.watch(
          currentParticipantProvider(
            CurrentParticipantParams(roomId: roomId, userId: currentUserId),
          ),
        );
        if (!participantValue.hasValue || participantValue.value == null) {
          return Stream.value(const <String>[]);
        }
      }

      final repository = ref.watch(roomRepositoryProvider);
      return traceFirestoreStream<List<String>>(
        key: 'room_speakers/$roomId',
        query: 'rooms/$roomId/speakers',
        roomId: roomId,
        itemCount: (value) => value.length,
        stream: repository.watchSpeakerUserIds(roomId),
      );
    });

class CurrentParticipantParams {
  final String roomId;
  final String userId;

  const CurrentParticipantParams({required this.roomId, required this.userId});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CurrentParticipantParams &&
            other.roomId == roomId &&
            other.userId == userId);
  }

  @override
  int get hashCode => Object.hash(roomId, userId);
}

class Cohost {
  final String id;

  const Cohost(this.id);
}

/// Derived view of cohosts from the canonical [participantsStreamProvider].
/// No separate Firestore query — filters client-side from the already-active
/// participants stream.
final coHostsProvider = Provider.autoDispose.family<List<Cohost>, String>((
  ref,
  roomId,
) {
  final participants =
      ref.watch(participantsStreamProvider(roomId)).valueOrNull ??
      const <RoomParticipantModel>[];
  return participants
      .where(
        (p) => normalizeRoomRole(p.role, fallbackRole: '') == roomRoleCohost,
      )
      .map((p) => Cohost(p.userId))
      .toList(growable: false);
});

final currentParticipantProvider = StreamProvider.autoDispose
    .family<RoomParticipantModel?, CurrentParticipantParams>((ref, params) {
      final firestore = ref.watch(roomFirestoreProvider);
      return traceFirestoreStream<RoomParticipantModel?>(
        key: 'current_participant/${params.roomId}/${params.userId}',
        query: 'rooms/${params.roomId}/participants/${params.userId}',
        roomId: params.roomId,
        userId: params.userId,
        itemCount: (value) => value == null ? 0 : 1,
        stream: firestore
            .collection('rooms')
            .doc(params.roomId)
            .collection('participants')
            .doc(
              params.userId,
            ) // Single-document read — .limit(1) not applicable for document snapshots.
            .snapshots()
            .map((doc) {
              if (!doc.exists) {
                return null;
              }
              return RoomParticipantModel.fromMap(
                doc.data() ?? <String, dynamic>{},
              );
            }),
      );
    });

/// Hydration-lag tolerant current participant accessor.
/// Falls back to the self-participant cache if participantsStreamProvider
/// is still lagging. This prevents false permission denials when multiple
/// users join simultaneously and the Firestore stream is slow.
/// 
/// Use this for chat/camera/stage gating logic; use currentParticipantProvider
/// for display-only (roster, names, etc).
final currentParticipantWithCacheFallbackProvider = Provider.autoDispose
    .family<RoomParticipantModel?, CurrentParticipantParams>((ref, params) {
      // First, try the stream (fresh, authoritative)
      final streamValue = ref.watch(currentParticipantProvider(params));
      if (streamValue.hasValue && streamValue.value != null) {
        return streamValue.value;
      }

      // Stream is lagging/not ready — fall back to the cache
      // (set by RoomController immediately upon join)
      final cached = ref.watch(selfParticipantCacheProvider(params.roomId));
      if (cached != null && cached.userId == params.userId) {
        return cached;
      }

      // No cache and no stream — wait for stream to complete
      return streamValue.valueOrNull;
    });

const Duration _kParticipantFreshnessWindow = Duration(seconds: 30);

bool _isParticipantFresh(RoomParticipantModel participant, {DateTime? now}) {
  // If the user drops connection, they should be evicted even if they are host/stage/camOn.
  // Otherwise, "Ghost Tiles" will remain frozen on stage.

  final currentTime = now ?? DateTime.now();
  // Using lastActiveAt which now includes our heartbeat update
  return currentTime.difference(participant.lastActiveAt) <=
      _kParticipantFreshnessWindow;
}

List<RoomParticipantModel> _mapParticipants(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final now = DateTime.now();
  final participants = snapshot.docs
      .map((doc) => RoomParticipantModel.fromMap(doc.data()))
      .where((participant) => _isParticipantFresh(participant, now: now))
      .toList(growable: false);

  // Deduplicate by userId — ensures a user only appears once in the roster
  final uniqueMap = <String, RoomParticipantModel>{};
  for (final p in participants) {
    uniqueMap[p.userId] = p;
  }
  return uniqueMap.values.toList(growable: false);
}

final participantsStreamProvider = StreamProvider.autoDispose
    .family<List<RoomParticipantModel>, String>((ref, roomId) {
      // Guard: do not attempt to stream participants until the room metadata is ready.
      final roomDocValue = ref.watch(roomDocStreamProvider(roomId));
      if (!roomDocValue.hasValue || roomDocValue.value == null) {
        return Stream.value(const <RoomParticipantModel>[]);
      }

      final firestore = ref.watch(roomFirestoreProvider);
      return traceFirestoreStream<List<RoomParticipantModel>>(
        key: 'participants/$roomId',
        query: 'rooms/$roomId/participants orderBy joinedAt',
        roomId: roomId,
        itemCount: (value) => value.length,
        stream: firestore
            .collection('rooms')
            .doc(roomId)
            .collection('participants')
            .orderBy('joinedAt')
            .limit(QueryPolicy.roomParticipantsLimit)
            .snapshots()
            .map(_mapParticipants),
      );
    });

/// Derived participant count from [participantsStreamProvider].
/// No separate Firestore query — counts the already-active stream.
final participantCountProvider = Provider.autoDispose.family<int, String>(
  (ref, roomId) =>
      ref.watch(participantsStreamProvider(roomId)).valueOrNull?.length ?? 0,
);

final isHostProvider = Provider.autoDispose.family<bool, RoomParticipantModel?>(
  (ref, participant) => isHostLikeRole(participant?.role ?? ''),
);

final isCohostProvider = Provider.autoDispose
    .family<bool, RoomParticipantModel?>((ref, participant) {
      return normalizeRoomRole(participant?.role, fallbackRole: '') ==
          roomRoleCohost;
    });

/// Streams participants who are currently active on the mic.
/// For migrated rooms, the shared `speakers` collection is authoritative.
final onMicParticipantsProvider = StreamProvider.autoDispose
    .family<List<RoomParticipantModel>, String>((ref, roomId) {
      final controller = StreamController<List<RoomParticipantModel>>();

      void publish() {
        final participants =
            ref.read(participantsStreamProvider(roomId)).valueOrNull ??
            const <RoomParticipantModel>[];
        final speakerUserIds =
            ref.read(roomSpeakerUserIdsProvider(roomId)).valueOrNull ??
            const <String>[];
        final roomDoc = ref.read(roomDocStreamProvider(roomId)).valueOrNull;
        final useSpeakerDocs =
            roomDoc?['speakerSyncVersion'] is num ||
            roomDoc?['maxSpeakers'] is num;

        if (useSpeakerDocs) {
          final participantsByUser = {
            for (final participant in participants)
              participant.userId.trim(): participant,
          };
          controller.add(
            speakerUserIds
                .map((userId) => participantsByUser[userId.trim()])
                .whereType<RoomParticipantModel>()
                .toList(growable: false),
          );
          return;
        }

        controller.add(
          participants
              .where((p) {
                final role = normalizeRoomRole(p.role, fallbackRole: '');
                return canManageStageRole(role) || role == roomRoleStage;
              })
              .toList(growable: false),
        );
      }

      ref.listen<AsyncValue<List<RoomParticipantModel>>>(
        participantsStreamProvider(roomId),
        (__, _) => publish(),
        fireImmediately: true,
      );
      ref.listen<AsyncValue<List<String>>>(
        roomSpeakerUserIdsProvider(roomId),
        (__, _) => publish(),
        fireImmediately: true,
      );
      ref.listen<AsyncValue<Map<String, dynamic>?>>(
        roomDocStreamProvider(roomId),
        (__, _) => publish(),
        fireImmediately: true,
      );
      ref.onDispose(controller.close);
      return controller.stream;
    });

/// Streams the most-recent [limit] entries from `rooms/{roomId}/mod_log`,
/// ordered by server timestamp descending. Only emits in debug/staff contexts;
/// the caller is responsible for guarding access.
final modLogStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
      final firestore = ref.watch(roomFirestoreProvider);
      return firestore
          .collection('rooms')
          .doc(roomId)
          .collection('mod_log')
          .orderBy('ts', descending: true)
          .limit(QueryPolicy.modLogLimit)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
                .toList(growable: false),
          );
    });




