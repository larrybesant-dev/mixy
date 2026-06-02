import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

String? _asNullableString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map(
          (item) =>
              item is String ? item.trim() : item?.toString().trim() ?? '',
        )
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

class TrendingPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final List<String> hashtags;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  TrendingPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    required this.hashtags,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
  });

  factory TrendingPost.fromJson(Map<String, dynamic> json, String id) {
    return TrendingPost(
      id: id,
      authorId: _asString(json['authorId']),
      authorName: _asString(json['authorName']),
      authorAvatarUrl: _asNullableString(json['authorAvatarUrl']),
      content: _asString(json['content']),
      hashtags: _asStringList(json['hashtags']),
      createdAt: _parseDateTime(json['createdAt']),
      likeCount: _asInt(json['likeCount']),
      commentCount: _asInt(json['commentCount']),
    );
  }
}

// Get trending hashtags
final trendingHashtagsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>((ref, date) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('hashtags')
      .orderBy('postCount', descending: true)
      .limit(20)
      .get()
      .then((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'hashtag': doc.id,
        'postCount': _asInt(data['postCount']),
        'trendScore': _asDouble(data['trendScore']),
      };
    }).toList();
  });
});

// Get posts with specific hashtag
final hashtagPostsProvider = Provider.autoDispose
    .family<AsyncValue<List<TrendingPost>>, String>((ref, hashtag) {
  final needle = '#${hashtag.trim().toLowerCase()}';
  return ref.watch(postsFeedProvider).whenData((posts) {
    final mapped = posts
        .where((post) => post.text.toLowerCase().contains(needle))
        .map(
          (post) => TrendingPost(
            id: post.id,
            authorId: post.userId,
            authorName: post.authorName ?? 'User',
            authorAvatarUrl: post.authorAvatarUrl,
            content: post.text,
            hashtags: const <String>[],
            createdAt: post.createdAt,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
          ),
        )
        .toList(growable: false)
      ..sort(
        (left, right) => right.likeCount.compareTo(left.likeCount),
      );

    if (mapped.length <= 30) {
      return mapped;
    }
    return mapped.sublist(0, 30);
  });
});

// Get trending posts (top posts by engagement in last 7 days)
final trendingPostsProvider =
    Provider.autoDispose<AsyncValue<List<TrendingPost>>>((ref) {
  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

  return ref.watch(postsFeedProvider).whenData((posts) {
    final mapped = posts
        .where((post) => post.createdAt.isAfter(sevenDaysAgo))
        .map(
          (post) => TrendingPost(
            id: post.id,
            authorId: post.userId,
            authorName: post.authorName ?? 'User',
            authorAvatarUrl: post.authorAvatarUrl,
            content: post.text,
            hashtags: const <String>[],
            createdAt: post.createdAt,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
          ),
        )
        .toList(growable: false);

    mapped.sort((left, right) {
      final leftScore = (left.likeCount + left.commentCount) / 2;
      final rightScore = (right.likeCount + right.commentCount) / 2;
      return rightScore.compareTo(leftScore);
    });

    if (mapped.length <= 20) {
      return mapped;
    }
    return mapped.sublist(0, 20);
  });
});
