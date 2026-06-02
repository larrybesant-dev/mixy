import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'participant_providers.dart';

class RoomMetaState {
  final Map<String, dynamic>? roomDoc;
  RoomMetaState({required this.roomDoc});
}

final roomMetaStateProvider =
    StreamProvider.autoDispose.family<RoomMetaState, String>((ref, roomId) {
  return Stream.multi((controller) {
    final subscription = ref.listen<AsyncValue<Map<String, dynamic>?>>(
      roomDocStreamProvider(roomId),
      (_, next) {
        if (controller.isClosed) return;

        // Only emit when we have a terminal state (data or error).
        // Initial loading should remain in AsyncLoading.
        if (next.hasValue) {
          if (next.value == null) {
            debugPrint(
                '[RoomMetaState] Warning: Room document for $roomId is null (not found).');
          }
          controller.add(RoomMetaState(roomDoc: next.value));
        } else if (next.hasError) {
          controller.addError(next.error!, next.stackTrace!);
        }
      },
      fireImmediately: true,
    );

    controller.onCancel = subscription.close;
  });
});
