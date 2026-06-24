import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../shared/providers/providers.dart';
import '../../shared/models/user.dart';
import '../../shared/models/direct_message.dart';
import '../../shared/models/message.dart' show MessageStatus;
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../shared/neon_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final User currentUser;
  final User otherUser;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  DocumentSnapshot? _lastDocument;
  bool _isTyping = false;
  Timer? _typingTimer;
  List<DirectMessage> _messages = [];
  bool _isInitialLoading = true;
  StreamSubscription<List<DirectMessage>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    // Load initial messages
    _loadInitialMessages();

    // Set up real-time message updates
    _setupMessageStream();

    // Mark messages as read when entering chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);

    // Add typing listener
    _messageController.addListener(_onTyping);
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTyping() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
      // In a real implementation, you'd send typing status to the other user
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  void _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final messagingService = ref.read(messagingServiceProvider);
      final (newMessages, lastDoc) =
          await messagingService.getPaginatedMessages(
        widget.currentUser.id,
        widget.otherUser.id,
        limit: 20,
        startAfter: _lastDocument,
      );

      if (newMessages.isNotEmpty) {
        setState(() {
          _messages.insertAll(
              0, newMessages); // Insert at beginning for older messages
          _lastDocument = lastDoc;
          _hasMoreMessages = newMessages.length == 20;
        });
      } else {
        setState(() {
          _hasMoreMessages = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _isInitialLoading = true;
    });

    try {
      final messagingService = ref.read(messagingServiceProvider);
      final (messages, lastDoc) = await messagingService.getPaginatedMessages(
        widget.currentUser.id,
        widget.otherUser.id,
        limit: 50,
      );

      setState(() {
        _messages = messages;
        _lastDocument = lastDoc;
        _isInitialLoading = false;
        _hasMoreMessages = messages.length == 50;
      });
    } catch (e) {
      debugPrint('Error loading initial messages: $e');
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  void _markMessagesAsRead() {
    final messagingService = ref.read(messagingServiceProvider);
    final conversationId = messagingService.getConversationId(
      widget.currentUser.id,
      widget.otherUser.id,
    );
    ref.read(markMessagesReadProvider(conversationId).future);
  }

  void _setupMessageStream() {
    final messagingService = ref.read(messagingServiceProvider);
    _messagesSubscription = messagingService
        .getConversationMessages(widget.currentUser.id, widget.otherUser.id)
        .listen((messages) async {
      if (mounted && !_isInitialLoading) {
        // Mark incoming messages as delivered
        for (final message in messages) {
          if (message.senderId != widget.currentUser.id &&
              message.status == MessageStatus.sent) {
            try {
              await ref.read(markMessageAsDeliveredProvider({
                'messageId': message.id,
              }).future);
            } catch (e) {
              // Silently handle errors for status updates
              debugPrint('Failed to mark message as delivered: $e');
            }
          }
        }

        setState(() {
          _messages = messages;
        });

        // Mark visible messages as read
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markMessagesAsRead();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4C4C), Color(0xFFFFD700)],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 2,
                  ),
                ),
                child: widget.otherUser.avatarUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          '${widget.otherUser.avatarUrl}?t=${DateTime.now().millisecondsSinceEpoch}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.displayName ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${widget.otherUser.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Messages list
            Expanded(
              child: _isInitialLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyChat()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _messages.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isLoadingMore) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFF4C4C)),
                                  ),
                                ),
                              );
                            }

                            final message = _messages[index];
                            final isCurrentUser = message
                                .isFromCurrentUser(widget.currentUser.id);

                            return MessageBubble(
                              message: message,
                              isCurrentUser: isCurrentUser,
                              onEditMessage: _editMessage,
                              onDeleteMessage: _deleteMessage,
                              onAddReaction: _addReaction,
                              onRemoveReaction: _removeReaction,
                            );
                          },
                        ),
            ),

            // Typing indicator
            if (_isTyping)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'You are typing...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Message input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const GlowText(
            text: 'Start a conversation!',
            fontSize: 18,
            color: Colors.white70,
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.otherUser.displayName}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFFF4C4C),
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
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF4C4C),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFD700),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          NeonButton(
            onPressed: _sendMessage,
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.send,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await ref.read(sendDirectMessageProvider({
        'receiverId': widget.otherUser.id,
        'content': content,
      }).future);
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: const Color(0xFFFF4C4C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _editMessage(String messageId, String newContent) async {
    try {
      await ref.read(editMessageProvider({
        'messageId': messageId,
        'newContent': newContent,
      }).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to edit message: $e'),
            backgroundColor: const Color(0xFFFF4C4C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deleteMessage(String messageId) async {
    try {
      await ref.read(deleteMessageProvider({
        'messageId': messageId,
      }).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: $e'),
            backgroundColor: const Color(0xFFFF4C4C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _addReaction(String messageId, String emoji) async {
    try {
      await ref.read(addReactionProvider({
        'messageId': messageId,
        'emoji': emoji,
      }).future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reaction: $e'),
            backgroundColor: const Color(0xFFFF4C4C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _removeReaction(String messageId, String emoji) async {
    try {
      await ref.read(removeReactionProvider({
        'messageId': messageId,
        'emoji': emoji,
      }).future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove reaction: $e'),
            backgroundColor: const Color(0xFFFF4C4C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class MessageBubble extends ConsumerWidget {
  final DirectMessage message;
  final bool isCurrentUser;
  final Function(String, String)? onEditMessage;
  final Function(String)? onDeleteMessage;
  final Function(String, String)? onAddReaction;
  final Function(String, String)? onRemoveReaction;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onEditMessage,
    this.onDeleteMessage,
    this.onAddReaction,
    this.onRemoveReaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Message bubble
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? const Color(0xFFFF4C4C)
                      : Colors.white.withValues(alpha: 0.1),
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
                  border: Border.all(
                    color: isCurrentUser
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isCurrentUser
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                        if (message.isEdited) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(edited)',
                            style: TextStyle(
                              color: isCurrentUser
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.3),
                              fontSize: 8,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          _buildStatusIndicator(message.status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reactions
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: message.reactions.entries.map((entry) {
                    final emoji = entry.key;
                    final users = entry.value;
                    final hasCurrentUserReacted =
                        currentUser != null && users.contains(currentUser.id);

                    return GestureDetector(
                      onTap: () {
                        if (currentUser != null) {
                          if (hasCurrentUserReacted) {
                            onRemoveReaction?.call(message.id, emoji);
                          } else {
                            onAddReaction?.call(message.id, emoji);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasCurrentUserReacted
                              ? const Color(0xFFFF4C4C).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasCurrentUserReacted
                                ? const Color(0xFFFF4C4C)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              users.length.toString(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit option (only if within 15 minutes and text message)
            if (_canEditMessage()) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Edit Message',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context);
                },
              ),
              const Divider(color: Colors.white24),
            ],
            // Add reaction option
            ListTile(
              leading: const Icon(Icons.add_reaction, color: Colors.white),
              title: const Text(
                'Add Reaction',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context);
              },
            ),
            const Divider(color: Colors.white24),
            // Delete option
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFFF4C4C)),
              title: const Text(
                'Delete Message',
                style: TextStyle(color: Color(0xFFFF4C4C)),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _canEditMessage() {
    if (message.type != DirectMessageType.text) return false;
    final timeDiff = DateTime.now().difference(message.timestamp);
    return timeDiff.inMinutes <= 15;
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        title: const Text(
          'Edit Message',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new message...',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFD700)),
            ),
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                final dialogContext = context;
                try {
                  onEditMessage?.call(message.id, newContent);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Message edited'),
                        backgroundColor: Color(0xFFFFD700),
                      ),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to edit message: $e'),
                        backgroundColor: const Color(0xFFFF4C4C),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFFFD700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        title: const Text(
          'Delete Message',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final dialogContext = context;
              try {
                onDeleteMessage?.call(message.id);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Message deleted'),
                      backgroundColor: Color(0xFFFF4C4C),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete message: $e'),
                      backgroundColor: const Color(0xFFFF4C4C),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF4C4C)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showReactionPicker(BuildContext context) {
    final commonEmojis = [
      'ðŸ‘',
      'â¤ï¸',
      'ðŸ˜‚',
      'ðŸ˜®',
      'ðŸ˜¢',
      'ðŸ˜¡',
      'ðŸŽ‰',
      'ðŸ”¥'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add Reaction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: commonEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onAddReaction?.call(message.id, emoji);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(MessageStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.schedule;
        color = Colors.white.withValues(alpha: 0.5);
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.white.withValues(alpha: 0.7);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white.withValues(alpha: 0.7);
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = const Color(0xFF4CAF50); // Green for read
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
}
