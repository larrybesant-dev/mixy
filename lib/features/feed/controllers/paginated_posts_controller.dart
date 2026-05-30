import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/feature_gate_service.dart';
import '../../../core/providers/firebase_providers.dart';
import '../models/post_model.dart';

class PaginatedPostsState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;
  final DateTime? lastFetchAt;

  PaginatedPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastDoc,
    this.lastFetchAt,
  });

  PaginatedPostsState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
    DateTime? lastFetchAt,
  }) {
    return PaginatedPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
      lastFetchAt: lastFetchAt ?? this.lastFetchAt,
    );
  }
}

class PaginatedPostsController extends StateNotifier<PaginatedPostsState> {
  PaginatedPostsController(this._firestore, this._ref)
    : super(PaginatedPostsState());

  final FirebaseFirestore _firestore;
  final Ref _ref;
  static const int _pageSize = 15;

  Future<void> loadPosts() async {
    if (state.isLoading || !state.hasMore) return;

    final gates = _ref.read(featureGateControllerProvider);
    final now = DateTime.now();

    // Throttle refresh rate based on Feature Gate
    if (state.lastFetchAt != null) {
      final diff = now.difference(state.lastFetchAt!);
      if (diff.inSeconds < gates.feedRefreshRateSeconds) {
        return; // Throttled
      }
    }

    state = state.copyWith(isLoading: true);

    try {
      var query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (state.lastDoc != null) {
        query = query.startAfterDocument(state.lastDoc!);
      }

      final snapshot = await query.get();
      final newPosts = snapshot.docs
          .map((doc) => PostModel.fromDoc(doc.id, doc.data()))
          .toList();

      state = state.copyWith(
        posts: [...state.posts, ...newPosts],
        isLoading: false,
        hasMore: snapshot.docs.length == _pageSize,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : state.lastDoc,
        lastFetchAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = PaginatedPostsState();
    await loadPosts();
  }
}

final paginatedPostsProvider =
    StateNotifierProvider.autoDispose<
      PaginatedPostsController,
      PaginatedPostsState
    >((ref) {
      return PaginatedPostsController(ref.read(firestoreProvider), ref);
    });




