import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/safe_network_avatar.dart';
import '../../core/layout/app_layout.dart';
import '../../core/routing/auth_invariant.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/guest_auth_gate.dart';
import '../feed/controllers/paginated_posts_controller.dart';
import '../feed/providers/feed_providers.dart';
import '../feed/widgets/post_card.dart';
import '../profile/profile_completion.dart';
import '../profile/profile_controller.dart';
import 'leaderboard_provider.dart';
import '../../presentation/providers/user_provider.dart';
import '../../models/room_model.dart';
import '../stories/widgets/stories_row.dart';
import 'daily_checkin_card.dart';
import 'leaderboard_strip.dart';
import 'widgets/social_pulse_section.dart';
import '../onboarding/session_stage_controller.dart';
import '../feed/models/home_feed_snapshot.dart';
import '../../models/user_model.dart';
import '../../widgets/brand_ui_kit.dart';
import '../../shared/widgets/canonical_ui_state.dart';
import '../../observability/startup_timeline.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(paginatedPostsProvider.notifier).loadPosts();
      }
    });
  }

  void _showNavigationError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openRoom(String? roomId) {
    final normalizedRoomId = roomId?.trim() ?? '';
    if (normalizedRoomId.isEmpty) {
      _showNavigationError('This room is unavailable right now.');
      return;
    }
    context.go('/room/${Uri.encodeComponent(normalizedRoomId)}');
  }

  void _openProfile(String? userId) {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) {
      _showNavigationError('This profile is unavailable right now.');
      return;
    }
    context.go('/profile/${Uri.encodeComponent(normalizedUserId)}');
  }

  void _openPulseItem(PulseFeedItem item) {
    if (item.isQuietState) {
      context.go('/rooms');
      return;
    }

    if (item.type == 'room_momentum') {
      final id = item.id.trim();
      if (id.startsWith('room:')) {
        _openRoom(id.substring('room:'.length));
        return;
      }
      context.go('/rooms');
      return;
    }

    context.go('/search');
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refreshDashboard() async {
    ref.invalidate(paginatedPostsProvider);
    ref.invalidate(roomsStreamProvider);
    ref.invalidate(onlineUsersCountProvider);
    ref.invalidate(liveRoomsCountProvider);
    ref.invalidate(newMembersStreamProvider);
    ref.invalidate(trendingUsersStreamProvider);
    ref.invalidate(currentUserActivitiesProvider);
    ref.invalidate(homeFeedSnapshotProvider);
    ref.invalidate(leaderboardProvider);
    ref.invalidate(dailyCheckinProvider);

    await Future.wait([
      ref.read(postsStreamProvider.future),
      ref.read(roomsStreamProvider.future),
      ref.read(onlineUsersCountProvider.future),
      ref.read(liveRoomsCountProvider.future),
      ref.read(newMembersStreamProvider.future),
      ref.read(trendingUsersStreamProvider.future),
      ref.read(currentUserActivitiesProvider.future),
      ref.read(leaderboardProvider.future),
      ref.read(dailyCheckinProvider.future),
    ]);
  }

  Future<void> _completeFirstSessionAndGo(String route) async {
    StartupProfiler.instance.markFirstUserAction(
      context: 'first_session_entry',
    );
    await ref
        .read(sessionStageProvider.notifier)
        .completeFirstSessionAction();
    if (!mounted) {
      return;
    }
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(paginatedPostsProvider);
    final roomsAsync = ref.watch(roomsStreamProvider);
    final trendingUsersAsync = ref.watch(trendingUsersStreamProvider);
    final profileState = ref.watch(profileControllerProvider);
    final setupItems = ProfileCompletion.homeNudgeItems(profileState);
    final currentUser = ref.watch(userProvider);
    final sessionStage = ref.watch(sessionStageProvider);
    if (currentUser == null) {
      return AuthInvariant.redirectToAuth();
    }

    if (sessionStage == SessionStage.loading) {
      return const AppPageScaffold(
        backgroundColor: VelvetNoir.surface,
        body: Padding(
          padding: EdgeInsets.all(16),
          child: LoadingState(
            title: 'Preparing your home',
            subtitle: 'Your first interactive view is loading now.',
          ),
        ),
      );
    }

    if (sessionStage == SessionStage.firstTime) {
      return AppPageScaffold(
        backgroundColor: VelvetNoir.surface,
        safeArea: false,
        body: _FirstSessionEntry(
          onPrimaryAction: () => _completeFirstSessionAndGo('/search'),
          onSecondaryAction: () => _completeFirstSessionAndGo('/rooms/create'),
        ),
      );
    }

    final newMembersAsync = ref.watch(newMembersStreamProvider);
    final homeFeedAsync = ref.watch(homeFeedSnapshotProvider);

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      safeArea: false,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: VelvetNoir.surface,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 16,
            title: Row(
              children: [
                // Current user avatar
                GestureDetector(
                  onTap: () {
                    final uid = currentUser.id;
                    if (uid.isNotEmpty) {
                      context.go('/profile/$uid');
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: VelvetNoir.primary.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      gradient: const RadialGradient(
                        colors: [Color(0xFF2A1A0A), Color(0xFF0B0B0B)],
                      ),
                    ),
                    child: ClipOval(
                      child: (currentUser.avatarUrl ?? '').isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: currentUser.avatarUrl!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                currentUser.username.isNotEmpty
                                    ? currentUser.username[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: VelvetNoir.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_greeting()}, ${currentUser.username}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: VelvetNoir.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: MixvyAppBarLogo(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            centerTitle: false,
            actions: [
              _StatsBarWidget(
                onlineAsync: ref.watch(onlineUsersCountProvider),
                liveAsync: ref.watch(liveRoomsCountProvider),
                isFirstSession: sessionStage == SessionStage.firstTime,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: VelvetNoir.onSurface,
                ),
                tooltip: 'Create',
                onPressed: () => _showCreateMenu(context, ref),
              ),
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: VelvetNoir.onSurface,
                ),
                onPressed: () => context.go('/notifications'),
              ),
            ],
          ),
        ],
        body: RefreshIndicator(
          color: VelvetNoir.primary,
          backgroundColor: VelvetNoir.surfaceHigh,
          onRefresh: _refreshDashboard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // MIX / CONNECT / INDULGE nav cards
              const SliverToBoxAdapter(child: _BrandNavCards()),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),

              // Stories
              const SliverToBoxAdapter(child: StoriesRow()),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),

              // Daily check-in
              const SliverToBoxAdapter(child: DailyCheckinCard()),

              // Hall of Fame leaderboard
              const SliverToBoxAdapter(child: LeaderboardStrip()),

              // Profile nudge
              if (setupItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _ProfileNudge(
                      setupItems: setupItems,
                      profileState: profileState,
                    ),
                  ),
                ),

              // Live Now header
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Live Now',
                  dotColor: VelvetNoir.liveGlow,
                  topPadding: 20,
                  trailing: TextButton(
                    onPressed: () => context.go('/rooms'),
                    child: const Text(
                      'See all',
                      style: TextStyle(color: VelvetNoir.primary, fontSize: 13),
                    ),
                  ),
                ),
              ),

              // Live rooms — circular avatar tiles
              SliverToBoxAdapter(
                child: roomsAsync.when(
                  data: (rooms) => rooms.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: EmptyState(
                            title: 'Rooms are warming up',
                            message:
                                'Start a room and set the energy for everyone arriving now.',
                            ctaLabel: 'Start a Room',
                            onCta: () => context.go('/create-room'),
                            icon: Icons.mic_rounded,
                          ),
                        )
                      : SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.pageHorizontalPadding,
                              vertical: 4,
                            ),
                            itemCount: rooms.length.clamp(0, 12),
                            separatorBuilder: (ctx, idx) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, i) => _LiveNowTile(
                              key: ValueKey(rooms[i].id),
                              room: rooms[i],
                              onTap: () => _openRoom(rooms[i].id),
                            ),
                          ),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LoadingState(
                      title: 'Loading live rooms',
                      subtitle: 'Fetching active rooms around you.',
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ErrorState(
                      title: 'Could not load live rooms',
                      message: 'Check your connection and try again.',
                      ctaLabel: 'Retry',
                      onCta: () => ref.invalidate(roomsStreamProvider),
                    ),
                  ),
                ),
              ),

              // SOCIAL PULSE section
              SliverToBoxAdapter(
                child: homeFeedAsync.when(
                  data: (snapshot) => SocialPulseSection(
                    pulseItems: snapshot.pulseItems,
                    headline: snapshot.headline,
                    subheadline: snapshot.subheadline,
                    liveRoomCount: snapshot.liveRooms.length,
                    suggestionCount: snapshot.suggestedUsers.length,
                    onOpenPulseItem: _openPulseItem,
                    onOpenRooms: () => context.go('/rooms'),
                    onOpenDiscover: () => context.go('/search'),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _HorizontalSkeleton(height: 190),
                  ),
                  error: (_, _) => SocialPulseSection(
                    pulseItems: [
                      PulseFeedItem(
                        id: 'pulse:fallback',
                        type: 'system_trending',
                        title: 'New rooms are trending right now',
                        detail: 'Jump in and find your people.',
                        timestamp: DateTime.now(),
                      ),
                    ],
                    onOpenPulseItem: _openPulseItem,
                    onOpenRooms: () => context.go('/rooms'),
                    onOpenDiscover: () => context.go('/search'),
                  ),
                ),
              ),

              // DISCOVER PEOPLE section
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Discover People',
                  dotColor: VelvetNoir.secondary,
                  topPadding: 24,
                  trailing: TextButton(
                    onPressed: () => context.go('/search'),
                    child: const Text(
                      'See all',
                      style: TextStyle(color: VelvetNoir.primary, fontSize: 13),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: trendingUsersAsync.when(
                  data: (users) => users.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: EmptyState(
                            title: 'New people are loading in',
                            message:
                                'Explore profiles and connect with your first matches.',
                            ctaLabel: 'Find People',
                            onCta: () => context.go('/search'),
                            icon: Icons.favorite_outline_rounded,
                          ),
                        )
                      : SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.pageHorizontalPadding,
                              vertical: 4,
                            ),
                            itemCount: users.length.clamp(0, 10),
                            separatorBuilder: (ctx, idx) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) => _DiscoverPersonCard(
                              user: users[i],
                              onTap: () => _openProfile(users[i].id),
                            ),
                          ),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LoadingState(
                      title: 'Loading people',
                      subtitle: 'Finding profiles worth your attention.',
                    ),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ErrorState(
                      title: 'Could not load people right now',
                      message: 'We could not fetch discover suggestions.',
                      ctaLabel: 'Retry',
                      onCta: () => ref.invalidate(trendingUsersStreamProvider),
                    ),
                  ),
                ),
              ),

              // POPULAR ROOMS section
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Popular Rooms',
                  dotColor: VelvetNoir.liveGlow,
                  topPadding: 24,
                  trailing: TextButton(
                    onPressed: () => context.go('/rooms'),
                    child: const Text(
                      'Browse',
                      style: TextStyle(color: VelvetNoir.primary, fontSize: 13),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: roomsAsync.when(
                  data: (rooms) => rooms.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: EmptyState(
                            title: 'No featured rooms yet',
                            message:
                                'Create one room to spark conversation and pull people in.',
                            ctaLabel: 'Start a Room',
                            onCta: () => context.go('/create-room'),
                            icon: Icons.graphic_eq_rounded,
                          ),
                        )
                      : SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.pageHorizontalPadding,
                              vertical: 4,
                            ),
                            itemCount: rooms.length.clamp(0, 8),
                            separatorBuilder: (ctx, idx) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) => _PopularRoomCard(
                              key: ValueKey(rooms[i].id),
                              room: rooms[i],
                              onTap: () => _openRoom(rooms[i].id),
                            ),
                          ),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LoadingState(
                      title: 'Loading featured rooms',
                      subtitle: 'Curating live rooms for quick join.',
                    ),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ErrorState(
                      title: 'Featured rooms unavailable',
                      message: 'Room recommendations are temporarily unavailable.',
                      ctaLabel: 'Retry',
                      onCta: () => ref.invalidate(roomsStreamProvider),
                    ),
                  ),
                ),
              ),

              // VIP LOUNGE banner
              const SliverToBoxAdapter(child: _VipLoungeBanner()),

              // New Members
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'New Members',
                  dotColor: VelvetNoir.primary,
                  topPadding: 24,
                ),
              ),
              SliverToBoxAdapter(
                child: newMembersAsync.when(
                  data: (members) => members.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: EmptyState(
                            title: 'Fresh members are arriving',
                            message:
                                'Use discover to meet the newest people in your circle.',
                            ctaLabel: 'Open Discover',
                            onCta: () => context.go('/search'),
                            icon: Icons.person_add_alt_1_rounded,
                          ),
                        )
                      : SizedBox(
                          height: 88,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.pageHorizontalPadding,
                              vertical: 4,
                            ),
                            itemCount: members.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 16),
                            itemBuilder: (ctx, i) => _NewMemberChip(
                              key: ValueKey(members[i].id),
                              user: members[i],
                              onTap: () => _openProfile(members[i].id),
                            ),
                          ),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LoadingState(
                      title: 'Loading new members',
                      subtitle: 'Bringing recent arrivals into view.',
                    ),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ErrorState(
                      title: 'Could not load new members',
                      message: 'Recent member updates are temporarily unavailable.',
                      ctaLabel: 'Retry',
                      onCta: () => ref.invalidate(newMembersStreamProvider),
                    ),
                  ),
                ),
              ),

              // Recent Posts header
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Recent Activity',
                  dotColor: VelvetNoir.primary,
                  topPadding: 24,
                ),
              ),

              // Posts feed
              if (postsState.posts.isEmpty && postsState.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LoadingState(
                      title: 'Loading recent activity',
                      subtitle: 'Preparing posts and conversation starters.',
                    ),
                  ),
                )
              else if (postsState.posts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EmptyState(
                      title: 'No posts yet',
                      message:
                          'Share the first moment so people have something to react to.',
                      ctaLabel: 'Create a Post',
                      onCta: () => context.go('/create-post'),
                      icon: Icons.edit_note_rounded,
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: postsState.posts.length,
                  itemBuilder: (ctx, i) => PostCard(
                    post: postsState.posts[i],
                    currentUserId: currentUser?.id ?? '',
                  ),
                ),

              if (postsState.hasMore && postsState.posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: postsState.isLoading
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(paginatedPostsProvider.notifier)
                                  .loadPosts(),
                              child: const Text('Load More'),
                            ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstSessionEntry extends StatelessWidget {
  const _FirstSessionEntry({
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VelvetNoir.surfaceHigh,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: VelvetNoir.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to MixVy',
                  style: GoogleFonts.playfairDisplay(
                    color: VelvetNoir.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Start with one move and your home feed will unlock around your vibe.',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onPrimaryAction,
                  icon: const Icon(Icons.favorite_outline_rounded),
                  label: const Text('Find People'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VelvetNoir.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onSecondaryAction,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: const Text('Start a Room'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VelvetNoir.onSurface,
                    side: BorderSide(
                      color: VelvetNoir.onSurface.withValues(alpha: 0.30),
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats bar (online count + live rooms count) shown in the AppBar actions
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBarWidget extends StatelessWidget {
  final AsyncValue<int> onlineAsync;
  final AsyncValue<int> liveAsync;
  final bool isFirstSession;

  const _StatsBarWidget({
    required this.onlineAsync,
    required this.liveAsync,
    this.isFirstSession = false,
  });

  @override
  Widget build(BuildContext context) {
    final online = onlineAsync.valueOrNull ?? 0;
    final live = liveAsync.valueOrNull ?? 0;
    final isLoading = onlineAsync.isLoading || liveAsync.isLoading;
    final onlineLabel = isLoading
        ? '...'
        : (online <= 0 || isFirstSession)
        ? 'new'
        : (online >= 500 ? '500+' : '$online');
    final liveLabel = isLoading
        ? '...'
        : (live <= 0 || isFirstSession)
        ? 'fresh'
        : '$live';

    return Row(
      children: [
        _StatPill(
          dot: VelvetNoir.primary,
          label: onlineLabel,
          tooltip: 'online now',
        ),
        const SizedBox(width: 6),
        _StatPill(
          dot: VelvetNoir.liveGlow,
          label: liveLabel,
          tooltip: 'live rooms',
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final Color dot;
  final String label;
  final String tooltip;
  const _StatPill({
    required this.dot,
    required this.label,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: VelvetNoir.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header with coloured left bar
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color dotColor;
  final double topPadding;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.dotColor,
    this.topPadding = 0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: VelvetNoir.onSurface,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New Member chip: avatar + username + "NEW" badge
// ─────────────────────────────────────────────────────────────────────────────

class _NewMemberChip extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _NewMemberChip({required this.user, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VelvetNoir.primary.withValues(alpha: 0.25),
                  border: Border.all(color: VelvetNoir.primary, width: 2),
                ),
                child: SafeNetworkAvatar(
                  radius: 26,
                  avatarUrl: avatarUrl,
                  backgroundColor: VelvetNoir.surfaceHigh,
                  fallbackText: user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?',
                  fallbackTextStyle: const TextStyle(
                    color: VelvetNoir.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: VelvetNoir.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: VelvetNoir.surface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              user.username,
              style: const TextStyle(
                fontSize: 10,
                color: VelvetNoir.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Now circular tile
// ─────────────────────────────────────────────────────────────────────────────

class _LiveNowTile extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;
  const _LiveNowTile({super.key, required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasThumb = (room.thumbnailUrl ?? '').isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: VelvetNoir.liveGlow, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: VelvetNoir.liveGlow.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasThumb
                        ? CachedNetworkImage(
                            imageUrl: room.thumbnailUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: VelvetNoir.surfaceHigh,
                            child: Center(
                              child: Text(
                                room.name.isNotEmpty
                                    ? room.name[0].toUpperCase()
                                    : 'R',
                                style: const TextStyle(
                                  color: VelvetNoir.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                // LIVE badge
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: VelvetNoir.liveGlow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Participant count
                if (room.memberCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: VelvetNoir.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: VelvetNoir.liveGlow,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        room.memberCount > 999
                            ? '${(room.memberCount / 1000).toStringAsFixed(1)}k'
                            : '${room.memberCount}',
                        style: const TextStyle(
                          color: VelvetNoir.onSurface,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              room.name,
              style: GoogleFonts.raleway(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: VelvetNoir.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Discover Person card — portrait photo card
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverPersonCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _DiscoverPersonCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VelvetNoir.primary.withValues(alpha: 0.18)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo / gradient bg
              avatarUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            VelvetNoir.secondary.withValues(alpha: 0.4),
                            VelvetNoir.surface,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: VelvetNoir.primary,
                          ),
                        ),
                      ),
                    ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
              // Name + online indicator
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  user.username,
                  style: GoogleFonts.raleway(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Connect button
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: VelvetNoir.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Popular Room card — wide cover card
// ─────────────────────────────────────────────────────────────────────────────

class _PopularRoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;
  const _PopularRoomCard({super.key, required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasThumb = (room.thumbnailUrl ?? '').isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VelvetNoir.liveGlow.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasThumb
                  ? CachedNetworkImage(
                      imageUrl: room.thumbnailUrl!,
                      fit: BoxFit.cover,
                    )
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A0810), Color(0xFF0B0B0B)],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.mic_external_on_rounded,
                          color: VelvetNoir.primary.withValues(alpha: 0.3),
                          size: 48,
                        ),
                      ),
                    ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.82),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),
              // LIVE tag + participant count (top)
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: VelvetNoir.liveGlow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        room.isLive ? 'LIVE' : 'ROOM',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${room.memberCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Room name (bottom)
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Text(
                  room.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIP Lounge banner
// ─────────────────────────────────────────────────────────────────────────────

class _VipLoungeBanner extends StatelessWidget {
  const _VipLoungeBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
      child: GestureDetector(
        onTap: () => context.go('/vip'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1E05), Color(0xFF1A1200), Color(0xFF0B0B0B)],
            ),
            border: Border.all(
              color: VelvetNoir.primary.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: VelvetNoir.primary.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFF8C6020)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VelvetNoir.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VIP LOUNGE',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: VelvetNoir.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Unlock exclusive features & rooms',
                      style: GoogleFonts.raleway(
                        fontSize: 12,
                        color: VelvetNoir.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFF8C6020)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'GO VIP',
                  style: GoogleFonts.raleway(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile nudge banner
// ─────────────────────────────────────────────────────────────────────────────

/// Maps the first incomplete nudge item to the edit-profile tab index:
/// 0 = Basics (name / avatar), 1 = About (bio), 2 = Interests
int _nudgeTab(List<String> items) {
  if (items.isEmpty) return 0;
  final first = items.first;
  if (first == 'Write a short bio') return 1;
  if (first == 'Add interests') return 2;
  return 0;
}

class _ProfileNudge extends StatelessWidget {
  final List<String> setupItems;
  final ProfileState profileState;
  const _ProfileNudge({required this.setupItems, required this.profileState});

  @override
  Widget build(BuildContext context) {
    final pct = (ProfileCompletion.homeNudgeCompleteness(profileState) * 100)
        .round();
    final isAlmostDone = pct >= 70;
    final Color accent = isAlmostDone
        ? VelvetNoir.secondary
        : VelvetNoir.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          final tab = _nudgeTab(setupItems);
          context.go('/edit-profile?tab=$tab');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAlmostDone ? 'Almost there!' : 'Complete your profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    Text(
                      '${setupItems.length} step${setupItems.length == 1 ? '' : 's'} left',
                      style: const TextStyle(
                        fontSize: 11,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: VelvetNoir.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create menu with NeonPulse bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showCreateMenu(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: VelvetNoir.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Wrap(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: VelvetNoir.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.article_outlined,
            color: VelvetNoir.primary,
          ),
          title: const Text(
            'New Post',
            style: TextStyle(color: VelvetNoir.onSurface),
          ),
          onTap: () async {
            final allowed = await GuestAuthGate.requirePostCreation(
              context,
              ref,
            );
            if (!allowed || !context.mounted) return;
            Navigator.pop(context);
            context.go('/create-post');
          },
        ),
        ListTile(
          leading: const Icon(
            Icons.auto_stories_outlined,
            color: VelvetNoir.secondary,
          ),
          title: const Text(
            'New Story',
            style: TextStyle(color: VelvetNoir.onSurface),
          ),
          onTap: () async {
            final allowed = await GuestAuthGate.requireStoryCreation(
              context,
              ref,
            );
            if (!allowed || !context.mounted) return;
            Navigator.pop(context);
            context.go('/create-story');
          },
        ),
        ListTile(
          leading: const Icon(
            Icons.meeting_room_outlined,
            color: VelvetNoir.primaryDim,
          ),
          title: const Text(
            'Host Room',
            style: TextStyle(color: VelvetNoir.onSurface),
          ),
          onTap: () async {
            final allowed = await GuestAuthGate.requireRoomCreation(
              context,
              ref,
            );
            if (!allowed || !context.mounted) return;
            Navigator.pop(context);
            context.go('/create-room');
          },
        ),
        ListTile(
          leading: const Icon(
            Icons.group_add_outlined,
            color: VelvetNoir.secondaryBright,
          ),
          title: const Text(
            'New Group',
            style: TextStyle(color: VelvetNoir.onSurface),
          ),
          onTap: () async {
            final allowed = await GuestAuthGate.requireGroupCreation(
              context,
              ref,
            );
            if (!allowed || !context.mounted) return;
            Navigator.pop(context);
            context.go('/create-group');
          },
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state pill
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPill extends StatelessWidget {
  final String label;
  const _EmptyPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: VelvetNoir.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline error card
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: VelvetNoir.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VelvetNoir.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: VelvetNoir.error),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: VelvetNoir.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalSkeleton extends StatelessWidget {
  final double height;
  const _HorizontalSkeleton({this.height = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Container(
          width: height < 100 ? 60 : 140,
          height: height,
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MIX · CONNECT · INDULGE — brand navigation cards
// ─────────────────────────────────────────────────────────────────────────────

class _BrandNavCards extends StatelessWidget {
  const _BrandNavCards();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _NavCard(
              label: 'MIX',
              sub: 'Discover people',
              icon: Icons.people_alt_rounded,
              accent: VelvetNoir.primary,
              onTap: () => context.go('/search'),
            ),
            const SizedBox(width: 10),
            _NavCard(
              label: 'CONNECT',
              sub: 'Messages',
              icon: Icons.chat_bubble_outline_rounded,
              accent: VelvetNoir.secondaryBright,
              onTap: () => context.go('/home?tab=1'),
            ),
            const SizedBox(width: 10),
            _NavCard(
              label: 'LIVE',
              sub: 'Join live rooms',
              icon: Icons.mic_external_on_rounded,
              accent: VelvetNoir.liveGlow,
              onTap: () => context.go('/rooms'),
            ),
            const SizedBox(width: 10),
            _NavCard(
              label: 'DATE',
              sub: 'Speed dating',
              icon: Icons.favorite_rounded,
              accent: VelvetNoir.secondary,
              onTap: () => context.go('/speed-dating'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _NavCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 116,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withAlpha(45), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.raleway(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: GoogleFonts.raleway(
                  fontSize: 10,
                  color: VelvetNoir.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
