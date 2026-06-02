import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Corrected Imports based on actual project structure ---
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/dashboard/leaderboard_provider.dart';
import 'package:mixvy/features/dashboard/widgets/social_pulse_section.dart';
import 'package:mixvy/features/dashboard/daily_checkin_card.dart';
import 'package:mixvy/features/dashboard/leaderboard_strip.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      body: DashboardView(),
    );
  }
}

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedSnapshotProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        Widget mainContent = feedAsync.when(
          loading: () => const LoadingView(),
          error: (e, s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load your dashboard.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: VelvetNoir.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => ref.refresh(homeFeedSnapshotProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (snapshot) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: VelvetNoir.primary.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: VelvetNoir.primary.withValues(alpha: 0.06),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: SocialPulseSection(
                      pulseItems: snapshot.pulseItems,
                      onOpenPulseItem: (item) {
                        // Map pulse item types to routes
                        if (item.type == 'room_momentum') {
                          context.push('/rooms/${item.id}');
                        } else if (item.type == 'followed_user') {
                          context.push('/profile/${item.id}');
                        } else {
                          context.push('/rooms/${item.id}');
                        }
                      },
                      onOpenRooms: () => context.push('/rooms'),
                      onOpenDiscover: () => context.push('/explore'),
                      headline: snapshot.headline,
                      subheadline: snapshot.subheadline,
                      liveRoomCount: snapshot.liveRooms.length,
                      suggestionCount: snapshot.suggestedUsers.length,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Additional dashboard sections can be added here
              ],
            );
          },
        );

        Widget sideBar = SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.only(top: 8, right: 8),
            padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: VelvetNoir.primary.withValues(alpha: 0.14),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: VelvetNoir.primary.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                // Make the checkin card tappable
                InkWell(
                  onTap: () => context.push('/checkin'),
                  borderRadius: BorderRadius.circular(10),
                  child: const DailyCheckinCard(),
                ),
                const SizedBox(height: 12),
                leaderboardAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (_) => const LeaderboardStrip(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: SingleChildScrollView(child: mainContent)),
              const SizedBox(width: 16),
              SizedBox(width: 360, child: sideBar),
            ],
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mainContent,
                const SizedBox(height: 12),
                sideBar,
              ],
            ),
          ),
        );
      },
    );
  }
}

// Simple loading skeleton for dashboard sections
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
          padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
