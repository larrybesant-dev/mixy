import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/mic_access_provider.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';
import 'package:mixvy/features/room/room_controller.dart';
import 'package:mixvy/features/room/services/room_session_service.dart';
import 'package:mixvy/models/presence_model.dart';
import 'package:mixvy/services/presence_controller.dart';
import 'package:mixvy/services/rtc_room_service.dart';
import 'package:mixvy/services/connection_recovery_handler.dart';
import 'package:mixvy/services/room_session_gateway.dart';

class _ChaosPresenceController extends PresenceController {
  final Map<String, PresenceControllerState> writesByUser =
      <String, PresenceControllerState>{};

  @override
  PresenceControllerState build() => const PresenceControllerState();

  @override
  Future<void> setInRoom(String userId, String roomId) async {
    writesByUser[userId] = PresenceControllerState(
      userId: userId,
      status: UserStatus.online,
      appState: PresenceAppState.foreground,
      inRoom: roomId,
    );
  }

  @override
  Future<void> clearInRoom(String userId) async {
    writesByUser[userId] = PresenceControllerState(
      userId: userId,
      status: UserStatus.online,
      appState: PresenceAppState.foreground,
      inRoom: null,
    );
  }
}

class _FakeRtcRoomService extends RtcRoomService {
  bool broadcaster = false;
  bool joined = true;
  bool localVideoCapturing = false;
  bool localAudioMuted = true;
  int publishAudioCalls = 0;
  int muteCalls = 0;
  int broadcasterCalls = 0;

  @override
  VoidCallback? onRemoteUserJoined;

  @override
  VoidCallback? onRemoteUserLeft;

  @override
  VoidCallback? onSpeakerActivityChanged;

  @override
  VoidCallback? onLocalVideoCaptureChanged;

  @override
  VoidCallback? onTokenWillExpire;

  @override
  VoidCallback? onConnectionLost;

  @override
  ValueChanged<RtcConnectionState>? onConnectionStateChanged;

  @override
  List<int> get remoteUids => const <int>[];

  @override
  bool get localSpeaking => !localAudioMuted;

  @override
  bool get canRenderLocalView => true;

  @override
  bool get isBroadcaster => broadcaster;

  @override
  bool get isJoinedChannel => joined;

  @override
  bool get isLocalVideoCapturing => localVideoCapturing;

  @override
  bool get isLocalAudioMuted => localAudioMuted;

  @override
  RtcConnectionState get connectionState => RtcConnectionState.idle;

  @override
  int get reconnectAttemptCount => 0;

  @override
  bool isRemoteSpeaking(int uid) => false;

  @override
  Widget getLocalView() => const SizedBox.shrink();

  @override
  Widget getRemoteView(int uid, String channelId) => const SizedBox.shrink();

  @override
  Future<void> initialize(String appId) async {}

  @override
  Future<void> joinRoom(
    String token,
    String channelName,
    int uid, {
    bool publishCameraTrackOnJoin = false,
    bool publishMicrophoneTrackOnJoin = false,
  }) async {}

  @override
  Future<void> enableVideo(
    bool enabled, {
    bool publishMicrophoneTrack = true,
  }) async {
    localVideoCapturing = enabled;
  }

  @override
  Future<void> mute(bool muted) async {
    muteCalls += 1;
    localAudioMuted = muted;
  }

  @override
  Future<void> setBroadcaster(bool enabled) async {
    broadcasterCalls += 1;
    broadcaster = enabled;
  }

  @override
  Future<void> publishLocalVideoStream(bool enabled) async {
    localVideoCapturing = enabled;
  }

  @override
  Future<void> publishLocalAudioStream(bool enabled) async {
    publishAudioCalls += 1;
    localAudioMuted = !enabled;
  }

  @override
  Future<void> setRemoteVideoSubscription(
    int uid, {
    required bool subscribe,
    bool highQuality = false,
  }) async {}

  @override
  Future<void> renewToken(String newToken) async {}

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> abortReconnection() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> ensureDeviceAccess({
    required bool video,
    required bool audio,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('room chaos master', () {
    test('host migration converges to one authoritative host', () {
      final state = RoomState(
        phase: LiveRoomPhase.joined,
        lifecycleState: RoomLifecycleState.active,
        roomId: 'room-a',
        currentUserId: 'user-2',
        hostId: 'user-2',
        userIds: const <String>['host-1', 'user-2'],
        stableUserIds: const <String>['host-1', 'user-2'],
        participantRolesByUser: const <String, String>{
          'host-1': 'host',
          'user-2': 'audience',
        },
        sessionSnapshotsByUser: const <String, RoomSessionSnapshot>{
          'host-1': RoomSessionSnapshot(
            userId: 'host-1',
            displayName: 'Old Host',
            role: 'host',
          ),
          'user-2': RoomSessionSnapshot(
            userId: 'user-2',
            displayName: 'New Host',
            role: 'audience',
          ),
        },
      );

      expect(
        state.canExecute(RoomAction.manageRoom, userId: 'host-1'),
        isFalse,
      );
      expect(state.canExecute(RoomAction.manageRoom, userId: 'user-2'), isTrue);
    });

    test('same user joining from two controllers remains deduped', () async {
      final firestore = FakeFirebaseFirestore();
      final roomSessionGateway = RoomSessionGateway(firestore);
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'ownerId': 'host-1',
        'isLocked': false,
      });
      await firestore.collection('users').doc('user-1').set({
        'isComplete': true,
        'username': 'user1',
        'displayName': 'Device One',
      });

      final presenceController = _ChaosPresenceController();
      final sessionService = RoomSessionService(
        firestore: firestore,
        roomSessionGateway: roomSessionGateway,
        presenceController: presenceController,
      );

      final firstContainer = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomSessionServiceProvider.overrideWithValue(sessionService),
        ],
      );
      final secondContainer = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomSessionServiceProvider.overrideWithValue(sessionService),
        ],
      );
      addTearDown(firstContainer.dispose);
      addTearDown(secondContainer.dispose);

      final firstController = firstContainer.read(
        roomControllerProvider('room-a').notifier,
      );
      final secondController = secondContainer.read(
        roomControllerProvider('room-a').notifier,
      );

      final results = await Future.wait([
        firstController.joinRoom('user-1', displayName: 'Device One'),
        secondController.joinRoom('user-1', displayName: 'Device Two'),
      ]);

      expect(results.every((result) => result.isSuccess), isTrue);

      final participantSnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .get();
      final memberSnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('members')
          .get();

      expect(participantSnapshot.docs.length, 1);
      expect(memberSnapshot.docs.length, 1);
      expect(participantSnapshot.docs.single.id, 'user-1');
      expect(memberSnapshot.docs.single.id, 'user-1');
    });

    test('host migration keeps only one active mic request per user', () async {
      final firestore = FakeFirebaseFirestore();
      final controller = MicAccessController(firestore);
      const roomId = 'room-a';

      await firestore.collection('rooms').doc(roomId).set({
        'hostId': 'host-1',
        'ownerId': 'host-1',
        'micQueueSequence': 0,
      });

      await controller.requestAccess(
        roomId: roomId,
        requesterId: 'user-1',
        hostId: 'host-1',
      );

      await firestore.collection('rooms').doc(roomId).set({
        'hostId': 'host-2',
        'ownerId': 'host-2',
      }, SetOptions(merge: true));

      await controller.requestAccess(
        roomId: roomId,
        requesterId: 'user-1',
        hostId: 'host-2',
      );

      final requestSnapshot = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('micQueue')
          .where('requesterId', isEqualTo: 'user-1')
          .get();

      final pendingRequests = requestSnapshot.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .toList(growable: false);

      expect(pendingRequests.length, 1);
      expect(pendingRequests.single.data()['hostId'], 'host-2');
        expect(requestSnapshot.docs.length, lessThanOrEqualTo(2));
    });

    test(
      'presence cleanup stays consistent through leave and rejoin',
      () async {
        final firestore = FakeFirebaseFirestore();
        final roomSessionGateway = RoomSessionGateway(firestore);
        final presenceController = _ChaosPresenceController();
        final sessionService = RoomSessionService(
          firestore: firestore,
          roomSessionGateway: roomSessionGateway,
          presenceController: presenceController,
        );

        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'host-1',
          'ownerId': 'host-1',
          'isLocked': false,
        });
        await firestore.collection('users').doc('user-9').set({
          'isComplete': true,
          'username': 'user9',
          'displayName': 'User Nine',
        });

        final joinResult = await sessionService.joinRoom(
          roomId: 'room-a',
          userId: 'user-9',
        );
        expect(joinResult.isSuccess, isTrue);
        expect(presenceController.writesByUser['user-9']?.inRoom, 'room-a');

        await sessionService.leaveRoom(roomId: 'room-a', userId: 'user-9');
        expect(presenceController.writesByUser['user-9']?.inRoom, isNull);

        final rejoinResult = await sessionService.joinRoom(
          roomId: 'room-a',
          userId: 'user-9',
        );
        expect(rejoinResult.isSuccess, isTrue);
        expect(presenceController.writesByUser['user-9']?.inRoom, 'room-a');

        final participantSnapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .get();
        expect(participantSnapshot.docs.length, 1);
      },
    );

    test('mic queue flood keeps unique pending requests under churn', () async {
      final firestore = FakeFirebaseFirestore();
      final controller = MicAccessController(firestore);
      const roomId = 'room-a';
      const hostId = 'host-1';

      await firestore.collection('rooms').doc(roomId).set({
        'hostId': hostId,
        'ownerId': hostId,
        'micQueueSequence': 0,
      });

      final requesters = List<String>.generate(30, (index) => 'user-$index');
      await Future.wait([
        for (final requester in requesters)
          controller.requestAccess(
            roomId: roomId,
            requesterId: requester,
            hostId: hostId,
          ),
      ]);

      await Future.wait([
        controller.requestAccess(
          roomId: roomId,
          requesterId: 'user-3',
          hostId: hostId,
        ),
        controller.requestAccess(
          roomId: roomId,
          requesterId: 'user-7',
          hostId: hostId,
        ),
        controller.cancelRequest(roomId, 'user-5_$hostId'),
        controller.cancelRequest(roomId, 'user-11_$hostId'),
      ]);

      final queueSnapshot = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('micQueue')
          .get();

      final requesterIds = queueSnapshot.docs
          .map((doc) => doc.data()['requesterId'] as String?)
          .whereType<String>()
          .toList(growable: false);

      expect(requesterIds.toSet().length, 30);

      final statusByRequester = <String, String>{
        for (final doc in queueSnapshot.docs)
          if ((doc.data()['requesterId'] as String?) != null)
            (doc.data()['requesterId'] as String):
                (doc.data()['status'] as String? ?? ''),
      };

      expect(statusByRequester['user-5'], 'cancelled');
      expect(statusByRequester['user-11'], 'cancelled');
      expect(statusByRequester['user-3'], 'pending');
      expect(statusByRequester['user-7'], 'pending');

      final pendingCount = statusByRequester.values
          .where((status) => status == 'pending')
          .length;
      expect(pendingCount, greaterThanOrEqualTo(28));
      expect(pendingCount, lessThanOrEqualTo(30));
    });

    test('rtc audio sync stays consistent under rapid abuse', () async {
      final service = _FakeRtcRoomService();
      final sequence = <RoomAudioState>[
        for (var i = 0; i < 20; i++)
          if (i.isEven) RoomAudioState.speaking else RoomAudioState.muted,
        RoomAudioState.requestingMic,
        RoomAudioState.speaking,
        RoomAudioState.denied,
      ];

      for (final state in sequence) {
        await service.syncAudio(
          state,
          shouldMute: state != RoomAudioState.speaking,
        );
      }

      expect(service.isBroadcaster, isFalse);
      expect(service.isLocalAudioMuted, isTrue);
      expect(service.publishAudioCalls, greaterThan(0));
      expect(service.muteCalls, greaterThan(0));
      expect(service.broadcasterCalls, greaterThan(0));
    });

    test(
      'combined chaos run converges without stuck authority or duplicates',
      () async {
        final firestore = FakeFirebaseFirestore();
        final roomSessionGateway = RoomSessionGateway(firestore);
        final presenceController = _ChaosPresenceController();
        final sessionService = RoomSessionService(
          firestore: firestore,
          roomSessionGateway: roomSessionGateway,
          presenceController: presenceController,
        );
        final micAccess = MicAccessController(firestore);
        final rtcService = _FakeRtcRoomService();

        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'host-1',
          'ownerId': 'host-1',
          'isLocked': false,
          'micQueueSequence': 0,
        });
        for (final seedUserId in ['host-1', 'host-2', 'user-9']) {
          await firestore.collection('users').doc(seedUserId).set({
            'isComplete': true,
            'username': seedUserId,
            'displayName': seedUserId,
          });
        }

        final oldHostContainer = ProviderContainer(
          overrides: [
            roomFirestoreProvider.overrideWithValue(firestore),
            roomSessionServiceProvider.overrideWithValue(sessionService),
          ],
        );
        final newHostContainer = ProviderContainer(
          overrides: [
            roomFirestoreProvider.overrideWithValue(firestore),
            roomSessionServiceProvider.overrideWithValue(sessionService),
          ],
        );
        addTearDown(oldHostContainer.dispose);
        addTearDown(newHostContainer.dispose);

        final oldHostController = oldHostContainer.read(
          roomControllerProvider('room-a').notifier,
        );
        final newHostController = newHostContainer.read(
          roomControllerProvider('room-a').notifier,
        );

        expect(
          (await oldHostController.joinRoom(
            'host-1',
            displayName: 'Old Host',
          )).isSuccess,
          isTrue,
        );
        expect(
          (await newHostController.joinRoom(
            'host-2',
            displayName: 'New Host',
          )).isSuccess,
          isTrue,
        );

        oldHostController.hydrateCurrentUser(
          'host-1',
          displayName: 'Old Host',
          role: 'host',
        );
        newHostController.hydrateCurrentUser(
          'host-2',
          displayName: 'New Host',
          role: 'cohost',
        );

        final duplicateJoins = await Future.wait([
          sessionService.joinRoom(roomId: 'room-a', userId: 'user-9'),
          sessionService.joinRoom(roomId: 'room-a', userId: 'user-9'),
        ]);
        expect(duplicateJoins.every((result) => result.isSuccess), isTrue);

        await micAccess.requestAccess(
          roomId: 'room-a',
          requesterId: 'user-9',
          hostId: 'host-1',
        );

        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'host-2',
          'ownerId': 'host-2',
        }, SetOptions(merge: true));
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        await expectLater(
          oldHostController.setMicTimer(30),
          throwsA(isA<StateError>()),
        );
        await expectLater(newHostController.setMicTimer(45), completes);

        await Future.wait([
          for (var i = 0; i < 20; i++)
            micAccess.requestAccess(
              roomId: 'room-a',
              requesterId: 'audience-$i',
              hostId: 'host-2',
            ),
        ]);

        for (final state in <RoomAudioState>[
          RoomAudioState.speaking,
          RoomAudioState.muted,
          RoomAudioState.speaking,
          RoomAudioState.requestingMic,
          RoomAudioState.denied,
        ]) {
          await rtcService.syncAudio(
            state,
            shouldMute: state != RoomAudioState.speaking,
          );
        }

        await oldHostController.leaveRoom();
        expect(presenceController.writesByUser['host-1']?.inRoom, isNull);
        expect(presenceController.writesByUser['host-2']?.inRoom, 'room-a');

        final participantSnapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .get();
        final participantIds = participantSnapshot.docs
            .map((doc) => doc.id)
            .toList(growable: false);
        expect(participantIds.toSet().length, participantIds.length);

        final queueSnapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('mic_access_requests')
            .get();
        final pendingRequesterIds = queueSnapshot.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .map((doc) => doc.data()['requesterId'] as String?)
            .whereType<String>()
            .toList(growable: false);
        expect(pendingRequesterIds.toSet().length, pendingRequesterIds.length);

        final policySnapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('policies')
            .doc('settings')
            .get();
        expect(policySnapshot.data()?['micTimerSeconds'], 45);
        expect(rtcService.isLocalAudioMuted, isTrue);
        expect(rtcService.isBroadcaster, isFalse);
      },
    );
  });
}
