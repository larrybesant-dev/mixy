import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/messaging/models/conversation_model.dart';
import 'package:mixvy/features/messaging/providers/messaging_provider.dart';

void main() {
  test('conversation stream delivers updates after idle period', () async {
    final firestore = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(firestore)],
    );
    addTearDown(container.dispose);

    final values = <AsyncValue<List<Conversation>>>[];
    final subscription = container.listen(
      rawConversationsStreamProvider('user-1'),
      (_, next) => values.add(next),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(values.any((value) => value.valueOrNull?.isEmpty ?? false), isTrue);

    await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
    await firestore.collection('conversations').doc('conv-after-idle').set({
      'participantIds': ['user-1', 'user-2'],
      'participantNames': {'user-2': 'Alice'},
      'type': 'direct',
      'status': 'active',
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastMessagePreview': 'Still connected',
      'isArchived': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      values.any(
        (value) =>
            value.valueOrNull?.any(
              (conversation) => conversation.id == 'conv-after-idle',
            ) ??
            false,
      ),
      isTrue,
    );
  });
}
