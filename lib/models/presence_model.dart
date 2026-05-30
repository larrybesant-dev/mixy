import 'package:cloud_firestore/cloud_firestore.dart';

enum UserStatus { online, away, dnd, offline }

enum PresenceAppState { foreground, background, detached, unknown }

class PresenceModel {
  PresenceModel({
    this.id,
    this.userId,
    this.isOnline,
    this.lastSeen,
    this.status = UserStatus.offline,
    this.inRoom,
    this.appState = PresenceAppState.unknown,
    this.activeSessionCount = 0,
    bool? online,
    String? roomId,
  }) : _online = online,
       _roomId = roomId;

  static const Duration staleThreshold = Duration(seconds: 60);

  final String? id;
  final String? userId;
  final bool? isOnline;
  final DateTime? lastSeen;
  final UserStatus status;
  final String? inRoom;
  final PresenceAppState appState;
  final int activeSessionCount;
  final bool? _online;
  final String? _roomId;

  bool get online => (_online ?? isOnline) == true;
  String? get roomId => _roomId ?? inRoom;

  static String? _asNullableString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static bool? _asNullableBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  static PresenceAppState _parseAppState(dynamic value) {
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'foreground':
          return PresenceAppState.foreground;
        case 'background':
          return PresenceAppState.background;
        case 'detached':
          return PresenceAppState.detached;
        default:
          return PresenceAppState.unknown;
      }
    }
    return PresenceAppState.unknown;
  }

  static UserStatus _parseStatus(dynamic value) {
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'online':
          return UserStatus.online;
        case 'away':
          return UserStatus.away;
        case 'dnd':
          return UserStatus.dnd;
        default:
          return UserStatus.offline;
      }
    }
    return UserStatus.offline;
  }

  factory PresenceModel.fromJson(Map<String, dynamic> json) {
    final status = _parseStatus(json['status'] ?? json['userStatus']);
    final explicitOnline =
        _asNullableBool(json['isOnline']) ?? _asNullableBool(json['online']);
    final inRoom = _asNullableString(json['inRoom'] ?? json['roomId']);
    final appState = _parseAppState(json['appState']);
    final activeSessionCount = _asInt(json['rtdbActiveSessionCount']);
    final lastSeen = _parseDateTime(
      json['lastSeen'] ?? json['lastActiveAt'] ?? json['lastHeartbeatAt'],
    );

    final resolvedOnline =
        (explicitOnline == true) ||
        activeSessionCount > 0 ||
        status != UserStatus.offline ||
        inRoom != null;

    final parsed = PresenceModel(
      id: _asNullableString(json['id']),
      userId: _asNullableString(json['userId']),
      isOnline: resolvedOnline,
      online: explicitOnline ?? (activeSessionCount > 0 ? true : null),
      lastSeen: lastSeen,
      status: resolvedOnline && status == UserStatus.offline
          ? UserStatus.online
          : status,
      inRoom: inRoom,
      roomId: inRoom,
      appState: appState,
      activeSessionCount: activeSessionCount,
    );

    return parsed.isStale
        ? parsed.copyWith(
            status: UserStatus.offline,
            isOnline: false,
            online: false,
            inRoom: null,
            roomId: null,
          )
        : parsed;
  }

  PresenceModel copyWith({
    String? id,
    String? userId,
    bool? isOnline,
    DateTime? lastSeen,
    UserStatus? status,
    String? inRoom,
    PresenceAppState? appState,
    int? activeSessionCount,
    bool? online,
    String? roomId,
    bool clearInRoom = false,
  }) {
    return PresenceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      inRoom: clearInRoom ? null : (inRoom ?? this.inRoom),
      appState: appState ?? this.appState,
      activeSessionCount: activeSessionCount ?? this.activeSessionCount,
      online: online ?? _online,
      roomId: clearInRoom ? null : (roomId ?? this.roomId),
    );
  }

  bool get isStale {
    if (status == UserStatus.offline || online != true) {
      return false;
    }
    final seenAt = lastSeen;
    if (seenAt == null) {
      return true;
    }
    return DateTime.now().difference(seenAt) > staleThreshold;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'isOnline': isOnline,
    'online': online,
    'lastSeen': lastSeen?.toIso8601String(),
    'status': status.name,
    'inRoom': inRoom,
    'appState': appState.name,
    'roomId': roomId,
    'rtdbActiveSessionCount': activeSessionCount,
  };
}



