// lib/services/agora_service_io.dart

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

class AgoraService {
  RtcEngine? _engine;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize({
    String? appId,
    String? channelName,
    int? uid,
  }) async {
    if (_initialized) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId ?? ''));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Agora IO: Joined channel ${connection.channelId}');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('Agora IO: Remote user joined: $remoteUid');
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('Agora IO: Remote user left: $remoteUid');
        },
      ),
    );

    await _engine!.enableVideo();
    await _engine!.startPreview();

    if (channelName != null && channelName.isNotEmpty) {
      await _engine!.joinChannel(
        token: '',
        channelId: channelName,
        uid: uid ?? 0,
        options: const ChannelMediaOptions(),
      );
    }

    _initialized = true;
  }

  Future<bool> joinChannel({
    String? token,
    required String channelId,
    required String uid,
  }) async {
    if (!_initialized) await initialize();
    try {
      await _engine!.joinChannel(
        token: token ?? '',
        channelId: channelId,
        uid: int.tryParse(uid) ?? 0,
        options: const ChannelMediaOptions(),
      );
      return true;
    } catch (e) {
      debugPrint('Agora IO joinChannel error: $e');
      return false;
    }
  }

  Future<void> leaveChannel() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
  }

  Future<void> setMicrophoneMuted(bool muted) async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(muted);
  }

  Future<void> setVideoCameraMuted(bool muted) async {
    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(muted);
  }

  /// IO stub — always returns false (not supported on IO)
  Future<bool> init(String appId) async => false;

  /// IO stub — not applicable on native
  Future<bool> startCamera(String elementId, [String? deviceId]) async => false;

  /// IO stub — not applicable on native
  Future<bool> startMic([String? deviceId]) async => false;

  /// IO stub
  Future<List<Map<String, dynamic>>> getDevices() async => [];

  /// IO stub
  Future<bool> switchCamera(String deviceId) async => false;

  /// IO stub
  Future<bool> switchMic(String deviceId) async => false;

  /// IO stub — not applicable on native (web-only feature)
  Future<bool> subscribeRemoteVideoTo(String elementId) async => false;
  Future<bool> renewToken(String newToken) async => false;

  Future<void> startScreenShare() async {}

  Future<void> stopScreenShare() async {}

  Future<void> dispose() async {
    if (_engine == null) return;
    await _engine!.release();
    _engine = null;
    _initialized = false;
  }
}
