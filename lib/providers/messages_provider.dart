import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';

/// Cache ChatService as a singleton
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

/// Stream messages via cached service
final messagesProvider = StreamProvider.family<List<Message>, String>((ref, roomId) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.streamMessages(roomId);
});
