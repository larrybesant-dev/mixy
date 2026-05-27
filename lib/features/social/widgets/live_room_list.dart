import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

/// A production-ready, beautifully themed Live Room List widget.
/// 
/// Binds dynamically to the system's live rooms state with:
/// - Real-time stream data binding via Riverpod (no mock data).
/// - Elegant pulsing skeleton shimmers for the loading state.
/// - High-contrast "Empty State" UI matching our Digital Premium Lounge theme.
/// - Polished error state with a retry option for connection failures.
class LiveRoomList extends ConsumerWidget {
  const LiveRoomList({
    super.key,
    this.onRoomTap,
    this.onStartRoomTap,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// Custom tap callback for when a user clicks on a live room.
  /// If null, navigates automatically to the room's route.
  final void Function(RoomModel room)? onRoomTap;

  /// Custom tap callback for the empty state or quick actions to start a room.
  /// If null, navigates automatically to `/rooms/create`.
  final VoidCallback? onStartRoomTap;

  /// Layout padding applied around the list.
  final EdgeInsetsGeometry padding;

  void _handleRoomNavigation(BuildContext context, RoomModel room) {
    if (onRoomTap != null) {
      onRoomTap!(room);
      return;
    }
    // Absolute route for rooms under our StatefulShellBranch
    final encodedRoomId = Uri.encodeComponent(room.id.trim());
    context.go('/rooms/room/$encodedRoomId', extra: room);
  }

  void _handleCreateRoom(BuildContext context) {
    if (onStartRoomTap != null) {
      onStartRoomTap!();
      return;
    }
    context.go('/rooms/create');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsStreamProvider);

    return roomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return _EmptyStateView(
            onStartRoom: () => _handleCreateRoom(context),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return SocialRoomCard(
              key: ValueKey<String>('live-room-list-${room.id}'),
              room: room,
              onTap: () => _handleRoomNavigation(context, room),
            );
          },
        );
      },
      loading: () => const _LoadingShimmerView(),
      error: (error, _) => _ErrorStateView(
        onRetry: () => ref.invalidate(roomsStreamProvider),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading State (Elegant, self-contained pulsing shimmer cards)
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingShimmerView extends StatefulWidget {
  const _LoadingShimmerView();

  @override
  State<_LoadingShimmerView> createState() => _LoadingShimmerViewState();
}

class _LoadingShimmerViewState extends State<_LoadingShimmerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.4 + (_pulseController.value * 0.45);
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Container(
              height: 98,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: VelvetNoir.surfaceContainer.withOpacity(opacity),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: VelvetNoir.outlineVariant.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 98,
                    decoration: BoxDecoration(
                      color: VelvetNoir.primary.withOpacity(opacity * 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: VelvetNoir.surfaceHigh.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: VelvetNoir.surfaceHigh.withOpacity(opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            width: 180,
                            height: 18,
                            decoration: BoxDecoration(
                              color: VelvetNoir.surfaceHigh.withOpacity(opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: VelvetNoir.surfaceHigh.withOpacity(opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State (Digital Premium Lounge, high contrast theme)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({required this.onStartRoom});

  final VoidCallback onStartRoom;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: VelvetNoir.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.24),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon container with ambient glow
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VelvetNoir.surfaceHigh,
                  border: Border.all(
                    color: VelvetNoir.primary.withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VelvetNoir.primary.withOpacity(0.12),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.mic_off_rounded,
                    color: VelvetNoir.primary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'The Lounge is Quiet',
                style: GoogleFonts.playfairDisplay(
                  color: VelvetNoir.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'No live rooms are active right now. Step up, open the floor, and set the premium energy for everyone arriving today.',
                style: GoogleFonts.raleway(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              MixvyGoldButton(
                label: 'Start the First Room',
                onPressed: onStartRoom,
                height: 48,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State (Clean recovery option)
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorStateView extends StatelessWidget {
  const _ErrorStateView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: VelvetNoir.error.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: VelvetNoir.error,
                size: 36,
              ),
              const SizedBox(height: 14),
              Text(
                'Connection Interrupted',
                style: GoogleFonts.playfairDisplay(
                  color: VelvetNoir.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We could not load the active rooms stream right now. Please check your signal and try again.',
                style: GoogleFonts.raleway(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              MixvyGoldOutlineButton(
                label: 'Retry Connection',
                onPressed: onRetry,
                height: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
