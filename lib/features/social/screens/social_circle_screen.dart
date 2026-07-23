import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/layout/app_layout.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/social/providers/social_providers.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';

class SocialCircleScreen extends ConsumerWidget {
  const SocialCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hp = context.pageHorizontalPadding;
    final isWideLayout = MediaQuery.sizeOf(context).width >= 900;

    final followingUsersAsync = ref.watch(followingUsersProvider(uid));
    final liveFollowingAsync = ref.watch(followingLiveRoomsProvider(uid));
    final newMembersAsync = ref.watch(newMembersStreamProvider);

    final liveNowCount = liveFollowingAsync.valueOrNull?.length ?? 0;
    final followingCount = followingUsersAsync.valueOrNull?.length ?? 0;
    final freshCount = newMembersAsync.valueOrNull?.length ?? 0;

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      safeArea: false,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: VelvetNoir.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Circle',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.search_rounded,
                  color: VelvetNoir.onSurfaceVariant,
                ),
                onPressed: () => context.go('/search'),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hp, 8, hp, 14),
              child: _CircleOverviewCard(
                liveNowCount: liveNowCount,
                followingCount: followingCount,
                freshCount: freshCount,
                onExplore: () => context.go('/explore'),
                onSearch: () => context.go('/search'),
              ),
            ),
          ),

          // Live following section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hp, 0, hp, 10),
              child: _SectionHeader(
                title: 'Who is Live Now',
                subtitle: 'People you follow on the mic',
                icon: Icons.sensors_rounded,
                iconColor: VelvetNoir.liveGlow,
              ),
            ),
          ),
          liveFollowingAsync.when(
            loading: () => const SliverToBoxAdapter(child: _ShimmerStrip()),
            error: (__, _) => const SliverToBoxAdapter(child: SizedBox()),
            data: (rooms) {
              if (rooms.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hp),
                    child: _EmptyCard(
                      emoji: '🫶',
                      title: 'Your circle is quiet right now',
                      message: 'Follow more hosts or explore new rooms.',
                      actionLabel: 'Explore Rooms',
                      onTap: () => context.go('/explore'),
                    ),
                  ),
                );
              }
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: hp),
                    scrollDirection: Axis.horizontal,
                    itemCount: rooms.length,
                    separatorBuilder: (__, _) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) => SocialRoomCardCompact(
                      key: ValueKey(rooms[i].id),
                      room: rooms[i],
                      onTap: () => ctx.go('/room/${rooms[i].id}'),
                    ),
                  ),
                ),
              );
            },
          ),

          // Following list
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hp, 24, hp, 10),
              child: _SectionHeader(
                title: 'Following',
                subtitle: 'People in your circle',
                icon: Icons.favorite_outline_rounded,
                iconColor: VelvetNoir.primary,
              ),
            ),
          ),
          followingUsersAsync.when(
            loading: () => const SliverToBoxAdapter(child: _ShimmerList()),
            error: (__, _) => const SliverToBoxAdapter(child: SizedBox()),
            data: (users) {
              if (users.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hp),
                    child: _EmptyCard(
                      emoji: '👥',
                      title: 'No follows yet',
                      message:
                          'Discover people, follow them, and build your circle.',
                      actionLabel: 'Find People',
                      onTap: () => context.go('/search'),
                    ),
                  ),
                );
              }
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 92,
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: hp),
                    scrollDirection: Axis.horizontal,
                    itemCount: users.length,
                    separatorBuilder: (__, _) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) => _UserPill(
                      user: users[i],
                      onTap: () => ctx.go('/profile/${users[i].id}'),
                    ),
                  ),
                ),
              );
            },
          ),

          // Recently active users section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hp, 24, hp, 10),
              child: _SectionHeader(
                title: 'Recently Active',
                subtitle: 'Fresh faces and returning vibes',
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
          ),
          newMembersAsync.when(
            loading: () => const SliverToBoxAdapter(child: _ShimmerList()),
            error: (__, _) => const SliverToBoxAdapter(child: SizedBox()),
            data: (users) {
              if (isWideLayout) {
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: hp),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisExtent: 86,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 10,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _RecentlyActiveTile(
                        user: users[i],
                        onTap: () => ctx.go('/profile/${users[i].id}'),
                        compact: true,
                      ),
                      childCount: users.length,
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RecentlyActiveTile(
                    user: users[i],
                    onTap: () => ctx.go('/profile/${users[i].id}'),
                  ),
                  childCount: users.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _CircleOverviewCard extends StatelessWidget {
  const _CircleOverviewCard({
    required this.liveNowCount,
    required this.followingCount,
    required this.freshCount,
    required this.onExplore,
    required this.onSearch,
  });

  final int liveNowCount;
  final int followingCount;
  final int freshCount;
  final VoidCallback onExplore;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VelvetNoir.surfaceHigh,
            VelvetNoir.secondary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VelvetNoir.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your social floor',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: VelvetNoir.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'See who is live, who is close, and where the vibe is moving.',
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: 'Live now', value: '$liveNowCount'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(label: 'Following', value: '$followingCount'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(label: 'Fresh faces', value: '$freshCount'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Explore Rooms'),
              ),
              OutlinedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('Find People'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: VelvetNoir.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.raleway(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.raleway(
                fontSize: 11,
                color: VelvetNoir.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserPill extends StatelessWidget {
  const _UserPill({required this.user, required this.onTap});

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: VelvetNoir.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: VelvetNoir.primary.withValues(alpha: 0.22),
              child: Text(
                initials,
                style: GoogleFonts.raleway(
                  fontWeight: FontWeight.w700,
                  color: VelvetNoir.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.raleway(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: VelvetNoir.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentlyActiveTile extends StatelessWidget {
  const _RecentlyActiveTile({
    required this.user,
    required this.onTap,
    this.compact = false,
  });

  final UserModel user;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final initials = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: VelvetNoir.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: compact ? 18 : 20,
              backgroundColor: VelvetNoir.secondary.withValues(alpha: 0.22),
              child: Text(
                initials,
                style: GoogleFonts.raleway(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  color: VelvetNoir.secondaryBright,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.raleway(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w700,
                      color: VelvetNoir.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    user.bio?.trim().isNotEmpty == true
                        ? user.bio!
                        : 'Open to connect',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.raleway(
                      fontSize: 11,
                      color: VelvetNoir.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.emoji,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: VelvetNoir.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [VelvetNoir.primary, VelvetNoir.primaryDim],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.raleway(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: VelvetNoir.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerStrip extends StatelessWidget {
  const _ShimmerStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(
          3,
          (i) => Container(
            width: 160,
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: VelvetNoir.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 78,
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}



