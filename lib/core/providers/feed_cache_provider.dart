import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../services/room_discovery_service.dart';

/// Cached feed state that persists across sessions
class CachedFeedData {
  final List<RoomModel> liveRooms;
  final List<RoomModel> upcomingRooms;
  final List<UserModel> trendingUsers;
  final Set<String> friendIds;
  final DateTime cachedAt;
  final String? lastError;

  CachedFeedData({
    required this.liveRooms,
    required this.upcomingRooms,
    required this.trendingUsers,
    required this.friendIds,
    required this.cachedAt,
    this.lastError,
  });

  /// Whether cached data is fresh (less than 5 minutes old)
  bool get isFresh => DateTime.now().difference(cachedAt).inMinutes < 5;

  /// Human-readable timestamp
  String get cachedAtDisplay {
    final minutes = DateTime.now().difference(cachedAt).inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes == 1) return '1 minute ago';
    if (minutes < 60) return '$minutes minutes ago';
    final hours = minutes ~/ 60;
    if (hours == 1) return '1 hour ago';
    return '$hours hours ago';
  }

  Map<String, dynamic> toJson() => {
    'liveRooms': liveRooms.map((r) => r.toJson()).toList(),
    'upcomingRooms': upcomingRooms.map((r) => r.toJson()).toList(),
    'trendingUsers': trendingUsers.map((u) => u.toJson()).toList(),
    'friendIds': friendIds.toList(),
    'cachedAt': cachedAt.toIso8601String(),
    'lastError': lastError,
  };

  static CachedFeedData fromJson(Map<String, dynamic> json) {
    return CachedFeedData(
      liveRooms: (json['liveRooms'] as List?)
          ?.map((r) => RoomModel.fromJson(r, r['id'] ?? ''))
          .toList() ?? [],
      upcomingRooms: (json['upcomingRooms'] as List?)
          ?.map((r) => RoomModel.fromJson(r, r['id'] ?? ''))
          .toList() ?? [],
      trendingUsers: (json['trendingUsers'] as List?)
          ?.map((u) => UserModel.fromJson(u))
          .toList() ?? [],
      friendIds: Set<String>.from(json['friendIds'] as List? ?? []),
      cachedAt: DateTime.parse(json['cachedAt'] as String? ?? DateTime.now().toIso8601String()),
      lastError: json['lastError'] as String?,
    );
  }
}

/// Provider for persisted feed cache
final feedCacheProvider = FutureProvider.autoDispose<CachedFeedData?>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('feed_cache_data');
    
    if (cached == null) {
      if (kDebugMode) {
        debugPrint('[FeedCache] No cached feed data found');
      }
      return null;
    }
    
    final data = CachedFeedData.fromJson(jsonDecode(cached));
    if (kDebugMode) {
      debugPrint('[FeedCache] Loaded cached feed (${data.liveRooms.length} rooms, cached ${data.cachedAtDisplay})');
    }
    return data;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[FeedCache] Error loading cached feed: $e');
    }
    return null;
  }
});

/// Save feed data to cache
final feedCacheSaveProvider = FutureProvider.autoDispose.family<bool, CachedFeedData>((ref, feedData) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feed_cache_data', jsonEncode(feedData.toJson()));
    
    if (kDebugMode) {
      debugPrint('[FeedCache] Saved feed cache (${feedData.liveRooms.length} rooms, ${feedData.trendingUsers.length} users)');
    }
    return true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[FeedCache] Error saving feed cache: $e');
    }
    return false;
  }
});

/// Combined feed state: tries to use fresh data, falls back to cache if network fails
class CombinedFeedState {
  final bool isLoading;
  final String? error;
  final List<RoomModel> liveRooms;
  final List<RoomModel> upcomingRooms;
  final Map<String, String> roomReasons;
  final Map<String, String> roomTiers;
  final List<UserModel> trendingUsers;
  final Set<String> friendIds;
  final RoomDiscoverySections? discoverySections;
  
  /// Whether data is from cache (stale) vs fresh network fetch
  final bool isCached;
  /// When the data was cached (if isCached == true)
  final String? cachedAtDisplay;

  CombinedFeedState({
    required this.isLoading,
    this.error,
    this.liveRooms = const [],
    this.upcomingRooms = const [],
    this.roomReasons = const {},
    this.roomTiers = const {},
    this.trendingUsers = const [],
    this.friendIds = const {},
    this.discoverySections,
    this.isCached = false,
    this.cachedAtDisplay,
  });

  /// User-friendly status message
  String get statusMessage {
    if (isLoading && !isCached) return 'Loading discovery feed...';
    if (isCached && error != null) return 'Using cached data (${cachedAtDisplay ?? 'unknown'})';
    if (isCached) return 'Last updated ${cachedAtDisplay ?? 'recently'}';
    return '';
  }
}
