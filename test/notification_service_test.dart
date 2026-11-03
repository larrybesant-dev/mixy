import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    late FakeFirebaseFirestore firestore;
    late NotificationService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = NotificationService(firestore: firestore);

      await firestore.collection('notifications').doc('n1').set({
        'userId': 'user-1',
        'actorId': 'user-2',
        'type': 'friend_request',
        'content': 'User 2 sent a friend request',
        'isRead': false,
        'createdAt': DateTime(2026, 1, 1),
      });
    });

    test('markRead updates only matching user notification', () async {
      await service.markRead('user-1', 'n1');

      final updated =
          await firestore.collection('notifications').doc('n1').get();
      expect(updated.data()?['isRead'], isTrue);
    });

    test(
      'markRead does not update notification owned by another user',
      () async {
        await service.markRead('user-3', 'n1');

        final unchanged =
            await firestore.collection('notifications').doc('n1').get();
        expect(unchanged.data()?['isRead'], isFalse);
      },
    );

    test('sendRoomInviteToFriends creates joinable notifications', () async {
      await service.sendRoomInviteToFriends(
        friendIds: const ['friend-1', 'friend-2'],
        inviterId: 'user-1',
        inviterName: 'User One',
        roomId: 'room-1',
        roomName: 'Friday Night',
      );

      final notifications = await firestore
          .collection('notifications')
          .where('type', isEqualTo: 'live_room_invite')
          .get();

      expect(notifications.docs, hasLength(2));
      expect(
        notifications.docs.map((doc) => doc.data()['userId']).toSet(),
        {'friend-1', 'friend-2'},
      );
      expect(
        notifications.docs.every(
          (doc) => doc.data()['roomId'] == 'room-1',
        ),
        isTrue,
      );
    });
  });
}
