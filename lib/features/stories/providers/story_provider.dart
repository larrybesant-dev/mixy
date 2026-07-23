import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/follow/providers/follow_provider.dart';
import '../../../services/story_stream_service.dart';

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

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
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

class Story {
  final String id;
  final String userId;
  final String username;
  final String? userAvatarUrl;
  final String? imageUrl;
  final String? videoUrl;
  final String? content;
  final DateTime createdAt;
  final DateTime expiresAt; // 24 hours after creation
  final List<String> viewedBy;
  final bool isDeleted;

  const Story({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
    this.imageUrl,
    this.videoUrl,
    this.content,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
    this.isDeleted = false,
  });

  factory Story.fromJson(Map<String, dynamic> json, String docId) {
    return Story(
      id: docId,
      userId: _asString(json['userId']),
      username: _asString(json['username']),
      userAvatarUrl: _asNullableString(json['userAvatarUrl']),
      imageUrl: _asNullableString(json['imageUrl']),
      videoUrl: _asNullableString(json['videoUrl']),
      content: _asNullableString(json['content']),
      createdAt: _parseDateTime(json['createdAt']),
      expiresAt: json['expiresAt'] == null
          ? DateTime.now().add(const Duration(hours: 24))
          : _parseDateTime(json['expiresAt']),
      viewedBy: _asStringList(json['viewedBy']),
      isDeleted: _asBool(json['isDeleted']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': viewedBy,
      'isDeleted': isDeleted,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// firestoreProvider is the canonical instance from core/providers/firebase_providers.dart
final followingIdsProvider = rawFollowGraphStreamProvider;

final storyStreamServiceProvider = Provider<StoryStreamService>((ref) {
  return StoryStreamService(firestore: ref.watch(firestoreProvider));
});

// Stream of stories from following users
final followingStoriesProvider = StreamProvider.autoDispose
    .family<List<Story>, ({String userId, List<String> followingIds})>((
      ref,
      params,
    ) {
      final streamService = ref.watch(storyStreamServiceProvider);
      return streamService
          .watchFollowingStories(
            userId: params.userId,
            followingIds: params.followingIds,
          )
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Story.fromJson(doc.data(), doc.id))
                .where((story) => !story.isExpired)
                .toList();
          });
    });

// Stream of user's own stories
final myStoriesProvider = StreamProvider.autoDispose
    .family<List<Story>, String>((ref, userId) {
      final streamService = ref.watch(storyStreamServiceProvider);
      return streamService
          .watchUserStories(userId)
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Story.fromJson(doc.data(), doc.id))
                .where((story) => !story.isExpired)
                .toList();
          });
    });

// Controller for story operations
final storyControllerProvider = Provider<StoryController>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return StoryController(firestore: firestore);
});

class StoryController {
  final FirebaseFirestore _firestore;

  StoryController({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Future<void> createStory({
    required String userId,
    required String username,
    required String? userAvatarUrl,
    String? imageUrl,
    String? videoUrl,
    String? content,
  }) async {
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    await _firestore.collection('users').doc(userId).collection('stories').add({
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': [userId],
      'isDeleted': false,
    });
  }

  Future<void> markStoryAsViewed({
    required String userId,
    required String storyId,
    required String viewerId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('stories')
        .doc(storyId)
        .update({
          'viewedBy': FieldValue.arrayUnion([viewerId]),
        });
  }

  Future<void> deleteStory({
    required String userId,
    required String storyId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('stories')
        .doc(storyId)
        .update({'isDeleted': true});
  }
}




