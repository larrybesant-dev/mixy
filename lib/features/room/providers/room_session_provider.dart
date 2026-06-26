import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the UI state for the live room session (join status, media controls, participants).
class RoomSessionState {
  const RoomSessionState({
    required this.hasJoined,
    required this.isVideoEnabled,
    required this.isAudioEnabled,
    required this.isAudioSharingEnabled,
    required this.remoteUsers,
    required this.userDisplayNames,
  });

  /// Whether the current user has joined the room.
  final bool hasJoined;

  /// Whether the local video (camera) is enabled.
  final bool isVideoEnabled;

  /// Whether the local audio (microphone) is enabled.
  final bool isAudioEnabled;

  /// Whether audio sharing from system is enabled (for future use).
  final bool isAudioSharingEnabled;

  /// List of remote participant user IDs currently in the room.
  final List<String> remoteUsers;

  /// Cache of user display names by UID for quick lookups.
  final Map<String, String> userDisplayNames;

  RoomSessionState copyWith({
    bool? hasJoined,
    bool? isVideoEnabled,
    bool? isAudioEnabled,
    bool? isAudioSharingEnabled,
    List<String>? remoteUsers,
    Map<String, String>? userDisplayNames,
  }) {
    return RoomSessionState(
      hasJoined: hasJoined ?? this.hasJoined,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isAudioSharingEnabled: isAudioSharingEnabled ?? this.isAudioSharingEnabled,
      remoteUsers: remoteUsers ?? this.remoteUsers,
      userDisplayNames: userDisplayNames ?? this.userDisplayNames,
    );
  }

  @override
  String toString() =>
      'RoomSessionState(hasJoined: $hasJoined, isVideoEnabled: $isVideoEnabled, '
      'isAudioEnabled: $isAudioEnabled, isAudioSharingEnabled: $isAudioSharingEnabled, '
      'remoteUsers: $remoteUsers, userDisplayNames: $userDisplayNames)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoomSessionState &&
        other.hasJoined == hasJoined &&
        other.isVideoEnabled == isVideoEnabled &&
        other.isAudioEnabled == isAudioEnabled &&
        other.isAudioSharingEnabled == isAudioSharingEnabled &&
        _listEquals(other.remoteUsers, remoteUsers) &&
        _mapEquals(other.userDisplayNames, userDisplayNames);
  }

  @override
  int get hashCode =>
      hasJoined.hashCode ^
      isVideoEnabled.hashCode ^
      isAudioEnabled.hashCode ^
      isAudioSharingEnabled.hashCode ^
      remoteUsers.hashCode ^
      userDisplayNames.hashCode;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}

/// Manages the live room session state for a specific room.
/// 
/// This notifier consolidates all UI state (media controls, join status, participants)
/// into a single Riverpod source of truth to eliminate double rebuilds and improve
/// performance under WebRTC load.
class RoomSessionNotifier extends StateNotifier<RoomSessionState> {
  RoomSessionNotifier()
      : super(
          const RoomSessionState(
            hasJoined: false,
            isVideoEnabled: false,
            isAudioEnabled: false,
            isAudioSharingEnabled: false,
            remoteUsers: [],
            userDisplayNames: {},
          ),
        );

  /// Mark the user as joined/left the room.
  void setJoined(bool joined) {
    state = state.copyWith(hasJoined: joined);
  }

  /// Enable/disable local video.
  void setVideoEnabled(bool enabled) {
    state = state.copyWith(isVideoEnabled: enabled);
  }

  /// Enable/disable local audio.
  void setAudioEnabled(bool enabled) {
    state = state.copyWith(isAudioEnabled: enabled);
  }

  /// Enable/disable audio sharing.
  void setAudioSharingEnabled(bool enabled) {
    state = state.copyWith(isAudioSharingEnabled: enabled);
  }

  /// Update the list of remote participant UIDs.
  void setRemoteUsers(List<String> userIds) {
    state = state.copyWith(remoteUsers: userIds);
  }

  /// Add a remote participant.
  void addRemoteUser(String userId) {
    final updated = [...state.remoteUsers, userId];
    state = state.copyWith(remoteUsers: updated);
  }

  /// Remove a remote participant.
  void removeRemoteUser(String userId) {
    final updated = state.remoteUsers.where((id) => id != userId).toList();
    state = state.copyWith(remoteUsers: updated);
  }

  /// Update a user's display name.
  void updateDisplayName(String userId, String displayName) {
    final updated = {...state.userDisplayNames};
    updated[userId] = displayName;
    state = state.copyWith(userDisplayNames: updated);
  }

  /// Clear all session state (for leaving the room).
  void reset() {
    state = const RoomSessionState(
      hasJoined: false,
      isVideoEnabled: false,
      isAudioEnabled: false,
      isAudioSharingEnabled: false,
      remoteUsers: [],
      userDisplayNames: {},
    );
  }
}

/// Family provider for room session state, scoped by roomId.
/// 
/// Each room gets its own independent session state, which is useful if the user
/// is in multiple rooms (e.g., nested rooms or tabs).
final roomSessionProvider =
    StateNotifierProvider.family<RoomSessionNotifier, RoomSessionState, String>(
  (ref, roomId) => RoomSessionNotifier(),
);
