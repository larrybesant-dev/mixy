// lib/features/discover/screens/discover_rooms_live_page.dart
//
// DiscoverRoomsLivePage – real-time list of public, active rooms.
// Uses discoverableRoomsProvider (StreamProvider) for live Firestore updates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/widgets/club_background.dart';
import '../../../shared/widgets/neon_components.dart';
import '../../../shared/providers/discovery_providers.dart';
import '../../../shared/models/room.dart';
import 'package:mixvy/core/routing/app_routes.dart';

/// Full-page screen showing public, active rooms ordered by viewer count.
class DiscoverRoomsLivePage extends ConsumerWidget {
  const DiscoverRoomsLivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(discoverableRoomsProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const NeonText(
            'DISCOVER ROOMS',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            textColor: DesignColors.white,
            glowColor: DesignColors.accent,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_box_rounded, color: DesignColors.accent),
              tooltip: 'Go Live',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.createRoom),
            ),
          ],
        ),
        body: roomsAsync.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return _buildEmptyState(context);
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                return _RoomCard(
                  room: rooms[index],
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.room,
                    arguments: rooms[index].id,
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: DesignColors.accent),
          ),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: DesignColors.error, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load rooms',
                  style: DesignTypography.body
                      .copyWith(color: DesignColors.white),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'discover_rooms_live_fab',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.createRoom),
          backgroundColor: DesignColors.accent,
          label: const Text('GO LIVE',
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          icon: const Icon(Icons.fiber_smart_record),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.live_tv_outlined,
              size: 64,
              color: DesignColors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No live rooms right now',
            style: DesignTypography.heading.copyWith(
              color: DesignColors.white.withValues(alpha: 0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to start one!',
            style: DesignTypography.body.copyWith(
              color: DesignColors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          NeonButton(
            label: 'CREATE ROOM',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.createRoom),
            glowColor: DesignColors.accent,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room card widget
// ─────────────────────────────────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  // Pick an icon based on room category
  IconData get _categoryIcon {
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
      case 'entertainment':
        return Icons.movie_rounded;
      case 'lifestyle':
        return Icons.self_improvement_rounded;
      default:
        return Icons.groups_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonGlowCard(
        glowColor: DesignColors.accent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Category icon / thumbnail
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        DesignColors.accent.withValues(alpha: 0.8),
                        DesignColors.tertiary.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: room.thumbnailUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            room.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              _categoryIcon,
                              color: DesignColors.white,
                              size: 26,
                            ),
                          ),
                        )
                      : Icon(_categoryIcon,
                          color: DesignColors.white, size: 26),
                ),
                const SizedBox(width: 12),

                // Room info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with LIVE badge
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.title,
                              style: DesignTypography.body.copyWith(
                                color: DesignColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.isLive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DesignColors.error,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: DesignColors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Host name
                      if (room.hostName != null)
                        Text(
                          'by ${room.hostName}',
                          style: DesignTypography.caption.copyWith(
                            color: DesignColors.white.withValues(alpha: 0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 5),

                      // Category + viewer count row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  DesignColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: DesignColors.accent
                                    .withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              room.category,
                              style: DesignTypography.caption.copyWith(
                                color: DesignColors.accent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.remove_red_eye_rounded,
                              size: 13,
                              color: DesignColors.white),
                          const SizedBox(width: 3),
                          Text(
                            '${room.viewerCount}',
                            style: DesignTypography.caption.copyWith(
                              color: DesignColors.white
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron
                const Icon(Icons.chevron_right_rounded,
                    color: DesignColors.accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

