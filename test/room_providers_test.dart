import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/host_controls_provider.dart';
import 'package:mixvy/features/room/providers/message_providers.dart';
import 'package:mixvy/features/room/providers/participant_providers.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';
import 'package:mixvy/features/room/providers/cam_access_provider.dart';
import 'package:mixvy/models/room_participant_model.dart';
import 'package:mixvy/models/room_policy_model.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

import 'package:mixvy/services/moderation_service.dart';

void main() {
  group('Room providers', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      ModerationService.clearCache();
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1',
              email: 'user1@mixvy.com',
              username: 'User One',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('participantCountProvider returns number of participants', () async {
      final now = Timestamp.fromDate(DateTime.now());
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'user-1',
        'isLocked': false,
      });

      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('user-1')
          .set({
            'userId': 'user-1',
            'role': 'host',
            'joinedAt': now,
            'lastActiveAt': now,
          });
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('user-2')
          .set({
            'userId': 'user-2',
            'role': 'audience',
            'joinedAt': now,
            'lastActiveAt': now,
          });

      // participantCountProvider is a sync Provider derived from the stream;
      // await the stream first so the count is populated, then read sync.
      await container.read(roomDocStreamProvider('room-a').future);
      await container.read(participantsStreamProvider('room-a').future);
      final count = container.read(participantCountProvider('room-a'));

      expect(count, 2);
    });

    test(
      'participantsStreamProvider filters stale participants from the roster',
      () async {
        final now = DateTime.now();
        final fresh = Timestamp.fromDate(now);
        final stale = Timestamp.fromDate(
          now.subtract(const Duration(minutes: 5)),
        );

        await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'user-1',
        'isLocked': false,
      });

      await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .doc('user-1')
            .set({
              'userId': 'user-1',
              'role': 'host',
              'joinedAt': fresh,
              'lastActiveAt': fresh,
            });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .doc('ghost-user')
            .set({
              'userId': 'ghost-user',
              'role': 'audience',
              'joinedAt': stale,
              'lastActiveAt': stale,
            });

        await container.read(roomDocStreamProvider('room-a').future);
        final participants = await container.read(
          participantsStreamProvider('room-a').future,
        );
        final count = container.read(participantCountProvider('room-a'));

        expect(participants.map((p) => p.userId), ['user-1']);
        expect(count, 1);
      },
    );

    test('currentParticipantProvider loads a participant model', () async {
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('user-1')
          .set({
            'userId': 'user-1',
            'role': 'cohost',
            'isMuted': true,
            'isBanned': false,
            'joinedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
            'lastActiveAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      final participant = await container.read(
        currentParticipantProvider(
          const CurrentParticipantParams(roomId: 'room-a', userId: 'user-1'),
        ).future,
      );

      expect(participant, isNotNull);
      expect(participant!.role, 'cohost');
      expect(participant.isMuted, true);
    });

    test('sendMessageProvider writes a message document', () async {
      final sendmessage = container.read(sendMessageProvider('room-a'));

      await sendmessage('  hello room  ');

      final snapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('messages')
          .get();
      expect(snapshot.docs, hasLength(1));
      expect(snapshot.docs.single.data()['content'], 'hello room');
      expect(snapshot.docs.single.data()['senderId'], 'user-1');
      expect(snapshot.docs.single.data()['clientSentAt'], isNotNull);
    });

    test('sendMessageProvider rejects message when host is blocked', () async {
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'host-1',
      });
      await firestore.collection('blocks').doc('user-1_host-1').set({
        'blockerUserId': 'user-1',
        'blockedUserId': 'host-1',
      });

      final sendmessage = container.read(sendMessageProvider('room-a'));

      await expectLater(
        () => sendmessage('blocked message'),
        throwsA(isA<StateError>()),
      );

      final snapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('messages')
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test(
      'sendMessageProvider rejects when blocked participant is present',
      () async {
        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'host-1',
        });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .doc('user-2')
            .set({
              'userId': 'user-2',
              'role': 'audience',
              'joinedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
              'lastActiveAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
            });
        await firestore.collection('blocks').doc('user-1_user-2').set({
          'blockerUserId': 'user-1',
          'blockedUserId': 'user-2',
        });

        final sendmessage = container.read(sendMessageProvider('room-a'));

        await expectLater(
          () => sendmessage('blocked in room'),
          throwsA(isA<StateError>()),
        );

        final snapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('messages')
            .get();
        expect(snapshot.docs, isEmpty);
      },
    );

    test(
      'sendMessageProvider rejects when room policy disables chat',
      () async {
        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'host-1',
        });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('policies')
            .doc('settings')
            .set({'allowChat': false});

        final sendmessage = container.read(sendMessageProvider('room-a'));

        await expectLater(
          () => sendmessage('chat disabled'),
          throwsA(isA<StateError>()),
        );

        final snapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('messages')
            .get();
        expect(snapshot.docs, isEmpty);
      },
    );

    test('hostControlsProvider toggles room lock state', () async {
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'user-1',
        'isLocked': false,
      });

      final controls = container.read(hostControlsProvider);
      await controls.toggleLockRoom('room-a');

      final roomSnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .get();
      expect(roomSnapshot.data()?['isLocked'], true);
    });

    test('hostControlsProvider toggles allowChat policy', () async {
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'user-1',
      });
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('policies')
          .doc('settings')
          .set({'allowChat': true});

      final controls = container.read(hostControlsProvider);
      await controls.toggleAllowChat('room-a');

      final policySnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('policies')
          .doc('settings')
          .get();
      expect(policySnapshot.data()?['allowChat'], false);
    });

    test('hostControlsProvider toggles allowCamRequests policy', () async {
      await firestore.collection('rooms').doc('room-a').set({
        'hostId': 'user-1',
      });
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('policies')
          .doc('settings')
          .set({'allowCamRequests': true});

      final controls = container.read(hostControlsProvider);
      await controls.toggleAllowCamRequests('room-a');

      final policySnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('policies')
          .doc('settings')
          .get();
      expect(policySnapshot.data()?['allowCamRequests'], false);
    });

    test('hostControlsProvider can promote and demote a participant', () async {
      await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('user-2')
          .set({
            'userId': 'user-2',
            'role': 'audience',
            'joinedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
            'lastActiveAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

      final controls = container.read(hostControlsProvider);
      await controls.promoteToCohost('room-a', 'user-2');
      var participantSnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('user-2')
          .get();
      expect(participantSnapshot.data()?['role'], 'cohost');

      await controls.demoteToAudience('room-a', 'user-2');
      participantSnapshot = await firestore
          .collection('rooms')
          .doc('room-a')
          .collection('participants')
          .doc('user-2')
          .get();
      expect(participantSnapshot.data()?['role'], 'audience');
    });

    test(
      'camAccessController approves request and promotes requester',
      () async {
        await firestore.collection('rooms').doc('room-a').set({
          'hostId': 'user-1',
        });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .doc('user-2')
            .set({
              'userId': 'user-2',
              'role': 'audience',
              'joinedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
              'lastActiveAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
            });
        await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('cam_access_requests')
            .doc('request-1')
            .set({
              'id': 'request-1',
              'roomId': 'room-a',
              'requesterId': 'user-2',
              'broadcasterId': 'user-1',
              'status': 'pending',
              'decisionScope': 'single_session',
              'createdAt': DateTime(2026, 1, 1).toIso8601String(),
              'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
            });

        final controller = container.read(camAccessControllerProvider);
        await controller.approveRequest(
          'room-a',
          const CamAccessRequestModel(
            id: 'request-1',
            roomId: 'room-a',
            requesterId: 'user-2',
            broadcasterId: 'user-1',
          ),
        );

        final requestSnapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('cam_access_requests')
            .doc('request-1')
            .get();
        final participantSnapshot = await firestore
            .collection('rooms')
            .doc('room-a')
            .collection('participants')
            .doc('user-2')
            .get();
        expect(requestSnapshot.data()?['status'], 'approved');
        expect(participantSnapshot.data()?['role'], 'cohost');
      },
    );
  });

  group('isHostProvider', () {
    final now = DateTime.now();

    RoomParticipantModel makeParticipant(String role) => RoomParticipantModel(
      userId: 'u',
      role: role,
      joinedAt: now,
      lastActiveAt: now,
    );

    test('returns true for role "host"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(isHostProvider(makeParticipant('host'))), isTrue);
    });

    test('returns true for legacy role "owner"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(isHostProvider(makeParticipant('owner'))), isTrue);
    });

    test('returns false for role "cohost"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(isHostProvider(makeParticipant('cohost'))),
        isFalse,
      );
    });

    test('returns false for role "audience"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(isHostProvider(makeParticipant('audience'))),
        isFalse,
      );
    });

    test('returns false for null participant', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(isHostProvider(null)), isFalse);
    });
  });

  group('isCohostProvider', () {
    final now = DateTime.now();

    RoomParticipantModel makeParticipant(String role) => RoomParticipantModel(
      userId: 'u',
      role: role,
      joinedAt: now,
      lastActiveAt: now,
    );

    test('returns true for role "cohost"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(isCohostProvider(makeParticipant('cohost'))),
        isTrue,
      );
    });

    test('returns false for role "host"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(isCohostProvider(makeParticipant('host'))),
        isFalse,
      );
    });

    test('returns false for null participant', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(isCohostProvider(null)), isFalse);
    });
  });
}
