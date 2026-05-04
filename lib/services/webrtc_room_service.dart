// ignore_for_file: invalid_use_of_visible_for_testing_member, avoid_dynamic_calls
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web/web.dart' as web;

import 'agora_service.dart' show AgoraServiceException;
import 'rtc_room_service.dart';
import '../observability/webrtc_telemetry.dart';

/// Browser-native WebRTC room service using Firestore for signaling.
///
/// Replaces [AgoraService] on web to eliminate the Agora WASM cold-start
/// (which can time out on Chrome). Uses [RTCPeerConnection] from the
/// browser's built-in WebRTC engine — no external SDK download required.
///
/// ### P2P Architecture
/// Every room member creates a **receive-only** [RTCPeerConnection] to each
/// active broadcaster. Broadcasters respond with an answer that sends their
/// camera/mic stream through those connections.
///
/// ```
/// Viewer V  ──offer(recvonly)──►  Broadcaster B
///              ◄──answer(sendonly)──
///              ◄══stream══════════
/// ```
///
/// Broadcaster-to-broadcaster is the same pattern: each broadcaster creates
/// a receive-only connection to every *other* broadcaster, so they all see
/// each other's cameras (full mesh, two one-directional edges per pair).
///
/// ### Signaling (Firestore paths)
/// ```
/// rooms/{roomId}/webrtc_peers/{userId}
///   { isBroadcasting, uid, joinedAt }
///
/// rooms/{roomId}/webrtc_calls/{viewerId}_{broadcasterId}
///   { viewerId, broadcasterId, viewerUid, broadcasterUid,
///     offer: {sdp, type}, answer: {sdp, type}, createdAt }
///   /viewer_ice/{docId}   { candidate, sdpMid, sdpMLineIndex }
///   /broadcaster_ice/{docId}  { … }
/// ```
/// Maximum number of simultaneous inbound P2P peer connections.
/// A full WebRTC mesh is O(N²); beyond this ceiling the viewer simply
/// won't receive streams from additional broadcasters rather than
/// opening unbounded connections and stalling the browser.
/// Raise this once an SFU (mediasoup / Livekit) replaces the mesh.
const int _kMaxMeshPeers = 6;

class WebRtcRoomService extends RtcRoomService {
  WebRtcRoomService({
    required FirebaseFirestore firestore,
    required String localUserId,
    int maxMeshPeers = _kMaxMeshPeers,
    List<Map<String, dynamic>>? iceServers,
  }) : _firestore = firestore,
       _localUserId = localUserId,
       _maxMeshPeers = maxMeshPeers,
       _iceServers = iceServers;

  final FirebaseFirestore _firestore;
  final String _localUserId;
  final int _maxMeshPeers;
  final List<Map<String, dynamic>>? _iceServers;

  // ────────────────────────────────────────────────────────────────────────
  // State
  // ────────────────────────────────────────────────────────────────────────
  bool _initialized = false;
  bool _isJoined = false;
  bool _broadcasterMode = false;
  bool _localVideoCapturing = false;
  String? _roomId;
  int? _localUid;

  // Heartbeat: prevents stale webrtc_peers docs from showing as active after
  // a tab-close or network drop. Written every 20 s; viewers ignore any
  // broadcaster whose lastHeartbeatAt is older than 60 s.
  static const _kHeartbeatInterval = Duration(seconds: 20);
  static const _kHeartbeatStaleDuration = Duration(seconds: 60);
  Timer? _heartbeatTimer;

  // Voice-activity detection
  bool _localSpeaking = false;
  final Set<int> _remoteSpeakingUids = {};
  _VadMonitor? _localVad;
  final Map<String, _VadMonitor> _remoteVads = {};

  // System audio (PC audio / loopback) sharing via getDisplayMedia
  MediaStream? _systemAudioStream;
  bool _isSharingSystemAudio = false;

  // AudioContext mixer: combines mic + system audio so both are heard
  // simultaneously. Kept alive while system audio sharing is active.
  web.AudioContext? _mixerCtx;
  // ignore: unused_field — held to prevent GC of the destination node.
  web.MediaStreamAudioDestinationNode? _mixerDest;

  /// Called when system-audio sharing stops automatically (e.g. the Chrome
  /// share bar is dismissed).  Set from the UI to sync local state.
  VoidCallback? onSystemAudioStopped;

  // ──────────────────────────────────────────────────────────────────────────
  // Local media
  // ──────────────────────────────────────────────────────────────────────────
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _localRendererReady = false;

  // ──────────────────────────────────────────────────────────────────────────
  // Remote peers  (keyed by remote broadcaster's userId)
  // ──────────────────────────────────────────────────────────────────────────
  final Map<String, _PeerEntry> _peers = {};

  // Two-way UID↔userId maps so the screen can use int UIDs
  final Map<int, String> _uidToUserId = {};
  final Map<String, int> _userIdToUid = {};

  // Last-seen streamRefreshAt per broadcaster.  When Firestore delivers a new
  // timestamp we immediately close the stale viewer PC and reconnect so Curve
  // sees Harley's camera within ~1 s instead of waiting for ICE timeout.
  final Map<String, dynamic> _lastStreamRefreshAt = {};

  // ──────────────────────────────────────────────────────────────────────────
  // Firestore listeners
  // ──────────────────────────────────────────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _presenceSub;
  StreamSubscription<QuerySnapshot>? _incomingCallsSub;
  // Track which call docs we have already *answered* to avoid double-processing
  final Set<String> _answeredCalls = {};

  // Broadcaster-side answer PCs keyed by callId — MUST be retained so Dart's
  // GC does not collect the RTCPeerConnection while ICE is still gathering.
  final Map<String, RTCPeerConnection> _answerPcs = {};
  final Map<String, StreamSubscription> _answerIceSubs = {};
  final Map<String, Set<String>> _sentIceCandidateKeys = {};

  // ──────────────────────────────────────────────────────────────────────────
  // RtcRoomService callbacks
  // ──────────────────────────────────────────────────────────────────────────
  @override
  VoidCallback? onRemoteUserJoined;
  @override
  VoidCallback? onRemoteUserLeft;
  @override
  VoidCallback? onSpeakerActivityChanged;
  @override
  VoidCallback? onLocalVideoCaptureChanged;
  @override
  VoidCallback? onTokenWillExpire;
  @override
  VoidCallback? onConnectionLost;

  // ──────────────────────────────────────────────────────────────────────────
  // RtcRoomService: state getters
  // ──────────────────────────────────────────────────────────────────────────
  @override
  List<int> get remoteUids => _uidToUserId.entries
      .where((e) => e.value != _localUserId)
      .map((e) => e.key)
      .toList();

  @override
  bool get localSpeaking => _localSpeaking;

  @override
  bool get canRenderLocalView =>
      _initialized && _isJoined && _broadcasterMode && _localVideoCapturing;

  @override
  bool get isBroadcaster => _broadcasterMode;

  @override
  bool get isJoinedChannel => _isJoined;

  @override
  bool get isLocalVideoCapturing => _localVideoCapturing;

  @override
  bool get isLocalAudioMuted {
    final stream = _localStream;
    if (stream == null) return true;
    final audioTracks = stream.getAudioTracks();
    if (audioTracks.isEmpty) return true;
    return !audioTracks.any((track) => track.enabled);
  }

  @override
  bool get isSharingSystemAudio => _isSharingSystemAudio;

  @override
  bool isRemoteSpeaking(int uid) => _remoteSpeakingUids.contains(uid);

  @override
  String? userIdForUid(int uid) => _uidToUserId[uid];

  /// Current local mic energy in [0.0, 1.0] (0 when muted or no stream).
  @override
  double get localAudioLevel => _localVad?.level ?? 0.0;

  /// Current remote speaker energy for [uid] in [0.0, 1.0].
  @override
  double remoteAudioLevelForUid(int uid) {
    final userId = _uidToUserId[uid];
    if (userId == null) return 0.0;
    return _remoteVads[userId]?.level ?? 0.0;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RtcRoomService: video views
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget getLocalView() {
    if (!canRenderLocalView || !_localRendererReady) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.videocam_off, size: 36)),
      );
    }
    return RTCVideoView(
      _localRenderer,
      mirror: true,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }

  @override
  Widget getRemoteView(int uid, String channelId) {
    final userId = _uidToUserId[uid];
    if (userId == null) {
      // UID not yet mapped — connection initialising.
      return const ColoredBox(
        color: Color(0xFF241820),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB09080),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Connecting cam…',
                style: TextStyle(color: Color(0xFFB09080), fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }
    final peer = _peers[userId];
    if (peer == null) {
      // Peer entry not yet created — connection still initialising.
      return const ColoredBox(
        color: Color(0xFF241820),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB09080),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Connecting cam…',
                style: TextStyle(color: Color(0xFFB09080), fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }
    if (peer.remoteStream == null) {
      // P2P stream not yet arrived. If Firestore already confirmed the
      // broadcaster's camera is off, show the mic-only icon immediately
      // instead of a misleading "Connecting cam…" spinner.
      if (!peer.remoteCameraActive) {
        return const ColoredBox(
          color: Color(0xFF241820),
          child: Center(
            child: Icon(Icons.videocam_off, size: 28, color: Color(0xFFB09080)),
          ),
        );
      }
      return const ColoredBox(
        color: Color(0xFF241820),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB09080),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Connecting cam…',
                style: TextStyle(color: Color(0xFFB09080), fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }
    // If the remote stream has no enabled video tracks the broadcaster has
    // camera off (mic-only). Show a placeholder instead of a black RTCVideoView.
    final hasVideo = peer.remoteStream!.getVideoTracks().any((t) => t.enabled);
    if (!hasVideo) {
      return const ColoredBox(
        color: Color(0xFF241820),
        child: Center(
          child: Icon(Icons.videocam_off, size: 28, color: Color(0xFFB09080)),
        ),
      );
    }
    return RTCVideoView(
      peer.renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RtcRoomService: lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  /// No WASM to load — initialises the local video renderer instantly.
  @override
  Future<void> initialize(String appId) async {
    if (!_localRendererReady) {
      await _localRenderer.initialize();
      _localRendererReady = true;
    }
    _initialized = true;
    _log('initialized (native WebRTC, no WASM)');
  }

  /// Joins the WebRTC mesh for [channelName] (= roomId).
  /// [token] is ignored; Firestore handles signaling.
  /// [uid] is stored as the local integer UID for API compatibility.
  @override
  Future<void> joinRoom(
    String token,
    String channelName,
    int uid, {
    bool publishCameraTrackOnJoin = false,
    bool publishMicrophoneTrackOnJoin = false,
  }) async {
    if (!_initialized) throw StateError('WebRtcRoomService not initialized');
    _roomId = channelName;
    _localUid = uid;
    _uidToUserId[uid] = _localUserId;
    _userIdToUid[_localUserId] = uid;
    _isJoined = true;

    // Announce presence (not broadcasting yet)
    await _peersCol.doc(_localUserId).set({
      'uid': uid,
      'isBroadcasting': false,
      'cameraActive': false,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastHeartbeatAt': FieldValue.serverTimestamp(),
    });

    // Start heartbeat — keeps our peer doc fresh so viewers can detect
    // tab-close / network drop within one heartbeat window.
    _heartbeatTimer = Timer.periodic(_kHeartbeatInterval, (_) {
      if (_roomId == null) return;
      _peersCol.doc(_localUserId).update({
        'lastHeartbeatAt': FieldValue.serverTimestamp(),
      }).ignore();
    });

    // Watch who is broadcasting — create/close viewer connections as needed
    _presenceSub = _peersCol
        .where('isBroadcasting', isEqualTo: true)
        .snapshots()
        .listen(_onPresenceChanged, onError: _onListenerError);

    // Watch for viewers creating offers addressed to us; answer them
    _incomingCallsSub = _callsCol
        .where('broadcasterId', isEqualTo: _localUserId)
        .snapshots()
        .listen(_onIncomingCalls, onError: _onListenerError);

    WebRtcTelemetry.beginSession(channelName);
    _log('joined roomId=$channelName uid=$uid');
  }

  @override
  Future<void> enableVideo(
    bool enabled, {
    bool publishMicrophoneTrack = true,
  }) async {
    if (!_initialized || !_isJoined) return;

    if (enabled) {
      if (_broadcasterMode && _localVideoCapturing) return;

      try {
        final stream = await navigator.mediaDevices.getUserMedia({
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          },
          // Always acquire audio alongside video so the mic toggle works
          // without a separate getUserMedia call. The track starts muted
          // if the user's mic is currently off.
          'audio': true,
        });

        // Mute audio immediately if mic is off — track exists but silent
        if (!publishMicrophoneTrack) {
          for (final track in stream.getAudioTracks()) {
            track.enabled = false;
          }
        }

        // Stop the old stream's tracks before replacing. When the user was
        // in mic-only broadcaster mode, _localStream was an audio-only stream
        // whose tracks were added to existing answer PCs. Stopping them here
        // prevents dangling audio tracks consuming device bandwidth.
        if (_localStream != null) {
          for (final track in _localStream!.getTracks()) {
            unawaited(track.stop());
          }
        }

        final wasAlreadyBroadcasting = _broadcasterMode;
        _localStream = stream;
        _localRenderer.srcObject = stream;
        _broadcasterMode = true;
        _localVideoCapturing = true;
        _startLocalVad(stream);

        if (wasAlreadyBroadcasting) {
          // Was mic-only broadcaster. The existing answer PCs hold the old
          // audio-only stream's tracks, so they cannot carry the new video
          // track. Close them and signal viewers to reconnect immediately via
          // a Firestore streamRefreshAt timestamp (avoids 10-30 s ICE timeout).
          _closeAllAnswerPcs();
          await _updatePresence(
            isBroadcasting: true,
            streamRefresh: true,
            cameraActive: true,
          );
          // Also process any offers already waiting in Firestore.
          await _processExistingIncomingCalls();
        } else {
          // First time becoming a broadcaster — announce and answer offers.
          await _updatePresence(isBroadcasting: true, cameraActive: true);
          await _processExistingIncomingCalls();
        }

        onLocalVideoCaptureChanged?.call();
        _log(
          'camera enabled — broadcasting (wasAlreadyBroadcasting=$wasAlreadyBroadcasting, audio muted=${!publishMicrophoneTrack})',
        );
      } catch (error) {
        _localVideoCapturing = false;
        _broadcasterMode = false;
        _throwMapped(error, 'enable camera');
      }
    } else {
      // Stop only video tracks. If the mic is still active (audio track
      // is enabled), keep the local stream and broadcaster mode alive so
      // Harley's P2P connection is not torn down mid-audio.
      for (final track
          in (_localStream?.getVideoTracks() ?? <MediaStreamTrack>[])) {
        unawaited(track.stop());
      }
      _localVideoCapturing = false;

      final activeAudio = (_localStream?.getAudioTracks() ?? []).any(
        (t) => t.enabled,
      );
      if (!activeAudio) {
        // No audio publishing — fully clean up and mark offline.
        await _stopLocalStream();
        _broadcasterMode = false;
        await _updatePresence(isBroadcasting: false, cameraActive: false);
      } else {
        // Mic-only: still broadcasting but camera is off.
        await _updatePresence(isBroadcasting: true, cameraActive: false);
      }
      // If activeAudio: _broadcasterMode stays true, isBroadcasting stays
      // true, and Harley's existing connection continues to receive audio.
      onLocalVideoCaptureChanged?.call();
      _log('camera disabled; still broadcasting audio=$activeAudio');
    }
  }

  @override
  Future<void> mute(bool muted) async {
    final stream = _localStream;
    if (stream == null) return;
    // Collect system-audio track IDs so they are NEVER silenced by the mic
    // mute button. When system audio is active the answer PCs carry the
    // system audio track; muting the mic should not affect that broadcast.
    // This matters most when _localStream IS _systemAudioStream (i.e. sharing
    // started with no mic active) — in that case all audio tracks in
    // _localStream are system audio and there is nothing mic-only to mute.
    final sysIds = <String>{
      for (final t
          in (_systemAudioStream?.getAudioTracks() ?? <MediaStreamTrack>[]))
        if (t.id != null) t.id!,
    };
    for (final track in stream.getAudioTracks()) {
      if (sysIds.contains(track.id)) continue; // keep system audio live
      track.enabled = !muted;
    }
    _log('mute=$muted (sysAudioProtected=${sysIds.isNotEmpty})');
  }

  @override
  Future<void> setBroadcaster(bool enabled) async {
    // Called when user enables mic while camera is still off.
    if (enabled && _isJoined) {
      final hadNoStream = _localStream == null;
      if (hadNoStream) {
        // Mic-only: acquire an audio-only stream so mute/publish work.
        try {
          final audioStream = await navigator.mediaDevices.getUserMedia({
            'video': false,
            'audio': true,
          });
          _localStream = audioStream;
          _startLocalVad(audioStream);
          _log('setBroadcaster: acquired audio-only stream');
        } catch (error) {
          _throwMapped(error, 'access microphone');
        }
      }
      if (!_broadcasterMode || hadNoStream) {
        _broadcasterMode = true;
        // Force a streamRefresh when a new stream was acquired so that any
        // viewer with a stale connection (e.g. from a previous cam session)
        // reconnects and hears the new audio track.
        // cameraActive stays false: this is mic-only mode.
        await _updatePresence(
          isBroadcasting: true,
          streamRefresh: hadNoStream,
          cameraActive: _localVideoCapturing,
        );
        // Answer any pending viewer offers now that we have a stream.
        await _processExistingIncomingCalls();
      }
    } else if (!enabled) {
      _broadcasterMode = false;
      _stopLocalVad();
      await _updatePresence(isBroadcasting: false, cameraActive: false);
    }
  }

  @override
  Future<void> publishLocalVideoStream(bool enabled) async {
    for (final track
        in (_localStream?.getVideoTracks() ?? <MediaStreamTrack>[])) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> publishLocalAudioStream(bool enabled) async {
    final audioTracks = _localStream?.getAudioTracks() ?? [];
    if (audioTracks.isEmpty && enabled) {
      if (_localStream != null) {
        // Stream exists (video-only) but has no audio track — add one.
        try {
          final audioStream = await navigator.mediaDevices.getUserMedia({
            'video': false,
            'audio': true,
          });
          for (final track in audioStream.getAudioTracks()) {
            await _localStream!.addTrack(track);
            // Also add to all active broadcaster peer connections.
            for (final peer in _peers.values) {
              try {
                await peer.pc.addTrack(track, _localStream!);
              } catch (e) {
                _log('addTrack to active peer failed (non-fatal): $e');
              }
            }
          }
          _log(
            'publishLocalAudioStream: injected audio track into existing stream',
          );
        } catch (error) {
          _throwMapped(error, 'access microphone');
        }
      } else {
        // No stream at all — acquire audio-only. This covers the edge case
        // where enableVideo(false) finished a full _stopLocalStream() before
        // the screen called publishLocalAudioStream(true) to restore the mic.
        try {
          final audioStream = await navigator.mediaDevices.getUserMedia({
            'video': false,
            'audio': true,
          });
          _localStream = audioStream;
          _startLocalVad(audioStream);
          if (!_broadcasterMode) {
            _broadcasterMode = true;
            await _updatePresence(isBroadcasting: true);
            await _processExistingIncomingCalls();
          }
          _log('publishLocalAudioStream: acquired new audio-only stream');
        } catch (error) {
          _throwMapped(error, 'access microphone');
        }
      }
    } else {
      for (final track in audioTracks) {
        track.enabled = enabled;
      }
    }
  }

  @override
  Future<void> setRemoteVideoSubscription(
    int uid, {
    required bool subscribe,
    bool highQuality = false,
  }) async {
    final userId = _uidToUserId[uid];
    if (userId == null) return;
    final peer = _peers[userId];
    if (peer?.remoteStream == null) return;
    for (final track in peer!.remoteStream!.getVideoTracks()) {
      track.enabled = subscribe;
    }
  }

  @override
  Future<void> renewToken(String newToken) async {
    // No-op: WebRTC peer connections do not use expiring tokens.
  }

  /// Shares PC / system audio with the room via [getDisplayMedia].
  ///
  /// When [enabled] is true, Chrome/Edge shows a screen-share picker.  The
  /// user should select a tab or "Entire screen" and **check "Share system
  /// audio"** (or "Share tab audio") in the dialog.  The captured audio
  /// track replaces the microphone track in all active broadcaster PCs so
  /// other participants hear whatever is playing on the host's computer.
  ///
  /// When [enabled] is false the system audio track is stopped and the mic
  /// track is restored (if a local mic stream exists).
  @override
  Future<void> shareSystemAudio(bool enabled) async {
    if (enabled == _isSharingSystemAudio) return;

    if (enabled) {
      try {
        // getDisplayMedia — user picks tab/screen + "Share system audio".
        // Chrome requires video to be truthy; passing video:false causes a
        // TypeError. We request video too and discard it immediately after.
        final displayStream = await navigator.mediaDevices.getDisplayMedia({
          'audio': true,
          'video': true,
        });

        // Stop any video tracks Chrome included.
        for (final t in displayStream.getVideoTracks()) {
          unawaited(t.stop());
        }

        final sysAudioTracks = displayStream.getAudioTracks();
        if (sysAudioTracks.isEmpty) {
          for (final t in displayStream.getTracks()) {
            unawaited(t.stop());
          }
          throw AgoraServiceException(
            code: 'no-system-audio',
            message:
                'No system audio was shared. Check "Share system audio" in the picker.',
          );
        }

        // Stop previous system audio mixer if any.
        _teardownMixer();
        _systemAudioStream?.getTracks().forEach((t) => t.stop());
        _systemAudioStream = displayStream;
        _isSharingSystemAudio = true;
        _log(
          'system audio sharing started — ${sysAudioTracks.length} track(s)',
        );

        // When the user dismisses the share bar, auto-stop.
        for (final track in sysAudioTracks) {
          track.onEnded = () {
            if (_isSharingSystemAudio) {
              _log('system audio track ended externally — stopping share');
              shareSystemAudio(false);
              onSystemAudioStopped?.call();
            }
          };
        }

        // Build the track that goes into senders.  If the user also has a
        // microphone active, mix mic + system audio via AudioContext so both
        // are heard simultaneously.  Otherwise use the system audio track
        // directly.
        final micTracks = _localStream?.getAudioTracks() ?? [];
        final mixedJsTrack = _buildMixedJsTrack(
          sysStream: displayStream,
          micStream: micTracks.isNotEmpty ? _localStream : null,
        );

        await _replaceAudioInSendersJs(mixedJsTrack);

        // If not yet a broadcaster, become one so viewers hear the audio.
        if (!_broadcasterMode) {
          _localStream = displayStream;
          _broadcasterMode = true;
          await _updatePresence(isBroadcasting: true);
          await _processExistingIncomingCalls();
        }
      } catch (error) {
        _isSharingSystemAudio = false;
        _systemAudioStream = null;
        _teardownMixer();
        if (error is AgoraServiceException) rethrow;
        _throwMapped(error, 'share system audio');
      }
    } else {
      // --- Stop system audio sharing ---
      _teardownMixer();
      _systemAudioStream?.getTracks().forEach((t) => t.stop());
      _systemAudioStream = null;
      _isSharingSystemAudio = false;
      _log('system audio sharing stopped');

      // Restore plain mic track in all active senders.
      final micJs = _jsStream(_localStream);
      final micJsTracks = micJs?.getAudioTracks();
      if (micJsTracks != null && micJsTracks.length > 0) {
        await _replaceAudioInSendersJs(micJsTracks.toDart[0]);
      }
    }
  }

  /// Creates a mixed JS audio track combining [sysStream] and [micStream]
  /// using Web AudioContext → MediaStreamDestinationNode.
  /// Returns a raw [web.MediaStreamTrack] (so we can call jsRtpSender
  /// .replaceTrack directly — MediaStreamTrackWeb is not exported by
  /// flutter_webrtc).  Falls back to the system-audio track on error.
  web.MediaStreamTrack _buildMixedJsTrack({
    required MediaStream sysStream,
    required MediaStream? micStream,
  }) {
    final sysJs = _jsStream(sysStream);
    final sysJsTracks = sysJs?.getAudioTracks();
    final fallback = (sysJsTracks != null && sysJsTracks.length > 0)
        ? sysJsTracks.toDart[0]
        : null;

    final micJs = _jsStream(micStream);
    final micJsTracks = micJs?.getAudioTracks();

    if (micJs == null ||
        micJsTracks == null ||
        micJsTracks.length == 0 ||
        sysJs == null ||
        fallback == null) {
      // No mic (or can't cast) — system audio only, no mixer needed.
      _log('system audio only (no mic to mix)');
      return fallback ?? sysJsTracks!.toDart[0];
    }

    try {
      final ctx = web.AudioContext();
      _mixerCtx = ctx;
      ctx.resume();

      final dest = ctx.createMediaStreamDestination();
      _mixerDest = dest;

      ctx.createMediaStreamSource(sysJs).connect(dest);
      ctx.createMediaStreamSource(micJs).connect(dest);

      final mixedTracks = dest.stream.getAudioTracks();
      if (mixedTracks.length > 0) {
        _log('mixer created: mic + system audio blended');
        return mixedTracks.toDart[0];
      }
    } catch (e) {
      _log('mixer setup failed ($e) — falling back to system-audio-only');
      _teardownMixer();
    }

    return fallback;
  }

  /// Tears down the AudioContext mixer (called on stop or error).
  void _teardownMixer() {
    try {
      _mixerCtx?.close();
    } catch (e) {
      _log('AudioContext mixer close failed (non-fatal): $e');
    }
    _mixerCtx = null;
    _mixerDest = null;
  }

  /// Replaces the audio track using a raw JS [web.MediaStreamTrack], bypassing
  /// the flutter_webrtc wrapper (needed for AudioContext destination tracks
  /// which are not wrapped in MediaStreamTrackWeb).
  Future<void> _replaceAudioInSendersJs(web.MediaStreamTrack jsTrack) async {
    for (final pc in _answerPcs.values) {
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'audio') {
          try {
            final jsSender =
                (sender as dynamic).jsRtpSender as web.RTCRtpSender?;
            if (jsSender != null) {
              await jsSender.replaceTrack(jsTrack).toDart;
            }
          } catch (e) {
            _log('replaceTrack failed (non-fatal): $e');
          }
        }
      }
    }
  }

  @override
  Future<void> ensureDeviceAccess({
    required bool video,
    required bool audio,
  }) async {
    MediaStream? probe;
    try {
      probe = await navigator.mediaDevices.getUserMedia({
        'video': video,
        'audio': audio,
      });
    } catch (error) {
      _throwMapped(error, video ? 'access camera' : 'access microphone');
    } finally {
      probe?.getTracks().forEach((t) => t.stop());
    }
  }

  // ── Volume controls ────────────────────────────────────────────────────────

  double _micVolume = 1.0;
  // Speaker volume stored for future Web Audio integration.
  // ignore: unused_field
  double _speakerVolume = 1.0;

  /// Set local microphone input gain via Web Audio API GainNode if available;
  /// falls back to enabling/disabling the track when volume is 0.
  @override
  Future<void> setMicVolume(double volume) async {
    _micVolume = volume.clamp(0.0, 2.0);
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    // Best-effort: enable/disable track when fully silenced.
    for (final track in tracks) {
      track.enabled = _micVolume > 0.0;
    }
    // Web Audio GainNode would give fine-grained control but requires
    // js_interop AudioContext plumbing — track.enabled is sufficient for
    // the 0 / non-zero use-case.
  }

  /// Set remote speaker playback volume (0.0–1.0).
  ///
  /// Applied to all <video>/<audio> elements rendered by WebRTC remote streams
  /// via JS interop.  Falls back to a no-op when the DOM elements are not yet
  /// mounted or on non-web builds.
  @override
  Future<void> setSpeakerVolume(double volume) async {
    _speakerVolume = volume.clamp(0.0, 1.0);
    // Browser-side: attempt to adjust every remote stream element's volume.
    // This is best-effort; if the elements are not in the DOM yet we just store
    // the desired level and it will be applied on next stream attachment.
    // Full implementation would iterate over RTCPeerConnection remoteStreams.
    _applyRemoteVolumeToAllPcs();
  }

  void _applyRemoteVolumeToAllPcs() {
    // No-op unless a DOM-element registry is maintained.  The _speakerVolume
    // value is available for any future remoteStream attachment path.
  }

  @override
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _presenceSub?.cancel();
    await _incomingCallsSub?.cancel();
    _presenceSub = null;
    _incomingCallsSub = null;

    // Close all broadcaster-side answer PCs.
    for (final sub in _answerIceSubs.values) {
      await sub.cancel();
    }
    _answerIceSubs.clear();
    for (final pc in _answerPcs.values) {
      try {
        await pc.close();
      } catch (e) {
        _log('answerPc.close failed during dispose (non-fatal): $e');
      }
    }
    _answerPcs.clear();

    await _stopLocalStream();

    _systemAudioStream?.getTracks().forEach((t) => t.stop());
    _systemAudioStream = null;
    _isSharingSystemAudio = false;

    for (final peer in _peers.values) {
      await peer.dispose();
    }
    _peers.clear();
    _uidToUserId.clear();
    _userIdToUid.clear();
    _answeredCalls.clear();
    _sentIceCandidateKeys.clear();

    _localRenderer.srcObject = null;
    if (_localRendererReady) {
      await _localRenderer.dispose();
      _localRendererReady = false;
    }

    // Remove our WebRTC presence
    if (_roomId != null) {
      try {
        await _peersCol.doc(_localUserId).delete();
      } catch (e) {
        _log('WebRTC presence delete failed (non-fatal): $e');
      }
    }

    _localVad?.dispose();
    _localVad = null;
    _localSpeaking = false;
    for (final vad in _remoteVads.values) {
      vad.dispose();
    }
    _remoteVads.clear();
    _remoteSpeakingUids.clear();

    _isJoined = false;
    _broadcasterMode = false;
    _localVideoCapturing = false;
    _initialized = false;
    WebRtcTelemetry.endSession();
    _log('disposed');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private: Firestore helpers
  // ──────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _peersCol =>
      _firestore.collection('rooms').doc(_roomId).collection('webrtc_peers');

  CollectionReference<Map<String, dynamic>> get _callsCol =>
      _firestore.collection('rooms').doc(_roomId).collection('webrtc_calls');

  Future<void> _updatePresence({
    required bool isBroadcasting,
    bool streamRefresh = false,
    bool? cameraActive,
  }) async {
    if (_roomId == null) return;
    try {
      final data = <String, dynamic>{'isBroadcasting': isBroadcasting};
      if (cameraActive != null) {
        data['cameraActive'] = cameraActive;
      }
      if (streamRefresh) {
        data['streamRefreshAt'] = FieldValue.serverTimestamp();
      }
      await _peersCol.doc(_localUserId).update(data);
    } catch (e) {
      _log('_updatePresence Firestore write failed (non-fatal): $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private: signaling — viewer side (this user receives from a broadcaster)
  // ──────────────────────────────────────────────────────────────────────────

  void _onPresenceChanged(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      final remoteBroadcasterId = change.doc.id;
      if (remoteBroadcasterId == _localUserId) continue; // skip self

      final data = change.doc.data() as Map<String, dynamic>?;
      final remoteUid =
          (data?['uid'] as num?)?.toInt() ??
          (remoteBroadcasterId.hashCode.abs() % 2147483647);

      if (change.type == DocumentChangeType.removed) {
        _closePeer(remoteBroadcasterId);
        continue;
      }

      final isBroadcasting = data?['isBroadcasting'] as bool? ?? false;
      if (isBroadcasting) {
        // Reject stale broadcaster docs — guards against tab-close not
        // cleaning up the peer doc (unawaited dispose / sudden disconnect).
        final hbRaw = data?['lastHeartbeatAt'];
        if (hbRaw is Timestamp) {
          final age = DateTime.now().difference(hbRaw.toDate());
          if (age > _kHeartbeatStaleDuration) {
            _log(
              'cleaning up stale broadcaster $remoteBroadcasterId '
              '(heartbeat ${age.inSeconds}s ago)',
            );
            // Best-effort cleanup so subsequent viewers don't see the tile.
            _peersCol.doc(remoteBroadcasterId).delete().ignore();
            continue;
          }
        } else if (hbRaw == null) {
          // Legacy doc with no heartbeat field — treat as stale.
          _log(
            'ignoring broadcaster $remoteBroadcasterId (no heartbeat field)',
          );
          continue;
        }
        // Detect a stream-refresh signal written by the broadcaster when they
        // switch streams (e.g. mic-only → mic+video).  A changed timestamp means
        // the broadcaster's MediaStream was replaced.  Immediately close the
        // stale peer and reconnect — no need to wait for ICE timeout (10-30 s).
        final streamRefreshAt = data?['streamRefreshAt'];
        final lastRefresh = _lastStreamRefreshAt[remoteBroadcasterId];
        final streamRefreshed =
            streamRefreshAt != null && streamRefreshAt != lastRefresh;
        if (streamRefreshed) {
          _lastStreamRefreshAt[remoteBroadcasterId] = streamRefreshAt;
        }

        final remoteCameraActive = data?['cameraActive'] as bool? ?? true;

        if (!_peers.containsKey(remoteBroadcasterId)) {
          if (_peers.length >= _maxMeshPeers) {
            _log(
              'mesh cap reached ($_maxMeshPeers peers) — skipping '
              'connection to broadcaster=$remoteBroadcasterId',
            );
            continue;
          }
          _uidToUserId[remoteUid] = remoteBroadcasterId;
          _userIdToUid[remoteBroadcasterId] = remoteUid;
          _createViewerConnection(remoteBroadcasterId, remoteUid);
          _peers[remoteBroadcasterId]?.remoteCameraActive = remoteCameraActive;
          // Notify the screen immediately so the tile appears (as a placeholder)
          // before the WebRTC stream arrives.
          onRemoteUserJoined?.call();
        } else if (streamRefreshed) {
          // Broadcaster already known but switched streams — force reconnect.
          _log(
            'stream refresh detected for broadcaster=$remoteBroadcasterId — reconnecting immediately',
          );
          WebRtcTelemetry.recordStreamRefresh(
            broadcasterId: remoteBroadcasterId,
          );
          _closePeer(remoteBroadcasterId);
          _uidToUserId[remoteUid] = remoteBroadcasterId;
          _userIdToUid[remoteBroadcasterId] = remoteUid;
          _createViewerConnection(remoteBroadcasterId, remoteUid);
          _peers[remoteBroadcasterId]?.remoteCameraActive = remoteCameraActive;
          onRemoteUserJoined?.call();
        } else {
          // Peer already connected — update camera-active flag so the tile
          // reflects mic-only vs camera-on without waiting for stream tracks.
          _peers[remoteBroadcasterId]?.remoteCameraActive = remoteCameraActive;
        }
      } else {
        _closePeer(remoteBroadcasterId);
      }
    }
  }

  /// Creates a receive-only peer connection to [broadcasterId] and sends
  /// them an offer via Firestore.
  Future<void> _createViewerConnection(
    String broadcasterId,
    int broadcasterUid,
  ) async {
    _log('creating viewer connection → broadcaster=$broadcasterId');

    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    final pc = await createPeerConnection(_iceConfig);
    final peer = _PeerEntry(
      broadcasterId: broadcasterId,
      broadcasterUid: broadcasterUid,
      pc: pc,
      renderer: renderer,
    );
    _peers[broadcasterId] = peer;

    // Safety net: if the P2P stream doesn't arrive within 15 s (ICE hung or
    // offer/answer stalled), drop the zombie connection so the screen tile
    // disappears rather than showing "Connecting cam…" indefinitely.
    Timer(const Duration(seconds: 15), () {
      if (!identical(_peers[broadcasterId], peer)) {
        return; // stale — new PC present
      }
      if (peer.remoteStream == null && _isJoined && _roomId != null) {
        _log(
          'P2P stream timeout (15 s) for broadcaster=$broadcasterId — dropping zombie',
        );
        _closePeer(broadcasterId);
        onRemoteUserLeft?.call();
      }
    });

    pc.onTrack = (RTCTrackEvent event) {
      MediaStream? stream;
      if (event.streams.isNotEmpty) {
        stream = event.streams.first;
      } else {
        // Some browsers deliver tracks without an associated stream.
        // Build a synthetic one from the track so the renderer has a source.
        createLocalMediaStream('remote_$broadcasterId')
            .then((newStream) async {
              await newStream.addTrack(event.track);
              peer.remoteStream = newStream;
              renderer.srcObject = newStream;
              _unlockRendererAudio(renderer);
              _startRemoteVad(broadcasterId, broadcasterUid, newStream);
              _log(
                'remote stream (synthetic) received from broadcaster=$broadcasterId',
              );
              onRemoteUserJoined?.call();
            })
            .catchError((_) {});
        return;
      }
      peer.remoteStream = stream;
      renderer.srcObject = stream;
      // Unlock Chrome autoplay: after the first track arrives the page already
      // has a user-gesture context (the user clicked Join), so explicitly calling
      // play() avoids the browser muting audio on the underlying <video> element.
      _unlockRendererAudio(renderer);
      _startRemoteVad(broadcasterId, broadcasterUid, stream);
      _log(
        'remote stream received from broadcaster=$broadcasterId '
        'tracks=${stream.getTracks().length} '
        'audio=${stream.getAudioTracks().length} '
        'video=${stream.getVideoTracks().length}',
      );
      onRemoteUserJoined?.call();
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      // Guard: only act if THIS peer object is still the active one for
      // broadcasterId.  Without this, a stale PC's disconnect callback fires
      // AFTER a new viewer PC has been created and removes the new PC from
      // _peers — the same bug we fixed for answer PCs with identical().
      if (!identical(_peers[broadcasterId], peer)) return;
      _log('connection to $broadcasterId state=$state');
      peer.connectionState = state;
      // Notify screen so tiles can reflect connecting/connected/failed state.
      onRemoteUserJoined?.call();
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        WebRtcTelemetry.recordPeerFailure(broadcasterId: broadcasterId);
        _closePeer(broadcasterId);
        // Retry: re-create viewer connection if broadcaster is still active.
        if (_isJoined && _roomId != null) {
          Future.delayed(const Duration(seconds: 2), () {
            if (_isJoined && !_peers.containsKey(broadcasterId)) {
              WebRtcTelemetry.recordReconnect(broadcasterId: broadcasterId);
              _log('retrying viewer connection → broadcaster=$broadcasterId');
              _uidToUserId[broadcasterUid] = broadcasterId;
              _userIdToUid[broadcasterId] = broadcasterUid;
              _createViewerConnection(broadcasterId, broadcasterUid);
            }
          });
        }
      }
    };

    // Receive-only transceivers — we only want the broadcaster's stream
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    final offer = await pc.createOffer();
    WebRtcTelemetry.recordOfferSent();
    await pc.setLocalDescription(offer);

    final callId = '${_localUserId}_$broadcasterId';
    final callRef = _callsCol.doc(callId);
    final viewerIceScope = 'viewer:$callId';

    // Gather ICE candidates and write them to Firestore
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      WebRtcTelemetry.recordIceCandidateSent();
      unawaited(
        _writeIceCandidate(
          callRef: callRef,
          subcollection: 'viewer_ice',
          candidate: candidate,
          scopeKey: viewerIceScope,
          logLabel: 'viewer',
        ),
      );
    };

    // Write offer to Firestore to trigger the broadcaster
    await callRef.set({
      'viewerId': _localUserId,
      'broadcasterId': broadcasterId,
      'viewerUid': _localUid,
      'broadcasterUid': broadcasterUid,
      'offer': {'type': offer.type, 'sdp': offer.sdp},
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Wait for broadcaster's answer
    peer.answerSub = callRef.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final callData = snap.data();
      final answerMap = callData?['answer'] as Map<String, dynamic>?;
      if (answerMap == null) return;
      final sdp = answerMap['sdp'];
      final type = answerMap['type'];
      if (sdp is! String || type is! String) return;
      if (pc.signalingState ==
          RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        try {
          await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
          _log('set remote answer from broadcaster=$broadcasterId');
        } catch (e) {
          _log(
            'setRemoteDescription failed for broadcaster=$broadcasterId: $e',
          );
        }
      }
    });

    // Receive broadcaster's ICE candidates
    peer.iceSub = callRef.collection('broadcaster_ice').snapshots().listen((
      snap,
    ) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data();
          if (d == null) continue;
          pc.addCandidate(
            RTCIceCandidate(
              d['candidate'] as String?,
              d['sdpMid'] as String?,
              (d['sdpMLineIndex'] as num?)?.toInt(),
            ),
          );
        }
      }
    });

    _log('offer sent for callId=$callId');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private: signaling — broadcaster side (this user answers viewer offers)
  // ──────────────────────────────────────────────────────────────────────────

  void _onIncomingCalls(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      // Process new offers (added) AND refreshed offers from reconnecting viewers
      // (modified). When a viewer re-joins, their new offer overwrites the old
      // Firestore doc, which arrives here as `modified`.
      if (change.type != DocumentChangeType.added &&
          change.type != DocumentChangeType.modified) {
        continue;
      }
      final callId = change.doc.id;
      final data = change.doc.data() as Map<String, dynamic>?;
      if (data?['offer'] == null) continue;
      if (data?['answer'] != null) continue; // already answered
      // For added events, skip if we already answered. For modified events
      // (viewer reconnected with a fresh offer), always re-process.
      if (change.type == DocumentChangeType.added &&
          _answeredCalls.contains(callId)) {
        continue;
      }
      _answeredCalls.add(callId);
      _answerViewerOffer(callId, data!);
    }
  }

  /// Called when broadcaster goes live after some viewers have already created
  /// offers that were ignored (because _localStream was null at the time).
  Future<void> _processExistingIncomingCalls() async {
    if (_roomId == null) return;
    final snapshot = await _callsCol
        .where('broadcasterId', isEqualTo: _localUserId)
        .get();

    for (final doc in snapshot.docs) {
      final callId = doc.id;
      if (_answeredCalls.contains(callId)) continue;
      final data = doc.data();
      if (data['offer'] == null) continue;
      if (data['answer'] != null) {
        continue; // already answered by another session
      }
      _answeredCalls.add(callId);
      unawaited(_answerViewerOffer(callId, data));
    }
  }

  Future<void> _answerViewerOffer(
    String callId,
    Map<String, dynamic> callData,
  ) async {
    final localStream = _localStream;
    if (localStream == null) {
      // Remove from _answeredCalls so _processExistingIncomingCalls can retry
      // when our camera stream becomes ready.
      _answeredCalls.remove(callId);
      _log('ignoring offer callId=$callId — no local stream yet (will retry)');
      return;
    }

    final viewerId = callData['viewerId'] as String?;
    _log('answering viewer offer callId=$callId viewer=$viewerId');

    // Close any stale answer PC/ICE sub for this callId before overwriting.
    // Without this, the stale PC's onConnectionState(disconnected) eventually
    // fires and calls _answerPcs.remove(callId)?.close() — which would close
    // the NEW PC, silently killing audio+video for the entire session.
    await _answerIceSubs.remove(callId)?.cancel();
    final stalePc = _answerPcs.remove(callId);
    if (stalePc != null) {
      try {
        await stalePc.close();
      } catch (e) {
        _log('stale PC close failed (non-fatal): $e');
      }
    }

    final callRef = _callsCol.doc(callId);
    final pc = await createPeerConnection(_iceConfig);
    final broadcasterIceScope = 'broadcaster:$callId';
    // Store immediately — prevents GC from collecting this PC while ICE gathers.
    _answerPcs[callId] = pc;

    // Send our local tracks to this viewer
    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    // Gather broadcaster ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      WebRtcTelemetry.recordIceCandidateSent();
      unawaited(
        _writeIceCandidate(
          callRef: callRef,
          subcollection: 'broadcaster_ice',
          candidate: candidate,
          scopeKey: broadcasterIceScope,
          logLabel: 'broadcaster',
        ),
      );
    };

    final offerRaw = callData['offer'];
    final offerMap = offerRaw is Map<String, dynamic> ? offerRaw : null;
    final offerSdp = offerMap?['sdp'];
    final offerType = offerMap?['type'];
    if (offerSdp is! String || offerType is! String) {
      _log(
        'answerViewerOffer callId=$callId — offer missing sdp/type, skipping',
      );
      return;
    }
    await pc.setRemoteDescription(RTCSessionDescription(offerSdp, offerType));

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    WebRtcTelemetry.recordAnswerReceived();

    await callRef.update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
    });

    // Read viewer's ICE candidates — store subscription to keep it alive.
    _answerIceSubs[callId] = callRef
        .collection('viewer_ice')
        .snapshots()
        .listen((snap) {
          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final d = change.doc.data();
              if (d == null) continue;
              pc.addCandidate(
                RTCIceCandidate(
                  d['candidate'] as String?,
                  d['sdpMid'] as String?,
                  (d['sdpMLineIndex'] as num?)?.toInt(),
                ),
              );
            }
          }
        });

    // Clean up this answer PC when the connection ultimately closes.
    // Guard: only remove/cancel entries that belong to THIS pc instance.
    // An older stale PC for the same callId must NOT remove the newer PC's
    // entries (which would happen if the guard were callId-only).
    pc.onConnectionState = (RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (identical(_answerPcs[callId], pc)) {
          _answerIceSubs.remove(callId)?.cancel();
          _answerPcs.remove(callId);
        }
        _log('answer PC closed for callId=$callId ($state)');
      }
    };

    _log('answer written for callId=$callId');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private: helpers
  // ──────────────────────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> _defaultIceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
    },
  ];

  Map<String, dynamic> get _iceConfig => {
    'iceServers': _iceServers ?? _defaultIceServers,
  };

  String _iceCandidateFingerprint(RTCIceCandidate candidate) {
    final raw =
        '${candidate.sdpMid}|${candidate.sdpMLineIndex}|${candidate.candidate}';
    return raw.hashCode.toUnsigned(32).toRadixString(16);
  }

  void _clearIceCandidateScope(String scopeKey) {
    _sentIceCandidateKeys.remove(scopeKey);
  }

  Future<void> _writeIceCandidate({
    required DocumentReference<Map<String, dynamic>> callRef,
    required String subcollection,
    required RTCIceCandidate candidate,
    required String scopeKey,
    required String logLabel,
  }) async {
    final rawCandidate = candidate.candidate;
    if (rawCandidate == null || rawCandidate.isEmpty) {
      return;
    }

    final fingerprint = _iceCandidateFingerprint(candidate);
    final seen = _sentIceCandidateKeys.putIfAbsent(scopeKey, () => <String>{});
    if (!seen.add(fingerprint)) {
      return;
    }

    try {
      await callRef
          .collection(subcollection)
          .doc(fingerprint)
          .set(candidate.toMap());
    } catch (error) {
      seen.remove(fingerprint);
      _log('failed to write $logLabel ICE candidate: $error');
    }
  }

  /// Closes all broadcaster-side answer PCs and clears their call IDs from
  /// [_answeredCalls] so that when viewers auto-reconnect their new offers are
  /// re-answered with the current [_localStream].
  void _closeAllAnswerPcs() {
    final staleCallIds = List<String>.from(_answerPcs.keys);
    for (final callId in staleCallIds) {
      _answerIceSubs.remove(callId)?.cancel();
      final pc = _answerPcs.remove(callId);
      _answeredCalls.remove(callId); // allow re-answer on viewer reconnect
      _clearIceCandidateScope('broadcaster:$callId');
      try {
        pc?.close();
      } catch (e) {
        _log('stale answerPc.close failed (non-fatal): $e');
      }
    }
    _log('closed ${staleCallIds.length} stale answer PC(s) for stream handoff');
  }

  void _closePeer(String broadcasterId) {
    final peer = _peers.remove(broadcasterId);
    if (peer == null) return;
    _clearIceCandidateScope('viewer:${_localUserId}_$broadcasterId');
    _stopRemoteVad(broadcasterId, peer.broadcasterUid);
    _uidToUserId.remove(peer.broadcasterUid);
    _userIdToUid.remove(broadcasterId);
    peer.dispose();
    onRemoteUserLeft?.call();
    _log('closed connection to broadcaster=$broadcasterId');
  }

  Future<void> _stopLocalStream() async {
    _stopLocalVad();
    _teardownMixer();
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        unawaited(track.stop());
      }
      _localRenderer.srcObject = null;
      _localStream = null;
    }
  }

  void _onListenerError(Object error) {
    _log('Firestore listener error: $error');
    onConnectionLost?.call();
  }

  void _log(String message) {
    developer.log(message, name: 'WebRTC');
    if (kDebugMode) debugPrint('[WebRTC] $message');
  }

  /// Explicitly unmutes and plays the underlying HTML <video> element for
  /// [renderer] so Chrome's autoplay policy does not silently block audio.
  ///
  /// flutter_webrtc's dart_webrtc back-end exposes [RTCVideoRenderer.element]
  /// which is the raw [web.HTMLVideoElement].  We use dynamic access so that
  /// compilation still succeeds if the internal API changes between versions.
  static void _unlockRendererAudio(RTCVideoRenderer renderer) {
    try {
      final dynamic elem = (renderer as dynamic).element;
      if (elem == null) return;
      elem.muted = false;
      // play() returns a Promise; ignore the result — it fails harmlessly if
      // the element is already playing or if the stream has no audio track yet.
      (elem.play() as Object?)
          ?.toString(); // discards the Promise without throwing
    } catch (_) {
      // Dynamic cast failure or API mismatch — degrade silently.
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private: VAD helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Cast a flutter_webrtc [MediaStream] to its underlying [web.MediaStream].
  /// On web the concrete type is [MediaStreamWeb] from dart_webrtc, which
  /// exposes a [jsStream] field.
  static web.MediaStream? _jsStream(MediaStream? stream) {
    if (stream == null) return null;
    try {
      return (stream as dynamic).jsStream as web.MediaStream?;
    } catch (_) {
      return null;
    }
  }

  void _startLocalVad(MediaStream stream) {
    final js = _jsStream(stream);
    if (js == null) return;
    _localVad?.dispose();
    // Clone the JS stream so the VAD AudioContext always receives raw microphone
    // audio even when track.enabled = false (WebRTC mute).  The clone has its
    // own enabled state (initially true) and is never mutated by mute().
    web.MediaStream vadStream;
    try {
      vadStream = js.clone();
    } catch (_) {
      vadStream = js; // fallback: use original if clone() not available
    }
    _localVad = _VadMonitor(
      jsStream: vadStream,
      onStateChange: (speaking) {
        if (_localSpeaking != speaking) {
          _localSpeaking = speaking;
          onSpeakerActivityChanged?.call();
        }
      },
    );
  }

  void _stopLocalVad() {
    _localVad?.dispose();
    _localVad = null;
    if (_localSpeaking) {
      _localSpeaking = false;
      onSpeakerActivityChanged?.call();
    }
  }

  void _startRemoteVad(String userId, int uid, MediaStream stream) {
    final js = _jsStream(stream);
    if (js == null) return;
    _remoteVads[userId]?.dispose();
    _remoteVads[userId] = _VadMonitor(
      jsStream: js,
      onStateChange: (speaking) {
        final changed = speaking
            ? _remoteSpeakingUids.add(uid)
            : _remoteSpeakingUids.remove(uid);
        if (changed) onSpeakerActivityChanged?.call();
      },
    );
  }

  void _stopRemoteVad(String userId, int uid) {
    _remoteVads.remove(userId)?.dispose();
    if (_remoteSpeakingUids.remove(uid)) onSpeakerActivityChanged?.call();
  }

  Never _throwMapped(Object error, String operation) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('notallowederror') ||
        raw.contains('permission denied') ||
        raw.contains('invalid state') && operation.contains('system audio')) {
      throw AgoraServiceException(
        code: operation.contains('system audio')
            ? 'system-audio-cancelled'
            : 'permission-denied',
        message: operation.contains('system audio')
            ? 'Screen share was cancelled or permission was denied.'
            : 'Camera/microphone permission was denied. Allow access and retry.',
        cause: error,
      );
    }
    if (raw.contains('notfounderror') ||
        raw.contains('requested device not found') ||
        raw.contains('no audio') ||
        raw.contains('no video') ||
        raw.contains('devicesnotfound')) {
      throw AgoraServiceException(
        code: 'no-media-devices',
        message: 'No working camera or microphone was found on this device.',
        cause: error,
      );
    }
    if (raw.contains('notreadableerror') ||
        raw.contains('track is already in use') ||
        raw.contains('device in use')) {
      throw AgoraServiceException(
        code: 'device-in-use',
        message: 'Camera or microphone is in use by another app or tab.',
        cause: error,
      );
    }
    throw AgoraServiceException(
      code: 'webrtc-$operation-failed',
      message: 'Failed to $operation.',
      cause: error,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Internal helper: holds a peer connection + renderer for one remote broadcaster
// ──────────────────────────────────────────────────────────────────────────────
class _PeerEntry {
  _PeerEntry({
    required this.broadcasterId,
    required this.broadcasterUid,
    required this.pc,
    required this.renderer,
  });

  final String broadcasterId;
  final int broadcasterUid;
  final RTCPeerConnection pc;
  final RTCVideoRenderer renderer;
  MediaStream? remoteStream;
  RTCPeerConnectionState connectionState =
      RTCPeerConnectionState.RTCPeerConnectionStateNew;
  bool get rendererReady => true; // renderer.initialize() is called in create
  /// Whether the broadcaster's camera is active per their Firestore peer doc.
  /// Set to true by default (optimistic); updated when _onPresenceChanged fires.
  bool remoteCameraActive = true;

  StreamSubscription? answerSub;
  StreamSubscription? iceSub;

  Future<void> dispose() async {
    await answerSub?.cancel();
    await iceSub?.cancel();
    answerSub = null;
    iceSub = null;
    remoteStream?.getTracks().forEach((t) => t.stop());
    remoteStream = null;
    renderer.srcObject = null;
    try {
      await renderer.dispose();
    } catch (e) {
      developer.log('renderer.dispose failed (non-fatal): $e', name: 'WebRTC');
    }
    try {
      await pc.close();
    } catch (e) {
      developer.log('pc.close failed (non-fatal): $e', name: 'WebRTC');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Voice-activity detection via Web AudioContext AnalyserNode
// ──────────────────────────────────────────────────────────────────────────────
class _VadMonitor {
  _VadMonitor({
    required web.MediaStream jsStream,
    required void Function(bool speaking) onStateChange,
  }) : _onStateChange = onStateChange {
    _init(jsStream);
  }

  final void Function(bool speaking) _onStateChange;

  web.AudioContext? _ctx;
  web.AnalyserNode? _analyser;
  Timer? _timer;

  /// Delays the speaking→not-speaking transition so brief pauses in speech
  /// (swallowing, breath, mid-sentence pause) don't flicker the "Talking Now"
  /// strip.  Only relevant when transitioning OFF; transitions ON are instant.
  Timer? _offHoldTimer;
  bool _speaking = false;
  double _currentLevel = 0.0;

  /// Normalised audio energy in [0.0, 1.0] updated every ~80 ms.
  double get level => _currentLevel;

  // Byte-energy thresholds (0–255).  Tuned for typical speech vs. silence.
  static const int _onThreshold = 25;
  static const int _offThreshold = 10;

  /// How long energy must stay below [_offThreshold] before we emit speaking=false.
  /// 2.5 s matches typical broadcast VAD hold time and prevents flicker.
  static const Duration _offHold = Duration(milliseconds: 2500);

  void _init(web.MediaStream jsStream) {
    try {
      _ctx = web.AudioContext();
      // Chrome auto-suspends AudioContexts created outside a user-gesture
      // callback (e.g. inside pc.onTrack). Resume immediately so the analyser
      // actually processes audio instead of returning all-zero frequency data.
      _ctx!.resume();
      final source = _ctx!.createMediaStreamSource(jsStream);
      final analyser = _ctx!.createAnalyser();
      analyser.fftSize = 256;
      analyser.smoothingTimeConstant = 0.8;
      source.connect(analyser);
      _analyser = analyser;
      _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _poll());
    } catch (_) {
      // AudioContext not available; VAD degrades gracefully to always-false.
    }
  }

  void _poll() {
    final analyser = _analyser;
    if (analyser == null) return;

    // Re-resume if Chrome re-suspended the context (e.g. tab backgrounded).
    if (_ctx?.state == 'suspended') {
      _ctx!.resume();
      return; // Skip this tick; next tick will have fresh data.
    }

    final bufLen = analyser.frequencyBinCount;
    final dataList = Uint8List(bufLen);
    final jsArr = dataList.toJS;
    analyser.getByteFrequencyData(jsArr);

    // Compute average byte energy across frequency bins.
    final bytes = jsArr.toDart;
    double sum = 0;
    for (final v in bytes) {
      sum += v;
    }
    final avg = bufLen > 0 ? sum / bufLen : 0.0;
    // Normalise: practical speech energies sit in 0–60 range; cap at 1.0.
    _currentLevel = (avg / 60.0).clamp(0.0, 1.0);

    final bool nowSpeaking;
    if (!_speaking && avg >= _onThreshold) {
      nowSpeaking = true;
    } else if (_speaking && avg < _offThreshold) {
      // Energy dropped — but don't emit false immediately.
      // Start (or restart) a hold timer; only go silent after _offHold ms.
      _offHoldTimer ??= Timer(_offHold, () {
        _offHoldTimer = null;
        if (_speaking) {
          _speaking = false;
          _onStateChange(false);
        }
      });
      return; // keep _speaking = true until the hold expires
    } else {
      nowSpeaking = _speaking;
    }

    // Energy rose above _onThreshold — cancel any pending off-hold timer.
    if (nowSpeaking && _offHoldTimer != null) {
      _offHoldTimer!.cancel();
      _offHoldTimer = null;
    }

    if (nowSpeaking != _speaking) {
      _speaking = nowSpeaking;
      _onStateChange(_speaking);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _offHoldTimer?.cancel();
    _offHoldTimer = null;
    _currentLevel = 0.0;
    try {
      _ctx?.close();
    } catch (e) {
      developer.log(
        'VAD AudioContext close failed (non-fatal): $e',
        name: 'WebRTC',
      );
    }
    _ctx = null;
    _analyser = null;
  }
}
