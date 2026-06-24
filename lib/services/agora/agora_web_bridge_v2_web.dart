// Agora Web Bridge v2 - window.agoraWeb object adapter (WASM-safe)
// Calls the JavaScript bridge defined in web/index.html
// Replaces dart:js with dart:js_interop for WASM compatibility.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../core/utils/app_logger.dart';

// ── Extension type: window.agoraWeb object ───────────────────────────────
// Represents the shape of the agoraWeb bridge object exposed by index.html.

extension type _AgoraWebJS._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean?> init(JSString appId);
  external JSPromise<JSBoolean?> joinChannel(
      JSString token, JSString channelName, JSString uid);
  external JSPromise<JSBoolean?> leaveChannel();
  external JSPromise<JSBoolean?> enableLocalTracks(
      JSBoolean enableAudio, JSBoolean enableVideo);
  external JSPromise<JSBoolean?> setAudioMuted(JSBoolean muted);
  external JSPromise<JSBoolean?> setVideoMuted(JSBoolean muted);
  external JSPromise<JSBoolean?> muteRemoteAudio(JSNumber uid, JSBoolean muted);
  external JSObject? getClientState();
  external set onRemoteUserPublished(JSFunction? fn);
  external set onRemoteUserUnpublished(JSFunction? fn);
  external set onRemoteUserLeft(JSFunction? fn);
}

// ── Extension type: getClientState() return object ───────────────────────

extension type _ClientStateJS._(JSObject _) implements JSObject {
  external JSBoolean? get hasClient;
  external JSBoolean? get hasAudioTrack;
  external JSBoolean? get hasVideoTrack;
}

// ── Extension type: remote-event callback argument ───────────────────────

extension type _RemoteEventJS._(JSObject _) implements JSObject {
  external JSAny? get uid;
  external JSString? get mediaType;
  external JSBoolean? get hasVideo;
  external JSBoolean? get hasAudio;
}

// ── Global accessor ───────────────────────────────────────────────────────

@JS('agoraWeb')
external JSAny? get _agoraWebBridgeRaw;

_AgoraWebJS? _getBridge() {
  final raw = _agoraWebBridgeRaw;
  if (raw == null) return null;
  return raw as _AgoraWebJS;
}

// ── AgoraWebBridgeV2 ──────────────────────────────────────────────────────

class AgoraWebBridgeV2 {
  static bool get isAvailable {
    if (!kIsWeb) return false;
    try {
      return _getBridge() != null;
    } catch (e) {
      debugPrint('[BRIDGE] Error checking isAvailable: $e');
      return false;
    }
  }

  static Future<bool> init(String appId) async {
    if (!kIsWeb) return false;
    try {
      final bridge = _getBridge();
      if (bridge == null) {
        AppLogger.error('Bridge agoraWeb not available');
        return false;
      }
      debugPrint('[BRIDGE] Calling JS init($appId)');
      final result = await bridge.init(appId.toJS).toDart;
      return result?.toDart ?? false;
    } catch (e) {
      AppLogger.error('init error: $e');
      return false;
    }
  }

  static Future<bool> joinChannel({
    required String channelName,
    required String token,
    required String uid,
  }) async {
    if (!kIsWeb) return false;
    try {
      final bridge = _getBridge();
      if (bridge == null) {
        AppLogger.error('Bridge agoraWeb not available');
        return false;
      }
      debugPrint('[BRIDGE] Calling JS joinChannel($channelName, uid=$uid)');
      final result =
          await bridge.joinChannel(token.toJS, channelName.toJS, uid.toJS).toDart;
      debugPrint('[BRIDGE] joinChannel result: $result');
      return result?.toDart ?? false;
    } catch (e) {
      AppLogger.error('joinChannel error: $e');
      return false;
    }
  }

  static Future<bool> leaveChannel() async {
    if (!kIsWeb) return false;
    try {
      final bridge = _getBridge();
      if (bridge == null) return false;
      final result = await bridge.leaveChannel().toDart;
      return result?.toDart ?? false;
    } catch (e) {
      AppLogger.error('leaveChannel error: $e');
      return false;
    }
  }

  static Future<bool> enableLocalTracks({
    required bool enableAudio,
    required bool enableVideo,
  }) async {
    if (!kIsWeb) return false;
    try {
      final bridge = _getBridge();
      if (bridge == null) return false;
      debugPrint('[BRIDGE] enableLocalTracks(audio=$enableAudio, video=$enableVideo)');
      final result =
          await bridge.enableLocalTracks(enableAudio.toJS, enableVideo.toJS).toDart;
      return result?.toDart ?? false;
    } catch (e) {
      AppLogger.error('enableLocalTracks error: $e');
      return false;
    }
  }

  static Future<bool> setAudioMuted(bool muted) async {
    if (!kIsWeb) return false;
    try {
      final bridge = _getBridge();
      if (bridge == null) return false;
      final result = await bridge.setAudioMuted(muted.toJS).toDart;
      return result?.toDart ?? false;
    } catch (e) {
      AppLogger.error('setAudioMuted error: $e');
      return false;
    }
  }

  static Future<bool> setVideoMuted(bool muted) async {
    if (!kIsWeb) return false;
    try {
      final bridge = _getBridge();
      if (bridge == null) return false;
      final result = await bridge.setVideoMuted(muted.toJS).toDart;
      return result?.toDart ?? false;
    } catch (e) {
      AppLogger.error('setVideoMuted error: $e');
      return false;
    }
  }

  /// Mute/unmute remote user audio (host controls)
  static Future<bool> muteRemoteAudio(int remoteUid, bool muted) async {
    if (!kIsWeb) return false;
    try {
      final bridge = _getBridge();
      if (bridge == null) return false;
      debugPrint('[BRIDGE] muteRemoteAudio(uid=$remoteUid, muted=$muted)');
      final result =
          await bridge.muteRemoteAudio(remoteUid.toJS, muted.toJS).toDart;
      return result?.toDart ?? false;
    } catch (e) {
      AppLogger.error('muteRemoteAudio error: $e');
      return false;
    }
  }

  // Deprecated alias
  static Future<bool> setMicMuted(bool muted) => setAudioMuted(muted);

  static Map<String, bool>? getClientState() {
    if (!kIsWeb) return null;
    try {
      final bridge = _getBridge();
      if (bridge == null) return null;
      final raw = bridge.getClientState();
      if (raw == null) return null;
      final state = raw as _ClientStateJS;
      return {
        'hasClient': state.hasClient?.toDart ?? false,
        'hasAudioTrack': state.hasAudioTrack?.toDart ?? false,
        'hasVideoTrack': state.hasVideoTrack?.toDart ?? false,
      };
    } catch (e) {
      debugPrint('[BRIDGE] Error getting client state: $e');
      return null;
    }
  }

  /// Set callback for remote user published event
  static void setOnRemoteUserPublished(
      void Function(Map<String, dynamic> event)? callback) {
    if (!kIsWeb) return;
    try {
      final bridge = _getBridge();
      if (bridge == null) return;
      if (callback == null) {
        bridge.onRemoteUserPublished = null;
        return;
      }
      bridge.onRemoteUserPublished = ((JSAny? raw) {
        try {
          final event = raw as _RemoteEventJS;
          callback({
            'uid': event.uid?.toString(),
            'mediaType': event.mediaType?.toDart,
            'hasVideo': event.hasVideo?.toDart ?? false,
            'hasAudio': event.hasAudio?.toDart ?? false,
          });
        } catch (e) {
          debugPrint('[BRIDGE] Error in onRemoteUserPublished: $e');
        }
      }).toJS;
      debugPrint('[BRIDGE] onRemoteUserPublished callback registered');
    } catch (e) {
      debugPrint('[BRIDGE] Error setting onRemoteUserPublished: $e');
    }
  }

  /// Set callback for remote user unpublished event
  static void setOnRemoteUserUnpublished(
      void Function(Map<String, dynamic> event)? callback) {
    if (!kIsWeb) return;
    try {
      final bridge = _getBridge();
      if (bridge == null) return;
      if (callback == null) {
        bridge.onRemoteUserUnpublished = null;
        return;
      }
      bridge.onRemoteUserUnpublished = ((JSAny? raw) {
        try {
          final event = raw as _RemoteEventJS;
          callback({
            'uid': event.uid?.toString(),
            'mediaType': event.mediaType?.toDart,
          });
        } catch (e) {
          debugPrint('[BRIDGE] Error in onRemoteUserUnpublished: $e');
        }
      }).toJS;
      debugPrint('[BRIDGE] onRemoteUserUnpublished callback registered');
    } catch (e) {
      debugPrint('[BRIDGE] Error setting onRemoteUserUnpublished: $e');
    }
  }

  /// Set callback for remote user left event
  static void setOnRemoteUserLeft(
      void Function(Map<String, dynamic> event)? callback) {
    if (!kIsWeb) return;
    try {
      final bridge = _getBridge();
      if (bridge == null) return;
      if (callback == null) {
        bridge.onRemoteUserLeft = null;
        return;
      }
      bridge.onRemoteUserLeft = ((JSAny? raw) {
        try {
          final event = raw as _RemoteEventJS;
          callback({'uid': event.uid?.toString()});
        } catch (e) {
          debugPrint('[BRIDGE] Error in onRemoteUserLeft: $e');
        }
      }).toJS;
      debugPrint('[BRIDGE] onRemoteUserLeft callback registered');
    } catch (e) {
      debugPrint('[BRIDGE] Error setting onRemoteUserLeft: $e');
    }
  }
}