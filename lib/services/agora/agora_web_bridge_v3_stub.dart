// Stub for non-web platforms. All methods return no-op values since dart:js is web-only.
import 'dart:async';

class AgoraWebBridgeV3 {
  static bool get isAvailable => false;

  static Future<bool> init(String appId) async => false;

  static Future<bool> joinChannel({
    required String appId,
    required String channelName,
    required String token,
    required String uid,
  }) async =>
      false;

  static Future<bool> leaveChannel() async => false;

  static Future<bool> setMicMuted(bool muted) async => false;

  static Future<bool> setVideoMuted(bool muted) async => false;

  static Map<String, dynamic> getState() => {};

  static void enableDebugLogging() {}

  static void printDebugInfo() {}

  static bool renewToken(String newToken) => false;

  // ─── Audio Mixing / Media Control Methods (Stubs for non-web) ───────────────

  static void registerTokenWillExpireCallback(
      void Function(String, String)? callback) {}

  static Future<bool> playCamera(String videoElementId) async => false;

  static Future<bool> playRemoteVideo(String uid, String videoElementId) async =>
      false;

  static void registerRemotePublishedCallback(
      void Function(String uid, String mediaType)? callback) {}

  static Future<bool> startAudioMixing(String url, bool loop) async => false;

  static Future<bool> stopAudioMixing() async => false;

  static Future<bool> pauseAudioMixing() async => false;

  static Future<bool> resumeAudioMixing() async => false;

  static Future<bool> setAudioMixingVolume(int volume) async => false;
}
