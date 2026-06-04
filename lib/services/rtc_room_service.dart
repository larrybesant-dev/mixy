import 'package:flutter/material.dart';

import '../features/room/controllers/room_state.dart';

/// Abstract interface shared by [AgoraService] (native/web Agora SDK) and
/// [WebRtcRoomService] (browser-native WebRTC with Firestore signaling).
///
/// The live_room_screen uses this type so it can transparently swap between
/// implementations without changing any call sites.
abstract class RtcRoomService {
  // ──────────────────────────────────────────────────────────────────────────
  // Callbacks
  // ──────────────────────────────────────────────────────────────────────────

  VoidCallback? get onRemoteUserJoined;
  set onRemoteUserJoined(VoidCallback? value);

  VoidCallback? get onRemoteUserLeft;
  set onRemoteUserLeft(VoidCallback? value);

  VoidCallback? get onSpeakerActivityChanged;
  set onSpeakerActivityChanged(VoidCallback? value);

  VoidCallback? get onLocalVideoCaptureChanged;
  set onLocalVideoCaptureChanged(VoidCallback? value);

  VoidCallback? get onTokenWillExpire;
  set onTokenWillExpire(VoidCallback? value);

  VoidCallback? get onConnectionLost;
  set onConnectionLost(VoidCallback? value);

  VoidCallback? get onNetworkQualityChanged => null;
  set onNetworkQualityChanged(VoidCallback? value) {}

  // ──────────────────────────────────────────────────────────────────────────
  // State getters
  // ──────────────────────────────────────────────────────────────────────────

  List<int> get remoteUids;
  bool get localSpeaking;
  bool get canRenderLocalView;
  bool get isBroadcaster;
  bool get isJoinedChannel;
  bool get isLocalVideoCapturing;
  bool get isLocalAudioMuted;

  /// True when the broadcaster is sharing PC/system audio via getDisplayMedia.
  bool get isSharingSystemAudio => false;

  /// True when the network is experiencing high packet loss/RTT and is degraded.
  bool get isNetworkDegraded => false;

  bool isRemoteSpeaking(int uid);

  /// Normalised local mic energy in [0.0, 1.0].  Returns 0 when muted.
  double get localAudioLevel => 0.0;

  /// Normalised remote speaker energy for [uid] in [0.0, 1.0].
  double remoteAudioLevelForUid(int uid) => 0.0;

  /// Returns the Firestore userId for a remote [uid] if the service has an
  /// explicit mapping (WebRTC), or null if the caller must fall back to the
  /// hash-based lookup (Agora).
  String? userIdForUid(int uid) => null;

  // ──────────────────────────────────────────────────────────────────────────
  // Video views
  // ──────────────────────────────────────────────────────────────────────────

  Widget getLocalView();
  Widget getRemoteView(int uid, String channelId);

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> initialize(String appId);

  Future<void> joinRoom(
    String token,
    String channelName,
    int uid, {
    bool publishCameraTrackOnJoin = false,
    bool publishMicrophoneTrackOnJoin = false,
  });

  Future<void> enableVideo(bool enabled, {bool publishMicrophoneTrack = true});

  Future<void> mute(bool muted);

  Future<void> setBroadcaster(bool enabled);

  Future<void> publishLocalVideoStream(bool enabled);

  Future<void> publishLocalAudioStream(bool enabled);

  Future<void> setRemoteVideoSubscription(
    int uid, {
    required bool subscribe,
    bool highQuality = false,
  });

  Future<void> renewToken(String newToken);

  /// Share PC/system audio (Chrome: pick a tab/screen + "Share system audio").
  /// Default no-op for Agora; only implemented on web via [WebRtcRoomService].
  Future<void> shareSystemAudio(bool enabled) async {}

  Future<void> holdLocalAudio() async {
    await publishLocalAudioStream(false);
    await mute(true);
  }

  Future<void> muteAndLock() async {
    await holdLocalAudio();
    if (isBroadcaster && !isLocalVideoCapturing) {
      await setBroadcaster(false);
    }
  }

  Future<void> syncAudio(
    RoomAudioState state, {
    bool shouldMute = false,
  }) async {
    switch (state) {
      case RoomAudioState.speaking:
      case RoomAudioState.cohostSpeaking:
        if (!isBroadcaster) {
          await ensureDeviceAccess(video: false, audio: true);
          await setBroadcaster(true);
        }
        await publishLocalAudioStream(true);
        await mute(shouldMute);
        break;
      case RoomAudioState.requestingMic:
      case RoomAudioState.muted:
        await holdLocalAudio();
        if (isBroadcaster && !isLocalVideoCapturing) {
          await setBroadcaster(false);
        }
        break;
      case RoomAudioState.denied:
        await muteAndLock();
        break;
    }
  }

  /// Set local microphone input gain.
  ///
  /// [volume] is in the range [0.0, 2.0] where 1.0 is the default (100%).
  /// Values above 1.0 amplify the signal; 0.0 is silent.
  /// Default no-op — implementations that support it override this.
  Future<void> setMicVolume(double volume) async {}

  /// Set local speaker / playback output volume.
  ///
  /// [volume] is in the range [0.0, 1.0] where 1.0 is the default (100%).
  /// Default no-op — implementations that support it override this.
  Future<void> setSpeakerVolume(double volume) async {}

  /// Suggests the encoding quality for the local outgoing stream.
  /// Used in Mesh to save bandwidth when the user is not the active speaker.
  Future<void> setEncodingQuality(bool highQuality) async {}

  Future<void> dispose();

  Future<void> ensureDeviceAccess({required bool video, required bool audio});
}
