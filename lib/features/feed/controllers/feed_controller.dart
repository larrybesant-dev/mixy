import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../../../services/moderation_service.dart';
import '../../../services/room_service.dart';
import '../../../services/room_discovery_service.dart';
import '../../../core/firestore/firestore_error_utils.dart';
import '../../../core/providers/firebase_providers.dart';

class FeedState {
  final bool isLoading;
  final String? error;
  final List<RoomModel> liveRooms;
  final List<RoomModel> upcomingRooms;
  final Map<String, String> roomReasons;
  final Map<String, String> roomTiers;
  final List<UserModel> trendingUsers;

  /// Friend IDs for the current viewer (empty when unauthenticated).
  /// Stored in state so widgets can compute per-room friend presence counts
  /// without additional Firestore reads.
  final Set<String> friendIds;

  /// Bucketed discovery sections derived from [liveRooms] + [friendIds].
  final RoomDiscoverySections? discoverySections;
  
  /// Whether this data came from browser cache (stale) vs fresh network fetch
  final bool isFromCache;
  /// When the cached data was last updated
  final DateTime? cachedAt;

  const FeedState({
    this.isLoading = false,
    this.error,
    this.liveRooms = const [],
    this.upcomingRooms = const [],
    this.roomReasons = const <String, String>{},
    this.roomTiers = const <String, String>{},
    this.trendingUsers = const [],
    this.friendIds = const <String>{},
    this.discoverySections,
    this.isFromCache = false,
    this.cachedAt,
  });

  FeedState copyWith({
    bool? isLoading,
    String? error,
    List<RoomModel>? liveRooms,
    List<RoomModel>? upcomingRooms,
    Map<String, String>? roomReasons,
    Map<String, String>? roomTiers,
    List<UserModel>? trendingUsers,
    Set<String>? friendIds,
    RoomDiscoverySections? discoverySections,
    bool? isFromCache,
    DateTime? cachedAt,
  }) {
    return FeedState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      liveRooms: liveRooms ?? this.liveRooms,
      upcomingRooms: upcomingRooms ?? this.upcomingRooms,
      roomReasons: roomReasons ?? this.roomReasons,
      roomTiers: roomTiers ?? this.roomTiers,
      trendingUsers: trendingUsers ?? this.trendingUsers,
      friendIds: friendIds ?? this.friendIds,
      discoverySections: discoverySections ?? this.discoverySections,
      isFromCache: isFromCache ?? this.isFromCache,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

class _FeedViewerProfile {
  const _FeedViewerProfile({
    this.friendIds = const <String>{},
    this.canAccessAdultRooms = false,
  });

  final Set<String> friendIds;
  final bool canAccessAdultRooms;
}

class FeedController extends Notifier<FeedState> {
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  late final ModerationService _moderationService;
  late final RoomService _roomService;

  @override
  FeedState build() {
    _firestore = ref.read(firestoreProvider);
    _auth = FirebaseAuth.instance;
    _moderationService = ModerationService(firestore: _firestore, auth: _auth);
    _roomService = ref.read(roomServiceProvider);
    return const FeedState();
  }

  Future<_FeedViewerProfile> _loadViewerProfile(String? userId) async {
    if (userId == null || userId.trim().isEmpty) {
      return const _FeedViewerProfile();
    }

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data();
    if (data == null) {
      return const _FeedViewerProfile();
    }

    return _FeedViewerProfile(
      friendIds: List<String>.from(data['friends'] ?? const <String>[]).toSet(),
      canAccessAdultRooms:
          data['adultModeEnabled'] == true &&
          data['adultConsentAccepted'] == true,
    );
  }

  /// Save feed data to browser localStorage for offline/fallback access
  void _saveFeedToCache(FeedState feedData) {
    try {
      final cacheData = {
        'liveRooms': feedData.liveRooms.map((r) => r.toJson()).toList(),
        'upcomingRooms': feedData.upcomingRooms.map((r) => r.toJson()).toList(),
        'trendingUsers': feedData.trendingUsers.map((u) => u.toJson()).toList(),
        'friendIds': feedData.friendIds.toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      };
      html.window.localStorage['feed_cache'] = jsonEncode(cacheData);
      if (kDebugMode) {
        debugPrint('[FeedCache] Saved ${feedData.liveRooms.length} rooms to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedCache] Error saving to cache: $e');
      }
    }
  }

  /// Load feed data from browser localStorage
  FeedState? _loadFeedFromCache() {
    try {
      final cached = html.window.localStorage['feed_cache'];
      if (cached == null) return null;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      final liveRooms = (data['liveRooms'] as List?)
          ?.map((r) => RoomModel.fromJson(r, r['id'] ?? ''))
          .toList() ?? [];
      final upcomingRooms = (data['upcomingRooms'] as List?)
          ?.map((r) => RoomModel.fromJson(r, r['id'] ?? ''))
          .toList() ?? [];
      final trendingUsers = (data['trendingUsers'] as List?)
          ?.map((u) => UserModel.fromJson(u))
          .toList() ?? [];
      final friendIds = Set<String>.from(data['friendIds'] as List? ?? []);
      final cachedAt = DateTime.parse(data['cachedAt'] as String? ?? DateTime.now().toIso8601String());

      final roomReasons = <String, String>{
        for (final room in liveRooms)
          room.id: _roomService.getRecommendationReason(room, friendIds: friendIds),
      };
      final roomTiers = <String, String>{
        for (final room in liveRooms)
          room.id: _roomService.getRecommendationTier(room, friendIds: friendIds),
      };

      if (kDebugMode) {
        debugPrint('[FeedCache] Loaded ${liveRooms.length} rooms from cache (cached ${cachedAt.toLocal()})');
      }

      return FeedState(
        isLoading: false,
        error: null,
        liveRooms: liveRooms,
        upcomingRooms: upcomingRooms,
        roomReasons: roomReasons,
        roomTiers: roomTiers,
        trendingUsers: trendingUsers,
        friendIds: friendIds,
        discoverySections: RoomDiscoveryService.buildSections(
          rankedRooms: liveRooms,
          friendIds: friendIds,
        ),
        isFromCache: true,
        cachedAt: cachedAt,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedCache] Error loading from cache: $e');
      }
      return null;
    }
  }

  /// Load feed from Firebase Function endpoint (bypasses browser extension blocking)
  /// Returns null if fetch fails
  Future<FeedState?> _loadFromFunctionEndpoint() async {
    try {
      final currentUserId = _auth.currentUser?.uid.trim();
      final url = Uri.parse(
        'https://us-east1-mixvy-v2.cloudfunctions.net/feed'
        '${currentUserId != null && currentUserId.isNotEmpty ? '?userId=$currentUserId' : ''}'
      );

      if (kDebugMode) {
        debugPrint('[FeedController] Fetching from Function endpoint: $url');
      }

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 504),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[FeedController] Function endpoint returned ${response.statusCode}');
        }
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        if (kDebugMode) {
          debugPrint('[FeedController] Function endpoint returned success=false');
        }
        return null;
      }

      // Parse response data
      final liveRoomsJson = data['liveRooms'] as List? ?? [];
      final upcomingRoomsJson = data['upcomingRooms'] as List? ?? [];
      final trendingUsersJson = data['trendingUsers'] as List? ?? [];

      final liveRooms = liveRoomsJson
          .map((r) => RoomModel.fromJson(r, r['id'] ?? ''))
          .toList();
      final upcomingRooms = upcomingRoomsJson
          .map((r) => RoomModel.fromJson(r, r['id'] ?? ''))
          .toList();
      final trendingUsers = trendingUsersJson
          .map((u) => UserModel.fromJson(u))
          .toList();

      // Get viewer profile for friend IDs (needed for room reasons/tiers)
      final isSignedIn = currentUserId != null && currentUserId.isNotEmpty;
      final viewerProfile = isSignedIn
          ? await _loadViewerProfile(currentUserId)
          : const _FeedViewerProfile();

      final roomReasons = <String, String>{
        for (final room in liveRooms)
          room.id: _roomService.getRecommendationReason(
            room,
            friendIds: viewerProfile.friendIds,
          ),
      };
      final roomTiers = <String, String>{
        for (final room in liveRooms)
          room.id: _roomService.getRecommendationTier(
            room,
            friendIds: viewerProfile.friendIds,
          ),
      };

      if (kDebugMode) {
        debugPrint('[FeedController] Successfully loaded feed from Function endpoint: ${liveRooms.length} live rooms');
      }

      return FeedState(
        isLoading: false,
        error: null,
        liveRooms: liveRooms,
        upcomingRooms: upcomingRooms,
        roomReasons: roomReasons,
        roomTiers: roomTiers,
        trendingUsers: trendingUsers,
        friendIds: viewerProfile.friendIds,
        discoverySections: RoomDiscoveryService.buildSections(
          rankedRooms: liveRooms,
          friendIds: viewerProfile.friendIds,
        ),
        isFromCache: false,
        cachedAt: null,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedController] Error loading from Function endpoint: $e');
      }
      return null;
    }
  }

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    
    // Phase 2: Try Function endpoint first (bypasses extension blocking)
    try {
      if (kDebugMode) {
        debugPrint('[FeedController] Attempting to load from Function endpoint...');
      }
      final functionFeed = await _loadFromFunctionEndpoint();
      if (functionFeed != null && functionFeed.liveRooms.isNotEmpty) {
        state = functionFeed;
        // Save to cache for offline fallback
        _saveFeedToCache(functionFeed);
        if (kDebugMode) {
          debugPrint('[FeedController] Successfully loaded feed from Function endpoint');
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedController] Function endpoint failed: $e');
      }
    }

    // Fallback 1: Try direct Firestore (may fail if extensions block)
    try {
      if (kDebugMode) {
        debugPrint('[FeedController] Function endpoint unavailable, trying Firestore directly...');
      }
      await _loadFeedData().timeout(
        const Duration(seconds: 10),
      );
      return;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[FeedController] Timeout loading from Firestore, checking cache...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeedController] Firestore error: $e, checking cache...');
      }
    }

    // Fallback 2: Try cache
    final cachedFeed = _loadFeedFromCache();
    if (cachedFeed != null && cachedFeed.liveRooms.isNotEmpty) {
      state = cachedFeed;
      if (kDebugMode) {
        debugPrint('[FeedController] Displayed cached feed (Function endpoint and Firestore unavailable)');
      }
      return;
    }

    // All methods failed - show error
    state = state.copyWith(
      isLoading: false,
      error: 'Unable to connect to the discovery feed. This may be caused by browser extensions. Try disabling ad blockers or opening in Incognito mode.',
    );
  }

  Future<void> _loadFeedData() async {
    try {
      final currentUserId = _auth.currentUser?.uid.trim();
      final isSignedIn = currentUserId != null && currentUserId.isNotEmpty;

      final blockedIds = isSignedIn
          ? await _moderationService.getExcludedUserIds(currentUserId)
          : <String>{};
      final viewerProfile = isSignedIn
          ? await _loadViewerProfile(currentUserId)
          : const _FeedViewerProfile();
      final liveRooms = await _roomService.getRecommendedLiveRooms(
        limit: 20,
        friendIds: viewerProfile.friendIds,
        excludedHostIds: blockedIds,
        includeAdultRooms: viewerProfile.canAccessAdultRooms,
      );
      final roomReasons = <String, String>{
        for (final room in liveRooms)
          room.id: _roomService.getRecommendationReason(
            room,
            friendIds: viewerProfile.friendIds,
          ),
      };
      final roomTiers = <String, String>{
        for (final room in liveRooms)
          room.id: _roomService.getRecommendationTier(
            room,
            friendIds: viewerProfile.friendIds,
          ),
      };
      var trendingUsers = const <UserModel>[];
      try {
        final usersSnap = await _firestore
            .collection('users')
            .where('isPrivate', isEqualTo: false)
            .limit(40)
            .get(const GetOptions(source: Source.server));
        final visibleUsers =
            usersSnap.docs
                .map((doc) => UserModel.fromJson({'id': doc.id, ...doc.data()}))
                .where((user) => !blockedIds.contains(user.id))
                .toList()
              ..sort((a, b) => b.coinBalance.compareTo(a.coinBalance));
        trendingUsers = visibleUsers.take(10).toList(growable: false);
      } on FirebaseException catch (e, stackTrace) {
        logFirestoreError(
          context: 'discovery feed trending users query',
          error: e,
          stackTrace: stackTrace,
        );
      } catch (e) {
        // Catch non-Firebase errors (network, browser extension blocking, etc.)
        debugPrint('[FeedController] Non-Firebase error fetching trending users: $e');
      }
      // Upcoming scheduled rooms (next 48 h)
      List<RoomModel> upcomingRooms = const [];
      try {
        upcomingRooms = await _roomService.getUpcomingRooms(
          limit: 8,
          includeAdultRooms: viewerProfile.canAccessAdultRooms,
        );
      } catch (e) {
        // non-critical; index may not exist yet in some environments
        debugPrint('[FeedController] Error fetching upcoming rooms: $e');
      }
      state = state.copyWith(
        isLoading: false,
        liveRooms: liveRooms,
        upcomingRooms: upcomingRooms,
        roomReasons: roomReasons,
        roomTiers: roomTiers,
        trendingUsers: trendingUsers,
        friendIds: viewerProfile.friendIds,
        discoverySections: RoomDiscoveryService.buildSections(
          rankedRooms: liveRooms,
          friendIds: viewerProfile.friendIds,
        ),
        isFromCache: false,
      );
      
      // Cache successful feed data for offline/fallback access
      _saveFeedToCache(state);
    } on FirebaseException catch (e, stackTrace) {
      logFirestoreError(
        context: 'discovery feed query',
        error: e,
        stackTrace: stackTrace,
      );
      
      // Most common cause: browser extension blocking Firestore API
      // Show helpful message to guide users to solutions
      final errorMessage = 'Unable to connect to the discovery feed.\n\n'
          'This may be caused by browser extensions blocking APIs.\n'
          'Try: disabling ad blockers or opening in Incognito mode.';
      
      if (kDebugMode) {
        debugPrint('[FeedController] Firestore error - code: ${e.code}, message: ${e.message}');
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    } catch (e, stackTrace) {
      // Catch all other errors (network, browser extension blocking, etc.)
      debugPrint('[FeedController] Error loading feed data: $e');
      debugPrintStack(stackTrace: stackTrace);
      
      // Provide helpful error message that hints at solutions
      String errorMessage = 'Failed to load discovery feed. Please check your connection and try again.';
      
      if (e.toString().contains('ABORTED') || 
          e.toString().contains('blocked') ||
          e.toString().contains('network')) {
        errorMessage = 'Unable to load discovery feed. '
            'Try disabling browser extensions (like ad blockers) or open in Incognito mode.';
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }
}

final feedControllerProvider = NotifierProvider<FeedController, FeedState>(
  () => FeedController(),
);

