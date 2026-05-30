import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  const FeedState({
    this.isLoading = true,
    this.error,
    this.liveRooms = const [],
    this.upcomingRooms = const [],
    this.roomReasons = const <String, String>{},
    this.roomTiers = const <String, String>{},
    this.trendingUsers = const [],
    this.friendIds = const <String>{},
    this.discoverySections,
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

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
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
            .get();
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
      }
      // Upcoming scheduled rooms (next 48 h)
      List<RoomModel> upcomingRooms = const [];
      try {
        upcomingRooms = await _roomService.getUpcomingRooms(
          limit: 8,
          includeAdultRooms: viewerProfile.canAccessAdultRooms,
        );
      } catch (_) {
        // non-critical; index may not exist yet in some environments
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
      );
    } on FirebaseException catch (e, stackTrace) {
      logFirestoreError(
        context: 'discovery feed query',
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isLoading: false,
        error: friendlyFirestoreMessage(
          e,
          fallbackContext: 'the discovery feed',
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final feedControllerProvider = NotifierProvider<FeedController, FeedState>(
  () => FeedController(),
);




