/// Suggested Users Page
/// Discover new people to follow based on interests and mutual connections
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/widgets/club_background.dart';
import '../../../shared/widgets/neon_components.dart';
import '../../../shared/widgets/presence_indicator.dart';
import '../../../shared/providers/social_graph_providers.dart';
import '../../../shared/providers/auth_providers.dart';

/// Suggested Users - Discover people to connect with
class SuggestedUsersPage extends ConsumerWidget {
  const SuggestedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedAsync = ref.watch(suggestedUsersProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const NeonText(
            'DISCOVER PEOPLE',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            textColor: DesignColors.white,
            glowColor: DesignColors.accent,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: DesignColors.white),
              onPressed: () {
                ref.invalidate(suggestedUsersProvider);
              },
            ),
          ],
        ),
        body: currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) {
              return const Center(child: Text('Please sign in'));
            }

            return suggestedAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(suggestedUsersProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildUserCard(context, ref, user, currentUser.id);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: DesignColors.white.withValues(
                          alpha: 255, red: 255, green: 255, blue: 255),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading suggestions',
                      style: TextStyle(
                        color: DesignColors.white.withValues(
                            alpha: 255, red: 255, green: 255, blue: 255),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    NeonButton(
                      label: 'Try Again',
                      onPressed: () {
                        ref.invalidate(suggestedUsersProvider);
                      },
                      glowColor: DesignColors.accent,
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading user')),
        ),
      ),
    );
  }

  Widget _buildUserCard(
      BuildContext context, WidgetRef ref, dynamic user, String currentUserId) {
    final isFollowingAsync = ref.watch(isFollowingProvider(user.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeonGlowCard(
        glowColor: DesignColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with avatar and follow button
            Row(
              children: [
                // Avatar with presence
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: DesignColors.accent.withValues(
                          alpha: 255, red: 255, green: 255, blue: 255),
                      backgroundImage: user.photos.isNotEmpty
                          ? NetworkImage(user.photos.first)
                          : null,
                      child: user.photos.isEmpty
                          ? Text(
                              user.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                color: DesignColors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: PresenceIndicator(
                        userId: user.id,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          color: DesignColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (user.age != null)
                        Text(
                          '${user.age} years old',
                          style: TextStyle(
                            color: DesignColors.white.withValues(
                                alpha: 255, red: 255, green: 255, blue: 255),
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            size: 14,
                            color: DesignColors.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${user.followersCount ?? 0} followers',
                            style: const TextStyle(
                              color: DesignColors.gold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Follow button
                isFollowingAsync.when(
                  data: (isFollowing) {
                    return NeonButton(
                      label: isFollowing ? 'Unfollow' : 'Follow',
                      onPressed: () async {
                        final service = ref.read(socialGraphServiceProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          if (isFollowing) {
                            await service.unfollowUser(user.id);
                          } else {
                            await service.followUser(user.id);
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(isFollowing
                                  ? 'Unfollowed'
                                  : 'Now following ${user.displayName}!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      glowColor:
                          isFollowing ? Colors.grey : DesignColors.accent,
                      width: 100,
                      height: 36,
                    );
                  },
                  loading: () => const SizedBox(
                    width: 100,
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),

            // Bio
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                user.bio!,
                style: TextStyle(
                  color: DesignColors.white
                      .withValues(alpha: 255, red: 255, green: 255, blue: 255),
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Interests
            if (user.interests != null && user.interests!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.interests!.take(5).map((interest) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: DesignColors.accent.withValues(
                          alpha: 255, red: 255, green: 255, blue: 255),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DesignColors.accent.withValues(
                            alpha: 255, red: 255, green: 255, blue: 255),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(
                        color: DesignColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // View profile button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/profile',
                    arguments: user.id,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: DesignColors.accent.withValues(
                          alpha: 255, red: 255, green: 255, blue: 255)),
                  foregroundColor: DesignColors.white,
                ),
                child: const Text('View Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: DesignColors.white
                .withValues(alpha: 255, red: 255, green: 255, blue: 255),
          ),
          const SizedBox(height: 16),
          Text(
            'No suggestions available',
            style: TextStyle(
              color: DesignColors.white
                  .withValues(alpha: 255, red: 255, green: 255, blue: 255),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try updating your interests in your profile',
            style: TextStyle(
              color: DesignColors.white,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
