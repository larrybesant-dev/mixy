// lib/features/room/live/live_room_schema.dart
//
// ── COST-OPTIMIZED MULTI-USER VIDEO ROOM ARCHITECTURE ──────────────────────
//
// FIRESTORE SCHEMA  (all collections are permanent — video channels are ephemeral)
//
//  /rooms/{roomId}
//    id               : String  — Firestore document ID
//    name             : String  — display name
//    type             : String  — 'social' | 'broadcast' | 'concert' | 'voice'
//    ownerId          : String  — creator uid
//    maxBroadcasters  : int     — max simultaneous camera slots
//    maxActiveMics    : int     — max simultaneous unmuted mics (1–4)
//    isActive         : bool    — room is open (can remain true 24/7)
//    videoChannelLive : bool    — true when ≥1 participant is in RoomScreen
//    participantCount : int     — cached count (updated on join/leave)
//    createdAt        : Timestamp
//    updatedAt        : Timestamp
//
//  /rooms/{roomId}/participants/{userId}
//    userId           : String
//    displayName      : String
//    avatarUrl        : String?
//    role             : String  — 'host' | 'broadcaster' | 'audience'
//    isOnCam          : bool    — user toggled cam on (logical/Firestore state)
//    isMicActive      : bool    — user toggled mic on (logical/Firestore state)
//    isStreaming      : bool    — video channel is actively publishing this stream
//    isForegrounded   : bool    — app is in foreground for this user
//    gridPosition     : int     — 0=host slot, 1–7=guest slots, -1=audience row
//    agoraUid         : int?    — video engine integer uid (set after token assigned)
//    joinedAt         : Timestamp
//    lastHeartbeat    : Timestamp
//
//  /presence/{userId}
//    userId           : String
//    status           : String  — 'online' | 'away' | 'offline'
//    currentRoomId    : String?
//    isForegrounded   : bool
//    lastSeen         : Timestamp
//
// ───────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Room type constants ─────────────────────────────────────────────────────

/// Room type identifiers stored in Firestore.
class RoomType {
  const RoomType._();

  /// Group conversation — 4 cams, 4 mics.
  static const social = 'social';

  /// Single streamer to many viewers — 1 cam, 1 mic.
  static const broadcast = 'broadcast';

  /// Performer room — 1 cam, 1 mic.
  static const concert = 'concert';

  /// Audio-only — 0 cams, 4 mics.
  static const voice = 'voice';
}

/// Max simultaneous active mics for a given room type.
int maxMicsForRoomType(String type) {
  switch (type) {
    case RoomType.social:
      return 4;
    case RoomType.broadcast:
      return 1;
    case RoomType.concert:
      return 1;
    case RoomType.voice:
      return 4;
    default:
      return 2;
  }
}

/// Max simultaneous camera broadcasters for a given room type.
int maxBroadcastersForRoomType(String type) {
  switch (type) {
    case RoomType.social:
      return 4;
    case RoomType.broadcast:
      return 1;
    case RoomType.concert:
      return 1;
    case RoomType.voice:
      return 0;
    default:
      return 2;
  }
}

// ── Participant roles ───────────────────────────────────────────────────────

class ParticipantRole {
  const ParticipantRole._();
  static const host = 'host';
  static const broadcaster = 'broadcaster';
  static const audience = 'audience';
}

// ── Firestore field-name constants ─────────────────────────────────────────

class RoomFields {
  const RoomFields._();
  static const id = 'id';
  static const name = 'name';
  static const type = 'type';
  static const ownerId = 'ownerId';
  static const maxBroadcasters = 'maxBroadcasters';
  static const maxActiveMics = 'maxActiveMics';
  static const isActive = 'isActive';
  static const videoChannelLive = 'videoChannelLive';
  static const participantCount = 'participantCount';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
}

class ParticipantFields {
  const ParticipantFields._();
  static const userId = 'userId';
  static const displayName = 'displayName';
  static const avatarUrl = 'avatarUrl';
  static const role = 'role';
  static const isOnCam = 'isOnCam';
  static const isMicActive = 'isMicActive';
  static const isStreaming = 'isStreaming';
  static const isForegrounded = 'isForegrounded';
  static const gridPosition = 'gridPosition';
  static const agoraUid = 'agoraUid';
  static const joinedAt = 'joinedAt';
  static const lastHeartbeat = 'lastHeartbeat';

  /// true when an audience member has requested a cam slot.
  static const camRequestPending = 'camRequestPending';
}

class PresenceFields {
  const PresenceFields._();
  static const userId = 'userId';
  static const status = 'status';
  static const currentRoomId = 'currentRoomId';
  static const isForegrounded = 'isForegrounded';
  static const lastSeen = 'lastSeen';
}

// ── Model: RoomMeta ─────────────────────────────────────────────────────────

/// Top-level room document — mirrors /rooms/{roomId}.
class RoomMeta {
  final String id;
  final String name;
  final String type;
  final String ownerId;
  final int maxBroadcasters;
  final int maxActiveMics;
  final bool isActive;
  final bool videoChannelLive;
  final int participantCount;

  const RoomMeta({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    required this.maxBroadcasters,
    required this.maxActiveMics,
    required this.isActive,
    required this.videoChannelLive,
    required this.participantCount,
  });

  factory RoomMeta.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final t = (d[RoomFields.type] as String?) ?? RoomType.social;
    // Resolve owner from whichever field was written at room creation.
    // Rooms may store the creator as 'ownerId', 'hostId', 'hostUid', or 'createdBy'.
    final ownerId = [
      d[RoomFields.ownerId],
      d['hostId'],
      d['hostUid'],
      d['createdBy'],
    ].whereType<String>().firstWhere((v) => v.isNotEmpty, orElse: () => '');
    return RoomMeta(
      id: doc.id,
      name: (d[RoomFields.name] as String?) ?? (d['title'] as String?) ?? '',
      type: t,
      ownerId: ownerId,
      maxBroadcasters: (d[RoomFields.maxBroadcasters] as int?) ??
          maxBroadcastersForRoomType(t),
      maxActiveMics:
          (d[RoomFields.maxActiveMics] as int?) ?? maxMicsForRoomType(t),
      isActive: (d[RoomFields.isActive] as bool?) ?? true,
      videoChannelLive: (d[RoomFields.videoChannelLive] as bool?) ?? false,
      participantCount: (d[RoomFields.participantCount] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        RoomFields.id: id,
        RoomFields.name: name,
        RoomFields.type: type,
        RoomFields.ownerId: ownerId,
        RoomFields.maxBroadcasters: maxBroadcasters,
        RoomFields.maxActiveMics: maxActiveMics,
        RoomFields.isActive: isActive,
        RoomFields.videoChannelLive: videoChannelLive,
        RoomFields.participantCount: participantCount,
        RoomFields.updatedAt: FieldValue.serverTimestamp(),
      };

  RoomMeta copyWith({
    bool? videoChannelLive,
    int? participantCount,
    bool? isActive,
  }) =>
      RoomMeta(
        id: id,
        name: name,
        type: type,
        ownerId: ownerId,
        maxBroadcasters: maxBroadcasters,
        maxActiveMics: maxActiveMics,
        isActive: isActive ?? this.isActive,
        videoChannelLive: videoChannelLive ?? this.videoChannelLive,
        participantCount: participantCount ?? this.participantCount,
      );
}

// ── Model: RoomParticipant ──────────────────────────────────────────────────

/// A single participant entry under /rooms/{roomId}/participants/{userId}.
class RoomParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final bool isOnCam; // logical state — user toggled cam on
  final bool isMicActive; // logical state — user toggled mic on
  final bool isStreaming; // video engine is actively publishing this stream
  final bool isForegrounded;
  final int gridPosition; // -1 = audience row
  final int? agoraUid; // video engine integer uid
  final bool camRequestPending; // audience member requested a cam slot
  final DateTime joinedAt;
  final DateTime lastHeartbeat;

  const RoomParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.isOnCam,
    required this.isMicActive,
    required this.isStreaming,
    required this.isForegrounded,
    required this.gridPosition,
    this.agoraUid,
    this.camRequestPending = false,
    required this.joinedAt,
    required this.lastHeartbeat,
  });

  factory RoomParticipant.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RoomParticipant(
      userId: (d[ParticipantFields.userId] as String?) ?? doc.id,
      displayName: (d[ParticipantFields.displayName] as String?) ?? 'Guest',
      avatarUrl: d[ParticipantFields.avatarUrl] as String?,
      role: (d[ParticipantFields.role] as String?) ?? ParticipantRole.audience,
      isOnCam: (d[ParticipantFields.isOnCam] as bool?) ?? false,
      isMicActive: (d[ParticipantFields.isMicActive] as bool?) ?? false,
      isStreaming: (d[ParticipantFields.isStreaming] as bool?) ?? false,
      isForegrounded: (d[ParticipantFields.isForegrounded] as bool?) ?? false,
      gridPosition: (d[ParticipantFields.gridPosition] as int?) ?? -1,
      agoraUid: d[ParticipantFields.agoraUid] as int?,
      camRequestPending:
          (d[ParticipantFields.camRequestPending] as bool?) ?? false,
      joinedAt: _toDateTime(d[ParticipantFields.joinedAt]) ?? DateTime.now(),
      lastHeartbeat:
          _toDateTime(d[ParticipantFields.lastHeartbeat]) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        ParticipantFields.userId: userId,
        ParticipantFields.displayName: displayName,
        ParticipantFields.avatarUrl: avatarUrl,
        ParticipantFields.role: role,
        ParticipantFields.isOnCam: isOnCam,
        ParticipantFields.isMicActive: isMicActive,
        ParticipantFields.isStreaming: isStreaming,
        ParticipantFields.isForegrounded: isForegrounded,
        ParticipantFields.gridPosition: gridPosition,
        ParticipantFields.agoraUid: agoraUid,
        ParticipantFields.camRequestPending: camRequestPending,
        ParticipantFields.joinedAt: FieldValue.serverTimestamp(),
        ParticipantFields.lastHeartbeat: FieldValue.serverTimestamp(),
      };

  RoomParticipant copyWith({
    bool? isOnCam,
    bool? isMicActive,
    bool? isStreaming,
    bool? isForegrounded,
    int? gridPosition,
    int? agoraUid,
    String? role,
    bool? camRequestPending,
  }) =>
      RoomParticipant(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: role ?? this.role,
        isOnCam: isOnCam ?? this.isOnCam,
        isMicActive: isMicActive ?? this.isMicActive,
        isStreaming: isStreaming ?? this.isStreaming,
        isForegrounded: isForegrounded ?? this.isForegrounded,
        gridPosition: gridPosition ?? this.gridPosition,
        agoraUid: agoraUid ?? this.agoraUid,
        camRequestPending: camRequestPending ?? this.camRequestPending,
        joinedAt: joinedAt,
        lastHeartbeat: lastHeartbeat,
      );

  bool get isGridVisible => gridPosition >= 0;

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  String toString() =>
      'RoomParticipant($userId, cam=$isOnCam, mic=$isMicActive, grid=$gridPosition)';
}
