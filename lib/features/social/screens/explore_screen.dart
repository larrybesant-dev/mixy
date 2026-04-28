import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/layout/app_layout.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/feed/widgets/trending_user_card.dart';
import 'package:mixvy/features/social/providers/social_providers.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';

// ── Category data ─────────────────────────────────────────────────────────────
const _categories = [
  (label: 'Music', emoji: '🎵', value: 'music', color: VelvetNoir.secondaryBright),
  (label: 'Talk', emoji: '💬', value: 'talk', color: VelvetNoir.primary),
  (label: 'Dating', emoji: '💕', value: 'dating', color: VelvetNoir.secondary),
  (label: 'Chill', emoji: '🍃', value: 'chill', color: VelvetNoir.surfaceBright),
  (label: 'Gaming', emoji: '🎮', value: 'gaming', color: VelvetNoir.primaryDim),
  (label: 'Art', emoji: '🎨', value: 'art', color: VelvetNoir.onSurfaceVariant),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RoomModel> _filterRooms(List<RoomModel> rooms) {
    List<RoomModel> filtered = rooms;
    if (_selectedCategory != null) {
      filtered = filtered
          .where((r) => r.category?.toLowerCase() == _selectedCategory)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.name.toLowerCase().contains(_searchQuery) ||
              (r.category?.toLowerCase().contains(_searchQuery) ?? false))
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final hp = context.pageHorizontalPadding;
    final roomsAsync = ref.watch(roomsStreamProvider);
    final newRoomsAsync = ref.watch(newLiveRoomsProvider);
    final trendingUsersAsync = ref.watch(trendingUsersStreamProvider);

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      safeArea: false,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: VelvetNoir.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Explore',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hp, 8, hp, 12),
              child: _SearchBar(controller: _searchController),
            ),
          ),

          // Category grid (only shown when no search query)
          if (_searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hp, 0, hp, 4),
                child: Text(
                  'Browse by Vibe',
                  style: GoogleFonts.raleway(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: VelvetNoir.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hp),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final cat = _categories[i];
                    final selected = _selectedCategory == cat.value;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedCategory =
                            selected ? null : cat.value;
                      }),
                      child: _CategoryTile(
                        label: cat.label,
                        emoji: cat.emoji,
                        color: cat.color,
                        selected: selected,
                      ),
                    );
                  },
                  childCount: _categories.length,
                ),
              ),
            ),
          ],

          // Active filter indicator
          if (_selectedCategory != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hp, 12, hp, 0),
                child: Row(
                  children: [
                    Text(
                      'Filtering: ',
                      style: GoogleFonts.raleway(
                        fontSize: 13,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: VelvetNoir.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: VelvetNoir.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _selectedCategory!,
                        style: GoogleFonts.raleway(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: VelvetNoir.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategory = null),
                      child: const Icon(Icons.close_rounded,
                          size: 16,
                          color: VelvetNoir.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),

          // Live rooms matching filter
          roomsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: _ShimmerList(),
            ),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox()),
            data: (rooms) {
              final filtered = _filterRooms(rooms);
              if (filtered.isEmpty && (_selectedCategory != null || _searchQuery.isNotEmpty)) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(hp),
                    child: _NoResults(query: _searchQuery.isNotEmpty
                        ? _searchQuery
                        : _selectedCategory ?? ''),
                  ),
                );
              }
              if (filtered.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox());
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => SocialRoomCard(
                    key: ValueKey(filtered[i].id),
                    room: filtered[i],
                    onTap: () => ctx.go('/room/${filtered[i].id}'),
                  ),
                  childCount: filtered.length,
                ),
              );
            },
          ),

          // ── New Rooms section ──
          if (_selectedCategory == null && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hp, 24, hp, 10),
                child: _SectionHeader(
                  title: 'Just Opened',
                  subtitle: 'Brand new rooms',
                  icon: Icons.new_releases_rounded,
                  iconColor: const Color(0xFF10B981),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: newRoomsAsync.when(
                  loading: () => const _HorizontalShimmer(),
                  error: (_, _) => const SizedBox(),
                  data: (rooms) {
                    if (rooms.isEmpty) return const SizedBox();
                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: hp),
                      scrollDirection: Axis.horizontal,
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 10),
                      itemBuilder: (ctx, i) => SocialRoomCardCompact(
                        key: ValueKey(rooms[i].id),
                        room: rooms[i],
                        onTap: () => ctx.go('/room/${rooms[i].id}'),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Suggested Hosts section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hp, 24, hp, 10),
                child: _SectionHeader(
                  title: 'Suggested Hosts',
                  subtitle: 'People making noise',
                  icon: Icons.record_voice_over_rounded,
                  iconColor: VelvetNoir.primary,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 130,
                child: trendingUsersAsync.when(
                  loading: () => const _HorizontalShimmer(height: 130),
                  error: (_, _) => const SizedBox(),
                  data: (users) {
                    if (users.isEmpty) return const SizedBox();
                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: hp),
                      scrollDirection: Axis.horizontal,
                      itemCount: users.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 12),
                      itemBuilder: (ctx, i) => TrendingUserCard(
                        key: ValueKey(users[i].id),
                        user: users[i],
                        onTap: () => ctx.go('/profile/${users[i].id}'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: VelvetNoir.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.raleway(
            fontSize: 14, color: VelvetNoir.onSurface),
        decoration: InputDecoration(
          hintText: 'Search rooms, categories...',
          hintStyle: GoogleFonts.raleway(
              fontSize: 14, color: VelvetNoir.onSurfaceVariant),
          prefixIcon: const Icon(Icons.search_rounded,
              color: VelvetNoir.onSurfaceVariant, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: VelvetNoir.onSurfaceVariant, size: 18),
                    onPressed: controller.clear,
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.emoji,
    required this.color,
    required this.selected,
  });

  final String label;
  final String emoji;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [color, color.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  color.withValues(alpha: 0.12),
                  VelvetNoir.surfaceHigh,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.7)
              : color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.raleway(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : color,
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

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'No rooms found for "$query"',
              style: GoogleFonts.raleway(
                fontSize: 14,
                color: VelvetNoir.onSurfaceVariant,
              ),
            ),
          ],
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
          height: 86,
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _HorizontalShimmer extends StatelessWidget {
  const _HorizontalShimmer({this.height = 200});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(left: 16),
          width: 160,
          height: height,
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
