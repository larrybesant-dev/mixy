import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mixvy/services/webrtc_room_service.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MixVy WebRTC Signaling Concurrency & Handshake Stress Test', () {
    testWidgets('Verify multi-user concurrent signaling handshake stability',
        (WidgetTester tester) async {
      debugPrint('[STRESS_TEST] Initializing test harness...');

      // 1. Prepare shared Fake Firestore database and Stream Lifecycle Manager
      final firestore = FakeFirebaseFirestore();
      final streamManager = StreamLifecycleManager();
      const channelName = 'concurrency_lounge_999';

      // 2. Define a list of 5 test user IDs simulating concurrent stress actors
      final testUsers = [
        'actor_omega_1',
        'actor_omega_2',
        'actor_omega_3',
        'actor_omega_4',
        'actor_omega_5',
      ];

      final Map<String, WebRtcRoomService> activeClients = {};

      // 3. Instantiate the WebRtcRoomService for each user
      for (final userId in testUsers) {
        activeClients[userId] = WebRtcRoomService(
          firestore: firestore,
          localUserId: userId,
          streamLifecycleManager: streamManager,
        );
      }

      debugPrint(
          '[STRESS_TEST] Instantiated ${testUsers.length} concurrent clients.');

      // 4. Concurrently join the WebRTC signaling room
      debugPrint('[STRESS_TEST] Joining room "$channelName" concurrently...');
      final List<Future<void>> joinFutures = [];
      for (int i = 0; i < testUsers.length; i++) {
        final userId = testUsers[i];
        final client = activeClients[userId]!;
        final uid = 1000 + i;
        joinFutures.add(
          client.joinRoom(
            'mock-token-$userId',
            channelName,
            uid,
            publishCameraTrackOnJoin: false,
            publishMicrophoneTrackOnJoin: false,
          ),
        );
      }

      await Future.wait(joinFutures);
      debugPrint('[STRESS_TEST] All clients initiated joinRoom successfully.');

      // 5. Allow some pump-and-settle / timer execution duration
      // We are running within standard flutter test frame system, so we pump to let tasks schedule
      await tester.pump(const Duration(seconds: 2));

      // 6. Verify that each participant is correctly registered in firestore
      final sessionRef =
          firestore.collection('webrtc_sessions').doc(channelName);
      final participantsSnap =
          await sessionRef.collection('participants').get();

      debugPrint(
          '[STRESS_TEST] Total registered participants in Firestore: ${participantsSnap.docs.length}');
      expect(participantsSnap.docs.length, equals(testUsers.length));

      for (final doc in participantsSnap.docs) {
        debugPrint('[STRESS_TEST] Verifying participant document: ${doc.id}');
        expect(testUsers.contains(doc.id), isTrue);
      }

      // 7. Clean up and dispose of all concurrent actors cleanly
      debugPrint('[STRESS_TEST] Cleaning up and disposing of all actors...');
      final List<Future<void>> disposeFutures = [];
      for (final userId in testUsers) {
        disposeFutures.add(activeClients[userId]!.dispose());
      }
      await Future.wait(disposeFutures);

      debugPrint(
          '[STRESS_TEST][SUCCESS] Concurrent signaling handshake stress test passed perfectly!');
    });
  });
}
