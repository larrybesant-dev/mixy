import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/contracts/room_contract.dart';
import 'room_meta_state_provider.dart';
import 'room_participants_state_provider.dart';
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

final roomLiveStateProvider = StreamProvider.autoDispose
    .family<RoomLiveState, String>((ref, roomId) {
      return Stream.multi((controller) {
        var metaState = RoomMetaState(roomDoc: null);
        var participantsState = RoomParticipantsState(participants: []);
        var activityState = RoomActivityState(
          presence: const <RoomPresenceModel>[],
          typing: const <String, bool>{},
        );
        var messagePreviewState = RoommessagePreviewState(messagePreview: []);

        void publish() {
          if (controller.isClosed) return;
          controller.add(
            RoomLiveStateMapper.fromFirestore(
              roomDoc: metaState.roomDoc,
              participants: participantsState.participants,
              presence: activityState.presence,
              messagePreview: messagePreviewState.messagePreview,
              typing: activityState.typing,
            ),
          );
        }

        final metaSubscription = ref.listen<AsyncValue<RoomMetaState>>(
          roomMetaStateProvider(roomId),
          (_, next) {
            metaState = next.valueOrNull ?? RoomMetaState(roomDoc: null);
            publish();
          },
          fireImmediately: true,
        );

        final participantsSubscription = ref
            .listen<AsyncValue<RoomParticipantsState>>(
              roomParticipantsStateProvider(roomId),
              (_, next) {
                participantsState =
                    next.valueOrNull ?? RoomParticipantsState(participants: []);
                publish();
              },
              fireImmediately: true,
            );

        final activitySubscription = ref.listen<AsyncValue<RoomActivityState>>(
          roomActivityStateProvider(roomId),
          (_, next) {
            activityState =
                next.valueOrNull ??
                RoomActivityState(
                  presence: const <RoomPresenceModel>[],
                  typing: const <String, bool>{},
                );
            publish();
          },
          fireImmediately: true,
        );

        final messagePreviewSubscription = ref
            .listen<AsyncValue<RoommessagePreviewState>>(
              roommessagePreviewStateProvider(roomId),
              (_, next) {
                messagePreviewState =
                    next.valueOrNull ??
                    RoommessagePreviewState(messagePreview: []);
                publish();
              },
              fireImmediately: true,
            );

        controller.onCancel = () {
          metaSubscription.close();
          participantsSubscription.close();
          activitySubscription.close();
          messagePreviewSubscription.close();
        };
      });
    });
