import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';

class PaginatedFollowingFeedState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDoc;

  PaginatedFollowingFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastDoc,
  });

  PaginatedFollowingFeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? lastDoc,
  }) {
    return PaginatedFollowingFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
    );
  }
}

class PaginatedFollowingFeedController extends StateNotifier<PaginatedFollowingFeedState> {
  PaginatedFollowingFeedController(this._firestore, this._userId) : super(PaginatedFollowingFeedState());

  final FirebaseFirestore _firestore;
  final String _userId;
  static const int _pageSize = 15;
  List<String>? _followingIds;

  Future<void> loadPosts() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    try {
      if (_followingIds == null) {
        final followsSnap = await _firestore
            .collection('follows')
            .where('followerUserId', isEqualTo: _userId)
            .get();
        _followingIds = followsSnap.docs
            .map((doc) => doc.data()['followedUserId'] as String?)
            .whereType<String>()
            .toList();
      }

      if (_followingIds!.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      // Firestore 'whereIn' is limited to 30. For beta-ready stability,
      // we only fetch from the first 30 people you follow in the paginated view.
      // A more robust solution would require a Cloud Function to aggregate feeds.
      final batch = _followingIds!.take(30).toList();

      var query = _firestore
          .collection('posts')
          .where('authorId', whereIn: batch)
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
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    _followingIds = null;
    state = PaginatedFollowingFeedState();
    await loadPosts();
  }
}

final paginatedFollowingFeedProvider = StateNotifierProvider.autoDispose
    .family<PaginatedFollowingFeedController, PaginatedFollowingFeedState, String>((ref, userId) {
  return PaginatedFollowingFeedController(FirebaseFirestore.instance, userId);
});
