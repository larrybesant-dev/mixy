import 'dart:ui' as ui;                   

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/firebase_options.dart'; 
import 'observability/provider_observer.dart';
import 'observability/startup_timeline.dart';
import 'app/app.dart';
import 'app/boot_state.dart';
import 'app/boot_state_notifier.dart';
import 'core/logger.dart';
import 'services/diagnostic_logger.dart';

// ignore: unused_element
const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev-local',
);

Future<void> main() async {
  final startup = StartupProfiler.instance;
  startup.markAppStartTime();
  startup.markMainStart();

  WidgetsFlutterBinding.ensureInitialized();
  startup.markBindingReady();

  // Initialize Firebase native platform bindings cleanly BEFORE layout initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] Firebase initialized successfully');
    
    // Enable Firestore offline persistence on web to stabilize auth token handling
    if (kIsWeb) {
      try {
        await FirebaseFirestore.instance.enableNetwork();
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,  // Disable local caching on web to avoid stale data
          sslEnabled: true,
          host: 'firestore.googleapis.com',
        );
        debugPrint('[Firebase] Firestore web settings configured');
      } catch (e) {
        debugPrint('[Firebase] Firestore settings error (non-fatal): $e');
      }
    }
    
    // Firestore settings are now managed by firestoreProvider in firebase_providers.dart
    // (Settings configured automatically when provider is first accessed)
    debugPrint('[Firebase] Firestore initialization delegated to firestoreProvider');
    
    // Setup production logging: Route [MIXVY_DEBUG] logs to Firebase Crashlytics
    if (!kDebugMode) {
      DiagnosticLogger.setProductionHandler((log) {
        // Route all diagnostic logs to Crashlytics
        FirebaseCrashlytics.instance.recordError(
          log.message,
          StackTrace.current,
          reason: '${log.category} [${log.severity}]',
          printDetails: true,
          fatal: log.severity == 'CRIT', // Mark CRITICAL logs as fatal
        );
        
        // Also add to custom keys for dashboard filtering
        FirebaseCrashlytics.instance.setCustomKey('diagnostic_severity', log.severity);
        FirebaseCrashlytics.instance.setCustomKey('diagnostic_category', log.category);
        
        // Log structured metadata if present
        if (log.metadata != null && log.metadata!.isNotEmpty) {
          FirebaseCrashlytics.instance.setCustomKey(
            'diagnostic_metadata',
            log.metadata.toString(),
          );
        }
      });
      debugPrint('[Logging] Production handler configured for Firebase Crashlytics');
    } else {
      debugPrint('[Logging] Development mode: DiagnosticLogger will output to console');
    }
  } catch (e) {
    debugPrint('[Firebase] Firebase initialization failed: $e');
    Logger.error('Firebase initialization failed', error: e);
  }

  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Logger.error(
      'Unhandled Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
      fatal: true,
    );
  };

  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    Logger.error(
      'Unhandled platform error',
      error: error,
      stackTrace: stackTrace,
      fatal: true,
    );
    return true;
  };

  runApp(
    ProviderScope(
      observers: [MixvyProviderObserver()],
      overrides: [
        bootStateProvider.overrideWith(
          (ref) => BootStateNotifier(initialState: BootState.loading),
        ),
      ],
      child: const MixVyApp(),
    ),
  );
}