import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/firestore/firestore_error_utils.dart';
import '../../../../core/layout/app_layout.dart';
import '../../../../core/theme.dart';
import '../../../../models/room_model.dart';
import '../../../../services/room_service.dart';
import '../../../../shared/widgets/guest_auth_gate.dart';
import 'package:mixvy/features/feed/widgets/live_room_card.dart';
import 'skeleton_loaders.dart';

final roomsByCategoryProvider = StreamProvider.autoDispose.family<List<RoomModel>, String?>((ref, category) {
  ref.keepAlive();
  return ref
      .read(roomServiceProvider)
      .watchLiveRoomsByCategory(category: category, limit: 50)
      .timeout(
        const Duration(seconds: 5),
        onTimeout: (sink) {
          sink.addError(TimeoutException('Connection dropped or timed out while fetching live rooms. Check your internet connectivity.'));
        },
      );
});

class RoomListView extends ConsumerWidget {
  const RoomListView({
    super.key,
    required this.category,
    required this.categoryLabel,
    required this.searchQuery,
    required this.searchController,
    required this.onBack,
  });

  final String? category;
  final String categoryLabel;
  final String searchQuery;
  final TextEditingController searchController;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsByCategoryProvider(category));
    return CustomScrollView(
      key: PageStorageKey('rooms_scroll_position_$category'),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 52, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B1216), VelvetNoir.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VelvetNoir.onSurface, size: 20),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                Text(
                  categoryLabel,
                  style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: VelvetNoir.onSurface),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.pageHorizontalPadding, 0, context.pageHorizontalPadding, 16),
            child: TextField(
              controller: searchController,
              style: GoogleFonts.raleway(fontSize: 14, color: VelvetNoir.onSurface),
              decoration: InputDecoration(
                hintText: 'Search rooms...',
                hintStyle: GoogleFonts.raleway(fontSize: 14, color: VelvetNoir.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search_rounded, color: VelvetNoir.onSurfaceVariant, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: VelvetNoir.onSurfaceVariant, size: 18),
                        onPressed: () => searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: VelvetNoir.surfaceContainer,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: VelvetNoir.outlineVariant.withValues(alpha: 0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: VelvetNoir.outlineVariant.withValues(alpha: 0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: VelvetNoir.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        roomsAsync.when(
          data: (allRooms) {
            final rooms = searchQuery.isEmpty
                ? allRooms
                : allRooms.where((r) => r.name.toLowerCase().contains(searchQuery) || (r.description?.toLowerCase().contains(searchQuery) ?? false)).toList();
            if (rooms.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎙️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('No live rooms right now', style: GoogleFonts.playfairDisplay(fontSize: 18, color: VelvetNoir.onSurface, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Be the first to start one!', style: GoogleFonts.raleway(fontSize: 13, color: VelvetNoir.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: () async {
                            final allowed = await GuestAuthGate.requireRoomCreation(context, ref);
                            if (!allowed || !context.mounted) return;
                            context.go('/create-room');
                          },
                          icon: const Icon(Icons.mic_rounded, color: VelvetNoir.primary),
                          label: Text('Start a Room', style: GoogleFonts.raleway(color: VelvetNoir.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SliverLayoutBuilder(
              builder: (ctx, constraints) {
                final cols = constraints.crossAxisExtent > 900 ? 4 : (constraints.crossAxisExtent > 600 ? 3 : 2);
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(context.pageHorizontalPadding, 0, context.pageHorizontalPadding, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => LiveRoomCard(
                        key: ValueKey(rooms[i].id),
                        featured: i == 0,
                        room: rooms[i],
                        onTap: () => context.go('/room/${rooms[i].id}'),
                      ),
                      childCount: rooms.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const RoomBrowserLoadingSliver(),
          error: (e, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(friendlyFirestoreMessage(e, fallbackContext: 'rooms'), textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RoomBrowserLoadingSliver extends StatelessWidget {
  const RoomBrowserLoadingSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(context.pageHorizontalPadding, 0, context.pageHorizontalPadding, 24),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.crossAxisExtent > 900 ? 4 : (constraints.crossAxisExtent > 600 ? 3 : 2);
          return SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => DecoratedBox(
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VelvetNoir.outlineVariant),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RoomBrowserSkeletonBlock(height: 68, radius: 16),
                    Padding(padding: EdgeInsets.fromLTRB(10, 10, 10, 0), child: RoomBrowserSkeletonLine(widthFactor: 0.64)),
                    Padding(padding: EdgeInsets.fromLTRB(10, 8, 10, 0), child: RoomBrowserSkeletonLine(widthFactor: 0.48)),
                    Padding(padding: EdgeInsets.fromLTRB(10, 10, 10, 0), child: RoomBrowserSkeletonPill()),
                  ],
                ),
              ),
              childCount: cols * 2,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: 1.15,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          );
        },
      ),
    );
  }
}




