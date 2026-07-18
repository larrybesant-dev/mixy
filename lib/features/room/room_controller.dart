import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/widgets.dart'; // Direct access to AppLifecycleState
import 'package:flutter/foundation.dart'
    show protected, debugPrint, listEquals, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

export '../../models/room_participant_model.dart'
    show roomParticipantCanBeShownAsTalking;

export 'room_permissions.dart' show shouldEjectJoinedUserFromRoom;

export 'controllers/room_state.dart'
    show
        LiveRoomPhase,
        RoomLifecycleState,
        RoomAudioState,
        RoomMembershipState,
        RoomMembershipStateX,
        RoomSessionSnapshot,
        RoomState,
        RoomStateMachine,
        RoomAction;

import '../../core/events/app_event.dart';
import '../../core/events/app_event_bus.dart';
import '../../core/firestore/firestore_error_utils.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../models/mic_access_request_model.dart';
import '../../models/room_participant_model.dart';
import '../../services/session_persistence_service.dart';
import 'controllers/room_state.dart';
import 'models/room_theme_model.dart';
import 'room_permissions.dart';
import 'room_state_contract.dart';
import 'providers/host_controls_provider.dart';
import 'providers/mic_access_provider.dart';
import 'providers/participant_providers.dart';
import 'providers/room_firestore_provider.dart';
import 'providers/message_providers.dart';
import 'repository/room_repository.dart';
import 'providers/room_policy_provider.dart';
import 'providers/user_cam_permissions_provider.dart';
import 'services/room_session_service.dart';

import '../../app/app_lifecycle_provider.dart';

final roomControllerProvider = NotifierProvider.family
    .autoDispose<RoomController, RoomState, String>(RoomController.new);

enum MicRequestResult { grabbed, queued }

/// Holds session-persistent state that must survive RoomController Notifier
/// recreation during dependency churn (common on Web and during joins).
/// This is isolated per ProviderContainer and per roomId.
class _RoomSessionState {
  LiveRoomPhase phase = LiveRoomPhase.idle;
  RoomLifecycleState lifecycleState = RoomLifecycleState.initializing;
  String? currentUserId;
  DateTime? joinedAt;
  String? errormessage;
  Set<String> excludedUserIds = const <String>{};
  bool micRequested = false;
  bool hasMicPermission = true;
  String? activeSessionId;
  final Set<String> pendingUserIds = {};
  final Set<String> stableUserIds = {};
  final Map<String, RoomSessionSnapshot> sessionSnapshotsByUser = {};
  final Map<String, DateTime> lastActiveAtByUser = {};
  final Map<String, String> pendingRoleByUser = {};
  final Map<String, DateTime> pendingRoleSetAtByUser = {};
}

final _roomSessionStateProvider = Provider.family<_RoomSessionState, String>((ref, roomId) => _RoomSessionState());

/// A simple notifier to trigger rebuilds of RoomController when session state changes.
/// Listens to the global event bus to synchronize multiple instances if needed.
class _RoomSessionRefreshNotifier extends FamilyNotifier<int, String> {
  @override
  int build(String arg) {
    final roomId = arg;
    final sub = AppEventBus.instance.stream.listen((event) {
      if (event is RoomSessionStateChangedEvent && event.roomId == roomId) {
        state++;
      }
    });
    ref.onDispose(sub.cancel);
    return 0;
  }
  void refresh() => state++;
}
final _roomSessionRefreshProvider = NotifierProvider.family<_RoomSessionRefreshNotifier, int, String>(_RoomSessionRefreshNotifier.new);

class RoomController extends AutoDisposeFamilyNotifier<RoomState, String> {
  RoomSessionService get _sessionService => _cachedSessionService!;
  HostControls get _hostControls => _cachedHostControls!;
  MicAccessController get _micAccess => _cachedMicAccess!;
  RoomRepository get _roomRepository => _cachedRoomRepository!;
  RoomPolicyController get _roomPolicy => _cachedRoomPolicy!;
  UserCamPermissionsController get _camPermissions => _cachedCamPermissions!;
  FirebaseFirestore get _firestore => _cachedFirestore!;
  _RoomSessionState get _session => _cachedSession!;

  RoomSessionService? _cachedSessionService;
  HostControls? _cachedHostControls;
  MicAccessController? _cachedMicAccess;
  RoomRepository? _cachedRoomRepository;
  RoomPolicyController? _cachedRoomPolicy;
  UserCamPermissionsController? _cachedCamPermissions;
  _RoomSessionState? _cachedSession;
  FirebaseFirestore? _cachedFirestore;

  static final Map<String, Timer> _joinStabilizationTimers = <String, Timer>{};
  static final Map<String, int> _userStabilizationEpochs = <String, int>{};

  Timer? _roomHeartbeatTimer;
  Timer? _graceWindowTimer;
  DateTime? _lastParticipantSyncAt;
  KeepAliveLink? _keepAliveLink;
  bool _isInGraceWindow = false;

  static final Map<String, String> _activeSessionByRoomUser =
      <String, String>{};

  bool _isDisposed = false;

  // Values from the Room State Contract (docs/ROOM_STATE_CONTRACT.md §5, §8).
  static const Duration _kPendingRoleTtl = kRoomPendingRoleTtl;

  static const Duration _kRoomHeartbeatInterval = Duration(seconds: 20);
  static const Duration _kLeaveGraceWindow = Duration(seconds: 2);

  String _roomUserKey({required String roomId, required String userId}) {
    return '${roomId.trim()}::${userId.trim()}';
  }

  String _newSessionId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
  }

  String _registerOwnership({required String roomId, required String userId}) {
    final sessionId = _newSessionId();
    _activeSessionByRoomUser[_roomUserKey(roomId: roomId, userId: userId)] =
        sessionId;
    _session.activeSessionId = sessionId;
    return sessionId;
  }

  bool _isSessionOwner({
    required String roomId,
    required String userId,
    required String? sessionId,
  }) {
    if (sessionId == null || sessionId.trim().isEmpty) {
      return false;
    }
    final current =
        _activeSessionByRoomUser[_roomUserKey(roomId: roomId, userId: userId)];
    return current == sessionId;
  }

  void _releaseOwnership({
    required String roomId,
    required String userId,
    required String? sessionId,
  }) {
    final key = _roomUserKey(roomId: roomId, userId: userId);
    final current = _activeSessionByRoomUser[key];
    if (current == null || current != sessionId) {
      return;
    }
    _activeSessionByRoomUser.remove(key);
    if (_session.activeSessionId == sessionId) {
      _session.activeSessionId = null;
    }
  }

  void _startLeaveGraceWindow() {
    _isInGraceWindow = true;
    _graceWindowTimer?.cancel();
    _graceWindowTimer = Timer(_kLeaveGraceWindow, () {
      _isInGraceWindow = false;
    });
  }

  void _resetLocalSessionState() {
    final s = _session;
    s.phase = LiveRoomPhase.idle;
    s.currentUserId = null;
    s.joinedAt = null;
    s.errormessage = null;
    s.excludedUserIds = const <String>{};
    s.micRequested = false;
    s.hasMicPermission = true;
    s.pendingUserIds.clear();
    s.stableUserIds.clear();
    s.sessionSnapshotsByUser.clear();
    s.lastActiveAtByUser.clear();
    s.pendingRoleByUser.clear();
    s.pendingRoleSetAtByUser.clear();
    s.lifecycleState = RoomLifecycleState.ended;
    state = const RoomState(lifecycleState: RoomLifecycleState.ended);
    _keepAliveLink?.close();
    _keepAliveLink = null;

    // HARDENING FIX #1: Clear participant cache on session end.
    // Defer to microtask to avoid Riverpod assertion errors if leaveRoom
    // was triggered during a dependency change.
    final roomId = arg;
    Future.microtask(() {
      if (!_isDisposed) {
        ref.read(selfParticipantCacheProvider(roomId).notifier).clear();
      }
    });
    _notifySessionChanged();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REACTIVE SNAPSHOT  (build)
  // RULE: build() is a pure projection of stream inputs + mutable state onto
  //       RoomState. It must NOT mutate any field or call async operations.
  //       All field mutations happen in async methods that call _emitState().
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  RoomState build(String roomId) {
    // Watch the refresh provider to ensure we rebuild when session state changes.
    ref.watch(_roomSessionRefreshProvider(roomId));

    // Cache services while ref is valid so they can be used in async methods
    // and ref.onDispose without triggering !_didChangeDependency.
    _cachedSessionService = ref.read(roomSessionServiceProvider);
    _cachedHostControls = ref.read(hostControlsProvider);
    _cachedMicAccess = ref.read(micAccessControllerProvider);
    _cachedRoomRepository = ref.read(roomRepositoryProvider);
    _cachedRoomPolicy = ref.read(roomPolicyControllerProvider);
    _cachedCamPermissions = ref.read(userCamPermissionsControllerProvider);
    _cachedSession = ref.read(_roomSessionStateProvider(roomId));
    _cachedFirestore = ref.read(roomFirestoreProvider);

    ref.onDispose(() {
      _isDisposed = true;
      // Sprint 3 A-2 Fix: Explicit timer cleanup to prevent zombie Firestore writes
      // Cancel heartbeat first to prevent further writes, then grace window
      _roomHeartbeatTimer?.cancel();
      _roomHeartbeatTimer = null;
      _graceWindowTimer?.cancel();
      _graceWindowTimer = null;
      _lastParticipantSyncAt = null;
      // Explicitly release room ownership to signal clean session end.
      //
      // Guard: skip release while a join is actively in-flight (phase ==
      // joining). Riverpod may invalidate/recreate this Notifier mid-join
      // when the join's own Firestore writes trigger a watched stream
      // update ("dependency churn... common on Web and during joins", see
      // _RoomSessionState doc comment). If we release ownership here, the
      // in-flight joinRoom()'s post-transaction _isSessionOwner check will
      // always fail, permanently stranding _session.phase at `joining`
      // even though the join actually succeeded.
      if (_session.phase != LiveRoomPhase.joining &&
          _session.activeSessionId != null) {
        _releaseOwnership(
          roomId: arg,
          userId: _session.currentUserId ?? '',
          sessionId: _session.activeSessionId,
        );
      }
    });

    // Watch lifecycle to pause heartbeats when backgrounded.
    final lifecycle = ref.watch(appLifecycleProvider);
    if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.inactive) {
      _stopRoomHeartbeat();
    } else if (lifecycle == AppLifecycleState.resumed && _session.phase == LiveRoomPhase.joined) {
      _startRoomHeartbeat();
    }

    final roomDoc = ref.watch(roomDocStreamProvider(roomId)).valueOrNull;
    final participants =
        ref.watch(participantsStreamProvider(roomId)).valueOrNull ??
        const <RoomParticipantModel>[];
    final memberUserIds =
        ref.watch(roomMemberUserIdsProvider(roomId)).valueOrNull ??
        const <String>[];
    final speakerUserIds =
        ref.watch(roomSpeakerUserIdsProvider(roomId)).valueOrNull ??
        const <String>[];

    // HARDENING: Ensure the current user's stabilization window is active if needed.
    final currentId = _session.currentUserId?.trim() ?? '';
    if (currentId.isNotEmpty && _session.pendingUserIds.contains(currentId)) {
      if (!_joinStabilizationTimers.containsKey(_roomUserKey(roomId: roomId, userId: currentId))) {
        Future.microtask(() {
          if (!_isDisposed && _session.pendingUserIds.contains(currentId)) {
            _scheduleStabilization(currentId);
          }
        });
      }
    }

    final hostId = _resolveHostId(roomDoc, participants);
    final userIds = _resolveUserIds(participants, memberUserIds: memberUserIds);
    final speakerIds = _resolveSpeakerIds(
      participants,
      hostId: hostId,
      speakerUserIds: speakerUserIds,
      useSpeakerDocs: _shouldUseSpeakerDocs(roomDoc),
    );
    final camViewersByUser = _resolveCamViewers(userIds);
    final participantRolesByUser = _resolveParticipantRoles(
      participants,
      hostId: hostId,
    );
    final sessionSnapshotsByUser = _resolveSessionSnapshots(
      participants,
      hostId: hostId,
    );
    final hostConflict = _hasHostConflict(
      hostId,
      participantRolesByUser,
      sessionSnapshotsByUser,
    );

    final mergedUserIds = <String>{...userIds};
    final normalizedCurrentUserId = _session.currentUserId?.trim() ?? '';
    if (normalizedCurrentUserId.isNotEmpty) {
      mergedUserIds.add(normalizedCurrentUserId);
    }

    final nextState = RoomState(
      phase: _session.phase,
      lifecycleState: _session.lifecycleState,
      roomId: roomId,
      currentUserId: _session.currentUserId,
      errormessage: _session.errormessage,
      joinedAt: _session.joinedAt,
      excludedUserIds: _session.excludedUserIds,
      hostId: hostId,
      userIds: mergedUserIds.toList(growable: false),
      stableUserIds: _resolveStableUserIds(
        mergedUserIds.toList(growable: false),
      ),
      pendingUserIds: Set<String>.unmodifiable(_session.pendingUserIds),
      speakerIds: speakerIds,
      camViewersByUser: camViewersByUser,
      participantRolesByUser: participantRolesByUser,
      sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
        sessionSnapshotsByUser,
      ),
      micRequested: _session.micRequested,
      hasMicPermission: _session.hasMicPermission,
      spotlightUserId: roomDoc?['spotlightUserId'] as String?,
    );

    // Compute lifecycle state as a pure local — no side effects in build().
    final resolvedLifecycleState = RoomStateMachine.resolveLifecycleState(
      roomId: roomId,
      phase: nextState.phase,
      isHydrated: nextState.isRoomFullyHydrated,
      currentUserId: nextState.currentUserId,
      errormessage: nextState.errormessage,
    );

    final currentUserId = nextState.currentUserId?.trim() ?? '';
    final resolvedRole = currentUserId.isEmpty
        ? roomRoleAudience
        : nextState.roleFor(currentUserId);
    final normalizedRole = normalizeRoomRole(
      resolvedRole,
      fallbackRole: roomRoleAudience,
    );
    final hasSpeakerSeat =
        currentUserId.isNotEmpty &&
        (nextState.isSpeaker(currentUserId) || normalizedRole == roomRoleStage);
    final resolvedAudioState = RoomStateMachine.resolveAudioState(
      roomState: resolvedLifecycleState,
      isHost: isHostLikeRole(normalizedRole),
      isCohost: normalizedRole == roomRoleCohost,
      micRequested: _session.micRequested,
      hasMicPermission: _session.hasMicPermission,
      hasSpeakerSeat: hasSpeakerSeat,
    );
    final hostMissing = _isHostMissing(
      phase: nextState.phase,
      hostId: hostId,
      userIds: mergedUserIds,
    );

    AppTelemetry.updateRoomState(
      roomId: arg,
      joinedUserId: _session.currentUserId,
      roomPhase: nextState.phase.name,
      roomError: nextState.errormessage,
      participantCount: mergedUserIds.length,
      hostConflict: hostConflict,
      hostMissing: hostMissing,
    );

    return _selfHeal(
      nextState.copyWith(
        lifecycleState: resolvedLifecycleState,
        audioState: resolvedAudioState,
        micRequested: _session.micRequested,
        hasMicPermission: _session.hasMicPermission,
        hasSpeakerSeat: hasSpeakerSeat,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESOLUTION LAYER  — stale filter + role/speaker projection
  // RULE: These helpers may read _lastActiveAtByUser and _pendingRoleByUser.
  //       Their only allowed side effects are:
  //         • updating _lastActiveAtByUser[userId] (high-water mark advance)
  //         • removing a confirmed entry from _pendingRoleByUser
  //       They must not call async operations or read other mutable fields.
  // ═══════════════════════════════════════════════════════════════════════════

  @protected
  String _resolveHostId(
    Map<String, dynamic>? roomDoc,
    List<RoomParticipantModel> participants,
  ) {
    return RoomStateMachine.resolveHostId(
      roomDoc: roomDoc,
      participants: participants,
    );
  }

  @protected
  List<String> _resolveUserIds(
    List<RoomParticipantModel> participants, {
    List<String> memberUserIds = const <String>[],
  }) {
    return <String>{
      ...memberUserIds.map((userId) => userId.trim()),
      ...participants.map((participant) => participant.userId.trim()),
    }.where((userId) => userId.isNotEmpty).toList(growable: false);
  }

  @protected
  bool _shouldUseSpeakerDocs(Map<String, dynamic>? roomDoc) {
    final rawVersion = roomDoc?['speakerSyncVersion'];
    final rawMaxSpeakers = roomDoc?['maxSpeakers'];
    return rawVersion is num || rawMaxSpeakers is num;
  }

  @protected
  List<String> _resolveSpeakerIds(
    List<RoomParticipantModel> participants, {
    required String hostId,
    List<String> speakerUserIds = const <String>[],
    required bool useSpeakerDocs,
  }) {
    if (useSpeakerDocs) {
      final participantsByUser = {
        for (final participant in participants)
          participant.userId.trim(): participant,
      };
      final resolvedUserIds =
          speakerUserIds
              .map((userId) => userId.trim())
              .where((userId) => userId.isNotEmpty)
              .toSet()
              .toList(growable: false)
            ..sort((left, right) {
              final leftParticipant = participantsByUser[left];
              final rightParticipant = participantsByUser[right];
              final leftRank = _speakerRank(
                leftParticipant ??
                    RoomParticipantModel(
                      userId: left,
                      role: left == hostId ? 'host' : 'stage',
                      joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
                      lastActiveAt: DateTime.fromMillisecondsSinceEpoch(0),
                    ),
                hostId: hostId,
              );
              final rightRank = _speakerRank(
                rightParticipant ??
                    RoomParticipantModel(
                      userId: right,
                      role: right == hostId ? 'host' : 'stage',
                      joinedAt: DateTime.fromMillisecondsSinceEpoch(0),
                      lastActiveAt: DateTime.fromMillisecondsSinceEpoch(0),
                    ),
                hostId: hostId,
              );
              if (leftRank != rightRank) {
                return leftRank.compareTo(rightRank);
              }
              final leftJoinedAt =
                  leftParticipant?.joinedAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final rightJoinedAt =
                  rightParticipant?.joinedAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return leftJoinedAt.compareTo(rightJoinedAt);
            });
      return resolvedUserIds
          .take(RoomState.maxSpeakers)
          .toList(growable: false);
    }

    final speakers =
        participants.where(_isSpeakerParticipant).toList(growable: false)
          ..sort((left, right) {
            final leftRank = _speakerRank(left, hostId: hostId);
            final rightRank = _speakerRank(right, hostId: hostId);
            if (leftRank != rightRank) {
              return leftRank.compareTo(rightRank);
            }
            return left.joinedAt.compareTo(right.joinedAt);
          });

    return speakers
        .map((participant) => participant.userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .take(RoomState.maxSpeakers)
        .toList(growable: false);
  }

  @protected
  bool _isSpeakerParticipant(RoomParticipantModel participant) {
    if (participant.userId.trim().isEmpty || participant.isBanned) {
      return false;
    }

    final normalizedRole = normalizeRoomRole(
      participant.role,
      fallbackRole: '',
    );
    final stageRole =
        canManageStageRole(normalizedRole) ||
        normalizedRole == roomRoleStage ||
        normalizedRole == roomRoleTrustedSpeaker;

    // Transient micOn flags from network lag must NOT promote audience members
    // to the speaker list. Only authoritative role grants speaker status on
    // the legacy (non-speakerDocs) path.
    return stageRole;
  }

  @protected
  int _speakerRank(RoomParticipantModel participant, {required String hostId}) {
    final normalizedRole = normalizeRoomRole(
      participant.role,
      fallbackRole: '',
    );
    if (participant.userId == hostId || isHostLikeRole(normalizedRole)) {
      return 0;
    }
    if (normalizedRole == roomRoleCohost) {
      return 1;
    }
    if (normalizedRole == roomRoleTrustedSpeaker) {
      return 2;
    }
    if (normalizedRole == roomRoleStage) {
      return 3;
    }
    return 4;
  }

  @protected
  Map<String, List<String>> _resolveCamViewers(List<String> userIds) {
    final result = <String, List<String>>{};
    for (final userId in userIds) {
      result[userId] =
          (ref.watch(userCamAllowedViewersProvider(userId)).valueOrNull ??
                  const <String>[])
              .map((viewerId) => viewerId.trim())
              .where((viewerId) => viewerId.isNotEmpty)
              .toSet()
              .toList(growable: false);
    }
    return result;
  }

  @protected
  Map<String, String> _resolveParticipantRoles(
    List<RoomParticipantModel> participants, {
    required String hostId,
  }) {
    final result = <String, String>{};
    for (final participant in participants) {
      final userId = participant.userId.trim();
      if (userId.isEmpty) {
        continue;
      }

      // Stale-event guard: if this doc is older than what we already accepted,
      // carry forward the role we already know rather than regressing.
      final incomingAt = participant.lastActiveAt;
      final knownAt = _session.lastActiveAtByUser[userId];
      if (knownAt != null && incomingAt.isBefore(knownAt)) {
        // Stale — preserve existing resolution.
        final existing = state.participantRolesByUser[userId];
        if (existing != null) {
          result[userId] = existing;
          continue;
        }
      }
      // Accept this doc's timestamp as the new high-water mark.
      if (knownAt == null || incomingAt.isAfter(knownAt)) {
        _session.lastActiveAtByUser[userId] = incomingAt;
      }

      // Pending-role precedence: an in-session promote/demote written to
      // Firestore has not yet been reflected in the incoming stream doc.
      // Keep the pending role until a fresh doc confirms the write, or until
      // _kPendingRoleTtl elapses (write likely failed silently).
      final pendingRole = _session.pendingRoleByUser[userId];
      if (pendingRole != null) {
        final setAt = _session.pendingRoleSetAtByUser[userId];
        final isExpired =
            setAt != null &&
            DateTime.now().difference(setAt) > _kPendingRoleTtl;
        if (isExpired) {
          // Firestore never confirmed the write — let the server doc win.
          _session.pendingRoleByUser.remove(userId);
          _session.pendingRoleSetAtByUser.remove(userId);
          AppTelemetry.logAction(
            level: 'warning',
            domain: 'room',
            action: 'pending_role_expired',
            message:
                'Pending role "$pendingRole" for user $userId expired '
                'without Firestore confirmation.',
            roomId: arg,
            metadata: <String, Object?>{
              'userId': userId,
              'expiredRole': pendingRole,
            },
          );
          // Fall through — Firestore doc determines the role below.
        } else {
          final normalizedIncoming = normalizeRoomRole(
            participant.role,
            fallbackRole: '',
          );
          // Once Firestore echoes back the same role we wrote, clear pending.
          if (normalizedIncoming == pendingRole) {
            _session.pendingRoleByUser.remove(userId);
            _session.pendingRoleSetAtByUser.remove(userId);
          }
          result[userId] = pendingRole;
          continue;
        }
      }

      final normalizedRole = participant.role.trim().toLowerCase();
      result[userId] = normalizedRole.isEmpty ? 'audience' : normalizedRole;
    }
    if (hostId.trim().isNotEmpty) {
      result.putIfAbsent(hostId.trim(), () => 'host');
    }
    return result;
  }

  bool _hasHostConflict(
    String hostId,
    Map<String, String> participantRolesByUser,
    Map<String, RoomSessionSnapshot> sessionSnapshotsByUser,
  ) {
    final normalizedHostId = hostId.trim();
    final hostLikeIds = <String>{
      if (normalizedHostId.isNotEmpty) normalizedHostId,
      for (final entry in participantRolesByUser.entries)
        if (isHostLikeRole(entry.value) && entry.key.trim().isNotEmpty)
          entry.key.trim(),
      for (final snapshot in sessionSnapshotsByUser.values)
        if (isHostLikeRole(snapshot.role) && snapshot.userId.trim().isNotEmpty)
          snapshot.userId.trim(),
    };

    if (normalizedHostId.isEmpty) {
      return hostLikeIds.length > 1;
    }

    return hostLikeIds.any((userId) => userId != normalizedHostId);
  }

  bool _isHostMissing({
    required LiveRoomPhase phase,
    required String hostId,
    required Iterable<String> userIds,
  }) {
    return phase == LiveRoomPhase.joined &&
        hostId.trim().isEmpty &&
        userIds.any((userId) => userId.trim().isNotEmpty);
  }

  bool _isPlaceholderDisplayName(String value) {
    final normalized = value.trim();
    final generatedHandlePattern = RegExp(
      r'^(User|Guest|Member) [A-Z0-9]{1,4}$',
    );
    final opaqueIdPattern = RegExp(r'^[A-Za-z0-9_-]{20,}$');
    return normalized.isEmpty ||
        normalized == 'MixVy User' ||
        normalized == 'MixVy Member' ||
        generatedHandlePattern.hasMatch(normalized) ||
        opaqueIdPattern.hasMatch(normalized);
  }

  String _safeRoomDisplayName(String userId) {
    final compact = userId
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (compact.isEmpty) {
      return 'MixVy Member';
    }
    final suffix = compact.substring(
      0,
      compact.length < 4 ? compact.length : 4,
    );
    return 'Member $suffix';
  }

  @protected
  Map<String, RoomSessionSnapshot> _resolveSessionSnapshots(
    List<RoomParticipantModel> participants, {
    required String hostId,
  }) {
    final result = <String, RoomSessionSnapshot>{..._session.sessionSnapshotsByUser};

    for (final participant in participants) {
      final userId = participant.userId.trim();
      if (userId.isEmpty) {
        continue;
      }

      // Stale-event guard: do not regress a snapshot we already accepted from
      // a fresher document. Use the same high-water mark maintained by
      // _resolveParticipantRoles (which runs first in build()).
      final incomingAt = participant.lastActiveAt;
      final knownAt = _session.lastActiveAtByUser[userId];
      if (knownAt != null && incomingAt.isBefore(knownAt)) {
        // Stale — keep the existing snapshot unchanged.
        continue;
      }

      final existing = result[userId];
      final existingName = existing?.displayName.trim() ?? '';

      // Determine the effective role, respecting any pending in-session write.
      final pendingRole = _session.pendingRoleByUser[userId];
      final firestoreRole = participant.role.trim().isEmpty
          ? (userId == hostId ? 'host' : 'audience')
          : participant.role.trim().toLowerCase();
      final effectiveRole = pendingRole ?? firestoreRole;

      result[userId] = RoomSessionSnapshot(
        userId: userId,
        displayName: existingName.isNotEmpty
            ? existingName
            : _safeRoomDisplayName(userId),
        role: effectiveRole,
        joinedAt: existing?.joinedAt ?? participant.joinedAt,
      );
    }

    final currentUserId = _session.currentUserId?.trim() ?? '';
    if (currentUserId.isNotEmpty) {
      result.putIfAbsent(
        currentUserId,
        () => RoomSessionSnapshot(
          userId: currentUserId,
          displayName: _safeRoomDisplayName(currentUserId),
          role: currentUserId == hostId ? 'host' : 'audience',
          joinedAt: _session.joinedAt,
        ),
      );
    }

    _session.sessionSnapshotsByUser
      ..clear()
      ..addAll(result);
    return result;
  }

  @protected
  List<String> _resolveStableUserIds(List<String> userIds) {
    // Hard filter: a user is only stable if they are in the active roster 
    // (or manually stabilized) AND NOT in the pending stabilization window.
    final candidates = <String>{...userIds, ..._session.stableUserIds};
    return candidates
        .where((id) => !_session.pendingUserIds.contains(id.trim()))
        .toList(growable: false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SELF-HEALING LAYER
  // Runs after state computation in both build() and _emitState() paths.
  // Applies surgical repairs for external inconsistencies caused by Firestore
  // doc arrival timing (not programming bugs — those are caught by assertions).
  // RULE: Log every repair. If healing frequency spikes, it is a signal of an
  //       upstream bug — investigate rather than tuning the heal thresholds.
  // ═══════════════════════════════════════════════════════════════════════════

  @protected
  RoomState _selfHeal(RoomState candidate) {
    RoomState healed = candidate;

    // Repair 1 — Ghost speaker removal.
    // Cause: speaker-doc arrives at this client before the participant-doc.
    // The speaker appears in speakerIds but not yet in userIds, so the UI
    // would render an empty slot. We prune until the participant arrives.
    final ghostSpeakers = healed.speakerIds
        .where(
          (id) =>
              !healed.userIds.contains(id) && id.trim() != healed.hostId.trim(),
        )
        .toList(growable: false);
    if (ghostSpeakers.isNotEmpty) {
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'room',
        action: 'self_heal_ghost_speakers',
        message:
            'Pruned ${ghostSpeakers.length} ghost speaker(s) from speakerIds '
            'pending participant-doc arrival.',
        roomId: arg,
        metadata: <String, Object?>{'removed': ghostSpeakers.join(',')},
      );
      healed = healed.copyWith(
        speakerIds: healed.speakerIds
            .where((id) => !ghostSpeakers.contains(id))
            .toList(growable: false),
      );
    }

    // Repair 2 — Host-role alignment.
    // Cause: Firestore hostId field and role field are separate documents;
    // a race can produce hostId = "X" while participantRolesByUser["X"] = "audience".
    final hostId = healed.hostId.trim();
    if (hostId.isNotEmpty) {
      final existingRole = healed.participantRolesByUser[hostId];
      if (existingRole != null && !isHostLikeRole(existingRole)) {
        AppTelemetry.logAction(
          level: 'warning',
          domain: 'room',
          action: 'self_heal_host_role',
          message:
              'Corrected participantRolesByUser["$hostId"] from '
              '"$existingRole" to "host".',
          roomId: arg,
          metadata: <String, Object?>{'userId': hostId, 'was': existingRole},
        );
        healed = healed.copyWith(
          participantRolesByUser: <String, String>{
            ...healed.participantRolesByUser,
            hostId: 'host',
          },
        );
      }
    }

    return healed;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE EMISSION
  // RULE: All async paths that change controller state must route through
  //       _emitState(). Never write `state = ...` directly outside this method.
  //       _emitState() owns the equality guard that prevents rebuild storms.
  // ═══════════════════════════════════════════════════════════════════════════

  @protected
  void _emitState(RoomState nextState) {
    // HARDENING: Final sanity check on roster disjointness.
    // Ensure no pending user leaked into the stable list during projection.
    final reconciledStable = nextState.stableUserIds
        .where((id) => !nextState.pendingUserIds.contains(id.trim()))
        .toList(growable: false);

    final validatedState = reconciledStable.length == nextState.stableUserIds.length
        ? nextState
        : nextState.copyWith(stableUserIds: reconciledStable);

    // Self-healing runs first so that assertions check post-repair state.
    // If an invariant still fires after healing, it is a programming bug.
    final healed = _selfHeal(validatedState);
    // ── Hard invariants (docs/ROOM_STATE_CONTRACT.md §6) ─────────────────────
    assert(RoomStateContract.assertValid(healed), '');

    final resolvedLifecycle = resolveRoomLifecycleState(
      roomId: healed.roomId,
      phase: healed.phase,
      isHydrated: healed.isRoomFullyHydrated,
      currentUserId: healed.currentUserId,
      errormessage: healed.errormessage,
    );
    _session.lifecycleState = resolvedLifecycle;
    final candidate = healed.copyWith(lifecycleState: resolvedLifecycle);
    // Avoid triggering downstream rebuilds when nothing meaningful changed.
    if (candidate.phase == state.phase &&
        candidate.lifecycleState == state.lifecycleState &&
        candidate.currentUserId == state.currentUserId &&
        candidate.errormessage == state.errormessage &&
        candidate.hostId == state.hostId &&
        listEquals(candidate.speakerIds, state.speakerIds) &&
        listEquals(candidate.userIds, state.userIds) &&
        listEquals(candidate.stableUserIds, state.stableUserIds) &&
        setEquals(candidate.pendingUserIds, state.pendingUserIds) &&
        candidate.audioState == state.audioState &&
        candidate.micRequested == state.micRequested &&
        candidate.hasMicPermission == state.hasMicPermission &&
        candidate.hasSpeakerSeat == state.hasSpeakerSeat) {
      return;
    }
    state = candidate;
  }

  @protected
  void _publishSessionState() {
    _notifySessionChanged();
    _emitState(
      state.copyWith(
        pendingUserIds: Set<String>.unmodifiable(_session.pendingUserIds),
        stableUserIds: _resolveStableUserIds(state.userIds),
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _session.sessionSnapshotsByUser,
        ),
      ),
    );
  }

  @protected
  void _notifySessionChanged() {
    if (_isDisposed) {
       // If the instance is disposed, we can't use 'ref', 
       // but we still want to notify other instances of the same roomId.
       AppEventBus.instance.emit(RoomSessionStateChangedEvent(
          id: 'refresh-$arg-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          roomId: arg,
       ));
       return;
    }
    
    // If not disposed, we can also manually trigger the rebuild via the provider.
    ref.read(_roomSessionRefreshProvider(arg).notifier).refresh();
    
    // Also emit the event to sync other instances (e.g. in multi-instance scenarios).
    AppEventBus.instance.emit(RoomSessionStateChangedEvent(
      id: 'refresh-$arg-${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      roomId: arg,
    ));
  }

  @protected
  void _scheduleStabilization(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    final userKey = _roomUserKey(roomId: arg, userId: normalizedUserId);

    // Increment epoch to invalidate any previous timers for this user.
    final epoch = (_userStabilizationEpochs[userKey] ?? 0) + 1;
    _userStabilizationEpochs[userKey] = epoch;

    _session.pendingUserIds.add(normalizedUserId);
    _session.stableUserIds.remove(normalizedUserId);
    _publishSessionState();

    _joinStabilizationTimers[userKey]?.cancel();
    _joinStabilizationTimers[userKey] = Timer(
      kRoomJoinStabilizationDelay,
      () {
        // Note: we check epoch to ensure we only process the LATEST timer for this user.
        if (_userStabilizationEpochs[userKey] != epoch) {
          return;
        }
        
        _joinStabilizationTimers.remove(userKey);
        _userStabilizationEpochs.remove(userKey);
        _session.pendingUserIds.remove(normalizedUserId);
        _session.stableUserIds.add(normalizedUserId);
        
        _notifySessionChanged();
      },
    );
  }

  void _startRoomHeartbeat() {
    _roomHeartbeatTimer?.cancel();
    if ((_session.currentUserId?.trim().isEmpty ?? true) ||
        _session.phase != LiveRoomPhase.joined) {
      return;
    }

    _roomHeartbeatTimer = Timer.periodic(_kRoomHeartbeatInterval, (_) {
      if (_isDisposed) return;
      unawaited(_sendRoomHeartbeat());
    });
  }

  Future<void> syncPresenceNow({bool forceSync = true}) async {
    await _sendRoomHeartbeat(forceSync: forceSync);
  }

  void _stopRoomHeartbeat() {
    _roomHeartbeatTimer?.cancel();
    _roomHeartbeatTimer = null;
    _lastParticipantSyncAt = null;
  }

  @protected
  Future<void> _sendRoomHeartbeat({bool forceSync = false}) async {
    final userId = _session.currentUserId?.trim() ?? '';
    if (userId.isEmpty || _session.phase != LiveRoomPhase.joined) {
      return;
    }

    if (_isInGraceWindow) {
      return;
    }

    final sessionId = _session.activeSessionId;
    if (sessionId != null &&
        !_isSessionOwner(roomId: arg, userId: userId, sessionId: sessionId)) {
      return;
    }

    try {
      _lastParticipantSyncAt = await _sessionService.heartbeat(
        roomId: arg,
        userId: userId,
        lastParticipantSyncAt: _lastParticipantSyncAt,
        forceParticipantSync: forceSync,
      );
      if ((_session.errormessage?.trim().isNotEmpty ?? false)) {
        _session.errormessage = null;
        _emitState(state.copyWith(errormessage: null));
      }
    } catch (error) {
      final info = parseFirestoreError(error);
      if (_isInGraceWindow || info.code.toLowerCase() == 'not-found') {
        return;
      }
      _session.errormessage = 'Room state is reconnecting. Try again in a moment.';
      _emitState(state.copyWith(errormessage: _session.errormessage));
    }
  }

  void hydrateCurrentUser(String userId, {String? displayName, String? role}) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    _session.currentUserId = normalizedUserId;
    final existing = _session.sessionSnapshotsByUser[normalizedUserId];
    final resolvedRole = role?.trim().toLowerCase();
    _session.sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
      userId: normalizedUserId,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : (existing?.displayName ?? normalizedUserId),
      role: (resolvedRole != null && resolvedRole.isNotEmpty)
          ? resolvedRole
          : resolveParticipantRole(
              userId: normalizedUserId,
              hostId: state.hostId,
              participantRolesByUser: state.participantRolesByUser,
              sessionSnapshotsByUser: _session.sessionSnapshotsByUser,
            ),
      joinedAt: existing?.joinedAt ?? _session.joinedAt,
    );
    _emitState(
      state.copyWith(
        currentUserId: normalizedUserId,
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _session.sessionSnapshotsByUser,
        ),
        stableUserIds: _resolveStableUserIds(state.userIds),
      ),
    );
  }

  void cacheDisplayName({
    required String userId,
    required String displayName,
    String? role,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedDisplayName = displayName.trim();
    if (normalizedUserId.isEmpty || normalizedDisplayName.isEmpty) {
      return;
    }

    final existing = _session.sessionSnapshotsByUser[normalizedUserId];
    final shouldUpdate =
        existing == null || _isPlaceholderDisplayName(existing.displayName);
    if (!shouldUpdate) {
      return;
    }

    _session.sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
      userId: normalizedUserId,
      displayName: normalizedDisplayName,
      role: role?.trim().isNotEmpty == true
          ? role!.trim().toLowerCase()
          : resolveParticipantRole(
              userId: normalizedUserId,
              hostId: state.hostId,
              participantRolesByUser: state.participantRolesByUser,
              sessionSnapshotsByUser: _session.sessionSnapshotsByUser,
            ),
      joinedAt: existing?.joinedAt ?? _session.joinedAt,
    );

    final normalizedCurrentUserId = _session.currentUserId?.trim() ?? '';
    final canAffectRosterVisibility =
        normalizedUserId == normalizedCurrentUserId ||
        state.userIds.contains(normalizedUserId);
    if (canAffectRosterVisibility) {
      _session.stableUserIds.add(normalizedUserId);
      _session.pendingUserIds.remove(normalizedUserId);
    }
    _publishSessionState();
  }

  void updateAudioContext({
    required bool micRequested,
    required bool hasMicPermission,
  }) {
    final nextMicRequested = hasMicPermission ? micRequested : false;
    if (_session.micRequested == nextMicRequested &&
        _session.hasMicPermission == hasMicPermission) {
      return;
    }
    _session.micRequested = nextMicRequested;
    _session.hasMicPermission = hasMicPermission;
    _notifySessionChanged();
    _emitState(
      state.copyWith(
        micRequested: _session.micRequested,
        hasMicPermission: _session.hasMicPermission,
      ),
    );
  }

  String get _actorUserId => _session.currentUserId?.trim() ?? '';

  void _logModerationAction(
    String action, {
    String? targetUserId,
    String result = 'success',
  }) {
    AppTelemetry.logAction(
      domain: 'moderation',
      action: action,
      message: 'Room moderation action applied.',
      roomId: arg,
      userId: _actorUserId,
      result: result,
      metadata: <String, Object?>{
        if (targetUserId != null && targetUserId.isNotEmpty)
          'targetUserId': targetUserId,
      },
    );
  }

  @protected
  void _requireActiveLifecycle() {
    final lifecycleState = state.lifecycleState;
    final isReadyForMutation =
        lifecycleState == RoomLifecycleState.active ||
        (state.phase == LiveRoomPhase.joined &&
            lifecycleState != RoomLifecycleState.ended);
    if (!isReadyForMutation) {
      throw StateError('Room state is still syncing. Try again in a moment.');
    }
  }

  @protected
  Future<String> _refreshActorRole(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return roomRoleAudience;
    }

    final firestore = _firestore;
    final roomSnapshot = await firestore.collection('rooms').doc(arg).get();
    final participantSnapshot = await firestore
        .collection('rooms')
        .doc(arg)
        .collection('participants')
        .doc(normalizedUserId)
        .get();

    final authoritativeHostId = RoomStateMachine.resolveHostId(
      roomDoc: roomSnapshot.data(),
    );
    final participantRole = normalizeRoomRole(
      participantSnapshot.data()?['role'] as String?,
      fallbackRole: '',
    );

    final nextParticipantRoles = Map<String, String>.from(
      state.participantRolesByUser,
    );
    if (participantRole.isNotEmpty) {
      nextParticipantRoles[normalizedUserId] = participantRole;
    }

    if (authoritativeHostId != state.hostId || participantRole.isNotEmpty) {
      _notifySessionChanged();
      _emitState(
        state.copyWith(
          hostId: authoritativeHostId,
          participantRolesByUser: Map<String, String>.unmodifiable(
            nextParticipantRoles,
          ),
        ),
      );
    }

    return RoomStateMachine.resolveParticipantRole(
      userId: normalizedUserId,
      hostId: authoritativeHostId,
      participantRolesByUser: nextParticipantRoles,
      sessionSnapshotsByUser: _session.sessionSnapshotsByUser,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHORITY GUARDS  — host > cohost/moderator > stage > audience
  // RULE: Every public mutation method must call exactly one of these before
  //       writing to Firestore. No shortcuts. No bypasses.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _requireStageAuthority() async {
    final actorUserId = _actorUserId;
    _requireActiveLifecycle();
    final actorRole = await _refreshActorRole(actorUserId);
    if (!canManageStageRole(actorRole)) {
      throw StateError('Only room staff can manage the stage.');
    }
  }

  Future<void> _requireModerationAuthority() async {
    final actorUserId = _actorUserId;
    _requireActiveLifecycle();
    final actorRole = await _refreshActorRole(actorUserId);
    if (!canModerateRole(actorRole)) {
      throw StateError('Only room staff can manage participants.');
    }
  }

  Future<void> _requireHostAuthority() async {
    final actorUserId = _actorUserId;
    _requireActiveLifecycle();
    final actorRole = await _refreshActorRole(actorUserId);
    if (!isHostLikeRole(actorRole)) {
      throw StateError('Only the room host can perform this action.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSION LIFECYCLE  — joinRoom / leaveRoom
  // RULE: leaveRoom() is the ONLY place that clears _lastActiveAtByUser and
  //       _pendingRoleByUser. Clearing them elsewhere breaks session isolation.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<RoomJoinResult> joinRoom(
    String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    _keepAliveLink ??= ref.keepAlive();
    final normalizedUserId = userId.trim();
    var normalizedDisplayName = displayName?.trim() ?? '';
    
    // Identity Correction: If username is raw/anonymous, fetch actual profile before join
    if (_isPlaceholderDisplayName(normalizedDisplayName) && normalizedUserId.isNotEmpty) {
      try {
        final profile = await ref.read(roomRepositoryProvider).loadUserLookup([normalizedUserId]);
        final actualName = profile[normalizedUserId]?.profileUsername;
        if (actualName != null && actualName.isNotEmpty) {
          normalizedDisplayName = actualName;
          debugPrint('LOG: [Web] Corrected join username from $displayName to $normalizedDisplayName');
        }
      } catch (e) {
        debugPrint('LOG: [Web] Profile fetch failed during join: $e');
      }
    }

    // Guard: ignore redundant join if already joined/joining for this user
    if (_session.currentUserId == normalizedUserId && (_session.phase == LiveRoomPhase.joined || _session.phase == LiveRoomPhase.joining)) {
      return RoomJoinResult.success(
        joinedAt: _session.joinedAt ?? DateTime.now(),
        excludedUserIds: _session.excludedUserIds,
      );
    }

    // Kill switch check. During dependency churn, ref.read may assert that
    // this provider is outdated; in that brief window, treat rooms as enabled
    // and allow normal join gating to continue.
    var enableLiveRooms = true;
    try {
      enableLiveRooms = ref.read(featureGateControllerProvider).enableLiveRooms;
    } on AssertionError {
      enableLiveRooms = true;
    }
    if (!enableLiveRooms) {
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'control_plane',
        action: 'room_join_denied',
        message: 'Room join blocked by runtime gate.',
        roomId: arg,
        userId: normalizedUserId,
        result: 'blocked',
        metadata: <String, Object?>{'feature': 'live_rooms'},
      );
      return RoomJoinResult.failure(
        'Room creation and joining are currently paused for maintenance.',
      );
    }

    if (_session.phase == LiveRoomPhase.joining ||
        (state.isJoined && _session.currentUserId == normalizedUserId)) {
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'room',
        action: 'join_guard_triggered',
        message: 'Duplicate room join was ignored for the active session.',
        roomId: arg,
        userId: normalizedUserId,
        result: 'guarded',
      );
      return RoomJoinResult.success(
        joinedAt: _session.joinedAt ?? DateTime.now(),
        excludedUserIds: _session.excludedUserIds,
      );
    }

    final sessionId = _registerOwnership(roomId: arg, userId: normalizedUserId);
    _isInGraceWindow = false;

    _session.phase = LiveRoomPhase.joining;
    _session.currentUserId = normalizedUserId;
    _session.errormessage = null;
    _session.micRequested = false;
    _session.hasMicPermission = true;
    _session.sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
      userId: normalizedUserId,
      displayName: normalizedDisplayName.isNotEmpty
          ? normalizedDisplayName
          : (_session.sessionSnapshotsByUser[normalizedUserId]?.displayName ??
                _safeRoomDisplayName(normalizedUserId)),
      role: normalizeRoomRole(
        _session.sessionSnapshotsByUser[normalizedUserId]?.role,
        fallbackRole: roomRoleAudience,
      ),
      joinedAt: DateTime.now(),
    );
    _scheduleStabilization(normalizedUserId);
    _emitState(
      state.copyWith(
        phase: _session.phase,
        currentUserId: _session.currentUserId,
        errormessage: null,
        pendingUserIds: Set<String>.unmodifiable(_session.pendingUserIds),
        stableUserIds: _resolveStableUserIds(state.userIds),
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _session.sessionSnapshotsByUser,
        ),
      ),
    );

    final firestore = _firestore;
    final sessionService = _sessionService;

    RoomJoinResult result;
    try {
      // Hardening: Own the transaction at the controller level to ensure
      // atomic join sequence and roster integrity.
      result = await firestore.runTransaction((transaction) async {
        return await sessionService.joinRoom(
          roomId: arg,
          userId: normalizedUserId,
          displayName: normalizedDisplayName,
          photoUrl: avatarUrl,
          transaction: transaction,
        );
      });
    } catch (error) {
      debugPrint('DEBUG: Join transaction error: $error');
      final info = parseFirestoreError(error);
      final message = info.isPermissionOrAuth
          ? 'Room access is blocked by Firestore permissions right now.'
          : 'Could not join room. Please try again.';
      result = RoomJoinResult.failure(message);
    }

    if (!_isSessionOwner(
      roomId: arg,
      userId: normalizedUserId,
      sessionId: sessionId,
    )) {
      return RoomJoinResult.success(
        joinedAt: result.joinedAt ?? DateTime.now(),
        excludedUserIds: result.excludedUserIds,
      );
    }

    if (!result.isSuccess) {
      AppTelemetry.logAction(
        level: 'error',
        domain: 'room',
        action: 'join',
        message: result.errormessage ?? 'Room join failed.',
        roomId: arg,
        userId: normalizedUserId,
        result: 'failure',
      );
      _stopRoomHeartbeat();
      _session.phase = LiveRoomPhase.error;
      _session.currentUserId = null;
      _session.errormessage = result.errormessage;
      _session.joinedAt = null;
      _session.excludedUserIds = result.excludedUserIds;
      _session.micRequested = false;
      _session.hasMicPermission = true;
      _session.pendingUserIds.remove(normalizedUserId);
      _session.stableUserIds.remove(normalizedUserId);
      _session.sessionSnapshotsByUser.remove(normalizedUserId);
      _emitState(
        state.copyWith(
          phase: _session.phase,
          currentUserId: null,
          errormessage: _session.errormessage,
          joinedAt: null,
          excludedUserIds: _session.excludedUserIds,
          pendingUserIds: Set<String>.unmodifiable(_session.pendingUserIds),
          stableUserIds: _resolveStableUserIds(state.userIds),
          sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
            _session.sessionSnapshotsByUser,
          ),
        ),
      );
      _releaseOwnership(
        roomId: arg,
        userId: normalizedUserId,
        sessionId: sessionId,
      );
      return result;
    }

    _session.phase = LiveRoomPhase.joined;
    _session.joinedAt = result.joinedAt;
    _session.excludedUserIds = result.excludedUserIds;
    _startRoomHeartbeat();
    _session.errormessage = null;
    final existingSnapshot = _session.sessionSnapshotsByUser[normalizedUserId];
    _session.sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
      userId: normalizedUserId,
      displayName: normalizedDisplayName.isNotEmpty
          ? normalizedDisplayName
          : (existingSnapshot?.displayName ??
                _safeRoomDisplayName(normalizedUserId)),
      role: normalizeRoomRole(
        existingSnapshot?.role,
        fallbackRole: roomRoleAudience,
      ),
      joinedAt: _session.joinedAt,
    );

    // ═══════════════════════════════════════════════════════════════════════
    // HARDENING FIX #1: Immediately cache current participant to avoid
    // permission-denied errors during participantsStreamProvider lag.
    // ═══════════════════════════════════════════════════════════════════════
    // Fetch the current user's participant doc from Firestore immediately
    // and cache it. This prevents hydration lag from blocking chat/camera
    // permission checks when multiple users join simultaneously.
    try {
      final firestore = _firestore;
      final participantSnap = await firestore
          .collection('rooms')
          .doc(arg)
          .collection('participants')
          .doc(normalizedUserId)
          .get();

      if (participantSnap.exists && participantSnap.data() != null) {
        final participant = RoomParticipantModel.fromMap(participantSnap.data()!);
        // Cache it so permission checks can use it immediately.
        // Wrap in microtask to avoid "!_didChangeDependency" assertion if joinRoom
        // completes during a provider rebuild cycle.
        unawaited(Future.microtask(() {
          if (!_isDisposed) {
            ref
                .read(selfParticipantCacheProvider(arg).notifier)
                .cacheParticipant(participant);
          }
        }));
      }
    } catch (e) {
      // Non-critical: cache miss just means we fall back to the stream.
      // Log but continue; the stream will eventually deliver the data.
      AppTelemetry.logAction(
        level: 'debug',
        domain: 'room',
        action: 'cache_participant_miss',
        message: 'Failed to cache current participant during join (non-critical).',
        roomId: arg,
        userId: normalizedUserId,
        metadata: <String, Object?>{'error': e.toString()},
      );
    }

    _emitState(
      state.copyWith(
        phase: _session.phase,
        currentUserId: normalizedUserId,
        errormessage: null,
        joinedAt: _session.joinedAt,
        excludedUserIds: _session.excludedUserIds,
        pendingUserIds: Set<String>.unmodifiable(_session.pendingUserIds),
        stableUserIds: _resolveStableUserIds(state.userIds),
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _session.sessionSnapshotsByUser,
        ),
      ),
    );
    await syncPresenceNow(forceSync: true);
    AppEventBus.instance.emit(
      RoomJoinedEvent(
        id: 'room-joined:$arg:$normalizedUserId:${(_session.joinedAt ?? DateTime.now()).millisecondsSinceEpoch}',
        timestamp: _session.joinedAt ?? DateTime.now(),
        sessionId: AppEventIds.roomSession(
          roomId: arg,
          userId: normalizedUserId,
        ),
        correlationId: AppEventIds.roomCorrelation(
          roomId: arg,
          userId: normalizedUserId,
        ),
        userId: normalizedUserId,
        roomId: arg,
      ),
    );
    return result;
  }

  Future<void> leaveRoom() async {
    final userId = _session.currentUserId?.trim();
    final sessionId = _session.activeSessionId;
    _startLeaveGraceWindow();
    if (userId == null || userId.isEmpty) {
      _stopRoomHeartbeat();
      _resetLocalSessionState();
      return;
    }

    _stopRoomHeartbeat();
    _session.phase = LiveRoomPhase.leaving;
    _emitState(state.copyWith(phase: _session.phase, errormessage: null));
    final ownsSession =
        sessionId == null ||
        _isSessionOwner(roomId: arg, userId: userId, sessionId: sessionId);
    if (ownsSession) {
      final firestore = _firestore;
      // Hardening: Use transaction to ensure memberCount is perfectly
      // synchronized with audience/stage arrays during leave.
      await firestore.runTransaction((transaction) async {
        await _sessionService.leaveRoom(
          roomId: arg,
          userId: userId,
          transaction: transaction,
        );
      });
      unawaited(SessionPersistence.saveLastRoom(null));
    }

    AppEventBus.instance.emit(
      RoomLeftEvent(
        id: 'room-left:$arg:$userId:${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        sessionId: AppEventIds.roomSession(roomId: arg, userId: userId),
        correlationId: AppEventIds.roomCorrelation(roomId: arg, userId: userId),
        userId: userId,
        roomId: arg,
      ),
    );
    _resetLocalSessionState();
  }

  Future<void> pausePresence() async {
    final userId = _session.currentUserId?.trim();
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _sessionService.setCustomStatus(
      roomId: arg,
      userId: userId,
      status: null,
    );
  }

  Future<void> resumePresence() async {
    if (_session.currentUserId?.trim().isEmpty ?? true) {
      return;
    }
    _session.phase = LiveRoomPhase.joined;
    _session.errormessage = null;
    _startRoomHeartbeat();
    _emitState(state.copyWith(phase: _session.phase, errormessage: null));
    await syncPresenceNow(forceSync: true);
  }

  Future<void> postSystemEvent(String content) {
    return _sessionService.postSystemEvent(roomId: arg, content: content);
  }

  Future<void> setCustomStatus({
    required String userId,
    required String? status,
  }) {
    return _sessionService.setCustomStatus(
      roomId: arg,
      userId: userId,
      status: status,
    );
  }

  Future<void> setTyping({required String userId, required bool isTyping}) {
    return _sessionService.setTyping(
      roomId: arg,
      userId: userId,
      isTyping: isTyping,
    );
  }

  Future<void> setSpotlightUser(String? userId) {
    return _sessionService.setSpotlightUser(roomId: arg, userId: userId);
  }

  Future<void> sendMessage(String content) async {
    final normalized = content.trim();
    if (normalized.isEmpty) return;
    await ref.read(sendMessageProvider(arg))(normalized);
  }

  Future<MicRequestResult> requestMic({required String userId}) async {
    final normalizedUserId = userId.trim();
    if (!state.canExecute(RoomAction.requestMic, userId: normalizedUserId)) {
      throw StateError('Only joined users can request the mic.');
    }

    if (state.isSpeaker(normalizedUserId)) {
      return MicRequestResult.grabbed;
    }

    // Trusted Speakers bypass the mic queue when a slot is free — they do
    // not need host approval, matching the system prompt contract.
    final actorRole = state.roleFor(normalizedUserId);
    final isTrustedOrStaff =
        canModerateRole(actorRole) || isTrustedSpeakerRole(actorRole);
    final hasOpenSlot = state.speakerIds.length < RoomState.maxSpeakers;
    if (isTrustedOrStaff && hasOpenSlot) {
      await _roomRepository.requestMic(
        roomId: arg,
        userId: normalizedUserId,
        displayName: state.snapshotFor(normalizedUserId)?.displayName,
        role: state.roleFor(normalizedUserId),
      );
      AppEventBus.instance.emit(
        MicStateChangedEvent(
          id: 'mic-grab:$arg:$normalizedUserId:${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          sessionId: AppEventIds.roomSession(
            roomId: arg,
            userId: normalizedUserId,
          ),
          correlationId: AppEventIds.roomCorrelation(
            roomId: arg,
            userId: normalizedUserId,
          ),
          userId: normalizedUserId,
          roomId: arg,
          isSpeaker: true,
        ),
      );
      updateAudioContext(micRequested: false, hasMicPermission: true);
      return MicRequestResult.grabbed;
    }

    final otherSpeakerIds = state.speakerIds
        .where((speakerId) => speakerId != normalizedUserId)
        .toList(growable: false);
    final canGrabDirectly =
        otherSpeakerIds.isEmpty &&
        state.speakerIds.length < RoomState.maxSpeakers;

    if (canGrabDirectly) {
      await _roomRepository.requestMic(
        roomId: arg,
        userId: normalizedUserId,
        displayName: state.snapshotFor(normalizedUserId)?.displayName,
        role: state.roleFor(normalizedUserId),
      );
      AppEventBus.instance.emit(
        MicStateChangedEvent(
          id: 'mic-grab:$arg:$normalizedUserId:${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          sessionId: AppEventIds.roomSession(
            roomId: arg,
            userId: normalizedUserId,
          ),
          correlationId: AppEventIds.roomCorrelation(
            roomId: arg,
            userId: normalizedUserId,
          ),
          userId: normalizedUserId,
          roomId: arg,
          isSpeaker: true,
        ),
      );
      updateAudioContext(micRequested: false, hasMicPermission: true);
      return MicRequestResult.grabbed;
    }

    final hostId = state.hostId.trim();
    if (hostId.isEmpty || hostId == normalizedUserId) {
      await _roomRepository.requestMic(
        roomId: arg,
        userId: normalizedUserId,
        displayName: state.snapshotFor(normalizedUserId)?.displayName,
        role: state.roleFor(normalizedUserId),
      );
      updateAudioContext(micRequested: false, hasMicPermission: true);
      return MicRequestResult.grabbed;
    }

    await _micAccess.requestAccess(
      roomId: arg,
      requesterId: normalizedUserId,
      hostId: hostId,
    );
    updateAudioContext(micRequested: true, hasMicPermission: true);
    return MicRequestResult.queued;
  }

  Future<void> approveMicRequest(MicAccessRequestModel request) async {
    await _requireStageAuthority();
    await _roomRepository.requestMic(
      roomId: arg,
      userId: request.requesterId,
      displayName: state.snapshotFor(request.requesterId)?.displayName,
      role: state.roleFor(request.requesterId),
    );
    await _micAccess.approveRequest(arg, request);
  }

  Future<void> denyMicRequest(String requestId) async {
    await _requireStageAuthority();
    return _micAccess.denyRequest(arg, requestId);
  }

  Future<void> cancelMicRequest(String requestId) {
    final actorUserId = _actorUserId;
    if (!state.canExecute(RoomAction.requestMic, userId: actorUserId)) {
      throw StateError('You must be in the room to cancel a mic request.');
    }
    updateAudioContext(micRequested: false, hasMicPermission: true);
    return _micAccess.cancelRequest(arg, requestId);
  }

  Future<void> releaseMic({required String userId}) async {
    final normalizedUserId = userId.trim();
    final actorUserId = _actorUserId;
    final isSelfRelease =
        actorUserId.isNotEmpty && actorUserId == normalizedUserId;
    if (!isSelfRelease) {
      await _requireStageAuthority();
    }
    await _roomRepository.releaseMic(roomId: arg, userId: normalizedUserId);
    if (actorUserId == normalizedUserId) {
      updateAudioContext(micRequested: false, hasMicPermission: true);
    }
    AppEventBus.instance.emit(
      MicStateChangedEvent(
        id: 'mic-release:$arg:$normalizedUserId:${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        sessionId: AppEventIds.roomSession(
          roomId: arg,
          userId: normalizedUserId,
        ),
        correlationId: AppEventIds.roomCorrelation(
          roomId: arg,
          userId: normalizedUserId,
        ),
        userId: normalizedUserId,
        roomId: arg,
        isSpeaker: false,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MUTATION METHODS  — stage + role changes
  // RULE: Every role-changing method must write _pendingRoleByUser[userId]
  //       BEFORE the awaited Firestore call so the stale filter holds the
  //       intended role during the write confirmation window.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> promoteSpeaker({
    String? actorUserId,
    required String targetUserId,
  }) async {
    final normalizedControllerActor = _actorUserId;
    final normalizedActorUserId = (actorUserId ?? normalizedControllerActor)
        .trim();
    final normalizedTargetUserId = targetUserId.trim();
    if (normalizedControllerActor.isNotEmpty &&
        normalizedActorUserId != normalizedControllerActor) {
      throw StateError(
        'Stage mutations must come from the active room controller.',
      );
    }
    await _requireStageAuthority();
    if (!state.hasAuthoritativeMembership(normalizedTargetUserId)) {
      throw StateError('Only joined users can be added to the stage.');
    }
    if (!state.canAddSpeaker(normalizedTargetUserId)) {
      throw StateError(
        'The stage already has ${RoomState.maxSpeakers} speakers.',
      );
    }
    await _roomRepository.requestMic(
      roomId: arg,
      userId: normalizedTargetUserId,
      displayName: state.snapshotFor(normalizedTargetUserId)?.displayName,
      role: state.roleFor(normalizedTargetUserId),
    );
  }

  Future<void> demoteSpeaker(String targetUserId) async {
    final normalizedTargetUserId = targetUserId.trim();
    final actorUserId = _actorUserId;
    if (actorUserId != normalizedTargetUserId) {
      await _requireStageAuthority();
    }
    if (!state.isSpeaker(normalizedTargetUserId)) {
      return;
    }
    await _roomRepository.forceRemoveSpeaker(
      roomId: arg,
      userId: normalizedTargetUserId,
    );
  }

  Future<void> muteUser(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireModerationAuthority();
    await _hostControls.muteUser(arg, normalizedUserId, actorId: _actorUserId);
    _logModerationAction('mute_user', targetUserId: normalizedUserId);
  }

  Future<void> unmuteUser(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireModerationAuthority();
    await _hostControls.unmuteUser(
      arg,
      normalizedUserId,
      actorId: _actorUserId,
    );
    _logModerationAction('unmute_user', targetUserId: normalizedUserId);
  }

  Future<void> promoteTrustedSpeaker(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    await _requireStageAuthority();
    _session.pendingRoleByUser[normalizedUserId] = roomRoleTrustedSpeaker;
    _session.pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
    _notifySessionChanged();
    await _hostControls.promoteToTrustedSpeaker(
      arg,
      normalizedUserId,
      actorId: _actorUserId,
    );
    _logModerationAction(
      'promote_trusted_speaker',
      targetUserId: normalizedUserId,
    );
  }

  Future<void> promoteToModerator(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireHostAuthority();
    _session.pendingRoleByUser[normalizedUserId] = roomRoleModerator;
    _session.pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
    _notifySessionChanged();
    await _hostControls.promoteToModerator(
      arg,
      normalizedUserId,
      actorId: _actorUserId,
    );
    _logModerationAction('promote_moderator', targetUserId: normalizedUserId);
  }

  Future<void> promoteToCohost(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireHostAuthority();
    _session.pendingRoleByUser[normalizedUserId] = roomRoleCohost;
    _session.pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
    _notifySessionChanged();
    await _hostControls.promoteToCohost(
      arg,
      normalizedUserId,
      actorId: _actorUserId,
    );
    _logModerationAction('promote_cohost', targetUserId: normalizedUserId);
  }

  Future<void> demoteToAudience(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireHostAuthority();
    _session.pendingRoleByUser[normalizedUserId] = roomRoleAudience;
    _session.pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
    _notifySessionChanged();
    await _hostControls.demoteToAudience(
      arg,
      normalizedUserId,
      actorId: _actorUserId,
    );
    _logModerationAction('demote_audience', targetUserId: normalizedUserId);
  }

  Future<void> removeUser(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireModerationAuthority();
    await _hostControls.removeUser(
      arg,
      normalizedUserId,
      actorId: _actorUserId,
    );
    _logModerationAction('remove_user', targetUserId: normalizedUserId);
  }

  Future<void> banUser(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireModerationAuthority();
    await _hostControls.banUser(arg, normalizedUserId, actorId: _actorUserId);
    _logModerationAction('ban_user', targetUserId: normalizedUserId);
  }

  Future<void> unbanUser(String userId) async {
    final normalizedUserId = userId.trim();
    await _requireModerationAuthority();
    await _hostControls.unbanUser(arg, normalizedUserId, actorId: _actorUserId);
    _logModerationAction('unban_user', targetUserId: normalizedUserId);
  }

  Future<void> transferHost({required String targetUserId}) async {
    await _requireHostAuthority();
    return _hostControls.transferHost(
      roomId: arg,
      fromUserId: _actorUserId,
      toUserId: targetUserId.trim(),
    );
  }

  Future<void> toggleSlowMode(int seconds) async {
    await _requireHostAuthority();
    return _hostControls.toggleSlowMode(arg, seconds);
  }

  Future<void> toggleLockRoom() async {
    await _requireHostAuthority();
    return _hostControls.toggleLockRoom(arg);
  }

  Future<void> toggleAllowChat() async {
    await _requireHostAuthority();
    return _hostControls.toggleAllowChat(arg);
  }

  Future<void> toggleAllowCamRequests() async {
    await _requireHostAuthority();
    return _hostControls.toggleAllowCamRequests(arg);
  }

  Future<void> toggleAllowMicRequests() async {
    await _requireHostAuthority();
    return _hostControls.toggleAllowMicRequests(arg);
  }

  Future<void> toggleAllowGifts() async {
    await _requireHostAuthority();
    return _hostControls.toggleAllowGifts(arg);
  }

  Future<void> setMaxBroadcasters(int max) async {
    await _requireHostAuthority();
    return _hostControls.setMaxBroadcasters(arg, max);
  }

  Future<void> setMicLimit(int limit) async {
    await _requireHostAuthority();
    return _roomPolicy.setMicLimit(arg, limit);
  }

  Future<void> setMicTimer(int? seconds) async {
    await _requireHostAuthority();
    return _roomPolicy.setMicTimer(arg, seconds);
  }

  Future<void> setCamLimit(int limit) async {
    await _requireHostAuthority();
    return _roomPolicy.setCamLimit(arg, limit);
  }

  Future<void> bumpMicRequest(String requestId) async {
    await _requireStageAuthority();
    return _micAccess.bumpPriority(arg, requestId);
  }

  Future<void> lowerMicRequest(String requestId) async {
    await _requireStageAuthority();
    return _micAccess.lowerPriority(arg, requestId);
  }

  Future<void> expireMicRequest(String requestId) async {
    await _requireStageAuthority();
    return _micAccess.expireNow(arg, requestId);
  }

  Future<void> dropFromMic(String targetUserId) async {
    final normalizedTargetUserId = targetUserId.trim();
    if (normalizedTargetUserId.isEmpty) return;
    await _requireStageAuthority();
    await _roomRepository.dropFromMic(
      roomId: arg,
      userId: normalizedTargetUserId,
      actorId: _actorUserId,
    );
    _logModerationAction('drop_from_mic', targetUserId: normalizedTargetUserId);
  }

  Future<void> muteUserToggle(String userId, bool muted) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    await _requireModerationAuthority();
    await _roomRepository.muteParticipant(
      roomId: arg,
      userId: normalizedUserId,
      muted: muted,
      actorId: _actorUserId,
    );
    _logModerationAction(
      muted ? 'mute_user' : 'unmute_user',
      targetUserId: normalizedUserId,
    );
  }

  Future<void> endRoom() async {
    await _requireHostAuthority();
    return _hostControls.endRoom(arg);
  }

  Future<void> setRoomInfo({
    String? name,
    String? description,
    String? category,
  }) async {
    await _requireHostAuthority();
    return _hostControls.setRoomInfo(
      arg,
      name: name,
      description: description,
      category: category,
    );
  }

  /// Updates the room's visual theme. Requires the caller to be host or
  /// co-host (enforced via [RoomPermissions.canEditRoomTheme]).
  Future<void> updateRoomTheme(RoomTheme theme) async {
    _requireActiveLifecycle();
    final actorRole = state.roleFor(_actorUserId);
    if (!RoomPermissions.canEditRoomTheme(actorRole)) {
      throw StateError('Only the host or a co-host can change the room theme.');
    }
    return _hostControls.updateRoomTheme(arg, theme);
  }

  /// Clears the room theme back to the default. Same permission requirement
  /// as [updateRoomTheme].
  Future<void> resetRoomTheme() async {
    _requireActiveLifecycle();
    final actorRole = state.roleFor(_actorUserId);
    if (!RoomPermissions.canEditRoomTheme(actorRole)) {
      throw StateError('Only the host or a co-host can reset the room theme.');
    }
    return _hostControls.resetRoomTheme(arg);
  }

  Future<void> approveCameraViewer({
    required String ownerUserId,
    required String viewerUserId,
    required bool approved,
  }) async {
    final normalizedOwnerUserId = ownerUserId.trim();
    final normalizedViewerUserId = viewerUserId.trim();
    final actorUserId = _actorUserId;
    _requireActiveLifecycle();
    final canManageViewerAccess = state.canExecute(
      RoomAction.manageCameraViewer,
      userId: actorUserId,
      targetUserId: normalizedOwnerUserId,
    );
    if (!canManageViewerAccess) {
      throw StateError(
        'Only the camera owner or room host can manage viewers.',
      );
    }
    if (approved) {
      await _camPermissions.addAllowedViewer(
        userId: normalizedOwnerUserId,
        viewerId: normalizedViewerUserId,
      );
      return;
    }
    await _camPermissions.removeAllowedViewer(
      userId: normalizedOwnerUserId,
      viewerId: normalizedViewerUserId,
    );
  }
}




