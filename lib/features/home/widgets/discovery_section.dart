// lib/features/home/widgets/discovery_section.dart
//
// Reusable horizontal discovery sections for the home page.
//
// Widgets exported:
//   DiscoveryUserSection   – horizontal scrollable row of user avatar cards
//   DiscoveryRoomSection   – horizontal scrollable row of room cards
//
// Each section shows:
//   - A header with title + live-count badge + "See All" link
//   - Compact avatar/room cards in a horizontal ListView
//   - Graceful loading and empty states (no errors shown inline)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/providers/discovery_providers.dart';
import '../../../shared/widgets/presence_indicator.dart';
import '../../../shared/models/room.dart';
import 'package:mixvy/core/routing/app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Suggested for You – horizontal user row
// ─────────────────────────────────────────────────────────────────────────────
class SuggestedForYouSection extends ConsumerWidget {
  const SuggestedForYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestedUsersProvider);
    return _DiscoveryUserSection(
      title: 'SUGGESTED FOR YOU',
      glowColor: DesignColors.accent,
      icon: Icons.person_add_rounded,
      seeAllRoute: AppRoutes.suggestedUsers,
      asyncValue: async,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trending Now – horizontal user row
// ─────────────────────────────────────────────────────────────────────────────
class TrendingNowSection extends ConsumerWidget {
  const TrendingNowSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trendingUsersProvider);
    return _DiscoveryUserSection(
      title: 'TRENDING NOW',
      glowColor: DesignColors.gold,
      icon: Icons.trending_up_rounded,
      seeAllRoute: AppRoutes.trendingUsers,
      asyncValue: async,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Now – horizontal user row (global online users, not just friends)
// ─────────────────────────────────────────────────────────────────────────────
class ActiveNowSection extends ConsumerWidget {
  const ActiveNowSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeNowUsersProvider);
    return _DiscoveryUserSection(
      title: 'ACTIVE NOW',
      glowColor: DesignColors.success,
      icon: Icons.circle,
      seeAllRoute: AppRoutes.activeNow,
      asyncValue: async,
      showPresencePulse: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Discover Rooms – horizontal room row
// ─────────────────────────────────────────────────────────────────────────────
class DiscoverRoomsSection extends ConsumerWidget {
  const DiscoverRoomsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discoverableRoomsProvider);
    return async.when(
      data: (rooms) {
        if (rooms.isEmpty) return const SizedBox.shrink();
        return _SectionWrapper(
          title: 'DISCOVER ROOMS',
          count: rooms.length,
          glowColor: DesignColors.accent,
          icon: Icons.live_tv_rounded,
          seeAllRoute: AppRoutes.discoverRoomsLive,
          child: SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _RoomMiniCard(room: rooms[index]),
            ),
          ),
        );
      },
      loading: () => const _SectionLoadingPlaceholder(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: generic user discovery section
// ─────────────────────────────────────────────────────────────────────────────
class _DiscoveryUserSection extends StatelessWidget {
  final String title;
  final Color glowColor;
  final IconData icon;
  final String seeAllRoute;
  final AsyncValue<List<dynamic>> asyncValue;
  final bool showPresencePulse;

  const _DiscoveryUserSection({
    required this.title,
    required this.glowColor,
    required this.icon,
    required this.seeAllRoute,
    required this.asyncValue,
    this.showPresencePulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return _SectionWrapper(
          title: title,
          count: users.length,
          glowColor: glowColor,
          icon: icon,
          seeAllRoute: seeAllRoute,
          child: SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserMiniCard(
                  user: user,
                  glowColor: glowColor,
                  showPresencePulse: showPresencePulse,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.userProfile,
                    arguments: user.id as String,
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const _SectionLoadingPlaceholder(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header + content wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SectionWrapper extends StatelessWidget {
  final String title;
  final int count;
  final Color glowColor;
  final IconData icon;
  final String seeAllRoute;
  final Widget child;

  const _SectionWrapper({
    required this.title,
    required this.count,
    required this.glowColor,
    required this.icon,
    required this.seeAllRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: glowColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: DesignTypography.caption.copyWith(
                  color: glowColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: glowColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, seeAllRoute),
                child: Text(
                  'See All',
                  style: DesignTypography.caption.copyWith(
                    color: glowColor.withValues(alpha: 0.8),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact user avatar card for horizontal rows
// ─────────────────────────────────────────────────────────────────────────────
class _UserMiniCard extends StatelessWidget {
  final dynamic user;
  final Color glowColor;
  final bool showPresencePulse;
  final VoidCallback onTap;

  const _UserMiniCard({
    required this.user,
    required this.glowColor,
    required this.onTap,
    this.showPresencePulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final photos = user.photos as List? ?? [];
    final displayName = (user.displayName as String?) ?? '?';
    final userId = user.id as String;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with optional presence indicator
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: glowColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photos.isNotEmpty
                        ? Image.network(
                            photos.first as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _initialsAvatar(displayName),
                          )
                        : _initialsAvatar(displayName),
                  ),
                ),
                if (showPresencePulse)
                  PresenceIndicator(userId: userId, size: 12),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              displayName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DesignColors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialsAvatar(String name) {
    return Container(
      color: DesignColors.surfaceLight,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: DesignColors.white.withValues(alpha: 0.9),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact room card for horizontal row
// ─────────────────────────────────────────────────────────────────────────────
class _RoomMiniCard extends StatelessWidget {
  final Room room;

  const _RoomMiniCard({required this.room});

  IconData get _icon {
    switch (room.category.toLowerCase()) {
      case 'music':
        return Icons.music_note_rounded;
      case 'gaming':
        return Icons.sports_esports_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'technology':
        return Icons.computer_rounded;
      default:
        return Icons.groups_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.room,
        arguments: room.id,
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              DesignColors.surfaceDefault,
              DesignColors.surfaceLight.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: DesignColors.accent.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: DesignColors.accent.withValues(alpha: 0.12),
              blurRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + LIVE badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: DesignColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_icon, color: DesignColors.accent, size: 18),
                ),
                const Spacer(),
                if (room.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: DesignColors.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: DesignColors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Room title
            Text(
              room.title,
              style: DesignTypography.body.copyWith(
                color: DesignColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Viewer count
            Row(
              children: [
                const Icon(Icons.remove_red_eye_rounded,
                    size: 11, color: DesignColors.white),
                const SizedBox(width: 3),
                Text(
                  '${room.viewerCount}',
                  style: DesignTypography.caption.copyWith(
                    color: DesignColors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading placeholder (shimmer-style animated bar)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLoadingPlaceholder extends StatelessWidget {
  const _SectionLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      child: SizedBox(
        height: 108,
        child: Row(
          children: List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DesignColors.surfaceLight.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 48,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: DesignColors.surfaceLight.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

