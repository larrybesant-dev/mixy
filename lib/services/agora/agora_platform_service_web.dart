// Web implementation of AgoraPlatformService.
// Only compiled when dart.library.js_interop is available (web targets).
// Does NOT import agora_rtc_engine — keeping the native SDK off the web build.

import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/utils/app_logger.dart';
import '../infra/token_service.dart';
import 'agora_web_bridge_v3.dart';

// ignore: constant_identifier_names
const bool AGORA_WEB_DISABLED = false;

void _consoleLog(String msg) {
  // Web-only log forwarded to debugPrint; JS bridge has its own console calls.
  debugPrint('[AGORA_WEB] $msg');
}

class AgoraPlatformService {
  // No native engine on web.
  // Typed as Null so callers can assign it to RtcEngine? without importing
  // agora_rtc_engine in this file.
  static Null get engine => null;

  static Future<void> initializeNative(String appId) async {
    // No-op on web — native SDK is not used.
  }

  static Future<bool> joinChannel({
    required String appId,
    required String channelName,
    required String token,
    required String uid,
  }) async {
    _consoleLog('joinChannel called');
    debugPrint('[DEBUG] AgoraPlatformService.joinChannel() [web] channel=$channelName');
    AppLogger.info('🌐 joinChannel [web] channel=$channelName');

    if (AGORA_WEB_DISABLED) {
      debugPrint('[AGORA_WEB] 🟡 Agora Web is DISABLED — joining room without video/audio');
      AppLogger.warning('🟡 Agora Web DISABLED: Joining room without voice/video');
      return true;
    }

    // Step 1: initialise bridge.
    final initSuccess = await AgoraWebBridgeV3.init(appId);
    if (!initSuccess) {
      _consoleLog('❌ Failed to initialize Agora');
      AppLogger.error('❌ Failed to initialize Agora');
      _printDebugState();
      return false;
    }

    // Step 2: join channel.
    final result = await AgoraWebBridgeV3.joinChannel(
      appId: appId,
      channelName: channelName,
      token: token,
      uid: uid,
    );

    if (!result) {
      _consoleLog('❌ Failed to join channel');
      AppLogger.error('❌ Failed to join channel');
      _printDebugState();
      return false;
    }

    _consoleLog('✅ Successfully joined channel');
    AppLogger.info('✅ WEB: Successfully joined channel');

    // Wire up automatic token renewal.
    AgoraWebBridgeV3.registerTokenWillExpireCallback(
      (String expiredChannel, String expiredUid) async {
        try {
          AppLogger.info('[AGORA] Token expiring — fetching renewal for $expiredChannel');
          final newToken = await TokenService().generateAgoraToken(
            channelName: expiredChannel,
            userId: expiredUid,
            isBroadcaster: true,
          );
          AgoraWebBridgeV3.renewToken(newToken);
          AppLogger.info('[AGORA] Token renewed successfully');
        } catch (e) {
          AppLogger.error('[AGORA] Token renewal failed: $e');
        }
      },
    );

    return true;
  }

  static Future<bool> leaveChannel() async {
    if (AGORA_WEB_DISABLED) {
      debugPrint('[AGORA_WEB] 🟡 Agora Web disabled — leaveChannel is no-op');
      return true;
    }
    return AgoraWebBridgeV3.leaveChannel();
  }

  static Future<bool> setMicMuted(bool muted) async {
    if (AGORA_WEB_DISABLED) {
      debugPrint('[AGORA_WEB] 🟡 Agora Web disabled — setMicMuted is no-op');
      return true;
    }
    return AgoraWebBridgeV3.setMicMuted(muted);
  }

  static Future<bool> setVideoMuted(bool muted) async {
    if (AGORA_WEB_DISABLED) {
      debugPrint('[AGORA_WEB] 🟡 Agora Web disabled — setVideoMuted is no-op');
      return true;
    }
    return AgoraWebBridgeV3.setVideoMuted(muted);
  }

  static Future<bool> playCamera(String videoElementId) async {
    if (AGORA_WEB_DISABLED) return false;
    return AgoraWebBridgeV3.playCamera(videoElementId);
  }

  static Future<bool> playRemoteVideo(String uid, String videoElementId) async {
    if (AGORA_WEB_DISABLED) return false;
    return AgoraWebBridgeV3.playRemoteVideo(uid, videoElementId);
  }

  static Future<bool> initializeWeb(String appId) async {
    if (AGORA_WEB_DISABLED) {
      debugPrint('[AGORA_WEB] 🟡 Agora Web disabled — initializeWeb is no-op');
      return true;
    }
    final state = AgoraWebBridgeV3.getState();
    if (state['initialized'] == true) return true;

    final initOk = await AgoraWebBridgeV3.init(appId);
    if (!initOk) {
      debugPrint('[AGORA_WEB] initializeWeb failed to initialize bridge');
      _printDebugState();
      return false;
    }
    return true;
  }

  static Map<String, dynamic> getWebBridgeState() {
    if (AGORA_WEB_DISABLED) return {'disabled': true};
    try {
      return AgoraWebBridgeV3.getState();
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static void enableWebDebugLogging() {
    if (!AGORA_WEB_DISABLED) {
      AgoraWebBridgeV3.enableDebugLogging();
      AppLogger.info('🔍 Agora Web debug logging enabled');
    }
  }

  static void enableDebugLogging() {
    AgoraWebBridgeV3.enableDebugLogging();
    AppLogger.info('🔍 Agora Web debug logging enabled');
  }

  static void _printDebugState() {
    try {
      final state = AgoraWebBridgeV3.getState();
      debugPrint('[DEBUG] Agora Web State:');
      state.forEach((key, value) {
        debugPrint('  $key: $value');
      });
      AgoraWebBridgeV3.printDebugInfo();
    } catch (e) {
      debugPrint('[DEBUG] Could not get state: $e');
    }
  }

  static void registerRemotePublishedCallback(
      void Function(String uid, String mediaType) callback) {
    AgoraWebBridgeV3.registerRemotePublishedCallback(callback);
  }

  // ── Audio mixing ─────────────────────────────────────────────────────────
  static Future<bool> startAudioMixing(String url, {bool loop = false}) async {
    if (AGORA_WEB_DISABLED) return false;
    return AgoraWebBridgeV3.startAudioMixing(url, loop);
  }

  static Future<bool> stopAudioMixing() async {
    if (AGORA_WEB_DISABLED) return false;
    return AgoraWebBridgeV3.stopAudioMixing();
  }

  static Future<bool> pauseAudioMixing() async {
    if (AGORA_WEB_DISABLED) return false;
    return AgoraWebBridgeV3.pauseAudioMixing();
  }

  static Future<bool> resumeAudioMixing() async {
    if (AGORA_WEB_DISABLED) return false;
    return AgoraWebBridgeV3.resumeAudioMixing();
  }

  static Future<bool> setAudioMixingVolume(int volume) async {
    if (AGORA_WEB_DISABLED) return false;
    return AgoraWebBridgeV3.setAudioMixingVolume(volume);
  }
}
