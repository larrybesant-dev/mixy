// Riverpod provider for Feed
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'post.dart';

// Feed state notifier
class FeedNotifier extends Notifier<List<Post>> {
  @override
  List<Post> build() => [];

  void addPost(Post post) {
    state = [...state, post];
  }

  void removePost(String postId) {
    state = state.where((p) => p.id != postId).toList();
  }

  void setPosts(List<Post> posts) {
    state = posts;
  }

  void clear() {
    state = [];
  }
}

final feedProvider = NotifierProvider<FeedNotifier, List<Post>>(
  () => FeedNotifier(),
);
