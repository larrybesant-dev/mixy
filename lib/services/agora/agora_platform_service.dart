import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as native;
import '../../core/utils/app_logger.dart';

// Import web bridge v3 - Production ready with SDK v5
import 'agora_web_bridge_v3.dart';

/// ============================================================================
/// FEATURE FLAG: Agora Web Disabled (Temporary)
/// ============================================================================
/// Agora Web SDK v5 has JS interop incompatibility with current bridge code.
/// This flag allows web users to join rooms WITHOUT voice/video while we fix
/// the JS bridge. They can still:
/// - Chat
/// - See presence
/// - View room UI
/// - Broadcast from mobile
///
/// Agora Web bridge is ready (SDK v5 + production JS bridge).
// ignore: constant_identifier_names
const bool AGORA_WEB_DISABLED = false;

void _consoleLog(String msg) {
  if (!kIsWeb) return;
  // JS logging only available on web
}

class AgoraPlatformService {
  // Native engine instance for mobile/desktop
  static native.RtcEngine? _engine;

  static Future<void> initializeNative(String appId) async {
    if (kIsWeb) return;
    if (_engine != null) return;

    _engine = native.createAgoraRtcEngine();
    await _engine!.initialize(
      native.RtcEngineContext(
          appId: appId,
          channelProfile:
              native.ChannelProfileType.channelProfileLiveBroadcasting),
    );

    // Enable video and audio
    await _engine!.enableVideo();
    await _engine!.enableAudio();
  }

  static Future<bool> joinChannel({
    required String appId,
    required String channelName,
    required String token,
    required String uid,
  }) async {
    _consoleLog('ðŸŒ joinChannel called - kIsWeb: $kIsWeb');
    debugPrint(
        '[DEBUG] AgoraPlatformService.joinChannel() called with kIsWeb=$kIsWeb');
    AppLogger.info('ðŸŒ joinChannel called - kIsWeb: $kIsWeb');

    if (kIsWeb) {
      // ========================================================================
      // AGORA WEB DISABLED: Allow web to join room WITHOUT voice/video
      // ========================================================================
      if (AGORA_WEB_DISABLED) {
        debugPrint(
            '[AGORA_WEB] ðŸŸ¡ Agora Web is DISABLED - Allowing room join without video/audio');
        AppLogger.warning(
            'ðŸŸ¡ Agora Web DISABLED: Joining room without voice/video');
        debugPrint('[AGORA_WEB]    Channel: $channelName');
        debugPrint('[AGORA_WEB]    UID: $uid');
        debugPrint(
            '[AGORA_WEB]    Web users can: Chat âœ…, Presence âœ…, UI âœ…, Voice/Video âŒ');
        return true; // Pretend join succeeded - room UI will render
      }

      _consoleLog('âœ… WEB PATH: Initializing AgoraWebBridgeV3 (SDK v5)');
      debugPrint('[DEBUG] WEB PATH: Initializing web bridge...');
      AppLogger.info('âœ… WEB PATH: Initializing Agora Web SDK v5');

      // === STEP 1: Initialize bridge ===
      debugPrint('[DEBUG] Calling AgoraWebBridgeV3.init()...');
      final initSuccess = await AgoraWebBridgeV3.init(appId);
      debugPrint('[DEBUG] AgoraWebBridgeV3.init() returned: $initSuccess');

      if (!initSuccess) {
        _consoleLog('âŒ Failed to initialize Agora');
        debugPrint('[DEBUG] Init failed, returning false');
        AppLogger.error('âŒ Failed to initialize Agora');

        // Debug output for troubleshooting
        _printDebugState();
        return false;
      }

      // === STEP 2: JOIN CHANNEL ===
      // The production bridge handles permissions automatically during join
      _consoleLog('âœ… WEB PATH: Calling AgoraWebBridgeV3.joinChannel()');
      debugPrint(
          '[DEBUG] Calling AgoraWebBridgeV3.joinChannel() with $channelName...');
      AppLogger.info('ðŸ”— Joining Agora channel: $channelName');

      final result = await AgoraWebBridgeV3.joinChannel(
        appId: appId,
        channelName: channelName,
        token: token,
        uid: uid,
      );
      debugPrint('[DEBUG] AgoraWebBridgeV3.joinChannel() returned: $result');

      if (!result) {
        _consoleLog('âŒ Failed to join channel');
        AppLogger.error('âŒ Failed to join channel');

        // Debug output for troubleshooting
        _printDebugState();
        return false;
      }

      _consoleLog('âœ… WEB PATH: Successfully joined channel');
      AppLogger.info('âœ… WEB PATH: Successfully joined channel');
      return result;
    }

    AppLogger.info('ðŸ“± NATIVE PATH: Using Agora NATIVE SDK (Flutter)');
    if (_engine == null) {
      AppLogger.info('Initializing Agora native engine...');
      await initializeNative(appId);
    }

    AppLogger.info('Calling Agora native joinChannel...');
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: int.tryParse(uid) ?? 0,
      options: const native.ChannelMediaOptions(
        clientRoleType: native.ClientRoleType.clientRoleBroadcaster,
        channelProfile:
            native.ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    AppLogger.info('Agora native joinChannel successful');

    return true;
  }

  static Future<bool> leaveChannel() async {
    if (kIsWeb) {
      if (AGORA_WEB_DISABLED) {
        debugPrint(
            '[AGORA_WEB] ðŸŸ¡ Agora Web disabled - leaveChannel is no-op');
        return true; // No-op since join was skipped
      }
      return AgoraWebBridgeV3.leaveChannel();
    }

    if (_engine == null) return false;
    await _engine!.leaveChannel();
    return true;
  }

  static Future<void> setMicMuted(bool muted) async {
    if (kIsWeb) {
      if (AGORA_WEB_DISABLED) {
        debugPrint(
            '[AGORA_WEB] ðŸŸ¡ Agora Web disabled - setMicMuted is no-op');
        return; // No-op since Agora is disabled
      }
      await AgoraWebBridgeV3.setMicMuted(muted);
      return;
    }

    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(muted);
  }

  static Future<void> setVideoMuted(bool muted) async {
    if (kIsWeb) {
      if (AGORA_WEB_DISABLED) {
        debugPrint(
            '[AGORA_WEB] ðŸŸ¡ Agora Web disabled - setVideoMuted is no-op');
        return; // No-op since Agora is disabled
      }
      await AgoraWebBridgeV3.setVideoMuted(muted);
      return;
    }

    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(muted);
  }

  /// Renew the Agora token for the current session without re-joining.
  /// Call this when [onTokenPrivilegeWillExpire] fires or on a ~23h refresh timer.
  static Future<bool> renewToken(String token) async {
    if (kIsWeb) {
      if (AGORA_WEB_DISABLED) return true;
      return AgoraWebBridgeV3.renewToken(token);
    }
    if (_engine == null) return false;
    try {
      await _engine!.renewToken(token);
      AppLogger.info('✅ Agora token renewed');
      return true;
    } catch (e) {
      AppLogger.error('renewToken failed: $e');
      return false;
    }
  }

  /// Initialize web-specific Agora instance
  static Future<bool> initializeWeb(String appId) async {
    if (!kIsWeb) return false;
    if (AGORA_WEB_DISABLED) {
      debugPrint(
          '[AGORA_WEB] ðŸŸ¡ Agora Web disabled - initializeWeb is no-op');
      return true; // Return success to allow room join without video
    }
    // Web initialization happens in joinChannel
    return true;
  }

  /// Get web bridge state for debugging
  static Map<String, dynamic> getWebBridgeState() {
    if (!kIsWeb) return {};
    if (AGORA_WEB_DISABLED) return {'disabled': true};
    try {
      return AgoraWebBridgeV3.getState();
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Enable debug logging for Web (external API method)
  static void enableWebDebugLogging() {
    if (kIsWeb && !AGORA_WEB_DISABLED) {
      AgoraWebBridgeV3.enableDebugLogging();
      AppLogger.info('ðŸ” Agora Web debug logging enabled');
    }
  }

  /// Enable debug logging for Web (internal)
  static void enableDebugLogging() {
    if (kIsWeb) {
      AgoraWebBridgeV3.enableDebugLogging();
      AppLogger.info('ðŸ” Agora Web debug logging enabled');
    }
  }

  /// Print debug state (Web only)
  static void _printDebugState() {
    if (!kIsWeb) return;

    try {
      final state = AgoraWebBridgeV3.getState();
      debugPrint('[DEBUG] Agora Web State:');
      state.forEach((key, value) {
        debugPrint('  $key: $value');
      });

      // Print to browser console too
      AgoraWebBridgeV3.printDebugInfo();
    } catch (e) {
      debugPrint('[DEBUG] Could not get state: $e');
    }
  }

  static native.RtcEngine? get engine => _engine;
}
