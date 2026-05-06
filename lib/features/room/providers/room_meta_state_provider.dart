import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'participant_providers.dart';
import '../contracts/room_meta_contract.dart';

class RoomMetaState {
  final Map<String, dynamic>? roomDoc;
  RoomMetaState({required this.roomDoc});
}

final roomMetaStateProvider = StreamProvider.autoDispose
    .family<RoomMetaState, String>((ref, roomId) async* {
      Map<String, dynamic>? previous;
      await for (final doc in ref.watch(roomDocStreamProvider(roomId).stream)) {
        if (previous != null &&
            !RoomMetaContract.shouldRebuild(previous, doc)) {
          continue;
        }
        previous = doc;
        yield RoomMetaState(roomDoc: doc);
      }
    });
