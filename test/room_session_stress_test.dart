import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/models/presence_model.dart';
import 'package:mixvy/features/room/providers/room_slot_provider.dart';
import 'package:mixvy/features/room/services/room_session_service.dart';
import 'package:mixvy/services/presence_controller.dart';

class _FakePresenceController extends PresenceController {
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

void main() {
  test('joinRoom writes a fresh shared participant record', () async {
    final firestore = FakeFirebaseFirestore();
    final presenceController = _FakePresenceController();
    final roomSessionService = RoomSessionService(
      firestore: firestore,
      presenceController: presenceController,
    );

    const roomId = 'room-a';
    const userId = 'user-1';
    await firestore.collection('rooms').doc(roomId).set({
      'hostId': 'host-1',
      'ownerId': 'host-1',
      'isLocked': false,
    });

    final result = await roomSessionService.joinRoom(
      roomId: roomId,
      userId: userId,
    );

    expect(result.isSuccess, isTrue);

    final participantDoc = await firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userId)
        .get();

    expect(participantDoc.exists, isTrue);
    expect(participantDoc.data()?['lastActiveAt'], isNotNull);
    expect(participantDoc.data()?['joinedAt'], isNotNull);
  });

  test(
    'stress simulates room churn without duplicates or presence drift',
    () async {
      AppTelemetry.reset();

      final firestore = FakeFirebaseFirestore();
      final presenceController = _FakePresenceController();
      final roomSessionService = RoomSessionService(
        firestore: firestore,
        presenceController: presenceController,
      );
      final slotService = RoomSlotService(firestore);

      const roomId = 'stress-room';
      await firestore.collection('rooms').doc(roomId).set({
        'hostId': 'user-0',
        'ownerId': 'user-0',
        'isLocked': false,
        'maxBroadcasters': 6,
      });

      final users = List<String>.generate(20, (index) => 'user-$index');
      final random = Random(42);
      final activeUsers = <String>{};
      final broadcastingUsers = <String>{};

      Future<void> joinUser(String userId) async {
        final result = await roomSessionService.joinRoom(
          roomId: roomId,
          userId: userId,
        );
        expect(result.isSuccess, isTrue);
        activeUsers.add(userId);
      }

      Future<void> leaveUser(String userId) async {
        await slotService.releaseSlot(roomId, userId);
        await roomSessionService.leaveRoom(roomId: roomId, userId: userId);
        activeUsers.remove(userId);
        broadcastingUsers.remove(userId);
      }

      await joinUser('user-0');

      for (var step = 0; step < 140; step++) {
        final userId = users[random.nextInt(users.length)];
        final operation = random.nextInt(5);

        switch (operation) {
          case 0:
            if (!activeUsers.contains(userId)) {
              await joinUser(userId);
            }
            break;
          case 1:
            if (activeUsers.contains(userId)) {
              await roomSessionService.heartbeat(
                roomId: roomId,
                userId: userId,
              );
            }
            break;
          case 2:
            if (activeUsers.contains(userId) &&
                !broadcastingUsers.contains(userId)) {
              final slotId = await slotService.claimSlot(
                roomId,
                userId,
                maxBroadcasters: 6,
              );
              if (slotId != null) {
                broadcastingUsers.add(userId);
              }
            } else if (broadcastingUsers.contains(userId)) {
              await slotService.releaseSlot(roomId, userId);
              broadcastingUsers.remove(userId);
            }
            break;
          case 3:
            if (activeUsers.contains(userId) && userId != 'user-0') {
              await leaveUser(userId);
            }
            break;
          case 4:
            if (activeUsers.contains(userId)) {
              await roomSessionService.setCustomStatus(
                roomId: roomId,
                userId: userId,
                status: 'step-$step',
              );
            }
            break;
        }

        final participantSnapshot = await firestore
            .collection('rooms')
            .doc(roomId)
            .collection('participants')
            .get();
        final participantIds = participantSnapshot.docs
            .map((doc) => (doc.data()['userId'] as String?) ?? doc.id)
            .toList(growable: false);
        expect(participantIds.toSet().length, participantIds.length);
        expect(participantIds.toSet(), activeUsers);

        final slotSnapshot = await firestore
            .collection('rooms')
            .doc(roomId)
            .collection('slots')
            .get();
        final slotUserIds = slotSnapshot.docs
            .map((doc) => doc.data()['userId'] as String?)
            .whereType<String>()
            .toList(growable: false);
        expect(slotUserIds.toSet().length, slotUserIds.length);
        expect(slotUserIds.length, lessThanOrEqualTo(6));

        for (final activeUser in activeUsers) {
          expect(presenceController.writesByUser[activeUser]?.inRoom, roomId);
        }
      }

      expect(AppTelemetry.state.firestoreWriteCount, greaterThan(0));
      expect(AppTelemetry.state.recentEvents, isNotEmpty);
    },
  );
}
