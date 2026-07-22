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

  /// Rank tier shown beside the user's display name in room roster/grid.
  final int rankTier;

  /// Diamond level shown beside the user's display name in room roster/grid.
  final int diamondLevel;

  /// Optional denormalized badge title (e.g. VIP, OG).
  final String? badgeTitle;

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
    this.rankTier = 0,
    this.diamondLevel = 0,
    this.badgeTitle,
    this.micExpiresAt,
  });

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

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
      rankTier: _asInt(map['rankTier']),
      diamondLevel: _asInt(map['diamondLevel']),
      badgeTitle: map['badgeTitle'] as String?,
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
      if (rankTier > 0) 'rankTier': rankTier,
      if (diamondLevel > 0) 'diamondLevel': diamondLevel,
      if (badgeTitle != null) 'badgeTitle': badgeTitle,
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
    int? rankTier,
    int? diamondLevel,
    String? badgeTitle,
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
      rankTier: rankTier ?? this.rankTier,
      diamondLevel: diamondLevel ?? this.diamondLevel,
      badgeTitle: badgeTitle ?? this.badgeTitle,
      micExpiresAt: micExpiresAt ?? this.micExpiresAt,
    );
  }
}



