// lib/features/discover_users/discover_users_page.dart
//
// Discover Users – card-swipe deck + search/browse tab bar.
//
// SWIPE tab  - Tinder-style stack driven by suggestedUsersProvider.
//              Drag right → follow user, drag left → skip.
// BROWSE tab - Search bar + suggested-user list (original behaviour).
// ----------------------------------------------------------------------
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/social_graph_providers.dart';
import '../../../shared/providers/user_providers.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/social_graph_widgets.dart';
import '../../../shared/widgets/club_background.dart';
import '../../../shared/widgets/offline_widgets.dart';
import '../../../core/design_system/design_constants.dart';
import 'package:mixmingle/core/analytics/analytics_service.dart';
import 'package:mixmingle/core/analytics/analytics_events.dart';

class DiscoverUsersPage extends ConsumerStatefulWidget {
  const DiscoverUsersPage({super.key});

  @override
  ConsumerState<DiscoverUsersPage> createState() => _DiscoverUsersPageState();
}

class _DiscoverUsersPageState extends ConsumerState<DiscoverUsersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    AnalyticsService.instance.logScreenView(screenName: 'screen_discover');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(profileServiceProvider).searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'DISCOVER',
            style: DesignTypography.heading.copyWith(
              fontSize: 22,
              letterSpacing: 2,
              color: DesignColors.white,
              shadows: DesignColors.primaryGlow,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: DesignColors.accent,
            indicatorWeight: 2,
            labelColor: DesignColors.accent,
            unselectedLabelColor: DesignColors.white.withValues(alpha: 0.5),
            labelStyle: DesignTypography.button
                .copyWith(fontSize: 12, letterSpacing: 1.5),
            tabs: const [
              Tab(text: 'SWIPE'),
              Tab(text: 'BROWSE'),
            ],
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SwipeTab(onOpenBrowse: () => _tabController.animateTo(1)),
                  _BrowseTab(
                    searchController: _searchController,
                    searchResults: _searchResults,
                    isSearching: _isSearching,
                    onSearch: _performSearch,
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

// ============================================================
//  SWIPE TAB
// ============================================================
class _SwipeTab extends ConsumerStatefulWidget {
  final VoidCallback onOpenBrowse;
  const _SwipeTab({required this.onOpenBrowse});

  @override
  ConsumerState<_SwipeTab> createState() => _SwipeTabState();
}

class _SwipeTabState extends ConsumerState<_SwipeTab>
    with SingleTickerProviderStateMixin {
  // Cards already seen in this session
  final Set<String> _dismissed = {};
  // Drag tracking
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  // Snap-back / fly-out animation
  late AnimationController _snapCtrl;
  late Animation<Offset> _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _snapAnim = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut));
    _snapCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  // Thresholds
  static const double _swipeThreshold = 140;
  static const double _maxAngleDeg = 12;

  void _onDragStart(DragStartDetails _) {
    setState(() {
      _isDragging = true;
      _snapCtrl.stop();
      _dragOffset = Offset.zero;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragOffset += d.delta);
  }

  void _onDragEnd(DragEndDetails _, List<UserProfile> users, int index) {
    final dx = _dragOffset.dx;
    if (dx.abs() >= _swipeThreshold) {
      _flyOut(dx > 0, users[index]);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    final start = _dragOffset;
    _snapAnim = Tween<Offset>(begin: start, end: Offset.zero)
        .animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut));
    _snapCtrl.forward(from: 0).then((_) {
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    });
  }

  void _flyOut(bool liked, UserProfile user) async {
    final end = Offset(liked ? 600 : -600, _dragOffset.dy * 1.5);
    _snapAnim = Tween<Offset>(begin: _dragOffset, end: end)
        .animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeIn));
    await _snapCtrl.forward(from: 0);

    if (liked) {
      try {
        await ref.read(socialGraphServiceProvider).followUser(user.id);
        AnalyticsService.instance.logDiscoverUserLiked(userId: user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You liked ${user.displayName ?? 'them'}!'),
            backgroundColor: DesignColors.success,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (_) {}
    } else {
      AnalyticsService.instance.logEngagement(AnalyticsEvents.discoverUserViewed, params: {'user_id': user.id});
    }

    setState(() {
      _dismissed.add(user.id);
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestedAsync = ref.watch(suggestedUsersProvider);
    return suggestedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildError(),
      data: (allUsers) {
        final users =
            allUsers.where((u) => !_dismissed.contains(u.id)).toList();
        if (users.isEmpty) return _buildEmpty();
        return _buildDeck(users);
      },
    );
  }

  Widget _buildDeck(List<UserProfile> users) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width - 32.0;
    final cardH = size.height * 0.60;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Counter
        Text(
          '${users.length} people nearby',
          style: DesignTypography.caption
              .copyWith(color: DesignColors.white.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 12),

        // Card stack
        SizedBox(
          width: cardW,
          height: cardH,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Back cards (non-interactive)
              for (int i = math.min(users.length - 1, 2); i >= 1; i--)
                _buildBackCard(users[i], i, cardW, cardH),

              // Front card (interactive)
              _buildFrontCard(users, cardW, cardH),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip
            _ActionButton(
              icon: Icons.close_rounded,
              color: DesignColors.error,
              size: 56,
              onTap: () => _flyOut(false, users.first),
            ),
            const SizedBox(width: 24),
            // Super-like
            _ActionButton(
              icon: Icons.star_rounded,
              color: DesignColors.gold,
              size: 44,
              onTap: () => _flyOut(true, users.first),
            ),
            const SizedBox(width: 24),
            // Like
            _ActionButton(
              icon: Icons.favorite_rounded,
              color: DesignColors.success,
              size: 56,
              onTap: () => _flyOut(true, users.first),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Browse link
        TextButton(
          onPressed: widget.onOpenBrowse,
          child: Text(
            'Browse all users',
            style: DesignTypography.caption.copyWith(
              color: DesignColors.accent.withValues(alpha: 0.7),
              decoration: TextDecoration.underline,
              decorationColor: DesignColors.accent.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrontCard(List<UserProfile> users, double w, double h) {
    final offset = _isDragging ? _dragOffset : _snapAnim.value;
    final angle = (offset.dx / 400) * (_maxAngleDeg * math.pi / 180);
    final likePct = (offset.dx / _swipeThreshold).clamp(-1.0, 1.0);

    return GestureDetector(
      onPanStart: _onDragStart,
      onPanUpdate: _onDragUpdate,
      onPanEnd: (d) => _onDragEnd(d, users, 0),
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: _ProfileCard(
            user: users.first,
            width: w,
            height: h,
            likeIndicator: likePct,
          ),
        ),
      ),
    );
  }

  Widget _buildBackCard(UserProfile user, int stackIndex, double w, double h) {
    final scale = 1.0 - stackIndex * 0.04;
    final yOffset = stackIndex * 12.0;
    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: scale,
        child: _ProfileCard(
          user: user,
          width: w,
          height: h,
          likeIndicator: 0,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border_rounded,
              size: 72, color: DesignColors.accent.withValues(alpha: 0.4)),
          const SizedBox(height: 20),
          Text('You\'ve seen everyone!',
              style: DesignTypography.subheading
                  .copyWith(color: DesignColors.white)),
          const SizedBox(height: 8),
          Text('Check back later for new suggestions',
              style: DesignTypography.body
                  .copyWith(color: DesignColors.white.withValues(alpha: 0.5)),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: DesignColors.accent),
              foregroundColor: DesignColors.accent,
            ),
            onPressed: () {
              setState(() => _dismissed.clear());
              ref.invalidate(suggestedUsersProvider);
            },
            child: const Text('Refresh'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onOpenBrowse,
            child: Text('Browse all users',
                style: DesignTypography.caption
                    .copyWith(color: DesignColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: DesignColors.error, size: 48),
          const SizedBox(height: 12),
          Text('Could not load suggestions',
              style: DesignTypography.body
                  .copyWith(color: DesignColors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.invalidate(suggestedUsersProvider),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: DesignColors.accent),
                foregroundColor: DesignColors.accent),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Profile card (used in stack) ──────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final UserProfile user;
  final double width;
  final double height;
  // -1 = full "nope", 0 = neutral, +1 = full "like"
  final double likeIndicator;

  const _ProfileCard({
    required this.user,
    required this.width,
    required this.height,
    required this.likeIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            if (user.photoUrl != null)
              Image.network(user.photoUrl!, fit: BoxFit.cover)
            else
              Container(
                color: DesignColors.surfaceLight,
                child: Center(
                  child: Text(
                    user.displayName?.isNotEmpty == true
                        ? user.displayName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: DesignColors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Bottom gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),

            // User info
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.age != null
                              ? '${user.displayName ?? user.nickname ?? 'Unknown'}, ${user.age}'
                              : user.displayName ?? user.nickname ?? 'Unknown',
                          style: const TextStyle(
                              color: DesignColors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black),
                              ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isPhotoVerified == true ||
                          user.isEmailVerified == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.verified_rounded,
                              color: DesignColors.gold, size: 20),
                        ),
                    ],
                  ),
                  if (user.location != null && user.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: DesignColors.white.withValues(alpha: 0.7),
                            size: 14),
                        const SizedBox(width: 4),
                        Text(user.location!,
                            style: TextStyle(
                                color:
                                    DesignColors.white.withValues(alpha: 0.7),
                                fontSize: 13)),
                      ],
                    ),
                  ],
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(user.bio!,
                        style: TextStyle(
                            color: DesignColors.white.withValues(alpha: 0.8),
                            fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  if (user.interests != null && user.interests!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: user.interests!
                          .take(4)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: DesignColors.accent
                                      .withValues(alpha: 0.2),
                                  border: Border.all(
                                      color: DesignColors.accent
                                          .withValues(alpha: 0.6),
                                      width: 1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(tag,
                                    style: const TextStyle(
                                        color: DesignColors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // LIKE overlay
            if (likeIndicator > 0.1)
              Positioned(
                top: 24,
                left: 20,
                child: Transform.rotate(
                  angle: -0.25,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: DesignColors.success.withValues(alpha: 0.15),
                      border: Border.all(color: DesignColors.success, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('LIKE',
                        style: TextStyle(
                            color: DesignColors.success,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            letterSpacing: 2)),
                  ),
                ),
              ),

            // NOPE overlay
            if (likeIndicator < -0.1)
              Positioned(
                top: 24,
                right: 20,
                child: Transform.rotate(
                  angle: 0.25,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: DesignColors.error.withValues(alpha: 0.15),
                      border: Border.all(color: DesignColors.error, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('NOPE',
                        style: TextStyle(
                            color: DesignColors.error,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            letterSpacing: 2)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Round action button ──────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DesignColors.surfaceLight,
          border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 0),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.48),
      ),
    );
  }
}

// ============================================================
//  BROWSE TAB
// ============================================================
class _BrowseTab extends ConsumerWidget {
  final TextEditingController searchController;
  final List<UserProfile> searchResults;
  final bool isSearching;
  final void Function(String) onSearch;

  const _BrowseTab({
    required this.searchController,
    required this.searchResults,
    required this.isSearching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedAsync = ref.watch(suggestedUsersProvider);
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            onSubmitted: onSearch,
            style: const TextStyle(color: DesignColors.white),
            decoration: InputDecoration(
              hintText: 'Search by name...',
              hintStyle:
                  TextStyle(color: DesignColors.white.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search,
                  color: DesignColors.accent.withValues(alpha: 0.7)),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: DesignColors.accent.withValues(alpha: 0.7)),
                      onPressed: () => onSearch(''),
                    )
                  : null,
              filled: true,
              fillColor: DesignColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: DesignColors.accent.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: DesignColors.divider, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: DesignColors.accent, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Results
        Expanded(
          child: searchController.text.isNotEmpty
              ? _buildSearchResults(context)
              : _buildSuggested(context, ref, suggestedAsync),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 60, color: DesignColors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No users found',
                style: DesignTypography.body.copyWith(
                    color: DesignColors.white.withValues(alpha: 0.6))),
          ],
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: searchResults.length,
      itemBuilder: (_, i) => _UserCard(user: searchResults[i]),
    );
  }

  Widget _buildSuggested(BuildContext context, WidgetRef ref,
      AsyncValue<List<UserProfile>> suggestedAsync) {
    return suggestedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(suggestedUsersProvider),
          child: Text('Retry',
              style:
                  DesignTypography.button.copyWith(color: DesignColors.accent)),
        ),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text('No suggestions yet',
                style: DesignTypography.body.copyWith(
                    color: DesignColors.white.withValues(alpha: 0.5))),
          );
        }
        return RefreshIndicator(
          color: DesignColors.accent,
          onRefresh: () async => ref.invalidate(suggestedUsersProvider),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: users.length,
            itemBuilder: (_, i) => _UserCard(user: users[i]),
          ),
        );
      },
    );
  }
}

// ── Browse user card row ─────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final UserProfile user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: DesignColors.divider.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                backgroundColor: DesignColors.surfaceDefault,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName?.isNotEmpty == true
                            ? user.displayName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: DesignColors.white, fontSize: 22))
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: PresenceIndicator(userId: user.id, size: 13),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? user.nickname ?? 'Unknown',
                  style: DesignTypography.body
                      .copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(user.bio!,
                      style: DesignTypography.caption.copyWith(
                          color: DesignColors.white.withValues(alpha: 0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                if (user.interests != null && user.interests!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    children: user.interests!
                        .take(3)
                        .map((interest) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    DesignColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: DesignColors.gold
                                        .withValues(alpha: 0.4),
                                    width: 1),
                              ),
                              child: Text(interest,
                                  style: const TextStyle(
                                      color: DesignColors.gold, fontSize: 11)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FollowButton(userId: user.id, compact: true),
        ],
      ),
    );
  }
}
