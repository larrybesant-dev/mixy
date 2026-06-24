// Agora Web Bridge v3 - Production Ready (WASM-safe)
// Interfaces with agora_web_v5_production.js
// Replaces dart:js with dart:js_interop for WASM compatibility.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../core/utils/app_logger.dart';

// ── External JS declarations ─────────────────────────────────────────────
// Each @JS annotation captures a nullable handle to a window property so
// we can check availability before calling.

@JS('agoraWebInit')
external JSAny? get _jsAgoraWebInit;

@JS('agoraWebJoinChannel')
external JSAny? get _jsAgoraWebJoinChannel;

@JS('agoraWebLeaveChannel')
external JSAny? get _jsAgoraWebLeaveChannel;

@JS('agoraWebSetMicMuted')
external JSAny? get _jsAgoraWebSetMicMuted;

@JS('agoraWebSetVideoMuted')
external JSAny? get _jsAgoraWebSetVideoMuted;

@JS('agoraWebGetState')
external JSAny? get _jsAgoraWebGetState;

@JS('agoraWebDebug')
external JSAny? get _jsAgoraWebDebug;

@JS('agoraWebRenewToken')
external JSAny? get _jsAgoraWebRenewToken;

// ── Helper: call a nullable JS function and await its Promise<bool> ───────

Future<bool> _callPromise(JSAny? fn, [
  JSAny? a1,
  JSAny? a2,
  JSAny? a3,
  JSAny? a4,
]) async {
  if (fn == null) throw Exception('JS function not found on window');
  final raw = (fn as JSFunction).callAsFunction(null, a1, a2, a3, a4);
  if (raw == null) return false;
  final result = await (raw as JSPromise<JSBoolean?>).toDart;
  return result?.toDart ?? false;
}

// ── Bridge class (public API unchanged) ───────────────────────────────────

class AgoraWebBridgeV3 {
  static bool get isAvailable {
    if (!kIsWeb) return false;
    try {
      return _jsAgoraWebInit != null && _jsAgoraWebJoinChannel != null;
    } catch (_) {
      return false;
    }
  }

  /// Initialize Agora Web with App ID
  static Future<bool> init(String appId) async {
    if (!kIsWeb) {
      AppLogger.error('[BRIDGE] Not on web, returning false');
      return false;
    }
    try {
      debugPrint('[BRIDGE] Initializing...');
      AppLogger.info('Initializing Agora Web SDK v5...');
      final ok = await _callPromise(_jsAgoraWebInit, appId.toJS);
      if (ok) AppLogger.info('Agora Web SDK v5 initialized');
      return ok;
    } catch (e) {
      AppLogger.error('Agora init failed: $e');
      debugPrint('[BRIDGE] Init error: $e');
      return false;
    }
  }

  /// Join a channel with token
  static Future<bool> joinChannel({
    required String appId,
    required String channelName,
    required String token,
    required String uid,
  }) async {
    if (!kIsWeb) return false;
    try {
      debugPrint('[BRIDGE] Joining channel: $channelName, uid: $uid');
      AppLogger.info('Joining Agora channel: $channelName...');
      final ok = await _callPromise(
        _jsAgoraWebJoinChannel,
        appId.toJS,
        channelName.toJS,
        token.toJS,
        uid.toJS,
      );
      if (ok) AppLogger.info('Successfully joined channel: $channelName');
      return ok;
    } catch (e) {
      AppLogger.error('Failed to join channel: $e');
      debugPrint('[BRIDGE] joinChannel error: $e');
      return false;
    }
  }

  /// Leave the current channel
  static Future<bool> leaveChannel() async {
    if (!kIsWeb) return false;
    try {
      final ok = await _callPromise(_jsAgoraWebLeaveChannel);
      if (ok) AppLogger.info('Left channel');
      return ok;
    } catch (e) {
      AppLogger.error('Failed to leave channel: $e');
      return false;
    }
  }

  /// Set microphone muted state
  static Future<bool> setMicMuted(bool muted) async {
    if (!kIsWeb) return false;
    try {
      final ok = await _callPromise(_jsAgoraWebSetMicMuted, muted.toJS);
      if (ok) AppLogger.info('Microphone ${muted ? "muted" : "unmuted"}');
      return ok;
    } catch (e) {
      AppLogger.error('Failed to set mic mute: $e');
      return false;
    }
  }

  /// Set video muted state
  static Future<bool> setVideoMuted(bool muted) async {
    if (!kIsWeb) return false;
    try {
      final ok = await _callPromise(_jsAgoraWebSetVideoMuted, muted.toJS);
      if (ok) AppLogger.info('Video ${muted ? "disabled" : "enabled"}');
      return ok;
    } catch (e) {
      AppLogger.error('Failed to set video mute: $e');
      return false;
    }
  }

  /// Get current Agora Web state (for debugging)
  static Map<String, dynamic> getState() {
    if (!kIsWeb) return {};
    try {
      final fn = _jsAgoraWebGetState;
      if (fn == null) return {'error': 'agoraWebGetState not found'};
      (fn as JSFunction).callAsFunction(null);
      return {'available': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Enable debug mode
  static void enableDebugLogging() {
    if (!kIsWeb) return;
    try {
      (_jsAgoraWebDebug as JSFunction?)?.callAsFunction(null);
    } catch (_) {}
  }

  /// Print debug info to console
  static void printDebugInfo() {
    if (!kIsWeb) return;
    try {
      (_jsAgoraWebDebug as JSFunction?)?.callAsFunction(null);
    } catch (e) {
      debugPrint('[BRIDGE] Error: $e');
    }
  }

  /// Renew the Agora token for the current session (synchronous JS call).
  /// Call this when the privilege expiry callback fires or on a ~23h timer.
  static bool renewToken(String newToken) {
    if (!kIsWeb) return false;
    try {
      final fn = _jsAgoraWebRenewToken;
      if (fn == null) return false;
      final result = (fn as JSFunction).callAsFunction(null, newToken.toJS);
      if (result == null) return false;
      final dartValue = (result as JSBoolean).toDart;
      return dartValue;
    } catch (e) {
      debugPrint('[BRIDGE] renewToken error: $e');
      return false;
    }
  }

  // ─── Audio Mixing / Media Control Methods (Web stubs) ───────────────────────

  /// Register callback for token expiration
  static void registerTokenWillExpireCallback(
      void Function(String, String)? callback) {
    // Stub: Web implementation would register JS callback
    debugPrint('[BRIDGE] registerTokenWillExpireCallback (stub)');
  }

  /// Play local camera video
  static Future<bool> playCamera(String videoElementId) async {
    debugPrint('[BRIDGE] playCamera: $videoElementId (stub)');
    return false;
  }

  /// Play remote user video
  static Future<bool> playRemoteVideo(String uid, String videoElementId) async {
    debugPrint('[BRIDGE] playRemoteVideo: $uid (stub)');
    return false;
  }

  /// Register callback for remote user publishing
  static void registerRemotePublishedCallback(
      void Function(String uid, String mediaType)? callback) {
    debugPrint('[BRIDGE] registerRemotePublishedCallback (stub)');
  }

  /// Start playing audio file as background music
  static Future<bool> startAudioMixing(String url, bool loop) async {
    debugPrint('[BRIDGE] startAudioMixing: $url (stub)');
    return false;
  }

  /// Stop audio mixing
  static Future<bool> stopAudioMixing() async {
    debugPrint('[BRIDGE] stopAudioMixing (stub)');
    return false;
  }

  /// Pause audio mixing
  static Future<bool> pauseAudioMixing() async {
    debugPrint('[BRIDGE] pauseAudioMixing (stub)');
    return false;
  }

  /// Resume audio mixing
  static Future<bool> resumeAudioMixing() async {
    debugPrint('[BRIDGE] resumeAudioMixing (stub)');
    return false;
  }

  /// Set audio mixing volume (0-100)
  static Future<bool> setAudioMixingVolume(int volume) async {
    debugPrint('[BRIDGE] setAudioMixingVolume: $volume (stub)');
    return false;
  }
}

// ── Compatibility alias ───────────────────────────────────────────────────
typedef AgoraWebBridgeV2 = AgoraWebBridgeV3;
