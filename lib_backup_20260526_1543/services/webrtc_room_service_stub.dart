import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'rtc_room_service.dart';
import '../core/streams/stream_lifecycle_manager.dart';

/// Non-web stub for [WebRtcRoomService].
///
/// Satisfies the type system on VM/native test builds so conditional imports
/// compile without pulling in [dart:js_interop] or [dart:js_interop_unsafe].
/// Should never be instantiated at runtime (the screen guards with [kIsWeb]).
class WebRtcRoomService extends RtcRoomService {
  WebRtcRoomService({
    required FirebaseFirestore firestore,
    required String localUserId,
    required StreamLifecycleManager streamLifecycleManager,
    int maxMeshPeers = 6,
    List<Map<String, dynamic>>? iceServers,
  });

  static Never _unsupported() =>
      throw UnsupportedError('WebRtcRoomService is web-only');

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
  VoidCallback? onSystemAudioStopped;

  @override
  List<int> get remoteUids => _unsupported();
  @override
  bool get localSpeaking => _unsupported();
  @override
  bool get canRenderLocalView => _unsupported();
  @override
  bool get isBroadcaster => _unsupported();
  @override
  bool get isJoinedChannel => _unsupported();
  @override
  bool get isLocalVideoCapturing => _unsupported();
  @override
  bool get isLocalAudioMuted => _unsupported();
  @override
  bool get isSharingSystemAudio => false;
  @override
  Future<void> shareSystemAudio(bool enabled) async {}

  @override
  bool isRemoteSpeaking(int uid) => _unsupported();
  @override
  String? userIdForUid(int uid) => _unsupported();
  @override
  double get localAudioLevel => _unsupported();
  @override
  double remoteAudioLevelForUid(int uid) => _unsupported();

  @override
  Widget getLocalView() => _unsupported();
  @override
  Widget getRemoteView(int uid, String channelId) => _unsupported();

  @override
  Future<void> initialize(String appId) => _unsupported();

  @override
  Future<void> joinRoom(
    String token,
    String channelName,
    int uid, {
    bool publishCameraTrackOnJoin = false,
    bool publishMicrophoneTrackOnJoin = false,
  }) =>
      _unsupported();

  @override
  Future<void> enableVideo(
    bool enabled, {
    bool publishMicrophoneTrack = true,
  }) =>
      _unsupported();

  @override
  Future<void> mute(bool muted) => _unsupported();

  @override
  Future<void> setBroadcaster(bool enabled) => _unsupported();

  @override
  Future<void> publishLocalVideoStream(bool enabled) => _unsupported();

  @override
  Future<void> publishLocalAudioStream(bool enabled) => _unsupported();

  @override
  Future<void> setRemoteVideoSubscription(
    int uid, {
    required bool subscribe,
    bool highQuality = false,
  }) =>
      _unsupported();

  @override
  Future<void> renewToken(String newToken) => _unsupported();

  @override
  Future<void> setMicVolume(double volume) async {}
  @override
  Future<void> setSpeakerVolume(double volume) async {}

  @override
  Future<void> dispose() => _unsupported();

  @override
  Future<void> ensureDeviceAccess({required bool video, required bool audio}) =>
      _unsupported();
}
