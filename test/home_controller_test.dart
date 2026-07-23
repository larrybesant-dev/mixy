import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/home/home_controller.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('HomeController', () {
    late ProviderContainer container;
    setUp(() {
      // Optionally, override providers here if needed
      container = ProviderContainer();
    });

    test('addRoom adds a room', () {
      final controller = container.read(homeControllerProvider.notifier);
      final room = RoomModel(
        id: 'room1',
        name: 'Test Room',
        hostId: 'host1',
        createdAt: Timestamp.fromDate(DateTime.now()),
      );
      controller.addRoom(room);
      final state = container.read(homeControllerProvider);
      expect(state.length, 1);
      expect(state.first.id, 'room1');
    });

    test('removeRoom removes a room', () {
      final controller = container.read(homeControllerProvider.notifier);
      final room = RoomModel(
        id: 'room1',
        name: 'Test Room',
        hostId: 'host1',
        createdAt: Timestamp.fromDate(DateTime.now()),
      );
      controller.addRoom(room);
      controller.removeRoom('room1');
      final state = container.read(homeControllerProvider);
      expect(state.isEmpty, true);
    });
  });
}
