import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/services/messenger_status_service.dart';

void main() {
  test('watches and updates a messenger status message', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('user-1').set({
      'uid': 'user-1',
      'statusMessage': 'Available to chat',
    });
    final service = FirestoreMessengerStatusService(firestore);

    final initial = await service.watchProfileStatus('user-1').first;
    expect(initial.statusMessage, 'Available to chat');
    expect(initial.availability, 'online');

    await service.updateStatusMessage('user-1', '  In a live room  ');
    await service.updateAvailability('user-1', 'away');
    final updated = await firestore.collection('users').doc('user-1').get();
    expect(updated.data()?['statusMessage'], 'In a live room');
    expect(updated.data()?['messengerStatus'], 'away');
  });

  test('rejects status updates without a user ID', () async {
    final service = FirestoreMessengerStatusService(FakeFirebaseFirestore());

    await expectLater(
      service.updateStatusMessage(' ', 'Available'),
      throwsArgumentError,
    );
  });
}
