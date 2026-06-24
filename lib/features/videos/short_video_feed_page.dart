import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/design_system/design_constants.dart';
import '../../services/social/short_video_service.dart';
import '../../core/routing/app_routes.dart';
import 'short_video_card_widget.dart';

// ── Providers ────────────────────────────────────────────────────────────────

/// Holds the paginated list of fetched videos + cursor for next page.
class _VideoFeedState {
  final List<ShortVideo> videos;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? cursor;

  const _VideoFeedState({
    this.videos = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.cursor,
  });

  _VideoFeedState copyWith({
    List<ShortVideo>? videos,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? cursor,
  }) =>
      _VideoFeedState(
        videos: videos ?? this.videos,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        cursor: cursor ?? this.cursor,
      );
}

class _VideoFeedNotifier extends Notifier<_VideoFeedState> {
  @override
  _VideoFeedState build() {
    Future.microtask(loadMore);
    return const _VideoFeedState();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    final newVideos = await ShortVideoService.instance.getVideoFeed(
      lastDoc: state.cursor,
      limit: 10,
    );

    state = state.copyWith(
      videos: [...state.videos, ...newVideos],
      isLoading: false,
      hasMore: newVideos.length == 10,
    );
  }

  Future<void> refresh() async {
    state = const _VideoFeedState();
    await loadMore();
  }

  Future<void> toggleLike(String videoId) async {
    final nowLiked = await ShortVideoService.instance.toggleLike(videoId);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    state = state.copyWith(
      videos: state.videos.map((v) {
        if (v.id != videoId) return v;
        final newLikedBy = List<String>.from(v.likedBy);
        if (nowLiked) {
          newLikedBy.add(uid);
        } else {
          newLikedBy.remove(uid);
        }
        return ShortVideo(
          id: v.id,
          userId: v.userId,
          userName: v.userName,
          userAvatar: v.userAvatar,
          videoUrl: v.videoUrl,
          thumbnailUrl: v.thumbnailUrl,
          caption: v.caption,
          tags: v.tags,
          likeCount: nowLiked ? v.likeCount + 1 : v.likeCount - 1,
          commentCount: v.commentCount,
          shareCount: v.shareCount,
          likedBy: newLikedBy,
          createdAt: v.createdAt,
          isVisible: v.isVisible,
        );
      }).toList(),
    );
  }
}

final videoFeedProvider = NotifierProvider<_VideoFeedNotifier, _VideoFeedState>(_VideoFeedNotifier.new);

// ── Page ─────────────────────────────────────────────────────────────────────

/// Vertical-swipe short-video feed (TikTok / Reels pattern).
/// Each card occupies the full viewport. Preloading happens frame-by-frame.
class ShortVideoFeedPage extends ConsumerStatefulWidget {
  const ShortVideoFeedPage({super.key});

  @override
  ConsumerState<ShortVideoFeedPage> createState() => _ShortVideoFeedPageState();
}

class _ShortVideoFeedPageState extends ConsumerState<ShortVideoFeedPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    final state = ref.read(videoFeedProvider);
    // Pre-load next page when near the end
    if (page >= state.videos.length - 3 && state.hasMore && !state.isLoading) {
      ref.read(videoFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(videoFeedProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (feedState.videos.isEmpty && feedState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: DesignColors.accent),
      );
    }

    if (feedState.videos.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: feedState.videos.length + (feedState.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= feedState.videos.length) {
              return const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: DesignColors.accent),
              );
            }
            final video = feedState.videos[index];
            return ShortVideoCardWidget(
              video: video,
              isActive: index == _currentPage,
              isLiked: video.isLikedBy(uid),
              onLike: () =>
                  ref.read(videoFeedProvider.notifier).toggleLike(video.id),
              onProfile: () =>
                  Navigator.pushNamed(context, AppRoutes.userProfile,
                      arguments: video.userId),
              onShare: () => ShortVideoService.instance.recordShare(video.id),
            );
          },
        ),
        // Upload button
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.createShortVideo),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DesignColors.background.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline,
              size: 72, color: DesignColors.textGray.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No Reels yet',
              style: TextStyle(
                  color: DesignColors.textGray,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Be the first to post a short video',
              style: TextStyle(
                  color: DesignColors.textGray.withValues(alpha: 0.6),
                  fontSize: 13)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.createShortVideo),
            icon: const Icon(Icons.add, color: DesignColors.accent),
            label: const Text('Create Reel',
                style: TextStyle(color: DesignColors.accent)),
          ),
        ],
      ),
    );
  }
}
