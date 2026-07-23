import '../../../models/room_participant_model.dart';

enum LiveRoomPhase { idle, joining, joined, leaving, error }

enum RoomLifecycleState { initializing, hydrating, active, degraded, ended }

enum RoomAudioState { muted, requestingMic, speaking, cohostSpeaking, denied }

enum RoomMembershipState {
  absent,
  joining,
  stabilizing,
  active,
  reconnecting,
  leaving,
}

extension RoomMembershipStateX on RoomMembershipState {
  bool get isAuthoritativeMember =>
      this == RoomMembershipState.stabilizing ||
      this == RoomMembershipState.active ||
      this == RoomMembershipState.reconnecting;

  bool get shouldDeferRemoval =>
      this == RoomMembershipState.joining ||
      this == RoomMembershipState.stabilizing ||
      this == RoomMembershipState.reconnecting;
}

enum RoomAction {
  requestMic,
  manageStage,
  manageMicQueue,
  moderateParticipants,
  manageRoom,
  manageCameraViewer,
}

bool _isAnonymousRoomDisplayName(String value, String userId) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return true;
  }

  final normalizedUserId = userId.trim();
  final generatedHandlePattern = RegExp(r'^(User|Guest|Member) [A-Z0-9]{1,4}$');
  final opaqueIdPattern = RegExp(r'^[A-Za-z0-9_-]{20,}$');

  return trimmed == normalizedUserId ||
      trimmed == 'MixVy User' ||
      trimmed == 'MixVy Member' ||
      generatedHandlePattern.hasMatch(trimmed) ||
      opaqueIdPattern.hasMatch(trimmed);
}

String _safeRoomMemberName(String userId) {
  final compact = userId
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toUpperCase();
  if (compact.isEmpty) {
    return 'MixVy Member';
  }
  final suffix = compact.substring(0, compact.length < 4 ? compact.length : 4);
  return 'Member $suffix';
}

class RoomStateMachine {
  const RoomStateMachine._();

  static RoomLifecycleState resolveLifecycleState({
    required String roomId,
    required LiveRoomPhase phase,
    required bool isHydrated,
    String? currentUserId,
    String? errormessage,
  }) {
    final normalizedRoomId = roomId.trim();
    final hasCurrentUser = currentUserId?.trim().isNotEmpty == true;
    final hasError = errormessage?.trim().isNotEmpty == true;

    switch (phase) {
      case LiveRoomPhase.joining:
        return RoomLifecycleState.hydrating;
      case LiveRoomPhase.joined:
        if (!hasCurrentUser || hasError) {
          return RoomLifecycleState.degraded;
        }
        return isHydrated
            ? RoomLifecycleState.active
            : RoomLifecycleState.hydrating;
      case LiveRoomPhase.error:
        return RoomLifecycleState.degraded;
      case LiveRoomPhase.leaving:
        return RoomLifecycleState.ended;
      case LiveRoomPhase.idle:
        if (normalizedRoomId.isEmpty) {
          return RoomLifecycleState.initializing;
        }
        if (!hasCurrentUser) {
          return RoomLifecycleState.ended;
        }
        if (hasError) {
          return RoomLifecycleState.degraded;
        }
        return isHydrated
            ? RoomLifecycleState.active
            : RoomLifecycleState.hydrating;
    }
  }

  static String resolveHostId({
    Map<String, dynamic>? roomDoc,
    Iterable<RoomParticipantModel> participants =
        const <RoomParticipantModel>[],
  }) {
    final ownerId = (roomDoc?['ownerId'] as String?)?.trim() ?? '';
    if (ownerId.isNotEmpty) {
      return ownerId;
    }

    final hostId = (roomDoc?['hostId'] as String?)?.trim() ?? '';
    if (hostId.isNotEmpty) {
      return hostId;
    }

    for (final participant in participants) {
      final userId = participant.userId.trim();
      if (userId.isEmpty) {
        continue;
      }
      if (isHostLikeRole(participant.role)) {
        return userId;
      }
    }

    return '';
  }

  static String resolveParticipantRole({
    required String userId,
    String hostId = '',
    Map<String, String> participantRolesByUser = const <String, String>{},
    Map<String, RoomSessionSnapshot> sessionSnapshotsByUser =
        const <String, RoomSessionSnapshot>{},
    String fallbackRole = roomRoleAudience,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return fallbackRole;
    }

    final normalizedHostId = hostId.trim();
    final participantRole = normalizeRoomRole(
      participantRolesByUser[normalizedUserId],
      fallbackRole: '',
    );
    final snapshotRole = normalizeRoomRole(
      sessionSnapshotsByUser[normalizedUserId]?.role,
      fallbackRole: '',
    );
    final hasAuthoritativeHost = normalizedHostId.isNotEmpty;

    final effectiveParticipantRole =
        hasAuthoritativeHost &&
            normalizedHostId != normalizedUserId &&
            participantRole == roomRoleHost
        ? ''
        : participantRole;
    final effectiveSnapshotRole =
        hasAuthoritativeHost &&
            normalizedHostId != normalizedUserId &&
            snapshotRole == roomRoleHost
        ? ''
        : snapshotRole;

    if (hasAuthoritativeHost && normalizedHostId == normalizedUserId) {
      if (isHostLikeRole(effectiveParticipantRole)) {
        return effectiveParticipantRole;
      }
      if (isHostLikeRole(effectiveSnapshotRole)) {
        return effectiveSnapshotRole;
      }
      return roomRoleHost;
    }

    if (effectiveParticipantRole.isNotEmpty) {
      return effectiveParticipantRole;
    }
    if (effectiveSnapshotRole.isNotEmpty) {
      return effectiveSnapshotRole;
    }

    return normalizeRoomRole(fallbackRole);
  }

  static RoomAudioState resolveAudioState({
    required RoomLifecycleState roomState,
    required bool isHost,
    required bool isCohost,
    required bool micRequested,
    required bool hasMicPermission,
    bool hasSpeakerSeat = false,
  }) {
    if (roomState != RoomLifecycleState.active) {
      return RoomAudioState.muted;
    }
    if (!hasMicPermission) {
      return RoomAudioState.denied;
    }
    if (isHost) {
      return RoomAudioState.speaking;
    }
    if (isCohost) {
      return RoomAudioState.cohostSpeaking;
    }
    if (hasSpeakerSeat) {
      return RoomAudioState.speaking;
    }
    if (micRequested) {
      return RoomAudioState.requestingMic;
    }
    return RoomAudioState.muted;
  }
}

RoomLifecycleState resolveRoomLifecycleState({
  required String roomId,
  required LiveRoomPhase phase,
  required bool isHydrated,
  String? currentUserId,
  String? errormessage,
}) {
  return RoomStateMachine.resolveLifecycleState(
    roomId: roomId,
    phase: phase,
    isHydrated: isHydrated,
    currentUserId: currentUserId,
    errormessage: errormessage,
  );
}

class RoomSessionSnapshot {
  const RoomSessionSnapshot({
    required this.userId,
    required this.displayName,
    required this.role,
    this.joinedAt,
  });

  final String userId;
  final String displayName;
  final String role;
  final DateTime? joinedAt;

  RoomSessionSnapshot copyWith({
    String? userId,
    String? displayName,
    String? role,
    Object? joinedAt = _unset,
  }) {
    return RoomSessionSnapshot(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: identical(joinedAt, _unset)
          ? this.joinedAt
          : joinedAt as DateTime?,
    );
  }
}

const String roomRoleHost = 'host';
const String roomRoleOwner = 'owner';
const String roomRoleCohost = 'cohost';
const String roomRoleModerator = 'moderator';
const String roomRoleTrustedSpeaker = 'trusted_speaker';
const String roomRoleStage = 'stage';
const String roomRoleAudience = 'audience';

String normalizeRoomRole(
  String? role, {
  String fallbackRole = roomRoleAudience,
}) {
  final normalized = role?.trim().toLowerCase() ?? '';
  switch (normalized) {
    case roomRoleHost:
    case roomRoleOwner:
    case roomRoleCohost:
    case roomRoleModerator:
    case roomRoleTrustedSpeaker:
    case roomRoleStage:
    case roomRoleAudience:
      return normalized;
    case '':
      return fallbackRole;
    default:
      return fallbackRole;
  }
}

bool isHostLikeRole(String role) {
  final normalized = normalizeRoomRole(role, fallbackRole: '');
  return normalized == roomRoleHost || normalized == roomRoleOwner;
}

bool canManageStageRole(String role) {
  final normalized = normalizeRoomRole(role, fallbackRole: '');
  return isHostLikeRole(normalized) || normalized == roomRoleCohost;
}

bool canModerateRole(String role) {
  final normalized = normalizeRoomRole(role, fallbackRole: '');
  return canManageStageRole(normalized) || normalized == roomRoleModerator;
}

bool isTrustedSpeakerRole(String role) {
  return normalizeRoomRole(role, fallbackRole: '') == roomRoleTrustedSpeaker;
}

bool canUseMicRole(String role) {
  final normalized = normalizeRoomRole(role, fallbackRole: '');
  return canModerateRole(normalized) ||
      normalized == roomRoleStage ||
      normalized == roomRoleTrustedSpeaker;
}

bool canUseCameraRole(String role) {
  return role.trim().isNotEmpty;
}

bool liveRoomAudioCanPublish(RoomAudioState state) {
  return state == RoomAudioState.speaking ||
      state == RoomAudioState.cohostSpeaking;
}

String resolveParticipantRole({
  required String userId,
  String hostId = '',
  Map<String, String> participantRolesByUser = const <String, String>{},
  Map<String, RoomSessionSnapshot> sessionSnapshotsByUser =
      const <String, RoomSessionSnapshot>{},
  String fallbackRole = roomRoleAudience,
}) {
  return RoomStateMachine.resolveParticipantRole(
    userId: userId,
    hostId: hostId,
    participantRolesByUser: participantRolesByUser,
    sessionSnapshotsByUser: sessionSnapshotsByUser,
    fallbackRole: fallbackRole,
  );
}

class RoomState {
  const RoomState({
    this.phase = LiveRoomPhase.idle,
    RoomLifecycleState lifecycleState = RoomLifecycleState.initializing,
    this.audioState = RoomAudioState.muted,
    this.roomId = '',
    this.currentUserId,
    this.errormessage,
    this.joinedAt,
    this.excludedUserIds = const <String>{},
    this.hostId = '',
    this.userIds = const <String>[],
    this.stableUserIds = const <String>[],
    this.pendingUserIds = const <String>{},
    this.speakerIds = const <String>[],
    this.camViewersByUser = const <String, List<String>>{},
    this.participantRolesByUser = const <String, String>{},
    this.sessionSnapshotsByUser = const <String, RoomSessionSnapshot>{},
    this.micRequested = false,
    this.hasMicPermission = true,
    this.hasSpeakerSeat = false,
    this.spotlightUserId,
  }) : _lifecycleState = lifecycleState;

  static const int maxSpeakers = 4;

  final LiveRoomPhase phase;
  final RoomLifecycleState _lifecycleState;
  final RoomAudioState audioState;
  final String roomId;
  final String? currentUserId;
  final String? errormessage;
  final DateTime? joinedAt;
  final Set<String> excludedUserIds;
  final String hostId;
  final List<String> userIds;
  final List<String> stableUserIds;
  final Set<String> pendingUserIds;
  final List<String> speakerIds;
  final Map<String, List<String>> camViewersByUser;
  final Map<String, String> participantRolesByUser;
  final Map<String, RoomSessionSnapshot> sessionSnapshotsByUser;
  final bool micRequested;
  final bool hasMicPermission;
  final bool hasSpeakerSeat;
  final String? spotlightUserId;

  String? get userId => currentUserId;

  List<String> get users => List<String>.unmodifiable(userIds);

  List<String> get speakers => List<String>.unmodifiable(speakerIds);

  RoomLifecycleState get lifecycleState {
    final resolvedLifecycleState = resolveRoomLifecycleState(
      roomId: roomId,
      phase: phase,
      isHydrated: isRoomFullyHydrated,
      currentUserId: currentUserId,
      errormessage: errormessage,
    );
    if (_lifecycleState == RoomLifecycleState.ended &&
        resolvedLifecycleState == RoomLifecycleState.initializing) {
      return _lifecycleState;
    }
    return resolvedLifecycleState;
  }

  bool get isConnected => phase == LiveRoomPhase.joined;

  bool get isJoined =>
      phase == LiveRoomPhase.joined && (currentUserId?.isNotEmpty == true);

  bool get isActive => lifecycleState == RoomLifecycleState.active;

  bool get isDegraded => lifecycleState == RoomLifecycleState.degraded;

  bool get isRequestingMic => audioState == RoomAudioState.requestingMic;

  bool get canPublishAudio => liveRoomAudioCanPublish(audioState);

  bool get isRoomFullyHydrated {
    final normalizedCurrentUserId = currentUserId?.trim() ?? '';
    if (normalizedCurrentUserId.isEmpty) {
      return false;
    }

    final snapshotRole =
        sessionSnapshotsByUser[normalizedCurrentUserId]?.role
            .trim()
            .toLowerCase() ??
        '';
    final hasExplicitAuthorityRole =
        snapshotRole.isNotEmpty && snapshotRole != 'audience';

    if (pendingUserIds.contains(normalizedCurrentUserId) &&
        !hasExplicitAuthorityRole) {
      return false;
    }

    return stableUserIds.contains(normalizedCurrentUserId) ||
        participantRolesByUser.containsKey(normalizedCurrentUserId) ||
        hostId.trim() == normalizedCurrentUserId ||
        hasExplicitAuthorityRole;
  }

  RoomMembershipState membershipStateFor(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return RoomMembershipState.absent;
    }

    final normalizedCurrentUserId = currentUserId?.trim() ?? '';
    final isCurrentUser = normalized == normalizedCurrentUserId;
    final isPending = pendingUserIds.contains(normalized);
    final isStable = stableUserIds.contains(normalized);
    final isListed = userIds.contains(normalized);
    final isHostUser = hostId.trim() == normalized;
    final hasRole =
        participantRolesByUser.containsKey(normalized) || isHostUser;
    final hasSessionSnapshot = sessionSnapshotsByUser.containsKey(normalized);

    if (phase == LiveRoomPhase.joining && isCurrentUser) {
      return RoomMembershipState.joining;
    }

    if (phase == LiveRoomPhase.leaving &&
        (isCurrentUser || isListed || hasSessionSnapshot)) {
      return RoomMembershipState.leaving;
    }

    if (isPending) {
      return RoomMembershipState.stabilizing;
    }

    if (isListed) {
      return RoomMembershipState.active;
    }

    if (hasRole && (isStable || isCurrentUser)) {
      return RoomMembershipState.active;
    }

    if (isCurrentUser &&
        (phase == LiveRoomPhase.joined || phase == LiveRoomPhase.error) &&
        hasSessionSnapshot) {
      return RoomMembershipState.reconnecting;
    }

    return RoomMembershipState.absent;
  }

  bool hasAuthoritativeMembership(String userId) =>
      membershipStateFor(userId).isAuthoritativeMember;

  bool shouldDeferMembershipRemoval(String userId) =>
      membershipStateFor(userId).shouldDeferRemoval;

  bool isUserInRoom(String userId) => hasAuthoritativeMembership(userId);

  bool canChat(String userId) => hasAuthoritativeMembership(userId);

  bool isSpeaker(String userId) {
    final normalized = userId.trim();
    return normalized.isNotEmpty && speakerIds.contains(normalized);
  }

  bool shouldRenderUser(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final membershipState = membershipStateFor(normalized);
    final normalizedCurrentUserId = currentUserId?.trim() ?? '';
    if (normalized == normalizedCurrentUserId) {
      return membershipState.isAuthoritativeMember ||
          membershipState == RoomMembershipState.joining;
    }

    return membershipState == RoomMembershipState.active;
  }

  RoomSessionSnapshot? snapshotFor(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return sessionSnapshotsByUser[normalized];
  }

  String displayNameFor(String userId, {String fallbackName = ''}) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      final trimmedFallback = fallbackName.trim();
      return trimmedFallback.isEmpty ? 'MixVy User' : trimmedFallback;
    }

    final snapshotName = snapshotFor(normalized)?.displayName.trim() ?? '';
    if (!_isAnonymousRoomDisplayName(snapshotName, normalized)) {
      return snapshotName;
    }

    final trimmedFallback = fallbackName.trim();
    if (!_isAnonymousRoomDisplayName(trimmedFallback, normalized)) {
      return trimmedFallback;
    }

    return _safeRoomMemberName(normalized);
  }

  String roleFor(String userId) {
    return resolveParticipantRole(
      userId: userId,
      hostId: hostId,
      participantRolesByUser: participantRolesByUser,
      sessionSnapshotsByUser: sessionSnapshotsByUser,
    );
  }

  String presentationRoleFor(
    String userId, {
    String fallbackRole = roomRoleAudience,
  }) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return fallbackRole;
    }

    final resolvedRole = normalizeRoomRole(
      roleFor(normalized),
      fallbackRole: '',
    );
    if (resolvedRole.isNotEmpty) {
      return resolvedRole;
    }
    if (isSpeaker(normalized)) {
      return roomRoleStage;
    }
    if (hostId.trim() == normalized) {
      return roomRoleHost;
    }
    return fallbackRole;
  }

  bool isOnMicByAuthority(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final normalizedCurrentUserId = currentUserId?.trim() ?? '';
    if (normalizedCurrentUserId != normalized &&
        !hasAuthoritativeMembership(normalized)) {
      return false;
    }

    final role = normalizeRoomRole(
      presentationRoleFor(normalized, fallbackRole: ''),
      fallbackRole: '',
    );
    return isSpeaker(normalized) ||
        role == roomRoleHost ||
        role == roomRoleOwner ||
        role == roomRoleCohost ||
        role == roomRoleStage;
  }

  bool _canResolveAuthorityFor(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final normalizedCurrentUserId = currentUserId?.trim() ?? '';
    if (normalizedCurrentUserId.isEmpty ||
        normalized != normalizedCurrentUserId) {
      return true;
    }
    return isRoomFullyHydrated;
  }

  bool isHost(String userId) {
    if (!_canResolveAuthorityFor(userId)) {
      return false;
    }
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return isHostLikeRole(roleFor(normalized));
  }

  bool isCohost(String userId) =>
      _canResolveAuthorityFor(userId) &&
      normalizeRoomRole(roleFor(userId), fallbackRole: '') == roomRoleCohost;

  bool isModerator(String userId) =>
      _canResolveAuthorityFor(userId) &&
      normalizeRoomRole(roleFor(userId), fallbackRole: '') == roomRoleModerator;

  bool canManageStage(String userId) {
    if (!_canResolveAuthorityFor(userId)) {
      return false;
    }
    return canManageStageRole(roleFor(userId));
  }

  bool canModerate(String userId) {
    if (!_canResolveAuthorityFor(userId)) {
      return false;
    }
    return canModerateRole(roleFor(userId));
  }

  bool canExecute(
    RoomAction action, {
    required String userId,
    String? targetUserId,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return false;
    }

    switch (action) {
      case RoomAction.requestMic:
        return isJoined &&
            isUserInRoom(normalizedUserId) &&
            audioState != RoomAudioState.denied;
      case RoomAction.manageStage:
      case RoomAction.manageMicQueue:
        if (lifecycleState != RoomLifecycleState.active) {
          return false;
        }
        return canManageStage(normalizedUserId);
      case RoomAction.moderateParticipants:
        if (lifecycleState != RoomLifecycleState.active) {
          return false;
        }
        return canModerate(normalizedUserId);
      case RoomAction.manageRoom:
        if (lifecycleState != RoomLifecycleState.active) {
          return false;
        }
        return isHost(normalizedUserId);
      case RoomAction.manageCameraViewer:
        if (lifecycleState != RoomLifecycleState.active) {
          return false;
        }
        final normalizedTargetUserId = targetUserId?.trim() ?? '';
        if (normalizedTargetUserId.isEmpty) {
          return false;
        }
        return normalizedUserId == normalizedTargetUserId ||
            isHost(normalizedUserId);
    }
  }

  bool canAddSpeaker(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (speakerIds.contains(normalized)) {
      return true;
    }
    return speakerIds.length < maxSpeakers;
  }

  bool canViewCamera({
    required String targetUserId,
    required String viewerUserId,
  }) {
    final normalizedTarget = targetUserId.trim();
    final normalizedViewer = viewerUserId.trim();
    if (normalizedTarget.isEmpty || normalizedViewer.isEmpty) {
      return false;
    }
    if (normalizedTarget == normalizedViewer) {
      return true;
    }
    return camViewersByUser[normalizedTarget]?.contains(normalizedViewer) ??
        false;
  }

  bool isWatchingMe({required String myUserId, required String otherUserId}) {
    final normalizedMe = myUserId.trim();
    final normalizedOther = otherUserId.trim();
    if (normalizedMe.isEmpty || normalizedOther.isEmpty) {
      return false;
    }
    return camViewersByUser[normalizedMe]?.contains(normalizedOther) ?? false;
  }

  int viewerCountFor(String targetUserId) {
    final normalized = targetUserId.trim();
    return camViewersByUser[normalized]?.length ?? 0;
  }

  RoomState copyWith({
    LiveRoomPhase? phase,
    RoomLifecycleState? lifecycleState,
    RoomAudioState? audioState,
    Object? currentUserId = _unset,
    Object? errormessage = _unset,
    Object? joinedAt = _unset,
    Set<String>? excludedUserIds,
    String? hostId,
    List<String>? userIds,
    List<String>? stableUserIds,
    Set<String>? pendingUserIds,
    List<String>? speakerIds,
    Map<String, List<String>>? camViewersByUser,
    Map<String, String>? participantRolesByUser,
    Map<String, RoomSessionSnapshot>? sessionSnapshotsByUser,
    bool? micRequested,
    bool? hasMicPermission,
    bool? hasSpeakerSeat,
    Object? spotlightUserId = _unset,
  }) {
    return RoomState(
      phase: phase ?? this.phase,
      lifecycleState: lifecycleState ?? _lifecycleState,
      audioState: audioState ?? this.audioState,
      roomId: roomId,
      currentUserId: identical(currentUserId, _unset)
          ? this.currentUserId
          : currentUserId as String?,
      errormessage: identical(errormessage, _unset)
          ? this.errormessage
          : errormessage as String?,
      joinedAt: identical(joinedAt, _unset)
          ? this.joinedAt
          : joinedAt as DateTime?,
      excludedUserIds: excludedUserIds ?? this.excludedUserIds,
      hostId: hostId ?? this.hostId,
      userIds: userIds ?? this.userIds,
      stableUserIds: stableUserIds ?? this.stableUserIds,
      pendingUserIds: pendingUserIds ?? this.pendingUserIds,
      speakerIds: speakerIds ?? this.speakerIds,
      camViewersByUser: camViewersByUser ?? this.camViewersByUser,
      participantRolesByUser:
          participantRolesByUser ?? this.participantRolesByUser,
      sessionSnapshotsByUser:
          sessionSnapshotsByUser ?? this.sessionSnapshotsByUser,
      micRequested: micRequested ?? this.micRequested,
      hasMicPermission: hasMicPermission ?? this.hasMicPermission,
      hasSpeakerSeat: hasSpeakerSeat ?? this.hasSpeakerSeat,
      spotlightUserId: identical(spotlightUserId, _unset)
          ? this.spotlightUserId
          : spotlightUserId as String?,
    );
  }
}

const Object _unset = Object();




