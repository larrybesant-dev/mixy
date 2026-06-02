import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/contracts/room_contract.dart';
import 'room_meta_state_provider.dart';
import 'room_participants_state_provider.dart';
import 'participant_providers.dart';
import 'room_activity_state_provider.dart';
import 'presence_provider.dart';
import 'room_message_preview_state_provider.dart';

export 'package:mixvy/core/contracts/room_contract.dart'
    show
        RoomStateContract,
        RoomLiveState,
        RoomContractGuard,
        RoomStateDiff,
        RoomSchemaException,
        kRoomSchemaVersion;

export 'participant_providers.dart' show roomSpeakerUserIdsProvider;

final roomLiveStateProvider =
    StreamProvider.autoDispose.family<RoomLiveState, String>((ref, roomId) {
  return Stream.multi((controller) {
    RoomMetaState? metaState;
    var participantsState = RoomParticipantsState(participants: []);
    var speakerIds = const <String>[];
    var activityState = RoomActivityState(
      presence: const <RoomPresenceModel>[],
      typing: const <String, bool>{},
    );
    var messagePreviewState = RoommessagePreviewState(messagePreview: []);

    void publish() {
      if (controller.isClosed) return;

      // Capture a stable local reference to avoid race conditions
      // or force-unwraps on mutable fields.
      final currentMeta = metaState;
      if (currentMeta == null) return;

      try {
        // RoomLiveStateMapper handles null roomDoc by throwing RoomSchemaException
        // which is caught and propagated as a clean stream error.
        controller.add(
          RoomLiveStateMapper.fromFirestore(
            roomDoc: currentMeta.roomDoc,
            participants: participantsState.participants,
            speakerIds: speakerIds,
            presence: activityState.presence,
            messagePreview: messagePreviewState.messagePreview,
            typing: activityState.typing,
            roomId: roomId,
          ),
        );
      } catch (e, st) {
        // Propagate validation errors (like "Room not found") to the UI.
        controller.addError(e, st);
      }
    }

    final metaSubscription = ref.listen<AsyncValue<RoomMetaState>>(
      roomMetaStateProvider(roomId),
      (_, next) {
        if (next.hasValue) {
          metaState = next.value!;
          publish();
        } else if (next.hasError) {
          controller.addError(next.error!, next.stackTrace!);
        }
      },
      fireImmediately: true,
    );

    final participantsSubscription =
        ref.listen<AsyncValue<RoomParticipantsState>>(
      roomParticipantsStateProvider(roomId),
      (_, next) {
        if (next.hasValue) {
          participantsState = next.value!;
          publish();
        }
      },
      fireImmediately: true,
    );

    final speakersSubscription = ref.listen<AsyncValue<List<String>>>(
      roomSpeakerUserIdsProvider(roomId),
      (_, next) {
        if (next.hasValue) {
          speakerIds = next.value!;
          publish();
        }
      },
      fireImmediately: true,
    );

    final activitySubscription = ref.listen<AsyncValue<RoomActivityState>>(
      roomActivityStateProvider(roomId),
      (_, next) {
        if (next.hasValue) {
          activityState = next.value!;
          publish();
        }
      },
      fireImmediately: true,
    );

    final messagePreviewSubscription =
        ref.listen<AsyncValue<RoommessagePreviewState>>(
      roommessagePreviewStateProvider(roomId),
      (_, next) {
        if (next.hasValue) {
          messagePreviewState = next.value!;
          publish();
        }
      },
      fireImmediately: true,
    );

    controller.onCancel = () {
      metaSubscription.close();
      participantsSubscription.close();
      speakersSubscription.close();
      activitySubscription.close();
      messagePreviewSubscription.close();
    };
  });
});
