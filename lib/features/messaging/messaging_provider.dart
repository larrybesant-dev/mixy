// Riverpod provider for Messaging
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message.dart';

// Messaging state notifier
class MessagingNotifier extends Notifier<List<Message>> {
  @override
  List<Message> build() => [];

  void addMessage(Message message) {
    state = [...state, message];
  }

  void removeMessage(String messageId) {
    state = state.where((m) => m.id != messageId).toList();
  }

  void setMessages(List<Message> messages) {
    state = messages;
  }

  void clear() {
    state = [];
  }
}

final messagingProvider = NotifierProvider<MessagingNotifier, List<Message>>(
  () => MessagingNotifier(),
);
