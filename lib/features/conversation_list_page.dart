import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_providers.dart';
import '../services/messaging_service.dart';
import '../shared/models/chat_room.dart';
import 'chat_room_page.dart';

final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService();
});

class ConversationListPage extends ConsumerWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final messaging = ref.watch(messagingServiceProvider);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<ChatRoom>>(
      stream: messaging.streamConversations(currentUser.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final conversations = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Messages'),
          ),
          body: ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final chatRoom = conversations[index];
              final unread = chatRoom.unreadCounts[currentUser.id] ?? 0;

              return ListTile(
                title: const Text('Chat'),
                subtitle: Text(chatRoom.lastMessage),
                trailing: unread > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomPage(
                        chatRoom: chatRoom,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
