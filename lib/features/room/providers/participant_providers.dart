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
            .doc(roomId) // Single-document read — .limit(1) not applicable for document snapshots.
            .snapshots()
            .map((snap) => snap.data()),
      );
    });

final roomMemberUserIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, roomId) {
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
            .doc(params.userId) // Single-document read — .limit(1) not applicable for document snapshots.
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

const Duration _kParticipantFreshnessWindow = Duration(seconds: 90);

bool _isParticipantFresh(RoomParticipantModel participant, {DateTime? now}) {
  final normalizedRole = normalizeRoomRole(participant.role, fallbackRole: '');
  final shouldKeepActiveSeatVisible =
      canManageStageRole(normalizedRole) ||
      normalizedRole == roomRoleStage ||
      participant.camOn ||
      participant.micOn;
  if (shouldKeepActiveSeatVisible) {
    return true;
  }

  final currentTime = now ?? DateTime.now();
  return currentTime.difference(participant.lastActiveAt) <=
      _kParticipantFreshnessWindow;
}

List<RoomParticipantModel> _mapParticipants(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final now = DateTime.now();
  return snapshot.docs
      .map((doc) => RoomParticipantModel.fromMap(doc.data()))
      .where((participant) => _isParticipantFresh(participant, now: now))
      .toList(growable: false);
}

final participantsStreamProvider = StreamProvider.autoDispose
    .family<List<RoomParticipantModel>, String>((ref, roomId) {
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
        (_, _) => publish(),
        fireImmediately: true,
      );
      ref.listen<AsyncValue<List<String>>>(
        roomSpeakerUserIdsProvider(roomId),
        (_, _) => publish(),
        fireImmediately: true,
      );
      ref.listen<AsyncValue<Map<String, dynamic>?>>(
        roomDocStreamProvider(roomId),
        (_, _) => publish(),
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
