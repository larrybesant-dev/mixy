// lib/providers/chat_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../../services/chat/chat_service.dart';
import '../../services/chat/typing_service.dart';
import '../../services/storage/file_share_service.dart';

final chatServiceProvider = Provider((ref) => ChatService());
final typingServiceProvider = Provider((ref) => TypingService());
final fileShareServiceProvider = Provider((ref) => FileShareService());

/// Conversation list provider - streams all chat rooms for current user
final conversationListProvider = StreamProvider<List<ChatRoom>>((ref) {
  final service = ref.watch(chatServiceProvider);
  return service.streamUserChatRooms();
});

/// Messages provider for a specific chat room (DM or group chat)
final messagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, roomId) {
    final service = ref.watch(chatServiceProvider);
    return service.streamMessages(roomId);
  },
);

/// Pinned messages provider for a chat room
final pinnedMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, roomId) {
    final service = ref.watch(chatServiceProvider);
    return service.streamPinnedMessages(roomId);
  },
);

/// Typing indicator provider for a chat room
final typingStatusProvider = StreamProvider.family<bool, String>(
  (ref, roomId) {
    final service = ref.watch(chatServiceProvider);
    return service.streamTypingStatus(roomId);
  },
);

/// Presence provider - streams online status for a user
final presenceProvider = StreamProvider.family<Map<String, dynamic>, String>(
  (ref, userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return {
          'isOnline': false,
          'lastSeen': null,
        };
      }

      final data = snapshot.data()!;
      return {
        'isOnline': data['isOnline'] ?? false,
        'lastSeen': data['lastSeen'] != null
            ? (data['lastSeen'] as Timestamp).toDate()
            : null,
      };
    });
  },
);

/// Chat settings provider
final chatSettingsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, roomId) async {
    final service = ref.watch(chatServiceProvider);
    return service.getChatSettings(roomId);
  },
);

/// Message count provider
final messageCountProvider = FutureProvider.family<int, String>(
  (ref, roomId) async {
    final service = ref.watch(chatServiceProvider);
    return service.getMessageCount(roomId);
  },
);
