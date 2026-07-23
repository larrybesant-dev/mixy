import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/providers/session_capabilities_provider.dart';
import 'package:mixvy/shared/widgets/guest_auth_gate.dart';

import '../providers/story_provider.dart';
import '../../../core/utils/network_image_url.dart';
import '../../../presentation/providers/user_provider.dart';

/// Horizontal scrolling row of story avatar bubbles shown at the top of feeds.
///
/// Tapping an avatar navigates to /stories/:userId.
/// The current user's bubble always appears first with a "+" add action.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(userProvider);
    final uid = authUser?.id;
    if (uid == null || uid.trim().isEmpty) return const SizedBox.shrink();

    final followingIds =
        ref.watch(followingIdsProvider(uid)).asData?.value ?? const <String>[];
    final params = (userId: uid, followingIds: followingIds);
    final storiesAsync = ref.watch(followingStoriesProvider(params));

    return storiesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (__, _) => const SizedBox.shrink(),
      data: (stories) {
        // Group stories by userId, preserving first occurrence order
        final seen = <String>{};
        final authorIds = <String>[];
        final authorData = <String, Story>{};
        for (final s in stories) {
          if (seen.add(s.userId)) {
            authorIds.add(s.userId);
            authorData[s.userId] = s;
          }
        }

        // Build list: own bubble first, then others
        final items = <String>[uid, ...authorIds.where((id) => id != uid)];

        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final id = items[i];
              final isOwn = id == uid;
              final story = authorData[id];
              final hasStory = story != null;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _StoryBubble(
                  userId: id,
                  username: isOwn ? 'Your Story' : (story?.username ?? ''),
                  avatarUrl: story?.userAvatarUrl,
                  hasStory: hasStory,
                  isOwn: isOwn,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final String userId;
  final String username;
  final String? avatarUrl;
  final bool hasStory;
  final bool isOwn;

  const _StoryBubble({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.hasStory,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeAvatarUrl = sanitizeNetworkImageUrl(avatarUrl);
    return GestureDetector(
      onTap: () async {
        if (isOwn && !hasStory) {
          final allowed = await GuestAuthGate.requireCapabilityFromContext(
            context,
            SessionCapability.createStory,
          );
          if (!allowed || !context.mounted) return;
          context.go('/home/create-story');
        } else {
          context.go('/stories/$userId');
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasStory
                      ? LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: hasStory
                      ? null
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                padding: const EdgeInsets.all(2.5),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.surface,
                  child: safeAvatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: safeAvatarUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: (___, __, _) =>
                                const Icon(Icons.person, size: 26),
                          ),
                        )
                      : const Icon(Icons.person, size: 26),
                ),
              ),
              if (isOwn)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 62,
            child: Text(
              username.isEmpty ? '...' : username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: hasStory ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



