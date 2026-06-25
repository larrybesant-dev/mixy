import 'package:cloud_firestore/cloud_firestore.dart';

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

class Group {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final List<String> memberIds;
  final String? coverImageUrl;
  final DateTime createdAt;
  final int memberCount;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.memberIds,
    this.coverImageUrl,
    required this.createdAt,
    required this.memberCount,
  });

  factory Group.fromJson(Map<String, dynamic> json, String id) {
    return Group(
      id: id,
      name: _asString(json['name']),
      description: _asString(json['description']),
      adminId: _asString(json['adminId']),
      memberIds: _asStringList(json['memberIds']),
      coverImageUrl: _asNullableString(json['coverImageUrl']),
      createdAt: _parseDateTime(json['createdAt']),
      memberCount: _asInt(json['memberCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'adminId': adminId,
      'memberIds': memberIds,
      'coverImageUrl': coverImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberCount': memberCount,
    };
  }

  bool isMember(String userId) => memberIds.contains(userId);
  bool isAdmin(String userId) => adminId == userId;
}

class GroupPost {
  final String id;
  final String groupId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final int likeCount;
  final List<String> likedBy;

  GroupPost({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.likeCount,
    required this.likedBy,
  });

  factory GroupPost.fromJson(Map<String, dynamic> json, String id) {
    return GroupPost(
      id: id,
      groupId: _asString(json['groupId']),
      authorId: _asString(json['authorId']),
      authorName: _asString(json['authorName']),
      authorAvatarUrl: _asNullableString(json['authorAvatarUrl']),
      content: _asString(json['content']),
      tags: _asStringList(json['tags']),
      createdAt: _parseDateTime(json['createdAt']),
      likeCount: _asInt(json['likeCount']),
      likedBy: _asStringList(json['likedBy']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likedBy': likedBy,
    };
  }
}




