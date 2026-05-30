import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'participant_providers.dart';
import 'package:mixvy/models/room_participant_model.dart';

class RoomParticipantsState {
  final List<RoomParticipantModel> participants;
  RoomParticipantsState({required this.participants});
}

final roomParticipantsStateProvider = StreamProvider.autoDispose
    .family<RoomParticipantsState, String>((ref, roomId) {
      return Stream.multi((controller) {
        final subscription = ref.listen<AsyncValue<List<RoomParticipantModel>>>(
          participantsStreamProvider(roomId),
          (_, next) {
            if (controller.isClosed) return;
            controller.add(
              RoomParticipantsState(
                participants:
                    next.valueOrNull ?? const <RoomParticipantModel>[],
              ),
            );
          },
          fireImmediately: true,
        );

        controller.onCancel = subscription.close;
      });
    });




