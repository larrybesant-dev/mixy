import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/controllers/live_room_media_controller.dart';

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('media controller tracks connect to ready transition', () {
    final container = createContainer();
    final notifier = container.read(
      liveRoomMediaControllerProvider('room-a').notifier,
    );

    notifier.beginConnecting();
    expect(
      container.read(liveRoomMediaControllerProvider('room-a')).phase,
      LiveRoomMediaPhase.connecting,
    );
    expect(
      container
          .read(liveRoomMediaControllerProvider('room-a'))
          .isCallConnecting,
      isTrue,
    );

    notifier.markReady(
      rtcUid: 77,
      cameraStatus: 'Live media ready. Tap camera to publish.',
    );

    final state = container.read(liveRoomMediaControllerProvider('room-a'));
    expect(state.phase, LiveRoomMediaPhase.ready);
    expect(state.isCallReady, isTrue);
    expect(state.currentRtcUid, 77);
    expect(state.isMicMuted, isTrue);
    expect(state.isVideoEnabled, isFalse);
    expect(state.localViewEpoch, 1);
  });

  test('media controller restores broadcaster state after reconnect', () {
    final container = createContainer();
    final notifier = container.read(
      liveRoomMediaControllerProvider('room-a').notifier,
    );

    notifier.markReconnecting('Reconnecting…');
    notifier.restoreBroadcastAfterReconnect(
      slotId: 'slot-3',
      wasMicMuted: false,
      role: 'stage',
    );

    final state = container.read(liveRoomMediaControllerProvider('room-a'));
    expect(state.phase, LiveRoomMediaPhase.ready);
    expect(state.claimedSlotId, 'slot-3');
    expect(state.appliedMediaRole, 'stage');
    expect(state.isVideoEnabled, isTrue);
    expect(state.isMicMuted, isFalse);
    expect(state.cameraStatus, 'Camera restored after reconnect.');
  });

  test('media controller clears slot and flags when disconnecting', () {
    final container = createContainer();
    final notifier = container.read(
      liveRoomMediaControllerProvider('room-a').notifier,
    );

    notifier.beginConnecting();
    notifier.markReady(
      rtcUid: 99,
      cameraStatus: 'Live media ready. Tap camera to publish.',
    );
    notifier.beginVideoAction('Starting camera...');
    notifier.setClaimedSlotId('slot-7');
    notifier.finishVideoAction(
      isVideoEnabled: true,
      claimedSlotId: 'slot-7',
      cameraStatus: 'Camera active.',
      appliedMediaRole: 'member',
    );
    notifier.beginMicAction();
    notifier.finishMicAction(isMuted: true);

    notifier.resetDisconnected();

    final state = container.read(liveRoomMediaControllerProvider('room-a'));
    expect(state.phase, LiveRoomMediaPhase.idle);
    expect(state.currentRtcUid, isNull);
    expect(state.claimedSlotId, isNull);
    expect(state.appliedMediaRole, isNull);
    expect(state.isVideoEnabled, isFalse);
    expect(state.isMicMuted, isFalse);
    expect(state.isMicActionInFlight, isFalse);
    expect(state.isVideoActionInFlight, isFalse);
  });
}
