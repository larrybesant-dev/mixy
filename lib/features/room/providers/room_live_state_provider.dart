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
      // ignore: deprecated_member_use
      final metaStream = ref.watch(roomMetaStateProvider(roomId).stream);
      // ignore: deprecated_member_use
      final participantsStream = ref.watch(
        roomParticipantsStateProvider(roomId).stream,
      );
      // ignore: deprecated_member_use
      final activityStream = ref.watch(
        roomActivityStateProvider(roomId).stream,
      );
      // ignore: deprecated_member_use
      final messagePreviewStream = ref.watch(
        roommessagePreviewStateProvider(roomId).stream,
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
