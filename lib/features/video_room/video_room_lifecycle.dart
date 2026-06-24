import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import '../../core/utils/app_logger.dart';
import '../../services/agora/agora_platform_service.dart';

/// Manages video room lifecycle: init â†’ join â†’ leave â†’ cleanup
class VideoRoomLifecycle {
  final String appId;
  final String userId;

  VideoRoomLifecycle({
    required this.appId,
    required this.userId,
  });

  /// Initialize Agora SDK
  /// Must be called before joining a room
  /// Throws exception if initialization fails
  Future<void> initialize() async {
    try {
      debugPrint('[VIDEO_ROOM] Initializing Agora SDK...');
      AppLogger.info('ðŸ“± Initializing Agora SDK...');

      await AgoraPlatformService.initializeNative(appId);

      if (kIsWeb) {
        final initialized = await AgoraPlatformService.initializeWeb(appId);
        if (!initialized) {
          throw Exception('Failed to initialize Agora Web SDK');
        }
      }

      debugPrint('[VIDEO_ROOM] Agora SDK initialized successfully');
      AppLogger.info('âœ… Agora SDK initialized successfully');
    } catch (e) {
      debugPrint('[VIDEO_ROOM] Failed to initialize: $e');
      AppLogger.error('âŒ Agora initialization failed: $e');
      rethrow;
    }
  }

  /// Request camera and microphone permissions (if on mobile)
  /// Returns true if permissions granted, false if denied
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      // Web browser handles permissions via browser dialog
      debugPrint(
          '[VIDEO_ROOM] Web platform - browser will request permissions');
      return true;
    }

    try {
      debugPrint(
          '[VIDEO_ROOM] Requesting camera and microphone permissions...');
      AppLogger.info('ðŸ” Requesting camera & microphone permissions...');

      // TODO: Implement mobile permission requests
      // For now, assume permissions are granted
      return true;
    } catch (e) {
      debugPrint('[VIDEO_ROOM] Permission request failed: $e');
      AppLogger.error('âŒ Permission request failed: $e');
      return false;
    }
  }

  /// Join a video channel
  /// Prerequisites:
  /// - Initialize() must have been called
  /// - User must be authenticated
  /// - User must have room access permission
  /// - Token must be valid
  Future<void> joinChannel({
    required String roomId,
    required String roomName,
    required String token,
  }) async {
    try {
      debugPrint('[VIDEO_ROOM] Joining channel: $roomName (room: $roomId)');
      AppLogger.info('ðŸ”— Joining channel: $roomName...');

      final joined = await AgoraPlatformService.joinChannel(
        appId: appId,
        channelName: roomName,
        token: token,
        uid: userId,
      );

      if (!joined) {
        throw Exception('Failed to join channel');
      }

      debugPrint('[VIDEO_ROOM] Successfully joined channel: $roomName');
      AppLogger.info('âœ… Successfully joined channel: $roomName');
    } catch (e) {
      debugPrint('[VIDEO_ROOM] Failed to join channel: $e');
      AppLogger.error('âŒ Failed to join channel: $e');
      rethrow;
    }
  }

  /// Leave the current video channel
  /// Does cleanup: mute audio/video, disconnect
  Future<void> leaveChannel() async {
    try {
      debugPrint('[VIDEO_ROOM] Leaving channel...');
      AppLogger.info('ðŸ‘‹ Leaving channel...');

      // Mute audio and video before leaving
      await Future.wait([
        AgoraPlatformService.setMicMuted(true),
        AgoraPlatformService.setVideoMuted(true),
      ]);

      // Leave the channel
      await AgoraPlatformService.leaveChannel();

      debugPrint('[VIDEO_ROOM] Successfully left channel');
      AppLogger.info('âœ… Left channel successfully');
    } catch (e) {
      debugPrint('[VIDEO_ROOM] Error leaving channel: $e');
      AppLogger.warning('âš ï¸ Error during cleanup: $e');
      // Don't rethrow - cleanup errors shouldn't prevent app closure
    }
  }

  /// Enable or disable microphone
  Future<void> setMicMuted(bool muted) async {
    try {
      await AgoraPlatformService.setMicMuted(muted);
      AppLogger.info('ðŸŽ¤ Microphone ${muted ? 'muted' : 'unmuted'}');
    } catch (e) {
      debugPrint('[VIDEO_ROOM] Failed to set mic mute: $e');
      AppLogger.error('âŒ Microphone control failed: $e');
      rethrow;
    }
  }

  /// Enable or disable video camera
  Future<void> setVideoMuted(bool muted) async {
    try {
      await AgoraPlatformService.setVideoMuted(muted);
      AppLogger.info('ðŸ“¹ Camera ${muted ? 'disabled' : 'enabled'}');
    } catch (e) {
      debugPrint('[VIDEO_ROOM] Failed to set video mute: $e');
      AppLogger.error('âŒ Camera control failed: $e');
      rethrow;
    }
  }

  /// Get current bridge state (for debugging)
  Map<String, dynamic> getState() {
    if (kIsWeb) {
      return AgoraPlatformService.getWebBridgeState();
    }
    return {};
  }

  /// Enable debug logging
  void enableDebugLogging() {
    if (kIsWeb) {
      AgoraPlatformService.enableWebDebugLogging();
    }
  }
}
