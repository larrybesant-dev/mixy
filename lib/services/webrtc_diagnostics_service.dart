import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mixvy/core/logger.dart';

class WebRtcCrashlyticsDiagnostics {
  /// Logs diagnostic metadata and records a non-fatal error to Firebase Crashlytics
  /// to enable real-time debugging of live room WebRTC drops.
  static void logConnectionError({
    required String roomId,
    required String localUserId,
    required int participantCount,
    required String connectionState,
    required String errorDetail,
    required Map<String, dynamic> peerIceStates,
  }) {
    try {
      final crashlytics = FirebaseCrashlytics.instance;

      // 1. Set custom keys for quick, structured dashboard filtering
      crashlytics.setCustomKey('webrtc_room_id', roomId);
      crashlytics.setCustomKey('webrtc_local_user_id', localUserId);
      crashlytics.setCustomKey('webrtc_participant_count', participantCount);
      crashlytics.setCustomKey('webrtc_connection_state', connectionState);
      crashlytics.setCustomKey(
          'webrtc_failure_type', 'webrtc_handshake_or_ice_failure');

      // 2. Log chronological events for root cause analysis
      crashlytics.log('[WebRTC][FAIL] Session Room ID: $roomId');
      crashlytics.log('[WebRTC][FAIL] Initiating User ID: $localUserId');
      crashlytics.log('[WebRTC][FAIL] Connection State: $connectionState');
      crashlytics
          .log('[WebRTC][FAIL] Peer Count at failure: $participantCount');
      crashlytics
          .log('[WebRTC][FAIL] Detailed Peer ICE States: $peerIceStates');
      crashlytics.log('[WebRTC][FAIL] Error Reason: $errorDetail');

      // 3. Record non-fatal exception to trigger instant alerts
      crashlytics.recordError(
        Exception(
            'WebRTC Drop in Room $roomId ($connectionState): $errorDetail'),
        StackTrace.current,
        reason: 'Handshake timeout or ICE connection severed in Room $roomId',
        fatal: false, // Non-fatal so we do not crash the user's application
      );

      Logger.info(
          '[Crashlytics] Recorded WebRTC connection failure diagnostic successfully.');
    } catch (e, st) {
      Logger.error('[Crashlytics] Error recording diagnostic: $e',
          error: e, stackTrace: st);
    }
  }
}
