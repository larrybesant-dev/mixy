import 'dart:ui' as ui;                   

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/firebase_options.dart'; 
import 'observability/provider_observer.dart';
import 'observability/startup_timeline.dart';
import 'app/app.dart';
import 'app/boot_state.dart';
import 'app/boot_state_notifier.dart';
import 'core/logger.dart';

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
    
    // Initialize Firebase App Check (critical security: blocks bot attacks on Firestore)
    // PRODUCTION: Enforced reCAPTCHA v3 + Play Integrity validation
    // SOFT LAUNCH: Web platform bypasses AppCheck; Firestore Rules enforce security
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: AndroidPlayIntegrityProvider(),
        );
        debugPrint('[Firebase] App Check activated on Android (Play Integrity)');
      } catch (e) {
        debugPrint('[Firebase] App Check activation error on Android: $e');
      }
    } else {
      // Web soft-launch: AppCheck disabled to unblock testing
      // Firestore Security Rules provide access control
      // Production: When ready, uncomment below and provide reCAPTCHA site key
      //
      // try {
      //   await FirebaseAppCheck.instance.activate(
      //     webRecaptchaSiteKey: 'YOUR_RECAPTCHA_V3_SITE_KEY_HERE',
      //   );
      //   debugPrint('[Firebase] App Check activated on web (reCAPTCHA v3)');
      // } catch (e) {
      //   debugPrint('[Firebase] App Check activation warning: $e');
      // }
      
      debugPrint('[Firebase] App Check disabled on web (soft-launch phase; Firestore Rules + Auth enforce security)');
    }
    
    // Firestore settings are now managed by firestoreProvider in firebase_providers.dart
    // (Settings configured automatically when provider is first accessed)
    debugPrint('[Firebase] Firestore initialization delegated to firestoreProvider');
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