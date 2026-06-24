import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../features/match_inbox/services/match_inbox_service.dart';
import '../../features/match_inbox/models/match_inbox_item.dart';

/// Custom exception for match operations
class MatchException implements Exception {
  final String message;
  final String code;

  MatchException(this.message, {this.code = 'unknown'});

  @override
  String toString() => 'MatchException($code): $message';
}

/// Comprehensive match service with validation, error handling, and retry logic
class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  // Rate limiting
  static const int _maxLikesPerDay = 100;
  static const Duration _rateLimitWindow = Duration(days: 1);
  final Map<String, List<DateTime>> _likeTimestamps = {};

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // ========== Like/Unlike Operations ==========

  /// Like a user with validation and error handling
  Future<void> likeUser(String likerId, String likedUserId) async {
    // Validation
    if (likerId.isEmpty || likedUserId.isEmpty) {
      throw MatchException('User IDs cannot be empty', code: 'invalid-user-id');
    }

    if (likerId == likedUserId) {
      throw MatchException('Cannot like yourself', code: 'self-like');
    }

    // Check client-side rate limiting window
    if (_isRateLimited(likerId)) {
      throw MatchException(
        'You have exceeded the maximum number of likes per day ($_maxLikesPerDay)',
        code: 'rate-limited',
      );
    }

    // Optional: server-side rate-limit enforcement
    await _checkRateLimitServer(
      uid: likerId,
      action: 'like',
      limit: _maxLikesPerDay,
      windowSeconds: _rateLimitWindow.inSeconds,
    );

    // Check if blocked
    if (await _isBlocked(likerId, likedUserId)) {
      throw MatchException('Cannot like blocked user', code: 'blocked-user');
    }

    // Check if user exists
    if (!await _userExists(likedUserId)) {
      throw MatchException('User not found', code: 'user-not-found');
    }

    try {
      await _likeUserWithRetry(likerId, likedUserId);
      _recordLike(likerId);
      debugPrint('âœ… User $likerId liked $likedUserId');
    } catch (e) {
      debugPrint('âŒ Failed to like user: $e');
      throw MatchException('Failed to like user: $e', code: 'like-failed');
    }
  }

  /// Like user with retry logic
  Future<void> _likeUserWithRetry(String likerId, String likedUserId,
      {int attempt = 0}) async {
    try {
      final likeData = {
        'likerId': likerId,
        'likedUserId': likedUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'matchQualityScore': await _calculateMatchQuality(likerId, likedUserId),
      };

      // Check if already liked
      final existingLike = await _firestore
          .collection('likes')
          .where('likerId', isEqualTo: likerId)
          .where('likedUserId', isEqualTo: likedUserId)
          .get();

      if (existingLike.docs.isEmpty) {
        await _firestore.collection('likes').add(likeData);

        // Check for mutual like (match)
        final mutualLike = await _firestore
            .collection('likes')
            .where('likerId', isEqualTo: likedUserId)
            .where('likedUserId', isEqualTo: likerId)
            .get();

        if (mutualLike.docs.isNotEmpty) {
          await _createMatch(likerId, likedUserId);
        } else {
          // Send notification for like (non-blocking)
          _sendLikeNotification(likedUserId, likerId).catchError((e) {
            debugPrint('Failed to send like notification: $e');
          });
        }
      } else {
        debugPrint('âš ï¸ User already liked');
      }
    } catch (e) {
      if (attempt < _maxRetries) {
        debugPrint('âš ï¸ Retry attempt ${attempt + 1} for like operation');
        await Future.delayed(_retryDelay * (attempt + 1));
        return _likeUserWithRetry(likerId, likedUserId, attempt: attempt + 1);
      }
      rethrow;
    }
  }

  /// Server-side rate limit check via Cloud Function
  Future<void> _checkRateLimitServer({
    required String uid,
    required String action,
    required int limit,
    required int windowSeconds,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkRateLimit');
      final result = await callable.call({
        'action': action,
        'limit': limit,
        'windowSeconds': windowSeconds,
      });
      final data = result.data as Map;
      final allowed = data['allowed'] == true;
      if (!allowed) {
        final retryAfterSeconds =
            (data['retryAfterSeconds'] as num?)?.toInt() ?? 0;
        throw MatchException(
          'Rate limit exceeded. Try again in ${retryAfterSeconds}s',
          code: 'rate-limited',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        final retryAfterSeconds =
            (e.details?['retryAfterSeconds'] as num?)?.toInt() ?? 0;
        throw MatchException(
          'Rate limit exceeded. Try again in ${retryAfterSeconds}s',
          code: 'rate-limited',
        );
      }
      // Non-rate-limit errors bubble up as general failures
      throw MatchException('Rate limit check failed: ${e.message}',
          code: 'rate-check-failed');
    } catch (e) {
      // If function unavailable, proceed without blocking to avoid hard dependency
      debugPrint('Rate limit function unavailable: $e');
    }
  }

  /// Unlike a user
  Future<void> unlikeUser(String likerId, String likedUserId) async {
    if (likerId.isEmpty || likedUserId.isEmpty) {
      throw MatchException('User IDs cannot be empty', code: 'invalid-user-id');
    }

    try {
      await _unlikeUserWithRetry(likerId, likedUserId);
      debugPrint('âœ… User $likerId unliked $likedUserId');
    } catch (e) {
      debugPrint('âŒ Failed to unlike user: $e');
      throw MatchException('Failed to unlike user: $e', code: 'unlike-failed');
    }
  }

  /// Unlike user with retry logic
  Future<void> _unlikeUserWithRetry(String likerId, String likedUserId,
      {int attempt = 0}) async {
    try {
      final likeQuery = await _firestore
          .collection('likes')
          .where('likerId', isEqualTo: likerId)
          .where('likedUserId', isEqualTo: likedUserId)
          .get();

      final batch = _firestore.batch();
      for (var doc in likeQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      if (attempt < _maxRetries) {
        debugPrint('âš ï¸ Retry attempt ${attempt + 1} for unlike operation');
        await Future.delayed(_retryDelay * (attempt + 1));
        return _unlikeUserWithRetry(likerId, likedUserId, attempt: attempt + 1);
      }
      rethrow;
    }
  }

  // ========== Match Operations ==========

  /// Create a match between two users - Phase 3: Transaction-based for atomicity
  Future<void> _createMatch(String user1Id, String user2Id) async {
    try {
      // Check if match already exists
      final existingMatch = await _findMatch(user1Id, user2Id);
      if (existingMatch != null) {
        debugPrint('âš ï¸ Match already exists');
        return;
      }

      // Use transaction to ensure atomicity
      String? matchId;
      String? chatId;

      await _firestore.runTransaction((transaction) async {
        // Calculate match quality
        final matchQuality = await _calculateMatchQuality(user1Id, user2Id);

        // Create chat room for the match first (generates ID)
        final chatRef = _firestore.collection('chatRooms').doc();
        chatId = chatRef.id;

        final chatData = {
          'participants': ([user1Id, user2Id]..sort()),
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'type': 'match',
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCounts': {user1Id: 0, user2Id: 0},
        };

        transaction.set(chatRef, chatData);

        // Create match document
        final matchRef = _firestore.collection('matches').doc();
        matchId = matchRef.id;

        final matchData = {
          'user1': user1Id,
          'user2': user2Id,
          'matchedAt': FieldValue.serverTimestamp(),
          'matchQualityScore': matchQuality,
          'chatId': chatId,
          'isActive': true,
        };

        transaction.set(matchRef, matchData);
      });

      // Send match notifications (non-blocking, outside transaction)
      if (matchId != null) {
        _sendMatchNotifications(user1Id, user2Id, matchId!).catchError((e) {
          debugPrint('âš ï¸ Failed to send match notifications: $e');
        });
      }
      // ── Create Match Inbox entries (non-blocking) ─────────────────────
      MatchInboxService.instance.createMatch(
        user1Id,
        user2Id,
        source: MatchSource.discovery,
        metadata: matchId != null ? {'globalMatchId': matchId!, 'chatId': chatId ?? ''} : {},
      ).catchError((e) {
        debugPrint('âš ï¸ Failed to create match inbox entries: $e');
      });
      debugPrint('âœ… Match created: $matchId with chat: $chatId');
    } catch (e) {
      debugPrint('âŒ Failed to create match: $e');
      throw MatchException('Failed to create match: $e',
          code: 'match-creation-failed');
    }
  }

  /// Unmatch two users - Phase 3: Transaction-based for atomicity
  Future<void> unmatch(String userId, String otherUserId) async {
    if (userId.isEmpty || otherUserId.isEmpty) {
      throw MatchException('User IDs cannot be empty', code: 'invalid-user-id');
    }

    try {
      final matchDoc = await _findMatch(userId, otherUserId);
      if (matchDoc == null) {
        throw MatchException('Match not found', code: 'match-not-found');
      }

      final matchData = matchDoc.data() as Map<String, dynamic>;
      final chatId = matchData['chatId'] as String?;

      // Use transaction to ensure atomic unmatch
      await _firestore.runTransaction((transaction) async {
        // Delete match
        transaction.delete(matchDoc.reference);

        // Mark chat room as inactive
        if (chatId != null) {
          final chatRef = _firestore.collection('chatRooms').doc(chatId);
          transaction.update(chatRef, {
            'isActive': false,
            'unmatchedAt': FieldValue.serverTimestamp(),
            'unmatchedBy': userId,
          });
        }

        // Delete likes in both directions
        final likes1 = await _firestore
            .collection('likes')
            .where('likerId', isEqualTo: userId)
            .where('likedUserId', isEqualTo: otherUserId)
            .limit(1)
            .get();

        for (var doc in likes1.docs) {
          transaction.delete(doc.reference);
        }

        final likes2 = await _firestore
            .collection('likes')
            .where('likerId', isEqualTo: otherUserId)
            .where('likedUserId', isEqualTo: userId)
            .limit(1)
            .get();

        for (var doc in likes2.docs) {
          transaction.delete(doc.reference);
        }
      });

      debugPrint('âœ… Unmatched users: $userId and $otherUserId');
    } catch (e) {
      debugPrint('âŒ Failed to unmatch: $e');
      throw MatchException('Failed to unmatch: $e', code: 'unmatch-failed');
    }
  }

  // ========== Query Operations ==========

  /// Check if user is liked
  Future<bool> isUserLiked(String likerId, String likedUserId) async {
    try {
      final likeQuery = await _firestore
          .collection('likes')
          .where('likerId', isEqualTo: likerId)
          .where('likedUserId', isEqualTo: likedUserId)
          .limit(1)
          .get();

      return likeQuery.docs.isNotEmpty;
    } catch (e) {
      debugPrint('âŒ Failed to check like status: $e');
      return false;
    }
  }

  /// Get user's likes
  Future<List<String>> getUserLikes(String userId) async {
    try {
      final likesQuery = await _firestore
          .collection('likes')
          .where('likerId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return likesQuery.docs
          .map((doc) => doc['likedUserId'] as String)
          .toList();
    } catch (e) {
      debugPrint('âŒ Failed to get user likes: $e');
      return [];
    }
  }

  /// Get users who liked this user
  Future<List<String>> getUserLikedBy(String userId) async {
    try {
      final likesQuery = await _firestore
          .collection('likes')
          .where('likedUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return likesQuery.docs.map((doc) => doc['likerId'] as String).toList();
    } catch (e) {
      debugPrint('âŒ Failed to get users who liked: $e');
      return [];
    }
  }

  /// Get user's matches
  Future<List<String>> getUserMatches(String userId) async {
    try {
      final matches1 = await _firestore
          .collection('matches')
          .where('user1', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final matches2 = await _firestore
          .collection('matches')
          .where('user2', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final matchUserIds = <String>[];
      matchUserIds.addAll(matches1.docs.map((doc) => doc['user2'] as String));
      matchUserIds.addAll(matches2.docs.map((doc) => doc['user1'] as String));

      return matchUserIds;
    } catch (e) {
      debugPrint('âŒ Failed to get user matches: $e');
      return [];
    }
  }

  /// Get potential matches with improved filtering
  Future<List<QueryDocumentSnapshot>> getPotentialMatches(
    String userId, {
    int limit = 50,
    List<String>? interests,
    int? minAge,
    int? maxAge,
    String? gender,
  }) async {
    try {
      // Get users already liked and matched
      final likedUsers = await getUserLikes(userId);
      final matchedUsers = await getUserMatches(userId);
      final excludedUsers = {...likedUsers, ...matchedUsers, userId};

      var query =
          _firestore.collection('users').where('uid', isNotEqualTo: userId);

      // Apply filters
      if (gender != null && gender.isNotEmpty) {
        query = query.where('gender', isEqualTo: gender);
      }

      if (interests != null && interests.isNotEmpty) {
        query = query.where('interests', arrayContainsAny: interests);
      }

      final snapshot =
          await query.limit(limit * 2).get(); // Get extra to filter out

      // Filter excluded users and apply age filter
      final filteredDocs = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final uid = data['uid'] as String?;

            if (uid == null || excludedUsers.contains(uid)) {
              return false;
            }

            // Age filter
            if (minAge != null || maxAge != null) {
              final age = data['age'] as int?;
              if (age == null) return false;
              if (minAge != null && age < minAge) return false;
              if (maxAge != null && age > maxAge) return false;
            }

            return true;
          })
          .take(limit)
          .toList();

      debugPrint('âœ… Found ${filteredDocs.length} potential matches');
      return filteredDocs;
    } catch (e) {
      debugPrint('âŒ Failed to get potential matches: $e');
      return [];
    }
  }

  /// Create chat room for match
  Future<String> createChatForMatch(String uid1, String uid2) async {
    try {
      final sortedIds = ([uid1, uid2]..sort());
      final roomId = sortedIds.join('_');
      await _firestore.collection('chatRooms').doc(roomId).set({
        'participants': sortedIds,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'unreadCounts': {uid1: 0, uid2: 0},
        'type': 'match',
      }, SetOptions(merge: true));

      debugPrint('Chat room created for match: $roomId');
      return roomId;
    } catch (e) {
      debugPrint('Failed to create chat room: $e');
      throw MatchException('Failed to create chat: $e',
          code: 'chat-creation-failed');
    }
  }

  // ========== Helper Methods ==========

  /// Check if user exists
  Future<bool> _userExists(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Check if users are blocked
  Future<bool> _isBlocked(String userId, String otherUserId) async {
    try {
      final blockQuery = await _firestore
          .collection('blocked_users')
          .where('blockerId', whereIn: [userId, otherUserId])
          .where('blockedId', whereIn: [userId, otherUserId])
          .limit(1)
          .get();

      return blockQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Find match between two users
  Future<DocumentSnapshot?> _findMatch(String user1Id, String user2Id) async {
    try {
      final match1 = await _firestore
          .collection('matches')
          .where('user1', isEqualTo: user1Id)
          .where('user2', isEqualTo: user2Id)
          .limit(1)
          .get();

      if (match1.docs.isNotEmpty) {
        return match1.docs.first;
      }

      final match2 = await _firestore
          .collection('matches')
          .where('user1', isEqualTo: user2Id)
          .where('user2', isEqualTo: user1Id)
          .limit(1)
          .get();

      return match2.docs.isNotEmpty ? match2.docs.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Calculate match quality score based on shared interests
  Future<double> _calculateMatchQuality(String user1Id, String user2Id) async {
    try {
      final user1Doc = await _firestore.collection('users').doc(user1Id).get();
      final user2Doc = await _firestore.collection('users').doc(user2Id).get();

      if (!user1Doc.exists || !user2Doc.exists) return 0.0;

      final user1Data = user1Doc.data() as Map<String, dynamic>;
      final user2Data = user2Doc.data() as Map<String, dynamic>;

      final user1Interests =
          (user1Data['interests'] as List?)?.cast<String>() ?? [];
      final user2Interests =
          (user2Data['interests'] as List?)?.cast<String>() ?? [];

      if (user1Interests.isEmpty || user2Interests.isEmpty) return 0.5;

      final sharedInterests =
          user1Interests.where((i) => user2Interests.contains(i)).length;
      final totalInterests = {...user1Interests, ...user2Interests}.length;

      return totalInterests > 0 ? sharedInterests / totalInterests : 0.5;
    } catch (e) {
      debugPrint('Failed to calculate match quality: $e');
      return 0.5;
    }
  }

  /// Check if user is rate limited
  bool _isRateLimited(String userId) {
    final now = DateTime.now();
    final timestamps = _likeTimestamps[userId] ?? [];

    // Remove old timestamps
    timestamps.removeWhere((t) => now.difference(t) > _rateLimitWindow);
    _likeTimestamps[userId] = timestamps;

    return timestamps.length >= _maxLikesPerDay;
  }

  /// Record like for rate limiting
  void _recordLike(String userId) {
    _likeTimestamps[userId] = [
      ...(_likeTimestamps[userId] ?? []),
      DateTime.now()
    ];
  }

  /// Send like notification via Cloud Function
  Future<void> _sendLikeNotification(String toUserId, String fromUserId) async {
    try {
      await _functions.httpsCallable('sendLikeNotification').call({
        'toUserId': toUserId,
        'fromUserId': fromUserId,
      });
    } catch (e) {
      debugPrint('Failed to send like notification: $e');
    }
  }

  /// Send match notifications to both users
  Future<void> _sendMatchNotifications(
      String user1Id, String user2Id, String matchId) async {
    try {
      await _functions.httpsCallable('sendMatchNotifications').call({
        'user1Id': user1Id,
        'user2Id': user2Id,
        'matchId': matchId,
      });
    } catch (e) {
      debugPrint('Failed to send match notifications: $e');
    }
  }
}
