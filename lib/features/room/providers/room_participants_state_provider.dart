import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'participant_providers.dart';
import 'package:mixvy/models/room_participant_model.dart';
import '../contracts/room_participants_contract.dart';

class RoomParticipantsState {
  final List<RoomParticipantModel> participants;
  RoomParticipantsState({required this.participants});
}

final roomParticipantsStateProvider = StreamProvider.autoDispose
    .family<RoomParticipantsState, String>((ref, roomId) async* {
      List<RoomParticipantModel>? previous;
      // ignore: deprecated_member_use
      await for (final participants in ref.watch(
        participantsStreamProvider(roomId).stream,
      )) {
        if (previous != null &&
            !RoomParticipantsContract.shouldRebuild(previous, participants)) {
          continue;
        }
        previous = participants;
        yield RoomParticipantsState(participants: participants);
      }
    });
