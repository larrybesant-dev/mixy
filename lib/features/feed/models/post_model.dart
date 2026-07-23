import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? imageUrl;
  final String? videoUrl;
  final int likeCount;
  final List<String> likedBy;
  final int commentCount;
  final int shareCount;

  PostModel({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
    this.imageUrl,
    this.videoUrl,
    this.likeCount = 0,
    this.likedBy = const [],
    this.commentCount = 0,
    this.shareCount = 0,
  });

  bool isLikedBy(String uid) => likedBy.contains(uid);

  factory PostModel.fromDoc(String id, Map<String, dynamic> data) {
    return PostModel(
      id: id,
      userId: data['authorId'] as String? ?? data['userId'] as String? ?? '',
      text: data['content'] as String? ?? data['text'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      authorName: data['authorName'] as String?,
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      imageUrl: data['imageUrl'] as String?,
      videoUrl: data['videoUrl'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      likedBy: _asStringList(data['likes']),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (data['shareCount'] as num?)?.toInt() ?? 0,
    );
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}




