import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_debug_tracing.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../../../models/room_slot_model.dart';
import 'room_firestore_provider.dart';

/// Streams the `slots` subcollection for a room.
/// Each document id is the slot identifier (e.g. '1', '2', …).
final roomSlotsProvider = StreamProvider.autoDispose
    .family<List<RoomSlotModel>, String>((ref, roomId) {
  final firestore = ref.watch(roomFirestoreProvider);
  return traceFirestoreStream<List<RoomSlotModel>>(
    key: 'room_slots/$roomId',
    query: 'rooms/$roomId/slots',
    roomId: roomId,
    itemCount: (value) => value.length,
    stream: firestore
        .collection('rooms')
        .doc(roomId)
        .collection('slots')
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => RoomSlotModel.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        ),
  );
});

class RoomSlotService {
  RoomSlotService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _slotsRef(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('slots');

  DocumentReference<Map<String, dynamic>> _participantRef(
    String roomId,
    String userId,
  ) =>
      _db
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(userId);

  /// Tries to claim a free slot for [userId].
  ///
  /// Returns the slot id that was claimed, or `null` when all slots are full.
  /// Uses a Firestore transaction so concurrent requests are race-safe.
  Future<String?> claimSlot(
    String roomId,
    String userId, {
    int maxBroadcasters = 6,
  }) async {
    if (roomId.trim().isEmpty || userId.trim().isEmpty) return null;

    try {
      String? claimedSlotId;

      // Build refs for all possible slots up front.
      final slotRefs = List.generate(
        maxBroadcasters,
        (i) => _slotsRef(roomId).doc('${i + 1}'),
      );

      await _db.runTransaction((txn) async {
        // Read every slot document inside the transaction (serialised read).
        final snaps = await Future.wait(slotRefs.map(txn.get));

        // If the user already owns a slot, just confirm it.
        for (final snap in snaps) {
          if (snap.exists && (snap.data()?['userId'] as String?) == userId) {
            claimedSlotId = snap.id;
            return;
          }
        }

        // Claim the first vacant slot.
        for (final snap in snaps) {
          final snapData = snap.exists ? snap.data() : null;
          final occupant = snapData?['userId'] as String?;
          if (occupant == null || occupant.isEmpty) {
            txn.set(snap.reference, {'userId': userId});
            claimedSlotId = snap.id;
            return;
          }
        }
        // All slots occupied — claimedSlotId stays null.
      });

      if (claimedSlotId != null) {
        // Mirror camOn = true into the participant document.
        await traceFirestoreWrite<void>(
          path: 'rooms/$roomId/participants/$userId',
          operation: 'mark_cam_on_after_slot_claim',
          roomId: roomId,
          userId: userId,
          action: () => _participantRef(
            roomId,
            userId,
          ).set({'camOn': true}, SetOptions(merge: true)),
        );
      }

      developer.log(
        'claimSlot: room=$roomId user=$userId result=$claimedSlotId',
        name: 'RoomSlotService',
      );
      AppTelemetry.logAction(
        domain: 'room',
        action: 'claim_slot',
        message: 'Camera slot claim finished.',
        roomId: roomId,
        userId: userId,
        result: claimedSlotId ?? 'full',
      );
      return claimedSlotId;
    } catch (error, stackTrace) {
      developer.log(
        'claimSlot failed: room=$roomId user=$userId error=$error',
        name: 'RoomSlotService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Releases any slot held by [userId] and marks their cam as off.
  Future<void> releaseSlot(String roomId, String userId) async {
    if (roomId.trim().isEmpty || userId.trim().isEmpty) return;

    try {
      final slotsSnap = await _slotsRef(
        roomId,
      ).where('userId', isEqualTo: userId).get();
      final batch = _db.batch();
      for (final doc in slotsSnap.docs) {
        // Delete the slot doc so the next claimant can create a fresh one.
        // (Writing {userId: null} would fail the security rule that requires
        // request.resource.data.userId == request.auth.uid on updates.)
        batch.delete(doc.reference);
      }
      batch.set(
          _participantRef(roomId, userId),
          {
            'camOn': false,
          },
          SetOptions(merge: true));
      await traceFirestoreWrite<void>(
        path: 'rooms/$roomId/slots',
        operation: 'release_slot_batch',
        roomId: roomId,
        userId: userId,
        metadata: <String, Object?>{'releasedSlotCount': slotsSnap.docs.length},
        action: batch.commit,
      );

      developer.log(
        'releaseSlot: room=$roomId user=$userId released=${slotsSnap.docs.length} slots',
        name: 'RoomSlotService',
      );
      AppTelemetry.logAction(
        domain: 'room',
        action: 'release_slot',
        message: 'Camera slot release finished.',
        roomId: roomId,
        userId: userId,
        result: slotsSnap.docs.length.toString(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'releaseSlot failed: room=$roomId user=$userId error=$error',
        name: 'RoomSlotService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final roomSlotServiceProvider = Provider<RoomSlotService>(
  (ref) => RoomSlotService(ref.watch(roomFirestoreProvider)),
);
