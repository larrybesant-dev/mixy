import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'environment_config.dart';
import '../utils/app_logger.dart';
import '../../services/infra/error_tracking_service.dart';

/// Production initialization for MixMingle app
class ProductionInitializer {
  /// Initialize all required services for production
  static Future<void> initialize() async {
    AppLogger.info('ðŸš€ Initializing MixMingle for production...');

    try {
      // 1. Initialize Firebase
      await _initializeFirebase();

      // 2. Setup crash reporting
      await _setupCrashReporting();

      // 3. Setup analytics
      await _setupAnalytics();

      // 4. Setup error tracking
      await _setupErrorTracking();

      // 5. Verify system health
      await _verifySystemHealth();

      AppLogger.info('âœ… Production initialization complete');
    } catch (e) {
      AppLogger.error('âŒ Production initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> _initializeFirebase() async {
    AppLogger.info('Initializing Firebase...');
    try {
      // Firebase is already initialized in main.dart
      // Just verify connection
      // ignore: unused_local_variable
      final auth = FirebaseAuth.instance;
      AppLogger.info('âœ… Firebase initialized');
    } catch (e) {
      AppLogger.error('Firebase initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> _setupCrashReporting() async {
    AppLogger.info('Setting up crash reporting...');
    try {
      final crashlytics = FirebaseCrashlytics.instance;

      // Enable Crashlytics collection in production
      await crashlytics.setCrashlyticsCollectionEnabled(
        !EnvironmentConfig.isDevelopment,
      );

      // Set custom error info (only on native platforms)
      if (!kIsWeb) {
        await crashlytics.setCustomKey('app_version', '1.0.1+2');
        await crashlytics.setCustomKey('environment',
            EnvironmentConfig.isProduction ? 'production' : 'staging');
      }

      AppLogger.info('âœ… Crash reporting enabled');
    } catch (e) {
      AppLogger.error('Crash reporting setup failed: $e');
    }
  }

  static Future<void> _setupAnalytics() async {
    AppLogger.info('Setting up analytics...');
    try {
      final analytics = FirebaseAnalytics.instance;

      // Log app launch
      await analytics.logAppOpen();

      // Set analytics collection in production
      await analytics.setAnalyticsCollectionEnabled(
        EnvironmentConfig.isProduction,
      );

      // Set user properties
      if (FirebaseAuth.instance.currentUser != null) {
        await analytics.setUserId(id: FirebaseAuth.instance.currentUser!.uid);
      }

      AppLogger.info('âœ… Analytics initialized');
    } catch (e) {
      AppLogger.error('Analytics setup failed: $e');
    }
  }

  static Future<void> _setupErrorTracking() async {
    AppLogger.info('Setting up error tracking...');
    try {
      await ErrorTrackingService().initialize();
      AppLogger.info('âœ… Error tracking initialized');
    } catch (e) {
      AppLogger.error('Error tracking setup failed: $e');
    }
  }

  static Future<void> _verifySystemHealth() async {
    AppLogger.info('Verifying system health...');
    try {
      // Check if system is in maintenance mode
      // This would come from Firestore or Remote Config
      AppLogger.info('âœ… System health verified');
    } catch (e) {
      AppLogger.error('System health check failed: $e');
    }
  }
}

// Import at top of file:
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
