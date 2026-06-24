import 'package:flutter/foundation.dart';
import '../../shared/models/remote_user.dart';
import 'video_engine_interface.dart';
import '../agora/agora_web_engine.dart';
import '../agora/agora_mobile_engine.dart';

/// Unified Video Engine Service
///
/// Single entry point for all video functionality.
/// Automatically routes to Web or Mobile implementation based on platform.
///
/// Usage:
/// ```dart
/// final videoEngine = VideoEngineService();
/// await videoEngine.init('YOUR_APP_ID');
/// await videoEngine.joinChannel(channel: 'room1', uid: 123, token: 'token');
/// // Listen to remote users
/// videoEngine.remoteUsersStream.listen((users) {
///   // Update UI with remote users
/// });
/// ```
class VideoEngineService implements IVideoEngine {
  late final IVideoEngine _engine;

  VideoEngineService() {
    if (kIsWeb) {
      _engine = AgoraWebEngine();
    } else {
      _engine = AgoraMobileEngine();
    }
    debugPrint(
        'ðŸŽ¥ VideoEngineService initialized for ${kIsWeb ? 'Web' : 'Mobile'}');
  }

  @override
  Future<void> init(String appId, {String? token}) =>
      _engine.init(appId, token: token);

  @override
  Future<void> joinChannel(
          {required String channel, required int uid, required String token}) =>
      _engine.joinChannel(channel: channel, uid: uid, token: token);

  @override
  Future<void> leaveChannel() => _engine.leaveChannel();

  @override
  Future<void> enableLocalTracks(
          {bool enableAudio = true, bool enableVideo = true}) =>
      _engine.enableLocalTracks(
          enableAudio: enableAudio, enableVideo: enableVideo);

  @override
  Future<void> setAudioMuted(bool muted) => _engine.setAudioMuted(muted);

  @override
  Future<void> setVideoMuted(bool muted) => _engine.setVideoMuted(muted);

  @override
  Stream<List<RemoteUser>> get remoteUsersStream => _engine.remoteUsersStream;
}
