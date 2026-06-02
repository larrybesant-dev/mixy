import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/layout/app_layout.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/core/telemetry/feed_experiment_contract.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/social/providers/social_providers.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';

class HomeLobbyScreen extends ConsumerStatefulWidget {
  const HomeLobbyScreen({super.key});

  @override
  ConsumerState<HomeLobbyScreen> createState() => _HomeLobbyScreenState();
}

class _HomeLobbyScreenState extends ConsumerState<HomeLobbyScreen> {
  Timer? _featuredDwellTimer;
  DateTime? _featuredVisibleAt;
  String? _featuredRoomId;
  final Set<int> _scrollMilestonesLogged = <int>{};

  int _stablePeopleCount(RoomModel room) {
    final derivedCount = room.stageUserIds.length + room.audienceUserIds.length;
    return room.memberCount > 0
        ? math.max(room.memberCount, derivedCount)
        : derivedCount;
  }

  int _activityScore(RoomModel room) {
    final total = _stablePeopleCount(room);
    final speakers = room.stageUserIds.length;
    final created = room.createdAt?.toDate() ?? DateTime.now();
    final minutesAgo = DateTime.now().difference(created).inMinutes;
    final recencyBoost = (120 - minutesAgo).clamp(0, 120) ~/ 10;
    final audienceBand = total >= 20
        ? 20
        : total >= 10
        ? 14
        : total >= 5
        ? 8
        : total >= 2
        ? 4
        : total;
    return audienceBand + (speakers * 3) + recencyBoost;
  }

  List<RoomModel> _trending(List<RoomModel> rooms) {
    final sorted = List<RoomModel>.from(rooms)
      ..sort((a, b) {
        final scoreA = _activityScore(a);
        final scoreB = _activityScore(b);
        final scoreDelta = scoreB - scoreA;
        if (scoreDelta.abs() > 2) {
          return scoreDelta;
        }

        final ta =
            a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb =
            b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final recencyCompare = tb.compareTo(ta);
        if (recencyCompare != 0) {
          return recencyCompare;
        }
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  List<RoomModel> _newest(List<RoomModel> rooms) {
    final sorted = List<RoomModel>.from(rooms)
      ..sort((a, b) {
        final ta =
            a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb =
            b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    return sorted;
  }

  @override
  void dispose() {
    _featuredDwellTimer?.cancel();
    super.dispose();
  }

  void _trackFeaturedRoom(RoomModel? room, {required String section}) {
    if (room == null || _featuredRoomId == room.id) {
      return;
    }

    _featuredDwellTimer?.cancel();
    _featuredRoomId = room.id;
    _featuredVisibleAt = DateTime.now();

    AppTelemetry.logAction(
      domain: 'room',
      action: 'feed_featured_impression',
      message: 'Featured room surfaced in the home feed.',
      roomId: room.id,
      result: 'visible',
      metadata: <String, Object?>{
        ...FeedAttentionExperiment.telemetryMetadata(),
        'section': section,
        'category': room.category ?? 'unknown',
        'members': _stablePeopleCount(room),
        'speakers': room.stageUserIds.length,
      },
    );

    _featuredDwellTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted ||
          _featuredRoomId != room.id ||
          _featuredVisibleAt == null) {
        return;
      }

      AppTelemetry.logAction(
        domain: 'room',
        action: 'feed_featured_dwell',
        message: 'Featured room held attention in the home feed.',
        roomId: room.id,
        result: 'engaged',
        metadata: <String, Object?>{
          ...FeedAttentionExperiment.telemetryMetadata(),
          'section': section,
          'category': room.category ?? 'unknown',
          'dwell_ms': DateTime.now()
              .difference(_featuredVisibleAt!)
              .inMilliseconds,
        },
      );
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final maxScrollExtent = notification.metrics.maxScrollExtent;
    if (maxScrollExtent <= 0) {
      return false;
    }

    final depthPercent =
        (notification.metrics.pixels / maxScrollExtent).clamp(0.0, 1.0) * 100;
    for (final milestone in const <int>[25, 50, 75]) {
      if (depthPercent >= milestone && _scrollMilestonesLogged.add(milestone)) {
        AppTelemetry.logAction(
          domain: 'room',
          action: 'feed_scroll_depth',
          message: 'User reached a home feed depth milestone.',
          result: 'scroll',
          metadata: <String, Object?>{
            ...FeedAttentionExperiment.telemetryMetadata(),
            'percent': milestone,
          },
        );
      }
    }
    return false;
  }

  void _openRoom(
    BuildContext context,
    RoomModel room, {
    required String section,
    required int rank,
    required bool featured,
  }) {
    final dwellMs = _featuredRoomId == room.id && _featuredVisibleAt != null
        ? DateTime.now().difference(_featuredVisibleAt!).inMilliseconds
        : null;

    AppTelemetry.logAction(
      domain: 'room',
      action: 'feed_room_open',
      message: 'User opened a room from the home feed.',
      roomId: room.id,
      result: featured ? 'featured' : 'standard',
      metadata: <String, Object?>{
        ...FeedAttentionExperiment.telemetryMetadata(),
        'section': section,
        'rank': rank,
        'featured': featured,
        'category': room.category ?? 'unknown',
        'members': _stablePeopleCount(room),
        'speakers': room.stageUserIds.length,
        'dwell_ms': if (dwellMs != null) dwellMs,
      },
    );

    context.go('/room/${room.id}');
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hp = context.pageHorizontalPadding;

    final roomsAsync = ref.watch(roomsStreamProvider);
    final followingLiveAsync = ref.watch(followingLiveRoomsProvider(uid));
    final forYouAsync = ref.watch(forYouRoomsProvider(uid));

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      safeArea: false,
      body: RefreshIndicator(
        color: VelvetNoir.primary,
        onRefresh: () async {
          ref.invalidate(roomsStreamProvider);
          ref.invalidate(followingLiveRoomsProvider(uid));
          ref.invalidate(forYouRoomsProvider(uid));
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                backgroundColor: VelvetNoir.surface,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Home',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: VelvetNoir.onSurface,
                      ),
                    ),
                    Text(
                      'Live voices, fresh rooms, your circle',
                      style: GoogleFonts.raleway(
                        fontSize: 11,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.search_rounded,
                      color: VelvetNoir.onSurfaceVariant,
                    ),
                    onPressed: () => context.go('/search'),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: VelvetNoir.onSurfaceVariant,
                    ),
                    onPressed: () => context.go('/notifications'),
                  ),
                ],
              ),

              // Main sections composed from shared room stream
              roomsAsync.when(
                loading: () => const SliverToBoxAdapter(child: _HomeShimmer()),
                error: (__, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(hp),
                    child: Center(
                      child: Text(
                        'Unable to load the social feed right now.',
                        style: GoogleFonts.raleway(
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                data: (rooms) {
                  final liveNow = rooms.take(10).toList();
                  final trending = _trending(rooms).take(6).toList();
                  final newest = _newest(rooms).take(6).toList();
                  final featuredRoom = trending.isNotEmpty
                      ? trending.first
                      : (liveNow.isNotEmpty ? liveNow.first : null);
                  final featuredRoomId = featuredRoom?.id;
                  final featuredSection = trending.isNotEmpty
                      ? 'trending'
                      : 'live_now';

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    _trackFeaturedRoom(featuredRoom, section: featuredSection);
                  });

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // A. Live Now
                      _SectionHeader(
                        padding: EdgeInsets.fromLTRB(hp, 14, hp, 10),
                        title: 'Live Now',
                        subtitle: 'Jump into the room that fits your mood',
                      ),
                      if (liveNow.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: hp),
                          child: const _EmptyRoomsCard(
                            title: 'No rooms are live yet',
                            subtitle: 'Check back soon or start one yourself.',
                          ),
                        )
                      else
                        SizedBox(
                          height: 200,
                          child: ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: hp),
                            scrollDirection: Axis.horizontal,
                            itemCount: liveNow.length,
                            separatorBuilder: (__, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (ctx, i) => SocialRoomCardCompact(
                              key: ValueKey(liveNow[i].id),
                              featured: liveNow[i].id == featuredRoomId,
                              room: liveNow[i],
                              onTap: () => _openRoom(
                                ctx,
                                liveNow[i],
                                section: 'live_now',
                                rank: i + 1,
                                featured: liveNow[i].id == featuredRoomId,
                              ),
                            ),
                          ),
                        ),

                      // B. Following Live
                      _SectionHeader(
                        padding: EdgeInsets.fromLTRB(hp, 22, hp, 10),
                        title: 'Following Live',
                        subtitle: 'People you already care about',
                      ),
                      followingLiveAsync.when(
                        loading: () => const _MiniLoadingStrip(),
                        error: (__, _) => const SizedBox.shrink(),
                        data: (followRooms) {
                          if (followRooms.isEmpty) {
                            final suggestions = rooms.take(3).toList();
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: hp),
                              child: Column(
                                children: [
                                  const _EmptyRoomsCard(
                                    title: 'Nobody you follow is live yet',
                                    subtitle:
                                        'Here are a few rooms worth checking out.',
                                  ),
                                  const SizedBox(height: 10),
                                  ...suggestions.map(
                                    (room) => SocialRoomCard(
                                      key: ValueKey(room.id),
                                      featured: room.id == featuredRoomId,
                                      room: room,
                                      onTap: () => _openRoom(
                                        context,
                                        room,
                                        section: 'following_suggestions',
                                        rank: suggestions.indexOf(room) + 1,
                                        featured: room.id == featuredRoomId,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: followRooms
                                .map(
                                  (room) => SocialRoomCard(
                                    key: ValueKey(room.id),
                                    featured: room.id == featuredRoomId,
                                    room: room,
                                    onTap: () => _openRoom(
                                      context,
                                      room,
                                      section: 'following_live',
                                      rank: followRooms.indexOf(room) + 1,
                                      featured: room.id == featuredRoomId,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),

                      // C. Trending Rooms
                      _SectionHeader(
                        padding: EdgeInsets.fromLTRB(hp, 22, hp, 10),
                        title: 'Trending Rooms',
                        subtitle: 'Ranked by activity, speakers, and recency',
                      ),
                      ...trending.map(
                        (room) => _RankedRoomCard(
                          room: room,
                          score: _activityScore(room),
                          onTap: () => _openRoom(
                            context,
                            room,
                            section: 'trending',
                            rank: trending.indexOf(room) + 1,
                            featured: room.id == featuredRoomId,
                          ),
                        ),
                      ),

                      // D. New Rooms
                      _SectionHeader(
                        padding: EdgeInsets.fromLTRB(hp, 22, hp, 10),
                        title: 'New Rooms',
                        subtitle: 'Fresh spaces that just opened',
                      ),
                      ...newest.map(
                        (room) => SocialRoomCard(
                          key: ValueKey('${room.id}-new'),
                          featured: room.id == featuredRoomId,
                          room: room,
                          onTap: () => _openRoom(
                            context,
                            room,
                            section: 'new_rooms',
                            rank: newest.indexOf(room) + 1,
                            featured: room.id == featuredRoomId,
                          ),
                        ),
                      ),

                      // E. For You
                      _SectionHeader(
                        padding: EdgeInsets.fromLTRB(hp, 22, hp, 10),
                        title: 'For You',
                        subtitle:
                            'Picked from your interests and social activity',
                      ),
                      forYouAsync.when(
                        loading: () => const _MiniLoadingStrip(),
                        error: (__, _) => const SizedBox.shrink(),
                        data: (suggestions) {
                          if (suggestions.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: hp),
                              child: const _EmptyRoomsCard(
                                title: 'Your recommendations are warming up',
                                subtitle:
                                    'Join a few rooms and follow hosts to personalize this feed.',
                              ),
                            );
                          }
                          return Column(
                            children: suggestions
                                .take(5)
                                .map(
                                  (room) => SocialRoomCard(
                                    key: ValueKey('${room.id}-foryou'),
                                    featured: room.id == featuredRoomId,
                                    room: room,
                                    onTap: () => _openRoom(
                                      context,
                                      room,
                                      section: 'for_you',
                                      rank: suggestions.indexOf(room) + 1,
                                      featured: room.id == featuredRoomId,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 100),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.padding,
    required this.title,
    required this.subtitle,
  });

  final EdgeInsets padding;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: VelvetNoir.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankedRoomCard extends StatelessWidget {
  const _RankedRoomCard({
    required this.room,
    required this.score,
    required this.onTap,
  });

  final RoomModel room;
  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SocialRoomCard(room: room, onTap: onTap),
        Positioned(
          top: 12,
          right: 22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VelvetNoir.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: VelvetNoir.secondaryBright.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Score $score',
              style: GoogleFonts.raleway(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.secondaryBright,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyRoomsCard extends StatelessWidget {
  const _EmptyRoomsCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Text('✨', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.raleway(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: VelvetNoir.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLoadingStrip extends StatelessWidget {
  const _MiniLoadingStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
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

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(
              3,
              (i) => Container(
                width: 160,
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const MiniLoadingStripWrapper(),
      ],
    );
  }
}

class MiniLoadingStripWrapper extends StatelessWidget {
  const MiniLoadingStripWrapper({super.key});

  @override
  Widget build(BuildContext context) => const _MiniLoadingStrip();
}



