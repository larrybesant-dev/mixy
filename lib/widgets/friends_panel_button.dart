import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_model.dart';
import '../core/utils/network_image_url.dart';
import '../features/messaging/providers/messaging_provider.dart';
import '../presentation/providers/friend_provider.dart';
import '../presentation/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FriendsPanelButton
//
// Drop-in icon button that opens a slide-up friends panel bottom sheet.
// Works anywhere in the app – just place inside any widget tree that has a
// ProviderScope ancestor (which is the entire app).
// ─────────────────────────────────────────────────────────────────────────────

class FriendsPanelButton extends StatelessWidget {
  const FriendsPanelButton({super.key, this.iconColor, this.size = 24});

  final Color? iconColor;
  final double size;

  /// Call this directly if you want to open the panel without the button.
  static void openPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FriendsPanelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Friends',
      icon: Icon(
        Icons.people_alt_rounded,
        color: iconColor ?? Theme.of(context).colorScheme.onSurface,
        size: size,
      ),
      onPressed: () => openPanel(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet content
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsPanelSheet extends ConsumerStatefulWidget {
  const _FriendsPanelSheet();

  @override
  ConsumerState<_FriendsPanelSheet> createState() => _FriendsPanelSheetState();
}

class _FriendsPanelSheetState extends ConsumerState<_FriendsPanelSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final friendsAsync = ref.watch(friendsListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      expand: false,
      builder: (sheetCtx, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.people_alt_rounded,
                        color: cs.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('Friends',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        GoRouter.of(context).push('/friends');
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('See all'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search friends…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Friend list
              Expanded(
                child: friendsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Could not load friends.')),
                  data: (friends) {
                    final filtered = _query.isEmpty
                        ? friends
                        : friends
                            .where((f) => f.username
                                .toLowerCase()
                                .contains(_query))
                            .toList();

                    if (filtered.isEmpty) {
                      return _EmptyState(
                          hasQuery: _query.isNotEmpty, query: _query);
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      padding: const EdgeInsets.only(bottom: 32),
                      itemBuilder: (_, i) => _FriendTile(friend: filtered[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.query});
  final bool hasQuery;
  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline,
              size: 52, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            hasQuery ? 'No results for "$query"' : 'No friends yet',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.of(context).push('/friends');
              },
              child: const Text('Find friends'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FriendTile extends ConsumerWidget {
  const _FriendTile({required this.friend});
  final UserModel friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(friendPresenceProvider(friend.id));
    final isOnline = presenceAsync.valueOrNull?.isOnline == true;
    final inRoom = presenceAsync.valueOrNull?.inRoom;
    final cs = Theme.of(context).colorScheme;
    final safeAvatarUrl = sanitizeNetworkImageUrl(friend.avatarUrl);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.primaryContainer,
            backgroundImage: safeAvatarUrl != null
              ? NetworkImage(safeAvatarUrl)
                : null,
            child: safeAvatarUrl == null
                ? Text(
                    friend.username.isNotEmpty
                        ? friend.username[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: cs.onPrimaryContainer),
                  )
                : null,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFFC45E7A)
                    : cs.outlineVariant,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(friend.username,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: isOnline
          ? Text(
              inRoom != null ? '🎙 In a room' : 'Online',
              style: const TextStyle(
                  color: Color(0xFFC45E7A), fontSize: 12),
            )
          : Text(
              'Offline',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontSize: 12),
            ),
      trailing: _MessageButton(friend: friend),
      onTap: () {
        Navigator.of(context).pop();
        GoRouter.of(context).push('/profile/${friend.id}');
      },
    );
  }
}

class _MessageButton extends ConsumerWidget {
  const _MessageButton({required this.friend});
  final UserModel friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userProvider);
    if (currentUser == null) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'message',
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
      onPressed: () async {
        final navigator = Navigator.of(context);
        final router = GoRouter.of(context);
        final messenger = ScaffoldMessenger.of(context);
        try {
          final conversationId = await ref.read(messagingControllerProvider).createDirectConversation(
                userId1: currentUser.id,
                user1Name: currentUser.username,
                user1AvatarUrl: currentUser.avatarUrl,
                userId2: friend.id,
                user2Name: friend.username,
                user2AvatarUrl: friend.avatarUrl,
              );
          navigator.pop();
          unawaited(router.push('/chat/$conversationId'));
        } catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not open chat: $error')),
          );
        }
      },
    );
  }
}
