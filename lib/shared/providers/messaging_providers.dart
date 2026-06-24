import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat/chat_service.dart';
import '../../services/chat/messaging_service.dart';
import '../models/message.dart';
import '../models/chat_message.dart';
import '../models/direct_message.dart';
import 'auth_providers.dart';

/// Service providers
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final messagingServiceProvider =
    Provider<MessagingService>((ref) => MessagingService());

/// Room messages stream provider with pagination
final roomMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('messages')
      .where('roomId', isEqualTo: roomId)
      .orderBy('timestamp', descending: true)
      .limit(50) // Pagination: load last 50 messages
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Message.fromMap(data);
          })
          .toList()
          .reversed // Reverse to show oldest first
          .toList())
      .transform(StreamTransformer.fromHandlers(
        handleError: (error, stackTrace, sink) {
          debugPrint('[CHAT] messages stream error (emitting empty): $error');
          sink.add(<Message>[]);
        },
      ));
});

/// Paginated room messages with cursor
/// Note: Use roomMessagesControllerProvider instead for better control
final paginatedRoomMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, roomId) {
  final messagingService = ref.watch(messagingServiceProvider);
  return messagingService
      .getRoomMessages(roomId)
      .handleError((_) => <Message>[]);
});

/// Room messages with pagination controller
final roomMessagesControllerProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, roomId) {
  final messagingService = ref.watch(messagingServiceProvider);
  return messagingService.getRoomMessages(roomId).handleError((error) {
    return <Message>[];
  });
});

// Controller class for actions
class RoomMessagesController {
  final Ref ref;
  final String roomId;

  RoomMessagesController(this.ref, this.roomId);

  late final MessagingService _messagingService =
      ref.read(messagingServiceProvider);

  /// Send a message to the room
  Future<void> sendMessage(String content,
      {String? replyToMessageId, String? mediaUrl}) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.sendRoomMessage(
        senderId: currentUser.id,
        senderName: currentUser.displayName ?? currentUser.username,
        senderAvatarUrl: currentUser.avatarUrl,
        roomId: roomId,
        content: content,
        mediaUrl: mediaUrl,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.deleteMessage(messageId, currentUser.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Edit a message
  Future<void> editMessage(String messageId, String newContent) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.editMessage(
          messageId, currentUser.id, newContent);
    } catch (e) {
      rethrow;
    }
  }

  /// Add reaction to message
  Future<void> addReaction(String messageId, String emoji) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.addReaction(messageId, currentUser.id, emoji);
    } catch (e) {
      rethrow;
    }
  }

  /// Remove reaction from message
  Future<void> removeReaction(String messageId, String emoji) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.removeReaction(messageId, currentUser.id, emoji);
    } catch (e) {
      rethrow;
    }
  }
}

/// Direct message conversations provider
final conversationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);

  final messagingService = ref.watch(messagingServiceProvider);
  return messagingService
      .getUserConversations(currentUser.id)
      .handleError((error) {
    return <Map<String, dynamic>>[];
  });
});

/// Conversation messages provider
final conversationMessagesProvider =
    StreamProvider.family<List<DirectMessage>, Map<String, String>>(
        (ref, params) {
  final messagingService = ref.watch(messagingServiceProvider);
  return messagingService
      .getConversationMessages(
    params['userId1']!,
    params['userId2']!,
  )
      .handleError((error) {
    return <DirectMessage>[];
  });
});

/// Direct message controller
final directMessageControllerProvider = StreamProvider.autoDispose
    .family<List<DirectMessage>, String>((ref, otherUserId) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);

  final messagingService = ref.watch(messagingServiceProvider);
  return messagingService
      .getConversationMessages(currentUser.id, otherUserId)
      .handleError((error) {
    return <DirectMessage>[];
  });
});

class DirectMessageController {
  final Ref ref;
  final String otherUserId;

  DirectMessageController(this.ref, this.otherUserId);

  late final MessagingService _messagingService =
      ref.read(messagingServiceProvider);

  /// Send a direct message
  Future<void> sendMessage(
    String content, {
    DirectMessageType type = DirectMessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.sendMessage(
        senderId: currentUser.id,
        receiverId: otherUserId,
        content: content,
        type: type,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        metadata: metadata,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markAsRead() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final conversationId =
          ChatMessage.createConversationId(currentUser.id, otherUserId);
      await _messagingService.markMessagesAsRead(
          conversationId, currentUser.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.deleteMessage(messageId, currentUser.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Edit a message
  Future<void> editMessage(String messageId, String newContent) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.editMessage(
          messageId, currentUser.id, newContent);
    } catch (e) {
      rethrow;
    }
  }

  /// Add reaction to message
  Future<void> addReaction(String messageId, String emoji) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.addReaction(messageId, currentUser.id, emoji);
    } catch (e) {
      rethrow;
    }
  }

  /// Remove reaction from message
  Future<void> removeReaction(String messageId, String emoji) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.removeReaction(messageId, currentUser.id, emoji);
    } catch (e) {
      rethrow;
    }
  }
}

/// Typing indicator provider
final typingUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  final messagingService = ref.watch(messagingServiceProvider);
  return messagingService.getTypingUsers(roomId).handleError((error) {
    return <String>[];
  });
});

/// Total unread messages count provider
final totalUnreadMessagesProvider = StreamProvider<int>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield 0;
    return;
  }

  final messagingService = ref.watch(messagingServiceProvider);
  try {
    final count = await messagingService.getTotalUnreadCount(currentUser.id);
    yield count;
  } catch (e) {
    yield 0;
  }
});

/// Unread messages per conversation provider
final unreadMessagesPerConversationProvider =
    StreamProvider.family<int, String>((ref, conversationId) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield 0;
    return;
  }

  // This would need to be implemented in MessagingService
  // For now, return 0
  yield 0;
});

/// Send a room message
final sendRoomMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.sendRoomMessage(
    senderId: currentUser.id,
    senderName: currentUser.displayName ?? 'Unknown User',
    senderAvatarUrl: currentUser.avatarUrl,
    roomId: params['roomId'],
    content: params['content'],
  );
});
