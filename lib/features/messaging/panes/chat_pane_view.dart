import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_error_utils.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme.dart';
import '../../../core/utils/network_image_url.dart';
import '../../../features/feed/providers/user_providers.dart' as feed_user;
import '../../../services/web_popout_service.dart';
import '../../../widgets/safe_network_avatar.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/guest_auth_gate.dart';
import '../../../widgets/emoji_pack/emoji_pack_picker.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../../../models/user_model.dart';
import '../../../observability/system_event_bus.dart';
import '../providers/messaging_provider.dart';

class ChatPaneView extends ConsumerStatefulWidget {
  const ChatPaneView({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.showHeader = true,
  });

  final String conversationId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final bool showHeader;

  @override
  ConsumerState<ChatPaneView> createState() => _ChatPaneViewState();
}

class _ChatPaneViewState extends ConsumerState<ChatPaneView> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  late final DraftCacheNotifier _draftCacheNotifier;
  late final ConversationScrollMemoryNotifier _scrollMemoryNotifier;
  late final MessagingController _messagingController;
  Timer? _typingTimer;
  Timer? _typingStartTimer;
  Timer? _hydrationTimer;
  bool _isTyping = false;
  bool _didAutoScrollInitialLoad = false;
  bool _allowEmptyState = false;
  bool _hydrationComplete = false;
  late final double? _savedScrollOffset;
  final List<_PendingMessage> _pendingMessages = <_PendingMessage>[];
  late final DateTime _entryTime;

  void _guardAsync(Future<void> future, {required String contextLabel}) {
    unawaited(
      future.catchError((error, stackTrace) {
        AppTelemetry.logAction(
          level: 'error',
          domain: 'messaging',
          action: 'guarded_async_failure',
          message: 'Guarded async operation failed in chat pane.',
          roomId: widget.conversationId,
          userId: widget.userId,
          metadata: <String, Object?>{'context': contextLabel},
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  void _startHydrationWindow() {
    _hydrationTimer?.cancel();
    _hydrationTimer = null;
    _allowEmptyState = false;
    _hydrationComplete = false;
    SystemEventBus.instance.emit(
      SystemEvent(
        type: 'HYDRATION_START',
        timestamp: DateTime.now(),
        meta: <String, dynamic>{'conversationId': widget.conversationId},
      ),
    );
    _hydrationTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _hydrationTimer = null;
      setState(() {
        _allowEmptyState = true;
      });
    });
  }

  void _markHydrationComplete(String outcome) {
    if (_hydrationComplete) {
      return;
    }
    _hydrationTimer?.cancel();
    _hydrationTimer = null;
    _hydrationComplete = true;
    SystemEventBus.instance.emit(
      SystemEvent(
        type: 'HYDRATION_COMPLETE',
        timestamp: DateTime.now(),
        meta: <String, dynamic>{
          'conversationId': widget.conversationId,
          'outcome': outcome,
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _startHydrationWindow();
    _entryTime = DateTime.now();
    _draftCacheNotifier = ref.read(draftCacheProvider.notifier);
    _scrollMemoryNotifier = ref.read(conversationScrollMemoryProvider.notifier);
    _messagingController = ref.read(messagingControllerProvider);
    final savedDraft = _draftCacheNotifier.getDraft(widget.conversationId);
    _messageController = TextEditingController(text: savedDraft);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
    _savedScrollOffset = ref.read(
      conversationScrollMemoryProvider,
    )[widget.conversationId];

    SystemEventBus.instance.emit(
      SystemEvent(
        type: 'MESSAGE_STREAM_ATTACHED',
        timestamp: DateTime.now(),
        meta: <String, dynamic>{'conversationId': widget.conversationId},
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guardAsync(
        _messagingController.markAsRead(
          conversationId: widget.conversationId,
          userId: widget.userId,
        ),
        contextLabel: 'mark_as_read_on_open',
      );
    });
  }

  @override
  void didUpdateWidget(covariant ChatPaneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _didAutoScrollInitialLoad = false;
      _startHydrationWindow();
    }
  }

  void _onTextChanged() {
    // Persist draft on every keystroke so tab switches don't lose it.
    _draftCacheNotifier.setDraft(
      widget.conversationId,
      _messageController.text,
    );
    if (_messageController.text.isEmpty) {
      _typingStartTimer?.cancel();
      _clearTyping();
      return;
    }
    if (!_isTyping) {
      // Debounce the "start typing" write by 350 ms — avoids one Firestore
      // write per keypress for fast typists hitting the field for the first time.
      _typingStartTimer?.cancel();
      _typingStartTimer = Timer(const Duration(milliseconds: 350), () {
        if (!_isTyping && mounted) {
          _isTyping = true;
          _guardAsync(
            _messagingController.updateTypingStatus(
              conversationId: widget.conversationId,
              userId: widget.userId,
              isTyping: true,
            ),
            contextLabel: 'typing_start',
          );
        }
      });
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), _clearTyping);
  }

  void _clearTyping() {
    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      _guardAsync(
        _messagingController.updateTypingStatus(
          conversationId: widget.conversationId,
          userId: widget.userId,
          isTyping: false,
        ),
        contextLabel: 'typing_stop',
      );
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.offset <=
            _scrollController.position.minScrollExtent + 120) {
      ref
          .read(paginatedMessageProvider(widget.conversationId).notifier)
          .loadMore(null);
    }
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions) {
      _scrollMemoryNotifier.setOffset(
        widget.conversationId,
        _scrollController.offset,
      );
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return true;
    }

    final distanceFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    return distanceFromBottom <= 96;
  }

  void _scheduleScrollToBottom({
    required Duration duration,
    Curve curve = Curves.easeOut,
    bool force = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && !_isNearBottom()) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: duration,
        curve: curve,
      );
    });
  }

  @override
  void dispose() {
    final duration = DateTime.now().difference(_entryTime);
    AppTelemetry.logAction(
      domain: 'messaging',
      action: 'chat_session_duration',
      message: 'User left the chat pane.',
      userId: widget.userId,
      metadata: {
        'conversationId': widget.conversationId,
        'durationSeconds': duration.inSeconds,
      },
    );
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions) {
      _scrollMemoryNotifier.setOffset(
        widget.conversationId,
        _scrollController.offset,
      );
    }
    // Safety-net: persist any unsent draft that wasn't saved via _onTextChanged.
    final remainingDraft = _messageController.text;
    _draftCacheNotifier.setDraft(widget.conversationId, remainingDraft);
    _clearTyping();
    _typingTimer?.cancel();
    _typingStartTimer?.cancel();
    _hydrationTimer?.cancel();
    SystemEventBus.instance.emit(
      SystemEvent(
        type: 'MESSAGE_STREAM_DISPOSE',
        timestamp: DateTime.now(),
        meta: <String, dynamic>{'conversationId': widget.conversationId},
      ),
    );
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final allowed = await GuestAuthGate.requireMessaging(context, ref);
    if (!allowed) return;

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _clearTyping();
    // Clear draft — message is being sent.
    _draftCacheNotifier.clearDraft(widget.conversationId);
    _messageController.clear();

    final pendingMessage = _PendingMessage(
      clientMessageId:
          '${DateTime.now().microsecondsSinceEpoch}-${widget.userId}',
      content: content,
      createdAt: DateTime.now(),
      senderId: widget.userId,
      senderName: widget.username,
      senderAvatarUrl: widget.avatarUrl,
    );
    setState(() {
      _pendingMessages.add(pendingMessage);
    });

    _scheduleScrollToBottom(
      duration: const Duration(milliseconds: 180),
      force: true,
    );

    try {
      await _messagingController.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.userId,
        senderName: widget.username,
        senderAvatarUrl: widget.avatarUrl,
        content: content,
        clientMessageId: pendingMessage.clientMessageId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere(
          (message) =>
              message.clientMessageId == pendingMessage.clientMessageId,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $error')));
      return;
    }

    _scheduleScrollToBottom(
      duration: const Duration(milliseconds: 300),
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageStream = ref.watch(
      messageStreamProvider(widget.conversationId),
    );
    final paginatedState = ref.watch(
      paginatedMessageProvider(widget.conversationId),
    );
    final conversationAsync = ref.watch(
      conversationDocProvider(widget.conversationId),
    );
    if (conversationAsync.hasError) {
      _markHydrationComplete('conversation_error');
      return AppErrorView(
        error: friendlyFirestoreMessage(
          conversationAsync.error!,
          fallbackContext: 'conversation',
        ),
        fallbackContext: 'Unable to load conversation.',
      );
    }

    if (conversationAsync.isLoading && !_allowEmptyState) {
      return const AppLoadingView(label: 'Connecting conversation');
    }

    final conversation = conversationAsync.valueOrNull;
    if (conversation == null) {
      if (!_allowEmptyState) {
        return const AppLoadingView(label: 'Hydrating conversation');
      }
      _markHydrationComplete('conversation_unavailable');
      SystemEventBus.instance.emit(
        SystemEvent(
          type: 'HYDRATION_EMPTY_STATE',
          timestamp: DateTime.now(),
          meta: <String, dynamic>{
            'conversationId': widget.conversationId,
            'reason': 'conversation_unavailable',
          },
        ),
      );
      return const AppEmptyView(
        title: 'Conversation unavailable',
        message:
            'This thread may have been removed or access is no longer available.',
        icon: Icons.forum_outlined,
      );
    }

    final otherUserId = conversation.participantIds.firstWhere(
      (participantId) => participantId != widget.userId,
      orElse: () => '',
    );
    final otherUserAsync = otherUserId.isEmpty
        ? const AsyncValue<UserModel?>.data(null)
        : ref.watch(feed_user.userProvider(otherUserId));
    final displayName = conversation.type == 'group'
        ? (conversation.groupName ?? 'Group Chat')
        : (conversation.getDisplayName(widget.userId).trim().isNotEmpty
              ? conversation.getDisplayName(widget.userId)
              : (otherUserAsync.valueOrNull?.username ?? 'Conversation'));
    final peerUser = otherUserAsync.valueOrNull;
    final displayAvatarUrl = sanitizeNetworkImageUrl(
      conversation.type == 'group'
          ? conversation.groupAvatarUrl
          : peerUser?.avatarUrl,
    );

    return Column(
      children: [
        if (widget.showHeader)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              24,
              context.pageHorizontalPadding,
              12,
            ),
            child: Row(
              children: [
                SafeNetworkAvatar(
                  radius: 22,
                  avatarUrl: displayAvatarUrl,
                  backgroundColor: VelvetNoir.primaryDim,
                  fallbackText: displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : '?',
                  fallbackTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: VelvetNoir.onSurface,
                    ),
                  ),
                ),
                if (kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Pop out',
                    onPressed: () => WebPopoutService().openWhisperWindow(
                      otherUserId,
                      displayName,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: messageStream.when(
            data: (liveMessages) {
              final pendingClientIds = _pendingMessages
                  .map((message) => message.clientMessageId)
                  .toSet();
              final liveClientIds = liveMessages
                  .map((message) => message.clientMessageId)
                  .whereType<String>()
                  .toSet();
              final pendingMessages = _pendingMessages
                  .where(
                    (message) =>
                        !liveClientIds.contains(message.clientMessageId),
                  )
                  .toList(growable: false);
              final allMessages = [
                ...paginatedState.olderMessages,
                ...liveMessages,
                ...pendingMessages.map(
                  (message) => message.toMessage(widget.conversationId),
                ),
              ];

              if (_pendingMessages.length != pendingMessages.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _pendingMessages
                      ..clear()
                      ..addAll(pendingMessages);
                  });
                });
              }

              if (!_didAutoScrollInitialLoad) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_scrollController.hasClients) return;
                  final targetOffset = _savedScrollOffset == null
                      ? _scrollController.position.maxScrollExtent
                      : _savedScrollOffset.clamp(
                          _scrollController.position.minScrollExtent,
                          _scrollController.position.maxScrollExtent,
                        );
                  _scrollController.jumpTo(targetOffset.toDouble());
                  _didAutoScrollInitialLoad = true;
                });
              } else {
                _scheduleScrollToBottom(
                  duration: const Duration(milliseconds: 160),
                );
              }

              if (allMessages.isEmpty) {
                if (!_allowEmptyState) {
                  return const AppLoadingView(label: 'Hydrating conversation');
                }
                _markHydrationComplete('no_messages');
                SystemEventBus.instance.emit(
                  SystemEvent(
                    type: 'HYDRATION_EMPTY_STATE',
                    timestamp: DateTime.now(),
                    meta: <String, dynamic>{
                      'conversationId': widget.conversationId,
                      'reason': 'no_messages',
                    },
                  ),
                );
                return const AppEmptyView(
                  title: 'No messages yet',
                  message: 'Start the conversation.',
                  icon: Icons.chat_bubble_outline_rounded,
                );
              }

              _markHydrationComplete('data');

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: allMessages.length + (paginatedState.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0 && paginatedState.hasMore) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: paginatedState.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: () => ref
                                    .read(
                                      paginatedMessageProvider(
                                        widget.conversationId,
                                      ).notifier,
                                    )
                                    .loadMore(null),
                                child: const Text('Load older message'),
                              ),
                      ),
                    );
                  }

                  final message =
                      allMessages[index - (paginatedState.hasMore ? 1 : 0)];
                  final isOwn = message.senderId == widget.userId;
                  final isPending = pendingClientIds.contains(
                    message.clientMessageId,
                  );
                  bool isReadByOther = false;
                  if (isOwn) {
                    final otherIds = conversation.participantIds.where(
                      (id) => id != widget.userId,
                    );
                    isReadByOther = otherIds.any((id) {
                      final readAt = conversation.lastReadAt[id];
                      return readAt != null &&
                          !readAt.isBefore(message.createdAt);
                    });
                  }

                  if (message.isDeleted) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'message deleted',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    );
                  }

                  return Align(
                    alignment: isOwn
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isOwn) ...[
                            SafeNetworkAvatar(
                              radius: 14,
                              avatarUrl: message.senderAvatarUrl,
                              backgroundColor: VelvetNoir.primaryDim,
                              fallbackText: message.senderName.isNotEmpty
                                  ? message.senderName[0].toUpperCase()
                                  : '?',
                              fallbackTextStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isOwn
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onLongPress: () => _showReactionPicker(
                                    context,
                                    ref,
                                    message.id,
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.72,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isOwn
                                          ? const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                VelvetNoir.primary,
                                                VelvetNoir.primaryDim,
                                              ],
                                            )
                                          : null,
                                      color: isOwn
                                          ? null
                                          : VelvetNoir.surfaceHigh,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: Radius.circular(
                                          isOwn ? 18 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isOwn ? 4 : 18,
                                        ),
                                      ),
                                      border: isOwn
                                          ? null
                                          : Border.all(
                                              color: VelvetNoir.outlineVariant
                                                  .withValues(alpha: 0.4),
                                              width: 1,
                                            ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isOwn
                                              ? VelvetNoir.primaryDim
                                                    .withValues(alpha: 0.25)
                                              : Colors.black.withValues(
                                                  alpha: 0.15,
                                                ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!isOwn) ...[
                                          Text(
                                            message.senderName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: VelvetNoir.secondary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                        ],
                                        EmojimessageContent(
                                          content: message.content,
                                          isOwn: isOwn,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _ReactionRow(
                                  conversationId: widget.conversationId,
                                  messageId: message.id,
                                  currentUserId: widget.userId,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 3,
                                    left: 4,
                                    right: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(message.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: VelvetNoir.onSurfaceVariant,
                                        ),
                                      ),
                                      if (isOwn) ...[
                                        const SizedBox(width: 4),
                                        Tooltip(
                                          message: _deliveryStateLabel(
                                            isPending: isPending,
                                            isReadByOther: isReadByOther,
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            transitionBuilder:
                                                (child, animation) {
                                                  return FadeTransition(
                                                    opacity: animation,
                                                    child: ScaleTransition(
                                                      scale: Tween<double>(
                                                        begin: 0.85,
                                                        end: 1,
                                                      ).animate(animation),
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                            child: Icon(
                                              _deliveryStateIcon(
                                                isPending: isPending,
                                                isReadByOther: isReadByOther,
                                              ),
                                              key: ValueKey<String>(
                                                _deliveryStateLabel(
                                                  isPending: isPending,
                                                  isReadByOther: isReadByOther,
                                                ),
                                              ),
                                              size: 13,
                                              color: _deliveryStateColor(
                                                isPending: isPending,
                                                isReadByOther: isReadByOther,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isOwn) const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () {
              if (_pendingMessages.isNotEmpty) {
                return _buildPendingWhileLoading();
              }
              return const AppLoadingView(label: 'Loading message');
            },
            skipLoadingOnRefresh: true,
            error: (error, stackTrace) => AppErrorView(
              error: friendlyFirestoreMessage(
                error,
                fallbackContext: 'message',
              ),
              fallbackContext: 'Unable to load message.',
            ),
          ),
        ),
        _TypingIndicatorRow(
          conversationId: widget.conversationId,
          currentUserId: widget.userId,
          otherUsername: displayName,
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: context.pageHorizontalPadding,
            right: context.pageHorizontalPadding,
            top: 8,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: VelvetNoir.surfaceHigh,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: VelvetNoir.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: VelvetNoir.onSurfaceVariant,
                  ),
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    final allowed = await GuestAuthGate.requireMessaging(
                      context,
                      ref,
                    );
                    if (!allowed) return;
                    if (!mounted) return;
                    final messagingController = ref.read(
                      messagingControllerProvider,
                    );
                    await EmojiPackPicker.show(
                      // ignore: use_build_context_synchronously
                      context,
                      ref,
                      onSelected: (item) async {
                        try {
                          await messagingController.sendMessage(
                            conversationId: widget.conversationId,
                            senderId: widget.userId,
                            senderName: widget.username,
                            senderAvatarUrl: widget.avatarUrl,
                            content: item.messageContent,
                          );
                        } catch (error, stackTrace) {
                          AppTelemetry.logAction(
                            level: 'error',
                            domain: 'messaging',
                            action: 'emoji_send_failed',
                            message: 'Emoji message send failed.',
                            roomId: widget.conversationId,
                            userId: widget.userId,
                            error: error,
                            stackTrace: stackTrace,
                          );
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text('Could not send message: $error'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'message…',
                      hintStyle: TextStyle(color: VelvetNoir.onSurfaceVariant),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(
                      color: VelvetNoir.onSurface,
                      fontSize: 14,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      gradient: VelvetNoir.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPendingWhileLoading() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _pendingMessages.length,
      itemBuilder: (context, index) {
        final pending = _pendingMessages[index];
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [VelvetNoir.primary, VelvetNoir.primaryDim],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojimessageContent(content: pending.content, isOwn: true),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: _deliveryStateLabel(
                      isPending: true,
                      isReadByOther: false,
                    ),
                    child: Icon(
                      _deliveryStateIcon(isPending: true, isReadByOther: false),
                      size: 13,
                      color: _deliveryStateColor(
                        isPending: true,
                        isReadByOther: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  IconData _deliveryStateIcon({
    required bool isPending,
    required bool isReadByOther,
  }) {
    if (isPending) {
      return Icons.schedule_rounded;
    }
    if (isReadByOther) {
      return Icons.done_all;
    }
    return Icons.done;
  }

  Color _deliveryStateColor({
    required bool isPending,
    required bool isReadByOther,
  }) {
    if (isPending) {
      return VelvetNoir.primary;
    }
    if (isReadByOther) {
      return VelvetNoir.secondary;
    }
    return VelvetNoir.onSurfaceVariant;
  }

  String _deliveryStateLabel({
    required bool isPending,
    required bool isReadByOther,
  }) {
    if (isPending) {
      return 'Sending';
    }
    if (isReadByOther) {
      return 'Seen';
    }
    return 'Delivered';
  }

  void _showReactionPicker(
    BuildContext context,
    WidgetRef ref,
    String messageId,
  ) {
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '👎'];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: emojis
                .map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _guardAsync(
                        ref
                            .read(messagingControllerProvider)
                            .toggleReaction(
                              conversationId: widget.conversationId,
                              messageId: messageId,
                              currentUserId: widget.userId,
                              emoji: emoji,
                            ),
                        contextLabel: 'toggle_reaction',
                      );
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicatorRow extends ConsumerWidget {
  const _TypingIndicatorRow({
    required this.conversationId,
    required this.currentUserId,
    required this.otherUsername,
  });

  final String conversationId;
  final String currentUserId;
  final String otherUsername;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingAsync = ref.watch(typingUsersProvider(conversationId));
    return typingAsync.when(
      data: (ids) {
        final othersTyping = ids.any((id) => id != currentUserId);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
            );
          },
          child: !othersTyping
              ? const SizedBox.shrink(key: ValueKey<String>('typing-hidden'))
              : Padding(
                  key: const ValueKey<String>('typing-visible'),
                  padding: const EdgeInsets.only(left: 20, bottom: 2),
                  child: Row(
                    children: [
                      _BouncingDots(),
                      const SizedBox(width: 6),
                      Text(
                        '$otherUsername is typing…',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final dy = -3.0 * (offset < 0.5 ? offset : 1.0 - offset) * 2;
            return Transform.translate(
              offset: Offset(0, dy),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 1.5),
                child: CircleAvatar(radius: 3, backgroundColor: Colors.grey),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ReactionRow extends ConsumerWidget {
  const _ReactionRow({
    required this.conversationId,
    required this.messageId,
    required this.currentUserId,
  });

  final String conversationId;
  final String messageId;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactionsAsync = ref.watch(
      messageReactionsProvider((
        conversationId: conversationId,
        messageId: messageId,
      )),
    );
    return reactionsAsync.when(
      data: (reactions) {
        if (reactions.isEmpty) return const SizedBox.shrink();
        final counts = <String, int>{};
        for (final emoji in reactions.values) {
          counts[emoji] = (counts[emoji] ?? 0) + 1;
        }
        return Padding(
          padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
          child: Wrap(
            spacing: 4,
            children: counts.entries
                .map((e) {
                  final myReaction = reactions[currentUserId] == e.key;
                  return GestureDetector(
                    onTap: () => ref
                        .read(messagingControllerProvider)
                        .toggleReaction(
                          conversationId: conversationId,
                          messageId: messageId,
                          currentUserId: currentUserId,
                          emoji: e.key,
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: myReaction
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        border: myReaction
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1,
                              )
                            : null,
                      ),
                      child: Text(
                        '${e.key} ${e.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PendingMessage {
  const _PendingMessage({
    required this.clientMessageId,
    required this.content,
    required this.createdAt,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
  });

  final String clientMessageId;
  final String content;
  final DateTime createdAt;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;

  MessageModel toMessage(String conversationId) {
    return MessageModel(
      id: clientMessageId,
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      content: content,
      createdAt: createdAt,
      isDeleted: false,
      readBy: [senderId],
    );
  }
}
