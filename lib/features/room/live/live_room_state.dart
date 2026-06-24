// lib/features/room/live/live_room_state.dart
//
// Immutable state for the cost-optimized multi-user video room.
//
// Phase machine:
//
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │                                                                      │
//  │  idle ──► joiningRoom ──► connectingVideo ──► active                │
//  │                                  │                │                 │
//  │                            (background)     (background)            │
//  │                                  └─────────►  suspended             │
//  │                                                   │                 │
//  │                                            (foreground)             │
//  │                                                   ▼                 │
//  │                                                active               │
//  │                                                                      │
//  │  Any phase ──► leaving ──► left                                     │
//  │  Any phase ──► error                                                │
//  └──────────────────────────────────────────────────────────────────────┘
//
// ───────────────────────────────────────────────────────────────────────────

import 'live_room_schema.dart';

// ── Phase ──────────────────────────────────────────────────────────────────

enum LiveRoomPhase {
  /// Initial state — not yet joined.
  idle,

  /// Writing participant doc, fetching video token — Firestore work in flight.
  joiningRoom,

  /// Firestore join done; video channel connection in progress.
  connectingVideo,

  /// Fully active: video channel open, visible tiles subscribed.
  active,

  /// App backgrounded: video subscriptions dropped, publishing paused.
  /// Video channel remains open. Presence stays alive.
  suspended,

  /// Leave sequence in progress — cleanup running.
  leaving,

  /// Fully exited. Safe to pop the screen.
  left,

  /// Error state — may be recoverable (shown in UI).
  error,
}

// ── State ──────────────────────────────────────────────────────────────────

class LiveRoomState {
  const LiveRoomState({
    required this.roomId,
    required this.localUserId,
    this.phase = LiveRoomPhase.idle,
    this.roomMeta,
    this.localRole = ParticipantRole.audience,
    this.participants = const [],
    this.visibleEngineUids = const [],
    this.subscribedEngineUids = const [],
    this.localEngineUid,
    this.isCamOn = false,
    this.isMicOn = false,
    this.isPublishingVideo = false,
    this.isPublishingAudio = false,
    this.isForegrounded = true,
    this.activeSpeakerUid,
    this.error,
    this.statusMessage,
  });

  final String roomId;
  final String localUserId;

  // ── Phase ────────────────────────────────────────────────────────────────
  final LiveRoomPhase phase;

  // ── Room metadata (mirrored from Firestore) ───────────────────────────────
  final RoomMeta? roomMeta;

  // ── Local user ────────────────────────────────────────────────────────────
  final String localRole; // ParticipantRole constant
  final int? localEngineUid; // Video engine integer uid
  final bool isCamOn; // Logical cam toggle (user intention)
  final bool isMicOn; // Logical mic toggle (user intention)
  final bool isPublishingVideo; // Engine actually streaming video
  final bool isPublishingAudio; // Engine actually streaming audio
  final bool isForegrounded;

  // ── Participant list (from Firestore) ─────────────────────────────────────
  final List<RoomParticipant> participants;

  // ── Subscription tracking ─────────────────────────────────────────────────

  /// Engine uids of tiles currently visible on screen (set by tile widget).
  final List<int> visibleEngineUids;

  /// Engine uids we are actively receiving video from.
  final List<int> subscribedEngineUids;

  // ── Speaker detection ─────────────────────────────────────────────────────
  final int? activeSpeakerUid;

  // ── Errors / progress messages ───────────────────────────────────────────
  final String? error;
  final String? statusMessage;

  // ── Computed helpers ──────────────────────────────────────────────────────

  bool get isIdle => phase == LiveRoomPhase.idle;
  bool get isJoining =>
      phase == LiveRoomPhase.joiningRoom ||
      phase == LiveRoomPhase.connectingVideo;
  bool get isActive => phase == LiveRoomPhase.active;
  bool get isSuspended => phase == LiveRoomPhase.suspended;
  bool get isLeaving => phase == LiveRoomPhase.leaving;
  bool get isLeft => phase == LiveRoomPhase.left;
  bool get hasError => phase == LiveRoomPhase.error;

  bool get isHost => localRole == ParticipantRole.host;
  bool get isBroadcaster =>
      localRole == ParticipantRole.broadcaster ||
      localRole == ParticipantRole.host;

  int get onCamCount => participants.where((p) => p.isOnCam).length;
  int get activeMicCount => participants.where((p) => p.isMicActive).length;

  /// Participants in the broadcaster grid (gridPosition ≥ 0).
  List<RoomParticipant> get gridParticipants =>
      participants.where((p) => p.isGridVisible).toList()
        ..sort((a, b) => a.gridPosition.compareTo(b.gridPosition));

  /// Participants in the audience row (gridPosition == -1).
  List<RoomParticipant> get audienceParticipants =>
      participants.where((p) => !p.isGridVisible).toList();

  /// Audience members who have raised their hand (requested a cam slot).
  List<RoomParticipant> get pendingRequests =>
      participants.where((p) => p.camRequestPending).toList();

  int get maxBroadcasters => roomMeta?.maxBroadcasters ?? 4;
  int get maxActiveMics => roomMeta?.maxActiveMics ?? 2;
  String get roomType => roomMeta?.type ?? RoomType.social;

  /// Video publishing is allowed only when all three conditions are true:
  ///   1. App is foregrounded
  ///   2. User has cam on
  ///   3. At least one subscriber exists (someone is watching)
  bool get canPublishVideo =>
      isForegrounded && isCamOn && isActive && subscribedEngineUids.isNotEmpty;

  // ── copyWith ──────────────────────────────────────────────────────────────

  LiveRoomState copyWith({
    LiveRoomPhase? phase,
    RoomMeta? roomMeta,
    String? localRole,
    int? localEngineUid,
    bool? isCamOn,
    bool? isMicOn,
    bool? isPublishingVideo,
    bool? isPublishingAudio,
    bool? isForegrounded,
    List<RoomParticipant>? participants,
    List<int>? visibleEngineUids,
    List<int>? subscribedEngineUids,
    int? activeSpeakerUid,
    String? error,
    String? statusMessage,
    bool clearError = false,
    bool clearActiveSpeaker = false,
    bool clearStatus = false,
  }) =>
      LiveRoomState(
        roomId: roomId,
        localUserId: localUserId,
        phase: phase ?? this.phase,
        roomMeta: roomMeta ?? this.roomMeta,
        localRole: localRole ?? this.localRole,
        localEngineUid: localEngineUid ?? this.localEngineUid,
        isCamOn: isCamOn ?? this.isCamOn,
        isMicOn: isMicOn ?? this.isMicOn,
        isPublishingVideo: isPublishingVideo ?? this.isPublishingVideo,
        isPublishingAudio: isPublishingAudio ?? this.isPublishingAudio,
        isForegrounded: isForegrounded ?? this.isForegrounded,
        participants: participants ?? this.participants,
        visibleEngineUids: visibleEngineUids ?? this.visibleEngineUids,
        subscribedEngineUids: subscribedEngineUids ?? this.subscribedEngineUids,
        activeSpeakerUid: clearActiveSpeaker
            ? null
            : (activeSpeakerUid ?? this.activeSpeakerUid),
        error: clearError ? null : (error ?? this.error),
        statusMessage:
            clearStatus ? null : (statusMessage ?? this.statusMessage),
      );

  @override
  String toString() =>
      'LiveRoomState(phase=$phase, cam=$isCamOn, mic=$isMicOn, '
      'participants=${participants.length}, '
      'subscribed=${subscribedEngineUids.length})';
}
