import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/providers/message_providers.dart'
    as room_message;

final messagetreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
      return ref
          .watch(room_message.messagetreamProvider(roomId).stream)
          .map((messages) {
            return messages
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
                .toList(growable: false);
          });
    });
