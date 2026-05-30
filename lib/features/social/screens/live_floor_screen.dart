import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/layout/app_layout.dart';
import 'package:mixvy/dev/app_debug_flags.dart';
import 'package:mixvy/dev/app_state_reasoning.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';
import 'package:mixvy/shared/widgets/guest_auth_gate.dart';
import 'package:mixvy/shared/widgets/ui_stability_contract.dart';

// ── Sort options ──────────────────────────────────────────────────────────────
enum _FloorSort { mostSpeakers, mostListeners, newestLive }

extension on _FloorSort {
  String get label {
    switch (this) {
      case _FloorSort.mostSpeakers:
        return 'Most Active';
      case _FloorSort.mostListeners:
        return 'Most Listeners';
      case _FloorSort.newestLive:
        return 'Newest Live';
    }
  }

  IconData get icon {
    switch (this) {
      case _FloorSort.mostSpeakers:
        return Icons.mic_rounded;
      case _FloorSort.mostListeners:
        return Icons.people_alt_rounded;
      case _FloorSort.newestLive:
        return Icons.new_releases_rounded;
    }
  }
}

class RoomsLayoutShell extends StatelessWidget {
  const RoomsLayoutShell({
    super.key,
    required this.hero,
    required this.controls,
    required this.roomList,
  }) : assert(
         true,
         'RoomsLayoutShell requires hero, controls, and roomList sections.',
       );

  final Widget hero;
  final Widget controls;
  final Widget roomList;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        hero,
        controls,
        Expanded(child: roomList),
      ],
    );
  }
}

class RoomsControlsSection extends StatelessWidget {
  const RoomsControlsSection({
    super.key,
    required this.sortLabel,
    this.controlChips = const <Widget>[],
  });

  final String sortLabel;
  final List<Widget> controlChips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: RoomLayoutV1.sortControlsKey,
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        4,
        context.pageHorizontalPadding,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sorted by $sortLabel',
            style: GoogleFonts.raleway(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
          if (controlChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: controlChips),
            ),
          ],
        ],
      ),
    );
  }
}

class RoomsListSection extends StatelessWidget {
  const RoomsListSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: RoomLayoutV1.roomCardsKey,
      width: double.infinity,
      child: child,
    );
  }
}

class RoomsVisibilityDebugPanel extends StatelessWidget {
  const RoomsVisibilityDebugPanel({
    super.key,
    required this.streamStateLabel,
    required this.roomCount,
    required this.visibleRoomCount,
    required this.sortLabel,
    required this.hint,
  });

  final String streamStateLabel;
  final int roomCount;
  final int visibleRoomCount;
  final String sortLabel;
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
      totalCount: roomCount,
      visibleCount: visibleRoomCount,
      filterLabel: 'all',
      errormessage: hint,
      isBackendConfirmed:
          streamStateLabel != 'loading' && streamStateLabel != 'error',
    );

    return StateReasonCard(
      title: 'Rooms Inspector',
      summary: summary,
      metrics: [
        'stream: $streamStateLabel',
        'rooms seen: $roomCount',
        'visible rooms: $visibleRoomCount',
        'sort: $sortLabel',
      ],
      backgroundColor: VelvetNoir.surfaceHigh.withValues(alpha: 0.94),
      borderColor: VelvetNoir.outlineVariant.withValues(alpha: 0.35),
      titleColor: VelvetNoir.primary,
      textColor: VelvetNoir.onSurfaceVariant,
      metricChipBuilder: (label) => _HeroStatPill(label: label),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class LiveFloorScreen extends ConsumerStatefulWidget {
  const LiveFloorScreen({super.key});

  @override
  ConsumerState<LiveFloorScreen> createState() => _LiveFloorScreenState();
}

class _LiveFloorScreenState extends ConsumerState<LiveFloorScreen> {
  _FloorSort _sort = _FloorSort.mostSpeakers;

  Future<void> _startRoomWithGate() async {
    final allowed = await GuestAuthGate.requireRoomCreation(context, ref);
    if (!allowed) return;
    if (!mounted) return;
    context.go('/rooms/create');
  }

  List<RoomModel> _sorted(List<RoomModel> rooms) {
    final list = List<RoomModel>.from(rooms);
    switch (_sort) {
      case _FloorSort.mostSpeakers:
        list.sort(
          (a, b) => b.stageUserIds.length.compareTo(a.stageUserIds.length),
        );
      case _FloorSort.mostListeners:
        list.sort((a, b) {
          final aMem = a.memberCount > 0
              ? a.memberCount
              : a.stageUserIds.length + a.audienceUserIds.length;
          final bMem = b.memberCount > 0
              ? b.memberCount
              : b.stageUserIds.length + b.audienceUserIds.length;
          return bMem.compareTo(aMem);
        });
      case _FloorSort.newestLive:
        list.sort((a, b) {
          final aTime =
              a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(roomVisibilitySectionsProvider);
    final hp = context.pageHorizontalPadding;
    final previewSections = sectionsAsync.valueOrNull;
    final previewPrimaryRooms = _sorted(
      previewSections?.primaryLive
              .map((item) => item.room)
              .toList(growable: false) ??
          const <RoomModel>[],
    );
    final previewColdRooms = _sorted(
      previewSections?.cold.map((item) => item.room).toList(growable: false) ??
          const <RoomModel>[],
    );
    final previewRooms = previewPrimaryRooms.isNotEmpty
        ? previewPrimaryRooms
        : previewColdRooms;
    final listenerCount = previewRooms.fold<int>(
      0,
      (sum, room) =>
          sum +
          (room.memberCount > 0
              ? room.memberCount
              : room.stageUserIds.length + room.audienceUserIds.length),
    );
    final streamStateLabel = sectionsAsync.isLoading
        ? 'loading'
        : sectionsAsync.hasError
        ? 'error'
        : previewRooms.isEmpty
        ? 'empty'
        : 'ready';
    final visibilityHint = sectionsAsync.isLoading
        ? 'Waiting for the stabilized live room stream.'
        : sectionsAsync.hasError
        ? 'The room stream returned an error, so visible rooms may be temporarily hidden.'
        : previewSections != null &&
              previewSections.primaryLive.isEmpty &&
              previewSections.cold.isNotEmpty
        ? 'Primary rooms are empty; showing cold fallback while freshness recovers.'
        : previewRooms.isEmpty
        ? 'No rooms currently match visibility tiers.'
        : 'Rooms are visible and sorted for quick entry.';

    RoomLayoutV1.debugAssertOrder(const <String>[
      RoomLayoutV1.heroSlotId,
      RoomLayoutV1.quickJoinSlotId,
      RoomLayoutV1.sortControlsSlotId,
      RoomLayoutV1.roomCardsSlotId,
    ]);

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      safeArea: false,
      body: Column(
        children: [
          Material(
            color: VelvetNoir.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hp, 12, hp, 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: VelvetNoir.liveGlow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: VelvetNoir.liveGlow.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rooms',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: VelvetNoir.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: VelvetNoir.primary,
                      ),
                      tooltip: 'Start a Room',
                      onPressed: _startRoomWithGate,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: RoomsLayoutShell(
              hero: Padding(
                padding: EdgeInsets.fromLTRB(hp, 10, hp, 0),
                child: LiveFloorHeroBanner(
                  key: RoomLayoutV1.heroKey,
                  roomCount: previewRooms.length,
                  listenerCount: listenerCount,
                  isLoading: sectionsAsync.isLoading,
                  sortLabel: _sort.label,
                  onQuickJoin: () {
                    if (previewRooms.isNotEmpty) {
                      context.go('/room/${previewRooms.first.id}');
                      return;
                    }
                    _startRoomWithGate();
                  },
                  onStartRoom: _startRoomWithGate,
                ),
              ),
              controls: RoomsControlsSection(
                sortLabel: _sort.label,
                controlChips: _FloorSort.values
                    .map((s) {
                      final selected = _sort == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _sort = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(
                                      colors: [
                                        VelvetNoir.primary,
                                        VelvetNoir.primaryDim,
                                      ],
                                    )
                                  : null,
                              color: selected ? null : VelvetNoir.surfaceHigh,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : VelvetNoir.outlineVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  s.icon,
                                  size: 13,
                                  color: selected
                                      ? VelvetNoir.surface
                                      : VelvetNoir.onSurfaceVariant,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  s.label,
                                  style: GoogleFonts.raleway(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: selected
                                        ? VelvetNoir.surface
                                        : VelvetNoir.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              roomList: RoomsListSection(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, 8),
                      child: RoomsVisibilityDebugPanel(
                        streamStateLabel: streamStateLabel,
                        roomCount: previewSections?.totalClassified ?? 0,
                        visibleRoomCount:
                            previewSections?.allVisible.length ?? 0,
                        sortLabel: _sort.label,
                        hint: visibilityHint,
                      ),
                    ),
                    Expanded(
                      child: sectionsAsync.when(
                        loading: () => const _FloorLoadingShimmer(),
                        error: (e, _) => Padding(
                          padding: EdgeInsets.all(hp),
                          child: Center(
                            child: Text(
                              'Could not load live rooms.',
                              style: GoogleFonts.raleway(
                                color: VelvetNoir.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        data: (sections) {
                          final discoverable = _sorted(
                            sections.discoverable
                                .map((item) => item.room)
                                .toList(growable: false),
                          );
                          final warm = _sorted(
                            sections.warm
                                .map((item) => item.room)
                                .toList(growable: false),
                          );
                          final cold = _sorted(
                            sections.cold
                                .map((item) => item.room)
                                .toList(growable: false),
                          );

                          if (discoverable.isEmpty &&
                              warm.isEmpty &&
                              cold.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.all(hp),
                              child: _EmptyFloor(
                                onCreateRoom: _startRoomWithGate,
                              ),
                            );
                          }

                          return ListView(
                            padding: EdgeInsets.only(bottom: 100),
                            children: [
                              _TierSection(
                                title: 'Discoverable',
                                subtitle: 'Fresh activity right now',
                                rooms: discoverable,
                                color: VelvetNoir.primary,
                              ),
                              _TierSection(
                                title: 'Warm',
                                subtitle: 'Still active and joinable',
                                rooms: warm,
                                color: const Color(0xFFE2A85A),
                              ),
                              _TierSection(
                                title: 'Cold',
                                subtitle:
                                    'Recent rooms while live traffic recovers',
                                rooms: cold,
                                color: const Color(0xFF9A7A5A),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierSection extends StatelessWidget {
  const _TierSection({
    required this.title,
    required this.subtitle,
    required this.rooms,
    required this.color,
  });

  final String title;
  final String subtitle;
  final List<RoomModel> rooms;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${rooms.length})',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: VelvetNoir.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.raleway(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...rooms.asMap().entries.map((entry) {
            final index = entry.key;
            final room = entry.value;
            return _FloorRoomTile(
              room: room,
              rank: index + 1,
              onTap: () => context.go('/room/${room.id}'),
            );
          }),
        ],
      ),
    );
  }
}

// ── Room tile with rank + hot badge ──────────────────────────────────────────
class LiveFloorHeroBanner extends StatelessWidget {
  const LiveFloorHeroBanner({
    super.key,
    required this.roomCount,
    required this.listenerCount,
    required this.onQuickJoin,
    required this.onStartRoom,
    this.isLoading = false,
    this.sortLabel = 'Most Active',
  });

  final int roomCount;
  final int listenerCount;
  final VoidCallback onQuickJoin;
  final VoidCallback onStartRoom;
  final bool isLoading;
  final String sortLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VelvetNoir.surfaceHigh, Color(0xFF241118)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                decoration: BoxDecoration(
                  color: VelvetNoir.liveGlow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: VelvetNoir.liveGlow.withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Jump into a live room',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: VelvetNoir.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroStatPill(
                label: isLoading
                    ? 'Loading live rooms'
                    : '$roomCount active rooms',
              ),
              _HeroStatPill(
                label: isLoading
                    ? 'Syncing listener counts'
                    : '$listenerCount listening live',
              ),
              _HeroStatPill(label: 'Sorted by $sortLabel'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The layout stays familiar while the most relevant rooms rise to the top.',
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: RoomLayoutV1.quickJoinKey,
                  onPressed: onQuickJoin,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('Quick Join'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStartRoom,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Start a Room'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VelvetNoir.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: VelvetNoir.onSurface,
        ),
      ),
    );
  }
}

class _FloorRoomTile extends StatelessWidget {
  const _FloorRoomTile({
    required this.room,
    required this.rank,
    required this.onTap,
  });

  final RoomModel room;
  final int rank;
  final VoidCallback onTap;

  bool get _isHot {
    final total = room.memberCount > 0
        ? room.memberCount
        : room.stageUserIds.length + room.audienceUserIds.length;
    return total >= 20 || room.stageUserIds.length >= 4;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SocialRoomCard(room: room, onTap: onTap),
        if (_isHot) Positioned(top: 12, right: 22, child: _HotBadge()),
        if (rank <= 3)
          Positioned(left: 24, bottom: 12, child: _RankBadge(rank: rank)),
      ],
    );
  }
}

class _HotBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFE03450)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE03450).withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        '🔥 HOT',
        style: GoogleFonts.raleway(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = [
      [const Color(0xFFD4AF37), const Color(0xFF9A7B1A)], // gold
      [const Color(0xFFC0C0C0), const Color(0xFF888888)], // silver
      [const Color(0xFFCD7F32), const Color(0xFF8B4513)], // bronze
    ];
    final c = colors[rank - 1];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: c),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '#$rank',
        style: GoogleFonts.raleway(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Empty / loading states ────────────────────────────────────────────────────
class _EmptyFloor extends StatelessWidget {
  const _EmptyFloor({required this.onCreateRoom});
  final VoidCallback onCreateRoom;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Text('🎙️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No live rooms right now',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to open the floor.',
              style: GoogleFonts.raleway(
                fontSize: 14,
                color: VelvetNoir.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onCreateRoom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [VelvetNoir.primary, VelvetNoir.primaryDim],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Start a Room',
                  style: GoogleFonts.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.surface,
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

class _FloorLoadingShimmer extends StatelessWidget {
  const _FloorLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 86,
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}



