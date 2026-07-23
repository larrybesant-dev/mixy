import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/providers/message_providers.dart'
    as room_message;

final roomMessageMapStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
      return Stream.multi((controller) {
        final subscription = ref.listen(
          room_message.roomMessageStreamProvider(roomId),
          (_, next) {
            if (controller.isClosed) return;
            next.whenData((messages) {
              controller.add(
                messages
                    .map(
                      (m) => <String, dynamic>{
                        'id': m.id,
                        'conversationId': m.conversationId,
                        'senderId': m.senderId,
                        'senderName': m.senderName,
                        'content': m.content,
                        'type': m.type,
                        'createdAt': m.createdAt,
                      },
                    )
                    .toList(growable: false),
              );
            });
          },
        );
        controller.onCancel = subscription.close;
      });
    });




