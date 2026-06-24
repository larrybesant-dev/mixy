import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/social_graph_providers.dart';
import '../../shared/providers/auth_providers.dart';
import '../models/user_presence.dart';
import '../models/user_profile.dart';

/// Follow/Unfollow button widget
class FollowButton extends ConsumerWidget {
  final String userId;
  final bool compact;

  const FollowButton({
    super.key,
    required this.userId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final isFollowingAsync = ref.watch(isFollowingProvider(userId));

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null || currentUser.id == userId) {
          return const SizedBox.shrink();
        }

        return isFollowingAsync.when(
          data: (isFollowing) {
            return ElevatedButton.icon(
              onPressed: () async {
                final service = ref.read(socialGraphServiceProvider);
                try {
                  if (isFollowing) {
                    await service.unfollowUser(userId);
                  } else {
                    await service.followUser(userId);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: Icon(
                isFollowing ? Icons.person_remove : Icons.person_add,
                size: compact ? 16 : 20,
              ),
              label: Text(
                isFollowing ? 'Unfollow' : 'Follow',
                style: TextStyle(fontSize: compact ? 12 : 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing
                    ? Colors.grey[800]
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            );
          },
          loading: () => const SizedBox(
            width: 80,
            height: 36,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Presence indicator widget
class PresenceIndicator extends ConsumerWidget {
  final String userId;
  final double size;
  final bool showLabel;

  const PresenceIndicator({
    super.key,
    required this.userId,
    this.size = 12,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(userPresenceProvider(userId));

    return presenceAsync.when(
      data: (presence) {
        if (presence == null) return const SizedBox.shrink();

        final color = _getStatusColor(presence.status);
        final label = _getStatusLabel(presence.status);

        if (showLabel) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: size > 10 ? 2 : 1,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _getStatusColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.orange;
      case PresenceStatus.busy:
        return Colors.red;
      case PresenceStatus.offline:
        return Colors.grey;
    }
  }

  String _getStatusLabel(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.busy:
        return 'Busy';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }
}

/// Followers list widget
class FollowersList extends ConsumerWidget {
  final String userId;

  const FollowersList({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersAsync = ref.watch(followerProfilesProvider(userId));

    return followersAsync.when(
      data: (followers) {
        if (followers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No followers yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: followers.length,
          itemBuilder: (context, index) {
            final user = followers[index];
            return _UserListTile(user: user);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

/// Following list widget
class FollowingList extends ConsumerWidget {
  final String userId;

  const FollowingList({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProfilesProvider(userId));

    return followingAsync.when(
      data: (following) {
        if (following.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Not following anyone yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: following.length,
          itemBuilder: (context, index) {
            final user = following[index];
            return _UserListTile(user: user);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

/// Mutual friends list widget
class MutualFriendsList extends ConsumerWidget {
  final String userId;

  const MutualFriendsList({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(mutualFriendsProfilesProvider(userId));

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No mutual friends yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final user = friends[index];
            return _UserListTile(user: user);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

/// Private user list tile widget
class _UserListTile extends ConsumerWidget {
  final UserProfile user;

  const _UserListTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.displayName?.isNotEmpty == true
                        ? user.displayName![0].toUpperCase()
                        : '?',
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: PresenceIndicator(userId: user.id, size: 12),
          ),
        ],
      ),
      title: Text(user.displayName ?? user.nickname ?? 'Unknown'),
      subtitle: user.bio != null
          ? Text(user.bio!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: FollowButton(userId: user.id, compact: true),
      onTap: () {
        // Navigate to user profile
        // You can implement this navigation based on your app structure
      },
    );
  }
}

/// Follower/Following stats widget
class SocialStatsWidget extends ConsumerWidget {
  final String userId;

  const SocialStatsWidget({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersCountAsync = ref.watch(followerCountProvider(userId));
    final followingCountAsync = ref.watch(followingCountProvider(userId));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatColumn(
          label: 'Followers',
          countAsync: followersCountAsync,
          onTap: () => _showFollowersList(context, userId),
        ),
        _StatColumn(
          label: 'Following',
          countAsync: followingCountAsync,
          onTap: () => _showFollowingList(context, userId),
        ),
      ],
    );
  }

  void _showFollowersList(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Followers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(child: FollowersList(userId: userId)),
          ],
        ),
      ),
    );
  }

  void _showFollowingList(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Following',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(child: FollowingList(userId: userId)),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final AsyncValue<int> countAsync;
  final VoidCallback onTap;

  const _StatColumn({
    required this.label,
    required this.countAsync,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          countAsync.when(
            data: (count) => Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            loading: () => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Text('--'),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}
