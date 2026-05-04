import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../feed/models/post_model.dart';
import '../../feed/providers/feed_providers.dart';

class PostCommentEntry {
  const PostCommentEntry({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String text;
  final DateTime createdAt;

  factory PostCommentEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PostCommentEntry(
      id: doc.id,
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? 'User',
      authorAvatarUrl: d['authorAvatarUrl'] as String?,
      text: d['text'] as String? ?? '',
      createdAt: _parseTs(d['createdAt']),
    );
  }

  static DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

final postCommentsFirestoreProvider = firestoreProvider;

final postDocProvider = Provider.autoDispose
    .family<AsyncValue<PostModel?>, String>((ref, postId) {
      return ref.watch(postsFeedProvider).whenData((posts) {
        for (final post in posts) {
          if (post.id == postId) {
            return post;
          }
        }
        return null;
      });
    });

final postCommentsProvider = StreamProvider.autoDispose
    .family<List<PostCommentEntry>, String>((ref, postId) {
      final firestore = ref.watch(postCommentsFirestoreProvider);
      return firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt')
          .limit(100)
          .snapshots()
          .map(
            (s) => s.docs.map(PostCommentEntry.fromDoc).toList(growable: false),
          );
    });
