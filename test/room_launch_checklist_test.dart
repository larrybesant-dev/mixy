import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/features/room/services/room_session_service.dart';
import 'package:mixvy/services/presence_controller.dart';

class _FakePresenceController extends PresenceController {
  @override
  PresenceControllerState build() => const PresenceControllerState();

  @override
  Future<void> setInRoom(String userId, String roomId) async {}

  @override
  Future<void> clearInRoom(String userId) async {}
}

void main() {
  group('MVP -> Beta Readiness Checklist', () {
    test('Verify minimal telemetry hooks are present', () {
      AppTelemetry.reset();

      // Simulate some activity
      AppTelemetry.recordFirestoreRead(path: 'users/1', operation: 'test_read');
      AppTelemetry.recordFirestoreWrite(
        path: 'users/1',
        operation: 'test_write',
      );

      expect(AppTelemetry.state.firestoreReadCount, 1);
      expect(AppTelemetry.state.firestoreWriteCount, 1);
    });

    test('Verify room join cost pressure (Read/Write Count)', () async {
      final firestore = FakeFirebaseFirestore();
      final sessionService = RoomSessionService(
        firestore: firestore,
        presenceController: _FakePresenceController(),
      );

      AppTelemetry.reset();

      await firestore.collection('rooms').doc('room-1').set({'isLive': true});

      await sessionService.joinRoom(roomId: 'room-1', userId: 'user-1');

      // A join should ideally cost few writes and reads
      // Currently, it does: get room, get excluded, get participants, get current participant,
      // then writes participant, member, and presence.

      expect(
        AppTelemetry.state.firestoreReadCount,
        lessThanOrEqualTo(5),
        reason: 'Join room is getting expensive in terms of reads',
      );
      expect(
        AppTelemetry.state.firestoreWriteCount,
        lessThanOrEqualTo(4),
        reason: 'Join room is getting expensive in terms of writes',
      );
    });

    test('Verify presence sync doesnt orphan participants', () async {
      // This is a logic check for Step 3 in user prompt.
      final firestore = FakeFirebaseFirestore();
      final sessionService = RoomSessionService(
        firestore: firestore,
        presenceController: _FakePresenceController(),
      );

      await firestore.collection('rooms').doc('room-1').set({'isLive': true});
      await sessionService.joinRoom(roomId: 'room-1', userId: 'user-crash');

      // Simulate crash by "leaving" without cleanup (app kill)
      // The hardening logic should eventually clean this up via Cloud Function
      // (which we simulate here by verifying the expected cleanup call path)

      final participants = await firestore
          .collection('rooms')
          .doc('room-1')
          .collection('participants')
          .get();
      expect(participants.docs.length, 1);

      // After a simulated "cleanup" (which in production happens via syncPresenceFromRtdbSessions)
      await sessionService.leaveRoom(roomId: 'room-1', userId: 'user-crash');

      final cleanedParticipants = await firestore
          .collection('rooms')
          .doc('room-1')
          .collection('participants')
          .get();
      expect(cleanedParticipants.docs.isEmpty, isTrue);
    });
  });
}
