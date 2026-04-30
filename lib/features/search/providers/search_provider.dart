import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

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

class SearchUser {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isVerified;
  final int followerCount;

  const SearchUser({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isVerified = false,
    this.followerCount = 0,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json, String docId) {
    return SearchUser(
      id: docId,
      username: _asString(json['username']),
      avatarUrl: _asNullableString(json['avatarUrl']),
      isVerified: _asBool(json['isVerified']),
      followerCount: _asInt(json['followerCount']),
    );
  }
}

class SearchPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final List<String> hashtags;
  final DateTime createdAt;
  final int likeCount;

  const SearchPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    this.hashtags = const [],
    required this.createdAt,
    this.likeCount = 0,
  });

  factory SearchPost.fromJson(Map<String, dynamic> json, String docId) {
    return SearchPost(
      id: docId,
      authorId: _asString(json['authorId']),
      authorName: _asString(json['authorName'], fallback: 'Unknown'),
      authorAvatarUrl: _asNullableString(json['authorAvatarUrl']),
      content: _asString(json['content']),
      hashtags: _asStringList(json['hashtags']),
      createdAt: _parseDateTime(json['createdAt']),
      likeCount: _asInt(json['likeCount']),
    );
  }
}

class SearchHashtag {
  final String hashtag;
  final int postCount;
  final DateTime lastUsedAt;

  const SearchHashtag({
    required this.hashtag,
    required this.postCount,
    required this.lastUsedAt,
  });

  factory SearchHashtag.fromJson(Map<String, dynamic> json, String docId) {
    return SearchHashtag(
      hashtag: docId,
      postCount: _asInt(json['postCount']),
      lastUsedAt: _parseDateTime(json['lastUsedAt']),
    );
  }
}

// Search users by name or username
final searchUsersProvider = FutureProvider.family<List<SearchUser>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];

  final firestore = ref.watch(firestoreProvider);
  final lowerQuery = query.trim().toLowerCase();

  try {
    var snapshot = await firestore
        .collection('users')
        .where('isPrivate', isEqualTo: false)
        .where('usernameLower', isGreaterThanOrEqualTo: lowerQuery)
        .where('usernameLower', isLessThan: '$lowerQuery\uf8ff')
        .limit(20)
        .get();

    if (snapshot.docs.isEmpty) {
      snapshot = await firestore
          .collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: lowerQuery)
          .where('usernameLower', isLessThan: '$lowerQuery\uf8ff')
          .limit(20)
          .get();
    }

    return snapshot.docs
        .where((doc) => (doc.data()['isPrivate'] as bool?) != true)
        .map((doc) => SearchUser.fromJson(doc.data(), doc.id))
        .toList();
  } on FirebaseException catch (error, stackTrace) {
    developer.log(
      'searchUsersProvider query failed for "$lowerQuery"',
      name: 'search_provider',
      error: error,
      stackTrace: stackTrace,
    );
    return const <SearchUser>[];
  }
});

// Search posts by content
final searchPostsProvider = FutureProvider.family<List<SearchPost>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];

  final firestore = ref.watch(firestoreProvider);

  final snapshot = await firestore
      .collection('posts')
      .where('tags', arrayContains: query.toLowerCase())
      .orderBy('createdAt', descending: true)
      .limit(20)
      .get();

  return snapshot.docs
      .map((doc) => SearchPost.fromJson(doc.data(), doc.id))
      .toList();
});

// Search hashtags
final searchHashtagsProvider =
    FutureProvider.family<List<SearchHashtag>, String>((ref, query) async {
      if (query.isEmpty) return [];

      final firestore = ref.watch(firestoreProvider);
      final lowerQuery = query.toLowerCase().replaceAll('#', '');

      final snapshot = await firestore
          .collection('hashtags')
          .where('hashtag', isGreaterThanOrEqualTo: lowerQuery)
          .where('hashtag', isLessThan: '${lowerQuery}z')
          .orderBy('hashtag')
          .orderBy('postCount', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => SearchHashtag.fromJson(doc.data(), doc.id))
          .toList();
    });

/// Returns the 50 most-recently joined users — shown on the People tab before
/// the user has typed anything.
final browseAllUsersProvider = FutureProvider<List<SearchUser>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();
  return snapshot.docs
      .map((doc) => SearchUser.fromJson(doc.data(), doc.id))
      .toList();
});

// Trending hashtags
final trendingHashtagsProvider = FutureProvider<List<SearchHashtag>>((
  ref,
) async {
  final firestore = ref.watch(firestoreProvider);

  final snapshot = await firestore
      .collection('hashtags')
      .orderBy('postCount', descending: true)
      .orderBy('lastUsedAt', descending: true)
      .limit(20)
      .get();

  return snapshot.docs
      .map((doc) => SearchHashtag.fromJson(doc.data(), doc.id))
      .toList();
});
