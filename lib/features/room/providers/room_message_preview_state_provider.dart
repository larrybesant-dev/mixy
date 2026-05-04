import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message_providers.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import '../contracts/room_message_preview_contract.dart';

class RoommessagePreviewState {
  final List<MessageModel> messagePreview;
  RoommessagePreviewState({required this.messagePreview});
}

final roommessagePreviewStateProvider = StreamProvider.autoDispose
    .family<RoommessagePreviewState, String>((ref, roomId) async* {
      List<MessageModel>? previous;
      // ignore: deprecated_member_use
      await for (final message in ref.watch(
        roomMessageStreamProvider(roomId).stream,
      )) {
        if (previous != null &&
            !RoommessagePreviewContract.shouldRebuild(previous, message)) {
          continue;
        }
        previous = message;
        yield RoommessagePreviewState(messagePreview: message);
      }
    });
