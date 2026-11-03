import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mixvy/services/webrtc_room_service.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MockRTCPeerConnection extends Mock implements RTCPeerConnection {}

class MockMediaStream extends Mock implements MediaStream {}

class MockMediaStreamTrack extends Mock implements MediaStreamTrack {}

class MockStreamLifecycleManager extends Mock
    implements StreamLifecycleManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    test('only treats active unmuted video tracks as renderable', () {
      final stream = MockMediaStream();
      final track = MockMediaStreamTrack();
      when(() => stream.getVideoTracks()).thenReturn([track]);
      when(() => track.enabled).thenReturn(true);
      when(() => track.muted).thenReturn(false);

      expect(hasRenderableVideoTrack(stream), isTrue);

      when(() => track.muted).thenReturn(true);
      expect(hasRenderableVideoTrack(stream), isFalse);

      when(() => track.muted).thenReturn(false);
      when(() => track.enabled).thenReturn(false);
      expect(hasRenderableVideoTrack(stream), isFalse);
    });

    test('initializes with firestore', () {
      expect(service, isNotNull);
    });

    test('can mute and restore incoming room playback', () async {
      await expectLater(service.setSpeakerVolume(0.0), completes);
      await expectLater(service.setSpeakerVolume(1.0), completes);
    });

    test('registers a browser connection identity when joining', () async {
      await service.joinRoom('', 'room-a', 42);

      final participant = await firestore
          .collection('webrtc_sessions')
          .doc('room-a')
          .collection('participants')
          .doc('test-user')
          .get();

      expect(participant.data()?['connectionId'], isA<String>());
      expect(
        (participant.data()?['connectionId'] as String?)?.isNotEmpty,
        isTrue,
      );

      await service.dispose();
    });

    test(
        'ensureDeviceAccess throws in unit environment without plugin bindings',
        () async {
      await expectLater(
        service.ensureDeviceAccess(video: true, audio: true),
        throwsA(isA<Exception>()),
      );
    });

    // Note: Testing createRoom/joinRoom requires mocking global methods
    // like createPeerConnection, which is difficult in pure unit tests
    // without dependency injection for the factory.
  });
}
