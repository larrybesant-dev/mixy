import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/room_slot_provider.dart';

void main() {
  group('RoomSlotService', () {
    late FakeFirebaseFirestore firestore;
    late RoomSlotService service;

    const roomId = 'room-1';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = RoomSlotService(firestore);
    });

    // Helpers ------------------------------------------------------------------

    Future<String?> slotOwner(String slotId) async {
      final doc = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('slots')
          .doc(slotId)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['userId'] as String?;
    }

    Future<bool?> participantCamOn(String userId) async {
      final doc = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(userId)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['camOn'] as bool?;
    }

    // -------------------------------------------------------------------------

    test(
      'claimSlot returns a slot id and writes userId to Firestore',
      () async {
        final slotId = await service.claimSlot(
          roomId,
          'user-a',
          maxBroadcasters: 3);

        expect(slotId, isNotNull);
        expect(await slotOwner(slotId!), 'user-a');
        expect(await participantCamOn('user-a'), isTrue);
      });

    test('claimSlot returns null when all slots are occupied', () async {
      // Fill 2 of 2 slots.
      await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('slots')
          .doc('1')
          .set({'userId': 'user-x'});
      await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('slots')
          .doc('2')
          .set({'userId': 'user-y'});

      final slotId = await service.claimSlot(
        roomId,
        'user-a',
        maxBroadcasters: 2);

      expect(slotId, isNull);
      // participant doc should not be written when claim fails.
      expect(await participantCamOn('user-a'), isNull);
    });

    test(
      'claimSlot is idempotent — re-claiming own slot returns same id',
      () async {
        final first = await service.claimSlot(
          roomId,
          'user-a',
          maxBroadcasters: 3);
        final second = await service.claimSlot(
          roomId,
          'user-a',
          maxBroadcasters: 3);

        expect(first, isNotNull);
        expect(second, equals(first));
      });

    test('releaseSlot deletes the slot doc and sets camOn=false', () async {
      final slotId = await service.claimSlot(
        roomId,
        'user-a',
        maxBroadcasters: 3);
      expect(slotId, isNotNull);

      await service.releaseSlot(roomId, 'user-a');

      // Slot document should be deleted so a new user can create it fresh.
      final doc = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('slots')
          .doc(slotId)
          .get();
      expect(doc.exists, isFalse);
      expect(await participantCamOn('user-a'), isFalse);
    });

    test('releaseSlot allows another user to claim the freed slot', () async {
      await service.claimSlot(roomId, 'user-a', maxBroadcasters: 1);
      await service.releaseSlot(roomId, 'user-a');

      final slotId = await service.claimSlot(
        roomId,
        'user-b',
        maxBroadcasters: 1);
      expect(slotId, isNotNull);
      expect(await slotOwner(slotId!), 'user-b');
    });

    test('claimSlot rejects blank roomId or userId gracefully', () async {
      expect(await service.claimSlot('', 'user-a'), isNull);
      expect(await service.claimSlot('  ', 'user-a'), isNull);
      expect(await service.claimSlot(roomId, ''), isNull);
      expect(await service.claimSlot(roomId, '  '), isNull);
    });

    test(
      'releaseSlot does nothing for blank inputs without throwing',
      () async {
        // Must not throw.
        await service.releaseSlot('', 'user-a');
        await service.releaseSlot(roomId, '');
      });

    test(
      'releaseSlot for a user who never held a slot sets camOn=false and does not throw',
      () async {
        // Simulates _handleForcedRoomExit when the user was a participant but
        // had never turned their camera on (no slot doc exists).
        await firestore
            .collection('rooms')
            .doc(roomId)
            .collection('participants')
            .doc('user-nocam')
            .set({'userId': 'user-nocam', 'camOn': true});

        await service.releaseSlot(roomId, 'user-nocam');

        // No slot existed, so nothing to delete — but camOn should be cleared.
        expect(await participantCamOn('user-nocam'), isFalse);
      });

    test(
      'releaseSlot is idempotent when slot was already deleted externally',
      () async {
        // Simulates a race where a Cloud Function or another client deletes the
        // slot before _handleForcedRoomExit calls releaseSlot.
        final slotId = await service.claimSlot(
          roomId,
          'user-a',
          maxBroadcasters: 3);
        expect(slotId, isNotNull);

        // Delete the slot externally before releaseSlot is called.
        await firestore
            .collection('rooms')
            .doc(roomId)
            .collection('slots')
            .doc(slotId)
            .delete();

        // Must not throw even though the slot doc is already gone.
        await expectLater(
          () => service.releaseSlot(roomId, 'user-a'),
          returnsNormally);
        expect(await participantCamOn('user-a'), isFalse);
      });

    test('concurrent claims respect maxBroadcasters limit', () async {
      // Simulate two sequential claims against a 1-slot room.
      // (fake_cloud_firestore does not execute true concurrent transactions,
      // but we verify that the second claim after the first is rejected.)
      final first = await service.claimSlot(
        roomId,
        'user-a',
        maxBroadcasters: 1);
      final second = await service.claimSlot(
        roomId,
        'user-b',
        maxBroadcasters: 1);

      expect(first, isNotNull);
      expect(second, isNull);
    });
  });
}










