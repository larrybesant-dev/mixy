import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/repository/room_repository.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';

void main() {
  test(
    'loadUserLookup falls back to displayName when username is missing',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = RoomRepository(
        firestore: firestore,
        streamLifecycleManager: StreamLifecycleManager(),
      );

      await firestore.collection('users').doc('host-1').set({
        'displayName': 'DJ Curve',
        'avatarUrl': 'https://example.com/avatar.png',
        'vipLevel': 3,
      });

      final lookup = await repository.loadUserLookup(const ['host-1']);

      expect(lookup['host-1']?.profileUsername, 'DJ Curve');
      expect(lookup['host-1']?.vipLevel, 3);
    },
  );

  test(
    'releaseMic demotes non-staff to audience without mutating room fields',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = RoomRepository(
        firestore: firestore,
        streamLifecycleManager: StreamLifecycleManager(),
      );

      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'name': 'Room A',
        'maxSpeakers': 8,
        'speakerSyncVersion': 7,
      });
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('user-1')
          .set({
            'userId': 'user-1',
            'role': 'stage',
            'micOn': true,
            'isMuted': false,
          });
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('speakers')
          .doc('user-1')
          .set({'userId': 'user-1'});

      await repository.releaseMic(roomId: 'room-a', userId: 'user-1');

      final roomData = (await firestore.collection('rooms').doc('room-a').get())
          .data()!;
      final participantData =
          (await firestore
                  .collection('rooms')
                  .doc('room-a')
                  .collection('participants')
                  .doc('user-1')
                  .get())
              .data()!;
      final speakerDoc = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('speakers')
          .doc('user-1')
          .get();

      expect(roomData['maxSpeakers'], 8);
      expect(roomData['speakerSyncVersion'], 7);
      expect(participantData['role'], 'audience');
      expect(participantData['micOn'], isFalse);
      expect(speakerDoc.exists, isTrue);
    },
  );
}
