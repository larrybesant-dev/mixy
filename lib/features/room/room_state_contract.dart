import 'package:flutter/material.dart';
import 'controllers/room_state.dart';

// ════════════════════════════════════════════════════════════════════════════
// ROOM STATE CONTRACT — Enforcement layer
//
// This file is the machine-readable counterpart to docs/ROOM_STATE_CONTRACT.md.
// It exposes:
//   • Constants used across the resolution pipeline (never hard-code these).
//   • RoomContractViolation — structured description of a broken invariant.
//   • RoomStateContract.validate() — returns all violations for a given state.
//   • RoomStateContract.assertValid() — throws AssertionError in debug builds.
//
// Usage in controller:
//   assert(RoomStateContract.assertValid(healed), '');
//
// Usage in tests:
//   expect(RoomStateContract.validate(state), isEmpty);
// ════════════════════════════════════════════════════════════════════════════

// ─── Contract §5: Pending-role TTL ──────────────────────────────────────────
/// Maximum time a pending role is held without Firestore confirmation.
/// After this window, the Firestore-streamed role is accepted as authoritative.
/// MUST NOT be made adaptive (see contract §5 and prohibition P-3).
const Duration kRoomPendingRoleTtl = Duration(seconds: 8);

// ─── Contract §2.3: Speaker ceiling ─────────────────────────────────────────
/// Hard ceiling on the number of concurrent speakers. Matches
/// [RoomState.maxSpeakers]. Both must be updated together if the ceiling
/// ever changes.
const int kRoomMaxSpeakers = 4;

// ─── Contract §12: Heal burst thresholds ────────────────────────────────────
/// Number of self-heal events within the telemetry window that triggers a
/// warning-level [self_heal_spike] alert.
const int kRoomHealBurstWarning = 3;

/// Number of self-heal events within the telemetry window that escalates the
/// alert to critical severity.
const int kRoomHealBurstCritical = 6;

// ─── Contract §8: Join stabilization window ─────────────────────────────────
/// Per-user delay before a newly joined participant is moved from
/// [RoomState.pendingUserIds] to [RoomState.stableUserIds].
/// Absorbs Firestore write-propagation lag.
const Duration kRoomJoinStabilizationDelay = Duration(milliseconds: 350);

// ─── Contract §1: Role authority sets ───────────────────────────────────────
/// Roles that grant full room management authority (host equivalent).
const Set<String> kRoomHostLikeRoles = <String>{roomRoleHost, roomRoleOwner};

/// Roles that grant stage management authority (can promote/demote mic seats).
const Set<String> kRoomStageManagementRoles = <String>{
  roomRoleHost,
  roomRoleOwner,
  roomRoleCohost,
};

/// Roles that grant moderation authority (can mute, ban, kick).
const Set<String> kRoomModerationRoles = <String>{
  roomRoleHost,
  roomRoleOwner,
  roomRoleCohost,
  roomRoleModerator,
};

/// Roles that allow mic seat occupancy (active speaker).
const Set<String> kRoomMicRoles = <String>{
  roomRoleHost,
  roomRoleOwner,
  roomRoleCohost,
  roomRoleModerator,
  roomRoleTrustedSpeaker,
  roomRoleStage,
};

/// All valid normalized role strings. Any other value is treated as [roomRoleAudience].
const Set<String> kAllRoomRoles = <String>{
  roomRoleHost,
  roomRoleOwner,
  roomRoleCohost,
  roomRoleModerator,
  roomRoleTrustedSpeaker,
  roomRoleStage,
  roomRoleAudience,
};

// ════════════════════════════════════════════════════════════════════════════

/// Identifies which hard invariant (§6 of the contract) was violated.
enum RoomContractInvariant {
  /// I-1: speakerIds.length > maxSpeakers
  speakerCeilingExceeded,

  /// I-2: speakerIds contains a userId not in userIds and not hostId
  ghostSpeakerPostHeal,

  /// I-3: phase == joined but currentUserId is not in userIds
  currentUserNotInRoster,

  /// I-4: hostId has a non-host-like role in participantRolesByUser
  hostRoleMismatchPostHeal,
}

/// A contract invariant that [RoomState] violates.
final class RoomContractViolation {
  const RoomContractViolation({required this.invariant, required this.detail});

  final RoomContractInvariant invariant;
  final String detail;

  @override
  String toString() => '[${invariant.name}] $detail';
}

/// Machine-readable enforcement of [docs/ROOM_STATE_CONTRACT.md].
///
/// All methods are static and pure — they never mutate state.
abstract final class RoomStateContract {
  RoomStateContract._();

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Returns every [RoomContractViolation] found in [state].
  ///
  /// An empty list means the state satisfies all hard invariants.
  /// Call this inside tests: `expect(RoomStateContract.validate(state), isEmpty)`.
  static List<RoomContractViolation> validate(RoomState state) {
    final violations = <RoomContractViolation>[];

    // I-1 — speaker ceiling
    if (state.speakerIds.length > kRoomMaxSpeakers) {
      violations.add(
        RoomContractViolation(
          invariant: RoomContractInvariant.speakerCeilingExceeded,
          detail:
              'speakerIds.length=${state.speakerIds.length} exceeds '
              'kRoomMaxSpeakers=$kRoomMaxSpeakers.',
        ),
      );
    }

    // I-2 — no ghost speakers
    final ghostSpeakers = state.speakerIds
        .where(
          (id) =>
              !state.userIds.contains(id) && id.trim() != state.hostId.trim(),
        )
        .toList(growable: false);
    if (ghostSpeakers.isNotEmpty) {
      violations.add(
        RoomContractViolation(
          invariant: RoomContractInvariant.ghostSpeakerPostHeal,
          detail:
              'speakerIds contains ${ghostSpeakers.length} id(s) absent from '
              'userIds and not hostId after self-healing: '
              '${ghostSpeakers.join(', ')}.',
        ),
      );
    }

    // I-3 — current user in roster when joined
    final currentId = state.currentUserId?.trim() ?? '';
    if (state.phase == LiveRoomPhase.joined &&
        currentId.isNotEmpty &&
        !state.userIds.contains(currentId)) {
      violations.add(
        RoomContractViolation(
          invariant: RoomContractInvariant.currentUserNotInRoster,
          detail:
              'phase=joined but currentUserId="$currentId" is not in userIds.',
        ),
      );
    }

    // I-4 — host role alignment
    final hostId = state.hostId.trim();
    if (hostId.isNotEmpty) {
      final hostRole = state.participantRolesByUser[hostId];
      if (hostRole != null && !isHostLikeRole(hostRole)) {
        violations.add(
          RoomContractViolation(
            invariant: RoomContractInvariant.hostRoleMismatchPostHeal,
            detail:
                'participantRolesByUser["$hostId"]="$hostRole" is not a '
                'host-like role even after self-healing.',
          ),
        );
      }
    }

    return violations;
  }

  /// Returns `true` if [state] satisfies all hard invariants.
  static bool isValid(RoomState state) => validate(state).isEmpty;

  /// Asserts that [state] is valid in debug builds.
  ///
  /// Returns `true` so it can be used directly in an `assert()` call:
  ///   `assert(RoomStateContract.assertValid(state), '');`
  ///
  /// Throws [AssertionError] describing the first violation found.
  static bool assertValid(RoomState state) {
    assert(() {
      final violations = validate(state);
      if (violations.isNotEmpty) {
        throw AssertionError(
          'RoomState invariant violation(s) detected:\n'
          '${violations.map((v) => '  • $v').join('\n')}',
        );
      }
      return true;
    }());
    return true;
  }

  // ── Authority queries ───────────────────────────────────────────────────────
  // Convenience wrappers so callers import one file instead of two.
  // All return false for unknown/empty roles rather than throwing.

  /// Returns true if [role] grants full room management authority (host tier).
  static bool isHostAuthority(String role) =>
      kRoomHostLikeRoles.contains(normalizeRoomRole(role, fallbackRole: ''));

  /// Returns true if [role] grants stage management authority (cohost tier+).
  static bool isStageAuthority(String role) => kRoomStageManagementRoles
      .contains(normalizeRoomRole(role, fallbackRole: ''));

  /// Returns true if [role] grants moderation authority (moderator tier+).
  static bool isModerationAuthority(String role) =>
      kRoomModerationRoles.contains(normalizeRoomRole(role, fallbackRole: ''));

  /// Returns true if [role] allows mic seat occupancy.
  static bool hasMicAuthority(String role) =>
      kRoomMicRoles.contains(normalizeRoomRole(role, fallbackRole: ''));
}




