import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:mixvy/core/contracts/room_contract.dart';
import 'room_meta_state_provider.dart';
import 'room_participants_state_provider.dart';
import 'room_activity_state_provider.dart';
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
      final metaStream = ref.watch(roomMetaStateProvider(roomId).stream).map(
            (state) => state ?? RoomMetaState(roomDoc: null),
          );
      final participantsStream = ref.watch(
        roomParticipantsStateProvider(roomId).stream,
      ).map(
            (state) => state ?? RoomParticipantsState(participants: []),
          );
      final activityStream = ref.watch(
        roomActivityStateProvider(roomId).stream,
      ).map(
            (state) => state ?? RoomActivityState(presence: {}, typing: {}),
          );
      final messagePreviewStream = ref.watch(
        roommessagePreviewStateProvider(roomId).stream,
      ).map(
            (state) => state ?? RoommessagePreviewState(messagePreview: []),
          );

      return Rx.combineLatest4(
        metaStream,
        participantsStream,
        activityStream,
        messagePreviewStream,
        (
          RoomMetaState meta,
          RoomParticipantsState participants,
          RoomActivityState activity,
          RoommessagePreviewState messagePreview,
        ) {
          return RoomLiveStateMapper.fromFirestore(
            roomDoc: meta.roomDoc,
            participants: participants.participants,
            presence: activity.presence,
            messagePreview: messagePreview.messagePreview,
            typing: activity.typing,
          );
        },
      ).debounceTime(const Duration(milliseconds: 50));
    });
