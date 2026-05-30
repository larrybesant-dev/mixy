import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/services/follow_service.dart';

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

class UserFollow {
  final String userId;
  final String username;
  final String? avatarUrl;
  final bool isVerified;

  const UserFollow({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.isVerified = false,
  });

  factory UserFollow.fromJson(Map<String, dynamic> json, String docId) {
    return UserFollow(
      userId: docId,
      username: _asString(json['username']),
      avatarUrl: _asNullableString(json['avatarUrl']),
      isVerified: _asBool(json['isVerified']),
    );
  }
}

final followServiceProvider = Provider<FollowService>((ref) {
  return FollowService(firestore: ref.watch(firestoreProvider));
});

/// The only provider in the app allowed to open a follows `.snapshots()` stream.
final rawFollowGraphStreamProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, userId) {
      return ref.watch(followServiceProvider).watchFollowingIds(userId);
    });

final rawFollowerIdsStreamProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, userId) {
      return ref.watch(followServiceProvider).watchFollowerIds(userId);
    });

Future<List<UserFollow>> _loadUserFollowsByIds({
  required FirebaseFirestore firestore,
  required List<String> ids,
}) async {
  if (ids.isEmpty) {
    return const <UserFollow>[];
  }

  final users = <UserFollow>[];
  for (var index = 0; index < ids.length; index += 10) {
    final end = (index + 10).clamp(0, ids.length);
    final batch = ids.sublist(index, end);
    try {
      final userSnap = await firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in userSnap.docs) {
        users.add(UserFollow.fromJson(doc.data(), doc.id));
      }
    } catch (_) {
      // Skip unavailable user records and keep the rest of the list responsive.
      continue;
    }
  }

  return users;
}

final _userFollowsByIdsKeyProvider = FutureProvider.autoDispose
    .family<List<UserFollow>, String>((ref, key) async {
      if (key.isEmpty) {
        return const <UserFollow>[];
      }

      final firestore = ref.watch(firestoreProvider);
      final ids = key
          .split('|')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      return _loadUserFollowsByIds(firestore: firestore, ids: ids);
    });

// Stream of followers
final followersProvider = Provider.autoDispose
    .family<AsyncValue<List<UserFollow>>, String>((ref, userId) {
      if (userId.trim().isEmpty) {
        return const AsyncValue.data(<UserFollow>[]);
      }

      final idsAsync = ref.watch(rawFollowerIdsStreamProvider(userId));
      if (idsAsync.hasError) {
        return AsyncValue<List<UserFollow>>.error(
          idsAsync.error!,
          idsAsync.stackTrace!,
        );
      }
      if (idsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      final ids =
          (idsAsync.valueOrNull ?? const <String>[])
              .where((id) => id.isNotEmpty)
              .toList(growable: false)
            ..sort();
      return ref.watch(_userFollowsByIdsKeyProvider(ids.join('|')));
    });

// Stream of following
final followingProvider = Provider.autoDispose
    .family<AsyncValue<List<UserFollow>>, String>((ref, userId) {
      if (userId.trim().isEmpty) {
        return const AsyncValue.data(<UserFollow>[]);
      }

      final idsAsync = ref.watch(rawFollowGraphStreamProvider(userId));
      if (idsAsync.hasError) {
        return AsyncValue<List<UserFollow>>.error(
          idsAsync.error!,
          idsAsync.stackTrace!,
        );
      }
      if (idsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      final ids =
          (idsAsync.valueOrNull ?? const <String>[])
              .where((id) => id.isNotEmpty)
              .toList(growable: false)
            ..sort();
      return ref.watch(_userFollowsByIdsKeyProvider(ids.join('|')));
    });

// Follow count
final followCountProvider =
    FutureProvider.family<({int followers, int following}), String>((
      ref,
      userId,
    ) async {
      final firestore = ref.watch(firestoreProvider);
      final followersSnap = await firestore
          .collection('follows')
          .where('followedUserId', isEqualTo: userId)
          .count()
          .get();
      final followingSnap = await firestore
          .collection('follows')
          .where('followerUserId', isEqualTo: userId)
          .count()
          .get();

      return (
        followers: followersSnap.count ?? 0,
        following: followingSnap.count ?? 0,
      );
    });

// Check if current user follows target user
final isFollowingProvider =
    FutureProvider.family<bool, ({String currentUserId, String targetUserId})>((
      ref,
      params,
    ) async {
      final firestore = ref.watch(firestoreProvider);
      final doc = await firestore
          .collection('follows')
          .doc('${params.currentUserId}_${params.targetUserId}')
          .get();
      return doc.exists;
    });

// Controller for follow operations
final followControllerProvider = Provider<FollowController>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FollowController(firestore: firestore);
});

class FollowController {
  final FirebaseFirestore _firestore;

  FollowController({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
    required String targetUsername,
  }) async {
    final batch = _firestore.batch();
    final now = Timestamp.fromDate(DateTime.now());

    // Add to current user's following
    batch.set(
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId),
      {'followedAt': now},
    );

    // Add to target user's followers
    batch.set(
      _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId),
      {'followedAt': now},
    );

    // Canonical follows edge doc used by shared follow graph streams.
    batch.set(
      _firestore.collection('follows').doc('${currentUserId}_$targetUserId'),
      {
        'followerUserId': currentUserId,
        'followedUserId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final batch = _firestore.batch();

    // Remove from current user's following
    batch.delete(
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId),
    );

    // Remove from target user's followers
    batch.delete(
      _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId),
    );

    // Canonical follows edge doc used by shared follow graph streams.
    batch.delete(
      _firestore.collection('follows').doc('${currentUserId}_$targetUserId'),
    );

    await batch.commit();
  }
}




