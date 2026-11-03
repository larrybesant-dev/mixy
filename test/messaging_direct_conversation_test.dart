import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/messaging/providers/messaging_provider.dart';

void main() {
  test('reuses an existing direct conversation without rewriting it', () async {
    final firestore = FakeFirebaseFirestore();

    final firstId = await ensureDirectConversationDocument(
      firestore: firestore,
      currentUserId: 'curve-user',
      currentUserName: 'Curve',
      targetUserId: 'tori-user',
      targetUserName: 'Tori',
    );
    final firstSnapshot =
        await firestore.collection('conversations').doc(firstId).get();
    final firstCreatedAt = firstSnapshot.data()?['createdAt'];

    final secondId = await ensureDirectConversationDocument(
      firestore: firestore,
      currentUserId: 'curve-user',
      currentUserName: 'Changed Curve',
      targetUserId: 'tori-user',
      targetUserName: 'Changed Tori',
    );
    final secondSnapshot =
        await firestore.collection('conversations').doc(secondId).get();

    expect(secondId, firstId);
    expect(secondSnapshot.data()?['createdAt'], firstCreatedAt);
    expect(secondSnapshot.data()?['participantNames'], {
      'curve-user': 'Curve',
      'tori-user': 'Tori',
    });
  });
}
