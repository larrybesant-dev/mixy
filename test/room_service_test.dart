import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/services/room_service.dart';

/// Local fake to allow streams to flow regardless of route in tests.
class _FakeLifecycleManager extends ChangeNotifier implements StreamLifecycleManager {
  @override String get currentRoutePath => '/home';
  @override void updateRoute(String routePath) {}
  @override bool isRouteActive(List<String> routePrefixes) => true;
  @override Stream<T> bind<T>({required String key, required Stream<T> Function() create, List<String> routePrefixes = const <String>[]}) => create();
  @override String buildDedupeKey({required String domain, String? userId, String? route, String? queryHash}) => '$domain|$queryHash';
}

void main() {
  group('RoomService', () {
    late FakeFirebaseFirestore firestore;
    late RoomService service;
    late _FakeLifecycleManager lifecycle;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      lifecycle = _FakeLifecycleManager();
      service = RoomService(
        firestore: firestore,
        lifecycleManager: lifecycle,
      );
    });

    test('createRoom trims input and applies defaults', () async {
      final roomId = await service.createRoom(
        hostId: ' host-1 ',
        name: '  Late Night Vibes  ',
        description: '  chill room  ',
        tags: const <String>[' chill ', ' ', 'music'],
      );

      final doc = await firestore.collection('rooms').doc(roomId).get();
      final data = doc.data()!;

      expect(data['hostId'], 'host-1');
      expect(data['name'], 'Late Night Vibes');
      expect(data['description'], 'chill room');
      expect(data['isLive'], true);
      expect(data['isLocked'], false);
      expect(data['slowModeSeconds'], 0);
      expect(data['audienceUserIds'], <String>['host-1']);
      expect(data['tags'], <String>['chill', 'music']);
    });

    test('createRoom rejects empty hostId and name', () async {
      await expectLater(
        () => service.createRoom(hostId: ' ', name: 'ok'),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => service.createRoom(hostId: 'host-1', name: '  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getLiveRooms returns live rooms ordered by createdAt desc', () async {
      await firestore.collection('rooms').doc('room-1').set({
        'name': 'Room One',
        'hostId': 'host-1',
        'isLive': true,
        'isAdult': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
      });
      await firestore
          .collection('rooms')
          .doc('room-1')
          .collection('participants')
          .doc('host-1')
          .set({'lastActiveAt': Timestamp.now()});
      await firestore.collection('rooms').doc('room-2').set({
        'name': 'Room Two',
        'hostId': 'host-2',
        'isLive': true,
        'isAdult': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 12)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 12)),
      });
      await firestore
          .collection('rooms')
          .doc('room-2')
          .collection('participants')
          .doc('host-2')
          .set({'lastActiveAt': Timestamp.now()});
      await firestore.collection('rooms').doc('room-3').set({
        'name': 'Room Three',
        'hostId': 'host-3',
        'isLive': false,
        'isAdult': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 13)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 13)),
      });

      final rooms = await service.getLiveRooms(limit: 10);

      expect(rooms, hasLength(2));
      expect(rooms.first.id, 'room-2'); // newer createdAt → first
      expect(rooms.last.id, 'room-1');
    });

    test(
      'getLiveRooms excludes adult rooms by default for discovery safety',
      () async {
        await firestore.collection('rooms').doc('public-room').set({
          'name': 'Public Room',
          'hostId': 'host-1',
          'isLive': true,
          'isAdult': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
        });
        await firestore
            .collection('rooms')
            .doc('public-room')
            .collection('participants')
            .doc('host-1')
            .set({'lastActiveAt': Timestamp.now()});

        await firestore.collection('rooms').doc('adult-room').set({
          'name': 'Adult Room',
          'hostId': 'host-2',
          'isLive': true,
          'isAdult': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
        });
        await firestore
            .collection('rooms')
            .doc('adult-room')
            .collection('participants')
            .doc('host-2')
            .set({'lastActiveAt': Timestamp.now()});

        final rooms = await service.getLiveRooms(limit: 10);

        expect(rooms.map((room) => room.id), contains('public-room'));
        expect(rooms.map((room) => room.id), isNot(contains('adult-room')));
      },
    );

    test(
      'getLiveRooms still includes legacy live rooms missing isAdult',
      () async {
        await firestore.collection('rooms').doc('legacy-room').set({
          'name': 'Legacy Room',
          'hostId': 'legacy-host',
          'isLive': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 8)),
        });
        await firestore
            .collection('rooms')
            .doc('legacy-room')
            .collection('participants')
            .doc('legacy-host')
            .set({'lastActiveAt': Timestamp.now()});

        final rooms = await service.getLiveRooms(limit: 10);

        expect(rooms.map((room) => room.id), contains('legacy-room'));
      },
    );

    test(
      'getLiveRooms keeps real active rooms visible when heartbeat sync lags',
      () async {
        await firestore.collection('rooms').doc('room-realtime').set({
          'name': 'Realtime Room',
          'hostId': 'host-rt',
          'isLive': true,
          'isAdult': false,
          'memberCount': 3,
          'stageUserIds': <String>['host-rt'],
          'audienceUserIds': <String>['user-2', 'user-3'],
          'updatedAt': Timestamp.now(),
        });

        final rooms = await service.getLiveRooms(limit: 10);

        expect(rooms.map((room) => room.id), contains('room-realtime'));
        expect(
          rooms.firstWhere((room) => room.id == 'room-realtime').memberCount,
          3,
        );
      },
    );

    test('getRecommendedLiveRooms boosts friend-hosted rooms', () async {
      await firestore.collection('rooms').doc('room-friend').set({
        'name': 'Friend Room',
        'hostId': 'friend-1',
        'isLive': true,
        'isAdult': false,
        'memberCount': 1,
        'stageUserIds': <String>[],
        'audienceUserIds': <String>['friend-1'],
        'isLocked': false,
        'updatedAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      });
      await firestore
          .collection('rooms')
          .doc('room-friend')
          .collection('participants')
          .doc('friend-1')
          .set({'lastActiveAt': Timestamp.now()});
      await firestore.collection('rooms').doc('room-busy').set({
        'name': 'Busy Room',
        'hostId': 'host-2',
        'isLive': true,
        'isAdult': false,
        'memberCount': 18,
        'stageUserIds': <String>[],
        'audienceUserIds': <String>['host-2'],
        'isLocked': false,
        'updatedAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      });
      await firestore
          .collection('rooms')
          .doc('room-busy')
          .collection('participants')
          .doc('host-2')
          .set({'lastActiveAt': Timestamp.now()});

      final rooms = await service.getRecommendedLiveRooms(
        limit: 2,
        friendIds: const <String>{'friend-1'},
      );

      expect(rooms, hasLength(2));
      expect(rooms.first.id, 'room-friend');
    });

    test('getRecommendedLiveRooms excludes blocked hosts', () async {
      await firestore.collection('rooms').doc('room-a').set({
        'name': 'Room A',
        'hostId': 'blocked-host',
        'isLive': true,
        'isAdult': false,
        'memberCount': 10,
        'stageUserIds': <String>[],
        'audienceUserIds': <String>['blocked-host'],
        'isLocked': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('blocked-host')
          .set({'lastActiveAt': Timestamp.now()});
      await firestore.collection('rooms').doc('room-b').set({
        'name': 'Room B',
        'hostId': 'safe-host',
        'isLive': true,
        'isAdult': false,
        'memberCount': 3,
        'stageUserIds': <String>[],
        'audienceUserIds': <String>['safe-host'],
        'isLocked': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      await firestore
          .collection('rooms')
          .doc('room-b')
          .collection('participants')
          .doc('safe-host')
          .set({'lastActiveAt': Timestamp.now()});

      final rooms = await service.getRecommendedLiveRooms(
        limit: 10,
        excludedHostIds: const <String>{'blocked-host'},
      );

      expect(rooms.map((room) => room.id), isNot(contains('room-a')));
      expect(rooms.map((room) => room.id), contains('room-b'));
    });

    test(
      'getLiveRooms can exclude adult rooms for public discovery queries',
      () async {
        await firestore.collection('rooms').doc('public-room').set({
          'name': 'Public Room',
          'hostId': 'host-1',
          'isLive': true,
          'isAdult': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
        });
        await firestore
            .collection('rooms')
            .doc('public-room')
            .collection('participants')
            .doc('host-1')
            .set({'lastActiveAt': Timestamp.now()});

        await firestore.collection('rooms').doc('adult-room').set({
          'name': 'Adult Room',
          'hostId': 'host-2',
          'isLive': true,
          'isAdult': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
        });
        await firestore
            .collection('rooms')
            .doc('adult-room')
            .collection('participants')
            .doc('host-2')
            .set({'lastActiveAt': Timestamp.now()});

        final rooms = await service.getLiveRooms(
          limit: 10,
          includeAdultRooms: false,
        );

        expect(rooms.map((room) => room.id), contains('public-room'));
        expect(rooms.map((room) => room.id), isNot(contains('adult-room')));
      },
    );

    test(
      'watchLiveRooms keeps recently seen rooms visible through a transient live gap',
      () async {
        await firestore.collection('rooms').doc('room-a').set({
          'name': 'Room A',
          'hostId': 'host-a',
          'isLive': true,
          'isAdult': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
        });
        await firestore.collection('rooms').doc('room-b').set({
          'name': 'Room B',
          'hostId': 'host-b',
          'isLive': true,
          'isAdult': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 10)),
        });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .doc('host-a')
            .set({'lastActiveAt': Timestamp.now()});
        await firestore
            .collection('rooms')
            .doc('room-b')
            .collection('participants')
            .doc('host-b')
            .set({'lastActiveAt': Timestamp.now()});

        final emissions = <List<RoomModel>>[];
        final sub = service.watchLiveRooms(limit: 10).listen(emissions.add);
        addTearDown(sub.cancel);

        // Allow initial emission to settle
        await Future<void>.delayed(const Duration(milliseconds: 500));
        
        await firestore.collection('rooms').doc('room-b').set({
          'isLive': false,
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));

        // Allow debounce window and classification to finish
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        expect(emissions, isNotEmpty);
        // Stabilized stream should keep room-b for the grace window duration
        expect(emissions.last.map((room) => room.id), contains('room-b'));
      },
    );

    test(
      'watchLiveRooms keeps the last known audience count during partial room updates',
      () async {
        await firestore.collection('rooms').doc('room-a').set({
          'name': 'Room A',
          'hostId': 'host-a',
          'isLive': true,
          'isAdult': false,
          'memberCount': 5,
          'stageUserIds': <String>['host-a'],
          'audienceUserIds': <String>['u-1', 'u-2', 'u-3', 'u-4'],
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1, 9)),
        });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .doc('host-a')
            .set({'lastActiveAt': Timestamp.now()});

        final emissions = <List<RoomModel>>[];
        final sub = service.watchLiveRooms(limit: 10).listen(emissions.add);
        addTearDown(sub.cancel);

        await Future<void>.delayed(const Duration(milliseconds: 500));
        await firestore.collection('rooms').doc('room-a').set({
          'memberCount': 0,
          'stageUserIds': <String>[],
          'audienceUserIds': <String>[],
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));

        await Future<void>.delayed(const Duration(milliseconds: 1000));

        expect(emissions, isNotEmpty);
        expect(emissions.last.single.memberCount, greaterThanOrEqualTo(5));
      },
    );

    test('getRecommendationReason returns social and popularity labels', () {
      final friendHostedRoom = RoomModel(
        id: 'room-1',
        name: 'Friend Room',
        hostId: 'friend-1',
        memberCount: 1,
      );
      final popularRoom = RoomModel(
        id: 'room-2',
        name: 'Popular Room',
        hostId: 'host-2',
        memberCount: 50,
      );

      final friendReason = service.getRecommendationReason(
        friendHostedRoom,
        friendIds: const <String>{'friend-1'},
      );
      final popularReason = service.getRecommendationReason(popularRoom);

      expect(friendReason, 'Friend is hosting');
      expect(popularReason, 'Popular right now');
    });

    test(
      'getRecommendationTier classifies rooms by social/popularity/recency',
      () {
        final friendRoom = RoomModel(
          id: 'room-f',
          name: 'Friend Room',
          hostId: 'friend-1',
        );
        final hotRoom = RoomModel(
          id: 'room-h',
          name: 'Hot Room',
          hostId: 'host-2',
          memberCount: 30,
        );
        final freshRoom = RoomModel(
          id: 'room-r',
          name: 'Fresh Room',
          hostId: 'host-3',
          updatedAt: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 10)),
          ),
        );
        final liveRoom = RoomModel(
          id: 'room-l',
          name: 'Live Room',
          hostId: 'host-4',
          updatedAt: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 3)),
          ),
        );

        expect(
          service.getRecommendationTier(
            friendRoom,
            friendIds: const <String>{'friend-1'},
          ),
          'Friends',
        );
        expect(service.getRecommendationTier(hotRoom), 'Hot');
        expect(service.getRecommendationTier(freshRoom), 'Fresh');
        expect(service.getRecommendationTier(liveRoom), 'Live');
      },
    );

    test('watchRoomById returns null stream for empty id', () async {
      final result = await service.watchRoomById('   ').first;
      expect(result, isNull);
    });

    test('setRoomLiveStatus trims room id before update', () async {
      await firestore.collection('rooms').doc('room-1').set({
        'name': 'Room One',
        'hostId': 'host-1',
        'isLive': false,
      });

      await service.setRoomLiveStatus(' room-1 ', isLive: true);

      final updated = await firestore.collection('rooms').doc('room-1').get();
      expect(updated.data()?['isLive'], true);
    });

    test('deleteRoom trims room id before delete', () async {
      await firestore.collection('rooms').doc('room-1').set({
        'name': 'Room One',
        'hostId': 'host-1',
        'isLive': true,
      });

      await service.deleteRoom(' room-1 ');

      final deleted = await firestore.collection('rooms').doc('room-1').get();
      expect(deleted.exists, isFalse);
    });

    test('getRoomById returns null for empty id', () async {
      final result = await service.getRoomById('   ');
      expect(result, isNull);
    });
  });
}
