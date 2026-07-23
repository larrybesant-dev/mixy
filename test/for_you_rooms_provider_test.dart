import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/social/providers/social_providers.dart';
import 'package:mixvy/services/room_service.dart';

void main() {
  group('forYouRoomsProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          roomServiceProvider.overrideWithValue(
            RoomService(firestore: firestore),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> seedUser({
      required String id,
      List<String> interests = const <String>[],
    }) async {
      await firestore.collection('users').doc(id).set({
        'username': id,
        'interests': interests,
        'createdAt': Timestamp.fromDate(DateTime(2026, 4, 20)),
      });
    }

    Future<void> seedLegacyLiveRoom({
      required String id,
      required String hostId,
      String? category,
    }) async {
      await firestore.collection('rooms').doc(id).set({
        'name': 'Legacy room $id',
        'hostId': hostId,
        'isLive': true,
        'category': category,
        'stageUserIds': <String>[hostId],
        'audienceUserIds': const <String>[],
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        // Intentionally omit isAdult + memberCount to simulate older docs.
      });
    }

    test('includes legacy live rooms with missing optional fields', () async {
      await seedUser(id: 'u1');
      await seedLegacyLiveRoom(id: 'room-legacy', hostId: 'host-1');

      final rooms = await container.read(forYouRoomsProvider('u1').future);

      expect(rooms.map((room) => room.id), contains('room-legacy'));
    });

    test(
      'includes interest-matched legacy rooms without requiring index-only fields',
      () async {
        await seedUser(id: 'u2', interests: const <String>['music']);
        await seedLegacyLiveRoom(
          id: 'room-music',
          hostId: 'host-2',
          category: 'music',
        );

        final rooms = await container.read(forYouRoomsProvider('u2').future);

        expect(rooms.map((room) => room.id), contains('room-music'));
      },
    );
  });
}
