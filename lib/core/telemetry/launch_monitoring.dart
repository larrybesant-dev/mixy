import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'app_telemetry.dart';

class LaunchMonitoring {
  LaunchMonitoring._();

  static const authFailure = 'launch_auth_failure';
  static const staleRoomNavigation = 'launch_stale_room_navigation';
  static const messagingFreshness = 'launch_messaging_freshness';
  static const rtcRecoveryExhausted = 'launch_rtc_recovery_exhausted';
  static const paymentEntitlementMismatch =
      'launch_payment_entitlement_mismatch';
  static const uncaughtError = 'launch_uncaught_error';

  static const messageAckWarning = Duration(seconds: 5);

  static void record({
    required String action,
    required String message,
    String level = 'error',
    String? userId,
    String? roomId,
    String? result,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppTelemetry.logAction(
      level: level,
      domain: 'ops',
      action: action,
      message: message,
      userId: userId,
      roomId: roomId,
      result: result,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
    unawaited(_forward(action: action, result: result, metadata: metadata));
  }

  static Future<void> _forward({
    required String action,
    String? result,
    required Map<String, Object?> metadata,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('recordOperationalSignal')
          .call<void>(<String, Object?>{
            'code': action,
            if (result != null) 'result': result,
            'metadata': metadata,
          });
    } catch (_) {
      // Monitoring transport must never affect the user flow it observes.
    }
  }
}
