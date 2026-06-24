// lib/features/discover/screens/active_now_page.dart
//
// ActiveNowPage – full-page list of users currently online or away.
// Uses activeNowUsersProvider (StreamProvider) backed by `presence` collection.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/widgets/club_background.dart';
import '../../../shared/widgets/neon_components.dart';
import '../../../shared/widgets/social_graph_widgets.dart';
import '../../../shared/providers/discovery_providers.dart';
import 'package:mixvy/core/routing/app_routes.dart';

/// Full-page screen showing users who are online or away right now.
class ActiveNowPage extends ConsumerWidget {
  const ActiveNowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeNowUsersProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: DesignColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const NeonText(
                'ACTIVE NOW',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                textColor: DesignColors.white,
                glowColor: DesignColors.success,
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: activeAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(activeNowUsersProvider),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _ActiveUserCard(
                    user: user,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.userProfile,
                      arguments: user.id,
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: DesignColors.success),
          ),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: DesignColors.error, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load active users',
                  style: DesignTypography.body
                      .copyWith(color: DesignColors.white),
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
          Icon(Icons.wifi_off_rounded,
              size: 64,
              color: DesignColors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No one active right now',
            style: DesignTypography.heading.copyWith(
              color: DesignColors.white.withValues(alpha: 0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Come back during peak hours!',
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
// Single active user card (grid item)
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveUserCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback onTap;

  const _ActiveUserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photos = user.photos as List? ?? [];
    final displayName = (user.displayName as String?) ?? 'Unknown';
    final followersCount = (user.followersCount as int?) ?? 0;

    return NeonGlowCard(
      glowColor: DesignColors.success,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with presence indicator
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor:
                        DesignColors.success.withValues(alpha: 0.2),
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
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  PresenceIndicator(
                    userId: user.id as String,
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Display name
              Text(
                displayName,
                style: DesignTypography.body.copyWith(
                  color: DesignColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),

              // Follower count
              Text(
                '$followersCount followers',
                style: DesignTypography.caption.copyWith(
                  color: DesignColors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),

              // Follow button
              FollowButton(userId: user.id as String, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

