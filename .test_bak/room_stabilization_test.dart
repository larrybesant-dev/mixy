import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixvy/features/room/room_controller.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

import 'package:fake_async/fake_async.dart';
import 'test_helpers.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('Room stabilization logic', () {
    test('User moves from pending to stable after delay', () async {
      fakeAsync((async) {
        final firestore = FakeFirebaseFirestore();
        firestore.collection('rooms').doc('test-room').set({
          'hostId': 'host-1',
          'isLocked': false,
        });

        final mockAuth = MockFirebaseAuth();
        final mockUser = MockUser();
        when(() => mockUser.uid).thenReturn('user-1');
        when(() => mockAuth.currentUser).thenReturn(mockUser);

        final container = ProviderContainer(
          overrides: [
            roomFirestoreProvider.overrideWithValue(firestore),
            firebaseAuthProvider.overrideWithValue(mockAuth),
          ]);
        final sub = container.listen(roomControllerProvider('test-room'), (_, __) {});
        
        final controller = container.read(roomControllerProvider('test-room').notifier);
        
        // Join room - runTransaction is async
        final joinFuture = controller.joinRoom('user-1', displayName: 'User One');
        
        // Elapse time for transaction and initial state emission
        async.flushMicrotasks();
        
        var state = container.read(roomControllerProvider('test-room'));
        expect(state.pendingUserIds, contains('user-1'), reason: 'User should be in pendingUserIds immediately after join');
        expect(state.stableUserIds, isNot(contains('user-1')), reason: 'User should NOT be in stableUserIds until stabilization delay passes');

        // stabilization delay is 350ms
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        
        state = container.read(roomControllerProvider('test-room'));
        expect(state.pendingUserIds, isNot(contains('user-1')), reason: 'User should be removed from pendingUserIds after stabilization delay');
        expect(state.stableUserIds, contains('user-1'), reason: 'User should be moved to stableUserIds after stabilization delay');

        joinFuture.ignore();

        sub.close();
        container.dispose();
      });
    });
  });
}










