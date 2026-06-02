import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

class _SearchCacheEntry<T> {
  const _SearchCacheEntry({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}

class SearchQueryCache {
  final Map<String, _SearchCacheEntry<List<SearchUser>>> _userCache = {};
  final Map<String, _SearchCacheEntry<List<SearchPost>>> _postCache = {};
  final Map<String, _SearchCacheEntry<List<SearchHashtag>>> _hashtagCache = {};
  _SearchCacheEntry<List<SearchUser>>? _browseAllUsers;
  _SearchCacheEntry<List<SearchHashtag>>? _trendingHashtags;

  Future<List<SearchUser>> users(
    String query,
    Future<List<SearchUser>> Function() loader,
  ) =>
      _resolveList(_userCache, query, const Duration(seconds: 45), loader);

  Future<List<SearchPost>> posts(
    String query,
    Future<List<SearchPost>> Function() loader,
  ) =>
      _resolveList(_postCache, query, const Duration(seconds: 30), loader);

  Future<List<SearchHashtag>> hashtags(
    String query,
    Future<List<SearchHashtag>> Function() loader,
  ) =>
      _resolveList(_hashtagCache, query, const Duration(seconds: 45), loader);

  Future<List<SearchUser>> browseAllUsers(
    Future<List<SearchUser>> Function() loader,
  ) async {
    final cached = _browseAllUsers;
    if (cached != null && cached.isFresh) {
      return cached.value;
    }
    final value = await loader();
    _browseAllUsers = _SearchCacheEntry(
      value: value,
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );
    return value;
  }

  Future<List<SearchHashtag>> trendingHashtags(
    Future<List<SearchHashtag>> Function() loader,
  ) async {
    final cached = _trendingHashtags;
    if (cached != null && cached.isFresh) {
      return cached.value;
    }
    final value = await loader();
    _trendingHashtags = _SearchCacheEntry(
      value: value,
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );
    return value;
  }

  Future<List<T>> _resolveList<T>(
    Map<String, _SearchCacheEntry<List<T>>> cache,
    String key,
    Duration ttl,
    Future<List<T>> Function() loader,
  ) async {
    final normalizedKey = key.trim().toLowerCase();
    final cached = cache[normalizedKey];
    if (cached != null && cached.isFresh) {
      return cached.value;
    }

    final value = await loader();
    cache[normalizedKey] = _SearchCacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
    return value;
  }
}

final searchQueryCacheProvider = Provider<SearchQueryCache>((ref) {
  return SearchQueryCache();
});

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
final searchUsersProvider = FutureProvider.autoDispose
    .family<List<SearchUser>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final firestore = ref.watch(firestoreProvider);
  final cache = ref.watch(searchQueryCacheProvider);
  final lowerQuery = query.trim().toLowerCase();

  return cache.users(lowerQuery, () async {
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
          .toList(growable: false);
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
});

// Search posts by content
final searchPostsProvider = FutureProvider.autoDispose
    .family<List<SearchPost>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final firestore = ref.watch(firestoreProvider);
  final cache = ref.watch(searchQueryCacheProvider);
  final normalizedQuery = query.trim().toLowerCase();

  return cache.posts(normalizedQuery, () async {
    final snapshot = await firestore
        .collection('posts')
        .where('tags', arrayContains: normalizedQuery)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => SearchPost.fromJson(doc.data(), doc.id))
        .toList(growable: false);
  });
});

// Search hashtags
final searchHashtagsProvider = FutureProvider.autoDispose
    .family<List<SearchHashtag>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final firestore = ref.watch(firestoreProvider);
  final cache = ref.watch(searchQueryCacheProvider);
  final lowerQuery = query.toLowerCase().replaceAll('#', '');

  return cache.hashtags(lowerQuery, () async {
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
        .toList(growable: false);
  });
});

/// Returns the 50 most-recently joined users — shown on the People tab before
/// the user has typed anything.
final browseAllUsersProvider = FutureProvider.autoDispose<List<SearchUser>>((
  ref,
) async {
  final firestore = ref.watch(firestoreProvider);
  final cache = ref.watch(searchQueryCacheProvider);
  return cache.browseAllUsers(() async {
    final snapshot = await firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => SearchUser.fromJson(doc.data(), doc.id))
        .toList(growable: false);
  });
});

// Trending hashtags
final trendingHashtagsProvider =
    FutureProvider.autoDispose<List<SearchHashtag>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final cache = ref.watch(searchQueryCacheProvider);

  return cache.trendingHashtags(() async {
    final snapshot = await firestore
        .collection('hashtags')
        .orderBy('postCount', descending: true)
        .orderBy('lastUsedAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => SearchHashtag.fromJson(doc.data(), doc.id))
        .toList(growable: false);
  });
});
