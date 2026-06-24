// lib/features/chat/repositories/i_chat_repository.dart
//
// Abstract contract for chat/messaging operations.
import 'package:mixvy/shared/models/chat_message.dart';
import 'package:mixvy/shared/models/chat_room.dart';

abstract class IChatRepository {
  /// Watch messages in a room/chat channel, ordered by time.
  Stream<List<ChatMessage>> watchMessages(String channelId, {int limit = 50});

  /// Send a message to a channel.
  /// [senderUid] is validated inside the implementation.
  Future<void> sendMessage({
    required String channelId,
    required String senderUid,
    required String text,
  });

  /// Delete a message (owner or moderator).
  Future<void> deleteMessage({
    required String channelId,
    required String messageId,
    required String requestingUid,
  });

  /// Fetch or create a direct message channel between two users.
  Future<ChatRoom> getOrCreateDmChannel({
    required String uidA,
    required String uidB,
  });

  /// List DM channels for a user.
  Stream<List<ChatRoom>> watchDmChannels(String uid);

  /// Mark all unread messages in a channel as read for [uid].
  Future<void> markRead({required String channelId, required String uid});
}

