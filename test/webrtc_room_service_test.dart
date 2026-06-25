import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mixvy/services/webrtc_room_service.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MockRTCPeerConnection extends Mock implements RTCPeerConnection {}
class MockMediaStream extends Mock implements MediaStream {}
class MockStreamLifecycleManager extends Mock implements StreamLifecycleManager {}

void main() {
  late WebRtcRoomService service;
  late FakeFirebaseFirestore firestore;
  late MockStreamLifecycleManager lifecycleManager;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    lifecycleManager = MockStreamLifecycleManager();
    service = WebRtcRoomService(
      firestore: firestore,
      localUserId: 'test-user',
      streamLifecycleManager: lifecycleManager,
    );
  });

  group('WebRtcRoomService', () {
    test('initializes with firestore', () {
      expect(service, isNotNull);
    });

    test('ensureDeviceAccess does not throw', () async {
      await expectLater(
        service.ensureDeviceAccess(video: true, audio: true),
        completes,
      );
    });

    // Note: Testing createRoom/joinRoom requires mocking global methods 
    // like createPeerConnection, which is difficult in pure unit tests 
    // without dependency injection for the factory.
  });
}
