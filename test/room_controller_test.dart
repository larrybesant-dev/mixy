import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/mic_access_provider.dart';
import 'package:mixvy/features/room/providers/participant_providers.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';
import 'package:mixvy/features/room/room_controller.dart';
import 'package:mixvy/features/room/services/room_session_service.dart';
import 'package:mixvy/models/room_participant_model.dart';
import 'package:mixvy/services/presence_controller.dart';

class _SpyMicAccessController extends MicAccessController {
  _SpyMicAccessController() : super(FakeFirebaseFirestore());

  bool queued = false;
  bool grabbed = false;
  bool cancelled = false;

  @override
  Future<void> requestAccess({
    required String roomId,
    required String requesterId,
    required String hostId,
    int? priority,
  }) async {
    queued = true;
  }

  @override
  Future<void> grabMicDirectly({
    required String roomId,
    required String userId,
  }) async {
    grabbed = true;
  }

  @override
  Future<void> cancelRequest(String roomId, String requestId) async {
    cancelled = true;
  }
}

class _TestPresenceController extends PresenceController {
  @override
  PresenceControllerState build() => const PresenceControllerState();

  @override
  Future<void> setInRoom(String userId, String roomId) async {}

  @override
  Future<void> clearInRoom(String userId) async {}
}

class _FlakyRoomSessionService extends RoomSessionService {
  _FlakyRoomSessionService({
    required super.firestore,
    required super.presenceController,
    this.joinFailuresRemaining = 0,
  });

  int joinFailuresRemaining;
  int heartbeatFailuresRemaining = 0;

  @override
  Future<RoomJoinResult> joinRoom({
    String? displayName,
    String? photoUrl,
    required String roomId,
    Transaction? transaction, // Add this line!
    required String userId,
  }) async {
    if (joinFailuresRemaining > 0) {
      joinFailuresRemaining -= 1;
      throw StateError('simulated join failure');
    }
    return super.joinRoom(
      roomId: roomId,
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  @override
  Future<DateTime> heartbeat({
    required String roomId,
    required String userId,
    DateTime? lastParticipantSyncAt,
    bool forceParticipantSync = false,
  }) async {
    if (heartbeatFailuresRemaining > 0) {
      heartbeatFailuresRemaining -= 1;
      throw StateError('simulated heartbeat failure');
    }
    return super.heartbeat(
      roomId: roomId,
      userId: userId,
      lastParticipantSyncAt: lastParticipantSyncAt,
      forceParticipantSync: forceParticipantSync,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoomController', () {
    test(
      'membership authority keeps the active user in-room while state hydrates',
      () {
        const state = RoomState(
          phase: LiveRoomPhase.joined,
          roomId: 'room-a',
          currentUserId: 'user-1',
          pendingUserIds: {'user-1'},
          sessionSnapshotsByUser: {
            'user-1': RoomSessionSnapshot(
              userId: 'user-1',
              displayName: 'User One',
              role: 'audience',
            ),
          },
        );

        expect(
          state.membershipStateFor('user-1'),
          RoomMembershipState.stabilizing,
        );
        expect(state.hasAuthoritativeMembership('user-1'), isTrue);
        expect(state.shouldDeferMembershipRemoval('user-1'), isTrue);
      },
    );

    test('joinRoom keeps the joined user in shared room state', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'isLocked': false,
      });

      final container = ProviderContainer(
        overrides: [roomFirestoreProvider.overrideWithValue(firestore)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        roomControllerProvider('room-a').notifier,
      );
      final result = await controller.joinRoom(
        'user-1',
        displayName: 'User One',
      );
      final state = container.read(roomControllerProvider('room-a'));

      expect(result.isSuccess, isTrue);
      expect(state.roomId, 'room-a');
      expect(state.currentUserId, 'user-1');
      expect(state.isConnected, isTrue);
      expect(state.users, contains('user-1'));
    });

    test(
      'membership authority marks users absent when no authority signals remain',
      () {
        const state = RoomState(
          phase: LiveRoomPhase.joined,
          roomId: 'room-a',
          currentUserId: 'user-1',
        );

        expect(state.membershipStateFor('user-1'), RoomMembershipState.absent);
        expect(state.hasAuthoritativeMembership('user-1'), isFalse);
      },
    );

    test('leaveRoom resets the room session state', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'isLocked': false,
      });

      final container = ProviderContainer(
        overrides: [roomFirestoreProvider.overrideWithValue(firestore)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        roomControllerProvider('room-a').notifier,
      );
      await controller.joinRoom('user-1', displayName: 'User One');
      await controller.leaveRoom();
      final state = container.read(roomControllerProvider('room-a'));

      expect(state.isConnected, isFalse);
      expect(state.currentUserId, isNull);
      expect(state.users, isEmpty);
    });

    test(
      'requestMic queues listeners when someone else already holds the mic',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'host-1',
          'isLocked': false,
        });

        final micAccess = _SpyMicAccessController();
        final scopedContainer = ProviderContainer(
          overrides: [
            roomFirestoreProvider.overrideWithValue(firestore),
            roomDocStreamProvider.overrideWith(
              (ref, roomId) => Stream.value({'hostId': 'host-1'}),
            ),
            participantsStreamProvider.overrideWith(
              (ref, roomId) => Stream.value([
                RoomParticipantModel(
                  userId: 'host-1',
                  role: 'host',
                  micOn: true,
                  joinedAt: DateTime(2026, 1, 1),
                  lastActiveAt: DateTime.now(),
                ),
                RoomParticipantModel(
                  userId: 'user-1',
                  role: 'audience',
                  micOn: false,
                  joinedAt: DateTime(2026, 1, 1),
                  lastActiveAt: DateTime.now(),
                ),
              ]),
            ),
            micAccessControllerProvider.overrideWithValue(micAccess),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final controller = scopedContainer.read(
          roomControllerProvider('room-a').notifier,
        );
        await controller.joinRoom('user-1', displayName: 'User One');
        final result = await controller.requestMic(userId: 'user-1');

        expect(result, MicRequestResult.queued);
        expect(micAccess.queued, isTrue);
        expect(micAccess.grabbed, isFalse);
      },
    );

    test('cancelMicRequest lets a listener lower their hand', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'isLocked': false,
      });

      final micAccess = _SpyMicAccessController();
      final scopedContainer = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomDocStreamProvider.overrideWith(
            (ref, roomId) => Stream.value({'hostId': 'host-1'}),
          ),
          participantsStreamProvider.overrideWith(
            (ref, roomId) => Stream.value([
              RoomParticipantModel(
                userId: 'host-1',
                role: 'host',
                micOn: true,
                joinedAt: DateTime(2026, 1, 1),
                lastActiveAt: DateTime.now(),
              ),
              RoomParticipantModel(
                userId: 'user-1',
                role: 'audience',
                micOn: false,
                joinedAt: DateTime(2026, 1, 1),
                lastActiveAt: DateTime.now(),
              ),
            ]),
          ),
          roomMemberUserIdsProvider.overrideWith(
            (ref, roomId) => Stream.value(const <String>['host-1', 'user-1']),
          ),
          micAccessControllerProvider.overrideWithValue(micAccess),
        ],
      );
      addTearDown(scopedContainer.dispose);

      final controller = scopedContainer.read(
        roomControllerProvider('room-a').notifier,
      );
      await controller.joinRoom('user-1', displayName: 'User One');
      await controller.cancelMicRequest('user-1_host-1');

      expect(micAccess.cancelled, isTrue);
    });

    test(
      'MicAccessController prevents rapid requeue spam after denial',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'host-1',
        });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('mic_access_requests')
            .doc('user-1_host-1')
            .set({
              'id': 'user-1_host-1',
              'roomId': 'room-a',
              'requesterId': 'user-1',
              'hostId': 'host-1',
              'status': 'denied',
              'priority': 1,
              'expiresAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(minutes: 5)),
              ),
              'createdAt': Timestamp.fromDate(DateTime.now()),
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });

        final controller = MicAccessController(firestore);

        await expectLater(
          controller.requestAccess(
            roomId: 'room-a',
            requesterId: 'user-1',
            hostId: 'host-1',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('MicAccessController leaves the parent room doc untouched', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'ownerId': 'host-1',
        'micQueueSequence': 7,
      });

      final controller = MicAccessController(firestore);
      await controller.requestAccess(
        roomId: 'room-a',
        requesterId: 'user-2',
        hostId: 'host-1',
      );

      final roomSnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .get();
      final requestSnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('mic_access_requests')
          .doc('user-2_host-1')
          .get();

      expect(roomSnapshot.data()?['micQueueSequence'], 7);
      expect(requestSnapshot.exists, isTrue);
      expect(requestSnapshot.data()?['status'], 'pending');
    });

    test('host authority survives delayed participant hydration', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'isLocked': false,
      });

      final participantsController =
          StreamController<List<RoomParticipantModel>>.broadcast();
      addTearDown(participantsController.close);

      final container = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomDocStreamProvider.overrideWith(
            (ref, roomId) => Stream.value({'hostId': 'host-1'}),
          ),
          participantsStreamProvider.overrideWith(
            (ref, roomId) => participantsController.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        roomControllerProvider('room-a').notifier,
      );

      await controller.joinRoom('host-1', displayName: 'Host One');

      final hydratingState = container.read(roomControllerProvider('room-a'));
      expect(hydratingState.lifecycleState, RoomLifecycleState.hydrating);

      controller.hydrateCurrentUser(
        'host-1',
        displayName: 'Host One',
        role: 'host',
      );

      final activeState = container.read(roomControllerProvider('room-a'));
      expect(activeState.lifecycleState, RoomLifecycleState.active);

      await expectLater(controller.setMicTimer(60), completes);

      final policySnap = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('policies')
          .doc('settings')
          .get();
      expect(policySnap.data()?['micTimerSeconds'], 60);
    });

    test('joinRoom degrades cleanly when the session service throws', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
        'ownerId': 'host-1',
        'isLocked': false,
      });

      final flakySession = _FlakyRoomSessionService(
        firestore: firestore,
        presenceController: _TestPresenceController(),
        joinFailuresRemaining: 1,
      );

      final container = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomSessionServiceProvider.overrideWithValue(flakySession),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        roomControllerProvider('room-a').notifier,
      );

      final result = await controller.joinRoom(
        'user-1',
        displayName: 'User One',
      );
      final state = container.read(roomControllerProvider('room-a'));

      expect(result.isSuccess, isFalse);
      expect(result.errormessage, isNotEmpty);
      expect(state.isConnected, isFalse);
      expect(state.currentUserId, isNull);
      expect(state.lifecycleState, RoomLifecycleState.degraded);
    });

    test('room lifecycle recovers after a transient sync failure', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'user-1',
        'ownerId': 'user-1',
        'isLocked': false,
      });

      final flakySession = _FlakyRoomSessionService(
        firestore: firestore,
        presenceController: _TestPresenceController(),
      );

      final container = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomSessionServiceProvider.overrideWithValue(flakySession),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        roomControllerProvider('room-a').notifier,
      );

      final result = await controller.joinRoom(
        'user-1',
        displayName: 'User One',
      );
      expect(result.isSuccess, isTrue);

      controller.hydrateCurrentUser(
        'user-1',
        displayName: 'User One',
        role: 'host',
      );
      expect(
        container.read(roomControllerProvider('room-a')).lifecycleState,
        RoomLifecycleState.active,
      );

      flakySession.heartbeatFailuresRemaining = 1;
      await controller.syncPresenceNow(forceSync: true);

      final degradedState = container.read(roomControllerProvider('room-a'));
      expect(degradedState.errormessage, isNotNull);
      expect(degradedState.lifecycleState, RoomLifecycleState.degraded);

      await controller.syncPresenceNow(forceSync: true);

      final recoveredState = container.read(roomControllerProvider('room-a'));
      expect(recoveredState.errormessage, isNull);
      expect(recoveredState.lifecycleState, RoomLifecycleState.active);
    });

    test(
      'stale Firestore doc does not overwrite a fresher role already accepted',
      () async {
        final now = DateTime(2026, 4, 15, 12, 0, 0);
        final staleAt = now.subtract(const Duration(seconds: 10));

        // Build a container with two successive participant stream emissions:
        // first a fresh doc (host role at `now`), then a stale doc (audience at
        // `staleAt`).  The controller must keep 'host' after the stale arrives.
        final streamController =
            StreamController<List<RoomParticipantModel>>.broadcast();

        final firestore = FakeFirebaseFirestore();
        await firestore.collection('rooms').doc('room-stale').set({
          'hostId': 'host-1',
          'isLocked': false,
        });

        final container = ProviderContainer(
          overrides: [
            roomFirestoreProvider.overrideWithValue(firestore),
            roomDocStreamProvider.overrideWith(
              (ref, roomId) =>
                  Stream.value({'hostId': 'host-1', 'ownerId': 'host-1'}),
            ),
            participantsStreamProvider.overrideWith(
              (ref, roomId) => streamController.stream,
            ),
          ],
        );
        addTearDown(() {
          container.dispose();
          streamController.close();
        });

        final controller = container.read(
          roomControllerProvider('room-stale').notifier,
        );
        await controller.joinRoom('host-1', displayName: 'Host');

        // Emit the fresh (authoritative) doc first.
        streamController.add([
          RoomParticipantModel(
            userId: 'host-1',
            role: 'host',
            joinedAt: now.subtract(const Duration(minutes: 5)),
            lastActiveAt: now,
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        // Emit a stale doc (older lastActiveAt) that claims audience role.
        streamController.add([
          RoomParticipantModel(
            userId: 'host-1',
            role: 'audience',
            joinedAt: now.subtract(const Duration(minutes: 5)),
            lastActiveAt: staleAt,
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        final roleAfterStale = container
            .read(roomControllerProvider('room-stale'))
            .participantRolesByUser['host-1'];

        // Stale doc must NOT have downgraded the role to audience.
        expect(roleAfterStale, isNot('audience'));
      },
    );

    test('speaker-doc arrives before participant-doc: ghost speaker is pruned '
        'until participant doc lands', () async {
      final now = DateTime(2026, 4, 15, 12, 0, 0);
      final participantStream =
          StreamController<List<RoomParticipantModel>>.broadcast();
      final speakerStream = StreamController<List<String>>.broadcast();

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-ghost').set({
        'hostId': 'host-1',
        'isLocked': false,
      });
      final container = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomDocStreamProvider.overrideWith(
            (ref, roomId) => Stream.value({
              'hostId': 'host-1',
              'ownerId': 'host-1',
              'speakerSyncVersion': 1,
            }),
          ),
          participantsStreamProvider.overrideWith(
            (ref, roomId) => participantStream.stream,
          ),
          roomSpeakerUserIdsProvider.overrideWith(
            (ref, roomId) => speakerStream.stream,
          ),
        ],
      );
      final ghostSub = container.listen(
        roomControllerProvider('room-ghost'),
        (_, __) {},
      );
      addTearDown(() {
        ghostSub.close();
        container.dispose();
        participantStream.close();
        speakerStream.close();
      });

      final controller = container.read(
        roomControllerProvider('room-ghost').notifier,
      );
      await controller.joinRoom('host-1', displayName: 'Host');

      // Emit host participant so controller is hydrated.
      participantStream.add([
        RoomParticipantModel(
          userId: 'host-1',
          role: 'host',
          joinedAt: now,
          lastActiveAt: now,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      // Speaker doc arrives for 'ghost-speaker' who has no participant doc yet.
      speakerStream.add(['host-1', 'ghost-speaker']);
      await Future<void>.delayed(Duration.zero);

      final stateAfterGhost = container.read(
        roomControllerProvider('room-ghost'),
      );
      // ghost-speaker is NOT in userIds so must not appear in speakerIds.
      expect(stateAfterGhost.speakerIds, isNot(contains('ghost-speaker')));

      // Re-emit speaker IDs so the value is fresh when the participant doc
      // arrives (broadcast streams don't replay to late subscribers).
      speakerStream.add(['host-1', 'ghost-speaker']);
      await Future<void>.delayed(Duration.zero);

      // Participant doc for ghost-speaker arrives.
      participantStream.add([
        RoomParticipantModel(
          userId: 'host-1',
          role: 'host',
          joinedAt: now,
          lastActiveAt: now,
        ),
        RoomParticipantModel(
          userId: 'ghost-speaker',
          role: 'stage',
          joinedAt: now,
          lastActiveAt: now,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      final stateAfterParticipant = container.read(
        roomControllerProvider('room-ghost'),
      );
      // Now the speaker doc and participant doc are consistent.
      expect(stateAfterParticipant.speakerIds, contains('ghost-speaker'));
    });

    test('out-of-order join events: multiple users joining in rapid succession '
        'all appear in userIds', () async {
      final now = DateTime(2026, 4, 15, 12, 0, 0);
      final participantStream =
          StreamController<List<RoomParticipantModel>>.broadcast();
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-rapid').set({
        'hostId': 'host-1',
        'isLocked': false,
      });

      final container = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          roomDocStreamProvider.overrideWith(
            (ref, roomId) =>
                Stream.value({'hostId': 'host-1', 'ownerId': 'host-1'}),
          ),
          participantsStreamProvider.overrideWith(
            (ref, roomId) => participantStream.stream,
          ),
        ],
      );
      final rapidSub = container.listen(
        roomControllerProvider('room-rapid'),
        (_, __) {},
      );
      addTearDown(() {
        rapidSub.close();
        container.dispose();
        participantStream.close();
      });

      final controller = container.read(
        roomControllerProvider('room-rapid').notifier,
      );
      await controller.joinRoom('host-1', displayName: 'Host');

      // Two new users appear in back-to-back Firestore snapshots.
      participantStream.add([
        RoomParticipantModel(
          userId: 'host-1',
          role: 'host',
          joinedAt: now,
          lastActiveAt: now,
        ),
        RoomParticipantModel(
          userId: 'user-a',
          role: 'audience',
          joinedAt: now,
          lastActiveAt: now,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      participantStream.add([
        RoomParticipantModel(
          userId: 'host-1',
          role: 'host',
          joinedAt: now,
          lastActiveAt: now,
        ),
        RoomParticipantModel(
          userId: 'user-a',
          role: 'audience',
          joinedAt: now,
          lastActiveAt: now,
        ),
        RoomParticipantModel(
          userId: 'user-b',
          role: 'audience',
          joinedAt: now,
          lastActiveAt: now,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      // Both users must appear in the resolved user set — per-user
      // stabilization timers must not interfere with each other.
      final state = container.read(roomControllerProvider('room-rapid'));
      expect(state.userIds, containsAll(['user-a', 'user-b']));
    });

    test('host-role alignment: hostId pointing to audience-role participant is '
        'corrected by _selfHeal within the same build cycle', () async {
      final now = DateTime(2026, 4, 15, 12, 0, 0);
      final participantStream =
          StreamController<List<RoomParticipantModel>>.broadcast();

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('rooms').doc('room-host-race').set({
        'hostId': 'host-1',
        'isLocked': false,
      });
      final container = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          // hostId is 'host-1' but the participant doc says 'audience' —
          // simulates Firestore race between room doc and participant doc.
          roomDocStreamProvider.overrideWith(
            (ref, roomId) =>
                Stream.value({'hostId': 'host-1', 'ownerId': 'host-1'}),
          ),
          participantsStreamProvider.overrideWith(
            (ref, roomId) => participantStream.stream,
          ),
        ],
      );
      final raceSub = container.listen(
        roomControllerProvider('room-host-race'),
        (_, __) {},
      );
      addTearDown(() {
        raceSub.close();
        container.dispose();
        participantStream.close();
      });

      final controller = container.read(
        roomControllerProvider('room-host-race').notifier,
      );
      await controller.joinRoom('host-1', displayName: 'Host');

      // Participant doc arrives with stale 'audience' role for host-1.
      participantStream.add([
        RoomParticipantModel(
          userId: 'host-1',
          role: 'audience', // wrong — will be corrected by _selfHeal
          joinedAt: now,
          lastActiveAt: now,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      final healed = container.read(roomControllerProvider('room-host-race'));
      // _selfHeal must have corrected the role to 'host'.
      expect(healed.participantRolesByUser['host-1'], equals('host'));
    });
  });
}
