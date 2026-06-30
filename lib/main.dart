import 'dart:ui' as ui;                   

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
    
    // Initialize Firebase App Check (critical security: blocks bot attacks on Firestore)
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider('6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU'),  // ← ReCAPTCHA v3 site key for Web
        providerAndroid: AndroidPlayIntegrityProvider(),  // ← Play Integrity API for Android
        // providerApple: DeviceCheckProvider() on iOS (available via firebase_app_check_web/ios)
      );
      debugPrint('[Firebase] App Check activated successfully');
    } catch (e) {
      debugPrint('[Firebase] App Check activation warning: $e (non-critical, continuing)');
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