import 'controllers/room_state.dart';

class RoomPermissions {
  static const String host = roomRoleHost;
  static const String cohost = roomRoleCohost;
  static const String moderator = roomRoleModerator;
  static const String trustedSpeaker = roomRoleTrustedSpeaker;
  static const String stage = roomRoleStage;
  static const String audience = roomRoleAudience;

  static bool isHost(String role) => isHostLikeRole(role);
  static bool isModerator(String role) =>
      normalizeRoomRole(role, fallbackRole: '') == moderator;
  static bool isTrustedSpeaker(String role) =>
      normalizeRoomRole(role, fallbackRole: '') == trustedSpeaker;
  static bool isStaff(String role) => canModerateRole(role);

  static bool canUseMic(String role) {
    return canUseMicRole(role);
  }

  static bool canUseCamera(String role) {
    return canUseCameraRole(role);
  }

  static bool canManageParticipant({
    required String actorRole,
    required String actorUserId,
    required String targetRole,
    required String targetUserId,
    required String hostUserId,
  }) {
    if (actorUserId == targetUserId) {
      return false;
    }

    final targetIsHost = targetUserId == hostUserId || targetRole == host;
    if (targetIsHost) {
      return false;
    }

    if (isHost(actorRole)) {
      return true;
    }

    // Moderators can only manage audience/stage/trusted_speaker participants.
    if (isModerator(actorRole)) {
      return targetRole == audience ||
          targetRole == stage ||
          targetRole == trustedSpeaker;
    }

    return false;
  }

  static bool canTransferOwnership({
    required String actorRole,
    required String actorUserId,
    required String targetUserId,
    required String hostUserId,
  }) {
    return isHost(actorRole) &&
        actorUserId == hostUserId &&
        actorUserId != targetUserId;
  }

  /// Returns true when [actorRole] is allowed to change the room's visual theme.
  /// Only the host or a co-host can edit the room theme.
  static bool canEditRoomTheme(String actorRole) {
    return isHost(actorRole) || canManageStageRole(actorRole);
  }
}

const Duration _ejectGraceWindow = Duration(seconds: 10);

bool shouldEjectJoinedUserFromRoom({
  required bool hasTrackedRoomJoin,
  bool isJoiningRoom = false,
  bool hasCurrentParticipant = false,
  bool isUserInResolvedRoomState = false,
  RoomMembershipState membershipState = RoomMembershipState.absent,
  DateTime? lastConfirmedMembershipAt,
  DateTime? now,
}) {
  if (!hasTrackedRoomJoin) return false;
  if (isJoiningRoom) return false;
  if (hasCurrentParticipant) return false;
  if (isUserInResolvedRoomState) return false;
  if (membershipState.shouldDeferRemoval) return false;
  final lastMembership = lastConfirmedMembershipAt;
  if (lastMembership == null) return false;
  final effectiveNow = now ?? DateTime.now();
  return effectiveNow.difference(lastMembership) > _ejectGraceWindow;
}
