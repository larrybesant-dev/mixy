// lib/features/discover/room_discovery_page_complete.dart
//
// Room Discovery — polished Rooms tab using the full design system.
//
// Sections:
//   • Search bar + Go Live CTA (sticky header)
//   • Vibe filter chips (All, Chill, Hype, Deep Talk, Late Night, Study, Party)
//   • Category chips (All, Music, Gaming, Chat, Entertainment, Education, Sports, Tech)
//   • ⭐ For You  — recommended rooms (friends-present + trending score)
//   • 🔥 Heating Up — horizontal compact-card rail (top-joinVelocity rooms)
//   • Featured — boosted rooms (if any)
//   • Full filtered room list
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/analytics/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../core/design_system/design_constants.dart';
import '../../shared/widgets/club_background.dart';
import '../../shared/models/room.dart';
import '../../app/app_routes.dart';
import 'providers/room_discovery_providers.dart';
import 'widgets/room_discovery_card.dart';
import 'widgets/room_preview_sheet.dart';
import '../room/room_access_wrapper.dart';

// ── Vibe config ───────────────────────────────────────────────────────────────

const _kVibes = [
  ('All', Icons.apps_outlined, DesignColors.accent),
  ('Chill', Icons.waves_outlined, Color(0xFF4A90FF)),
  ('Hype', Icons.bolt, Color(0xFFFF4D8B)),
  ('Deep Talk', Icons.forum_outlined, Color(0xFF8B5CF6)),
  ('Late Night', Icons.nightlight_outlined, Color(0xFF6366F1)),
  ('Study', Icons.menu_book_outlined, Color(0xFF00E5CC)),
  ('Party', Icons.celebration_outlined, Color(0xFFFFAB00)),
];

const _kCategories = [
  'All',
  'Music',
  'Gaming',
  'Chat',
  'Entertainment',
  'Education',
  'Sports',
  'Technology',
  'Lifestyle',
];

// ── Page ──────────────────────────────────────────────────────────────────────

/// Complete Room Discovery Page — used as the Rooms tab in HomePageElectric.
class RoomDiscoveryPageComplete extends ConsumerStatefulWidget {
  const RoomDiscoveryPageComplete({super.key});

  @override
  ConsumerState<RoomDiscoveryPageComplete> createState() =>
      _RoomDiscoveryPageCompleteState();
}

class _RoomDiscoveryPageCompleteState
    extends ConsumerState<RoomDiscoveryPageComplete> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _joinRoom(Room room) {
    HapticFeedback.mediumImpact();
    AnalyticsService().trackRoomJoined(room.id, room.title);
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomAccessWrapper(room: room, userId: uid),
      ),
    );
  }

  /// Shows the room preview bottom sheet, then joins on confirmation.
  void _previewRoom(Room room) {
    AnalyticsService().logEvent('room_preview_opened', parameters: {
      'room_id': room.id,
      'room_title': room.title,
    });
    RoomPreviewSheet.show(
      context,
      room: room,
      onJoin: () => _joinRoom(room),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredLiveRoomsProvider);
    final heatingUp = ref.watch(heatingUpRoomsProvider);
    final featured = ref.watch(featuredRoomsProvider);
    final recommended = ref.watch(recommendedRoomsProvider);
    final selectedVibe = ref.watch(discoveryVibeFilterProvider);
    final selectedCat = ref.watch(discoveryCategoryFilterProvider);
    final roomCountMap = ref.watch(roomCountByCategoryProvider);
    final searchText = _searchController.text;

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            // ── Search + Go Live header ──────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSearchHeader(selectedVibe),
            ),

            // ── Vibe filter chips ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildVibeChips(selectedVibe),
            ),

            // ── Category chips ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildCategoryChips(selectedCat, roomCountMap),
            ),

            // ── Heating Up rail (hidden when filtering) ───────────────────
            if (selectedVibe.isEmpty &&
                selectedCat.isEmpty &&
                searchText.isEmpty &&
                heatingUp.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHeatingUpSection(heatingUp),
              ),

            // ── For You — recommended rooms (hidden when filtering) ────────
            if (selectedVibe.isEmpty &&
                selectedCat.isEmpty &&
                searchText.isEmpty &&
                recommended.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildForYouSection(recommended),
              ),

            // ── Featured section ──────────────────────────────────────────
            if (selectedVibe.isEmpty &&
                selectedCat.isEmpty &&
                searchText.isEmpty &&
                featured.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildFeaturedBanner(featured.first),
              ),

            // ── Section header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(selectedVibe, selectedCat),
            ),

            // ── Room list ─────────────────────────────────────────────────
            filteredAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: DesignColors.accent),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _buildError(e),
              ),
              data: (rooms) {
                if (rooms.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmpty(selectedVibe, selectedCat),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RoomDiscoveryCard(
                        room: rooms[i],
                        onTap: () => _previewRoom(rooms[i]),
                      ),
                    ),
                    childCount: rooms.length,
                  ),
                );
              },
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search header ─────────────────────────────────────────────────────────

  Widget _buildSearchHeader(String selectedVibe) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Title (hidden when a vibe is selected to save space)
          if (selectedVibe.isEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text(
                'Live Rooms',
                style: TextStyle(
                  color: DesignColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),

          // Search bar
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: DesignColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignColors.divider),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  ref.read(discoverySearchQueryProvider.notifier).set(v);
                  setState(() {});
                },
                style: const TextStyle(
                    color: DesignColors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search rooms…',
                  hintStyle: TextStyle(
                      color: DesignColors.textGray, fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: DesignColors.textGray, size: 18),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Go Live button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.goLive),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4D8B), DesignColors.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D8B).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Go Live',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vibe chips ────────────────────────────────────────────────────────────

  Widget _buildVibeChips(String selectedVibe) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _kVibes.length,
        itemBuilder: (_, i) {
          final (label, icon, color) = _kVibes[i];
          final isAll = label == 'All';
          final selected =
              isAll ? selectedVibe.isEmpty : selectedVibe == label;

          return GestureDetector(
            onTap: () {
              ref.read(discoveryVibeFilterProvider.notifier).set(
                  isAll ? '' : label);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : DesignColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.6)
                      : DesignColors.divider,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 6,
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 13,
                      color: selected ? color : DesignColors.textGray),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? color : DesignColors.textGray,
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Category chips ────────────────────────────────────────────────────────

  Widget _buildCategoryChips(
      String selectedCat, Map<String, int> countMap) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        itemCount: _kCategories.length,
        itemBuilder: (_, i) {
          final cat = _kCategories[i];
          final isAll = cat == 'All';
          final selected =
              isAll ? selectedCat.isEmpty : selectedCat == cat;
          final count = isAll ? null : countMap[cat];

          return GestureDetector(
            onTap: () {
              ref.read(discoveryCategoryFilterProvider.notifier).set(
                  isAll ? '' : cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? DesignColors.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? DesignColors.accent.withValues(alpha: 0.5)
                      : DesignColors.divider,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat,
                    style: TextStyle(
                      color: selected
                          ? DesignColors.accent
                          : DesignColors.textGray,
                      fontSize: 11.5,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  if (count != null && count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: selected
                            ? DesignColors.accent
                            : DesignColors.textGray,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Heating up rail ───────────────────────────────────────────────────────

  Widget _buildHeatingUpSection(List<Room> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFFF6B35), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Heating Up',
                style: TextStyle(
                  color: DesignColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'trending now',
                style: TextStyle(
                    color: Color(0xFFFF6B35), fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: rooms.length,
            itemBuilder: (_, i) => RoomDiscoveryCardCompact(
              room: rooms[i],
              onTap: () => _previewRoom(rooms[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── For You section ────────────────────────────────────────────────

  Widget _buildForYouSection(List<Room> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D8B), DesignColors.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'For You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Based on friends & trends',
                  style: TextStyle(
                    color: DesignColors.textGray,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: rooms.length,
            itemBuilder: (_, i) => RoomDiscoveryCardCompact(
              room: rooms[i],
              onTap: () => _previewRoom(rooms[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Featured banner ───────────────────────────────────────────────

  Widget _buildFeaturedBanner(Room room) {
    return GestureDetector(
      onTap: () => _previewRoom(room),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              DesignColors.tertiary.withValues(alpha: 0.6),
              DesignColors.accent.withValues(alpha: 0.4),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: DesignColors.tertiary.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: DesignColors.tertiary.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignColors.gold.withValues(alpha: 0.12),
                border: Border.all(
                    color: DesignColors.gold.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.star,
                  color: DesignColors.gold, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'FEATURED ROOM',
                    style: TextStyle(
                      color: DesignColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DesignColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.people,
                          size: 12, color: DesignColors.textGray),
                      const SizedBox(width: 4),
                      Text(
                        '${room.viewerCount} listening',
                        style: const TextStyle(
                          color: DesignColors.textGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DesignColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: DesignColors.gold.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.arrow_forward,
                  color: DesignColors.gold, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String vibe, String cat) {
    final showingAll =
        vibe.isEmpty && cat.isEmpty && _searchController.text.isEmpty;
    final label = [
      if (vibe.isNotEmpty) vibe,
      if (cat.isNotEmpty) cat,
      if (_searchController.text.isNotEmpty) '"${_searchController.text}"',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            showingAll ? 'All Live Rooms' : label,
            style: const TextStyle(
              color: DesignColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (!showingAll)
            GestureDetector(
              onTap: _clearFilters,
              child: const Row(
                children: [
                  Icon(Icons.close, size: 13, color: DesignColors.accent),
                  SizedBox(width: 3),
                  Text(
                    'Clear',
                    style: TextStyle(
                        color: DesignColors.accent, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _clearFilters() {
    ref.read(discoveryVibeFilterProvider.notifier).set('');
    ref.read(discoveryCategoryFilterProvider.notifier).set('');
    ref.read(discoverySearchQueryProvider.notifier).set('');
    _searchController.clear();
    setState(() {});
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty(String vibe, String cat) {
    final hasFilter = vibe.isNotEmpty ||
        cat.isNotEmpty ||
        _searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignColors.accent.withValues(alpha: 0.08),
              ),
              child: const Icon(Icons.voice_chat,
                  color: DesignColors.accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilter
                  ? 'No rooms match your filters'
                  : 'No live rooms right now',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DesignColors.textLightGray,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try a different vibe or category'
                  : 'Be the first to go live!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: DesignColors.textGray, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (hasFilter)
              GestureDetector(
                onTap: _clearFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: DesignColors.accent.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Clear Filters',
                      style: TextStyle(
                          color: DesignColors.accent, fontSize: 13)),
                ),
              )
            else
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.goLive),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D8B), DesignColors.tertiary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D8B)
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Go Live Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: DesignColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load rooms',
              style: TextStyle(
                color: DesignColors.textLightGray,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: DesignColors.textGray, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
