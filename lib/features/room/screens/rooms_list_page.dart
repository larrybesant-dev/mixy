/// Vibe-Driven Room Discovery Page
/// The social playground where every room has an energy.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/widgets/club_background.dart';
import '../../../shared/models/room.dart';
import '../../../shared/models/room_categories.dart';
import '../../../shared/providers/all_providers.dart' hide roomsProvider;
import '../../../shared/providers/social_graph_providers.dart';
import '../providers/rooms_provider.dart';

// ─── Vibe identity ───────────────────────────────────────────────────────────
const _kVibeAll = 'All';
const _kVibes = [
  _kVibeAll,
  'Chill',
  'Hype',
  'Deep Talk',
  'Late Night',
  'Study',
  'Party',
];

const _kVibeColors = <String, Color>{
  'Chill': Color(0xFF4A90FF),
  'Hype': Color(0xFFFF4D8B),
  'Deep Talk': Color(0xFF8B5CF6),
  'Late Night': Color(0xFF6366F1),
  'Study': Color(0xFF00E5CC),
  'Party': Color(0xFFFFAB00),
};

const _kVibeIcons = <String, IconData>{
  'Chill': Icons.waves_outlined,
  'Hype': Icons.bolt,
  'Deep Talk': Icons.forum_outlined,
  'Late Night': Icons.nightlight_outlined,
  'Study': Icons.menu_book_outlined,
  'Party': Icons.celebration_outlined,
};

Color _vibeColor(String? vibe) => _kVibeColors[vibe] ?? DesignColors.accent;
IconData _vibeIcon(String? vibe) => _kVibeIcons[vibe] ?? Icons.graphic_eq;

// ─────────────────────────────────────────────────────────────────────────────

class RoomsListPage extends ConsumerStatefulWidget {
  const RoomsListPage({super.key});

  @override
  ConsumerState<RoomsListPage> createState() => _RoomsListPageState();
}

class _RoomsListPageState extends ConsumerState<RoomsListPage>
    with SingleTickerProviderStateMixin {
  String _selectedVibe = _kVibeAll;
  String? _selectedCategory;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<Room> _filtered(List<Room> all, {String? userVibe}) {
    final rooms = _selectedVibe == _kVibeAll
        ? [...all]
        : all
            .where((r) =>
                (r.vibeTag?.toLowerCase() == _selectedVibe.toLowerCase()) ||
                r.tags
                    .any((t) => t.toLowerCase() == _selectedVibe.toLowerCase()))
            .toList();
    rooms.sort((a, b) {
      final aScore = (a.viewerCount * 0.4) +
          (a.boostScore * 0.2) +
          (a.vibeTag == userVibe ? 20.0 : 0.0) +
          (a.joinVelocity * 1.0);
      final bScore = (b.viewerCount * 0.4) +
          (b.boostScore * 0.2) +
          (b.vibeTag == userVibe ? 20.0 : 0.0) +
          (b.joinVelocity * 1.0);
      return bScore.compareTo(aScore);
    });
    return rooms;
  }

  List<Room> _heatingUp(List<Room> all) {
    final live = all.where((r) => r.isLive).toList()
      ..sort((a, b) {
        final aScore = (a.joinVelocity * 2) + a.viewerCount;
        final bScore = (b.joinVelocity * 2) + b.viewerCount;
        return bScore.compareTo(aScore);
      });
    return live.take(6).toList();
  }

  int _friendsInRoom(Room room, List<String> followingIds) =>
      room.participantIds.where(followingIds.contains).length;

  @override
  Widget build(BuildContext context) {
    final roomsState = ref.watch(roomsProvider);
    final allRooms = roomsState.rooms;
    // Derive uid reactively from profile so friends pill updates on login/logout
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final uid = profile?.id;
    final followingIds = uid != null
        ? ref.watch(followingIdsProvider(uid)).asData?.value ?? <String>[]
        : <String>[];
    final filtered = _filtered(allRooms, userVibe: profile?.topVibe);
    final hot = _heatingUp(allRooms);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _buildCreateFab(),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(child: _buildVibeFilterBar()),
              if (_selectedVibe == _kVibeAll && hot.isNotEmpty)
                SliverToBoxAdapter(child: _buildHeatingUpRail(hot)),
              SliverToBoxAdapter(child: _buildCategoryBar()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(
                                  alpha: 0.7 * _pulseController.value),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${filtered.length} room${filtered.length == 1 ? '' : 's'} live now',
                      style: const TextStyle(
                          color: DesignColors.textGray, fontSize: 12),
                    ),
                  ]),
                ),
              ),
              roomsState.isLoading && allRooms.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()))
                  : filtered.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) =>
                                  _buildRoomCard(filtered[i], followingIds),
                              childCount: filtered.length,
                            ),
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.accent,
            boxShadow: [
              BoxShadow(
                  color: DesignColors.accent.withValues(alpha: 0.7),
                  blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Text('LIVE ROOMS',
            style: TextStyle(
              color: DesignColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: DesignColors.primaryGlow,
            )),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: DesignColors.textGray),
          onPressed: () {},
          tooltip: 'Search rooms',
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  VIBE FILTER BAR
  // ══════════════════════════════════════════════════════════
  Widget _buildVibeFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      child: SizedBox(
        height: 52,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _kVibes.length,
          itemBuilder: (_, i) {
            final vibe = _kVibes[i];
            final isAll = vibe == _kVibeAll;
            final selected = _selectedVibe == vibe;
            final color = isAll ? DesignColors.accent : _vibeColor(vibe);
            final icon = isAll ? Icons.apps_outlined : _vibeIcon(vibe);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedVibe = vibe),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [color, color.withValues(alpha: 0.5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: selected ? null : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected ? color : color.withValues(alpha: 0.35),
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon,
                        size: 13, color: selected ? Colors.white : color),
                    const SizedBox(width: 5),
                    Text(vibe,
                        style: TextStyle(
                          color: selected ? Colors.white : color,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HEATING UP RAIL
  // ══════════════════════════════════════════════════════════
  Widget _buildHeatingUpRail(List<Room> rooms) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text('HEATING UP',
              style: TextStyle(
                color: DesignColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                shadows: DesignColors.secondaryGlow,
              )),
          const SizedBox(width: 8),
          Expanded(
              child: Container(
                  height: 1,
                  color: DesignColors.secondary.withValues(alpha: 0.3))),
        ]),
      ),
      SizedBox(
        height: 148,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: rooms.length,
          itemBuilder: (_, i) => _buildHotCard(rooms[i]),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildHotCard(Room room) {
    final color = _vibeColor(room.vibeTag);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/room', arguments: room.id),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.18),
                DesignColors.surfaceDefault
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DesignColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                if (room.isLive) _liveBadge(),
              ]),
              const SizedBox(height: 6),
              if (room.vibeTag != null) _miniVibeChip(room.vibeTag!, color),
              const Spacer(),
              _energyBar(room, color),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.people_outline,
                    size: 12, color: DesignColors.textGray),
                const SizedBox(width: 4),
                Text('${room.viewerCount}',
                    style: const TextStyle(
                        color: DesignColors.textGray, fontSize: 11)),
                if (room.camCount > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.videocam_outlined,
                      size: 12, color: DesignColors.textGray),
                  const SizedBox(width: 4),
                  Text('${room.camCount}',
                      style: const TextStyle(
                          color: DesignColors.textGray, fontSize: 11))
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CATEGORY CHIP BAR
  // ══════════════════════════════════════════════════════════
  Widget _buildCategoryBar() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _categoryChip('All', null),
          ...RoomCategories.all
              .map((c) => _categoryChip(RoomCategories.getDisplayName(c), c)),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? value) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCategory = selected ? null : value);
          ref.read(roomsProvider.notifier).setCategory(_selectedCategory);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? DesignColors.accent.withValues(alpha: 0.25)
                : DesignColors.surfaceLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? DesignColors.accent.withValues(alpha: 0.7)
                  : DesignColors.divider.withValues(alpha: 0.4),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? DesignColors.accent : DesignColors.textGray,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              )),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  MAIN ROOM CARD
  // ══════════════════════════════════════════════════════════
  Widget _buildRoomCard(Room room, List<String> followingIds) {
    final color = _vibeColor(room.vibeTag);
    final isHot = room.viewerCount >= 5;
    final friendCount = _friendsInRoom(room, followingIds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/room', arguments: room.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: DesignColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _roomThumbnail(room, color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(room.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: DesignColors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                )),
                          ),
                          if (room.isLive) ...[
                            const SizedBox(width: 6),
                            _liveBadge()
                          ],
                        ]),
                        const SizedBox(height: 4),
                        if (room.description.isNotEmpty)
                          Text(room.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: DesignColors.textGray, fontSize: 12)),
                        const SizedBox(height: 8),
                        _buildStatsRow(room, color),
                      ]),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.arrow_forward_ios,
                      size: 13, color: DesignColors.textGray),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (room.vibeTag != null) ...[
                  _miniVibeChip(room.vibeTag!, color),
                  const SizedBox(width: 6)
                ],
                _categoryTag(room.category),
                if (isHot) ...[const SizedBox(width: 6), _hotTag()],
                if (friendCount > 0) ...[
                  const SizedBox(width: 6),
                  _friendsPill(friendCount)
                ],
                const Spacer(),
                SizedBox(width: 80, child: _energyBar(room, color)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _roomThumbnail(Room room, Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final glow = room.isLive
            ? color.withValues(alpha: 0.3 + 0.2 * _pulseController.value)
            : color.withValues(alpha: 0.1);
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: glow, blurRadius: 14)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: room.thumbnailUrl != null
                ? Image.network(room.thumbnailUrl!, fit: BoxFit.cover)
                : Stack(alignment: Alignment.center, children: [
                    Icon(_vibeIcon(room.vibeTag),
                        size: 30, color: color.withValues(alpha: 0.5)),
                    if (room.isLive) Positioned(bottom: 6, child: _liveBadge()),
                  ]),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(Room room, Color color) {
    return Row(children: [
      Icon(Icons.people_outline, size: 13, color: color),
      const SizedBox(width: 4),
      Text('${room.viewerCount}',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 10),
      if (room.camCount > 0) ...[
        const Icon(Icons.videocam_outlined,
            size: 13, color: DesignColors.textGray),
        const SizedBox(width: 4),
        Text('${room.camCount} 📷',
            style: const TextStyle(color: DesignColors.textGray, fontSize: 11)),
        const SizedBox(width: 10),
      ],
      Text('${room.currentMembers}/${room.capacity}',
          style: const TextStyle(color: DesignColors.textGray, fontSize: 11)),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  //  MICRO-WIDGETS
  // ══════════════════════════════════════════════════════════
  Widget _liveBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent
                  .withValues(alpha: 0.6 * _pulseController.value),
              blurRadius: 6,
            )
          ],
        ),
        child: const Text('LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            )),
      ),
    );
  }

  Widget _miniVibeChip(String vibe, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_vibeIcon(vibe), size: 10, color: color),
        const SizedBox(width: 4),
        Text(vibe,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _categoryTag(String cat) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: DesignColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(RoomCategories.getDisplayName(cat),
            style: const TextStyle(color: DesignColors.textGray, fontSize: 10)),
      );

  Widget _friendsPill(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5CC).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFF00E5CC).withValues(alpha: 0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.people_outline, size: 10, color: Color(0xFF00E5CC)),
          const SizedBox(width: 4),
          Text('$count friend${count > 1 ? 's' : ''} here',
              style: const TextStyle(
                  color: Color(0xFF00E5CC),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _hotTag() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: DesignColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: DesignColors.secondary.withValues(alpha: 0.4)),
        ),
        child: const Text('🔥 Hot',
            style: TextStyle(
              color: DesignColors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            )),
      );

  Widget _energyBar(Room room, Color color) {
    final ratio =
        (room.viewerCount / math.max(room.maxUsers, 1)).clamp(0.0, 1.0);
    final label = ratio < 0.15
        ? 'Quiet'
        : ratio < 0.5
            ? 'Active'
            : 'Buzzing';
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Energy',
                style: TextStyle(color: DesignColors.textGray, fontSize: 9)),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ]);
  }

  // ══════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    final color = _vibeColor(_selectedVibe == _kVibeAll ? null : _selectedVibe);
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 20)
            ],
          ),
          child: Icon(
            _selectedVibe == _kVibeAll
                ? Icons.video_call_outlined
                : _vibeIcon(_selectedVibe),
            size: 42,
            color: color.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _selectedVibe == _kVibeAll
              ? 'No rooms live yet'
              : 'No $_selectedVibe rooms right now',
          style: const TextStyle(
            color: DesignColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedVibe == _kVibeAll
              ? 'Drop in and be the first to set the vibe.'
              : 'Be the first to start a $_selectedVibe room 🎉',
          textAlign: TextAlign.center,
          style: const TextStyle(color: DesignColors.textGray, fontSize: 13),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _showCreateRoomDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14)
              ],
            ),
            child: const Text('Create a Room',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CREATE ROOM FAB
  // ══════════════════════════════════════════════════════════
  Widget _buildCreateFab() {
    final vibeAccent = ref.watch(vibeAccentProvider);
    final vibeGlow = ref.watch(vibeGlowProvider);
    return GestureDetector(
      onTap: _showCreateRoomDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [vibeAccent, vibeAccent.withValues(alpha: 0.6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: vibeGlow, // first real vibeGlowProvider consumer
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('Create Room',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CREATE ROOM DIALOG  (with vibe picker)
  // ══════════════════════════════════════════════════════════
  Future<void> _showCreateRoomDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedCategory;
    String? selectedVibe;

    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: DesignColors.surfaceLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.mic_none_outlined,
                        color: DesignColors.accent, size: 20),
                    SizedBox(width: 8),
                    Text('Create a Room',
                        style: TextStyle(
                          color: DesignColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        )),
                  ]),
                  const SizedBox(height: 20),
                  _dialogField(nameController, 'Room Name', Icons.title),
                  const SizedBox(height: 14),
                  _dialogField(descController, 'Vibe description (optional)',
                      Icons.notes,
                      maxLines: 2),
                  const SizedBox(height: 16),
                  const Text('Set the vibe',
                      style: TextStyle(
                        color: DesignColors.textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kVibes.skip(1).map((v) {
                      final color = _vibeColor(v);
                      final picked = selectedVibe == v;
                      return GestureDetector(
                        onTap: () => setDialogState(
                            () => selectedVibe = picked ? null : v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: picked
                                ? color.withValues(alpha: 0.25)
                                : color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: picked
                                  ? color
                                  : color.withValues(alpha: 0.35),
                              width: picked ? 1.5 : 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_vibeIcon(v), size: 12, color: color),
                            const SizedBox(width: 5),
                            Text(v,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: picked
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category',
                      style: TextStyle(
                        color: DesignColors.textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      )),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: DesignColors.surfaceDefault,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DesignColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        dropdownColor: DesignColors.surfaceLight,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Pick a category',
                              style: TextStyle(
                                  color: DesignColors.textGray, fontSize: 13)),
                        ),
                        items: RoomCategories.all
                            .map((c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      RoomCategories.getDisplayName(c),
                                      style: const TextStyle(
                                          color: DesignColors.white,
                                          fontSize: 13),
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedCategory = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel',
                            style: TextStyle(color: DesignColors.textGray)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () async {
                          if (nameController.text.trim().isEmpty) return;
                          final navigator = Navigator.of(ctx);
                          final roomId =
                              await ref.read(roomsProvider.notifier).createRoom(
                                    name: nameController.text.trim(),
                                    description:
                                        descController.text.trim().isEmpty
                                            ? null
                                            : descController.text.trim(),
                                    category: selectedCategory,
                                  );
                          if (mounted && roomId != null) {
                            navigator.pop();
                            // ignore: use_build_context_synchronously
                            Navigator.pushNamed(context, '/room',
                                arguments: roomId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A90FF), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    DesignColors.accent.withValues(alpha: 0.3),
                                blurRadius: 10,
                              )
                            ],
                          ),
                          child: const Center(
                            child: Text('Go Live 🚀',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surfaceDefault,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignColors.divider),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: DesignColors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: DesignColors.textGray, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: DesignColors.textGray),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
