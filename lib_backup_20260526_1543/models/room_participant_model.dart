import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseDateTimeField(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Returns true if [p] should be shown as actively talking.
/// Authority: [RoomParticipantModel.micOn] is set by the backend (grabMic CF
/// and RoomController) and is the single source of truth for on-mic state.
bool roomParticipantCanBeShownAsTalking(RoomParticipantModel p) => p.micOn;

class RoomParticipantModel {
  final String userId;
  final String role; // e.g. 'host', 'cohost', 'audience', 'stage'
  final bool isMuted;
  final bool isBanned;
  final bool camOn;
  final bool micOn;
  final String? customStatus;
  final String? userStatus;
  final String? displayName;
  final String? photoUrl;
  final DateTime joinedAt;
  final DateTime lastActiveAt;

  /// Set when the room owner has enabled a mic play-time limit.
  /// When DateTime.now() >= micExpiresAt the client demotes the user and
  /// the next grabMic call treats the doc as stale.
  final DateTime? micExpiresAt;

  RoomParticipantModel({
    required this.userId,
    required this.role,
    this.isMuted = false,
    this.isBanned = false,
    this.camOn = false,
    this.micOn = false,
    this.customStatus,
    this.userStatus,
    this.displayName,
    this.photoUrl,
    required this.joinedAt,
    required this.lastActiveAt,
    this.micExpiresAt,
  });

  factory RoomParticipantModel.fromMap(Map<String, dynamic> map) {
    return RoomParticipantModel(
      userId: map['userId'] ?? '',
      role: map['role'] ?? 'audience',
      isMuted: map['isMuted'] ?? false,
      isBanned: map['isBanned'] ?? false,
      camOn: map['camOn'] ?? false,
      micOn: map['micOn'] ?? false,
      customStatus: map['customStatus'] as String?,
      userStatus: map['userStatus'] as String?,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      joinedAt: (map['joinedAt'] is Timestamp)
          ? (map['joinedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['joinedAt']?.toString() ?? '') ??
              DateTime.now(),
      lastActiveAt: (map['lastActiveAt'] is Timestamp)
          ? (map['lastActiveAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['lastActiveAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      micExpiresAt: _parseDateTimeField(map['micExpiresAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final expiresAt = micExpiresAt;
    return {
      'userId': userId,
      'role': role,
      'isMuted': isMuted,
      'isBanned': isBanned,
      'camOn': camOn,
      'micOn': micOn,
      if (customStatus != null) 'customStatus': customStatus,
      if (userStatus != null) 'userStatus': userStatus,
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      if (expiresAt != null) 'micExpiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  RoomParticipantModel copyWith({
    String? userId,
    String? role,
    bool? isMuted,
    bool? isBanned,
    bool? camOn,
    bool? micOn,
    String? customStatus,
    String? userStatus,
    String? displayName,
    String? photoUrl,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    DateTime? micExpiresAt,
  }) {
    return RoomParticipantModel(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      isBanned: isBanned ?? this.isBanned,
      camOn: camOn ?? this.camOn,
      micOn: micOn ?? this.micOn,
      customStatus: customStatus ?? this.customStatus,
      userStatus: userStatus ?? this.userStatus,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      micExpiresAt: micExpiresAt ?? this.micExpiresAt,
    );
  }
}
