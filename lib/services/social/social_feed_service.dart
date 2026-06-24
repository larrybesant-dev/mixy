import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/post.dart';

/// Social Feed Service
/// Manages posts, likes, comments, and feed pagination
class SocialFeedService {
  static SocialFeedService? _instance;
  static SocialFeedService get instance => _instance ??= SocialFeedService._();

  SocialFeedService._();
  factory SocialFeedService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _postsCollection =>
      _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ============================================================
  // POST CRUD
  // ============================================================

  /// Create a new post
  Future<String?> createPost({
    required String userId,
    required String content,
    String? imageUrl,
    String? roomId,
    PostType type = PostType.text,
  }) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      final userData = userDoc.data() ?? {};

      final postRef = await _postsCollection.add({
        'userId': userId,
        'userName': userData['displayName'] ?? 'User',
        'userAvatar': userData['avatarUrl'] ?? userData['photoUrl'] ?? '',
        'content': content,
        'imageUrl': imageUrl,
        'roomId': roomId,
        'type': type.name,
        'likes': [],
        'likeCount': 0,
        'commentCount': 0,
        'tipCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isVisible': true,
      });

      debugPrint('âœ… [SocialFeed] Post created: ${postRef.id}');
      return postRef.id;
    } catch (e) {
      debugPrint('âŒ [SocialFeed] Error creating post: $e');
      return null;
    }
  }

  /// Get paginated feed for a user (posts from friends + own posts)
  Future<List<Post>> getFeed({
    required String userId,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    try {
      // Get user's friends list
      final userDoc = await _usersCollection.doc(userId).get();
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);

      // Include own posts
      final allUserIds = [userId, ...friendIds];

      // Firestore 'whereIn' limited to 30, batch if needed
      final batches = <List<String>>[];
      for (var i = 0; i < allUserIds.length; i += 30) {
        batches.add(
          allUserIds.sublist(
            i,
            i + 30 > allUserIds.length ? allUserIds.length : i + 30,
          ),
        );
      }

      final posts = <Post>[];
      for (final batch in batches) {
        Query<Map<String, dynamic>> query = _postsCollection
            .where('userId', whereIn: batch)
            .where('isVisible', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(limit);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get();
        posts.addAll(snapshot.docs.map((doc) => Post.fromFirestore(doc)));
      }

      // Sort all posts by date
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts.take(limit).toList();
    } catch (e) {
      debugPrint('âŒ [SocialFeed] Error getting feed: $e');
      return [];
    }
  }

  /// Get global/discover feed (all public posts)
  Stream<List<Post>> getGlobalFeedStream({int limit = 50}) {
    return _postsCollection
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

  /// Friends feed — posts from users the current user follows.
  /// Returns a live stream. Falls back to global if friend list is empty.
  Stream<List<Post>> getFriendsFeedStream(String userId,
      {int limit = 50}) async* {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      final raw = userDoc.data();
      final friendIds = <String>[
        userId,
        ...List<String>.from(raw?['friends'] ?? raw?['following'] ?? []),
      ];

      if (friendIds.length == 1) {
        // No friends yet — show own posts only
        yield* _postsCollection
            .where('userId', isEqualTo: userId)
            .where('isVisible', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .snapshots()
            .map((s) => s.docs.map((d) => Post.fromFirestore(d)).toList());
        return;
      }

      // Firestore whereIn max 30; take first batch
      final batch = friendIds.take(30).toList();
      yield* _postsCollection
          .where('userId', whereIn: batch)
          .where('isVisible', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map((d) => Post.fromFirestore(d)).toList());
    } catch (e) {
      debugPrint('❌ [SocialFeed] Friends feed error: $e');
      yield [];
    }
  }

  /// Room Highlights feed — posts that are room share / room highlights.
  Stream<List<Post>> getRoomHighlightsFeedStream({int limit = 50}) {
    return _postsCollection
        .where('isVisible', isEqualTo: true)
        .where('type', isEqualTo: 'roomShare')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

  /// Get posts for a specific user
  Stream<List<Post>> getUserPostsStream(String userId, {int limit = 20}) {
    return _postsCollection
        .where('userId', isEqualTo: userId)
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

  // ============================================================
  // INTERACTIONS
  // ============================================================

  /// Like/unlike a post
  Future<bool> toggleLike(String postId, String userId) async {
    try {
      final postRef = _postsCollection.doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) return false;

      final likes = List<String>.from(postDoc.data()?['likes'] ?? []);
      final isLiked = likes.contains(userId);

      if (isLiked) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }

      await postRef.update({
        'likes': likes,
        'likeCount': likes.length,
      });

      debugPrint('âœ… [SocialFeed] Post ${isLiked ? 'unliked' : 'liked'}');
      return !isLiked;
    } catch (e) {
      debugPrint('âŒ [SocialFeed] Error toggling like: $e');
      return false;
    }
  }

  /// Add a comment to a post
  Future<String?> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      final userData = userDoc.data() ?? {};

      final commentRef =
          await _postsCollection.doc(postId).collection('comments').add({
        'userId': userId,
        'userName': userData['displayName'] ?? 'User',
        'userAvatar': userData['avatarUrl'] ?? userData['photoUrl'] ?? '',
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update comment count
      await _postsCollection.doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      debugPrint('âœ… [SocialFeed] Comment added');
      return commentRef.id;
    } catch (e) {
      debugPrint('âŒ [SocialFeed] Error adding comment: $e');
      return null;
    }
  }

  /// Get comments for a post
  Stream<List<Comment>> getCommentsStream(String postId) {
    return _postsCollection
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList());
  }

  /// Tip a post author
  Future<bool> tipPost({
    required String postId,
    required String fromUserId,
    required int coinAmount,
  }) async {
    try {
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) return false;

      final toUserId = postDoc.data()?['userId'] as String;

      // Deduct from sender
      await _usersCollection.doc(fromUserId).update({
        'coinBalance': FieldValue.increment(-coinAmount),
      });

      // Add to receiver
      await _usersCollection.doc(toUserId).update({
        'coinBalance': FieldValue.increment(coinAmount),
      });

      // Record tip on post
      await _postsCollection.doc(postId).update({
        'tipCount': FieldValue.increment(coinAmount),
      });

      // Record transaction
      await _firestore.collection('transactions').add({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': coinAmount,
        'type': 'post_tip',
        'postId': postId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('âœ… [SocialFeed] Post tipped $coinAmount coins');
      return true;
    } catch (e) {
      debugPrint('âŒ [SocialFeed] Error tipping post: $e');
      return false;
    }
  }

  /// Delete a post
  Future<bool> deletePost(String postId, String userId) async {
    try {
      final postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) return false;

      // Only author can delete
      if (postDoc.data()?['userId'] != userId) return false;

      await _postsCollection.doc(postId).update({
        'isVisible': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('âœ… [SocialFeed] Post deleted');
      return true;
    } catch (e) {
      debugPrint('âŒ [SocialFeed] Error deleting post: $e');
      return false;
    }
  }
  // ============================================================
  // TRENDING & DISCOVERY FEEDS (NEW)
  // ============================================================

  /// Stream of trending posts (sorted by like count)
  Stream<List<Post>> getTrendingFeedStream({int limit = 20}) {
    return _postsCollection
        .where('isVisible', isEqualTo: true)
        .orderBy('likeCount', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromFirestore(doc
                  as DocumentSnapshot<Map<String, dynamic>>))
              .toList();
        })
        .handleError((e) {
          debugPrint('❌ [SocialFeed] Error streaming trending feed: $e');
          return <Post>[];
        });
  }

  /// Get paginated global feed (all posts from all users) — returns (posts, nextCursor)
  Future<(List<Post>, DocumentSnapshot?)> getGlobalFeedPage({
    DocumentSnapshot? cursor,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _postsCollection
          .where('isVisible', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit + 1); // Get one extra to check if there's a next page

      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      // Check if there are more pages
      final hasMore = docs.length > limit;
      final posts = docs
          .take(limit)
          .map((doc) => Post.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      final nextCursor = hasMore ? docs[limit] : null;

      return (posts, nextCursor);
    } catch (e) {
      debugPrint('❌ [SocialFeed] Error getting global feed: $e');
      return (<Post>[], null) as (List<Post>, DocumentSnapshot?);
    }
  }

  /// Get paginated feed from users that the current user follows — returns (posts, nextOffset)
  Future<(List<Post>, int?)> getFollowingFeedPage({
    required String userId,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      final followingIds = List<String>.from(userDoc.data()?['following'] ?? []);

      if (followingIds.isEmpty) {
        return (<Post>[], null) as (List<Post>, int?);
      }

      // Batch by 30 (Firestore whereIn limit)
      final batches = <List<String>>[];
      for (var i = 0; i < followingIds.length; i += 30) {
        batches.add(
          followingIds.sublist(
            i,
            i + 30 > followingIds.length ? followingIds.length : i + 30,
          ),
        );
      }

      final allPosts = <Post>[];
      for (final batch in batches) {
        final Query<Map<String, dynamic>> query = _postsCollection
            .where('userId', whereIn: batch)
            .where('isVisible', isEqualTo: true)
            .orderBy('createdAt', descending: true);

        final snapshot = await query.get();
        allPosts.addAll(snapshot.docs
            .map((doc) => Post.fromFirestore(
                doc as DocumentSnapshot<Map<String, dynamic>>)));
      }

      // Sort combined results by createdAt
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply offset and limit
      final startIndex = offset;
      final endIndex = (offset + limit + 1).clamp(0, allPosts.length);
      final hasMore = endIndex < allPosts.length;
      final posts = allPosts.sublist(
        startIndex,
        hasMore ? (offset + limit) : endIndex,
      );

      final nextOffset = hasMore ? offset + limit : null;

      return (posts, nextOffset);
    } catch (e) {
      debugPrint('❌ [SocialFeed] Error getting following feed: $e');
      return (<Post>[], null) as (List<Post>, int?);
    }
  }
}
