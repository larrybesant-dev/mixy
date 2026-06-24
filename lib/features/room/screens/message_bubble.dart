import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/message.dart';
import 'package:mixvy/shared/providers/user_display_name_provider.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final String currentUserId;
  final Message? repliedMessage; // For displaying replied message content
  final VoidCallback? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.repliedMessage,
    this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentUser = message.senderId == currentUserId;

    // Get cached display name - use message.senderName if available, otherwise fetch
    final displayNameAsync =
        ref.watch(userDisplayNameProvider(message.senderId));
    final displayName = message.senderName.isNotEmpty
        ? message.senderName
        : displayNameAsync.maybeWhen(
            data: (name) => name,
            orElse: () => 'Loading...',
          );

    return GestureDetector(
      onLongPress: onReply,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? const Color(0xFFFF69B4)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isCurrentUser
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isCurrentUser
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply indicator
                    if (message.replyToMessageId != null &&
                        repliedMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color:
                                  isCurrentUser ? Colors.white70 : Colors.blue,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repliedMessage!.senderName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isCurrentUser
                                    ? Colors.white70
                                    : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              repliedMessage!.content,
                              style: TextStyle(
                                fontSize: 12,
                                color: isCurrentUser
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                    if (!isCurrentUser)
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    if (!isCurrentUser) const SizedBox(height: 4),

                    // Message content
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Timestamp and status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isCurrentUser ? Colors.white70 : Colors.black54,
                          ),
                        ),

                        // Read receipt for current user's messages
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          _buildReadReceipt(),
                        ],

                        // Edited indicator
                        if (message.isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(edited)',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isCurrentUser
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadReceipt() {
    IconData icon;
    Color color;

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.schedule;
        color = Colors.grey;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }

    return Icon(
      icon,
      size: 12,
      color: color,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

