import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/chat_message.dart';
import 'package:mixvy/features/room/providers/room_subcollection_providers.dart';

/// Chat overlay widget for voice room
class VoiceRoomChatOverlay extends ConsumerStatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentDisplayName;
  final VoidCallback? onClosed;

  const VoiceRoomChatOverlay({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentDisplayName,
    this.onClosed,
  });

  @override
  ConsumerState<VoiceRoomChatOverlay> createState() =>
      _VoiceRoomChatOverlayState();
}

class _VoiceRoomChatOverlayState extends ConsumerState<VoiceRoomChatOverlay>
    with SingleTickerProviderStateMixin {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController.forward();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Debug: Log what we're sending
    debugPrint(
        'ðŸ“¤ Sending message: displayName="${widget.currentDisplayName}", userId="${widget.currentUserId}", message="$message"');

    try {
      final repository = ref.read(roomSubcollectionRepositoryProvider);
      final chatMessage = ChatMessage(
        id: '', // Will be assigned by Firestore
        senderId: widget.currentUserId,
        senderName: widget.currentDisplayName,
        content: message,
        timestamp: DateTime.now(),
        context: MessageContext.room,
        roomId: widget.roomId,
        contentType: MessageContentType.text,
      );

      await repository.sendMessage(
        roomId: widget.roomId,
        message: chatMessage,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('âŒ Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(roomMessagesFirestoreProvider(widget.roomId));

    return messagesAsync.when(
      data: (messages) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_slideController),
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(240, 20, 20, 30),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Messages list
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet\nStart the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _ChatMessageBubble(
                            message: messages[index],
                            isCurrentUser: messages[index].senderId ==
                                widget.currentUserId,
                          );
                        },
                      ),
              ),

              // Input field
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border(
                    top: BorderSide(color: Colors.grey[800]!),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Colors.pink),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.grey[800],
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.pink,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ), // Close Container
      ), // Close SlideTransition
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    ); // Close when()
  }
}

/// Individual chat message bubble
class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;

  const _ChatMessageBubble({
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'ðŸ’¬ Rendering message bubble - senderId="${message.senderId}", senderName="${message.senderName}", isCurrentUser=$isCurrentUser, content="${message.content}"');

    // ChatMessage doesn't have isSystemMessage, so check content pattern
    final isSystemMessage = message.content.startsWith('[System]');

    if (isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            message.content,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final displayName =
        message.senderName.isNotEmpty ? message.senderName : message.senderId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            Tooltip(
              message: displayName,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[700],
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (!isCurrentUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.pink : Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Always show sender name
                  Text(
                    displayName,
                    style: TextStyle(
                      color: isCurrentUser
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.pink,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}

/// Bottom sheet version of chat
void showVoiceRoomChat(
  BuildContext context, {
  required String roomId,
  required String currentUserId,
  required String currentDisplayName,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => VoiceRoomChatOverlay(
      roomId: roomId,
      currentUserId: currentUserId,
      currentDisplayName: currentDisplayName,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

