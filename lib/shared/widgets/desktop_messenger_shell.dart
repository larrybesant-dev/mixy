
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme.dart';
import '../../core/utils/network_image_url.dart';
import '../../features/friends/models/friend_roster_entry.dart';
import '../../features/friends/providers/friends_providers.dart';
import '../../features/messaging/models/conversation_model.dart';
import '../../features/messaging/providers/messaging_provider.dart';
import '../../widgets/safe_network_avatar.dart';
import 'messenger_shell_route.dart';
import '../../models/presence_model.dart';
import '../../models/user_model.dart';
import '../../presentation/providers/user_provider.dart';
import '../../services/moderation_service.dart';
import '../../services/notification_service.dart';

class DesktopMessengerShell extends ConsumerStatefulWidget {
  const DesktopMessengerShell({
    required this.routeState,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    super.key,
  });

  final MessengerRouteState routeState;
  final String userId;
  final String username;
  final String? avatarUrl;

  @override
  ConsumerState<DesktopMessengerShell> createState() => _DesktopMessengerShellState();
}

class _DesktopMessengerShellState extends ConsumerState<DesktopMessengerShell> {
  late final TextEditingController _searchController;
  String _query = '';
  bool _showOffline = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final isFriendsRoute = widget.routeState.kind == MessengerRouteKind.friends;
    final centerPane = buildMessengerRouteChild(
      routeState: widget.routeState,
      userId: widget.userId,
      username: widget.username,
      avatarUrl: widget.avatarUrl,
    );
    if (currentUser == null) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: VelvetNoir.surface),
        child: SafeArea(child: centerPane),
      );
    }

    final controller = _MessengerSidebarController(
      messagingController: ref.read(messagingControllerProvider),
      moderationService: ModerationService(),
      notificationService: NotificationService(),
    );
    final railWidth = context.screenWidth >= AppBreakpoints.expanded ? 288.0 : 256.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VelvetNoir.surface,
            VelvetNoir.surfaceLow,
            VelvetNoir.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              if (!isFriendsRoute) ...[
                SizedBox(
                  width: 320,
                  child: _ShellPanel(
                    child: _MessengerSidebar(
                      currentUser: currentUser,
                      controller: controller,
                      searchController: _searchController,
                      routeState: widget.routeState,
                      query: _query,
                      showOffline: _showOffline,
                      onToggleOffline: () => setState(() => _showOffline = !_showOffline),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _ShellPanel(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          VelvetNoir.surface.withValues(alpha: 0.95),
                          VelvetNoir.surfaceLow.withValues(alpha: 0.94),
                        ],
                      ),
                    ),
                    child: centerPane,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: railWidth,
                child: _ShellPanel(
                  child: _DesktopSocialRail(currentUser: currentUser),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellPanel extends StatelessWidget {
  const _ShellPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh.withValues(alpha: 0.62),
          border: Border.all(
            color: VelvetNoir.outlineVariant.withValues(alpha: 0.32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _MessengerSidebar extends ConsumerWidget {
  const _MessengerSidebar({
    required this.currentUser,
    required this.controller,
    required this.searchController,
    required this.routeState,
    required this.query,
    required this.showOffline,
    required this.onToggleOffline,
  });

  final UserModel currentUser;
  final _MessengerSidebarController controller;
  final TextEditingController searchController;
  final MessengerRouteState routeState;
  final String query;
  final bool showOffline;
  final VoidCallback onToggleOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(friendRosterProvider).valueOrNull ?? const <FriendRosterEntry>[];
    final conversations = ref.watch(conversationsStreamProvider(currentUser.id)).valueOrNull ?? const <Conversation>[];
    final favoriteIds = ref.watch(favoriteFriendIdsProvider).valueOrNull ?? const <String>{};
    final currentRoomId = ref.watch(currentUserPresenceProvider).valueOrNull?.inRoom;
    final selectedConversationId = routeState.conversationId;

    final recentConversations = conversations.where((conversation) {
      if (conversation.type != 'direct') return false;
      if (query.isEmpty) return true;
      final displayName = conversation.getDisplayName(currentUser.id).toLowerCase();
      final preview = (conversation.lastMessagePreview ?? '').toLowerCase();
      return displayName.contains(query) || preview.contains(query);
    }).toList(growable: false)
      ..sort((left, right) {
        final leftPinned = left.isPinnedFor(currentUser.id);
        final rightPinned = right.isPinnedFor(currentUser.id);
        if (leftPinned != rightPinned) {
          return leftPinned ? -1 : 1;
        }
        return (right.lastMessageAt ?? right.createdAt)
          .compareTo(left.lastMessageAt ?? left.createdAt);
      });

    final filteredRoster = roster.where((entry) {
      if (query.isEmpty) return true;
      final conversation = _directConversationForFriend(conversations, currentUser.id, entry.friendId);
      final preview = (conversation?.lastMessagePreview ?? '').toLowerCase();
      return entry.user.username.toLowerCase().contains(query) || preview.contains(query);
    }).toList(growable: false)
      ..sort(_compareRosterEntries);

    final favorites = filteredRoster.where((entry) => favoriteIds.contains(entry.friendId)).toList(growable: false);
    final online = filteredRoster.where((entry) => !favoriteIds.contains(entry.friendId) && entry.isOnline).toList(growable: false);
    final offline = filteredRoster.where((entry) => !favoriteIds.contains(entry.friendId) && !entry.isOnline).toList(growable: false);

    Widget friendList(List<FriendRosterEntry> entries) => Column(
          children: entries.map((entry) {
            final conversation = _directConversationForFriend(conversations, currentUser.id, entry.friendId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FriendRosterRow(
                entry: entry,
                conversation: conversation,
                unread: conversation?.hasUnreadmessage(currentUser.id) ?? false,
                canInviteToRoom: currentRoomId != null && currentRoomId.isNotEmpty && currentRoomId != entry.roomId,
                onOpenChat: () => _openConversation(context, currentUser, entry.user, conversation),
                onViewProfile: () => context.go('/profile/${entry.user.id}'),
                onInviteToRoom: currentRoomId == null || currentRoomId.isEmpty
                    ? null
                    : () => _inviteToRoom(context, currentUser, entry.user, currentRoomId),
                onBlockUser: () => _blockUser(context, entry.user),
              ),
            );
          }).toList(growable: false),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceLow,
        border: Border(right: BorderSide(color: VelvetNoir.outlineVariant.withValues(alpha: 0.35))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messenger', style: GoogleFonts.playfairDisplay(color: VelvetNoir.primary, fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('See people. Click. Talk.', style: GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  const SizedBox(height: 12),
                  const _SidebarQuickNav(),
                  const SizedBox(height: 16),
                  _SearchField(controller: searchController),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                children: [
                  _SidebarSection(
                    title: 'Recent Conversations',
                    count: recentConversations.length,
                    child: recentConversations.isEmpty
                        ? const _SidebarEmptyState(label: 'Recent chats show up here once you start talking.')
                        : Column(
                            children: recentConversations.map((conversation) {
                              final otherUserId = _directOtherUserId(conversation, currentUser.id);
                              final rosterEntry = _rosterEntryForUserId(roster, otherUserId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _RecentConversationRow(
                                  isSelected: selectedConversationId == conversation.id,
                                  pinned: conversation.isPinnedFor(currentUser.id),
                                  isOnline: rosterEntry?.isOnline ?? false,
                                  displayName: conversation.getDisplayName(currentUser.id),
                                  avatarUrl: rosterEntry == null ? null : sanitizeNetworkImageUrl(rosterEntry.user.avatarUrl),
                                  preview: conversation.lastMessagePreview ?? 'No message yet',
                                  timestamp: conversation.lastMessageAt ?? conversation.createdAt,
                                  unread: conversation.hasUnreadmessage(currentUser.id),
                                  onTogglePin: () => controller.togglePinned(
                                    conversationId: conversation.id,
                                    userId: currentUser.id,
                                    pinned: !conversation.isPinnedFor(currentUser.id),
                                  ),
                                  onTap: () => context.go('/chat/${conversation.id}'),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                  ),
                  _SidebarSection(
                    title: 'Favorites',
                    count: favorites.length,
                    child: favorites.isEmpty ? const _SidebarEmptyState(label: 'No favorite friends yet.') : friendList(favorites),
                  ),
                  _SidebarSection(
                    title: 'Online',
                    count: online.length,
                    child: online.isEmpty ? const _SidebarEmptyState(label: 'Nobody online right now.') : friendList(online),
                  ),
                  _SidebarSection(
                    title: 'Offline',
                    count: offline.length,
                    trailing: TextButton(onPressed: onToggleOffline, child: Text(showOffline ? 'Hide' : 'Show')),
                    child: !showOffline
                        ? const _SidebarEmptyState(label: 'Offline friends collapsed.')
                        : offline.isEmpty
                            ? const _SidebarEmptyState(label: 'No offline friends.')
                            : friendList(offline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openConversation(BuildContext context, UserModel currentUser, UserModel friend, Conversation? conversation) async {
    try {
      final conversationId = await controller.openConversation(currentUser: currentUser, friend: friend, existingConversation: conversation);
      if (context.mounted) context.go('/chat/$conversationId');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open chat: $error')));
    }
  }

  Future<void> _inviteToRoom(BuildContext context, UserModel currentUser, UserModel friend, String roomId) async {
    try {
      await controller.inviteFriendToRoom(currentUser: currentUser, friend: friend, roomId: roomId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite sent to ${friend.username}.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send invite: $error')));
    }
  }

  Future<void> _blockUser(BuildContext context, UserModel friend) async {
    try {
      await controller.blockUser(friend.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${friend.username} blocked.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not block user: $error')));
    }
  }
}

class _MessengerSidebarController {
  const _MessengerSidebarController({
    required this.messagingController,
    required this.moderationService,
    required this.notificationService,
  });

  final MessagingController messagingController;
  final ModerationService moderationService;
  final NotificationService notificationService;

  Future<String> openConversation({
    required UserModel currentUser,
    required UserModel friend,
    required Conversation? existingConversation,
  }) async {
    final existingId = existingConversation?.id;
    if (existingId != null && existingId.isNotEmpty) return existingId;
    return messagingController.createDirectConversation(
      userId1: currentUser.id,
      user1Name: currentUser.username,
      user1AvatarUrl: currentUser.avatarUrl,
      userId2: friend.id,
      user2Name: friend.username,
      user2AvatarUrl: friend.avatarUrl,
    );
  }

  Future<void> inviteFriendToRoom({required UserModel currentUser, required UserModel friend, required String roomId}) {
    return notificationService.sendRoomInviteToFriends(
      friendIds: [friend.id],
      inviterId: currentUser.id,
      inviterName: currentUser.username,
      roomId: roomId,
      roomName: "${currentUser.username}'s room",
    );
  }

  Future<void> blockUser(String friendId) => moderationService.blockUser(friendId);

  Future<void> togglePinned({
    required String conversationId,
    required String userId,
    required bool pinned,
  }) {
    return messagingController.setConversationPinned(
      conversationId: conversationId,
      userId: userId,
      pinned: pinned,
    );
  }
}

class _DesktopSocialRail extends ConsumerWidget {
  const _DesktopSocialRail({required this.currentUser});

  final UserModel currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(friendRosterProvider).valueOrNull ?? const <FriendRosterEntry>[];
    final conversations = ref.watch(conversationsStreamProvider(currentUser.id)).valueOrNull ?? const <Conversation>[];
    final myPresence = ref.watch(currentUserPresenceProvider).valueOrNull;
    final requestCount = ref.watch(requestsStreamProvider(currentUser.id)).valueOrNull?.length ?? 0;
    final onlineCount = roster.where((entry) => entry.isOnline).length;
    final inRoomCount = roster.where((entry) => (entry.roomId ?? '').isNotEmpty).length;
    final unreadCount = conversations.where((c) => c.hasUnreadmessage(currentUser.id)).length;
    final pinnedCount = conversations.where((c) => c.isPinnedFor(currentUser.id)).length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceLow,
        border: Border(left: BorderSide(color: VelvetNoir.outlineVariant.withValues(alpha: 0.35))),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _RailCard(title: 'Presence', child: Column(children: [
              _StatRow(label: 'Online friends', value: '$onlineCount'),
              _StatRow(label: 'Friends in rooms', value: '$inRoomCount'),
              _StatRow(label: 'Unread chats', value: '$unreadCount'),
              _StatRow(label: 'Pinned chats', value: '$pinnedCount'),
              _StatRow(label: 'Requests', value: '$requestCount'),
            ])),
            const SizedBox(height: 14),
            _RailCard(
              title: 'Your status',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _StatusPill(color: _presenceColor(myPresence?.status, myPresence?.inRoom), label: _presenceLabel(myPresence)),
                if ((myPresence?.inRoom ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/room/${myPresence!.inRoom}'),
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('Rejoin current room'),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRosterRow extends StatefulWidget {
  const _FriendRosterRow({
    required this.entry,
    required this.conversation,
    required this.unread,
    required this.canInviteToRoom,
    required this.onOpenChat,
    required this.onViewProfile,
    required this.onInviteToRoom,
    required this.onBlockUser,
  });

  final FriendRosterEntry entry;
  final Conversation? conversation;
  final bool unread;
  final bool canInviteToRoom;
  final VoidCallback onOpenChat;
  final VoidCallback onViewProfile;
  final VoidCallback? onInviteToRoom;
  final VoidCallback onBlockUser;

  @override
  State<_FriendRosterRow> createState() => _FriendRosterRowState();
}

class _FriendRosterRowState extends State<_FriendRosterRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final preview = widget.conversation?.lastMessagePreview ?? _presenceLabel(widget.entry.presence);
    final timestamp = widget.conversation?.lastMessageAt ?? widget.entry.lastSeen;
    final avatarUrl = sanitizeNetworkImageUrl(widget.entry.user.avatarUrl);
    final borderColor = widget.unread
        ? VelvetNoir.primary.withValues(alpha: 0.42)
        : _isHovered
            ? VelvetNoir.secondary.withValues(alpha: 0.32)
            : VelvetNoir.outlineVariant.withValues(alpha: 0.28);
    final backgroundColor = _isHovered
        ? VelvetNoir.surfaceContainer.withValues(alpha: 0.92)
        : VelvetNoir.surfaceHigh.withValues(alpha: 0.95);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onOpenChat,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                if (_isHovered)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
              ],
          ),
          child: Row(
            children: [
              SafeNetworkAvatar(
                radius: 24,
                avatarUrl: avatarUrl,
                backgroundColor: VelvetNoir.surfaceHighest,
                fallbackText: widget.entry.user.username.isNotEmpty
                    ? widget.entry.user.username[0].toUpperCase()
                    : '?',
                fallbackTextStyle: const TextStyle(
                  color: VelvetNoir.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  offset: widget.entry.isOnline
                      ? const Offset(-0.82, 1.32)
                      : const Offset(-0.82, 1.0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: widget.entry.isOnline ? 1 : 0,
                    child: const _PresenceDot(),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(widget.entry.user.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VelvetNoir.onSurface, fontSize: 14, fontWeight: FontWeight.w700))),
                        if (timestamp != null) Text(_formatConversationTime(timestamp), style: const TextStyle(color: VelvetNoir.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.unread ? VelvetNoir.onSurface : VelvetNoir.onSurfaceVariant, fontSize: 12, fontWeight: widget.unread ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _isHovered || widget.unread ? 1 : 0.7,
                child: PopupMenuButton<_FriendMenuAction>(
                tooltip: 'Friend actions',
                color: VelvetNoir.surfaceHigh,
                onSelected: (value) {
                  switch (value) {
                    case _FriendMenuAction.viewProfile:
                        widget.onViewProfile();
                    case _FriendMenuAction.startChat:
                        widget.onOpenChat();
                    case _FriendMenuAction.inviteToRoom:
                        widget.onInviteToRoom?.call();
                    case _FriendMenuAction.blockUser:
                        widget.onBlockUser();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<_FriendMenuAction>(value: _FriendMenuAction.viewProfile, child: Text('View Profile')),
                  const PopupMenuItem<_FriendMenuAction>(value: _FriendMenuAction.startChat, child: Text('Start Chat')),
                    PopupMenuItem<_FriendMenuAction>(value: _FriendMenuAction.inviteToRoom, enabled: widget.canInviteToRoom, child: const Text('Invite to Room')),
                  const PopupMenuItem<_FriendMenuAction>(value: _FriendMenuAction.blockUser, child: Text('Block User')),
                ],
                icon: const Icon(Icons.more_vert_rounded, color: VelvetNoir.onSurfaceVariant),
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

class _RecentConversationRow extends StatefulWidget {
  const _RecentConversationRow({
    required this.isSelected,
    required this.pinned,
    required this.isOnline,
    required this.displayName,
    required this.avatarUrl,
    required this.preview,
    required this.timestamp,
    required this.unread,
    required this.onTogglePin,
    required this.onTap,
  });

  final bool isSelected;
  final bool pinned;
  final bool isOnline;
  final String displayName;
  final String? avatarUrl;
  final String preview;
  final DateTime timestamp;
  final bool unread;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;

  @override
  State<_RecentConversationRow> createState() => _RecentConversationRowState();
}

class _RecentConversationRowState extends State<_RecentConversationRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.avatarUrl;
    final backgroundColor = widget.isSelected
        ? VelvetNoir.primary.withValues(alpha: 0.12)
        : _isHovered
            ? VelvetNoir.surfaceContainer.withValues(alpha: 0.94)
            : VelvetNoir.surfaceHigh.withValues(alpha: 0.95);
    final borderColor = widget.isSelected
        ? VelvetNoir.primary.withValues(alpha: 0.52)
        : widget.unread
            ? VelvetNoir.primary.withValues(alpha: 0.42)
            : _isHovered
                ? VelvetNoir.secondary.withValues(alpha: 0.28)
                : VelvetNoir.outlineVariant.withValues(alpha: 0.28);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                if (_isHovered || widget.isSelected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
              ],
          ),
          child: Row(
            children: [
              SafeNetworkAvatar(
                radius: 24,
                avatarUrl: avatarUrl,
                backgroundColor: VelvetNoir.surfaceHighest,
                fallbackText: widget.displayName.isNotEmpty
                    ? widget.displayName[0].toUpperCase()
                    : '?',
                fallbackTextStyle: const TextStyle(
                  color: VelvetNoir.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  offset: widget.isOnline
                      ? const Offset(-0.82, 1.32)
                      : const Offset(-0.82, 1.0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: widget.isOnline ? 1 : 0,
                    child: const _PresenceDot(),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(widget.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: VelvetNoir.onSurface, fontSize: 14, fontWeight: widget.unread ? FontWeight.w800 : FontWeight.w700))),
                        Text(_formatConversationTime(widget.timestamp), style: TextStyle(color: widget.unread ? VelvetNoir.primary : VelvetNoir.onSurfaceVariant, fontSize: 11, fontWeight: widget.unread ? FontWeight.w700 : FontWeight.w600)),
                        const SizedBox(width: 4),
                        AnimatedScale(
                          duration: const Duration(milliseconds: 160),
                          scale: widget.pinned ? 1 : (_isHovered ? 1 : 0.92),
                          child: IconButton(
                          tooltip: widget.pinned ? 'Unpin conversation' : 'Pin conversation',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: widget.onTogglePin,
                          icon: Icon(
                            widget.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                            size: 16,
                            color: widget.pinned ? VelvetNoir.secondaryBright : VelvetNoir.onSurfaceVariant,
                          ),
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(color: widget.unread ? VelvetNoir.onSurface : VelvetNoir.onSurfaceVariant, fontSize: 12, fontWeight: widget.unread ? FontWeight.w700 : FontWeight.w500),
                      child: Text(widget.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
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

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.title, required this.count, required this.child, this.trailing});

  final String title;
  final int count;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${count.toString()})',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SidebarQuickNav extends StatelessWidget {
  const _SidebarQuickNav();

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, IconData icon, String route) {
      return Expanded(
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: 38,
            decoration: BoxDecoration(
              color: VelvetNoir.surfaceContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VelvetNoir.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: VelvetNoir.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('Rooms', Icons.meeting_room_rounded, '/rooms'),
        const SizedBox(width: 8),
        chip('Discover', Icons.explore_rounded, '/discover'),
        const SizedBox(width: 8),
        chip('Friends', Icons.people_alt_rounded, '/friends'),
      ],
    );
  }
}

class _SidebarEmptyState extends StatelessWidget {
  const _SidebarEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(color: VelvetNoir.surfaceHigh.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(16), border: Border.all(color: VelvetNoir.outlineVariant.withValues(alpha: 0.28))),
      child: Text(label, style: const TextStyle(color: VelvetNoir.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(color: VelvetNoir.surfaceHigh.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(18), border: Border.all(color: VelvetNoir.outlineVariant.withValues(alpha: 0.28))),
      child: TextField(
        controller: controller,
        style: GoogleFonts.raleway(color: VelvetNoir.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search people or chats',
          hintStyle: GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: VelvetNoir.onSurfaceVariant, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        shape: BoxShape.circle,
        border: Border.all(color: VelvetNoir.surfaceLow, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

enum _FriendMenuAction { viewProfile, startChat, inviteToRoom, blockUser }

Conversation? _directConversationForFriend(List<Conversation> conversations, String currentUserId, String friendId) {
  for (final conversation in conversations) {
    if (conversation.type == 'direct' && conversation.participantIds.contains(currentUserId) && conversation.participantIds.contains(friendId)) {
      return conversation;
    }
  }
  return null;
}

String _directOtherUserId(Conversation conversation, String currentUserId) => conversation.participantIds.firstWhere((participantId) => participantId != currentUserId, orElse: () => '');

FriendRosterEntry? _rosterEntryForUserId(List<FriendRosterEntry> roster, String userId) {
  for (final entry in roster) {
    if (entry.friendId == userId) return entry;
  }
  return null;
}

int _compareRosterEntries(FriendRosterEntry a, FriendRosterEntry b) {
  final aRoom = (a.roomId ?? '').isNotEmpty;
  final bRoom = (b.roomId ?? '').isNotEmpty;
  if (aRoom != bRoom) return aRoom ? -1 : 1;
  if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
  return a.user.username.toLowerCase().compareTo(b.user.username.toLowerCase());
}

Color _presenceColor(UserStatus? status, String? roomId) {
  if ((roomId ?? '').isNotEmpty) return VelvetNoir.secondaryBright;
  switch (status) {
    case UserStatus.online:
      return const Color(0xFF22C55E);
    case UserStatus.away:
      return const Color(0xFFF59E0B);
    case UserStatus.dnd:
      return VelvetNoir.secondaryBright;
    case UserStatus.offline:
    case null:
      return VelvetNoir.onSurfaceVariant;
  }
}

String _presenceLabel(PresenceModel? presence) {
  if (presence == null) return 'Offline';
  if ((presence.inRoom ?? '').isNotEmpty) return 'In room';
  switch (presence.status) {
    case UserStatus.online:
      return 'Online';
    case UserStatus.away:
      return 'Away';
    case UserStatus.dnd:
      return 'Do not disturb';
    case UserStatus.offline:
      if (presence.lastSeen == null) return 'Offline';
      final delta = DateTime.now().difference(presence.lastSeen!);
      if (delta.inMinutes < 1) return 'Last seen just now';
      if (delta.inMinutes < 60) return 'Last seen ${delta.inMinutes}m ago';
      if (delta.inHours < 24) return 'Last seen ${delta.inHours}h ago';
      return 'Last seen ${delta.inDays}d ago';
  }
}

String _formatConversationTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  return '${value.month}/${value.day}';
}


class _RailCard extends StatelessWidget {
  const _RailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VelvetNoir.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              color: VelvetNoir.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: VelvetNoir.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: VelvetNoir.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}











