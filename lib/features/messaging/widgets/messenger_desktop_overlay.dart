import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../models/presence_model.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/messenger_status_service.dart';
import '../../friends/models/friend_roster_entry.dart';
import '../../friends/providers/friends_providers.dart';
import '../panes/chat_pane_view.dart';
import '../providers/messaging_provider.dart';
import '../providers/messenger_window_provider.dart';

class MessengerDesktopOverlay extends ConsumerWidget {
  const MessengerDesktopOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < messengerDesktopBreakpoint) return child;

        final messenger = ref.watch(messengerDesktopProvider);
        final currentUser = messenger.windows.any((entry) => !entry.minimized)
            ? ref.watch(userProvider)
            : null;
        final buddyWidth = constraints.maxWidth < 1100 ? 292.0 : 320.0;
        final chatWidth = constraints.maxWidth < 1100 ? 330.0 : 370.0;
        final panelHeight = (constraints.maxHeight - 32).clamp(360.0, 620.0);
        final buddyOffset = messenger.isBuddyListOpen ? buddyWidth + 12 : 0.0;
        final expanded = messenger.windows
            .where((entry) => !entry.minimized)
            .toList(growable: false)
            .reversed
            .toList(growable: false);
        final minimized = messenger.windows
            .where((entry) => entry.minimized)
            .toList(growable: false);

        return Stack(
          children: [
            Positioned.fill(child: child),
            if (messenger.isBuddyListOpen)
              Positioned(
                right: 16,
                bottom: 16,
                width: buddyWidth,
                height: panelHeight,
                child: const _BuddyListPanel(),
              ),
            for (var index = 0; index < expanded.length; index++)
              Positioned(
                right: 16 + buddyOffset + (index * (chatWidth + 12)),
                bottom: 16,
                width: chatWidth,
                height: panelHeight.clamp(360.0, 560.0),
                child: _MessengerChatWindow(
                  entry: expanded[index],
                  currentUser: currentUser,
                ),
              ),
            for (var index = 0; index < minimized.length; index++)
              Positioned(
                right: 16 + buddyOffset + (index * 184),
                bottom: 16,
                width: 172,
                child: _MinimizedChatButton(entry: minimized[index]),
              ),
          ],
        );
      },
    );
  }
}

class _BuddyListPanel extends ConsumerStatefulWidget {
  const _BuddyListPanel();

  @override
  ConsumerState<_BuddyListPanel> createState() => _BuddyListPanelState();
}

class _BuddyListPanelState extends ConsumerState<_BuddyListPanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final roster = ref.watch(friendRosterProvider);
    final profileStatus =
        ref.watch(currentMessengerProfileStatusProvider).valueOrNull ??
        const MessengerProfileStatus();
    final statusMessage = profileStatus.statusMessage;

    return Material(
      key: const ValueKey<String>('mixvy-messenger-buddy-panel'),
      elevation: 16,
      color: VelvetNoir.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF241820),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.forum_rounded,
                  color: VelvetNoir.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'MixVy Messenger',
                    style: TextStyle(
                      color: VelvetNoir.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New group',
                  onPressed: () {
                    ref
                        .read(messengerDesktopProvider.notifier)
                        .closeBuddyList();
                    context.go('/messages/create-group-chat');
                  },
                  icon: const Icon(Icons.group_add_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Close messenger',
                  onPressed: ref
                      .read(messengerDesktopProvider.notifier)
                      .closeBuddyList,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          currentUser.username,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: VelvetNoir.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DropdownButton<UserStatus>(
                        value: switch (profileStatus.availability) {
                          'away' => UserStatus.away,
                          'dnd' => UserStatus.dnd,
                          _ => UserStatus.online,
                        },
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: UserStatus.online,
                            child: Text('Online'),
                          ),
                          DropdownMenuItem(
                            value: UserStatus.away,
                            child: Text('Away'),
                          ),
                          DropdownMenuItem(
                            value: UserStatus.dnd,
                            child: Text('Busy'),
                          ),
                        ],
                        onChanged: (status) async {
                          if (status == null) return;
                          try {
                            await ref
                                .read(messengerStatusServiceProvider)
                                .updateAvailability(
                                  currentUser.id,
                                  status.name,
                                );
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not update availability: $error',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _editStatusMessage(statusMessage),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                            color: VelvetNoir.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              statusMessage.isEmpty
                                  ? 'Set a status message'
                                  : statusMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VelvetNoir.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search buddies',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: roster.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const Center(
                child: Text(
                  'Could not load buddies.',
                  style: TextStyle(color: VelvetNoir.onSurfaceVariant),
                ),
              ),
              data: (entries) {
                final filtered = entries
                    .where(
                      (entry) =>
                          _query.isEmpty ||
                          entry.user.username.toLowerCase().contains(_query),
                    )
                    .toList(growable: false)
                  ..sort(_compareRosterEntries);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No buddies found.',
                      style: TextStyle(color: VelvetNoir.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _BuddyTile(
                    entry: filtered[index],
                    onOpen: () => _openConversation(filtered[index].user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _compareRosterEntries(
    FriendRosterEntry left,
    FriendRosterEntry right,
  ) {
    final leftRank = _presenceRank(left.presence.status, left.isOnline);
    final rightRank = _presenceRank(right.presence.status, right.isOnline);
    if (leftRank != rightRank) return leftRank.compareTo(rightRank);
    return left.user.username.toLowerCase().compareTo(
          right.user.username.toLowerCase(),
        );
  }

  int _presenceRank(UserStatus status, bool online) {
    if (!online) return 3;
    return switch (status) {
      UserStatus.online => 0,
      UserStatus.away => 1,
      UserStatus.dnd => 2,
      UserStatus.offline => 3,
    };
  }

  Future<void> _openConversation(UserModel friend) async {
    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;

    try {
      final conversationId =
          await ref.read(messagingControllerProvider).createDirectConversation(
                userId1: currentUser.id,
                user1Name: currentUser.username,
                user1AvatarUrl: currentUser.avatarUrl,
                userId2: friend.id,
                user2Name: friend.username,
                user2AvatarUrl: friend.avatarUrl,
              );
      ref.read(messengerDesktopProvider.notifier).openConversation(
            conversationId: conversationId,
            title: friend.username,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $error')),
      );
    }
  }

  Future<void> _editStatusMessage(String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Status message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'What are you up to?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;

    final userId = ref.read(userProvider)?.id ?? '';
    try {
      await ref
          .read(messengerStatusServiceProvider)
          .updateStatusMessage(userId, value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $error')),
      );
    }
  }
}

class _BuddyTile extends StatelessWidget {
  const _BuddyTile({required this.entry, required this.onOpen});

  final FriendRosterEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = entry.isOnline
        ? switch (entry.user.messengerStatus) {
            'away' => UserStatus.away,
            'dnd' => UserStatus.dnd,
            _ => UserStatus.online,
          }
        : UserStatus.offline;
    final statusColor = switch (status) {
      UserStatus.online => const Color(0xFF22C55E),
      UserStatus.away => const Color(0xFFF59E0B),
      UserStatus.dnd => const Color(0xFFEF4444),
      UserStatus.offline => const Color(0xFF6B7280),
    };
    final statusLabel = switch (status) {
      UserStatus.online => 'Online',
      UserStatus.away => 'Away',
      UserStatus.dnd => 'Busy',
      UserStatus.offline => 'Offline',
    };
    final customStatus = entry.user.statusMessage?.trim() ?? '';

    return ListTile(
      dense: true,
      onTap: onOpen,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundImage: (entry.user.avatarUrl?.trim().isNotEmpty ?? false)
                ? NetworkImage(entry.user.avatarUrl!.trim())
                : null,
            child: (entry.user.avatarUrl?.trim().isNotEmpty ?? false)
                ? null
                : Text(
                    entry.user.username.isEmpty
                        ? '?'
                        : entry.user.username[0].toUpperCase(),
                  ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: VelvetNoir.surfaceHigh,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        entry.user.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        customStatus.isEmpty ? statusLabel : '$statusLabel · $customStatus',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: statusColor, fontSize: 11),
      ),
      trailing: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
    );
  }
}

class _MessengerChatWindow extends ConsumerWidget {
  const _MessengerChatWindow({
    required this.entry,
    required this.currentUser,
  });

  final MessengerWindowEntry entry;
  final UserModel? currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = currentUser;
    return Material(
      key: ValueKey<String>('messenger-window-${entry.conversationId}'),
      elevation: 18,
      color: VelvetNoir.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF241820),
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.circle,
                  color: Color(0xFF22C55E),
                  size: 9,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VelvetNoir.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Minimize chat',
                  onPressed: () => ref
                      .read(messengerDesktopProvider.notifier)
                      .setMinimized(entry.conversationId, true),
                  icon: const Icon(Icons.remove, size: 19),
                ),
                IconButton(
                  tooltip: 'Close chat',
                  onPressed: () => ref
                      .read(messengerDesktopProvider.notifier)
                      .closeConversation(entry.conversationId),
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
          ),
          Expanded(
            child: user == null
                ? const Center(child: Text('Sign in to use Messenger.'))
                : ChatPaneView(
                    conversationId: entry.conversationId,
                    userId: user.id,
                    username: user.username,
                    avatarUrl: user.avatarUrl,
                    showHeader: false,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MinimizedChatButton extends ConsumerWidget {
  const _MinimizedChatButton({required this.entry});

  final MessengerWindowEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () => ref
          .read(messengerDesktopProvider.notifier)
          .setMinimized(entry.conversationId, false),
      icon: const Icon(Icons.chat_bubble_rounded, size: 17),
      label: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
