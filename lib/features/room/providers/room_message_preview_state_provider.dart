import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message_providers.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import '../contracts/room_message_preview_contract.dart';

class RoommessagePreviewState {
  final List<MessageModel> messagePreview;
  RoommessagePreviewState({required this.messagePreview});
}

final roommessagePreviewStateProvider = StreamProvider.autoDispose
    .family<RoommessagePreviewState, String>((ref, roomId) {
      return Stream.multi((controller) {
        List<MessageModel>? previous;
        final subscription = ref.listen<AsyncValue<List<MessageModel>>>(
          roomMessageStreamProvider(roomId),
          (_, next) {
            if (controller.isClosed) return;
            final List<MessageModel> messages =
                next.value ?? const <MessageModel>[];
            if (previous != null) {
              if (!RoommessagePreviewContract.shouldRebuild(
                previous!,
                messages,
              )) {
                return;
              }
            }
            previous = messages;
            controller.add(RoommessagePreviewState(messagePreview: messages));
          },
          fireImmediately: true,
        );

        controller.onCancel = subscription.close;
      });
    });




