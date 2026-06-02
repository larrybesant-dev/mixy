import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/features/messaging/models/message_model.dart';
import 'package:mixvy/core/velvet_noir_constants.dart';
import 'message_bubble.dart';

/// Self-contained chat panel widget for the Paltalk-style room layout.
/// Accepts streams/data as props and exposes a send callback so the
/// parent (LiveRoomScreen) retains all RTC/Firestore logic.
class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({
    super.key,
    required this.messages,
    required this.isLoadingMessages,
    required this.currentUserId,
    required this.currentUsername,
    required this.isSending,
    required this.cooldownMessage,
    required this.isMuted,
    required this.isBanned,
    required this.allowChat,
    required this.hasBlockedRelationship,
    required this.showEmojiTray,
    required this.onToggleEmojiTray,
    required this.onSendMessage,
    required this.onTyping,
    required this.messageController,
    required this.scrollController,
    required this.senderLabelResolver,
    required this.senderVipLevelResolver,
    required this.senderAvatarResolver,
    this.onTapSender,
    this.typingNames = const [],
    this.extraHeader,
  });

  final List<MessageModel> messages;
  final bool isLoadingMessages;
  final String currentUserId;
  final String currentUsername;
  final bool isSending;
  final String cooldownMessage;
  final bool isMuted;
  final bool isBanned;
  final bool allowChat;
  final bool hasBlockedRelationship;
  final bool showEmojiTray;
  final VoidCallback onToggleEmojiTray;
  final Future<void> Function(String text) onSendMessage;
  final VoidCallback onTyping;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final String Function(String senderId) senderLabelResolver;
  final int Function(String senderId) senderVipLevelResolver;
  final String? Function(String senderId) senderAvatarResolver;

  /// Called when the user taps the avatar or name of a message sender.
  final void Function(String senderId)? onTapSender;

  /// Names of users currently typing.
  final List<String> typingNames;

  /// Optional widget rendered above the message list (e.g. gift row,
  /// blocked warning, slow-mode notice).
  final Widget? extraHeader;

  static const List<String> _quickEmojis = [
    '😀',
    '😂',
    '😍',
    '🔥',
    '👏',
    '🙏',
    '💯',
    '🎉',
    '❤️',
    '👍',
    '👀',
    '😎',
  ];

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  int _lastCount = 0;
  bool _userHasScrolledUp = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    if (!widget.scrollController.hasClients) return;

    final pos = widget.scrollController.position;
    // If we are more than 100 pixels away from the bottom, assume user is reading history.
    final double offsetFromBottom = pos.maxScrollExtent - pos.pixels;

    if (offsetFromBottom > 100) {
      if (!_userHasScrolledUp) {
        setState(() => _userHasScrolledUp = true);
      }
    } else {
      if (_userHasScrolledUp) {
        setState(() => _userHasScrolledUp = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_userHasScrolledUp) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.scrollController.hasClients &&
          widget.scrollController.position.hasContentDimensions) {
        widget.scrollController.jumpTo(
          widget.scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final npOnVariant = kVelvetGold.withValues(alpha: 0.65);

    if (widget.messages.length != _lastCount) {
      _lastCount = widget.messages.length;
      _scrollToBottom();
    }

    final hintText = widget.isMuted
        ? 'You are muted'
        : widget.isBanned
            ? 'You are banned'
            : widget.hasBlockedRelationship
                ? 'Blocked relationship in room'
                : !widget.allowChat
                    ? 'Chat disabled by host'
                    : 'Type a message…';
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final canSend = !widget.isSending &&
        !widget.isMuted &&
        !widget.isBanned &&
        widget.allowChat &&
        !widget.hasBlockedRelationship;

    return Container(
      decoration: BoxDecoration(
        color: kVelvetJet.withValues(alpha: 0.65), // Translucent backdrop matching Velvet Noir
        borderRadius: BorderRadius.zero,
        border: Border(
          left: BorderSide(
            color: kVelvetGold.withValues(alpha: 0.18), // Ultra thin premium gold border
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // Premium glassmorphic blur
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kVelvetJet.withValues(alpha: 0.5),
                  kVelvetWine.withValues(alpha: 0.08), // Subtle, elegant undertone of wine red
                  kVelvetJet.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Column(
              children: [
          // Extra header (gift row, blocked warning, etc.)
          if (widget.extraHeader != null) widget.extraHeader!,

          // message list
          Expanded(
            child: widget.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : widget.messages.isEmpty
                    ? Center(
                        child: Text(
                          'No message yet.',
                          style: TextStyle(color: npOnVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.all(6),
                        itemCount: widget.messages.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (context, i) {
                          final msg = widget.messages[i];
                          return MessageBubble(
                            key: ValueKey('msg_${msg.id}'),
                            message: msg,
                            isMe: msg.senderId == widget.currentUserId,
                            senderLabel:
                                widget.senderLabelResolver(msg.senderId),
                            senderVipLevel: widget.senderVipLevelResolver(
                              msg.senderId,
                            ),
                            senderAvatarUrl: widget.senderAvatarResolver(
                              msg.senderId,
                            ),
                            onTapSender: widget.onTapSender,
                          );
                        },
                      ),
          ),

          // Scroll-to-bottom fab overlay
          if (_userHasScrolledUp)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: FloatingActionButton.small(
                  backgroundColor: const Color(0xFFD4A853),
                  onPressed: () {
                    setState(() => _userHasScrolledUp = false);
                    _scrollToBottom();
                  },
                  child: const Icon(Icons.arrow_downward,
                      size: 18, color: Colors.white),
                ),
              ),
            ),

          // Cooldown notice
          if (widget.cooldownMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
              child: Text(
                widget.cooldownMessage,
                style: const TextStyle(
                  color: Color(0xFFFF6E84),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),

          // Typing indicator
          if (widget.typingNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.typingNames.length == 1
                      ? '${widget.typingNames[0]} is typing…'
                      : '${widget.typingNames.join(', ')} are typing…',
                  style: TextStyle(
                    color: npOnVariant,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Emoji tray
          if (widget.showEmojiTray)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: ChatPanel._quickEmojis.map((e) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      widget.messageController.text += e;
                      widget.messageController.selection =
                          TextSelection.fromPosition(
                        TextPosition(
                          offset: widget.messageController.text.length,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Input row
          SafeArea(
            top: false,
            left: false,
            right: false,
            minimum: const EdgeInsets.only(bottom: 4),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset > 0 ? 4 : 0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Emojis',
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        widget.showEmojiTray
                            ? Icons.emoji_emotions
                            : Icons.emoji_emotions_outlined,
                        color: npOnVariant,
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        widget.onToggleEmojiTray();
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.messageController,
                        onChanged: (_) => widget.onTyping(),
                        enabled: canSend,
                        textInputAction: TextInputAction.send,
                        scrollPadding: EdgeInsets.only(
                          top: 24,
                          bottom: keyboardInset + 120,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(
                            color: npOnVariant,
                            fontSize: 12,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: kVelvetGold.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: kVelvetGold.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: kVelvetGold,
                            ),
                          ),
                          filled: true,
                          fillColor: kVelvetJet.withValues(alpha: 0.55),
                        ),
                        onSubmitted: canSend
                            ? (text) async {
                                final trimmed = text.trim();
                                if (trimmed.isNotEmpty) {
                                  await widget.onSendMessage(trimmed);
                                }
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 36,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kVelvetGold,
                          foregroundColor: kVelvetJet,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: kVelvetGold.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                        ),
                        onPressed: canSend
                            ? () async {
                                final text =
                                    widget.messageController.text.trim();
                                if (text.isNotEmpty) {
                                  await widget.onSendMessage(text);
                                }
                              }
                            : null,
                        child: widget.isSending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Send',
                                style: TextStyle(
                                  color: kVelvetJet,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    ),
    ),
    );
  }
}
