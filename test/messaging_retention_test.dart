import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import 'package:mixvy/features/messaging/providers/messaging_provider.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('Messaging retention', () {
    test(
      'sendMessage writes expiresAt and updates conversation summary',
      () async {
        final firestore = FakeFirebaseFirestore();
        final controller = MessagingController(firestore: firestore);
        final now = DateTime.now();

        await firestore.collection('conversations').doc('conv-1').set({
          'type': 'direct',
          'participantIds': ['user-1', 'user-2'],
          'participantNames': {'user-1': 'User One', 'user-2': 'User Two'},
          'createdAt': Timestamp.fromDate(now),
          'lastReadAt': {
            'user-1': Timestamp.fromDate(now),
            'user-2': Timestamp.fromDate(now),
          },
          'isArchived': false,
          'status': 'active',
        });

        await controller.sendMessage(
          conversationId: 'conv-1',
          senderId: 'user-1',
          senderName: 'User One',
          senderAvatarUrl: null,
          content: 'Hello there',
        );

        final message = await firestore
            .collection('conversations')
            .doc('conv-1')
            .collection('messages')
            .get();
        expect(message.docs, hasLength(1));

        final messageData = message.docs.single.data();
        final expiresAt = (messageData['expiresAt'] as Timestamp).toDate();
        final lowerBound = now.add(const Duration(days: 89));
        final upperBound = now.add(const Duration(days: 91));
        expect(expiresAt.isAfter(lowerBound), isTrue);
        expect(expiresAt.isBefore(upperBound), isTrue);

        final conversation = await firestore
            .collection('conversations')
            .doc('conv-1')
            .get();
        expect(conversation.data()?['lastMessageId'], message.docs.single.id);
        expect(conversation.data()?['lastMessagePreview'], 'Hello there');
        expect(conversation.data()?['lastMessageSenderId'], 'user-1');
        expect(conversation.data()?['lastMessageAt'], isA<Timestamp>());
      },
    );

    test('MessageModel.fromJson parses expiresAt', () {
      final now = DateTime.now();
      final createdAt = Timestamp.fromDate(now.subtract(const Duration(days: 1)));
      final expectedExpiry = now.add(const Duration(days: 30));
      final expiresAt = Timestamp.fromDate(expectedExpiry);

      final parsedMessage = MessageModel.fromJson({
        'conversationId': 'conv-1',
        'senderId': 'user-1',
        'senderName': 'User One',
        'content': 'Hello',
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'isDeleted': false,
        'readBy': ['user-1'],
      }, 'message-1');

      expect(parsedMessage.expiresAt, expectedExpiry);
      expect(parsedMessage.isExpired, isFalse);
    });
  });
}
