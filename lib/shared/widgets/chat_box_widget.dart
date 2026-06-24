library;

import 'package:flutter/material.dart';

/// Chat Box Widget - Enhanced with message animations and smooth picker transitions
///
/// Features:
/// - Message fade-in animation with stagger effect (300ms per message)
/// - Smooth emoji/sticker picker opening/closing animations
/// - Sender avatar circles with proper sizing
/// - File attachment menu with smooth transitions
/// - Responsive message layout (left for others, right for current user)
/// - Time formatting with relative display (just now, 5m ago, etc.)
/// - Dark/light theme support
/// - Inline documentation for all components
///
/// Usage:
/// ```dart
/// ChatBoxWidget()
/// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/ui_provider.dart';
import '../../shared/providers/auth_providers.dart';
import '../../core/constants/ui_constants.dart';
import '../models/chat_message.dart';
import '../../core/design_system/design_constants.dart';

class ChatBoxWidget extends ConsumerStatefulWidget {
  const ChatBoxWidget({super.key});

  @override
  ConsumerState<ChatBoxWidget> createState() => _ChatBoxWidgetState();
}

class _ChatBoxWidgetState extends ConsumerState<ChatBoxWidget>
    with SingleTickerProviderStateMixin {
  late TextEditingController _messageController;
  late AnimationController _pickerController;
  bool _showEmojiPicker = false;
  bool _showStickerPicker = false;
  late Animation<double> _pickerHeightAnimation;

  final List<String> _emojis = const [
    'ðŸ˜€',
    'ðŸ˜‚',
    'ðŸ˜',
    'ðŸ¥°',
    'ðŸ˜Ž',
    'ðŸ¤”',
    'ðŸ˜’',
    'ðŸ”¥',
    'ðŸ’¯',
    'ðŸ‘',
    'ðŸ‘',
    'ðŸŽ‰',
    'ðŸŽŠ',
    'ðŸ’ª',
    'âœ¨',
    'ðŸŒŸ',
  ];

  final List<String> _stickers = const [
    'ðŸ‘‹',
    'ðŸ¤',
    'ðŸ’¼',
    'ðŸŽ¯',
    'ðŸŽ¬',
    'ðŸŽ¨',
    'ðŸŽ­',
    'ðŸŽ®',
  ];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _pickerController = AnimationController(
      duration: AnimationDurations.fast,
      vsync: this,
    );

    _pickerHeightAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pickerController, curve: AppCurves.easeOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pickerController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    setState(() {
      if (_showEmojiPicker) {
        _pickerController.reverse().then((_) {
          setState(() => _showEmojiPicker = false);
        });
      } else {
        _showStickerPicker = false;
        _showEmojiPicker = true;
        _pickerController.forward();
      }
    });
  }

  void _toggleStickerPicker() {
    setState(() {
      if (_showStickerPicker) {
        _pickerController.reverse().then((_) {
          setState(() => _showStickerPicker = false);
        });
      } else {
        _showEmojiPicker = false;
        _showStickerPicker = true;
        _pickerController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    final messages = ref.watch(chatMessagesProvider);

    return Column(
      children: [
        /// Chat message history
        Expanded(
          child: messages.isEmpty
              ? _buildEmptyState(darkMode)
              : _buildMessageList(messages),
        ),

        /// Message input area with controls
        _buildMessageInputArea(darkMode),
      ],
    );
  }

  /// Builds empty state message
  Widget _buildEmptyState(bool darkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: WidgetSizes.largeIconSize,
            color: DesignColors.accent,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Your inbox is empty',
            style: AppTextStyles.h5.copyWith(
              color: DesignColors.white,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Go find someone to chat with ðŸ‘‰',
            style: AppTextStyles.body2.copyWith(
              color: DesignColors.textLightGray,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds animated message list with staggered fade-in
  Widget _buildMessageList(List<ChatMessage> messages) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(Spacing.md),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final delayMs = index * 100;

        return _AnimatedChatMessage(
          message: message,
          delayMs: delayMs,
        );
      },
    );
  }

  /// Builds the message input area with controls and optional pickers
  Widget _buildMessageInputArea(bool darkMode) {
    return Container(
      color: DesignColors.surfaceDefault,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: DesignColors.accentDark,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Emoji picker with animation
          if (_showEmojiPicker)
            _buildAnimatedPicker(
              height: 200,
              darkMode: darkMode,
              items: _emojis,
              onEmojiSelected: (emoji) {
                _messageController.text += emoji;
                _toggleEmojiPicker();
              },
            ),

          /// Sticker picker with animation
          if (_showStickerPicker)
            _buildAnimatedPicker(
              height: 150,
              darkMode: darkMode,
              items: _stickers,
              onEmojiSelected: (sticker) {
                _messageController.text += sticker;
                _toggleStickerPicker();
              },
            ),

          /// Input controls
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: _buildInputControls(darkMode),
          ),
        ],
      ),
    );
  }

  /// Builds the input controls row with file, emoji, sticker, and send buttons
  Widget _buildInputControls(bool darkMode) {
    return Row(
      children: [
        /// File attachment menu
        _buildAttachmentButton(darkMode),
        const SizedBox(width: Spacing.sm),

        /// Message input field
        Expanded(
          child: TextField(
            controller: _messageController,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Say hi ðŸ‘‹ ... or share a vibe',
              hintStyle: const TextStyle(
                color: DesignColors.textLightGray,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BorderRadii.lg),
                borderSide: const BorderSide(
                  color: DesignColors.accentDark,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              filled: true,
              fillColor: DesignColors.surfaceAlt,
            ),
            style: AppTextStyles.body2.copyWith(
              color: DesignColors.white,
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),

        /// Emoji button
        _buildPickerButton(
          icon: Icons.emoji_emotions,
          onTap: _toggleEmojiPicker,
          isActive: _showEmojiPicker,
        ),
        const SizedBox(width: Spacing.sm),

        /// Sticker button
        _buildPickerButton(
          label: 'ðŸŽ¨',
          onTap: _toggleStickerPicker,
          isActive: _showStickerPicker,
        ),
        const SizedBox(width: Spacing.sm),

        /// Send button
        _buildSendButton(),
      ],
    );
  }

  /// Builds the file attachment menu button
  Widget _buildAttachmentButton(bool darkMode) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'file') {
          _handleFileUpload();
        } else if (value == 'image') {
          _handleImageUpload();
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'file',
          child: Row(
            children: [
              Icon(
                Icons.attach_file,
                size: WidgetSizes.smallIconSize,
                color: DesignColors.accent,
              ),
              SizedBox(width: Spacing.md),
              Text('Share File'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'image',
          child: Row(
            children: [
              Icon(
                Icons.image,
                size: WidgetSizes.smallIconSize,
                color: DesignColors.accent,
              ),
              SizedBox(width: Spacing.md),
              Text('Share Image'),
            ],
          ),
        ),
      ],
      child: _buildIconButton(Icons.attach_file),
    );
  }

  /// Builds a reusable icon button for controls
  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: DesignColors.surfaceAlt,
        borderRadius: BorderRadius.circular(BorderRadii.circular),
      ),
      child: Icon(
        icon,
        size: WidgetSizes.mediumIconSize,
        color: DesignColors.accent,
      ),
    );
  }

  /// Builds emoji/sticker picker buttons
  Widget _buildPickerButton({
    IconData? icon,
    String? label,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return Material(
      color: DesignColors.surfaceAlt,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BorderRadii.circular),
        child: Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: isActive ? DesignColors.accent : DesignColors.surfaceAlt,
            borderRadius: BorderRadius.circular(BorderRadii.circular),
            boxShadow: isActive ? AppShadows.elevation2 : const [],
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: WidgetSizes.mediumIconSize,
                  color: isActive ? DesignColors.white : DesignColors.accent,
                )
              : Text(
                  label!,
                  style: DesignTypography.body.copyWith(
                    color: DesignColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  /// Builds the send button with icon
  Widget _buildSendButton() {
    return Material(
      color: DesignColors.accent,
      child: InkWell(
        onTap: _sendMessage,
        borderRadius: BorderRadius.circular(BorderRadii.circular),
        child: Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: DesignColors.accent,
            borderRadius: BorderRadius.circular(BorderRadii.circular),
            boxShadow: AppShadows.elevation2,
          ),
          child: const Icon(
            Icons.send,
            size: WidgetSizes.mediumIconSize,
            color: DesignColors.white,
          ),
        ),
      ),
    );
  }

  /// Builds animated picker with fade and slide animation
  Widget _buildAnimatedPicker({
    required double height,
    required bool darkMode,
    required List<String> items,
    required Function(String) onEmojiSelected,
  }) {
    return AnimatedBuilder(
      animation: _pickerHeightAnimation,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _pickerHeightAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        height: height,
        color: DesignColors.surfaceAlt,
        padding: const EdgeInsets.all(Spacing.sm),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: Spacing.sm,
            crossAxisSpacing: Spacing.sm,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildPickerItem(items[index], onEmojiSelected);
          },
        ),
      ),
    );
  }

  /// Builds individual picker item with hover effect
  Widget _buildPickerItem(
    String item,
    Function(String) onSelected,
  ) {
    return Material(
      color: DesignColors.surfaceAlt,
      child: InkWell(
        onTap: () => onSelected(item),
        borderRadius: BorderRadius.circular(BorderRadii.md),
        hoverColor: DesignColors.accentDark,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xs),
          child: Center(
            // ignore: prefer_const_constructors
            child: Text(
              item,
              style: DesignTypography.body.copyWith(
                color: DesignColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sends a message and clears the input field
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final currentUser = ref.read(currentUserProvider).value;
    ref.read(chatMessagesProvider.notifier).sendMessage(
          senderId: currentUser?.id ?? 'anonymous',
          senderName: currentUser?.displayName ?? 'You',
          senderAvatarUrl:
              currentUser?.avatarUrl ?? 'https://i.pravatar.cc/150?u=current',
          content: content,
        );

    _messageController.clear();
    if (_showEmojiPicker) _toggleEmojiPicker();
    if (_showStickerPicker) _toggleStickerPicker();
  }

  void _handleFileUpload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File upload coming soon'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(Spacing.md),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  void _handleImageUpload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image upload coming soon'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(Spacing.md),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }
}

/// Animated chat message with fade-in and slide effect
class _AnimatedChatMessage extends StatefulWidget {
  final ChatMessage message;
  final int delayMs;

  const _AnimatedChatMessage({
    required this.message,
    required this.delayMs,
  });

  @override
  State<_AnimatedChatMessage> createState() => _AnimatedChatMessageState();
}

class _AnimatedChatMessageState extends State<_AnimatedChatMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationDurations.normal,
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeOut),
    );

    // Staggered animation based on delay
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _ChatMessageTile(message: widget.message),
      ),
    );
  }
}

/// Chat message tile displaying the message content and metadata
class _ChatMessageTile extends ConsumerWidget {
  final ChatMessage message;

  const _ChatMessageTile({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final isCurrentUser = message.senderId == (currentUser?.id ?? '');
    final senderLabel = isCurrentUser
        ? 'You'
        : (message.senderName.isNotEmpty ? message.senderName : 'Unknown');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          /// Avatar for other users (left side)
          if (!isCurrentUser) ...[
            _buildAvatar(message.senderAvatarUrl ?? ''),
            const SizedBox(width: Spacing.md),
          ],

          /// Message bubble and metadata
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                /// Sender name
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Text(
                    senderLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: DesignColors.accentLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                /// Message bubble
                _buildMessageBubble(isCurrentUser, darkMode),

                /// Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: AppTextStyles.caption.copyWith(
                      color: DesignColors.textLightGray,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Avatar for current user (right side)
          if (isCurrentUser) ...[
            const SizedBox(width: Spacing.md),
            _buildAvatar(message.senderAvatarUrl ?? ''),
          ],
        ],
      ),
    );
  }

  /// Builds the avatar circle
  Widget _buildAvatar(String avatarUrl) {
    return CircleAvatar(
      backgroundImage: NetworkImage(avatarUrl),
      radius: 16,
      onBackgroundImageError: (exception, stackTrace) {},
    );
  }

  /// Builds the message bubble with content
  Widget _buildMessageBubble(bool isCurrentUser, bool darkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: isCurrentUser ? DesignColors.accent : DesignColors.surfaceAlt,
        border: isCurrentUser
            ? null
            : Border.all(color: DesignColors.accentDark, width: 1),
        borderRadius: BorderRadius.circular(BorderRadii.lg),
        boxShadow: AppShadows.elevation1,
      ),
      child: _buildMessageContent(isCurrentUser),
    );
  }

  /// Builds the message content (handles files and text)
  Widget _buildMessageContent(bool isCurrentUser) {
    if (message.contentType == MessageContentType.file) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_file,
            size: WidgetSizes.smallIconSize,
            color: isCurrentUser ? DesignColors.white : DesignColors.accent,
          ),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Text(
              message.content,
              style: AppTextStyles.body2.copyWith(
                color: isCurrentUser ? DesignColors.white : DesignColors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      message.content,
      style: AppTextStyles.body2.copyWith(
        color: isCurrentUser ? DesignColors.white : DesignColors.white,
      ),
    );
  }

  /// Formats timestamp to relative time display
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
