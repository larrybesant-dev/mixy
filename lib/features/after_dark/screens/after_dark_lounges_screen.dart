import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/firestore/firestore_error_utils.dart';
import '../../../core/layout/app_layout.dart';
import '../../../models/room_model.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../providers/after_dark_provider.dart';
import '../theme/after_dark_theme.dart';
import '../widgets/after_dark_live_room_card.dart';

const List<({String label, String emoji, String? value})> _loungeCategories = [
  (label: 'All', emoji: '🔥', value: null),
  (label: 'Romance', emoji: '💋', value: 'romance'),
  (label: 'Roleplay', emoji: '🎭', value: 'roleplay'),
  (label: 'Chat', emoji: '💬', value: 'chat'),
  (label: 'Couples', emoji: '💑', value: 'couples'),
  (label: 'Dating', emoji: '❤️', value: 'dating'),
  (label: 'Party', emoji: '🥂', value: 'party'),
];

/// After Dark lounges browser — lists all 18+ live rooms with category filter.
class AfterDarkLoungesScreen extends ConsumerStatefulWidget {
  const AfterDarkLoungesScreen({super.key});

  @override
  ConsumerState<AfterDarkLoungesScreen> createState() =>
      _AfterDarkLoungesScreenState();
}

class _AfterDarkLoungesScreenState
    extends ConsumerState<AfterDarkLoungesScreen> {
  String? _selectedCategory;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<RoomModel> _lastResolvedRooms = const <RoomModel>[];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(adultRoomsProvider(_selectedCategory));
    final resolvedRooms = roomsAsync.when(
      data: (rooms) => rooms,
      loading: () => null,
      error: (error, stackTrace) => null,
    );
    if (resolvedRooms != null) {
      _lastResolvedRooms = resolvedRooms;
    }
    final visibleRooms = resolvedRooms ?? _lastResolvedRooms;

    return AppPageScaffold(
      backgroundColor: EmberDark.surface,
      safeArea: false,
      body: CustomScrollView(
        slivers: [
          // Sticky search + category bar
          SliverAppBar(
            backgroundColor: EmberDark.surface,
            automaticallyImplyLeading: false,
            pinned: true,
            toolbarHeight: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(112),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pageHorizontalPadding,
                      8,
                      context.pageHorizontalPadding,
                      0,
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.raleway(color: EmberDark.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search the mood…',
                        hintStyle: GoogleFonts.raleway(
                          color: EmberDark.onSurfaceVariant,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: EmberDark.onSurfaceVariant,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: EmberDark.onSurfaceVariant,
                                ),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: EmberDark.surfaceHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Category chips
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.pageHorizontalPadding,
                      ),
                      itemCount: _loungeCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final cat = _loungeCategories[i];
                        final isSelected = _selectedCategory == cat.value;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? EmberDark.primaryGradient
                                  : null,
                              color: isSelected ? null : EmberDark.surfaceHigh,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : EmberDark.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                            ),
                            child: Text(
                              '${cat.emoji} ${cat.label}',
                              style: GoogleFonts.raleway(
                                color: isSelected
                                    ? Colors.white
                                    : EmberDark.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Create lounge banner
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                12,
                context.pageHorizontalPadding,
                4,
              ),
              child: _CreateLoungeBanner(),
            ),
          ),

          // Rooms grid
          roomsAsync.when(
            loading: () {
              if (visibleRooms.isNotEmpty) {
                return _buildRoomGrid(
                  context,
                  _filterRooms(visibleRooms),
                  isRefreshing: true,
                );
              }
              return const _AfterDarkLoungesLoadingSliver();
            },
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageHorizontalPadding,
                  24,
                  context.pageHorizontalPadding,
                  24,
                ),
                child: AppErrorView(
                  error: friendlyFirestoremessage(
                    e,
                    fallbackContext: 'lounges',
                  ),
                  fallbackContext: 'Unable to load lounges.',
                ),
              ),
            ),
            data: (allRooms) {
              final rooms = _filterRooms(allRooms);

              if (rooms.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pageHorizontalPadding,
                      40,
                      context.pageHorizontalPadding,
                      0,
                    ),
                    child: AppEmptyView(
                      title: 'No live lounges right now',
                      message: 'Be the first to open the floor tonight.',
                      icon: Icons.nightlife_outlined,
                      action: FilledButton.icon(
                        onPressed: () =>
                            context.go('/after-dark/create-lounge'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Start a Lounge'),
                        style: FilledButton.styleFrom(
                          backgroundColor: EmberDark.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return _buildRoomGrid(context, rooms);
            },
          ),
        ],
      ),
    );
  }

  List<RoomModel> _filterRooms(List<RoomModel> rooms) {
    return _searchQuery.isEmpty
        ? rooms
        : rooms
              .where(
                (room) =>
                    room.name.toLowerCase().contains(_searchQuery) ||
                    (room.description?.toLowerCase().contains(_searchQuery) ??
                        false),
              )
              .toList();
  }

  Widget _buildRoomGrid(
    BuildContext context,
    List<RoomModel> rooms, {
    bool isRefreshing = false,
  }) {
    return SliverMainAxisGroup(
      slivers: [
        if (isRefreshing)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: EmberDark.primary,
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.pageHorizontalPadding,
            12,
            context.pageHorizontalPadding,
            32,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final crossAxisCount = width >= 980
                  ? 4
                  : width >= 720
                  ? 3
                  : 2;
              final aspectRatio = width >= 980
                  ? 0.88
                  : width >= 720
                  ? 0.86
                  : 0.85;

              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _AfterDarkGridReveal(
                    key: ValueKey(rooms[i].id),
                    delay: i * 35,
                    child: AfterDarkLiveRoomCard(
                      room: rooms[i],
                      onTap: () => context.go('/room/${rooms[i].id}'),
                    ),
                  ),
                  childCount: rooms.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AfterDarkLoungesLoadingSliver extends StatelessWidget {
  const _AfterDarkLoungesLoadingSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        12,
        context.pageHorizontalPadding,
        32,
      ),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final crossAxisCount = width >= 980
              ? 4
              : width >= 720
              ? 3
              : 2;
          final aspectRatio = width >= 980
              ? 0.88
              : width >= 720
              ? 0.86
              : 0.85;

          return SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => DecoratedBox(
                decoration: BoxDecoration(
                  color: EmberDark.surfaceHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: EmberDark.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 118,
                      decoration: BoxDecoration(
                        color: EmberDark.surfaceHighest.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: EmberDark.surfaceHighest.withValues(
                            alpha: 0.42,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Container(
                        height: 10,
                        width: 74,
                        decoration: BoxDecoration(
                          color: EmberDark.surfaceHighest.withValues(
                            alpha: 0.28,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              childCount: crossAxisCount * 2,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          );
        },
      ),
    );
  }
}

class _CreateLoungeBanner extends StatefulWidget {
  @override
  State<_CreateLoungeBanner> createState() => _CreateLoungeBannerState();
}

class _CreateLoungeBannerState extends State<_CreateLoungeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => GestureDetector(
        onTap: () => context.go('/after-dark/create-lounge'),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [EmberDark.primaryDim, EmberDark.primary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: EmberDark.secondary.withValues(
                  alpha: 0.16 + (_controller.value * 0.18),
                ),
                blurRadius: 14 + (_controller.value * 10),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open a Velvet Lounge',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Go live for adults looking for late-night chemistry',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AfterDarkGridReveal extends StatelessWidget {
  final Widget child;
  final int delay;

  const _AfterDarkGridReveal({super.key, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}
