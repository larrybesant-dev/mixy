import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Monitors Firestore connection health and provides connection status
/// This helps detect and display when Firestore real-time sync is unavailable
final firestoreHealthMonitorProvider = StreamProvider<FirestoreHealthStatus>((ref) async* {
  final firestore = FirebaseFirestore.instance;
  var connectionAttempts = 0;
  var failureCount = 0;
  
  // Create a stream that polls Firestore health periodically
  Stream<void> healthCheckStream() async* {
    while (true) {
      try {
        connectionAttempts++;
        
        // Attempt a quick Firestore operation
        await firestore
            .collection('_health')
            .doc('check')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
        
        // If successful, reset failure count
        failureCount = 0;
        yield FirestoreHealthStatus.healthy(
          connectionAttempts: connectionAttempts,
          latencyMs: 0,
        );
      } catch (e) {
        failureCount++;
        debugPrint('[Firestore Health] Connection attempt $connectionAttempts failed: $e');
        
        // If we've had multiple failures, we're degraded
        if (failureCount > 2) {
          yield FirestoreHealthStatus.degraded(
            failureCount: failureCount,
            lastError: e.toString(),
          );
        } else {
          yield FirestoreHealthStatus.connecting();
        }
      }
      
      // Wait 10 seconds before next check
      await Future.delayed(const Duration(seconds: 10));
    }
  }
  
  await for (final _ in healthCheckStream()) {
    yield FirestoreHealthStatus.checking();
  }
});

/// Firestore connection health status
sealed class FirestoreHealthStatus {
  const FirestoreHealthStatus();
  
  factory FirestoreHealthStatus.healthy({
    required int connectionAttempts,
    required int latencyMs,
  }) = FirestoreHealthy;
  
  factory FirestoreHealthStatus.connecting() = FirestoreConnecting;
  
  factory FirestoreHealthStatus.checking() = FirestoreChecking;
  
  factory FirestoreHealthStatus.degraded({
    required int failureCount,
    required String lastError,
  }) = FirestoreDegraded;
  
  factory FirestoreHealthStatus.offline({
    required String reason,
  }) = FirestoreOffline;
  
  bool get isHealthy => this is FirestoreHealthy;
  bool get isDegraded => this is FirestoreDegraded;
  bool get isOffline => this is FirestoreOffline;
  bool get isConnecting => this is FirestoreConnecting;
}

class FirestoreHealthy extends FirestoreHealthStatus {
  const FirestoreHealthy({
    required this.connectionAttempts,
    required this.latencyMs,
  });
  
  final int connectionAttempts;
  final int latencyMs;
}

class FirestoreConnecting extends FirestoreHealthStatus {
  const FirestoreConnecting();
}

class FirestoreChecking extends FirestoreHealthStatus {
  const FirestoreChecking();
}

class FirestoreDegraded extends FirestoreHealthStatus {
  const FirestoreDegraded({
    required this.failureCount,
    required this.lastError,
  });
  
  final int failureCount;
  final String lastError;
  
  @override
  String toString() => 'FirestoreDegraded($failureCount failures: $lastError)';
}

class FirestoreOffline extends FirestoreHealthStatus {
  const FirestoreOffline({
    required this.reason,
  });
  
  final String reason;
  
  @override
  String toString() => 'FirestoreOffline: $reason';
}
