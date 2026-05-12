import 'dart:async';

import 'package:flutter/foundation.dart' show protected, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final roomControllerProvider = NotifierProvider.family
    .autoDispose<RoomController, RoomState, String>(RoomController.new);

enum MicRequestResult { grabbed, queued }

class RoomController extends AutoDisposeFamilyNotifier<RoomState, String> {
  RoomSessionService get _sessionService =>
      ref.read(roomSessionServiceProvider);
  HostControls get _hostControls => ref.read(hostControlsProvider);
  MicAccessController get _micAccess => ref.read(micAccessControllerProvider);
  RoomRepository get _roomRepository => ref.read(roomRepositoryProvider);
  RoomPolicyController get _roomPolicy =>
      ref.read(roomPolicyControllerProvider);
  UserCamPermissionsController get _camPermissions =>
      ref.read(userCamPermissionsControllerProvider);

  // Cached so it can be used inside ref.onDispose without calling ref.read
  // (which is illegal after a dependency has changed).
  // ignore: unused_field
  RoomSessionService? _cachedSessionService;

  // ═══════════════════════════════════════════════════════════════════════════
  // MUTABLE STATE
  //   Session state   — cleared fully on every leaveRoom().
  //   Consistency maps — _lastActiveAtByUser + _pendingRoleByUser (see below).
  //   Timers          — per-user join stabilization + heartbeat.
  // See docs/ROOM_CONTROLLER_CONFLICT_RULES.md for update rules.
  // ═══════════════════════════════════════════════════════════════════════════

  LiveRoomPhase _phase = LiveRoomPhase.idle;
  RoomLifecycleState _lifecycleState = RoomLifecycleState.initializing;
  String? _currentUserId;
  String? _errormessage;
  DateTime? _joinedAt;
  Set<String> _excludedUserIds = const <String>{};
  bool _micRequested = false;
  bool _hasMicPermission = true;
  final Map<String, RoomSessionSnapshot> _sessionSnapshotsByUser =
      <String, RoomSessionSnapshot>{};
  final Set<String> _pendingUserIds = <String>{};
  final Set<String> _stableUserIds = <String>{};
  // Per-user stabilization timers — a single Timer? would cancel the previous
  // user's stabilization window on each new join, leaving them stuck in
  // _pendingUserIds permanently (ghost pending).
  final Map<String, Timer> _joinStabilizationTimers = <String, Timer>{};
  Timer? _roomHeartbeatTimer;
  Timer? _graceWindowTimer;
  DateTime? _lastParticipantSyncAt;
  KeepAliveLink? _keepAliveLink;
  String? _activeSessionId;
  bool _isInGraceWindow = false;

  static final Map<String, String> _activeSessionByRoomUser =
      <String, String>{};

  bool _isDisposed = false;

  /// Tracks the most-recent `lastActiveAt` seen per user from Firestore.
  /// Any incoming participant doc with an older timestamp is stale and must
  /// not overwrite the role or snapshot we already accepted.
  final Map<String, DateTime> _lastActiveAtByUser = <String, DateTime>{};

  /// Holds roles set by in-session controller mutations (promote/demote/join)
  /// that have been written to Firestore but not yet reflected in the stream.
  /// A Firestore doc that arrives with an equal-or-older lastActiveAt while a
  /// pending role exists must not overwrite the pending role.
  final Map<String, String> _pendingRoleByUser = <String, String>{};

  /// Records when each pending role was written. Used to enforce a TTL: if
  /// Firestore does not confirm the write within `_kPendingRoleTtl`, the entry
  /// is expired and the current Firestore doc is allowed to win. This prevents
  /// a silently-failed write from holding `_pendingRoleByUser` open forever.
  final Map<String, DateTime> _pendingRoleSetAtByUser = <String, DateTime>{};

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
    _activeSessionId = sessionId;
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
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
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
    _phase = LiveRoomPhase.idle;
    _currentUserId = null;
    _joinedAt = null;
    _errormessage = null;
    _excludedUserIds = const <String>{};
    _micRequested = false;
    _hasMicPermission = true;
    _pendingUserIds.clear();
    _stableUserIds.clear();
    _sessionSnapshotsByUser.clear();
    _lastActiveAtByUser.clear();
    _pendingRoleByUser.clear();
    _pendingRoleSetAtByUser.clear();
    _lifecycleState = RoomLifecycleState.ended;
    state = const RoomState(lifecycleState: RoomLifecycleState.ended);
    _keepAliveLink?.close();
    _keepAliveLink = null;

    // HARDENING FIX #1: Clear participant cache on session end
    ref.read(selfParticipantCacheProvider(arg).notifier).clear();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REACTIVE SNAPSHOT  (build)
  // RULE: build() is a pure projection of stream inputs + mutable state onto
  //       RoomState. It must NOT mutate any field or call async operations.
  //       All field mutations happen in async methods that call _emitState().
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  RoomState build(String roomId) {
    // Cache the session service while ref is valid so it can be used
    // in ref.onDispose without triggering !_didChangeDependency.
    _cachedSessionService = ref.read(roomSessionServiceProvider);
    ref.onDispose(() {
      _isDisposed = true;
      for (final t in _joinStabilizationTimers.values) {
        t.cancel();
      }
      _joinStabilizationTimers.clear();
      _roomHeartbeatTimer?.cancel();
      _roomHeartbeatTimer = null;
      _graceWindowTimer?.cancel();
      _graceWindowTimer = null;
      // Do not execute Firestore/persistence side-effects from onDispose.
      // Auto-dispose can run during dependency churn; explicit leaveRoom()
      // owns remote cleanup semantics.
    });

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
    final normalizedCurrentUserId = _currentUserId?.trim() ?? '';
    if (normalizedCurrentUserId.isNotEmpty) {
      mergedUserIds.add(normalizedCurrentUserId);
    }

    final nextState = RoomState(
      phase: _phase,
      lifecycleState: _lifecycleState,
      roomId: roomId,
      currentUserId: _currentUserId,
      errormessage: _errormessage,
      joinedAt: _joinedAt,
      excludedUserIds: _excludedUserIds,
      hostId: hostId,
      userIds: mergedUserIds.toList(growable: false),
      stableUserIds: _resolveStableUserIds(
        mergedUserIds.toList(growable: false),
      ),
      pendingUserIds: Set<String>.unmodifiable(_pendingUserIds),
      speakerIds: speakerIds,
      camViewersByUser: camViewersByUser,
      participantRolesByUser: participantRolesByUser,
      sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
        sessionSnapshotsByUser,
      ),
      micRequested: _micRequested,
      hasMicPermission: _hasMicPermission,
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
      micRequested: _micRequested,
      hasMicPermission: _hasMicPermission,
      hasSpeakerSeat: hasSpeakerSeat,
    );
    final hostMissing = _isHostMissing(
      phase: nextState.phase,
      hostId: hostId,
      userIds: mergedUserIds,
    );

    AppTelemetry.updateRoomState(
      roomId: arg,
      joinedUserId: _currentUserId,
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
        micRequested: _micRequested,
        hasMicPermission: _hasMicPermission,
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
      final knownAt = _lastActiveAtByUser[userId];
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
        _lastActiveAtByUser[userId] = incomingAt;
      }

      // Pending-role precedence: an in-session promote/demote written to
      // Firestore has not yet been reflected in the incoming stream doc.
      // Keep the pending role until a fresh doc confirms the write, or until
      // _kPendingRoleTtl elapses (write likely failed silently).
      final pendingRole = _pendingRoleByUser[userId];
      if (pendingRole != null) {
        final setAt = _pendingRoleSetAtByUser[userId];
        final isExpired =
            setAt != null &&
            DateTime.now().difference(setAt) > _kPendingRoleTtl;
        if (isExpired) {
          // Firestore never confirmed the write — let the server doc win.
          _pendingRoleByUser.remove(userId);
          _pendingRoleSetAtByUser.remove(userId);
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
            _pendingRoleByUser.remove(userId);
            _pendingRoleSetAtByUser.remove(userId);
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
    final result = <String, RoomSessionSnapshot>{..._sessionSnapshotsByUser};

    for (final participant in participants) {
      final userId = participant.userId.trim();
      if (userId.isEmpty) {
        continue;
      }

      // Stale-event guard: do not regress a snapshot we already accepted from
      // a fresher document. Use the same high-water mark maintained by
      // _resolveParticipantRoles (which runs first in build()).
      final incomingAt = participant.lastActiveAt;
      final knownAt = _lastActiveAtByUser[userId];
      if (knownAt != null && incomingAt.isBefore(knownAt)) {
        // Stale — keep the existing snapshot unchanged.
        continue;
      }

      final existing = result[userId];
      final existingName = existing?.displayName.trim() ?? '';

      // Determine the effective role, respecting any pending in-session write.
      final pendingRole = _pendingRoleByUser[userId];
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

    final currentUserId = _currentUserId?.trim() ?? '';
    if (currentUserId.isNotEmpty) {
      result.putIfAbsent(
        currentUserId,
        () => RoomSessionSnapshot(
          userId: currentUserId,
          displayName: _safeRoomDisplayName(currentUserId),
          role: currentUserId == hostId ? 'host' : 'audience',
          joinedAt: _joinedAt,
        ),
      );
    }

    _sessionSnapshotsByUser
      ..clear()
      ..addAll(result);
    return result;
  }

  @protected
  List<String> _resolveStableUserIds(List<String> userIds) {
    final stable = <String>{...userIds, ..._stableUserIds};
    for (final userId in _pendingUserIds) {
      if (!userIds.contains(userId)) {
        stable.remove(userId);
      }
    }
    return stable.toList(growable: false);
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
    // Self-healing runs first so that assertions check post-repair state.
    // If an invariant still fires after healing, it is a programming bug.
    final healed = _selfHeal(nextState);
    // ── Hard invariants (docs/ROOM_STATE_CONTRACT.md §6) ─────────────────────
    assert(RoomStateContract.assertValid(healed), '');

    final resolvedLifecycle = resolveRoomLifecycleState(
      roomId: healed.roomId,
      phase: healed.phase,
      isHydrated: healed.isRoomFullyHydrated,
      currentUserId: healed.currentUserId,
      errormessage: healed.errormessage,
    );
    _lifecycleState = resolvedLifecycle;
    final candidate = healed.copyWith(lifecycleState: resolvedLifecycle);
    // Avoid triggering downstream rebuilds when nothing meaningful changed.
    if (candidate.phase == state.phase &&
        candidate.lifecycleState == state.lifecycleState &&
        candidate.currentUserId == state.currentUserId &&
        candidate.errormessage == state.errormessage &&
        candidate.hostId == state.hostId &&
        candidate.speakerIds == state.speakerIds &&
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
    _emitState(
      state.copyWith(
        pendingUserIds: Set<String>.unmodifiable(_pendingUserIds),
        stableUserIds: _resolveStableUserIds(state.userIds),
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _sessionSnapshotsByUser,
        ),
      ),
    );
  }

  @protected
  void _scheduleStabilization(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    _pendingUserIds.add(normalizedUserId);
    _stableUserIds.remove(normalizedUserId);
    _publishSessionState();

    // Cancel only this user's timer, preserving all other users' windows.
    _joinStabilizationTimers[normalizedUserId]?.cancel();
    _joinStabilizationTimers[normalizedUserId] = Timer(
      kRoomJoinStabilizationDelay,
      () {
        if (_isDisposed) return;
        _joinStabilizationTimers.remove(normalizedUserId);
        _pendingUserIds.remove(normalizedUserId);
        _stableUserIds.add(normalizedUserId);
        _publishSessionState();
      },
    );
  }

  void _startRoomHeartbeat() {
    _roomHeartbeatTimer?.cancel();
    if ((_currentUserId?.trim().isEmpty ?? true) ||
        _phase != LiveRoomPhase.joined) {
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
    final userId = _currentUserId?.trim() ?? '';
    if (userId.isEmpty || _phase != LiveRoomPhase.joined) {
      return;
    }

    if (_isInGraceWindow) {
      return;
    }

    final sessionId = _activeSessionId;
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
      if ((_errormessage?.trim().isNotEmpty ?? false)) {
        _errormessage = null;
        _emitState(state.copyWith(errormessage: null));
      }
    } catch (error) {
      final info = parseFirestoreError(error);
      if (_isInGraceWindow || info.code.toLowerCase() == 'not-found') {
        return;
      }
      _errormessage = 'Room state is reconnecting. Try again in a moment.';
      _emitState(state.copyWith(errormessage: _errormessage));
    }
  }

  void hydrateCurrentUser(String userId, {String? displayName, String? role}) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    _currentUserId = normalizedUserId;
    final existing = _sessionSnapshotsByUser[normalizedUserId];
    final resolvedRole = role?.trim().toLowerCase();
    _sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
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
              sessionSnapshotsByUser: _sessionSnapshotsByUser,
            ),
      joinedAt: existing?.joinedAt ?? _joinedAt,
    );
    _emitState(
      state.copyWith(
        currentUserId: normalizedUserId,
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _sessionSnapshotsByUser,
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

    final existing = _sessionSnapshotsByUser[normalizedUserId];
    final shouldUpdate =
        existing == null || _isPlaceholderDisplayName(existing.displayName);
    if (!shouldUpdate) {
      return;
    }

    _sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
      userId: normalizedUserId,
      displayName: normalizedDisplayName,
      role: role?.trim().isNotEmpty == true
          ? role!.trim().toLowerCase()
          : resolveParticipantRole(
              userId: normalizedUserId,
              hostId: state.hostId,
              participantRolesByUser: state.participantRolesByUser,
              sessionSnapshotsByUser: _sessionSnapshotsByUser,
            ),
      joinedAt: existing?.joinedAt ?? _joinedAt,
    );

    final normalizedCurrentUserId = _currentUserId?.trim() ?? '';
    final canAffectRosterVisibility =
        normalizedUserId == normalizedCurrentUserId ||
        state.userIds.contains(normalizedUserId);
    if (canAffectRosterVisibility) {
      _stableUserIds.add(normalizedUserId);
      _pendingUserIds.remove(normalizedUserId);
    }
    _publishSessionState();
  }

  void updateAudioContext({
    required bool micRequested,
    required bool hasMicPermission,
  }) {
    final nextMicRequested = hasMicPermission ? micRequested : false;
    if (_micRequested == nextMicRequested &&
        _hasMicPermission == hasMicPermission) {
      return;
    }
    _micRequested = nextMicRequested;
    _hasMicPermission = hasMicPermission;
    _emitState(
      state.copyWith(
        micRequested: _micRequested,
        hasMicPermission: _hasMicPermission,
      ),
    );
  }

  String get _actorUserId => state.currentUserId?.trim() ?? '';

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

    final firestore = ref.read(roomFirestoreProvider);
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
      sessionSnapshotsByUser: state.sessionSnapshotsByUser,
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
    if (_currentUserId == normalizedUserId && (_phase == LiveRoomPhase.joined || _phase == LiveRoomPhase.joining)) {
      return RoomJoinResult.success(
        joinedAt: _joinedAt ?? DateTime.now(),
        excludedUserIds: _excludedUserIds,
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

    if (_phase == LiveRoomPhase.joining ||
        (state.isJoined && state.currentUserId == normalizedUserId)) {
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
        joinedAt: state.joinedAt ?? DateTime.now(),
        excludedUserIds: state.excludedUserIds,
      );
    }

    final sessionId = _registerOwnership(roomId: arg, userId: normalizedUserId);
    _isInGraceWindow = false;

    _phase = LiveRoomPhase.joining;
    _currentUserId = normalizedUserId;
    _errormessage = null;
    _micRequested = false;
    _hasMicPermission = true;
    _sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
      userId: normalizedUserId,
      displayName: normalizedDisplayName.isNotEmpty
          ? normalizedDisplayName
          : (_sessionSnapshotsByUser[normalizedUserId]?.displayName ??
                _safeRoomDisplayName(normalizedUserId)),
      role: normalizeRoomRole(
        _sessionSnapshotsByUser[normalizedUserId]?.role,
        fallbackRole: roomRoleAudience,
      ),
      joinedAt: DateTime.now(),
    );
    _scheduleStabilization(normalizedUserId);
    _emitState(
      state.copyWith(
        phase: _phase,
        currentUserId: _currentUserId,
        errormessage: null,
        pendingUserIds: Set<String>.unmodifiable(_pendingUserIds),
        stableUserIds: _resolveStableUserIds(state.userIds),
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _sessionSnapshotsByUser,
        ),
      ),
    );

    final firestore = ref.read(roomFirestoreProvider);
    RoomJoinResult result;
    try {
      // Hardening: Own the transaction at the controller level to ensure
      // atomic join sequence and roster integrity.
      result = await firestore.runTransaction((transaction) async {
        return await _sessionService.joinRoom(
          roomId: arg,
          userId: normalizedUserId,
          displayName: normalizedDisplayName,
          photoUrl: avatarUrl,
          transaction: transaction,
        );
      });
    } catch (error) {
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
      _phase = LiveRoomPhase.error;
      _currentUserId = null;
      _errormessage = result.errormessage;
      _joinedAt = null;
      _excludedUserIds = result.excludedUserIds;
      _micRequested = false;
      _hasMicPermission = true;
      _pendingUserIds.remove(normalizedUserId);
      _stableUserIds.remove(normalizedUserId);
      _sessionSnapshotsByUser.remove(normalizedUserId);
      _emitState(
        state.copyWith(
          phase: _phase,
          currentUserId: null,
          errormessage: _errormessage,
          joinedAt: null,
          excludedUserIds: _excludedUserIds,
          pendingUserIds: Set<String>.unmodifiable(_pendingUserIds),
          stableUserIds: _resolveStableUserIds(state.userIds),
          sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
            _sessionSnapshotsByUser,
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

    _phase = LiveRoomPhase.joined;
    _joinedAt = result.joinedAt;
    _excludedUserIds = result.excludedUserIds;
    _startRoomHeartbeat();
    _errormessage = null;
    final existingSnapshot = _sessionSnapshotsByUser[normalizedUserId];
    _sessionSnapshotsByUser[normalizedUserId] = RoomSessionSnapshot(
      userId: normalizedUserId,
      displayName: normalizedDisplayName.isNotEmpty
          ? normalizedDisplayName
          : (existingSnapshot?.displayName ??
                _safeRoomDisplayName(normalizedUserId)),
      role: normalizeRoomRole(
        existingSnapshot?.role,
        fallbackRole: roomRoleAudience,
      ),
      joinedAt: _joinedAt,
    );

    // ═══════════════════════════════════════════════════════════════════════
    // HARDENING FIX #1: Immediately cache current participant to avoid
    // permission-denied errors during participantsStreamProvider lag.
    // ═══════════════════════════════════════════════════════════════════════
    // Fetch the current user's participant doc from Firestore immediately
    // and cache it. This prevents hydration lag from blocking chat/camera
    // permission checks when multiple users join simultaneously.
    try {
      final firestore = ref.read(roomFirestoreProvider);
      final participantSnap = await firestore
          .collection('rooms')
          .doc(arg)
          .collection('participants')
          .doc(normalizedUserId)
          .get();

      if (participantSnap.exists && participantSnap.data() != null) {
        final participant = RoomParticipantModel.fromMap(participantSnap.data()!);
        // Cache it so permission checks can use it immediately
        ref
            .read(selfParticipantCacheProvider(arg).notifier)
            .cacheParticipant(participant);
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
        phase: _phase,
        currentUserId: normalizedUserId,
        errormessage: null,
        joinedAt: _joinedAt,
        excludedUserIds: _excludedUserIds,
        pendingUserIds: Set<String>.unmodifiable(_pendingUserIds),
        stableUserIds: _resolveStableUserIds(state.userIds),
        sessionSnapshotsByUser: Map<String, RoomSessionSnapshot>.unmodifiable(
          _sessionSnapshotsByUser,
        ),
      ),
    );
    await syncPresenceNow(forceSync: true);
    AppEventBus.instance.emit(
      RoomJoinedEvent(
        id: 'room-joined:$arg:$normalizedUserId:${(_joinedAt ?? DateTime.now()).millisecondsSinceEpoch}',
        timestamp: _joinedAt ?? DateTime.now(),
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
    final userId = _currentUserId?.trim();
    final sessionId = _activeSessionId;
    _startLeaveGraceWindow();
    if (userId == null || userId.isEmpty) {
      _stopRoomHeartbeat();
      _resetLocalSessionState();
      return;
    }

    _stopRoomHeartbeat();
    _phase = LiveRoomPhase.leaving;
    _emitState(state.copyWith(phase: _phase, errormessage: null));
    final ownsSession =
        sessionId == null ||
        _isSessionOwner(roomId: arg, userId: userId, sessionId: sessionId);
    if (ownsSession) {
      final firestore = ref.read(roomFirestoreProvider);
      // Hardening: Use transaction to ensure memberCount is perfectly
      // synchronized with audience/stage arrays during leave.
      await firestore.runTransaction((transaction) async {
        await _sessionService.leaveRoom(
          roomId: arg,
          userId: userId,
          transaction: transaction,
        );
      });
    }

    // Hardening: Clear persisted room session on clean exit
    if (ownsSession) {
      unawaited(SessionPersistence.saveLastRoom(null));
      _releaseOwnership(roomId: arg, userId: userId, sessionId: sessionId);
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
    final userId = _currentUserId?.trim();
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
    if (_currentUserId?.trim().isEmpty ?? true) {
      return;
    }
    _phase = LiveRoomPhase.joined;
    _errormessage = null;
    _startRoomHeartbeat();
    _emitState(state.copyWith(phase: _phase, errormessage: null));
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
    _pendingRoleByUser[normalizedUserId] = roomRoleTrustedSpeaker;
    _pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
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
    _pendingRoleByUser[normalizedUserId] = roomRoleModerator;
    _pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
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
    _pendingRoleByUser[normalizedUserId] = roomRoleCohost;
    _pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
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
    _pendingRoleByUser[normalizedUserId] = roomRoleAudience;
    _pendingRoleSetAtByUser[normalizedUserId] = DateTime.now();
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
