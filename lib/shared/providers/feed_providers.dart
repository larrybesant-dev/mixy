// lib/shared/providers/feed_providers.dart
//
// Feed providers for the social feed engine (Riverpod 3.0).
// • globalFeedProvider / trendingFeedProvider  — real-time StreamProviders
// • globalFeedNotifierProvider                 — paginated Notifier (cursor)
// • followingFeedNotifierProvider              — paginated Notifier (offset)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../../services/social/social_feed_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Provides a singleton instance of [SocialFeedService].
final socialFeedServiceProvider = Provider<SocialFeedService>((ref) {
  return SocialFeedService();
});

// ─────────────────────────────────────────────────────────────────────────────
// STREAM PROVIDERS  (real-time, first-page only)
// ─────────────────────────────────────────────────────────────────────────────

/// Real-time stream of the 50 most-recent public posts.
final globalFeedProvider = StreamProvider<List<Post>>(
  (ref) => ref.watch(socialFeedServiceProvider).getGlobalFeedStream(limit: 50),
);

/// Real-time stream of the top 20 trending posts (by likeCount).
final trendingFeedProvider = StreamProvider<List<Post>>(
  (ref) =>
      ref.watch(socialFeedServiceProvider).getTrendingFeedStream(limit: 20),
);

// ─────────────────────────────────────────────────────────────────────────────
// PAGINATION STATE MODEL
// ─────────────────────────────────────────────────────────────────────────────

class FeedPageState {
  const FeedPageState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  FeedPageState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      FeedPageState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL FEED PAGINATION  (cursor-based, DocumentSnapshot)
// ─────────────────────────────────────────────────────────────────────────────

class GlobalFeedNotifier extends Notifier<FeedPageState> {
  DocumentSnapshot? _cursor;
  static const int _pageSize = 20;

  @override
  FeedPageState build() {
    Future.microtask(_loadInitial);
    return const FeedPageState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    state = const FeedPageState(isLoading: true, hasMore: true);
    _cursor = null;
    final (posts, cursor) = await ref
        .read(socialFeedServiceProvider)
        .getGlobalFeedPage(limit: _pageSize);
    _cursor = cursor;
    state = state.copyWith(
      posts: posts,
      isLoading: false,
      hasMore: cursor != null,
    );
  }

  /// Reload from the first page.
  Future<void> refresh() => _loadInitial();

  /// Append the next page. No-op when already loading or exhausted.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _cursor == null) return;
    state = state.copyWith(isLoadingMore: true);
    final (newPosts, cursor) = await ref
        .read(socialFeedServiceProvider)
        .getGlobalFeedPage(cursor: _cursor, limit: _pageSize);
    _cursor = cursor;
    state = state.copyWith(
      posts: [...state.posts, ...newPosts],
      isLoadingMore: false,
      hasMore: cursor != null,
    );
  }
}

/// Paginated ""For You"" (global public) feed.  Supports [loadMore] and [refresh].
final globalFeedNotifierProvider =
    NotifierProvider<GlobalFeedNotifier, FeedPageState>(
  () => GlobalFeedNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOWING FEED PAGINATION  (offset-based, handles multi-query batching)
// ─────────────────────────────────────────────────────────────────────────────

class FollowingFeedNotifier extends Notifier<FeedPageState> {
  int _offset = 0;
  static const int _pageSize = 20;

  String? get _userId => fb.FirebaseAuth.instance.currentUser?.uid;

  @override
  FeedPageState build() {
    Future.microtask(_loadInitial);
    return const FeedPageState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    final userId = _userId;
    if (userId == null) {
      state = const FeedPageState();
      return;
    }
    state = const FeedPageState(isLoading: true, hasMore: true);
    _offset = 0;
    final (posts, nextOffset) = await ref
        .read(socialFeedServiceProvider)
        .getFollowingFeedPage(userId: userId, offset: 0, limit: _pageSize);
    _offset = nextOffset ?? 0;
    state = state.copyWith(
      posts: posts,
      isLoading: false,
      hasMore: nextOffset != null,
    );
  }

  /// Reload from the first page.
  Future<void> refresh() => _loadInitial();

  /// Append the next page. No-op when already loading or exhausted.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isLoadingMore: true);
    final (newPosts, nextOffset) = await ref
        .read(socialFeedServiceProvider)
        .getFollowingFeedPage(
          userId: userId,
          offset: _offset,
          limit: _pageSize,
        );
    _offset = nextOffset ?? _offset;
    state = state.copyWith(
      posts: [...state.posts, ...newPosts],
      isLoadingMore: false,
      hasMore: nextOffset != null,
    );
  }
}

/// Paginated following feed. Reads current userId from FirebaseAuth.
/// Supports [loadMore] and [refresh].
final followingFeedNotifierProvider =
    NotifierProvider<FollowingFeedNotifier, FeedPageState>(
  () => FollowingFeedNotifier(),
);
