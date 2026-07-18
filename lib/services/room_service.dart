import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/features/room/contracts/room_visibility_contract.dart';
import 'package:mixvy/features/room/contracts/room_with_visibility.dart';
import 'package:mixvy/features/room/providers/room_visibility_windows_provider.dart';
import 'package:mixvy/models/room_model.dart';

import '../core/logger.dart';
import '../core/services/feature_gate_service.dart';
import '../core/streams/stream_lifecycle_manager.dart';

final roomServiceProvider = Provider<RoomService>((ref) {
  // Read (don't watch) any providers to avoid cascading rebuilds
  // that trigger "Cannot use ref functions after dependency changed" errors
  ref.read(roomVisibilityWindowsBootstrapProvider);
  final lifecycleManager = ref.read(streamLifecycleManagerProvider);
  return RoomService(
    isLiveRoomsEnabled: () {
      try {
        return ref.read(featureGateControllerProvider).enableLiveRooms;
      } on AssertionError {
        return true;
      }
    },
    visibilityWindowsResolver: () => ref.read(roomVisibilityWindowsProvider),
    lifecycleManager: lifecycleManager,
  );
});

class RoomService {
  static const Duration _liveRoomRemovalGraceWindow = Duration(seconds: 2);
  static const Duration _liveRoomsDebounceWindow = Duration(milliseconds: 220);
  static const Duration _discoverableDemotionBuffer = Duration(minutes: 1);
  static const Duration _discoverablePromotionBuffer = Duration(minutes: 2);
  static const Duration _warmDemotionBuffer = Duration(minutes: 3);
  static const Duration _warmPromotionBuffer = Duration(minutes: 4);

  RoomService({
    FirebaseFirestore? firestore,
    bool Function()? isLiveRoomsEnabled,
    RoomVisibilityWindows Function()? visibilityWindowsResolver,
    StreamLifecycleManager? lifecycleManager,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _isLiveRoomsEnabled = isLiveRoomsEnabled,
       _visibilityWindowsResolver = visibilityWindowsResolver,
       _streamLifecycleManager = lifecycleManager ?? StreamLifecycleManager();

  final FirebaseFirestore _firestore;
  final bool Function()? _isLiveRoomsEnabled;
  final RoomVisibilityWindows Function()? _visibilityWindowsResolver;
  final StreamLifecycleManager _streamLifecycleManager;

  RoomVisibilityWindows get _visibilityWindows {
    final resolver = _visibilityWindowsResolver;
    if (resolver == null) {
      return RoomVisibilityWindows.defaults;
    }
    return resolver();
  }

  CollectionReference<Map<String, dynamic>> get _roomsCollection =>
      _firestore.collection('rooms');

  Query<Map<String, dynamic>> _liveRoomsQuery({
    required int limit,
    String? category,
  }) {
    Query<Map<String, dynamic>> query = _roomsCollection.where('isLive', isEqualTo: true);
    final normalizedCategory = category?.trim();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      query = query.where('category', isEqualTo: normalizedCategory);
    }
    return query.orderBy('createdAt', descending: true).limit(limit);
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

  String _normalizeRoomId(String roomId) {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'roomId cannot be empty');
    }
    return trimmedRoomId;
  }

  bool _canCreateLiveRooms() {
    final resolver = _isLiveRoomsEnabled;
    if (resolver == null) {
      return true;
    }

    try {
      return resolver();
    } on AssertionError {
      return true;
    }
  }

  DateTime get _now => DateTime.now();

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
    final previousTiers = <String, RoomVisibilityTier>{};
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
        previousTiers: previousTiers,
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
          previousTiers.remove(entry.key);
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

    final dedupeKey = _streamLifecycleManager.buildDedupeKey(
      domain: 'room-live-query',
      queryHash: query.hashCode.toUnsigned(32).toRadixString(16),
    );
    final subscription = _streamLifecycleManager
        .bind<QuerySnapshot<Map<String, dynamic>>>(
          key: dedupeKey,
          routePrefixes: const <String>[
            '/home',
            '/rooms',
            '/explore',
            '/trending',
          ],
          create: () => query.snapshots(),
        )
        .listen(
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
    Map<String, RoomVisibilityTier>? previousTiers,
  }) async {
    final classified = await _classifyLiveRooms(
      docs,
      includeAdultRooms: includeAdultRooms,
      previousTiers: previousTiers,
    );
    return classified
        .where((item) => item.isVisible)
        .map((item) => item.room)
        .toList(growable: false);
  }

  Future<List<RoomWithVisibility>> _classifyLiveRooms(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool includeAdultRooms,
    Map<String, RoomVisibilityTier>? previousTiers,
  }) async {
    final activeRooms = <RoomModel>[];
    final classifiedRooms = <RoomWithVisibility>[];
    final now = _now;
    var totalDocs = 0;
    var adultDropped = 0;
    var parseDropped = 0;
    var invalidDropped = 0;
    var discoverableCount = 0;
    var warmCount = 0;
    var coldCount = 0;
    final windows = _visibilityWindows;

    for (final doc in docs) {
      totalDocs += 1;

      RoomModel room;
      try {
        room = _normalizeLiveRoomSnapshot(
          RoomModel.fromJson(doc.data(), doc.id),
        );
      } catch (error, stackTrace) {
        parseDropped += 1;
        Logger.warning(
          'ROOM_VISIBILITY parse_drop roomId=${doc.id} reason=model_parse_failed',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }

      if (!includeAdultRooms && room.isAdult) {
        adultDropped += 1;
        continue;
      }

      final decision = RoomVisibilityContract.evaluate(
        room,
        now: now,
        windows: windows,
      );
      final stabilizedDecision = _applyTierHysteresis(
        roomId: room.id,
        decision: decision,
        previousTier: previousTiers?[room.id],
        windows: windows,
      );
      previousTiers?[room.id] = stabilizedDecision.tier;

      RoomVisibilityContract.logDecision(room, stabilizedDecision);
      final withVisibility = RoomWithVisibility(
        room: room,
        visibility: stabilizedDecision,
      );
      classifiedRooms.add(withVisibility);

      switch (stabilizedDecision.tier) {
        case RoomVisibilityTier.discoverable:
          discoverableCount += 1;
          break;
        case RoomVisibilityTier.warm:
          warmCount += 1;
          break;
        case RoomVisibilityTier.cold:
          coldCount += 1;
          break;
        case RoomVisibilityTier.invalid:
          invalidDropped += 1;
          break;
      }

      if (stabilizedDecision.isVisible) {
        activeRooms.add(room);
      }
    }

    activeRooms.sort((a, b) => _compareStableLiveRooms(a, b, windows: windows));

    Logger.info(
      'ROOM_VISIBILITY snapshot_total=$totalDocs visible=${activeRooms.length} discoverable=$discoverableCount warm=$warmCount cold=$coldCount invalid_dropped=$invalidDropped adult_dropped=$adultDropped parse_dropped=$parseDropped includeAdult=$includeAdultRooms',
    );

    classifiedRooms.sort(
      (a, b) => _compareStableLiveRooms(a.room, b.room, windows: windows),
    );
    return classifiedRooms;
  }

  Stream<List<RoomWithVisibility>> watchRoomsWithVisibility({
    int limit = 30,
    bool includeAdultRooms = false,
    String? category,
  }) {
    return _liveRoomsQuery(
      limit: limit,
      category: category,
    ).snapshots().asyncMap(
      (snapshot) => _classifyLiveRooms(
        snapshot.docs,
        includeAdultRooms: includeAdultRooms,
      ),
    );
  }

  Stream<RoomWithVisibility?> watchPendingDirectCallForCallee({
    required String calleeId,
    bool includeAdultRooms = false,
  }) {
    final normalizedCalleeId = calleeId.trim();
    if (normalizedCalleeId.isEmpty) {
      return Stream.value(null);
    }

    final query = _roomsCollection
        .where('isDirectCall', isEqualTo: true)
        .where('calleeId', isEqualTo: normalizedCalleeId)
        .where('callDeclined', isEqualTo: false)
        .limit(3);

    return query.snapshots().asyncMap((snapshot) async {
      final classified = await _classifyLiveRooms(
        snapshot.docs,
        includeAdultRooms: includeAdultRooms,
      );
      for (final candidate in classified) {
        if (candidate.isVisible) {
          return candidate;
        }
      }

      if (classified.isNotEmpty) {
        final candidate = classified.first;
        AppTelemetry.logAction(
          level: 'warning',
          domain: 'feed',
          action: 'pending_direct_call_hidden',
          message: 'Pending direct call classified but not renderable.',
          roomId: candidate.room.id,
          userId: normalizedCalleeId,
          result: candidate.visibility.reasonCode.name,
          metadata: <String, Object?>{
            'candidateCount': classified.length,
            'tier': candidate.tier.name,
          },
        );
      }

      return null;
    });
  }

  Future<List<RoomWithVisibility>> getRoomsWithVisibility({
    int limit = 20,
    bool includeAdultRooms = false,
    String? category,
  }) async {
    if (limit <= 0) {
      return const <RoomWithVisibility>[];
    }

    final snapshot = await _liveRoomsQuery(
      limit: limit,
      category: category,
    ).get();
    return _classifyLiveRooms(
      snapshot.docs,
      includeAdultRooms: includeAdultRooms,
      previousTiers: null,
    );
  }

  Future<List<RoomWithVisibility>> getHostedRoomsWithVisibility({
    required String hostId,
    int limit = 10,
    bool includeAdultRooms = false,
  }) async {
    final normalizedHostId = hostId.trim();
    if (normalizedHostId.isEmpty || limit <= 0) {
      return const <RoomWithVisibility>[];
    }

    final snapshot = await _roomsCollection
        .where('hostId', isEqualTo: normalizedHostId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return _classifyLiveRooms(
      snapshot.docs,
      includeAdultRooms: includeAdultRooms,
      previousTiers: null,
    );
  }

  RoomVisibilityResult _applyTierHysteresis({
    required String roomId,
    required RoomVisibilityResult decision,
    required RoomVisibilityTier? previousTier,
    required RoomVisibilityWindows windows,
  }) {
    final staleness = decision.staleness;
    if (previousTier == null || staleness == null) {
      return decision;
    }

    if (previousTier == RoomVisibilityTier.discoverable &&
        decision.tier == RoomVisibilityTier.warm) {
      final holdUntil =
          windows.discoverableWindow + _discoverableDemotionBuffer;
      if (staleness <= holdUntil) {
        return RoomVisibilityResult(
          tier: RoomVisibilityTier.discoverable,
          reasonCode: RoomVisibilityReasonCode.discoverableHysteresisHold,
          staleness: staleness,
        );
      }
    }

    if (previousTier == RoomVisibilityTier.warm &&
        decision.tier == RoomVisibilityTier.discoverable) {
      final promoteBefore =
          windows.discoverableWindow - _discoverablePromotionBuffer;
      if (promoteBefore > Duration.zero && staleness > promoteBefore) {
        return RoomVisibilityResult(
          tier: RoomVisibilityTier.warm,
          reasonCode: RoomVisibilityReasonCode.warmHysteresisHold,
          staleness: staleness,
        );
      }
    }

    if (previousTier == RoomVisibilityTier.warm &&
        decision.tier == RoomVisibilityTier.cold) {
      final holdUntil = windows.warmWindow + _warmDemotionBuffer;
      if (staleness <= holdUntil) {
        return RoomVisibilityResult(
          tier: RoomVisibilityTier.warm,
          reasonCode: RoomVisibilityReasonCode.warmHysteresisHold,
          staleness: staleness,
        );
      }
    }

    if (previousTier == RoomVisibilityTier.cold &&
        decision.tier == RoomVisibilityTier.warm) {
      final promoteBefore = windows.warmWindow - _warmPromotionBuffer;
      if (promoteBefore > Duration.zero && staleness > promoteBefore) {
        return RoomVisibilityResult(
          tier: RoomVisibilityTier.cold,
          reasonCode: RoomVisibilityReasonCode.coldHysteresisHold,
          staleness: staleness,
        );
      }
    }

    if (decision.tier != previousTier) {
      Logger.info(
        'ROOM_VISIBILITY_TIER_TRANSITION roomId=$roomId from=${previousTier.name} to=${decision.tier.name} stalenessMs=${staleness.inMilliseconds}',
      );
    }

    return decision;
  }

  int _compareStableLiveRooms(
    RoomModel a,
    RoomModel b, {
    RoomVisibilityWindows? windows,
  }) {
    final resolvedWindows = windows ?? _visibilityWindows;
    final tierA = RoomVisibilityContract.tierFor(a, windows: resolvedWindows);
    final tierB = RoomVisibilityContract.tierFor(b, windows: resolvedWindows);
    final tierCompare = RoomVisibilityContract.tierPriority(
      tierA,
    ).compareTo(RoomVisibilityContract.tierPriority(tierB));
    if (tierCompare != 0) {
      return tierCompare;
    }

    // Score without friend context so the stable watch stream consistently
    // surfaces active rooms over stale ones, regardless of viewer identity.
    final scoreA = _scoreRoom(a, const <String>{});
    final scoreB = _scoreRoom(b, const <String>{});
    final scoreCompare = scoreB.compareTo(scoreA);
    if (scoreCompare != 0) return scoreCompare;

    // Tie-break with createdAt desc (newest first).
    final createdA = a.createdAt?.toDate() ?? DateTime(2020);
    final createdB = b.createdAt?.toDate() ?? DateTime(2020);
    final createCompare = createdB.compareTo(createdA);
    if (createCompare != 0) return createCompare;

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

  /// One-shot fetch of currently live rooms, for polling/fallback modes
  /// that cannot rely on a persistent `.snapshots()` listener.
  Future<List<RoomModel>> fetchLiveRoomsOnce({
    int limit = 50,
    bool includeAdultRooms = false,
  }) async {
    final snapshot = await _liveRoomsQuery(
      limit: limit,
    ).get(const GetOptions(source: Source.server));
    final rooms = snapshot.docs
        .map((doc) => RoomModel.fromJson(doc.data(), doc.id))
        .where((room) => includeAdultRooms || !room.isAdult)
        .toList();
    return rooms;
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
    // Force fresh HTTP request from server, not WebSocket cache
    final snapshot = await _upcomingRoomsQuery(
      limit: limit,
      now: now,
      cutoff: cutoff,
    ).get(
      const GetOptions(source: Source.server),
    );

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

    // Force fresh HTTP request from server, not WebSocket cache
    // This helps when browser extensions block WebSocket connections
    final snapshot = await _liveRoomsQuery(limit: limit).get(
      const GetOptions(source: Source.server),
    );

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
    final ageMinutes = math.max(
      1,
      DateTime.now().difference(createdAt).inMinutes,
    );
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
    String? hostUsername,
    String? hostAvatarUrl,
    String? description,
    String? rules,
    bool isLive = true,
    bool isAdult = false,
    String? thumbnailUrl,
    String? category,
    List<String> tags = const <String>[],
    DateTime? scheduledAt,
  }) async {
    if (!_canCreateLiveRooms()) {
      Logger.warning(
        'CONTROL_GATE feature_blocked feature=live_rooms operation=create_room result=blocked',
      );
      throw StateError(
        'Room creation is temporarily disabled for maintenance.',
      );
    }

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
      'meta': <String, dynamic>{'title': trimmedName},
      'description': description?.trim(),
      'rules': rules?.trim(),
      'hostId': trimmedHostId,
      'ownerId': trimmedHostId,
      'hostUsername': hostUsername?.trim(),
      'hostAvatarUrl': hostAvatarUrl?.trim(),
      'isLive': isLive,
      'endedAt': null,
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
      'endedAt': isLive ? null : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoom(String roomId) async {
    final normalizedRoomId = _normalizeRoomId(roomId);
    await _roomsCollection.doc(normalizedRoomId).delete();
  }

  /// Identifies and removes rooms that have been inactive for more than 24 hours.
  /// This maintains database hygiene for the Beta launch.
  Future<int> pruneStaleRooms() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final cutoffTimestamp = Timestamp.fromDate(cutoff);

    // 1. Prune rooms marked as Live but not updated in 24h
    final liveStaleQuery = await _roomsCollection
        .where('isLive', isEqualTo: true)
        .where('updatedAt', isLessThan: cutoffTimestamp)
        .get();

    // 2. Prune rooms that ended more than 24h ago
    final endedStaleQuery = await _roomsCollection
        .where('endedAt', isLessThan: cutoffTimestamp)
        .get();

    final allDocs = [...liveStaleQuery.docs, ...endedStaleQuery.docs];
    if (allDocs.isEmpty) return 0;

    final batch = _firestore.batch();
    int count = 0;
    for (final doc in allDocs) {
      batch.delete(doc.reference);
      count++;
    }

    await batch.commit();
    Logger.info('DATABASE_HYGIENE pruned_rooms=$count');
    return count;
  }
}

class _StableLiveRoomBufferEntry {
  _StableLiveRoomBufferEntry({required this.room, this.missingSince});

  RoomModel room;
  DateTime? missingSince;
}




