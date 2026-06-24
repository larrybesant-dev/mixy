// lib/features/discover/screens/trending_users_page.dart
//
// TrendingUsersPage – scrollable list of top users ranked by follower count.
// Uses trendingUsersProvider (StreamProvider) for real-time Firestore updates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/widgets/club_background.dart';
import '../../../shared/widgets/neon_components.dart';
import '../../../shared/widgets/social_graph_widgets.dart';
import '../../../shared/providers/discovery_providers.dart';
import 'package:mixvy/core/routing/app_routes.dart';

/// Full-page screen showing the top users by follower count.
class TrendingUsersPage extends ConsumerWidget {
  const TrendingUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingUsersProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const NeonText(
            'TRENDING NOW',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            textColor: DesignColors.white,
            glowColor: DesignColors.gold,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: trendingAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return _buildEmptyState();
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _TrendingUserCard(
                  user: user,
                  rank: index + 1,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.userProfile,
                    arguments: user.id,
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: DesignColors.gold),
          ),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: DesignColors.error, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load trending users',
                  style: DesignTypography.body.copyWith(color: DesignColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, size: 64,
              color: DesignColors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No trending users yet',
            style: DesignTypography.heading.copyWith(
              color: DesignColors.white.withValues(alpha: 0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon as the community grows!',
            style: DesignTypography.body.copyWith(
              color: DesignColors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single trending user card with rank badge
// ─────────────────────────────────────────────────────────────────────────────
class _TrendingUserCard extends StatelessWidget {
  final dynamic user;
  final int rank;
  final VoidCallback onTap;

  const _TrendingUserCard({
    required this.user,
    required this.rank,
    required this.onTap,
  });

  Color get _rankColor {
    if (rank == 1) return DesignColors.gold;
    if (rank == 2) return const Color(0xFFC0C0C0); // silver
    if (rank == 3) return const Color(0xFFCD7F32); // bronze
    return DesignColors.white.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final photos = user.photos as List? ?? [];
    final displayName = (user.displayName as String?) ?? 'Unknown';
    final followersCount = (user.followersCount as int?) ?? 0;
    final bio = user.bio as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonGlowCard(
        glowColor: rank <= 3 ? _rankColor : DesignColors.accent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Rank badge
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    style: DesignTypography.heading.copyWith(
                      color: _rankColor,
                      fontSize: rank <= 3 ? 18 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar with presence
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: DesignColors.accent.withValues(alpha: 0.3),
                      backgroundImage: photos.isNotEmpty
                          ? NetworkImage(photos.first as String)
                          : null,
                      child: photos.isEmpty
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: DesignColors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: PresenceIndicator(userId: user.id as String, size: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Name + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: DesignTypography.heading.copyWith(
                          color: DesignColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          bio,
                          style: DesignTypography.caption.copyWith(
                            color: DesignColors.white.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.people, size: 13, color: DesignColors.gold),
                          const SizedBox(width: 4),
                          Text(
                            '$followersCount followers',
                            style: DesignTypography.caption.copyWith(
                              color: DesignColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Follow button
                FollowButton(userId: user.id as String, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

