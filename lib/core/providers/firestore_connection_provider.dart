import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Monitors Firestore connection health
/// Returns true if connection is active, false if disconnected
final firestoreConnectionProvider = StreamProvider<bool>((ref) {
  final firestore = ref.watch(firestoreProvider);
  
  // On web, Firestore doesn't provide a direct connection status stream
  // So we create a synthetic stream by monitoring a snapshot listener
  try {
    return firestore
        .collection('_connection_check')
        .doc('status')
        .snapshots()
        .map((snapshot) {
          debugPrint('[Firestore] Connection check: document exists = ${snapshot.exists}');
          return true;  // If we can get snapshots, connection is working
        })
        .handleError((error) {
          debugPrint('[Firestore] Connection error detected: $error');
          return false;
        });
  } catch (e) {
    debugPrint('[Firestore] Failed to set up connection monitor: $e');
    return Stream.value(false);
  }
});

/// Provides enhanced error handling for Firestore queries
/// Catches common connection and permission errors
extension FirestoreErrorHandling on Future<QuerySnapshot<Map<String, dynamic>>> {
  Future<QuerySnapshot<Map<String, dynamic>>> withErrorLogging(String context) {
    return catchError((error, stackTrace) {
      debugPrint('[Firestore] Error in $context: $error');
      debugPrint('$stackTrace');
      
      // Re-throw to allow upstream handling
      throw error;
    });
  }
}

/// Extension for DocumentSnapshot error handling
extension FirestoreDocErrorHandling on Future<DocumentSnapshot<Map<String, dynamic>>> {
  Future<DocumentSnapshot<Map<String, dynamic>>> withErrorLogging(String context) {
    return catchError((error, stackTrace) {
      debugPrint('[Firestore] Document error in $context: $error');
      debugPrint('$stackTrace');
      
      // Re-throw to allow upstream handling
      throw error;
    });
  }
}

/// Provider for Firestore health diagnostics
final firestoreHealthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final startTime = DateTime.now();
  
  try {
    // Attempt a simple read to test connectivity
    await firestore
        .collection('_health_check')
        .limit(1)
        .get()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Firestore health check timed out', const Duration(seconds: 5));
          },
        );
    
    final duration = DateTime.now().difference(startTime);
    
    return {
      'status': 'healthy',
      'latencyMs': duration.inMilliseconds,
      'timestamp': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    return {
      'status': 'unhealthy',
      'error': e.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
});
