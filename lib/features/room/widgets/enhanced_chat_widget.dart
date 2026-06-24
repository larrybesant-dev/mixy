import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/services/enhanced_chat_service.dart';

/// Enhanced Chat Widget for voice rooms
///
/// Features:
/// - Message display with user avatars
/// - Pinned messages section
/// - Message reactions
/// - Delete and pin actions
/// - Responsive design
class EnhancedChatWidget extends ConsumerStatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatarUrl;

  const EnhancedChatWidget({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatarUrl,
  });

  @override
  ConsumerState<EnhancedChatWidget> createState() => _EnhancedChatWidgetState();
}

class _EnhancedChatWidgetState extends ConsumerState<EnhancedChatWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showPinned = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));
    final pinnedMessagesAsync =
        ref.watch(pinnedChatMessagesProvider(widget.roomId));
    final chatService = ref.read(enhancedChatServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with pinned messages toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.chat, color: Color(0xFFFF4C4C), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Room Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                pinnedMessagesAsync.whenData((pinnedMessages) {
                      if (pinnedMessages.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return InkWell(
                        onTap: () {
                          setState(() => _showPinned = !_showPinned);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _showPinned
                                ? const Color(0xFFFF4C4C)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.push_pin,
                                color: _showPinned
                                    ? Colors.white
                                    : const Color(0xFFFF4C4C),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${pinnedMessages.length}',
                                style: TextStyle(
                                  color: _showPinned
                                      ? Colors.white
                                      : const Color(0xFFFF4C4C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).value ??
                    const SizedBox.shrink(),
              ],
            ),
          ),

          // Pinned messages section
          if (_showPinned)
            pinnedMessagesAsync.when(
              data: (pinnedMessages) {
                if (pinnedMessages.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'No pinned messages',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: pinnedMessages.map((message) {
                      return _buildMessageBubble(
                        message,
                        chatService,
                        isPinned: true,
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(
                      messages[index],
                      chatService,
                      isCurrentUser:
                          messages[index].userId == widget.currentUserId,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFFF4C4C),
                  ),
                ),
              ),
              error: (error, __) => Center(
                child: Text(
                  'Error loading messages',
                  style: TextStyle(color: Colors.red[300]),
                ),
              ),
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
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
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF4C4C),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(chatService),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFFF4C4C),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _sendMessage(chatService),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    EnhancedChatService chatService, {
    bool isCurrentUser = false,
    bool isPinned = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            CircleAvatar(
              radius: 16,
              backgroundImage: message.userAvatarUrl.isNotEmpty
                  ? NetworkImage(message.userAvatarUrl)
                  : null,
              child: message.userAvatarUrl.isEmpty
                  ? Text(message.userName[0].toUpperCase())
                  : null,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Text(
                    message.userName,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? const Color(0xFFFF4C4C)
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      if (message.reactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 4,
                            children: message.reactions
                                .map((emoji) => Text(emoji,
                                    style: const TextStyle(fontSize: 14)))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          chatService.pinMessage(widget.roomId, message.id);
                        },
                        child: Icon(
                          message.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: message.isPinned
                              ? const Color(0xFFFF4C4C)
                              : Colors.grey,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          chatService.deleteMessage(widget.roomId, message.id);
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Future<void> _sendMessage(EnhancedChatService chatService) async {
    if (_messageController.text.isEmpty) return;

    try {
      await chatService.sendMessage(
        roomId: widget.roomId,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        userAvatarUrl: widget.currentUserAvatarUrl,
        content: _messageController.text,
      );
      _messageController.clear();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

