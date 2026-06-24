import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/widgets/skeleton_loaders.dart';
import 'package:mixmingle/shared/widgets/empty_states.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/app/app_routes.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationListAsync = ref.watch(conversationListProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) {
              return const Center(
                  child: Text('Please sign in to view messages'));
            }

            return conversationListAsync.when(
              data: (chatRooms) {
                if (chatRooms.isEmpty) {
                  return EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No conversations yet',
                    message: 'Match with someone to start a chat!',
                    actionLabel: 'Find People',
                    onAction: () => Navigator.pushNamed(
                        context, AppRoutes.discoverUsers),
                  );
                }

                return ListView.builder(
                  itemCount: chatRooms.length,
                  itemBuilder: (ctx, i) {
                    final chatRoom = chatRooms[i];
                    final otherUserId = chatRoom.participants.firstWhere(
                      (id) => id != currentUser.id,
                      orElse: () => chatRoom.participants.first,
                    );
                    final unreadCount =
                        chatRoom.unreadCounts[currentUser.id] ?? 0;

                    // Watch other user profile
                    final otherUserAsync =
                        ref.watch(userProfileProvider(otherUserId));

                    return otherUserAsync.when(
                      data: (otherUser) {
                        // Watch presence status
                        final presenceAsync =
                            ref.watch(presenceProvider(otherUserId));

                        return presenceAsync.when(
                          data: (presence) {
                            final isOnline = presence['isOnline'] as bool;

                            return ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.3),
                                    backgroundImage: otherUser
                                                ?.photos.isNotEmpty ==
                                            true
                                        ? NetworkImage(otherUser!.photos.first)
                                        : null,
                                    child: otherUser?.photos.isEmpty == true
                                        ? Text(
                                            otherUser?.displayName
                                                        ?.isNotEmpty ==
                                                    true
                                                ? otherUser!.displayName![0]
                                                    .toUpperCase()
                                                : '?',
                                          )
                                        : null,
                                  ),
                                  // Online indicator
                                  if (isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                otherUser?.displayName ??
                                    otherUser?.username ??
                                    'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  if (chatRoom.isTyping)
                                    const Text(
                                      'Typing...',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: Text(
                                        chatRoom.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: unreadCount > 0
                                              ? Colors.white
                                              : Colors.white70,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatTime(chatRoom.lastMessageTime),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.chat,
                                arguments: chatRoom.id,
                              ),
                            );
                          },
                          loading: () => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.3),
                              backgroundImage:
                                  otherUser?.photos.isNotEmpty == true
                                      ? NetworkImage(otherUser!.photos.first)
                                      : null,
                              child: otherUser?.photos.isEmpty == true
                                  ? Text(
                                      otherUser?.displayName?.isNotEmpty == true
                                          ? otherUser!.displayName![0]
                                              .toUpperCase()
                                          : '?',
                                    )
                                  : null,
                            ),
                            title: Text(
                              otherUser?.displayName ??
                                  otherUser?.username ??
                                  'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              chatRoom.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          error: (error, stack) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.3),
                              backgroundImage:
                                  otherUser?.photos.isNotEmpty == true
                                      ? NetworkImage(otherUser!.photos.first)
                                      : null,
                              child: otherUser?.photos.isEmpty == true
                                  ? Text(
                                      otherUser?.displayName?.isNotEmpty == true
                                          ? otherUser!.displayName![0]
                                              .toUpperCase()
                                          : '?',
                                    )
                                  : null,
                            ),
                            title: Text(
                              otherUser?.displayName ??
                                  otherUser?.username ??
                                  'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              chatRoom.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      },
                      loading: () => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.3),
                          child: const Icon(Icons.person, size: 20),
                        ),
                        title: const Text('Loading...',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      error: (error, stack) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.3),
                          child: const Icon(Icons.error, size: 20),
                        ),
                        title: const Text('Error loading user',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    );
                  },
                );
              },
              loading: () => ListView.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const SkeletonTile(
                  showAvatar: true,
                  textLines: 2,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading conversations: $error',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => ListView.builder(
            itemCount: 6,
            itemBuilder: (_, __) => const SkeletonTile(
              showAvatar: true,
              textLines: 2,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          error: (error, stack) => const Center(
            child: Text('Error loading user',
                style: TextStyle(color: Colors.white70)),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      return _getDayName(dateTime.weekday);
    } else {
      // Older - show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
