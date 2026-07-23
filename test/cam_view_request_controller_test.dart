import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/cam_view_request_provider.dart';

void main() {
  group('CamViewRequestController', () {
    late FakeFirebaseFirestore firestore;
    late CamViewRequestController controller;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      controller = CamViewRequestController(firestore);
    });

    test(
      'sendRequest notifies the target and refreshes repeated requests',
      () async {
        await controller.sendRequest(
          roomId: 'room-1',
          requesterId: 'harley',
          targetId: 'me',
          requesterName: 'Harley',
        );

        await controller.sendRequest(
          roomId: 'room-1',
          requesterId: 'harley',
          targetId: 'me',
          requesterName: 'Harley',
        );

        final requests = await firestore
            .collection('rooms')
            .doc('room-1')
            .collection('cam_view_requests')
            .get();
        final notifications = await firestore
            .collection('notifications')
            .where('userId', isEqualTo: 'me')
            .get();
        final statuses = requests.docs
            .map((doc) => doc.data()['status'] as String? ?? '')
            .toList(growable: false);

        expect(requests.docs, hasLength(2));
        expect(statuses.where((status) => status == 'pending'), hasLength(1));
        expect(
          statuses.where((status) => status == 'superseded'),
          hasLength(1),
        );
        expect(notifications.docs, hasLength(2));
        expect(
          notifications.docs.last.data()['content'],
          contains('Harley wants to view your camera'),
        );
      },
    );
  });
}
