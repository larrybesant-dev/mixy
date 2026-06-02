import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/notification_provider.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

void main() {
  group('Notification providers', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await firestore.collection('notifications').doc('n1').set({
        'userId': 'user-1',
        'type': 'payment',
        'content': 'Payment received',
        'isRead': false,
        'createdAt': DateTime(2026, 1, 1),
      });
      await firestore.collection('notifications').doc('n2').set({
        'userId': 'user-2',
        'type': 'room',
        'content': 'Room invite',
        'isRead': false,
        'createdAt': DateTime(2026, 1, 2),
      });

      container = ProviderContainer(
        overrides: [
          notificationFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1',
              email: 'user1@mixvy.dev',
              username: 'User One',
              createdAt: DateTime(2026, 1, 1))),
        ]);
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'notificationsStreamProvider scopes notifications to current user',
      () async {
        final notifications = await container.read(
          notificationsStreamProvider.future);

        expect(notifications, hasLength(1));
        expect(notifications.single.id, 'n1');
        expect(notifications.single.content, 'Payment received');
      });
  });
}










