import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/moderation.dart';

/// Service for room categories and discovery
class RoomDiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Predefined room categories
  static const List<RoomCategory> defaultCategories = [
    RoomCategory(
      id: 'music',
      name: 'Music',
      description: 'Share your favorite tunes and discover new music',
      iconUrl: 'ðŸŽµ',
      roomCount: 0,
      popularTags: ['dj', 'concert', 'karaoke', 'radio'],
    ),
    RoomCategory(
      id: 'gaming',
      name: 'Gaming',
      description: 'Talk about games, esports, and gaming culture',
      iconUrl: 'ðŸŽ®',
      roomCount: 0,
      popularTags: ['fps', 'moba', 'rpg', 'streaming'],
    ),
    RoomCategory(
      id: 'social',
      name: 'Social',
      description: 'Meet new people and make friends',
      iconUrl: 'ðŸ‘¥',
      roomCount: 0,
      popularTags: ['chat', 'hangout', 'friends', 'meetup'],
    ),
    RoomCategory(
      id: 'education',
      name: 'Education',
      description: 'Learn and teach together',
      iconUrl: 'ðŸ“š',
      roomCount: 0,
      popularTags: ['study', 'language', 'coding', 'tutoring'],
    ),
    RoomCategory(
      id: 'entertainment',
      name: 'Entertainment',
      description: 'Movies, TV shows, and more',
      iconUrl: 'ðŸŽ¬',
      roomCount: 0,
      popularTags: ['movies', 'tv', 'comedy', 'drama'],
    ),
    RoomCategory(
      id: 'sports',
      name: 'Sports',
      description: 'Discuss your favorite teams and athletes',
      iconUrl: 'âš½',
      roomCount: 0,
      popularTags: ['football', 'basketball', 'soccer', 'fitness'],
    ),
    RoomCategory(
      id: 'technology',
      name: 'Technology',
      description: 'Tech talk, gadgets, and innovation',
      iconUrl: 'ðŸ’»',
      roomCount: 0,
      popularTags: ['coding', 'ai', 'crypto', 'startups'],
    ),
    RoomCategory(
      id: 'lifestyle',
      name: 'Lifestyle',
      description: 'Fashion, wellness, and daily life',
      iconUrl: 'âœ¨',
      roomCount: 0,
      popularTags: ['fashion', 'wellness', 'cooking', 'travel'],
    ),
  ];

  /// Get all categories with live room counts
  Future<List<RoomCategory>> getCategories() async {
    try {
      final List<RoomCategory> categories = [];

      for (var defaultCategory in defaultCategories) {
        // Count active rooms in this category
        final roomCount = await _getRoomCountForCategory(defaultCategory.id);

        categories.add(RoomCategory(
          id: defaultCategory.id,
          name: defaultCategory.name,
          description: defaultCategory.description,
          iconUrl: defaultCategory.iconUrl,
          roomCount: roomCount,
          popularTags: defaultCategory.popularTags,
        ));
      }

      return categories;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return defaultCategories;
    }
  }

  /// Get room count for a category
  Future<int> _getRoomCountForCategory(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('category', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting room count: $e');
      return 0;
    }
  }

  /// Get rooms by category
  Future<List<DocumentSnapshot>> getRoomsByCategory(
    String categoryId, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('category', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .orderBy('viewerCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      debugPrint('Error getting rooms by category: $e');
      return [];
    }
  }

  /// Get trending rooms (most viewers in last hour)
  Future<List<DocumentSnapshot>> getTrendingRooms({int limit = 10}) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

      final snapshot = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .orderBy('createdAt')
          .orderBy('viewerCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      debugPrint('Error getting trending rooms: $e');
      return [];
    }
  }

  /// Search rooms by keyword
  Future<List<DocumentSnapshot>> searchRooms(
    String keyword, {
    int limit = 20,
  }) async {
    try {
      final lowerKeyword = keyword.toLowerCase();

      // Search in title and tags
      final snapshot = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .orderBy('viewerCount', descending: true)
          .limit(limit * 2) // Get more to filter
          .get();

      // Filter results that match keyword in title or tags
      final filtered = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final title = (data['title'] as String?)?.toLowerCase() ?? '';
            final tags = List<String>.from(data['tags'] ?? [])
                .map((tag) => tag.toLowerCase())
                .toList();

            return title.contains(lowerKeyword) ||
                tags.any((tag) => tag.contains(lowerKeyword));
          })
          .take(limit)
          .toList();

      return filtered;
    } catch (e) {
      debugPrint('Error searching rooms: $e');
      return [];
    }
  }

  /// Get popular tags
  Future<List<String>> getPopularTags({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .orderBy('viewerCount', descending: true)
          .limit(100)
          .get();

      // Count tag occurrences
      final Map<String, int> tagCounts = {};
      for (var doc in snapshot.docs) {
        final tags = List<String>.from(doc.data()['tags'] ?? []);
        for (var tag in tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      // Sort by count and return top tags
      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('Error getting popular tags: $e');
      return [];
    }
  }

  /// Get new rooms (created in last 24 hours)
  Future<List<DocumentSnapshot>> getNewRooms({int limit = 20}) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      debugPrint('Error getting new rooms: $e');
      return [];
    }
  }

  /// Get rooms with most participants
  Future<List<DocumentSnapshot>> getPopularRooms({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .orderBy('viewerCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      debugPrint('Error getting popular rooms: $e');
      return [];
    }
  }

  // ── Typed discovery queries (Phase 1 Room Discovery Sweep) ─────────────────

  /// Trending rooms: ordered by viewerCount DESC, limit 20.
  /// This is the canonical trending query used by trendingRoomsProvider.
  Future<List<DocumentSnapshot>> getTrendingRoomsTyped({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .orderBy('viewerCount', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('Error getting trending rooms (typed): $e');
      return [];
    }
  }

  /// New rooms: ordered by createdAt DESC, limit 20.
  Future<List<DocumentSnapshot>> getNewRoomsTyped({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('Error getting new rooms (typed): $e');
      return [];
    }
  }

  /// Rooms where at least one of [friendIds] appears in participantIds.
  /// Uses array-contains-any (Firestore supports up to 30 values per query).
  Future<List<DocumentSnapshot>> getFriendsInRoomsTyped(
    List<String> friendIds, {
    int limit = 20,
  }) async {
    if (friendIds.isEmpty) return [];
    try {
      // array-contains-any supports max 30 values; chunk if needed.
      final chunks = <List<String>>[];
      for (var i = 0; i < friendIds.length; i += 30) {
        chunks.add(friendIds.sublist(
            i, i + 30 > friendIds.length ? friendIds.length : i + 30));
      }

      final results = <DocumentSnapshot>[];
      final seen = <String>{};

      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection('rooms')
            .where('isActive', isEqualTo: true)
            .where('participantIds', arrayContainsAny: chunk)
            .limit(limit)
            .get();
        for (final doc in snapshot.docs) {
          if (seen.add(doc.id)) results.add(doc);
        }
      }

      return results.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting friends-in-rooms: $e');
      return [];
    }
  }

  /// Recommended rooms: filter by user [interests] or [categories].
  /// Falls back to trending (viewerCount DESC) if no matches found.
  Future<List<DocumentSnapshot>> getRecommendedRoomsTyped({
    List<String> interests = const [],
    List<String> categories = const [],
    int limit = 20,
  }) async {
    try {
      final candidates = <DocumentSnapshot>[];
      final seen = <String>{};

      // Try by category first
      for (final cat in categories.take(5)) {
        final snapshot = await _firestore
            .collection('rooms')
            .where('isActive', isEqualTo: true)
            .where('category', isEqualTo: cat)
            .orderBy('viewerCount', descending: true)
            .limit(limit)
            .get();
        for (final doc in snapshot.docs) {
          if (seen.add(doc.id)) candidates.add(doc);
        }
        if (candidates.length >= limit) break;
      }

      // Try by tags/interests
      if (candidates.length < limit && interests.isNotEmpty) {
        final snapshot = await _firestore
            .collection('rooms')
            .where('isActive', isEqualTo: true)
            .where('tags', arrayContainsAny: interests.take(10).toList())
            .orderBy('viewerCount', descending: true)
            .limit(limit)
            .get();
        for (final doc in snapshot.docs) {
          if (seen.add(doc.id)) candidates.add(doc);
        }
      }

      // Fallback to trending if still empty
      if (candidates.isEmpty) {
        return getTrendingRoomsTyped(limit: limit);
      }

      return candidates.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting recommended rooms: $e');
      return getTrendingRoomsTyped(limit: limit);
    }
  }
}
