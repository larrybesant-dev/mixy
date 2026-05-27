import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mixvy/services/webrtc_room_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MockRTCPeerConnection extends Mock implements RTCPeerConnection {}
class MockMediaStream extends Mock implements MediaStream {}

void main() {
  late WebRTCRoomService service;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = WebRTCRoomService(firestore: firestore);
  });

  group('WebRTCRoomService', () {
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
