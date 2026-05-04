import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_layout.dart';
import '../../feed/providers/feed_providers.dart';
import '../../../models/room_model.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../theme/after_dark_theme.dart';
import '../widgets/after_dark_live_room_card.dart';

// ── Derived adult rooms view (no direct Firestore access in UI layer) ───────
final _liveAdultRoomsProvider =
    Provider.autoDispose<AsyncValue<List<RoomModel>>>((ref) {
      return ref.watch(roomsStreamProvider).whenData((rooms) {
        final filtered =
            rooms
                .where((room) => room.isAdult)
                .toList(growable: false)
              ..sort((a, b) {
                final aTs = a.createdAt?.seconds ?? 0;
                final bTs = b.createdAt?.seconds ?? 0;
                final byCreatedAt = bTs.compareTo(aTs);
                if (byCreatedAt != 0) return byCreatedAt;
                return a.id.compareTo(b.id);
              });

        return filtered.take(20).toList(growable: false);
      });
    });

/// After Dark home screen — moody, crimson-themed live feed.
class AfterDarkHomeScreen extends ConsumerWidget {
  const AfterDarkHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(_liveAdultRoomsProvider);

    return AppPageScaffold(
      safeArea: false,
      backgroundColor: EmberDark.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero banner ───────────────────────────────────────────────────
          SliverToBoxAdapter(child: _HeroBanner()),

          // ── Quick actions ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                20,
                context.pageHorizontalPadding,
                4,
              ),
              child: _QuickActions(),
            ),
          ),

          // ── Live Lounges section header ───────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox.shrink()),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                24,
                context.pageHorizontalPadding,
                10,
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, color: EmberDark.primary, size: 10),
                  SizedBox(width: 6),
                  Text(
                    'LIVE LOUNGES',
                    style: TextStyle(
                      color: EmberDark.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Live rooms grid ───────────────────────────────────────────────
          roomsAsync.when(
            loading: () => const _AfterDarkRoomGridSkeleton(),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load lounges.',
                    style: TextStyle(color: EmberDark.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            data: (rooms) {
              if (rooms.isEmpty) {
                return SliverToBoxAdapter(child: _EmptyLounge());
              }
              return SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final crossAxisCount = width >= 1100
                      ? 4
                      : width >= 760
                      ? 3
                      : 2;
                  return SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.pageHorizontalPadding,
                    ),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _AfterDarkReveal(
                          key: ValueKey(rooms[i].id),
                          delay: i * 45,
                          child: AfterDarkLiveRoomCard(
                            room: rooms[i],
                            onTap: () => context.go('/room/${rooms[i].id}'),
                          ),
                        ),
                        childCount: rooms.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: width >= 760 ? 0.92 : 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // ── Coming soon — subscriptions ───────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                0,
                context.pageHorizontalPadding,
                32,
              ),
              child: _ComingSoonCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterDarkRoomGridSkeleton extends StatelessWidget {
  const _AfterDarkRoomGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.pageHorizontalPadding),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final crossAxisCount = width >= 1100
              ? 4
              : width >= 760
              ? 3
              : 2;
          return SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => DecoratedBox(
                decoration: BoxDecoration(
                  color: EmberDark.surfaceHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: EmberDark.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 112,
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
                        width: 96,
                        decoration: BoxDecoration(
                          color: EmberDark.surfaceHighest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Container(
                        height: 10,
                        width: 72,
                        decoration: BoxDecoration(
                          color: EmberDark.surfaceHighest.withValues(
                            alpha: 0.32,
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
              childAspectRatio: width >= 760 ? 0.92 : 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
          );
        },
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _AfterDarkReveal(
      child: Container(
        height: 200,
        decoration: const BoxDecoration(gradient: EmberDark.velvetGradient),
        child: Stack(
          children: [
            // Glow overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 0.8,
                    colors: [
                      EmberDark.secondary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: EmberDark.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: EmberDark.secondary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '18+ VERIFIED ONLY',
                      style: GoogleFonts.raleway(
                        color: EmberDark.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Velvet lounges for chemistry, flirtation, and late-night energy.',
                    style: GoogleFonts.playfairDisplay(
                      color: EmberDark.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Curated for adults who want a moodier, more intimate side of MixVy.',
                    style: GoogleFonts.raleway(
                      color: EmberDark.onSurface.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.4,
                    ),
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

// ── Quick action chips ────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.nightlife_rounded, 'Lounges', '/after-dark/lounges'),
      (Icons.favorite_outline_rounded, 'Speed Date', '/speed-dating'),
      (Icons.person_add_alt_1_outlined, 'My Profile', '/after-dark/profile'),
      (
        Icons.add_circle_outline_rounded,
        'Go Live',
        '/after-dark/create-lounge',
      ),
    ];

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final (icon, label, route) = actions[i];
          return _AfterDarkReveal(
            delay: 90 + (i * 55),
            child: GestureDetector(
              onTap: () => context.go(route),
              child: Container(
                width: 80,
                decoration: BoxDecoration(
                  color: EmberDark.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: EmberDark.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: EmberDark.primary, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.raleway(
                        color: EmberDark.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty lounges ─────────────────────────────────────────────────────────────
class _EmptyLounge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: EmberDark.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: EmberDark.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.nightlife_outlined,
            color: EmberDark.onSurfaceVariant,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'The room is quiet right now',
            style: TextStyle(
              color: EmberDark.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the first lounge and set the mood for tonight.',
            style: GoogleFonts.raleway(color: EmberDark.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.go('/after-dark/create-lounge'),
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
        ],
      ),
    );
  }
}

// ── Coming soon subscriptions ─────────────────────────────────────────────────
class _ComingSoonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _AfterDarkReveal(
      delay: 180,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              EmberDark.primaryDim.withValues(alpha: 0.3),
              EmberDark.surfaceHigh,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: EmberDark.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: EmberDark.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: EmberDark.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Creator Subscriptions',
                    style: TextStyle(
                      color: EmberDark.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Private rooms, premium access, and closer connections are coming soon.',
                    style: TextStyle(
                      color: EmberDark.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: EmberDark.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: EmberDark.primary.withValues(alpha: 0.35),
                ),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  color: EmberDark.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AfterDarkReveal extends StatelessWidget {
  final Widget child;
  final int delay;

  const _AfterDarkReveal({super.key, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}
