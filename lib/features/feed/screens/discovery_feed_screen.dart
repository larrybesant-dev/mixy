import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/providers/session_capabilities_provider.dart';
import '../../../core/theme.dart';
import '../../../dev/app_debug_flags.dart';
import '../../../dev/app_state_reasoning.dart';
import '../../../core/utils/network_image_url.dart';
import '../../../models/room_model.dart';
import '../../../services/session_persistence_service.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/ui_stability_contract.dart';
import '../../../shared/widgets/guest_auth_gate.dart';
import '../../../widgets/brand_ui_kit.dart';

import '../../../shared/state/tab_scroll_memory.dart';
import '../../ads/ad_manager.dart';
import '../../payments/premium_entitlement.dart';
import '../../room/widgets/room_activity_badge.dart';
import '../../room/widgets/room_avatar_stack.dart';
import '../../room/widgets/room_identity_chip.dart';
import '../../stories/widgets/stories_row.dart';
import '../controllers/feed_controller.dart';
import '../controllers/paginated_following_feed_controller.dart';
import '../widgets/post_card.dart';
import '../widgets/trending_user_card.dart';
import '../../stories/providers/story_provider.dart';
import '../../../presentation/providers/notification_provider.dart';
import '../../../services/room_discovery_service.dart';
import '../../../core/providers/firebase_providers.dart';

// ── Velvet Noir brand aliases ────────────────────────────────────────────────
const _npSurface = VelvetNoir.surface;
const _npSurfaceHigh = VelvetNoir.surfaceBright;
const _npSurfaceHighest = VelvetNoir.surfaceHighest;
const _npPrimary = VelvetNoir.primary;
const _npPrimaryDim = VelvetNoir.primaryDim;
const _npSecondary = VelvetNoir.secondaryBright;
const _npError = VelvetNoir.liveGlow;
const _npOnSurface = VelvetNoir.onSurface;
const _npOnVariant = VelvetNoir.onSurfaceVariant;
const _npGhost = Color(0x1A4A2E35);

// ── Host avatar provider ──────────────────────────────────────────────────────
final _hostAvatarProvider = FutureProvider.autoDispose.family<String?, String>((
  ref,
  hostId,
) async {
  final doc = await ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(hostId)
      .get();
  if (!doc.exists) return null;
  return sanitizeNetworkImageUrl(doc.data()?['avatarUrl'] as String?);
});

class DiscoveryFeedScreen extends ConsumerStatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  ConsumerState<DiscoveryFeedScreen> createState() =>
      _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends ConsumerState<DiscoveryFeedScreen> {
  late ScrollController _scrollController;

  // Tab index for AppShell (Feed = 0)
  static const int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    final savedOffset = ref.read(tabScrollMemoryProvider)[_tabIndex] ?? 0.0;
    _scrollController = ScrollController(initialScrollOffset: savedOffset);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions) {
      ref
          .read(tabScrollMemoryProvider.notifier)
          .setOffset(_tabIndex, _scrollController.offset);
    }
  }

  @override
  void dispose() {
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions) {
      ref
          .read(tabScrollMemoryProvider.notifier)
          .setOffset(_tabIndex, _scrollController.offset);
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        backgroundColor: _npSurface,
        safeArea: false,
        floatingActionButton: const _GoLiveFab(),
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: _npSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: _MixVyLogo(),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: _npOnVariant),
                  onPressed: () => context.go('/search'),
                ),
                const _NotificationBell(),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _npGhost)),
                  ),
                  child: TabBar(
                    labelColor: _npPrimary,
                    unselectedLabelColor: _npOnVariant,
                    indicatorColor: _npPrimary,
                    indicatorWeight: 2,
                    labelStyle: GoogleFonts.raleway(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: GoogleFonts.raleway(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Discover'),
                      Tab(text: 'Following'),
                    ],
                  ),
                ),
              ),
            ),
            // Live Now strip — visible on both Discover and Following tabs
            const SliverToBoxAdapter(child: _LiveNowStrip()),
          ],
          body: const TabBarView(
            children: [DiscoveryFeedContent(), _FollowingFeedTab()],
          ),
        ),
      ),
    );
  }
}

// ── Logo wordmark ─────────────────────────────────────────────────────────────
typedef _MixVyLogo = MixvyAppBarLogo;

class DiscoveryLivePulseBanner extends StatelessWidget {
  const DiscoveryLivePulseBanner({
    super.key,
    required this.liveRoomCount,
    required this.activeListenerCount,
    required this.featuredRoomCount,
    this.onOpenRooms,
  });

  final int liveRoomCount;
  final int activeListenerCount;
  final int featuredRoomCount;
  final VoidCallback? onOpenRooms;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_npSurfaceHighest, _npSurfaceHigh],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _npGhost),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _npError,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Pulse',
                style: GoogleFonts.raleway(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _npPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Live energy is moving right now.',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _npOnSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PulseChip(label: '$liveRoomCount rooms live'),
              _PulseChip(label: '$activeListenerCount listening now'),
              _PulseChip(label: '$featuredRoomCount featured'),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onOpenRooms,
              icon: const Icon(Icons.meeting_room_rounded),
              label: const Text('Go to Rooms'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseChip extends StatelessWidget {
  const _PulseChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _npSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _npGhost),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _npOnSurface,
        ),
      ),
    );
  }
}

class HomeLivePulseSection extends StatelessWidget {
  const HomeLivePulseSection({
    super.key,
    required this.liveRoomCount,
    required this.activeListenerCount,
    required this.featuredRoomCount,
    this.onOpenRooms,
  });

  final int liveRoomCount;
  final int activeListenerCount;
  final int featuredRoomCount;
  final VoidCallback? onOpenRooms;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: HomeLayoutV1.livePulseKey,
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        context.sectionSpacing,
        context.pageHorizontalPadding,
        10,
      ),
      child: DiscoveryLivePulseBanner(
        liveRoomCount: liveRoomCount,
        activeListenerCount: activeListenerCount,
        featuredRoomCount: featuredRoomCount,
        onOpenRooms: onOpenRooms,
      ),
    );
  }
}

class HomeFeaturedRoomsSection extends StatelessWidget {
  const HomeFeaturedRoomsSection({
    super.key,
    required this.hasRooms,
    required this.child,
  });

  final bool hasRooms;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: HomeLayoutV1.featuredRoomsKey,
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        context.sectionSpacing,
        context.pageHorizontalPadding,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscoverySectionHeader(
            title: 'Featured Rooms',
            subtitle:
                'Highlighted for live momentum, friend activity, or a fresh start.',
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class HomeDiscoverySection extends StatelessWidget {
  const HomeDiscoverySection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: HomeLayoutV1.discoveryFeedKey,
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        context.sectionSpacing,
        context.pageHorizontalPadding,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscoverySectionHeader(
            title: 'Discovery Feed',
            subtitle: 'Stable layout, fresh activity underneath it.',
            showLiveBadge: true,
            gradientColors: <Color>[_npSecondary, _npPrimary],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class DiscoveryVisibilityDebugPanel extends StatelessWidget {
  const DiscoveryVisibilityDebugPanel({
    super.key,
    required this.streamStateLabel,
    required this.liveRoomCount,
    required this.visibleRoomCount,
    required this.upcomingRoomCount,
    required this.selectedCategoryLabel,
    required this.hint,
  });

  final String streamStateLabel;
  final int liveRoomCount;
  final int visibleRoomCount;
  final int upcomingRoomCount;
  final String selectedCategoryLabel;
  final String hint;

  @override
  Widget build(BuildContext context) {
    if (!kEnableVisibilityDiagnostics) {
      return const SizedBox.shrink();
    }

    final summary = explainCollectionVisibility(
      sourceName: 'rooms',
      isLoading: streamStateLabel == 'loading',
      hasError: streamStateLabel == 'error',
      totalCount: liveRoomCount,
      visibleCount: visibleRoomCount,
      filterLabel: selectedCategoryLabel,
      errormessage: hint,
      isBackendConfirmed:
          streamStateLabel != 'loading' && streamStateLabel != 'error',
    );

    return StateReasonCard(
      title: 'Discovery Inspector',
      summary: summary,
      metrics: [
        'stream: $streamStateLabel',
        'live rooms: $liveRoomCount',
        'visible: $visibleRoomCount',
        'upcoming: $upcomingRoomCount',
        'filter: $selectedCategoryLabel',
      ],
      backgroundColor: _npSurfaceHigh.withValues(alpha: 0.94),
      borderColor: _npGhost,
      titleColor: _npPrimary,
      textColor: _npOnVariant,
      metricChipBuilder: (label) => _PulseChip(label: label),
    );
  }
}

// ── Discovery feed content ────────────────────────────────────────────────────
class DiscoveryFeedContent extends ConsumerStatefulWidget {
  const DiscoveryFeedContent({super.key});

  @override
  ConsumerState<DiscoveryFeedContent> createState() =>
      _DiscoveryFeedContentState();
}

class _DiscoveryFeedContentState extends ConsumerState<DiscoveryFeedContent> {
  static const List<({String label, String? value})> _categories = [
    (label: 'All Rooms', value: null),
    (label: '🎵 Music', value: 'music'),
    (label: '🎮 Gaming', value: 'gaming'),
    (label: '❤️ Dating', value: 'dating'),
    (label: '💬 Chill', value: 'talk'),
    (label: '💻 Tech', value: 'tech'),
    (label: '🎨 Art', value: 'art'),
    (label: '💃 Dance', value: 'dance'),
  ];

  String? _selectedCategory;
  String? _joiningRoomId;

  Future<void> _joinRoom(RoomModel room) async {
    final allowed = await GuestAuthGate.requireRoomJoin(context, ref);
    if (!allowed || !mounted) return;

    if (_joiningRoomId != null) return;
    setState(() => _joiningRoomId = room.id);
    context.go('/room/${room.id}', extra: room);

    // Hardening: Persist room ID so it can be recovered after crash
    unawaited(SessionPersistence.saveLastRoom(room.id));

    // Clear the joining state after a short window so the button re-enables
    // if the user navigates back before the new screen mounts.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _joiningRoomId = null);
    });
  }

  Future<void> _startRoomCreation() async {
    final allowed = await GuestAuthGate.requireRoomCreation(context, ref);
    if (!allowed) return;
    if (!mounted) return;
    context.go('/create-room');
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(feedControllerProvider.notifier).loadFeed(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);
    final horizontalPadding = context.pageHorizontalPadding;

    if (feedState.isLoading) {
      return const AppLoadingView(label: 'Loading discovery feed');
    }

    if (feedState.error != null) {
      return _buildErrorState(feedState.error!);
    }

    final filteredRooms = _selectedCategory == null
        ? feedState.liveRooms
        : feedState.liveRooms
              .where((r) => r.category?.toLowerCase() == _selectedCategory)
              .toList();
    final liveRoomCount = feedState.liveRooms.length;
    final activeListenerCount = feedState.liveRooms.fold<int>(
      0,
      (total, room) =>
          total +
          (room.memberCount > 0
              ? room.memberCount
              : room.stageUserIds.length + room.audienceUserIds.length),
    );
    final featuredRoomCount = liveRoomCount >= 3 ? 3 : liveRoomCount;
    final discoveryStateLabel = feedState.error != null
        ? 'error'
        : filteredRooms.isEmpty
        ? 'empty'
        : 'ready';
    final selectedCategoryLabel = _selectedCategory ?? 'all';
    final discoveryHint = feedState.error != null
        ? feedState.error!
        : filteredRooms.isEmpty
        ? (_selectedCategory == null
              ? 'No live rooms currently passed visibility rules.'
              : 'No live rooms match the selected category right now.')
        : 'Rooms are visible and ranked normally.';

    HomeLayoutV1.debugAssertOrder(const <String>[
      HomeLayoutV1.livePulseSlotId,
      HomeLayoutV1.featuredRoomsSlotId,
      HomeLayoutV1.discoveryFeedSlotId,
    ]);

    return RefreshIndicator(
      color: _npPrimary,
      backgroundColor: _npSurfaceHigh,
      onRefresh: () => ref.read(feedControllerProvider.notifier).loadFeed(),
      child: CustomScrollView(
        slivers: [
          // ── Live-state count bar ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _LiveStateBar(
              liveRooms: feedState.liveRooms,
              liveRoomCount: liveRoomCount,
              activeListenerCount: activeListenerCount,
            ),
          ),

          // ── Hero CTA — "Join a Room" / "Start Your Own Room" ──────────
          SliverToBoxAdapter(
            child: _HeroJoinCard(
              firstRoom: filteredRooms.isNotEmpty ? filteredRooms[0] : null,
              onStartRoom: _startRoomCreation,
            ),
          ),

          // ── Speed Date card — secondary CTA ───────────────────────────
          const SliverToBoxAdapter(child: _SpeedDateCard()),

          SliverToBoxAdapter(
            child: HomeLivePulseSection(
              liveRoomCount: liveRoomCount,
              activeListenerCount: activeListenerCount,
              featuredRoomCount: featuredRoomCount,
              onOpenRooms: () => context.go('/live'),
            ),
          ),

          if (filteredRooms.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: HomeFeaturedRoomsSection(
                hasRooms: true,
                child: _buildBentoGrid(
                  filteredRooms,
                  feedState.roomReasons,
                  feedState.roomTiers,
                ),
              ),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: HomeFeaturedRoomsSection(
                hasRooms: false,
                child: const AppEmptyView(
                  title: 'No featured rooms right now',
                  message: 'When rooms go live, they will appear here first.',
                  icon: Icons.sensors_off_rounded,
                ),
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: HomeDiscoverySection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiscoveryVisibilityDebugPanel(
                    streamStateLabel: discoveryStateLabel,
                    liveRoomCount: liveRoomCount,
                    visibleRoomCount: filteredRooms.length,
                    upcomingRoomCount: feedState.upcomingRooms.length,
                    selectedCategoryLabel: selectedCategoryLabel,
                    hint: discoveryHint,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: StoriesRow(),
                  ),
                  _buildCategoryChips(),
                  const _FriendsLiveSection(),
                ],
              ),
            ),
          ),

          if (filteredRooms.length > 3)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final crossAxisCount = width >= 980
                      ? 4
                      : width >= 720
                      ? 3
                      : 2;
                  final aspectRatio = width >= 980
                      ? 1.0
                      : width >= 720
                      ? 0.95
                      : 1.0;

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: aspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final room = filteredRooms[i + 3];
                        return _RoomGridCard(
                          key: ValueKey(room.id),
                          room: room,
                          reason:
                              feedState.roomReasons[room.id] ?? 'Active now',
                          tier: feedState.roomTiers[room.id],
                          joining: _joiningRoomId == room.id,
                          onTap: () => _joinRoom(room),
                        );
                      },
                      childCount: filteredRooms.length > 3
                          ? filteredRooms.length - 3
                          : 0,
                    ),
                  );
                },
              ),
            ),

          // Promo banner (free tier only)
          SliverToBoxAdapter(
            child: Builder(
              builder: (ctx) {
                final hasVipEntitlement =
                    ref.watch(vipEntitlementProvider).valueOrNull ?? false;
                if (!AdManager.shouldShowAds(
                  hasVipEntitlement: hasVipEntitlement,
                )) {
                  return const SizedBox.shrink();
                }
                return _buildPromoBanner(ctx);
              },
            ),
          ),

          // Trending users
          if (feedState.trendingUsers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  context.sectionSpacing,
                  horizontalPadding,
                  12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_npPrimary, _npSecondary],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trending Creators',
                      style: GoogleFonts.raleway(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _npOnSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  scrollDirection: Axis.horizontal,
                  itemCount: feedState.trendingUsers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final user = feedState.trendingUsers[index];
                    return TrendingUserCard(
                      key: ValueKey(user.id),
                      user: user,
                      onTap: () => context.go('/profile/${user.id}'),
                    );
                  },
                ),
              ),
            ),
          ],

          // Upcoming rooms
          if (feedState.upcomingRooms.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  context.sectionSpacing,
                  horizontalPadding,
                  12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _npSurfaceHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upcoming Rooms',
                      style: GoogleFonts.raleway(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _npOnSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final room = feedState.upcomingRooms[i];
                final scheduledAt = room.scheduledAt?.toDate();
                return _UpcomingRoomTile(
                  key: ValueKey(room.id),
                  room: room,
                  scheduledAt: scheduledAt,
                );
              }, childCount: feedState.upcomingRooms.length),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: context.pageHorizontalPadding,
          vertical: 8,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat.value;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedCategory = cat.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [_npPrimary, _npPrimaryDim],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected ? null : _npSurfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? Colors.transparent : _npGhost,
                ),
              ),
              child: Text(
                cat.label,
                style: GoogleFonts.raleway(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _npSurface : _npOnVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBentoGrid(
    List<RoomModel> rooms,
    Map<String, String> roomReasons,
    Map<String, String> roomTiers,
  ) {
    if (rooms.isEmpty) return const SizedBox.shrink();
    final hero = rooms[0];
    final List<RoomModel> secondary = rooms.length > 1
        ? rooms.sublist(1, rooms.length.clamp(1, 3))
        : const <RoomModel>[];

    return SizedBox(
      height: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card (2/3 width)
          Expanded(
            flex: 2,
            child: _BentoHeroCard(
              room: hero,
              reason: roomReasons[hero.id] ?? 'Active now',
              tier: roomTiers[hero.id],
              joining: _joiningRoomId == hero.id,
              onTap: () => _joinRoom(hero),
            ),
          ),
          const SizedBox(width: 8),
          // Secondary cards (1/3 width, stacked)
          Expanded(
            child: Column(
              children: [
                if (secondary.isNotEmpty)
                  Expanded(
                    child: _BentoSmallCard(
                      room: secondary[0],
                      reason: roomReasons[secondary[0].id] ?? 'Active now',
                      tier: roomTiers[secondary[0].id],
                      onTap: () => _joinRoom(secondary[0]),
                    ),
                  ),
                if (secondary.length > 1) ...[
                  const SizedBox(height: 8),
                  Expanded(
                    child: _BentoSmallCard(
                      room: secondary[1],
                      reason: roomReasons[secondary[1].id] ?? 'Active now',
                      tier: roomTiers[secondary[1].id],
                      onTap: () => _joinRoom(secondary[1]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return AppErrorView(
      error: error,
      fallbackContext: 'Unable to load the discovery feed.',
      onRetry: () => ref.read(feedControllerProvider.notifier).loadFeed(),
    );
  }

  Widget _buildPromoBanner(BuildContext ctx) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ctx.pageHorizontalPadding,
        16,
        ctx.pageHorizontalPadding,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _npSurfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _npGhost),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_npPrimary, _npPrimaryDim],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: _npSurface,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Premium',
                    style: GoogleFonts.raleway(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _npOnSurface,
                    ),
                  ),
                  Text(
                    'Remove ads & unlock exclusive rooms.',
                    style: GoogleFonts.raleway(
                      fontSize: 12,
                      color: _npOnVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => ctx.go('/payments'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_npPrimary, _npPrimaryDim],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Upgrade',
                  style: GoogleFonts.raleway(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _npSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverySectionHeader extends StatelessWidget {
  const _DiscoverySectionHeader({
    required this.title,
    this.subtitle,
    this.showLiveBadge = false,
    this.gradientColors = const <Color>[_npPrimary, _npPrimaryDim],
  });

  final String title;
  final String? subtitle;
  final bool showLiveBadge;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.raleway(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _npOnSurface,
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: GoogleFonts.raleway(fontSize: 12, color: _npOnVariant),
                ),
              ],
            ],
          ),
        ),
        if (showLiveBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _npSurfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _npGhost),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _npError,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: GoogleFonts.raleway(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _npError,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Bento hero card ───────────────────────────────────────────────────────────
class _BentoHeroCard extends ConsumerWidget {
  const _BentoHeroCard({
    required this.room,
    required this.reason,
    required this.onTap,
    this.tier,
    this.joining = false,
  });
  final RoomModel room;
  final String reason;
  final String? tier;
  final VoidCallback onTap;
  final bool joining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarAsync = ref.watch(_hostAvatarProvider(room.hostId));
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C1240), Color(0xFF0D0A0C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xCC0D0A0C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(top: 12, left: 12, child: _LiveBadge()),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ReasonChip(label: reason, tier: tier),
                  const SizedBox(height: 6),
                  RoomIdentityChip(room: room),
                ],
              ),
            ),
            Positioned(
              bottom: 52,
              right: 12,
              child: _viewerPill(room.memberCount),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.raleway(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _npOnSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: avatarAsync.when(
                            data: (url) => url != null
                                ? CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        Container(color: _npPrimaryDim),
                                  )
                                : Container(color: _npPrimaryDim),
                            loading: () => Container(color: _npPrimaryDim),
                            error: (_, _) => Container(color: _npPrimaryDim),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      () {
                        final rel = _relativeTime(room.createdAt?.toDate());
                        return Text(
                          rel.isNotEmpty ? rel : 'Host',
                          style: GoogleFonts.raleway(
                            fontSize: 12,
                            color: _npOnVariant,
                          ),
                        );
                      }(),
                      const Spacer(),
                      // Live stats
                      RoomActivityBadge(
                        icon: '🔥',
                        count: room.memberCount > 0
                            ? room.memberCount
                            : room.stageUserIds.length +
                                  room.audienceUserIds.length,
                        label: 'listening',
                      ),
                      const SizedBox(width: 6),
                      RoomActivityBadge(
                        icon: '🎤',
                        count: room.stageUserIds.length,
                        label: 'speaking',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: joining ? null : onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: _npPrimary,
                        foregroundColor: _npSurface,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: joining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _npSurface,
                              ),
                            )
                          : Text(
                              'JOIN',
                              style: GoogleFonts.raleway(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.6,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bento small card ──────────────────────────────────────────────────────────
class _BentoSmallCard extends StatelessWidget {
  const _BentoSmallCard({
    required this.room,
    required this.reason,
    required this.onTap,
    this.tier,
  });
  final RoomModel room;
  final String reason;
  final String? tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1B1216), const Color(0xFF0D0A0C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xCC0D0A0C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(top: 8, left: 8, child: _LiveBadge(small: true)),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ReasonChip(label: reason, tier: tier, small: true),
                  const SizedBox(height: 4),
                  RoomIdentityChip(room: room, small: true),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.raleway(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _npOnSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Room grid card ────────────────────────────────────────────────────────────
class _RoomGridCard extends ConsumerWidget {
  const _RoomGridCard({
    required this.room,
    required this.reason,
    required this.onTap,
    this.tier,
    this.joining = false,
    super.key,
  });
  final RoomModel room;
  final String reason;
  final String? tier;
  final VoidCallback onTap;
  final bool joining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarAsync = ref.watch(_hostAvatarProvider(room.hostId));
    final listenerCount = room.memberCount > 0
        ? room.memberCount
        : room.stageUserIds.length + room.audienceUserIds.length;
    final speakerCount = room.stageUserIds.length;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1C1C2E), _npSurfaceHigh],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: LIVE badge + reason chip
              Row(
                children: [
                  _LiveBadge(small: true),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ReasonChip(label: reason, tier: tier, small: true),
                      const SizedBox(height: 4),
                      RoomIdentityChip(room: room, small: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Room name + host avatar
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.raleway(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _npOnSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClipOval(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: avatarAsync.when(
                        data: (url) => url != null
                            ? CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    Container(color: _npPrimaryDim),
                              )
                            : Container(color: _npPrimaryDim),
                        loading: () => Container(color: _npPrimaryDim),
                        error: (_, _) => Container(color: _npPrimaryDim),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Stats row
              Row(
                children: [
                  RoomActivityBadge(icon: '🔥', count: listenerCount),
                  const SizedBox(width: 4),
                  RoomActivityBadge(icon: '🎤', count: speakerCount),
                ],
              ),
              const SizedBox(height: 6),
              // JOIN button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: joining ? null : onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: _npPrimary,
                    foregroundColor: _npSurface,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: joining
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _npSurface,
                          ),
                        )
                      : Text(
                          'JOIN',
                          style: GoogleFonts.raleway(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.6,
                          ),
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

// ── Upcoming room tile ────────────────────────────────────────────────────────
class _UpcomingRoomTile extends StatelessWidget {
  const _UpcomingRoomTile({required this.room, this.scheduledAt, super.key});
  final RoomModel room;
  final DateTime? scheduledAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        0,
        context.pageHorizontalPadding,
        10,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _npSurfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _npGhost),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _npPrimary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('📅', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: GoogleFonts.raleway(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _npOnSurface,
                  ),
                ),
                const SizedBox(height: 2),
                scheduledAt == null
                    ? Text(
                        'Scheduled',
                        style: GoogleFonts.raleway(
                          fontSize: 12,
                          color: _npOnVariant,
                        ),
                      )
                    : _RoomCountdown(scheduledAt: scheduledAt!),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You\'ll be notified when "${room.name}" goes live.',
                  style: GoogleFonts.raleway(color: _npOnSurface),
                ),
                backgroundColor: _npSurfaceHigh,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: _npPrimary.withAlpha(80)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Remind',
                style: GoogleFonts.raleway(fontSize: 12, color: _npPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label, this.tier, this.small = false});

  final String label;

  /// Optional tier string from [RoomService.getRecommendationTier].
  /// Controls the chip accent color for visual social-proof hierarchy.
  final String? tier;
  final bool small;

  // ── Tier color map ─────────────────────────────────────────────────────────
  // Friends → gold border/text
  // Momentum/Hot → wine red/orange
  // Fresh → teal
  // Live (default) → neutral
  static Color _borderFor(String? tier) {
    switch (tier) {
      case 'Friends':
        return const Color(0xFFD4AF37); // gold
      case 'Momentum':
        return const Color(0xFF9B2535); // wine
      case 'Hot':
        return const Color(0xFFE07A5F); // warm orange
      case 'Fresh':
        return const Color(0xFF4DB6AC); // teal
      default:
        return const Color(0x1A4A2E35); // ghost
    }
  }

  static Color _textFor(String? tier) {
    switch (tier) {
      case 'Friends':
        return const Color(0xFFD4AF37);
      case 'Momentum':
        return const Color(0xFFE07A8A);
      case 'Hot':
        return const Color(0xFFE07A5F);
      case 'Fresh':
        return const Color(0xFF4DB6AC);
      default:
        return VelvetNoir.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = _borderFor(tier);
    final textColor = _textFor(tier);
    return Container(
      constraints: BoxConstraints(maxWidth: small ? 110 : 160),
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0x99161A21),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withAlpha(180)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.raleway(
          fontSize: small ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge({this.small = false});
  final bool small;

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.small ? 6 : 8,
        vertical: widget.small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _npError.withAlpha(230),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: _npError.withAlpha(80),
            blurRadius: widget.small ? 6 : 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: widget.small ? 5 : 6,
              height: widget.small ? 5 : 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: widget.small ? 3 : 4),
          Text(
            'LIVE',
            style: GoogleFonts.raleway(
              fontSize: widget.small ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _viewerPill(int count) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x80161A21),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_red_eye_outlined,
              size: 12,
              color: _npOnVariant,
            ),
            const SizedBox(width: 4),
            Text(
              count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
              style: GoogleFonts.raleway(fontSize: 11, color: _npOnSurface),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Following feed tab ────────────────────────────────────────────────────────
class _FollowingFeedTab extends ConsumerStatefulWidget {
  const _FollowingFeedTab();

  @override
  ConsumerState<_FollowingFeedTab> createState() => _FollowingFeedTabState();
}

class _FollowingFeedTabState extends ConsumerState<_FollowingFeedTab> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      Future.microtask(
        () =>
            ref.read(paginatedFollowingFeedProvider(uid).notifier).loadPosts(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const AppEmptyView(
        title: 'Sign in to see your following feed',
        message: 'Your followed creators and posts will appear here.',
        icon: Icons.login_rounded,
      );
    }

    final feedState = ref.watch(paginatedFollowingFeedProvider(uid));

    if (feedState.posts.isEmpty && feedState.isLoading) {
      return const AppLoadingView(label: 'Loading following feed');
    }

    if (feedState.posts.isEmpty) {
      return AppEmptyView(
        title: 'No posts from people you follow yet',
        message: 'Find more creators and your following feed will update live.',
        icon: Icons.people_outline_rounded,
        action: _FollowFeedActionButton(onTap: () => context.go('/search')),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(paginatedFollowingFeedProvider(uid).notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(height: 1, color: _npGhost),
        itemBuilder: (context, i) {
          if (i == feedState.posts.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: feedState.isLoading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: () => ref
                            .read(paginatedFollowingFeedProvider(uid).notifier)
                            .loadPosts(),
                        child: const Text('Load More'),
                      ),
              ),
            );
          }
          return PostCard(post: feedState.posts[i], currentUserId: uid);
        },
      ),
    );
  }
}

// ── Room countdown ────────────────────────────────────────────────────────────
class _RoomCountdown extends StatefulWidget {
  const _RoomCountdown({required this.scheduledAt});
  final DateTime scheduledAt;

  @override
  State<_RoomCountdown> createState() => _RoomCountdownState();
}

class _RoomCountdownState extends State<_RoomCountdown> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.scheduledAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = widget.scheduledAt.difference(DateTime.now());
      setState(() => _remaining = remaining);
      if (remaining.isNegative) _timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return Text(
        'Going live now!',
        style: GoogleFonts.raleway(
          color: _npSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final String label;
    if (_remaining.inSeconds < 600) {
      final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      label = 'Going live in ${m}m ${s}s';
    } else if (_remaining.inHours < 24) {
      label =
          'In ${_remaining.inHours}h ${_remaining.inMinutes.remainder(60)}m';
    } else {
      label = 'In ${_remaining.inDays}d';
    }
    return Text(
      label,
      style: GoogleFonts.raleway(fontSize: 12, color: _npOnVariant),
    );
  }
}

// ── Live Now Strip — always visible above both feed tabs ───────────────────────
class _LiveNowStrip extends ConsumerWidget {
  const _LiveNowStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedControllerProvider);
    final rooms = feedState.liveRooms.take(12).toList();
    if (rooms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pageHorizontalPadding,
            12,
            context.pageHorizontalPadding,
            8,
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _npError,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Live Now',
                style: GoogleFonts.raleway(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _npError,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _npError.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${rooms.length}',
                  style: GoogleFonts.raleway(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _npError,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: context.pageHorizontalPadding,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: rooms.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (ctx, i) => _LiveNowBubble(
              room: rooms[i],
              onTap: () => context.go('/room/${rooms[i].id}', extra: rooms[i]),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: _npGhost),
      ],
    );
  }
}

class _FollowFeedActionButton extends StatelessWidget {
  const _FollowFeedActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_npPrimary, _npPrimaryDim]),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search, size: 16, color: _npSurface),
            const SizedBox(width: 8),
            Text(
              'Find people to follow',
              style: GoogleFonts.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _npSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live Now bubble (avatar ring + name) ──────────────────────────────────────
class _LiveNowBubble extends ConsumerWidget {
  const _LiveNowBubble({
    required this.room,
    required this.onTap,
    this.friendCount = 0,
  });

  final RoomModel room;
  final VoidCallback onTap;

  /// How many of the viewer's friends are in this room (host + audience).
  /// When > 0, a gold "👥 N" badge is shown on the avatar ring.
  final int friendCount;

  static const _categoryEmoji = {
    'music': '🎵',
    'gaming': '🎮',
    'dating': '❤️',
    'talk': '💬',
    'tech': '💻',
    'art': '🎨',
    'dance': '💃',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarAsync = ref.watch(_hostAvatarProvider(room.hostId));
    final emoji = _categoryEmoji[room.category?.toLowerCase()] ?? '📡';
    final memberCount = room.memberCount > 0
        ? room.memberCount
        : room.stageUserIds.length + room.audienceUserIds.length;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Gradient ring: gold → rose wine
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [_npError, _npPrimary, _npSecondary, _npError],
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: avatarAsync.when(
                      data: (url) => url != null
                          ? CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  _EmojiAvatar(emoji: emoji),
                            )
                          : _EmojiAvatar(emoji: emoji),
                      loading: () => _EmojiAvatar(emoji: emoji),
                      error: (_, _) => _EmojiAvatar(emoji: emoji),
                    ),
                  ),
                ),
                // Friend-count badge (gold, top-left)
                if (friendCount > 0)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _npPrimary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _npSurface, width: 1.5),
                      ),
                      child: Text(
                        '👥 $friendCount',
                        style: GoogleFonts.raleway(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _npSurface,
                        ),
                      ),
                    ),
                  ),
                // Member count badge
                if (memberCount > 0)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _npSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _npSurfaceHigh, width: 1.5),
                      ),
                      child: Text(
                        memberCount >= 1000
                            ? '${(memberCount / 1000).toStringAsFixed(1)}k'
                            : '$memberCount',
                        style: GoogleFonts.raleway(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _npOnVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.raleway(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _npOnVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live-state count bar ─────────────────────────────────────────────────────
class _LiveStateBar extends StatelessWidget {
  const _LiveStateBar({
    required this.liveRooms,
    required this.liveRoomCount,
    required this.activeListenerCount,
  });
  final List<RoomModel> liveRooms;
  final int liveRoomCount;
  final int activeListenerCount;

  // Gather up to 4 unique participant UIDs from the first few rooms.
  List<String> _clusterUids() {
    final seen = <String>{};
    final uids = <String>[];
    for (final room in liveRooms.take(4)) {
      for (final uid in [...room.stageUserIds, ...room.audienceUserIds]) {
        if (seen.add(uid)) {
          uids.add(uid);
          if (uids.length >= 4) return uids;
        }
      }
      // Fallback: use hostId so we always have something
      if (seen.add(room.hostId)) {
        uids.add(room.hostId);
        if (uids.length >= 4) return uids;
      }
    }
    return uids;
  }

  // "3 rooms started in the last hour"
  String _temporalSummary() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    final recentCount = liveRooms.where((r) {
      final ts = r.createdAt?.toDate();
      return ts != null && ts.isAfter(cutoff);
    }).length;
    if (recentCount == 0) return '$liveRoomCount rooms live';
    if (recentCount == liveRoomCount) {
      return '$liveRoomCount rooms started this hour';
    }
    return '$recentCount of $liveRoomCount started this hour';
  }

  @override
  Widget build(BuildContext context) {
    if (liveRoomCount == 0) return const SizedBox.shrink();
    final listeners = activeListenerCount > 999
        ? '${(activeListenerCount / 1000).toStringAsFixed(1)}k'
        : '$activeListenerCount';
    final clusterUids = _clusterUids();
    return Container(
      margin: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        12,
        context.pageHorizontalPadding,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _npError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _npError.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _AnimatedPulseDot(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _temporalSummary(),
                  style: GoogleFonts.raleway(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _npError,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$listeners listening now',
                  style: GoogleFonts.raleway(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _npOnVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _JoinEventTicker(liveRooms: liveRooms),
              ],
            ),
          ),
          if (clusterUids.isNotEmpty) ...[
            const SizedBox(width: 10),
            RoomAvatarStack(
              uids: clusterUids,
              // Using denormalized data if available, though clusterUids usually implies multiple users
              // For now just pass the IDs, and we'll harden the RoomCard to use denormalized host data.
            ),
          ],
        ],
      ),
    );
  }
}

// ── Animated pulse dot (reusable) ─────────────────────────────────────────────
class _AnimatedPulseDot extends StatefulWidget {
  const _AnimatedPulseDot({this.size = 8.0});
  final double size;

  @override
  State<_AnimatedPulseDot> createState() => _AnimatedPulseDotState();
}

class _AnimatedPulseDotState extends State<_AnimatedPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _npError,
          boxShadow: [
            BoxShadow(
              color: _npError.withValues(alpha: 0.55),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Speed Date card — secondary CTA ──────────────────────────────────────────
class _SpeedDateCard extends StatelessWidget {
  const _SpeedDateCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        10,
        context.pageHorizontalPadding,
        4,
      ),
      child: GestureDetector(
        onTap: () => context.go('/speed-dating'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A0A14), Color(0xFF1A0A10), Color(0xFF0B0B0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _npSecondary.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: _npSecondary.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _npSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _npSecondary.withValues(alpha: 0.30),
                  ),
                ),
                child: const Center(
                  child: Text('❤️', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speed Dating',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _npOnSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Jump into 3-min video rounds',
                      style: GoogleFonts.raleway(
                        fontSize: 12,
                        color: _npOnVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _npSecondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _npSecondary.withValues(alpha: 0.40),
                  ),
                ),
                child: Text(
                  'DATE',
                  style: GoogleFonts.raleway(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _npSecondary,
                    letterSpacing: 0.6,
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

// ── Hero Join / Start Room card ───────────────────────────────────────────────
/// Dominant CTA card at the top of the Discover feed.
/// Two actions: join the first live room (if any), or start your own room.
class _HeroJoinCard extends StatelessWidget {
  const _HeroJoinCard({this.firstRoom, this.onStartRoom});
  final RoomModel? firstRoom;
  final VoidCallback? onStartRoom;

  @override
  Widget build(BuildContext context) {
    final hasLiveRoom = firstRoom != null;
    final listenerCount = firstRoom == null
        ? 0
        : firstRoom!.memberCount > 0
        ? firstRoom!.memberCount
        : firstRoom!.stageUserIds.length + firstRoom!.audienceUserIds.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        16,
        context.pageHorizontalPadding,
        4,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1240), Color(0xFF1A0A0E), Color(0xFF0B0B0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hasLiveRoom
                ? _npPrimary.withValues(alpha: 0.38)
                : _npSurfaceHighest.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: hasLiveRoom
                  ? _npError.withValues(alpha: 0.18)
                  : Colors.black26,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (hasLiveRoom)
                  _AnimatedPulseDot(size: 8)
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _npOnVariant,
                    ),
                  ),
                const SizedBox(width: 7),
                Text(
                  hasLiveRoom ? '🎤  Live Now' : '🎤  Quiet right now',
                  style: GoogleFonts.raleway(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasLiveRoom ? _npError : _npOnVariant,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasLiveRoom
                  ? firstRoom!.name.isNotEmpty
                        ? firstRoom!.name
                        : 'Someone is live right now'
                  : 'No one is live yet — be first',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _npOnSurface,
              ),
            ),
            if (hasLiveRoom && listenerCount > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$listenerCount listening',
                    style: GoogleFonts.raleway(
                      fontSize: 12,
                      color: _npOnVariant,
                    ),
                  ),
                  () {
                    final rel = _relativeTime(firstRoom!.createdAt?.toDate());
                    if (rel.isEmpty) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _npOnVariant,
                          ),
                        ),
                        Text(
                          rel,
                          style: GoogleFonts.raleway(
                            fontSize: 12,
                            color: _npOnVariant,
                          ),
                        ),
                      ],
                    );
                  }(),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: hasLiveRoom
                    ? () => context.go(
                        '/room/${firstRoom!.id}',
                        extra: firstRoom!,
                      )
                    : onStartRoom,
                style: FilledButton.styleFrom(
                  backgroundColor: _npPrimary,
                  foregroundColor: _npSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  hasLiveRoom ? Icons.meeting_room_rounded : Icons.mic_rounded,
                ),
                label: Text(
                  hasLiveRoom ? 'Join a Room' : 'Start the Night',
                  style: GoogleFonts.raleway(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (hasLiveRoom) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onStartRoom,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _npPrimary,
                    side: BorderSide(color: _npPrimary.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(
                    'Start Your Own Room',
                    style: GoogleFonts.raleway(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Join micro-event ticker ───────────────────────────────────────────────────
/// Cycles through data-derived join signals every 4 seconds.
/// Only shows when there are live rooms with recent activity.
class _JoinEventTicker extends StatefulWidget {
  const _JoinEventTicker({required this.liveRooms});
  final List<RoomModel> liveRooms;

  @override
  State<_JoinEventTicker> createState() => _JoinEventTickerState();
}

class _JoinEventTickerState extends State<_JoinEventTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  late List<String> _events;
  int _index = 0;
  Timer? _timer;

  List<String> _buildEvents(List<RoomModel> rooms) {
    final events = <String>[];
    final now = DateTime.now();

    for (final room in rooms) {
      final updatedAt = room.updatedAt?.toDate();
      if (updatedAt == null) continue;
      final secAgo = now.difference(updatedAt).inSeconds;

      if (secAgo <= 90) {
        // Very fresh join signal
        final name = room.name.length > 22
            ? '${room.name.substring(0, 22)}…'
            : room.name;
        events.add('Someone joined $name');
      } else if (secAgo <= 300) {
        // 1-5 min old activity
        final count = room.stageUserIds.length + room.audienceUserIds.length;
        if (count > 1) {
          events.add(
            'Audience growing · ${room.name.length > 18 ? '${room.name.substring(0, 18)}…' : room.name}',
          );
        }
      }
    }

    // Count rooms active in the last 2 minutes
    final veryRecentCount = rooms.where((r) {
      final ua = r.updatedAt?.toDate();
      return ua != null && now.difference(ua).inSeconds <= 120;
    }).length;
    if (veryRecentCount >= 2) {
      events.add('$veryRecentCount rooms had joins in the last 2 min');
    }

    return events.isEmpty ? const [] : events;
  }

  @override
  void initState() {
    super.initState();
    _events = _buildEvents(widget.liveRooms);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeInOut);

    if (_events.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
    }
  }

  void _advance() {
    if (!mounted || _events.isEmpty) return;
    _fade.reverse().then((_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _events.length);
      _fade.forward();
    });
  }

  @override
  void didUpdateWidget(_JoinEventTicker old) {
    super.didUpdateWidget(old);
    _events = _buildEvents(widget.liveRooms);
    _index = _index.clamp(0, _events.isEmpty ? 0 : _events.length - 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _opacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward_rounded, size: 10, color: _npOnVariant),
          const SizedBox(width: 4),
          Text(
            _events[_index.clamp(0, _events.length - 1)],
            style: GoogleFonts.raleway(
              fontSize: 11,
              color: _npOnVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Relative-time helper ─────────────────────────────────────────────────────────
String _relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just started';
  if (diff.inMinutes < 60) return 'started ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'started ${diff.inHours}h ago';
  return '';
}

// ── Emoji fallback avatar ─────────────────────────────────────────────────────
class _EmojiAvatar extends StatelessWidget {
  const _EmojiAvatar({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _npSurfaceHighest,
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.go('/notifications'),
      icon: unreadCount > 0
          ? Badge(
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(
                Icons.notifications_outlined,
                color: _npOnVariant,
              ),
            )
          : const Icon(Icons.notifications_outlined, color: _npOnVariant),
    );
  }
}

class _GoLiveFab extends StatelessWidget {
  const _GoLiveFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final allowed = await GuestAuthGate.requireCapabilityFromContext(
          context,
          SessionCapability.createRoom,
        );
        if (!allowed) return;
        if (!context.mounted) return;
        context.go('/create-room');
      },
      backgroundColor: _npPrimary,
      foregroundColor: _npSurface,
      icon: const Icon(Icons.mic_rounded),
      label: Text(
        'Start Room',
        style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FriendsLiveSection extends ConsumerWidget {
  const _FriendsLiveSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final followingAsync = ref.watch(followingIdsProvider(uid));
    final feedState = ref.watch(feedControllerProvider);

    return followingAsync.when(
      data: (followingIds) {
        if (followingIds.isEmpty) {
          return const SizedBox.shrink();
        }

        final friendRooms = feedState.liveRooms
            .where((room) => followingIds.contains(room.hostId))
            .take(10)
            .toList();

        if (friendRooms.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No friends live right now — discover rooms below.',
              style: GoogleFonts.raleway(fontSize: 13, color: _npOnVariant),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(0, context.sectionSpacing, 0, 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_npSecondary, _npPrimary],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Friends Live',
                    style: GoogleFonts.raleway(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _npOnSurface,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemCount: friendRooms.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) => _LiveNowBubble(
                  room: friendRooms[i],
                  friendCount: RoomDiscoveryService.friendCountIn(
                    friendRooms[i],
                    followingIds.toSet(),
                  ),
                  onTap: () => context.go(
                    '/room/${friendRooms[i].id}',
                    extra: friendRooms[i],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
