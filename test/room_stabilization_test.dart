import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/room_controller.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';

void main() {
  group('Room stabilization logic', () {
    test('User moves from pending to stable after delay', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('test-room').set({
        'hostId': 'host-1',
        'isLocked': false,
      });

      final container = ProviderContainer(
        overrides: [roomFirestoreProvider.overrideWithValue(firestore)],
      );
      addTearDown(container.dispose);

      final controller = container.read(roomControllerProvider('test-room').notifier);
      
      // Join room
      await controller.joinRoom('user-1', displayName: 'User One');
      
      var state = container.read(roomControllerProvider('test-room'));
      expect(state.pendingUserIds, contains('user-1'));
      expect(state.stableUserIds, isNot(contains('user-1')));

      // Wait for stabilization delay (default is 1s in kRoomJoinStabilizationDelay if it matches contract)
      // Since we are in a test, Timer might need to be pumped or we wait real time.
      // But standard Flutter tests use fake async.
      
      await Future.delayed(const Duration(seconds: 2));
      
      state = container.read(roomControllerProvider('test-room'));
      expect(state.pendingUserIds, isNot(contains('user-1')));
      expect(state.stableUserIds, contains('user-1'));
    });
  });
}
