import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_providers.dart';
import '../providers/service_providers.dart';
import '../services/messaging_service.dart';
import '../shared/models/chat_room.dart';
import 'chat_room_page.dart';

/// Resolves (or creates) a conversation between [currentUser] and
/// [otherUserId], then pushes [ChatRoomPage].
///
/// Callable from any [ConsumerWidget]:
/// ```dart
/// onPressed: () => startConversation(context, ref, otherUserId),
/// ```
Future<void> startConversation(
  BuildContext context,
  WidgetRef ref,
  String otherUserId,
) async {
  final currentUser = ref.read(currentUserProvider).value;
  if (currentUser == null) return;

  final convoId = await ref
      .read(messagingServiceProvider)
      .getOrCreateConversationId(currentUser.id, otherUserId);

  if (!context.mounted) return;

  // Create a ChatRoom object for navigation
  final chatRoom = ChatRoom(
    id: convoId ?? '',
    participants: [currentUser.id, otherUserId],
    lastMessage: '',
    lastMessageTime: DateTime.now(),
    unreadCounts: {},
    isTyping: false,
  );

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatRoomPage(chatRoom: chatRoom),
    ),
  );
}

/// Drop-in "Message" button. Handles the full start-conversation flow.
///
/// ```dart
/// StartConversationButton(otherUserId: profile.id)
/// ```
class StartConversationButton extends ConsumerWidget {
  final String otherUserId;

  const StartConversationButton({super.key, required this.otherUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () => startConversation(context, ref, otherUserId),
      icon: const Icon(Icons.message),
      label: const Text('Message'),
    );
  }
}
