import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/theme.dart';
import '../../../models/presence_model.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../widgets/safe_network_avatar.dart';
import '../models/conversation_model.dart';
import '../providers/messaging_provider.dart';

class MessagesPaneView extends ConsumerStatefulWidget {
  const MessagesPaneView({
    super.key,
    required this.userId,
    required this.username,
    this.showHeader = true,
  });

  final String userId;
  final String username;
  final bool showHeader;

  @override
  ConsumerState<MessagesPaneView> createState() => _MessagesPaneViewState();
}

class _MessagesPaneViewState extends ConsumerState<MessagesPaneView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _filterAll(List<Conversation> convs) =>
      convs.where((c) => c.status == 'active').toList();

  List<Conversation> _filterUnread(List<Conversation> convs) => convs
      .where((c) => c.status == 'active' && c.hasUnreadMessages(widget.userId))
      .toList();

  List<Conversation> _filterGroups(List<Conversation> convs) =>
      convs.where((c) => c.status == 'active' && c.type == 'group').toList();

  List<Conversation> _applySearch(List<Conversation> convs) {
    if (_query.isEmpty) return convs;
    return convs.where((c) {
      final name = c.getDisplayName(widget.userId).toLowerCase();
      final preview = (c.lastMessagePreview ?? '').toLowerCase();
      return name.contains(_query) || preview.contains(_query);
    }).toList();
  }

  void _showRequestsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetNoir.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MessageRequestsSheet(
        userId: widget.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(
      conversationsStreamProvider(widget.userId),
    );
    final requestsAsync = ref.watch(requestsStreamProvider(widget.userId));
    final requestCount = requestsAsync.valueOrNull?.length ?? 0;

    return Column(
      children: [
        if (widget.showHeader)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              24,
              context.pageHorizontalPadding,
              16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inbox',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: VelvetNoir.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Desktop keeps message inside the center pane.',
                        style: GoogleFonts.raleway(
                          color: VelvetNoir.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/messages/new'),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('New message'),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pageHorizontalPadding,
            8,
            context.pageHorizontalPadding,
            8,
          ),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: VelvetNoir.surfaceHigh.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: VelvetNoir.outlineVariant.withValues(alpha: 0.28),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search conversations',
                hintStyle: GoogleFonts.raleway(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: VelvetNoir.onSurfaceVariant,
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                        onPressed: _searchController.clear,
                        padding: EdgeInsets.zero,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        if (requestCount > 0)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              0,
              context.pageHorizontalPadding,
              8,
            ),
            child: InkWell(
              onTap: () => _showRequestsSheet(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: VelvetNoir.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: VelvetNoir.secondary.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: VelvetNoir.secondaryBright,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$requestCount request${requestCount > 1 ? 's' : ''}',
                      style: GoogleFonts.raleway(
                        color: VelvetNoir.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Review pending conversations',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.raleway(
                          color: VelvetNoir.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: VelvetNoir.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pageHorizontalPadding,
            0,
            context.pageHorizontalPadding,
            8,
          ),
          child: Container(
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: VelvetNoir.surfaceHigh.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: VelvetNoir.outlineVariant.withValues(alpha: 0.24),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: VelvetNoir.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VelvetNoir.primary.withValues(alpha: 0.22),
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: VelvetNoir.onSurface,
              unselectedLabelColor: VelvetNoir.onSurfaceVariant,
              labelStyle: GoogleFonts.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              splashBorderRadius: BorderRadius.circular(12),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
                Tab(text: 'Groups'),
              ],
            ),
          ),
        ),
        Expanded(
          child: AppAsyncValueView<List<Conversation>>(
            value: conversationsAsync,
            fallbackContext: 'conversations',
            data: (conversations) => TabBarView(
              controller: _tabController,
              children: [
                _ConversationsList(
                  conversations: _applySearch(_filterAll(conversations)),
                  userId: widget.userId,
                  emptyMessage: _query.isNotEmpty
                      ? 'No results for "$_query"'
                      : 'No conversations yet',
                ),
                _ConversationsList(
                  conversations: _applySearch(_filterUnread(conversations)),
                  userId: widget.userId,
                  emptyMessage: 'No unread messages',
                ),
                _ConversationsList(
                  conversations: _applySearch(_filterGroups(conversations)),
                  userId: widget.userId,
                  emptyMessage: 'No group chats yet',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MessageRequestsSheet extends ConsumerWidget {
  const MessageRequestsSheet({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(requestsStreamProvider(userId));
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Message Requests',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: VelvetNoir.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: VelvetNoir.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: VelvetNoir.outlineVariant.withValues(alpha: 0.3),
            ),
            Expanded(
              child: AppAsyncValueView<List<Conversation>>(
                value: requestsAsync,
                fallbackContext: 'message requests',
                isEmpty: (requests) => requests.isEmpty,
                empty: const AppEmptyView(
                  icon: Icons.mark_email_read_outlined,
                  title: 'No pending message requests.',
                ),
                data: (requests) {
                  return ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (__, _) => Divider(
                      height: 1,
                      indent: 72,
                      color: VelvetNoir.outlineVariant.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      final conversation = requests[index];
                      final displayName = conversation.getDisplayName(userId);
                      return ListTile(
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/messages/chat/${conversation.id}');
                        },
                        leading: CircleAvatar(
                          backgroundColor: VelvetNoir.surfaceHigh,
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: VelvetNoir.primary),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(color: VelvetNoir.onSurface),
                        ),
                        subtitle: Text(
                          conversation.lastMessagePreview ??
                              'New message request',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: VelvetNoir.onSurfaceVariant,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref
                                .read(messagingControllerProvider)
                                .acceptMessageRequest(
                                  conversationId: conversation.id,
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              context.go('/messages/chat/${conversation.id}');
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: VelvetNoir.primary,
                          ),
                          child: const Text('Accept'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _otherParticipantIdForConversation(
  Conversation conversation,
  String userId,
) {
  if (conversation.type == 'group') {
    return null;
  }
  final peer = conversation.participantIds.firstWhere(
    (id) => id != userId,
    orElse: () => '',
  );
  return peer.isEmpty ? null : peer;
}

class _ConversationsList extends ConsumerWidget {
  const _ConversationsList({
    required this.conversations,
    required this.userId,
    required this.emptyMessage,
  });

  final List<Conversation> conversations;
  final String userId;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (conversations.isEmpty) {
      return Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: VelvetNoir.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 56,
                color: VelvetNoir.primary.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/messages/new'),
                child: Text(
                  'Start a conversation',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visiblePeerIds = conversations
        .map(
          (conversation) =>
              _otherParticipantIdForConversation(conversation, userId),
        )
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final presenceBatchKey = buildPresenceBatchKey(visiblePeerIds);
    final presenceMap =
        ref.watch(batchedPresenceProvider(presenceBatchKey)).valueOrNull ??
            const <String, PresenceModel>{};

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: conversations.length,
      separatorBuilder: (_, index) {
        final currentPinned = conversations[index].isPinnedFor(userId);
        final nextPinned = conversations[index + 1].isPinnedFor(userId);
        if (currentPinned && !nextPinned) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              indent: 16,
              endIndent: 16,
              height: 1,
              color: VelvetNoir.primary.withValues(alpha: 0.28),
            ),
          );
        }
        return const Divider(indent: 52, height: 1, color: Color(0x18F7EDE2));
      },
      itemBuilder: (context, index) => _ConversationTile(
        conversation: conversations[index],
        userId: userId,
        peerPresence: presenceMap[_otherParticipantIdForConversation(
          conversations[index],
          userId,
        )],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.userId,
    required this.peerPresence,
  });

  final Conversation conversation;
  final String userId;
  final PresenceModel? peerPresence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = conversation.hasUnreadMessages(userId);
    final pinned = conversation.isPinnedFor(userId);
    final displayName = conversation.getDisplayName(userId);
    final avatarUrl = conversation.groupAvatarUrl;
    final previewText = conversation.lastMessagePreview ?? 'No message yet';
    final isGroup = conversation.type == 'group';
    final peerUserId = _otherParticipantId();
    final typingUsers =
        ref.watch(typingUsersProvider(conversation.id)).valueOrNull ??
            const <String>{};
    final isPeerTyping = peerUserId != null && typingUsers.contains(peerUserId);
    final resolvedPresence = isGroup ? null : peerPresence;
    final presenceColor = _presenceColor(resolvedPresence);
    final hasPresenceSignal = presenceColor != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/messages/chat/${conversation.id}'),
        onLongPress: () => _showActionSheet(context, ref),
        child: Container(
          color: unread
              ? VelvetNoir.secondary.withValues(alpha: 0.08)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar with presence ring + unread badge ──────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasPresenceSignal
                            ? presenceColor
                            : Colors.transparent,
                        width: 1.8,
                      ),
                      boxShadow: hasPresenceSignal
                          ? [
                              BoxShadow(
                                color: presenceColor.withValues(alpha: 0.28),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: SafeNetworkAvatar(
                      radius: 20,
                      avatarUrl: avatarUrl,
                      backgroundColor: isGroup
                          ? VelvetNoir.secondary.withValues(alpha: 0.18)
                          : VelvetNoir.primaryDim,
                      fallbackText: displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      fallbackTextStyle: const TextStyle(
                        color: VelvetNoir.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (unread)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: VelvetNoir.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: VelvetNoir.surface,
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.notifications_active_rounded,
                            size: 9,
                            color: VelvetNoir.surface,
                          ),
                        ),
                      ),
                    ),
                  if (pinned)
                    Positioned(
                      left: -2,
                      bottom: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: VelvetNoir.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: VelvetNoir.surface,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.push_pin_rounded,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (hasPresenceSignal) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: presenceColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.raleway(
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 14,
                              color: VelvetNoir.onSurface,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(conversation.lastMessageAt),
                          style: GoogleFonts.raleway(
                            fontSize: 11,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                            color: unread
                                ? VelvetNoir.primary
                                : VelvetNoir.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isGroup)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: VelvetNoir.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'G',
                              style: GoogleFonts.raleway(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: VelvetNoir.secondaryBright,
                              ),
                            ),
                          ),
                        Expanded(
                          child: isPeerTyping
                              ? Row(
                                  children: [
                                    Text(
                                      'Typing',
                                      style: GoogleFonts.raleway(
                                        fontSize: 12,
                                        color: const Color(0xFF22C55E),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const _TypingDots(),
                                  ],
                                )
                              : Text(
                                  previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.raleway(
                                    fontSize: 12,
                                    height: 1.2,
                                    color: unread
                                        ? VelvetNoir.onSurface
                                        : VelvetNoir.onSurfaceVariant,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetNoir.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ConversationActionSheet(conversation: conversation, userId: userId),
    );
  }

  String? _otherParticipantId() {
    for (final id in conversation.participantIds) {
      if (id != userId) return id;
    }
    return null;
  }

  Color? _presenceColor(PresenceModel? presence) {
    if (presence == null) return null;
    if ((presence.inRoom ?? '').isNotEmpty) return VelvetNoir.secondaryBright;
    if (presence.isOnline == true) return const Color(0xFF22C55E);
    final lastSeen = presence.lastSeen;
    if (lastSeen == null) return null;
    final isRecentlyActive = DateTime.now().difference(lastSeen).inMinutes < 10;
    return isRecentlyActive ? const Color(0xFF86EFAC) : null;
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.month}/${dateTime.day}';
  }
}

class _ConversationActionSheet extends ConsumerWidget {
  const _ConversationActionSheet({
    required this.conversation,
    required this.userId,
  });

  final Conversation conversation;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = conversation.isPinnedFor(userId);
    final displayName = conversation.getDisplayName(userId);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: VelvetNoir.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              displayName,
              style: const TextStyle(
                color: VelvetNoir.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(color: VelvetNoir.outlineVariant, height: 1),
          ListTile(
            leading: Icon(
              pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: VelvetNoir.primary,
            ),
            title: Text(
              pinned ? 'Unpin conversation' : 'Pin conversation',
              style: const TextStyle(color: VelvetNoir.onSurface, fontSize: 15),
            ),
            onTap: () {
              ref.read(messagingControllerProvider).setConversationPinned(
                    conversationId: conversation.id,
                    userId: userId,
                    pinned: !pinned,
                  );
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.archive_outlined,
              color: VelvetNoir.primary,
            ),
            title: const Text(
              'Archive conversation',
              style: TextStyle(color: VelvetNoir.onSurface, fontSize: 15),
            ),
            onTap: () {
              // Archive action
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: VelvetNoir.error),
            title: const Text(
              'Delete conversation',
              style: TextStyle(color: VelvetNoir.error, fontSize: 15),
            ),
            onTap: () {
              // Delete with confirmation
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = (_controller.value * 3).floor() % 3;
        final dots = '.' * (phase + 1);
        return Text(
          dots,
          style: GoogleFonts.raleway(
            fontSize: 12,
            color: const Color(0xFF22C55E),
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }
}
