import 'dart:math' as math;

import '../models/room_model.dart';

/// Bucketed room discovery sections.
///
/// Rooms are de-duplicated across sections: a room appears in exactly one
/// of the priority sections (friend-hosted > trending > new > popular) and
/// always appears in [allRanked].
class RoomDiscoverySections {
  const RoomDiscoverySections({
    required this.friendHostedRooms,
    required this.friendPresentRooms,
    required this.trendingRooms,
    required this.newRooms,
    required this.popularRooms,
    required this.allRanked,
  });

  /// Rooms where a friend is the host (highest social signal).
  final List<RoomModel> friendHostedRooms;

  /// Rooms where at least one friend is in the audience but is NOT the host.
  final List<RoomModel> friendPresentRooms;

  /// Rooms growing faster than [RoomDiscoveryService.trendingRateThreshold]
  /// listeners per minute (de-duped: excludes friend rooms).
  final List<RoomModel> trendingRooms;

  /// Rooms started within [RoomDiscoveryService.newRoomMaxAgeMinutes]
  /// (de-duped: excludes friend and trending rooms).
  final List<RoomModel> newRooms;

  /// Rooms with [RoomDiscoveryService.popularMinListeners]+ listeners
  /// (de-duped: excludes friend, trending, and new rooms).
  final List<RoomModel> popularRooms;

  /// All rooms in discovery-ranked order (not de-duped — full list).
  final List<RoomModel> allRanked;

  /// `true` when every section is empty (i.e. no rooms at all).
  bool get isEmpty => allRanked.isEmpty;

  /// Total unique priority rooms (friend-hosted + trending + new + popular).
  /// Does not include [allRanked] to avoid double-counting.
  int get prioritySectionCount =>
      friendHostedRooms.length +
      friendPresentRooms.length +
      trendingRooms.length +
      newRooms.length +
      popularRooms.length;
}

/// Pure-Dart service for computing discovery sections from an already-loaded
/// list of ranked [RoomModel]s.
///
/// No Firebase dependency — all data is provided by the caller.
/// Call [buildSections] after [RoomService.getRecommendedLiveRooms].
abstract final class RoomDiscoveryService {
  // ─── Thresholds ───────────────────────────────────────────────────────────

  /// Listeners-per-minute growth rate above which a room is "trending".
  static const double trendingRateThreshold = 1.0;

  /// Rooms started within this many minutes are labelled "New".
  static const int newRoomMaxAgeMinutes = 20;

  /// Minimum listener count to qualify for the "Popular" section.
  static const int popularMinListeners = 20;

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Build discovery sections from [rankedRooms] (already ranked by score)
  /// and the viewer's [friendIds].
  ///
  /// Sections are capped to avoid overwhelming the UI:
  /// * [RoomDiscoverySections.friendHostedRooms] — up to 5
  /// * [RoomDiscoverySections.friendPresentRooms] — up to 5
  /// * [RoomDiscoverySections.trendingRooms] — up to 6
  /// * [RoomDiscoverySections.newRooms] — up to 4
  /// * [RoomDiscoverySections.popularRooms] — up to 8
  static RoomDiscoverySections buildSections({
    required List<RoomModel> rankedRooms,
    required Set<String> friendIds,
  }) {
    // Track which room IDs have been placed into a priority section.
    final prioritised = <String>{};

    // ── Friend-hosted ──────────────────────────────────────────────────────
    final friendHosted = <RoomModel>[];
    for (final room in rankedRooms) {
      if (friendHosted.length >= 5) break;
      if (friendIds.contains(room.hostId)) {
        friendHosted.add(room);
        prioritised.add(room.id);
      }
    }

    // ── Friend-present (in audience, NOT hosting) ──────────────────────────
    final friendPresent = <RoomModel>[];
    for (final room in rankedRooms) {
      if (friendPresent.length >= 5) break;
      if (prioritised.contains(room.id)) continue;
      final members = [...room.stageUserIds, ...room.audienceUserIds];
      final hasFriendInAudience =
          members.any((id) => friendIds.contains(id) && id != room.hostId);
      if (hasFriendInAudience) {
        friendPresent.add(room);
        prioritised.add(room.id);
      }
    }

    // ── Trending (fast growth) ─────────────────────────────────────────────
    final trending = <RoomModel>[];
    for (final room in rankedRooms) {
      if (trending.length >= 6) break;
      if (prioritised.contains(room.id)) continue;
      if (_growthRate(room) >= trendingRateThreshold) {
        trending.add(room);
        prioritised.add(room.id);
      }
    }

    // ── New rooms ──────────────────────────────────────────────────────────
    final newRooms = <RoomModel>[];
    for (final room in rankedRooms) {
      if (newRooms.length >= 4) break;
      if (prioritised.contains(room.id)) continue;
      final createdAt = room.createdAt?.toDate();
      if (createdAt != null &&
          DateTime.now().difference(createdAt).inMinutes <=
              newRoomMaxAgeMinutes) {
        newRooms.add(room);
        prioritised.add(room.id);
      }
    }

    // ── Popular rooms ──────────────────────────────────────────────────────
    final popular = <RoomModel>[];
    for (final room in rankedRooms) {
      if (popular.length >= 8) break;
      if (prioritised.contains(room.id)) continue;
      final listeners = _effectiveListeners(room);
      if (listeners >= popularMinListeners) {
        popular.add(room);
        prioritised.add(room.id);
      }
    }

    return RoomDiscoverySections(
      friendHostedRooms: friendHosted,
      friendPresentRooms: friendPresent,
      trendingRooms: trending,
      newRooms: newRooms,
      popularRooms: popular,
      allRanked: List.unmodifiable(rankedRooms),
    );
  }

  // ─── Social proof helpers ─────────────────────────────────────────────────

  /// Returns the count of friends currently in [room] (host + audience).
  static int friendCountIn(RoomModel room, Set<String> friendIds) {
    if (friendIds.isEmpty) return 0;
    return room.members.where((id) => friendIds.contains(id)).length;
  }

  /// Returns `true` if [room] is growing fast enough to be "trending".
  static bool isTrending(RoomModel room) =>
      _growthRate(room) >= trendingRateThreshold;

  /// Returns `true` if [room] started recently (< [newRoomMaxAgeMinutes]).
  static bool isNew(RoomModel room) {
    final createdAt = room.createdAt?.toDate();
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt).inMinutes <= newRoomMaxAgeMinutes;
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  static double _growthRate(RoomModel room) {
    final createdAt = room.createdAt?.toDate();
    if (createdAt == null) return 0;
    final ageMinutes =
        math.max(1, DateTime.now().difference(createdAt).inMinutes);
    return _effectiveListeners(room) / ageMinutes;
  }

  static int _effectiveListeners(RoomModel room) => math.max(
        room.memberCount,
        room.stageUserIds.length + room.audienceUserIds.length,
      );
}
