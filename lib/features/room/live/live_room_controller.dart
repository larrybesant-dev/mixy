// lib/features/room/live/live_room_controller.dart
//
// Central orchestrator for the cost-optimized multi-user video room.
//
// Owns and coordinates:
//   • LiveRoomPresence  — Firebase layer (always active)
//   • LiveAgoraClient   — Video engine (active only when screen is open)
//   • LiveRoomAudioManager — Enforces mic limits
//
// Architecture rules enforced:
//   1.  Presence = Firestore only, never paused.
//   2.  Video = only when screen is in foreground.
//   3.  Never auto-subscribe — only setVisibleEngineUids() drives subscription.
//   4.  Background → drop subs + publishing; keep presence + channel.
//   5.  Publishing requires: foregrounded + cam on + ≥1 subscriber.
//   6.  Mic toggle enforces the 1–4 active mic rule per room type.
//   7.  Rooms exist 24/7; videoChannelLive flips only when ≥1 user is in room view.
// ───────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_room_schema.dart';
import 'live_room_state.dart';
import 'live_room_presence.dart';
import 'live_agora_client.dart';
import 'live_room_audio.dart';

// ── Provider args ─────────────────────────────────────────────────────────

class LiveRoomArgs {
  const LiveRoomArgs({
    required this.roomId,
    required this.displayName,
    this.avatarUrl,
  });
  final String roomId;
  final String displayName;
  final String? avatarUrl;
}

// ── Provider ──────────────────────────────────────────────────────────────

final liveRoomControllerProvider =
    NotifierProvider<LiveRoomController, LiveRoomState>(
  LiveRoomController.new,
);

// ── Controller ────────────────────────────────────────────────────────────

class LiveRoomController extends Notifier<LiveRoomState> {
  // ── Room args (set in enterRoom) ──────────────────────────────────────────
  LiveRoomArgs? _args;

  // ── Subsystems ────────────────────────────────────────────────────────────
  late LiveRoomPresence _presence;
  late LiveAgoraClient _video;
  late LiveRoomAudioManager _audio;

  // ── Stream subscriptions ──────────────────────────────────────────────────
  StreamSubscription<List<RoomParticipant>>? _participantSub;
  StreamSubscription<VideoEngineEvent>? _videoEventSub;
  StreamSubscription<DocumentSnapshot>? _roomMetaSub;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Exposes the underlying Agora engine for use in video rendering widgets.
  /// Returns null on web (web uses JS bridge separately).
  RtcEngine? get videoEngine {
    try {
      return _video.engine;
    } catch (_) {
      return null;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  LiveRoomState build() {
    ref.onDispose(_cleanup);
    return LiveRoomState(roomId: '', localUserId: _uid);
  }

  // ── Entry point ───────────────────────────────────────────────────────────

  /// Call once when the room screen mounts (after authentication is confirmed).
  Future<void> enterRoom(LiveRoomArgs args) async {
    if (!state.isIdle) return;
    _args = args;

    // Reset state with the correct roomId now that args are known
    state = LiveRoomState(
      roomId: args.roomId,
      localUserId: _uid,
      phase: LiveRoomPhase.joiningRoom,
      statusMessage: 'Joining room…',
    );

    try {
      // ── 1. Load room metadata ─────────────────────────────────────────
      final roomSnap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(_args!.roomId)
          .get();

      if (!roomSnap.exists) {
        state = state.copyWith(
          phase: LiveRoomPhase.error,
          error: 'Room not found.',
        );
        return;
      }

      final meta = RoomMeta.fromFirestore(roomSnap);

      // ── 2. Assign local role ──────────────────────────────────────────
      debugPrint('[ROOM_CTRL] ownerId="${meta.ownerId}" localUid="$_uid" match=${meta.ownerId == _uid}');
      final role = meta.ownerId == _uid
          ? ParticipantRole.host
          : ParticipantRole.audience;
      final gridPos = role == ParticipantRole.host ? 0 : -1;

      state = state.copyWith(
        roomMeta: meta,
        localRole: role,
        statusMessage: 'Registering presence…',
      );

      // ── 3. Create subsystems ──────────────────────────────────────────
      _audio = LiveRoomAudioManager.forRoomType(meta.type);

      _presence = LiveRoomPresence(
        roomId: _args!.roomId,
        roomType: meta.type,
        initialDisplayName: _args!.displayName,
        initialAvatarUrl: _args!.avatarUrl,
      );

      _video = LiveAgoraClient(roomType: meta.type);

      // ── 4. Join Firestore presence ────────────────────────────────────
      await _presence.join(role: role, gridPosition: gridPos);

      // ── 5. Subscribe to participant changes ───────────────────────────
      _participantSub = _presence.participantsStream.listen(
        _onParticipantsUpdated,
        onError: (e) => debugPrint('[ROOM_CTRL] participant stream error: $e'),
      );

      // ── 6. Watch room metadata changes ────────────────────────────────
      _roomMetaSub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(_args!.roomId)
          .snapshots()
          .listen(_onRoomMetaUpdated);

      // ── 7. Initialise and join video channel ──────────────────────────
      state = state.copyWith(
        phase: LiveRoomPhase.connectingVideo,
        statusMessage: 'Connecting video…',
      );

      await _video.initialize();

      _videoEventSub = _video.events.listen(
        _onVideoEvent,
        onError: (e) => debugPrint('[ROOM_CTRL] video event error: $e'),
      );

      await _video.joinChannel(
        channelId: _args!.roomId,
        userId: _uid,
        isBroadcaster: role == ParticipantRole.host,
      );

      // Flip videoChannelLive = true on the room doc (first user in)
      await _presence.setVideoChannelLive(true);

      // Hosts auto-enable cam
      if (role == ParticipantRole.host) {
        await _presence.setCamOn(true);
        state = state.copyWith(isCamOn: true);
      }

      state = state.copyWith(
        phase: LiveRoomPhase.active,
        clearError: true,
        clearStatus: true,
      );
    } catch (e, st) {
      debugPrint('[ROOM_CTRL] enterRoom error: $e\n$st');
      state = state.copyWith(
        phase: LiveRoomPhase.error,
        error: 'Could not join room: $e',
      );
    }
  }

  // ── Visibility-based subscription ─────────────────────────────────────────

  /// Called by the tile grid widget whenever the visible tile set changes.
  /// This is the sole mechanism that drives video subscriptions.
  Future<void> setVisibleEngineUids(List<int> uids) async {
    if (!state.isActive) return;
    state = state.copyWith(visibleEngineUids: uids);
    await _video.setVisibleUids(uids);
    state = state.copyWith(
      subscribedEngineUids: _video.subscribedUids.toList(),
    );
    await _enforcePublishRules();
  }

  // ── Cam toggle ────────────────────────────────────────────────────────────

  /// Returns null on success, or a user-facing error string on failure.
  Future<String?> toggleCam() async {
    if (!state.isActive) return 'Not in an active room.';
    // Audience members must go through the requestCam() flow instead.
    if (!state.isBroadcaster) return 'Request to go live first.';
    final meta = state.roomMeta;
    if (meta == null) return 'Room data not loaded.';

    final wantOn = !state.isCamOn;

    if (wantOn) {
      final decision = _audio.canTurnCamOn(
        userId: _uid,
        currentCamCount: state.onCamCount,
        maxCams: meta.maxBroadcasters,
      );
      if (!decision.allowed) return decision.reason;
    }

    await _presence.setCamOn(wantOn);
    state = state.copyWith(isCamOn: wantOn);
    await _enforcePublishRules();
    return null;
  }

  // ── Mic toggle ────────────────────────────────────────────────────────────

  /// Returns null on success, or a user-facing error string on failure.
  Future<String?> toggleMic() async {
    if (!state.isActive) return 'Not in an active room.';

    final wantOn = !state.isMicOn;

    if (wantOn) {
      final decision = _audio.canUnmute(_uid);
      if (!decision.allowed) return decision.reason;
    }

    await _presence.setMicActive(wantOn);
    state = state.copyWith(isMicOn: wantOn);

    if (wantOn) {
      await _video.startPublishingAudio();
      _audio.markMicActive(_uid);
      state = state.copyWith(isPublishingAudio: true);
    } else {
      await _video.stopPublishingAudio();
      _audio.markMicInactive(_uid);
      state = state.copyWith(isPublishingAudio: false);
    }
    return null;
  }

  // ── Cam request (audience ↔ broadcaster promotion) ──────────────────────

  /// Audience member signals they want a cam slot.
  Future<String?> requestCam() async {
    if (!state.isActive) return 'Not in an active room.';
    if (state.isBroadcaster) return null; // already on cam
    final meta = state.roomMeta;
    if (meta == null) return 'Room data not loaded.';
    if (state.onCamCount >= meta.maxBroadcasters) {
      return 'All cam slots are taken (${meta.maxBroadcasters} max).';
    }
    await _presence.setCamRequestPending(true);
    return null;
  }

  /// Cancel a pending cam request.
  Future<void> cancelCamRequest() async {
    if (!state.isActive) return;
    await _presence.setCamRequestPending(false);
  }

  /// Host approves a cam request — promotes the user to the next free grid slot.
  Future<String?> approveRequest(String userId) async {
    if (!state.isHost) return 'Only the host can approve requests.';
    final meta = state.roomMeta;
    if (meta == null) return 'Room data not loaded.';

    // Find the next free guest slot (0 = host, 1..maxBroadcasters-1 = guests)
    final occupied = state.participants
        .where((p) => p.gridPosition >= 0)
        .map((p) => p.gridPosition)
        .toSet();
    int? freeSlot;
    for (int i = 1; i < meta.maxBroadcasters; i++) {
      if (!occupied.contains(i)) {
        freeSlot = i;
        break;
      }
    }
    if (freeSlot == null) {
      return 'All cam slots are full \u2014 remove someone first.';
    }

    await _presence.promoteParticipant(
      userId,
      gridPosition: freeSlot,
      role: ParticipantRole.broadcaster,
    );
    return null;
  }

  /// Host denies a cam request — clears the pending flag.
  Future<void> denyRequest(String userId) async {
    if (!state.isHost) return;
    await _presence.denyParticipantRequest(userId);
  }

  /// Host removes a broadcaster from their cam slot (demotion).
  /// The demoted user is moved back to the audience row.
  Future<String?> demoteParticipant(String userId) async {
    if (!state.isHost) return 'Only the host can remove broadcasters.';
    if (userId == _uid) return 'Cannot demote yourself.';
    await _presence.demoteParticipant(userId);
    return null;
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  /// Call when the app is backgrounded / minimised / screen switches away.
  Future<void> onSuspended() async {
    if (!state.isActive && !state.isSuspended) return;
    state =
        state.copyWith(isForegrounded: false, phase: LiveRoomPhase.suspended);

    // Drop video subscriptions (stay in channel, just stop receiving)
    await _video.dropAllSubscriptions();
    // Stop publishing (save bandwidth + battery)
    await _video.dropPublishing();
    // Notify Firestore
    await _presence.setStreaming(false);
    await _presence.setForegrounded(false);

    state = state.copyWith(
      isPublishingVideo: false,
      isPublishingAudio: false,
      subscribedEngineUids: [],
    );
  }

  /// Call when the app returns to the foreground.
  Future<void> onResumed() async {
    if (!state.isSuspended) return;
    state = state.copyWith(isForegrounded: true, phase: LiveRoomPhase.active);
    await _presence.setForegrounded(true);

    // Restore subscriptions for currently visible tiles
    await _video.setVisibleUids(state.visibleEngineUids);
    state = state.copyWith(
      subscribedEngineUids: _video.subscribedUids.toList(),
    );
    await _enforcePublishRules();
  }

  // ── Leave room ────────────────────────────────────────────────────────────

  Future<void> leaveRoom() async {
    if (state.isLeaving || state.isLeft) return;
    state =
        state.copyWith(phase: LiveRoomPhase.leaving, statusMessage: 'Leaving…');

    // Stop video first
    await _video.dropPublishing();
    await _video.leaveChannel();

    // Flip videoChannelLive = false if this was the last participant
    await _presence.deactivateVideoChannelIfLast();

    // Remove Firestore presence
    await _presence.leave();

    state = state.copyWith(
      phase: LiveRoomPhase.left,
      clearStatus: true,
    );
  }

  // ── Publish rule enforcement ──────────────────────────────────────────────

  /// Re-evaluates whether video publishing should be active.
  /// Rule: publish only when foregrounded + cam on + ≥1 subscriber.
  Future<void> _enforcePublishRules() async {
    if (!state.isActive) return;

    final shouldPublish = state.isForegrounded &&
        state.isCamOn &&
        state.subscribedEngineUids.isNotEmpty;

    if (shouldPublish && !state.isPublishingVideo) {
      await _video.startPublishingVideo();
      await _presence.setStreaming(true);
      state = state.copyWith(isPublishingVideo: true);
    } else if (!shouldPublish && state.isPublishingVideo) {
      await _video.stopPublishingVideo();
      await _presence.setStreaming(false);
      state = state.copyWith(isPublishingVideo: false);
    }
  }

  // ── Firestore event handlers ──────────────────────────────────────────────

  void _onParticipantsUpdated(List<RoomParticipant> participants) {
    _audio.syncFromParticipants(participants);

    // Detect whether the local user's role or cam state changed in Firestore
    // (e.g. host promoted this user while they were audience).
    final localP = participants.where((p) => p.userId == _uid).firstOrNull;

    var updated = state.copyWith(participants: participants);

    if (localP != null) {
      final roleChanged = localP.role != state.localRole;
      final camChanged = localP.isOnCam != state.isCamOn;

      if (roleChanged) updated = updated.copyWith(localRole: localP.role);
      if (camChanged) updated = updated.copyWith(isCamOn: localP.isOnCam);

      state = updated;

      // When this user is freshly promoted, enforce publish rules so the
      // video engine switch from audience → broadcaster role happens
      // immediately the next time the user turns their cam on.
      if (roleChanged) _enforcePublishRules();
    } else {
      state = updated;
    }
  }

  void _onRoomMetaUpdated(DocumentSnapshot snap) {
    if (!snap.exists) {
      // Room document was deleted — gracefully leave
      debugPrint('[ROOM_CTRL] Room deleted while active — leaving.');
      state = state.copyWith(error: 'This room has been deleted.');
      leaveRoom();
      return;
    }
    final meta = RoomMeta.fromFirestore(snap);
    state = state.copyWith(roomMeta: meta);

    if (!meta.isActive && (state.isActive || state.isSuspended)) {
      // Room was closed by host/admin
      debugPrint('[ROOM_CTRL] Room deactivated — leaving.');
      state = state.copyWith(error: 'This room has been closed by the host.');
      leaveRoom();
    }
  }

  // ── Video engine event handler ────────────────────────────────────────────

  void _onVideoEvent(VideoEngineEvent event) {
    switch (event) {
      case EngineJoinedEvent(:final localUid):
        if (localUid != 0) {
          state = state.copyWith(localEngineUid: localUid);
          _presence.setVideoEngineUid(localUid);
        }

      case EngineLeftEvent():
        break;

      case RemoteUserJoinedEvent():
        // Subscription driven by setVisibleEngineUids — nothing to do here
        break;

      case RemoteUserLeftEvent(:final remoteUid):
        final updated = List<int>.from(state.subscribedEngineUids)
          ..remove(remoteUid);
        state = state.copyWith(subscribedEngineUids: updated);

      case RemoteVideoToggleEvent():
        break; // UI reacts via participant stream when needed

      case ActiveSpeakerEvent(:final speakerUid):
        state = state.copyWith(
          activeSpeakerUid: speakerUid,
          clearActiveSpeaker: speakerUid == null,
        );

      case EngineErrorEvent(:final message):
        debugPrint('[ROOM_CTRL] Video engine error: $message');
        // Non-fatal — log and surface to UI but don't kill the room
        state = state.copyWith(error: 'Video: $message');
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void _cleanup() {
    _participantSub?.cancel();
    _videoEventSub?.cancel();
    _roomMetaSub?.cancel();
    try {
      _presence.dispose();
    } catch (_) {}
    try {
      _video.dispose();
    } catch (_) {}
  }
}
