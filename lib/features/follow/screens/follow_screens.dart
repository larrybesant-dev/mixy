import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../presentation/providers/friend_provider.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../profile/widgets/profile_card.dart';
import '../../profile/widgets/social_user_card.dart';
import '../providers/follow_provider.dart';

class FollowersScreen extends ConsumerWidget {
  final String userId;

  const FollowersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersAsync = ref.watch(followersProvider(userId));

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: AppAsyncValueView<List<UserFollow>>(
        value: followersAsync,
        fallbackContext: 'followers',
        isEmpty: (followers) => followers.isEmpty,
        empty: const AppEmptyView(
          title: 'No followers yet',
          icon: Icons.people_outline_rounded,
        ),
        data: (followers) => ListView.separated(
          itemCount: followers.length,
          separatorBuilder: (__, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final follower = followers[index];
            return _FollowUserTile(
              userId: follower.userId,
              avatarUrl: follower.avatarUrl,
              username: follower.username,
              isVerified: follower.isVerified,
              onTap: () => context.push('/profile/${follower.userId}'),
            );
          },
        ),
      ),
    );
  }
}

class FollowingScreen extends ConsumerWidget {
  final String userId;

  const FollowingScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider(userId));

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Following')),
      body: AppAsyncValueView<List<UserFollow>>(
        value: followingAsync,
        fallbackContext: 'following',
        isEmpty: (following) => following.isEmpty,
        empty: const AppEmptyView(
          title: 'Not following anyone yet',
          icon: Icons.person_add_alt_rounded,
        ),
        data: (following) => ListView.separated(
          itemCount: following.length,
          separatorBuilder: (__, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = following[index];
            return _FollowUserTile(
              userId: user.userId,
              avatarUrl: user.avatarUrl,
              username: user.username,
              isVerified: user.isVerified,
              onTap: () => context.push('/profile/${user.userId}'),
            );
          },
        ),
      ),
    );
  }
}

class _FollowUserTile extends ConsumerWidget {
  const _FollowUserTile({
    required this.userId,
    required this.avatarUrl,
    required this.username,
    required this.isVerified,
    required this.onTap,
  });

  final String userId;
  final String? avatarUrl;
  final String username;
  final bool isVerified;
  final VoidCallback onTap;

  String _buildHandle(String value) {
    final normalized = value.trim().toLowerCase();
    final compact = normalized.replaceAll(RegExp(r'[^a-z0-9_]+'), '');
    return compact.isEmpty ? '@mixvy' : '@$compact';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(friendPresenceProvider(userId)).valueOrNull;
    final roomId = presence?.inRoom;
    final presenceState = (roomId ?? '').isNotEmpty
        ? ProfilePresenceState.inRoom
        : presence?.isOnline == true
        ? ProfilePresenceState.online
        : ProfilePresenceState.offline;
    final statusText = (roomId ?? '').isNotEmpty
        ? 'Currently in room'
        : isVerified
        ? 'Verified member'
        : (presence?.isOnline == true ? 'Online' : 'MixVy member');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SocialUserCard(
        displayName: username,
        username: _buildHandle(username),
        avatarUrl: avatarUrl,
        statusText: statusText,
        presenceState: presenceState,
        primaryLabel: 'View Profile',
        onPrimaryPressed: onTap,
        secondaryLabel: (roomId ?? '').isNotEmpty ? 'Join Room' : null,
        onSecondaryPressed: (roomId ?? '').isNotEmpty
            ? () => context.push('/room/$roomId')
            : null,
        onTap: onTap,
      ),
    );
  }
}



