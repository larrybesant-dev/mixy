import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'participant_providers.dart';

class RoomMetaState {
  final Map<String, dynamic>? roomDoc;
  RoomMetaState({required this.roomDoc});
}

final roomMetaStateProvider = StreamProvider.autoDispose
    .family<RoomMetaState, String>((ref, roomId) {
      return Stream.multi((controller) {
        final subscription = ref.listen<AsyncValue<Map<String, dynamic>?>>(
          roomDocStreamProvider(roomId),
          (_, next) {
            if (controller.isClosed) return;
            controller.add(RoomMetaState(roomDoc: next.valueOrNull));
          },
          fireImmediately: true,
        );

        controller.onCancel = subscription.close;
      });
    });
