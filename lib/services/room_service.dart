import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/models/room_model.dart';

final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

class RoomService {
  static const Duration _participantFreshnessWindow = Duration(seconds: 90);
  static const Duration _liveRoomRemovalGraceWindow = Duration(seconds: 2);
  static const Duration _liveRoomsDebounceWindow = Duration(milliseconds: 220);
  static const Duration _roomActivityFallbackWindow = Duration(minutes: 3);

  RoomService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _roomsCollection =>
      _firestore.collection('rooms');

  Query<Map<String, dynamic>> _liveRoomsQuery({
    required int limit,
    String? category,
  }) {
    Query<Map<String, dynamic>> query = _roomsCollection.where(
      'isLive',
      isEqualTo: true,
    );
    final normalizedCategory = category?.trim();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      query = query.where('category', isEqualTo: normalizedCategory);
    }
    return query.limit(limit);
  }

  Query<Map<String, dynamic>> _upcomingRoomsQuery({
    required int limit,
    required Timestamp now,
    required Timestamp cutoff,
  }) {
    return _roomsCollection
        .where('isLive', isEqualTo: false)
        .where('scheduledAt', isGreaterThanOrEqualTo: now)
        .where('scheduledAt', isLessThanOrEqualTo: cutoff)
        .limit(limit);
  }

  CollectionReference<Map<String, dynamic>> _participantsCollection(
    String roomId,
  ) => _roomsCollection.doc(roomId).collection('participants');

  CollectionReference<Map<String, dynamic>> _membersCollection(String roomId) =>
      _roomsCollection.doc(roomId).collection('members');

  String _normalizeRoomId(String roomId) {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'roomId cannot be empty');
    }
    return trimmedRoomId;
  }

  DateTime get _freshParticipantCutoff =>
      DateTime.now().subtract(_participantFreshnessWindow);

  bool _roomDocShowsRecentActivity(RoomModel room) {
    final effectiveCount = _effectiveRoomMemberCount(room);
    if (effectiveCount <= 0) {
      return false;
    }

    final activityAt = room.updatedAt?.toDate() ?? room.createdAt?.toDate();
    if (activityAt == null) {
      return true;
    }

    return DateTime.now().difference(activityAt) <= _roomActivityFallbackWindow;
  }

  Future<bool> _hasFreshParticipants(RoomModel room) async {
    try {
      final cutoff = Timestamp.fromDate(_freshParticipantCutoff);
      final participantSnapshot = await _participantsCollection(
        room.id,
      ).where('lastActiveAt', isGreaterThanOrEqualTo: cutoff).limit(1).get();
      if (participantSnapshot.docs.isNotEmpty) {
        return true;
      }

      final memberSnapshot = await _membersCollection(
        room.id,
      ).where('lastActiveAt', isGreaterThanOrEqualTo: cutoff).limit(1).get();
      if (memberSnapshot.docs.isNotEmpty) {
        return true;
      }

      return _roomDocShowsRecentActivity(room);
    } on FirebaseException {
      // Some production rule sets can restrict participant reads.
      // Fail open here so discovery feed remains usable.
      return true;
    }
  }

/*
  Future<void> _markRoomInactive(String roomId) {
    return _roomsCollection.doc(roomId).set({
      'isLive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
*/

  int _effectiveRoomMemberCount(RoomModel room) {
    return math.max(
      room.memberCount,
      room.stageUserIds.length + room.audienceUserIds.length,
    );
  }

  RoomModel _normalizeLiveRoomSnapshot(RoomModel room) {
    return room.copyWith(memberCount: _effectiveRoomMemberCount(room));
  }

  RoomModel _mergeStableLiveRoom(RoomModel previous, RoomModel incoming) {
    final normalizedIncoming = _normalizeLiveRoomSnapshot(incoming);
    final incomingLooksCollapsed =
        normalizedIncoming.memberCount == 0 &&
        normalizedIncoming.stageUserIds.isEmpty &&
        normalizedIncoming.audienceUserIds.isEmpty &&
        _effectiveRoomMemberCount(previous) > 0;

    if (!incomingLooksCollapsed) {
      return normalizedIncoming;
    }

    return normalizedIncoming.copyWith(
      stageUserIds: previous.stageUserIds,
      audienceUserIds: previous.audienceUserIds,
      memberCount: _effectiveRoomMemberCount(previous),
    );
  }

  List<RoomModel> _sortedBufferedLiveRooms(
    Map<String, _StableLiveRoomBufferEntry> bufferedRooms,
  ) {
    final rooms =
        bufferedRooms.values.map((entry) => entry.room).toList(growable: false)
          ..sort(_compareStableLiveRooms);
    return rooms;
  }

  String _roomsFingerprint(List<RoomModel> rooms) {
    return rooms
        .map(
          (room) => [
            room.id,
            room.isLive ? '1' : '0',
            '${room.memberCount}',
            '${room.updatedAt?.millisecondsSinceEpoch ?? 0}',
          ].join(':'),
        )
        .join('|');
  }

  Stream<List<RoomModel>> _watchStabilizedLiveRooms(
    Query<Map<String, dynamic>> query, {
    required bool includeAdultRooms,
  }) {
    final controller = StreamController<List<RoomModel>>();
    final bufferedRooms = <String, _StableLiveRoomBufferEntry>{};
    Timer? debounceTimer;
    Future<void> pending = Future<void>.value();
    String? lastFingerprint;

    Future<void> processSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) async {
      final now = DateTime.now();
      final incomingRooms = await _filterActiveLiveRooms(
        snapshot.docs,
        includeAdultRooms: includeAdultRooms,
      );
      final incomingIds = <String>{};

      for (final room in incomingRooms) {
        incomingIds.add(room.id);
        final previousRoom = bufferedRooms[room.id]?.room;
        final mergedRoom = previousRoom == null
            ? room
            : _mergeStableLiveRoom(previousRoom, room);
        bufferedRooms[room.id] = _StableLiveRoomBufferEntry(
          room: mergedRoom,
          missingSince: null,
        );
      }

      for (final entry in bufferedRooms.entries.toList(growable: false)) {
        if (incomingIds.contains(entry.key)) {
          continue;
        }
        final missingSince = entry.value.missingSince ??= now;
        if (now.difference(missingSince) >= _liveRoomRemovalGraceWindow) {
          bufferedRooms.remove(entry.key);
        }
      }

      debounceTimer?.cancel();
      debounceTimer = Timer(_liveRoomsDebounceWindow, () {
        if (controller.isClosed) {
          return;
        }
        final rooms = _sortedBufferedLiveRooms(bufferedRooms);
        final fingerprint = _roomsFingerprint(rooms);
        if (fingerprint == lastFingerprint) {
          return;
        }
        lastFingerprint = fingerprint;
        controller.add(rooms);
      });
    }

    final subscription = query.snapshots().listen(
      (snapshot) {
        pending = pending.then((_) => processSnapshot(snapshot));
      },
      onError: controller.addError,
      onDone: () {
        debounceTimer?.cancel();
        controller.close();
      },
    );

    controller.onCancel = () async {
      debounceTimer?.cancel();
      await subscription.cancel();
    };

    return controller.stream;
  }

  Future<List<RoomModel>> _filterActiveLiveRooms(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool includeAdultRooms,
  }) async {
    final activeRooms = <RoomModel>[];
    for (final doc in docs) {
      final room = _normalizeLiveRoomSnapshot(
        RoomModel.fromJson(doc.data(), doc.id),
      );
      if (!includeAdultRooms && room.isAdult) {
        continue;
      }
      try {
        if (await _hasFreshParticipants(room)) {
          activeRooms.add(room);
        }
      } on FirebaseException {
        // Keep the room visible instead of failing the entire feed.
        activeRooms.add(room);
      }
    }
    activeRooms.sort(_compareStableLiveRooms);
    return activeRooms;
  }

  int _compareStableLiveRooms(RoomModel a, RoomModel b) {
    final createdA = a.createdAt?.toDate();
    final createdB = b.createdAt?.toDate();
    final createdCompare = (createdB ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(createdA ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (createdCompare != 0) {
      return createdCompare;
    }

    return a.id.compareTo(b.id);
  }

  Stream<List<RoomModel>> watchLiveRooms({
    int limit = 30,
    bool includeAdultRooms = false,
  }) {
    return _watchStabilizedLiveRooms(
      _liveRoomsQuery(limit: limit),
      includeAdultRooms: includeAdultRooms,
    );
  }

  Stream<List<RoomModel>> watchLiveRoomsByCategory({
    String? category,
    int limit = 30,
    bool includeAdultRooms = false,
  }) {
    return _watchStabilizedLiveRooms(
      _liveRoomsQuery(limit: limit, category: category),
      includeAdultRooms: includeAdultRooms,
    );
  }

  /// Rooms scheduled to start in the next 48 hours, ordered soonest first.
  Stream<List<RoomModel>> watchUpcomingRooms({
    int limit = 10,
    bool includeAdultRooms = false,
  }) {
    final now = Timestamp.now();
    final cutoff = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 48)),
    );
    return _upcomingRoomsQuery(
      limit: limit,
      now: now,
      cutoff: cutoff,
    ).snapshots().map((snap) {
      final rooms =
          snap.docs
              .map((doc) => RoomModel.fromJson(doc.data(), doc.id))
              .where((room) => includeAdultRooms || !room.isAdult)
              .toList(growable: false)
            ..sort((a, b) {
              final scheduledA =
                  a.scheduledAt?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final scheduledB =
                  b.scheduledAt?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return scheduledA.compareTo(scheduledB);
            });
      return rooms;
    });
  }

  Future<List<RoomModel>> getUpcomingRooms({
    int limit = 10,
    bool includeAdultRooms = false,
  }) async {
    if (limit <= 0) {
      return const <RoomModel>[];
    }

    final now = Timestamp.now();
    final cutoff = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 48)),
    );
    final snapshot = await _upcomingRoomsQuery(
      limit: limit,
      now: now,
      cutoff: cutoff,
    ).get();

    final rooms =
        snapshot.docs
            .map((doc) => RoomModel.fromJson(doc.data(), doc.id))
            .where((room) => includeAdultRooms || !room.isAdult)
            .toList(growable: false)
          ..sort((a, b) {
            final scheduledA =
                a.scheduledAt?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final scheduledB =
                b.scheduledAt?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return scheduledA.compareTo(scheduledB);
          });
    return rooms;
  }

  Future<List<RoomModel>> getLiveRooms({
    int limit = 20,
    bool includeAdultRooms = false,
  }) async {
    if (limit <= 0) {
      return const <RoomModel>[];
    }

    final snapshot = await _liveRoomsQuery(limit: limit).get();

    return _filterActiveLiveRooms(
      snapshot.docs,
      includeAdultRooms: includeAdultRooms,
    );
  }

  Future<List<RoomModel>> getRecommendedLiveRooms({
    required int limit,
    Set<String> friendIds = const <String>{},
    Set<String> excludedHostIds = const <String>{},
    bool includeAdultRooms = false,
  }) async {
    if (limit <= 0) {
      return const <RoomModel>[];
    }

    final rooms = await getLiveRooms(
      limit: math.max(limit * 2, limit),
      includeAdultRooms: includeAdultRooms,
    );
    final filtered = rooms
        .where((room) => !excludedHostIds.contains(room.hostId))
        .toList(growable: false);

    final sorted = filtered.toList(growable: false)
      ..sort((a, b) {
        final scoreB = _scoreRoom(b, friendIds);
        final scoreA = _scoreRoom(a, friendIds);
        final scoreCompare = scoreB.compareTo(scoreA);
        if (scoreCompare != 0) {
          return scoreCompare;
        }

        final updatedA =
            a.updatedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final updatedB =
            b.updatedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return updatedB.compareTo(updatedA);
      });

    return sorted.take(limit).toList(growable: false);
  }

  String getRecommendationReason(
    RoomModel room, {
    Set<String> friendIds = const <String>{},
  }) {
    if (friendIds.contains(room.hostId)) {
      return 'Friend is hosting';
    }

    final friendPresenceCount = room.members
        .where((memberId) => friendIds.contains(memberId))
        .length;
    if (friendPresenceCount > 1) {
      return '$friendPresenceCount friends are here';
    }
    if (friendPresenceCount == 1) {
      return '1 friend is here';
    }

    if (_isTrendingFast(room)) {
      return 'Trending fast';
    }

    if (room.memberCount >= 25) {
      return 'Popular right now';
    }

    final updatedAt = room.updatedAt?.toDate();
    if (updatedAt != null &&
        DateTime.now().difference(updatedAt).inMinutes <= 20) {
      return 'Just started';
    }

    return 'Active now';
  }

  String getRecommendationTier(
    RoomModel room, {
    Set<String> friendIds = const <String>{},
  }) {
    if (friendIds.contains(room.hostId)) {
      return 'Friends';
    }

    final friendPresenceCount = room.members
        .where((memberId) => friendIds.contains(memberId))
        .length;
    if (friendPresenceCount > 0) {
      return 'Friends';
    }

    if (_isTrendingFast(room)) {
      return 'Momentum';
    }

    if (room.memberCount >= 25) {
      return 'Hot';
    }

    final updatedAt = room.updatedAt?.toDate();
    if (updatedAt != null &&
        DateTime.now().difference(updatedAt).inMinutes <= 20) {
      return 'Fresh';
    }

    return 'Live';
  }

  bool _isTrendingFast(RoomModel room) {
    final effectiveCount = room.memberCount > 0
        ? room.memberCount
        : room.stageUserIds.length + room.audienceUserIds.length;
    if (effectiveCount < 4) {
      return false;
    }
    return _growthRate(room) >= 1.25;
  }

  double _growthRate(RoomModel room) {
    final createdAt = room.createdAt?.toDate();
    if (createdAt == null) {
      return 0;
    }
    final ageMinutes = math.max(1, DateTime.now().difference(createdAt).inMinutes);
    final effectiveCount = room.memberCount > 0
        ? room.memberCount
        : room.stageUserIds.length + room.audienceUserIds.length;
    return effectiveCount / ageMinutes;
  }

  double _scoreRoom(RoomModel room, Set<String> friendIds) {
    final memberCountScore = room.memberCount.clamp(0, 120).toDouble() * 0.8;

    final hostFriendBonus = friendIds.contains(room.hostId) ? 25.0 : 0.0;

    final friendPresenceCount = room.members
        .where((memberId) => friendIds.contains(memberId))
        .length;
    final friendPresenceBonus = math.min(friendPresenceCount * 6.0, 24.0);

    final updatedAt = room.updatedAt?.toDate();
    double recencyBonus = 0;
    if (updatedAt != null) {
      final minutesAgo = DateTime.now().difference(updatedAt).inMinutes;
      recencyBonus = math.max(0, 18 - (minutesAgo / 8));
    }

    // Momentum: listeners-per-minute since room started.
    // Favors rooms filling up quickly over established rooms coasting on size.
    double momentumBonus = 0;
    final growthRate = _growthRate(room);
    if (growthRate > 0) {
      // Cap contribution at 20pts so a brand-new room with 1 listener
      // doesn't fully outrank a popular established room.
      momentumBonus = math.min(growthRate * 4.0, 20.0);
    }

    final lockPenalty = room.isLocked ? -6.0 : 0.0;

    return memberCountScore +
        hostFriendBonus +
        friendPresenceBonus +
        recencyBonus +
        momentumBonus +
        lockPenalty;
  }

  Stream<RoomModel?> watchRoomById(String roomId) {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      return Stream<RoomModel?>.value(null);
    }

    return _roomsCollection.doc(trimmedRoomId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return RoomModel.fromJson(data, doc.id);
    });
  }

  Future<RoomModel?> getRoomById(String roomId) async {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      return null;
    }

    final doc = await _roomsCollection.doc(trimmedRoomId).get();
    if (!doc.exists) {
      return null;
    }

    final data = doc.data();
    if (data == null) {
      return null;
    }

    return RoomModel.fromJson(data, doc.id);
  }

  Future<String> createRoom({
    required String hostId,
    required String name,
    String? description,
    String? rules,
    bool isLive = true,
    bool isAdult = false,
    String? thumbnailUrl,
    String? category,
    List<String> tags = const <String>[],
    DateTime? scheduledAt,
  }) async {
    final trimmedHostId = hostId.trim();
    final trimmedName = name.trim();
    if (trimmedHostId.isEmpty) {
      throw ArgumentError.value(hostId, 'hostId', 'hostId cannot be empty');
    }
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'name cannot be empty');
    }

    final now = FieldValue.serverTimestamp();
    final docRef = _roomsCollection.doc();

    await docRef.set({
      'name': trimmedName,
      'description': description?.trim(),
      'rules': rules?.trim(),
      'hostId': trimmedHostId,
      'isLive': isLive,
      'isAdult': isAdult,
      'thumbnailUrl': thumbnailUrl?.trim(),
      'createdAt': now,
      'updatedAt': now,
      'stageUserIds': <String>[],
      'audienceUserIds': <String>[trimmedHostId],
      'memberCount': 1,
      'category': category?.trim(),
      'tags': tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      'coHosts': <String>[],
      'isLocked': false,
      'slowModeSeconds': 0,
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt),
    });

    return docRef.id;
  }

  Future<void> updateRoom(RoomModel room) async {
    final roomId = _normalizeRoomId(room.id);
    await _roomsCollection.doc(roomId).update({
      ...room.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setRoomLiveStatus(String roomId, {required bool isLive}) async {
    final normalizedRoomId = _normalizeRoomId(roomId);
    await _roomsCollection.doc(normalizedRoomId).update({
      'isLive': isLive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoom(String roomId) async {
    final normalizedRoomId = _normalizeRoomId(roomId);
    await _roomsCollection.doc(normalizedRoomId).delete();
  }
}

class _StableLiveRoomBufferEntry {
  _StableLiveRoomBufferEntry({required this.room, this.missingSince});

  RoomModel room;
  DateTime? missingSince;
}
