import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Detects if Firestore WebSocket connections are failing and activates emergency polling mode.
/// 
/// This service monitors Firestore listener creation and detects `net::ERR_ABORTED` patterns,
/// automatically enabling polling-based data fetching as a fallback when WebSocket fails.
/// 
/// Typical failure pattern:
/// - User opens app
/// - Firestore tries to open WebSocket to /google.firestore.v1.Firestore/Listen/channel
/// - Browser extension intercepts and aborts the connection
/// - App detects failure pattern and switches to polling mode
/// - Discovery feed loads successfully via REST API polling

class FirestoreConnectionFallback {
  static final FirestoreConnectionFallback _instance =
      FirestoreConnectionFallback._internal();

  factory FirestoreConnectionFallback() {
    return _instance;
  }

  FirestoreConnectionFallback._internal();

  /// Global flag: when true, use polling instead of real-time listeners
  static bool isPollingModeEnabled = false;

  /// Tracks connection failure attempts
  static int _connectionFailureCount = 0;
  static const int _failureThreshold = 3; // Trigger polling after 3 failures

  /// Call this from FirebaseOptions or firebase_providers initialization
  /// to enable automatic fallback detection
  static void enableFallbackDetection(FirebaseFirestore firestore) {
    if (kDebugMode) {
      debugPrint('[FirestoreConnectionFallback] Fallback detection enabled');
    }

    // Monitor for listener failures by attempting a test subscription
    _attemptTestSubscription(firestore);
  }

  /// Attempt a test subscription to detect WebSocket failures early
  static Future<void> _attemptTestSubscription(
      FirebaseFirestore firestore) async {
    try {
      // Create a test collection reference
      final testRef = firestore.collection('_firestore_test_');

      // Try to listen for 2 seconds
      final subscription = testRef.limit(1).snapshots().listen(
        (snapshot) {
          if (kDebugMode) {
            debugPrint('[FirestoreConnectionFallback] ✅ Real-time listener works');
          }
          _connectionFailureCount = 0;
          isPollingModeEnabled = false;
        },
        onError: (error) {
          _handleListenerError(error);
        },
      );

      // Cancel after 2 seconds (it's just a test)
      await Future.delayed(const Duration(seconds: 2));
      await subscription.cancel();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirestoreConnectionFallback] Test subscription error: $e');
      }
      _handleListenerError(e);
    }
  }

  /// Handle listener errors and activate polling if threshold reached
  static void _handleListenerError(dynamic error) {
    _connectionFailureCount++;

    if (kDebugMode) {
      debugPrint(
        '[FirestoreConnectionFallback] Connection failure #$_connectionFailureCount: $error',
      );
    }

    // If we've failed multiple times, switch to polling mode
    if (_connectionFailureCount >= _failureThreshold) {
      if (!isPollingModeEnabled) {
        debugPrint(
          '[FirestoreConnectionFallback] ⚠️  ACTIVATING POLLING MODE - WebSocket likely blocked',
        );
        isPollingModeEnabled = true;
      }
    }
  }

  /// Reset failure counter (call after successful WebSocket connection)
  static void resetFailureCount() {
    _connectionFailureCount = 0;
    if (isPollingModeEnabled) {
      debugPrint(
        '[FirestoreConnectionFallback] ✅ WebSocket recovered - disabling polling mode',
      );
      isPollingModeEnabled = false;
    }
  }

  /// Get current mode status
  static String getStatus() {
    return isPollingModeEnabled
        ? '🔴 POLLING MODE (WebSocket blocked)'
        : '🟢 REAL-TIME MODE (WebSocket active)';
  }

  /// Manually force polling mode (useful for testing)
  static void forcePollingMode() {
    isPollingModeEnabled = true;
    debugPrint('[FirestoreConnectionFallback] Polling mode forced');
  }

  /// Manually force real-time mode (useful for testing)
  static void forceRealtimeMode() {
    isPollingModeEnabled = false;
    _connectionFailureCount = 0;
    debugPrint('[FirestoreConnectionFallback] Real-time mode forced');
  }
}

/// Extension method for easy polling mode check
extension FirestorePollingExtension on FirebaseFirestore {
  bool get isPollingMode => FirestoreConnectionFallback.isPollingModeEnabled;

  String get connectionStatus =>
      FirestoreConnectionFallback.getStatus();
}
