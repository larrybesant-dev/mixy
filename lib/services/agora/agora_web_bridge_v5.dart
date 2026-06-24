// Agora Web Bridge v5 - Production-Ready Web Interop
// Interfaces with window.agoraWebBridge from agora_bridge.js
// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:mixvy/core/utils/app_logger.dart';
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// External JS function declarations using dart:js_interop
/// Object-style: window.agoraWebBridge.init, etc.

@JS('agoraWebBridge.init')
external JSPromise<JSBoolean?> _jsInit(JSString appId);

@JS('agoraWebBridge.joinChannel')
external JSPromise<JSBoolean?> _jsJoinChannel(
    JSString token, JSString channel, JSString uid);

@JS('agoraWebBridge.createCameraTrack')
external JSPromise<JSBoolean?> _jsCreateCameraTrack();

@JS('agoraWebBridge.createMicrophoneTrack')
external JSPromise<JSBoolean?> _jsCreateMicrophoneTrack();

@JS('agoraWebBridge.leaveChannel')
external JSPromise<JSBoolean?> _jsLeaveChannel();

@JS('agoraWebBridge.setMicMuted')
external JSPromise<JSBoolean?> _jsSetMicMuted(JSBoolean muted);

@JS('agoraWebBridge.setVideoMuted')
external JSPromise<JSBoolean?> _jsSetVideoMuted(JSBoolean muted);

/// Flat style functions for backward compatibility
@JS('agoraWebJoinChannel')
external JSPromise<JSBoolean?> _jsFlatJoinChannel(
    JSString appId, JSString channelName, JSString token, JSString uid);

@JS('agoraWebGetState')
external JSObject? _jsFlatGetState();

@JS('agoraBridgeReady')
external JSBoolean? get _jsBridgeReady;

/// Direct interop to window.agoraWebBridge functions
/// Required: agora_bridge.js must be loaded in index.html BEFORE Flutter loads
class AgoraWebBridge {
  static bool _initialized = false;
  static String? _appId;

  /// Check if JS bridge is available
  static bool get isBridgeReady {
    if (!kIsWeb) return false;
    try {
      return _jsBridgeReady?.toDart ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if initialized
  static bool get isInitialized => _initialized;

  /// Get cached app ID
  static String? get appId => _appId;

  /// Initialize Agora Web with App ID
  static Future<bool> init(String appId) async {
    if (_initialized && _appId == appId) {
      debugPrint('[BRIDGE] Already initialized with same appId');
      return true;
    }

    if (!kIsWeb) {
      AppLogger.error('[BRIDGE] Not on web platform');
      return false;
    }

    try {
      debugPrint('[BRIDGE] Checking bridge availability...');

      if (!isBridgeReady) {
        debugPrint(
            '[BRIDGE] âŒ JS bridge not ready - check agora_bridge.js loaded in index.html');
        AppLogger.error('âŒ Agora JS bridge not loaded');
        return false;
      }

      debugPrint(
          '[BRIDGE] âœ… Bridge ready, initializing with appId: ${appId.substring(0, 8)}...');
      AppLogger.info('ðŸŒ Initializing Agora Web SDK v5...');

      // Call the actual JS init function (this starts async SDK load)
      await _jsInit(appId.toJS).toDart;

      // CRITICAL FIX: Give JS time to finish async SDK load and initialization
      // This fixes the race condition where Dart checks too early
      await Future.delayed(const Duration(milliseconds: 400));

      // Now verify the JS state is actually ready
      final state = getState();

      if (state['initialized'] != true) {
        throw Exception(
            'Agora JS initialized but state not ready. State: $state');
      }

      _initialized = true;
      _appId = appId;
      AppLogger.info('âœ… Agora Web SDK v5 initialized and state verified');
      debugPrint('[BRIDGE] Init successful with state verification');
      return true;
    } catch (e) {
      AppLogger.error('âŒ Agora init failed: $e');
      debugPrint('[BRIDGE] Init error: $e');
      return false;
    }
  }

  /// Join a channel (object-style API - uses stored appId)
  static Future<bool> joinChannelSimple(
    String token,
    String channel,
    String uid,
  ) async {
    if (!kIsWeb) return false;

    try {
      debugPrint('[BRIDGE] Joining channel (simple): $channel, uid: $uid');
      AppLogger.info('ðŸ”— Joining Agora channel: $channel...');

      final result =
          await _jsJoinChannel(token.toJS, channel.toJS, uid.toJS).toDart;

      if (result?.toDart == true) {
        AppLogger.info('âœ… Joined channel successfully');
        debugPrint('[BRIDGE] Join channel successful');
        return true;
      } else {
        AppLogger.error('âŒ Join channel returned false');
        debugPrint('[BRIDGE] Join channel returned false');
        return false;
      }
    } catch (e) {
      AppLogger.error('âŒ Failed to join channel: $e');
      debugPrint('[BRIDGE] joinChannel error: $e');
      return false;
    }
  }

  /// Join a channel (flat-style API - pass appId explicitly)
  static Future<bool> joinChannel(
    String appId,
    String channelName,
    String token,
    String uid,
  ) async {
    if (!kIsWeb) return false;

    try {
      debugPrint('[BRIDGE] Joining channel: $channelName, uid: $uid');
      AppLogger.info('ðŸ”— Joining Agora channel: $channelName...');

      final result = await _jsFlatJoinChannel(
        appId.toJS,
        channelName.toJS,
        token.toJS,
        uid.toJS,
      ).toDart;

      if (result?.toDart == true) {
        AppLogger.info('âœ… Joined channel successfully');
        debugPrint('[BRIDGE] Join channel successful');
        return true;
      } else {
        AppLogger.error('âŒ Join channel returned false');
        debugPrint('[BRIDGE] Join channel returned false');
        return false;
      }
    } catch (e) {
      AppLogger.error('âŒ Failed to join channel: $e');
      debugPrint('[BRIDGE] joinChannel error: $e');
      return false;
    }
  }

  /// Leave the current channel
  static Future<bool> leaveChannel() async {
    if (!kIsWeb) return false;

    try {
      debugPrint('[BRIDGE] Leaving channel...');
      AppLogger.info('ðŸ‘‹ Leaving channel...');

      final result = await _jsLeaveChannel().toDart;

      if (result?.toDart == true) {
        AppLogger.info('âœ… Left channel successfully');
        debugPrint('[BRIDGE] Leave channel successful');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('âŒ Failed to leave channel: $e');
      debugPrint('[BRIDGE] leaveChannel error: $e');
      return false;
    }
  }

  /// Set microphone muted state
  static Future<bool> setMicMuted(bool muted) async {
    if (!kIsWeb) return false;

    try {
      debugPrint('[BRIDGE] Setting mic muted: $muted');

      final result = await _jsSetMicMuted(muted.toJS).toDart;

      if (result?.toDart == true) {
        AppLogger.info('ðŸŽ¤ Microphone ${muted ? 'muted' : 'unmuted'}');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('âŒ Failed to set mic mute: $e');
      return false;
    }
  }

  /// Set video muted state
  static Future<bool> setVideoMuted(bool muted) async {
    if (!kIsWeb) return false;

    try {
      debugPrint('[BRIDGE] Setting video muted: $muted');

      final result = await _jsSetVideoMuted(muted.toJS).toDart;

      if (result?.toDart == true) {
        AppLogger.info('ðŸ“¹ Video ${muted ? 'disabled' : 'enabled'}');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('âŒ Failed to set video mute: $e');
      return false;
    }
  }

  /// Create camera track (requests permission and starts camera)
  static Future<bool> createCameraTrack() async {
    if (!kIsWeb) return false;

    try {
      debugPrint('[BRIDGE] Creating camera track...');

      final result = await _jsCreateCameraTrack().toDart;

      if (result?.toDart == true) {
        AppLogger.info('ðŸ“¹ Camera track created');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('âŒ Failed to create camera track: $e');
      return false;
    }
  }

  /// Create microphone track (requests permission and starts mic)
  static Future<bool> createMicrophoneTrack() async {
    if (!kIsWeb) return false;

    try {
      debugPrint('[BRIDGE] Creating microphone track...');

      final result = await _jsCreateMicrophoneTrack().toDart;

      if (result?.toDart == true) {
        AppLogger.info('ðŸŽ¤ Microphone track created');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('âŒ Failed to create microphone track: $e');
      return false;
    }
  }

  /// Start camera with retry logic
  static Future<bool> startCamera({int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      final success = await createCameraTrack();
      if (success) return true;
      if (i < retries - 1) {
        debugPrint('[BRIDGE] Camera retry ${i + 1}/$retries');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  /// Start microphone with retry logic
  static Future<bool> startMic({int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      final success = await createMicrophoneTrack();
      if (success) return true;
      if (i < retries - 1) {
        debugPrint('[BRIDGE] Mic retry ${i + 1}/$retries');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  /// Full room join flow: init -> join -> camera -> mic
  static Future<bool> joinRoomFull({
    required String appId,
    required String channel,
    required String token,
    required String uid,
    bool enableCamera = true,
    bool enableMic = true,
  }) async {
    if (!kIsWeb) return false;

    try {
      // Step 1: Init
      final initOk = await init(appId);
      if (!initOk) {
        AppLogger.error('âŒ Full join failed at init');
        return false;
      }

      // Step 2: Join channel
      final joinOk = await joinChannel(appId, channel, token, uid);
      if (!joinOk) {
        AppLogger.error('âŒ Full join failed at join channel');
        return false;
      }

      // Step 3: Start camera (with retry)
      if (enableCamera) {
        final cameraOk = await startCamera();
        if (!cameraOk) {
          AppLogger.warning('âš ï¸ Camera failed but continuing...');
        }
      }

      // Step 4: Start mic (with retry)
      if (enableMic) {
        final micOk = await startMic();
        if (!micOk) {
          AppLogger.warning('âš ï¸ Mic failed but continuing...');
        }
      }

      AppLogger.info('âœ… Full room join complete');
      return true;
    } catch (e) {
      AppLogger.error('âŒ Full room join failed: $e');
      return false;
    }
  }

  /// Get current state
  static Map<String, dynamic> getState() {
    if (!kIsWeb) return {};

    try {
      final jsState = _jsFlatGetState();
      if (jsState == null) return {'bridgeReady': false};

      // Convert JS object to Dart map using js_interop_unsafe
      return {
        'bridgeReady': isBridgeReady,
        'initialized': (jsState['initialized'] as JSBoolean?)?.toDart ?? false,
        'sdkLoaded': (jsState['sdkLoaded'] as JSBoolean?)?.toDart ?? false,
        'inChannel': (jsState['inChannel'] as JSBoolean?)?.toDart ?? false,
        'currentChannel': (jsState['currentChannel'] as JSString?)?.toDart,
        'currentUid': (jsState['currentUid'] as JSNumber?)?.toDartInt,
        'hasAudio': (jsState['hasAudio'] as JSBoolean?)?.toDart ?? false,
        'hasVideo': (jsState['hasVideo'] as JSBoolean?)?.toDart ?? false,
        'audioMuted': (jsState['audioMuted'] as JSBoolean?)?.toDart ?? true,
        'videoMuted': (jsState['videoMuted'] as JSBoolean?)?.toDart ?? true,
      };
    } catch (e) {
      debugPrint('[BRIDGE] getState error: $e');
      return {};
    }
  }

  /// Print debug info
  static void printDebugInfo() {
    if (!kIsWeb) return;
    final state = getState();
    debugPrint('[BRIDGE] State: $state');
  }

  /// Enable debug logging
  static void enableDebugLogging() {
    if (!kIsWeb) return;
    debugPrint(
        '[BRIDGE] Debug logging enabled - check browser console for [AgoraBridge] logs');
  }
}

// Backward compatibility alias
typedef AgoraWebBridgeV3 = AgoraWebBridge;

