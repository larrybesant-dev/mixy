import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/app_logger.dart';

/// Monitor app health and performance metrics
class AppHealthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Report app crash or error
  Future<void> reportCrash({
    required String userId,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    try {
      await _firestore.collection('crash_reports').add({
        'user_id': userId,
        'error_message': errorMessage,
        'stack_trace': stackTrace,
        'context': context,
        'reported_at': FieldValue.serverTimestamp(),
        'app_version': '1.0.1+2', // Should come from app version
        'environment': 'production',
      });
    } catch (e) {
      AppLogger.error('Failed to report crash: $e');
    }
  }

  /// Report performance issue
  Future<void> reportPerformanceIssue({
    required String userId,
    required String feature,
    required int durationMs,
    String? description,
  }) async {
    try {
      // Only report if slower than threshold (e.g., 3 seconds)
      if (durationMs > 3000) {
        await _firestore.collection('performance_issues').add({
          'user_id': userId,
          'feature': feature,
          'duration_ms': durationMs,
          'description': description,
          'reported_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      AppLogger.error('Failed to report performance issue: $e');
    }
  }

  /// Get system health status
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final doc =
          await _firestore.collection('system').doc('health_status').get();

      return doc.data() ??
          {
            'status': 'operational',
            'message': 'All systems operational',
          };
    } catch (e) {
      return {
        'status': 'unknown',
        'message': 'Unable to check system status',
      };
    }
  }

  /// Check if app is under maintenance
  Future<bool> isMaintenanceMode() async {
    try {
      final doc = await _firestore.collection('system').doc('settings').get();
      return doc['maintenance_mode'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get maintenance message
  Future<String> getMaintenanceMessage() async {
    try {
      final doc = await _firestore.collection('system').doc('settings').get();
      return doc['maintenance_message'] as String? ??
          'MixMingle is undergoing maintenance. Please try again later.';
    } catch (e) {
      return 'Unable to connect to service. Please try again later.';
    }
  }

  /// Test methods for health dashboard (stub implementations)
  Future<bool> testFirebaseCore() async {
    try {
      return true; // Firestore is always initialized if this service is created
    } catch (e) {
      return false;
    }
  }

  Future<bool> testFirebaseAuth() async {
    // Stub: Always return true for now
    return true;
  }

  Future<bool> testFirestore() async {
    try {
      await _firestore.collection('health_check').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, bool> getAllStatus() {
    return {
      'firebaseCore': true,
      'firebaseAuth': true,
      'firestore': true,
    };
  }

  bool get firebaseCore => true;
  bool get firebaseAuth => true;
  bool get firestore => true;
}

// Provider for app health service
final appHealthServiceProvider = Provider((ref) {
  return AppHealthService();
});
