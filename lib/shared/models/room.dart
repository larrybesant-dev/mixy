import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomPrivacy { public, private }

enum RoomStatus { live, ended }

enum RoomType { text, voice, video }

/// Unified Room model supporting both legacy and new architecture
class Room {
  // Core fields
  final String id;
  final String title;
  final String description;
  final String hostId;
  final List<String> tags;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLive;
  final int viewerCount;

  // New architecture fields
  final List<String> admins; // Moderators who can manage room
  final int camCount; // Number of users on camera
  final bool isLocked; // Requires password to join
  final String? passwordHash; // Hashed password if locked
  final int maxUsers; // Room capacity
  final bool isNSFW; // Adult content flag
  final bool isHidden; // Hidden from public listings
  final int slowModeSeconds; // Message rate limiting (0 = disabled)

  // Legacy fields (kept for backward compatibility)
  final String? name; // Alias for title
  final List<String> participantIds; // Active participants
  final bool isActive; // Alias for isLive
  final String privacy; // 'public' or 'private'
  final String status; // 'live' or 'ended'
  final String? hostName; // Host display name
  final String? thumbnailUrl;
  final RoomType roomType;
  final List<String> moderators; // Legacy - use admins instead
  final List<String> bannedUsers;
  final List<String> mutedUsers;
  final List<String> kickedUsers;
  final String? agoraChannelName;
  final List<String> speakers;
  final List<String> listeners;
  final bool allowSpeakerRequests;
  final bool turnBased;
  final String? currentSpeakerId;
  final List<String> speakerQueue;
  final List<String> raisedHands;
  final int turnDurationSeconds;

  final List<String> activeBroadcasters; // UIDs of current broadcasters
  final int maxBroadcasters; // Max simultaneous broadcasters (default 20)

  // Sprint 2: Host/Moderator control state
  final List<String> removedUsers; // Users force-removed from room
  final bool isRoomLocked; // No new joins allowed
  final bool isRoomEnded; // Room is closed

  // ── Sprint 1: Vibe ─────────────────────────────────────────
  /// Vibe tag describing the room's energy (matches user VibeTag vocabulary).
  final String? vibeTag;

  /// Coarse energy bucket used for home-screen rails ("chill" | "high_energy").
  final String? energyLevel;

  // ── Sprint 4 Stubs: Monetisation Rails (feature-flagged off) ────────
  /// True when the room requires a paid ticket or VIP tier to enter.
  final bool isPremiumRoom;

  /// Access gate: "everyone" | "vip_only" | "subscribers_only"
  final String? accessTier;

  /// Boost score — higher value surfaces the room in recommended rails.
  final int boostScore;

  // ── Intelligence Layer ──────────────────────────────────────
  /// Number of new joins in the last 5 minutes — written by Cloud Function.
  /// Used to power the "Heating Up" rail on home/rooms pages.
  final int joinVelocity;

  // Getters for convenience properties
  int get currentMembers => participantIds.length;
  int get capacity => maxUsers;
  const Room({
    required this.id,
    required this.title,
    required this.description,
    required this.hostId,
    this.admins = const [],
    required this.tags,
    required this.category,
    required this.createdAt,
    DateTime? updatedAt,
    required this.isLive,
    required this.viewerCount,
    this.camCount = 0,
    this.isLocked = false,
    this.passwordHash,
    this.maxUsers = 200,
    this.isNSFW = false,
    this.isHidden = false,
    this.slowModeSeconds = 0,
    // Legacy fields
    this.name,
    this.participantIds = const [],
    bool? isActive,
    String? privacy,
    String? status,
    this.hostName,
    this.thumbnailUrl,
    RoomType? roomType,
    List<String>? moderators,
    this.bannedUsers = const [],
    this.mutedUsers = const [],
    this.kickedUsers = const [],
    this.agoraChannelName,
    this.speakers = const [],
    this.listeners = const [],
    this.allowSpeakerRequests = true,
    this.turnBased = false,
    this.currentSpeakerId,
    this.speakerQueue = const [],
    this.raisedHands = const [],
    this.turnDurationSeconds = 60,
    this.activeBroadcasters = const [],
    this.maxBroadcasters = 20,
    this.removedUsers = const [],
    this.isRoomLocked = false,
    this.isRoomEnded = false,
    // Sprint 1
    this.vibeTag,
    this.energyLevel,
    // Sprint 4 stubs
    this.isPremiumRoom = false,
    this.accessTier,
    this.boostScore = 0,
    // Intelligence layer
    this.joinVelocity = 0,
  })  : updatedAt = updatedAt ?? createdAt,
        isActive = isActive ?? isLive,
        privacy = privacy ?? (isLocked ? 'private' : 'public'),
        status = status ?? (isLive ? 'live' : 'ended'),
        roomType = roomType ?? RoomType.voice,
        moderators = moderators ?? admins;

  factory Room.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt'];
    final DateTime createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : createdAtValue is String
            ? DateTime.parse(createdAtValue)
            : DateTime.now();

    final updatedAtValue = json['updatedAt'];
    final DateTime updatedAt = updatedAtValue is Timestamp
        ? updatedAtValue.toDate()
        : updatedAtValue is String
            ? DateTime.parse(updatedAtValue)
            : createdAt;

    return Room(
      id: json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? '',
      name: json['name'] ?? json['title'],
      description: json['description'] ?? '',
      hostId: json['hostId'] ?? '',
      admins: List<String>.from(json['admins'] ?? json['moderators'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      category: json['category'] ?? 'Other',
      createdAt: createdAt,
      updatedAt: updatedAt,
      isLive: json['isLive'] ?? json['isActive'] ?? false,
      viewerCount: json['viewerCount'] ?? 0,
      camCount: json['camCount'] ?? 0,
      isLocked: json['isLocked'] ?? (json['privacy'] == 'private') ?? false,
      passwordHash: json['passwordHash'],
      maxUsers: json['maxUsers'] ?? 200,
      isNSFW: json['isNSFW'] ?? false,
      isHidden: json['isHidden'] ?? false,
      slowModeSeconds: json['slowModeSeconds'] ?? 0,
      // Legacy fields
      participantIds: List<String>.from(
          json['participantIds'] ?? json['participants'] ?? []),
      hostName: json['hostName'],
      thumbnailUrl: json['thumbnailUrl'],
      roomType: json['roomType'] != null
          ? RoomType.values.firstWhere(
              (e) => e.toString() == 'RoomType.${json['roomType']}',
              orElse: () => RoomType.voice,
            )
          : RoomType.voice,
      bannedUsers: List<String>.from(json['bannedUsers'] ?? []),
      mutedUsers: List<String>.from(json['mutedUsers'] ?? []),
      kickedUsers: List<String>.from(json['kickedUsers'] ?? []),
      agoraChannelName: json['agoraChannelName'],
      speakers: List<String>.from(json['speakers'] ?? []),
      listeners: List<String>.from(json['listeners'] ?? []),
      allowSpeakerRequests: json['allowSpeakerRequests'] ?? true,
      turnBased: json['turnBased'] as bool? ?? false,
      currentSpeakerId: json['currentSpeakerId'] as String?,
      speakerQueue: List<String>.from(json['speakerQueue'] ?? []),
      raisedHands: List<String>.from(json['raisedHands'] ?? []),
      turnDurationSeconds: json['turnDurationSeconds'] ?? 60,
      activeBroadcasters: List<String>.from(json['activeBroadcasters'] ?? []),
      maxBroadcasters: json['maxBroadcasters'] ?? 20,
      removedUsers: List<String>.from(json['removedUsers'] ?? []),
      isRoomLocked: json['isRoomLocked'] ?? false,
      isRoomEnded: json['isRoomEnded'] ?? false,
      // Sprint 1
      vibeTag: json['vibeTag'] as String?,
      energyLevel: json['energyLevel'] as String?,
      // Sprint 4 stubs
      isPremiumRoom: json['isPremiumRoom'] as bool? ?? false,
      accessTier: json['accessTier'] as String?,
      boostScore: json['boostScore'] as int? ?? 0,
      // Intelligence layer
      joinVelocity: json['joinVelocity'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'name': name ?? title,
      'description': description,
      'hostId': hostId,
      'admins': admins,
      'tags': tags,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isLive': isLive,
      'isActive': isActive,
      'viewerCount': viewerCount,
      'camCount': camCount,
      'isLocked': isLocked,
      'passwordHash': passwordHash,
      'maxUsers': maxUsers,
      'isNSFW': isNSFW,
      'isHidden': isHidden,
      'slowModeSeconds': slowModeSeconds,
      // Legacy fields
      'participantIds': participantIds,
      'privacy': privacy,
      'status': status,
      'hostName': hostName,
      'thumbnailUrl': thumbnailUrl,
      'roomType': roomType.toString().split('.').last,
      'moderators': moderators,
      'bannedUsers': bannedUsers,
      'mutedUsers': mutedUsers,
      'kickedUsers': kickedUsers,
      'agoraChannelName': agoraChannelName,
      'speakers': speakers,
      'listeners': listeners,
      'allowSpeakerRequests': allowSpeakerRequests,
      'turnBased': turnBased,
      'currentSpeakerId': currentSpeakerId,
      'speakerQueue': speakerQueue,
      'raisedHands': raisedHands,
      'turnDurationSeconds': turnDurationSeconds,
      'activeBroadcasters': activeBroadcasters,
      'maxBroadcasters': maxBroadcasters,
      'removedUsers': removedUsers,
      'isRoomLocked': isRoomLocked,
      'isRoomEnded': isRoomEnded,
      // Sprint 1
      'vibeTag': vibeTag,
      'energyLevel': energyLevel,
      // Sprint 4 stubs
      'isPremiumRoom': isPremiumRoom,
      'accessTier': accessTier,
      'boostScore': boostScore,
      // Intelligence layer
      'joinVelocity': joinVelocity,
    };
  }

  /// Firestore-compatible map (uses Timestamps)
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'hostId': hostId,
      'admins': admins,
      'tags': tags,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isLive': isLive,
      'viewerCount': viewerCount,
      'camCount': camCount,
      'isLocked': isLocked,
      'passwordHash': passwordHash,
      'maxUsers': maxUsers,
      'isNSFW': isNSFW,
      'isHidden': isHidden,
      'slowModeSeconds': slowModeSeconds,
      // Legacy fields for compatibility
      'name': name ?? title,
      'participantIds': participantIds,
      'isActive': isActive,
      'privacy': privacy,
      'status': status,
      'hostName': hostName,
      'thumbnailUrl': thumbnailUrl,
      'roomType': roomType.toString().split('.').last,
      'moderators': moderators,
      'bannedUsers': bannedUsers,
      'mutedUsers': mutedUsers,
      'kickedUsers': kickedUsers,
      'agoraChannelName': agoraChannelName,
      'speakers': speakers,
      'listeners': listeners,
      'allowSpeakerRequests': allowSpeakerRequests,
      'turnBased': turnBased,
      'currentSpeakerId': currentSpeakerId,
      'speakerQueue': speakerQueue,
      'raisedHands': raisedHands,
      'turnDurationSeconds': turnDurationSeconds,
      'activeBroadcasters': activeBroadcasters,
      'maxBroadcasters': maxBroadcasters,
      'removedUsers': removedUsers,
      'isRoomLocked': isRoomLocked,
      'isRoomEnded': isRoomEnded,
      // Sprint 1
      'vibeTag': vibeTag,
      'energyLevel': energyLevel,
      // Sprint 4 stubs
      'isPremiumRoom': isPremiumRoom,
      'accessTier': accessTier,
      'boostScore': boostScore,
      // Intelligence layer
      'joinVelocity': joinVelocity,
    };
  }

  Map<String, dynamic> toMap() {
    final map = toFirestore();
    map['id'] = id;
    // Convert Timestamps to ISO8601 strings for JSON compatibility
    if (map['createdAt'] is Timestamp) {
      map['createdAt'] =
          (map['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (map['updatedAt'] is Timestamp) {
      map['updatedAt'] =
          (map['updatedAt'] as Timestamp).toDate().toIso8601String();
    }
    return map;
  }

  factory Room.fromMap(Map<String, dynamic> map, [String? id]) {
    if (id != null) {
      map['id'] = id;
    }
    return Room.fromJson(map);
  }

  factory Room.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Room.fromMap(data);
  }

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Room.fromMap(data, doc.id);
  }

  /// Create a copy with updated fields
  Room copyWith({
    String? id,
    String? title,
    String? name,
    String? description,
    String? hostId,
    List<String>? admins,
    List<String>? tags,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isLive,
    int? viewerCount,
    int? camCount,
    bool? isLocked,
    String? passwordHash,
    int? maxUsers,
    bool? isNSFW,
    bool? isHidden,
    int? slowModeSeconds,
    List<String>? participantIds,
    String? hostName,
    String? thumbnailUrl,
    RoomType? roomType,
    List<String>? bannedUsers,
    String? agoraChannelName,
    List<String>? speakers,
    List<String>? listeners,
    bool? allowSpeakerRequests,
    bool? turnBased,
    String? currentSpeakerId,
    List<String>? speakerQueue,
    List<String>? raisedHands,
    int? turnDurationSeconds,
    List<String>? removedUsers,
    bool? isRoomLocked,
    bool? isRoomEnded,
    // Sprint 1
    String? vibeTag,
    String? energyLevel,
    // Sprint 4 stubs
    bool? isPremiumRoom,
    String? accessTier,
    int? boostScore,
    // Intelligence layer
    int? joinVelocity,
  }) {
    return Room(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      description: description ?? this.description,
      hostId: hostId ?? this.hostId,
      admins: admins ?? this.admins,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLive: isLive ?? this.isLive,
      viewerCount: viewerCount ?? this.viewerCount,
      camCount: camCount ?? this.camCount,
      isLocked: isLocked ?? this.isLocked,
      passwordHash: passwordHash ?? this.passwordHash,
      maxUsers: maxUsers ?? this.maxUsers,
      isNSFW: isNSFW ?? this.isNSFW,
      isHidden: isHidden ?? this.isHidden,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
      participantIds: participantIds ?? this.participantIds,
      hostName: hostName ?? this.hostName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      roomType: roomType ?? this.roomType,
      bannedUsers: bannedUsers ?? this.bannedUsers,
      agoraChannelName: agoraChannelName ?? this.agoraChannelName,
      speakers: speakers ?? this.speakers,
      listeners: listeners ?? this.listeners,
      allowSpeakerRequests: allowSpeakerRequests ?? this.allowSpeakerRequests,
      turnBased: turnBased ?? this.turnBased,
      currentSpeakerId: currentSpeakerId ?? this.currentSpeakerId,
      speakerQueue: speakerQueue ?? this.speakerQueue,
      raisedHands: raisedHands ?? this.raisedHands,
      turnDurationSeconds: turnDurationSeconds ?? this.turnDurationSeconds,
      removedUsers: removedUsers ?? this.removedUsers,
      isRoomLocked: isRoomLocked ?? this.isRoomLocked,
      isRoomEnded: isRoomEnded ?? this.isRoomEnded,
      // Sprint 1
      vibeTag: vibeTag ?? this.vibeTag,
      energyLevel: energyLevel ?? this.energyLevel,
      // Sprint 4 stubs
      isPremiumRoom: isPremiumRoom ?? this.isPremiumRoom,
      accessTier: accessTier ?? this.accessTier,
      boostScore: boostScore ?? this.boostScore,
      // Intelligence layer
      joinVelocity: joinVelocity ?? this.joinVelocity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
