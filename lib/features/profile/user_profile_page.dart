import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/user.dart';
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../shared/neon_button.dart';
import '../messages/chat_screen.dart';
import '../profile/widgets/friend_request_button.dart';

class UserProfilePage extends ConsumerWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(userId));
    final currentUserAsync = ref.watch(currentUserProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const GlowText(
            text: 'Profile',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: userAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(
                child: GlowText(
                  text: 'User not found',
                  fontSize: 18,
                  color: Color(0xFFFF4C4C),
                ),
              );
            }

            return currentUserAsync.when(
              data: (currentUser) {
                final isOwnProfile = currentUser?.id == userId;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Header
                      _buildProfileHeader(user, isOwnProfile, ref),

                      const SizedBox(height: 24),

                      // Stats
                      _buildStats(user),

                      const SizedBox(height: 24),

                      // Bio
                      if (user.bio.isNotEmpty) ...[
                        _buildBioSection(user),
                        const SizedBox(height: 24),
                      ],

                      // Interests
                      if (user.interests.isNotEmpty) ...[
                        _buildInterestsSection(user),
                        const SizedBox(height: 24),
                      ],

                      // Social Links
                      if (user.socialLinks.isNotEmpty) ...[
                        _buildSocialLinksSection(user),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
                ),
              ),
              error: (error, stack) => const Center(
                child: GlowText(
                  text: 'Error loading profile',
                  fontSize: 18,
                  color: Color(0xFFFF4C4C),
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
            ),
          ),
          error: (error, stack) => const Center(
            child: GlowText(
              text: 'Error loading user',
              fontSize: 18,
              color: Color(0xFFFF4C4C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user, bool isOwnProfile, WidgetRef ref) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4C4C), Color(0xFFFFD700)],
            ),
            border: Border.all(
              color: const Color(0xFFFFD700),
              width: 3,
            ),
          ),
          child: user.avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    '${user.avatarUrl}?t=${DateTime.now().millisecondsSinceEpoch}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                )
              : const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 60,
                ),
        ),

        const SizedBox(height: 16),

        // Name and Username
        GlowText(
          text: user.displayName ?? 'Unknown User',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          glowColor: const Color(0xFFFF4C4C),
        ),

        Text(
          '@${user.username}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 16),

        // Follow Button (only show if not own profile)
        if (!isOwnProfile) _buildFollowButton(user, ref),

        // Friend Button (only show if not own profile)
        if (!isOwnProfile) ...[
          const SizedBox(height: 12),
          FriendRequestButton(
            targetUserId: user.id,
            targetUserName: user.displayName,
            targetUserAvatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
          ),
        ],
      ],
    );
  }

  Widget _buildFollowButton(User user, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isFollowingAsync = ref.watch(isFollowingProvider({
      'followerId': currentUser.value?.id ?? '',
      'followingId': user.id,
    }));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Follow Button
        Expanded(
          child: isFollowingAsync.when(
            data: (isFollowing) => NeonButton(
              onPressed: () {
                if (isFollowing) {
                  ref.read(unfollowUserProvider(user.id).future);
                } else {
                  ref.read(followUserProvider(user.id).future);
                }
              },
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            loading: () => const SizedBox(
              width: 80,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
              ),
            ),
            error: (error, stack) => NeonButton(
              onPressed: () {
                ref.read(followUserProvider(user.id).future);
              },
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                'Follow',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Message Button
        Expanded(
          child: NeonButton(
            onPressed: () => _startConversation(user, ref),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              'Message',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _startConversation(User user, WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser != null) {
      Navigator.push(
        ref.context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            currentUser: currentUser,
            otherUser: user,
          ),
        ),
      );
    }
  }

  Widget _buildStats(User user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('${user.followersCount}', 'Followers'),
        _buildStatItem('${user.followingCount}', 'Following'),
        _buildStatItem('${user.liveSessionsHosted}', 'Sessions'),
        _buildStatItem('${user.totalTipsReceived}', 'Tips'),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        GlowText(
          text: value,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFD700),
          glowColor: const Color(0xFFFF4C4C),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlowText(
            text: 'About',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 8),
          Text(
            user.bio,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlowText(
            text: 'Interests',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.interests.map((interest) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF4C4C),
                    width: 1,
                  ),
                ),
                child: Text(
                  interest,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlowText(
            text: 'Social Links',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 12),
          ...user.socialLinks.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '${entry.key}: ',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    entry.value,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
