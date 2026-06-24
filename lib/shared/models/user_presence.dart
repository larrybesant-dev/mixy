/// User Presence Model
///
/// Tracks real-time user presence across the app
/// Reference: DESIGN_BIBLE.md Section G.1 (Backend Integration)
/// Firestore Path: presence/{userId}
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// User presence state enum
enum PresenceState {
  online, // Active in a room
  idle, // App open but inactive
  away, // Away for > 5 min
  offline, // Not connected
}

/// Legacy presence status enum (kept for UI backward compatibility)
enum PresenceStatus {
  online,
  away,
  offline,
  busy,
}

/// Convert string to PresenceState
PresenceState presenceStateFromString(String value) {
  switch (value.toLowerCase()) {
    case 'online':
      return PresenceState.online;
    case 'idle':
      return PresenceState.idle;
    case 'away':
      return PresenceState.away;
    case 'offline':
      return PresenceState.offline;
    default:
      return PresenceState.offline;
  }
}

extension PresenceStateExtension on PresenceState {
  String get value {
    switch (this) {
      case PresenceState.online:
        return 'online';
      case PresenceState.idle:
        return 'idle';
      case PresenceState.away:
        return 'away';
      case PresenceState.offline:
        return 'offline';
    }
  }

  /// Visual indicator color for status
  String get displayText {
    switch (this) {
      case PresenceState.online:
        return '├░┼╕┼╕┬ó Online';
      case PresenceState.idle:
        return '├░┼╕┼╕┬í Idle';
      case PresenceState.away:
        return '├░┼╕ΓÇ¥┬┤ Away';
      case PresenceState.offline:
        return '├ó┼í┬½ Offline';
    }
  }
}

class UserPresence {
  /// Firestore user ID
  final String userId;

  /// Current presence state (online, idle, away, offline)
  final PresenceState state;

  /// Room ID if user is in a room (null if not online)
  final String? roomId;

  /// Room name for display
  final String? roomName;

  /// Last update timestamp
  final DateTime lastUpdate;

  /// Platform: 'web', 'android', 'ios'
  final String platform;

  /// Video publishing status
  final bool isPublishing;

  /// Audio mute status
  final bool isMuted;

  /// Video enabled status
  final bool isVideoEnabled;

  /// Active video window ID
  final String? activeWindowId;

  const UserPresence({
    required this.userId,
    required this.state,
    this.roomId,
    this.roomName,
    required this.lastUpdate,
    required this.platform,
    this.isPublishing = false,
    this.isMuted = false,
    this.isVideoEnabled = true,
    this.activeWindowId,
  });

  /// Create copy with optional field overrides
  UserPresence copyWith({
    String? userId,
    PresenceState? state,
    String? roomId,
    String? roomName,
    DateTime? lastUpdate,
    String? platform,
    bool? isPublishing,
    bool? isMuted,
    bool? isVideoEnabled,
    String? activeWindowId,
  }) {
    return UserPresence(
      userId: userId ?? this.userId,
      state: state ?? this.state,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      platform: platform ?? this.platform,
      isPublishing: isPublishing ?? this.isPublishing,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      activeWindowId: activeWindowId ?? this.activeWindowId,
    );
  }

  /// Convert to Firestore document (WITHOUT userId for /presence/{userId})
  Map<String, dynamic> toFirestore() {
    return {
      'state': state.value,
      'roomId': roomId,
      'roomName': roomName,
      'lastUpdate': Timestamp.fromDate(lastUpdate),
      'platform': platform,
      'isPublishing': isPublishing,
      'isMuted': isMuted,
      'isVideoEnabled': isVideoEnabled,
      'activeWindowId': activeWindowId,
    };
  }

  /// Create from Firestore document
  factory UserPresence.fromFirestore(
    String userId,
    Map<String, dynamic> data,
  ) {
    final timestamp = data['lastUpdate'] as Timestamp?;
    return UserPresence(
      userId: userId,
      state: presenceStateFromString(data['state'] ?? 'offline'),
      roomId: data['roomId'],
      roomName: data['roomName'],
      lastUpdate: timestamp?.toDate() ?? DateTime.now(),
      platform: data['platform'] ?? 'web',
      isPublishing: data['isPublishing'] ?? false,
      isMuted: data['isMuted'] ?? false,
      isVideoEnabled: data['isVideoEnabled'] ?? true,
      activeWindowId: data['activeWindowId'],
    );
  }

  /// Create from JSON
  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      userId: json['userId'] ?? '',
      state: presenceStateFromString(json['state'] ?? 'offline'),
      roomId: json['roomId'],
      roomName: json['roomName'],
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : DateTime.now(),
      platform: json['platform'] ?? 'web',
      isPublishing: json['isPublishing'] ?? false,
      isMuted: json['isMuted'] ?? false,
      isVideoEnabled: json['isVideoEnabled'] ?? true,
      activeWindowId: json['activeWindowId'],
    );
  }

  /// Whether user is actively online
  bool get isOnline => state == PresenceState.online;

  /// Whether user is idle or away
  bool get isInactive =>
      state == PresenceState.idle || state == PresenceState.away;

  /// Whether user is completely offline
  bool get isOffline => state == PresenceState.offline;

  /// Time since last activity
  Duration get inactivityDuration => DateTime.now().difference(lastUpdate);

  /// Legacy status getter for backward-compatible UI
  PresenceStatus get status {
    switch (state) {
      case PresenceState.online:
        return PresenceStatus.online;
      case PresenceState.idle:
        return PresenceStatus.busy;
      case PresenceState.away:
        return PresenceStatus.away;
      case PresenceState.offline:
        return PresenceStatus.offline;
    }
  }

  /// Create from Map (alias for fromJson)
  factory UserPresence.fromMap(String userId, Map<String, dynamic> data) =>
      UserPresence.fromFirestore(userId, data);

  @override
  String toString() =>
      'UserPresence($userId, state=$state, room=$roomId, publishing=$isPublishing, muted=$isMuted, video=$isVideoEnabled, lastUpdate=$lastUpdate)';
}
