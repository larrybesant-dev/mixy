import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import 'boot_state_notifier.dart';
import '../router/app_router.dart';
import '../observability/startup_timeline.dart';
import '../firebase_options.dart';
import '../services/push_messaging_service.dart';

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final startup = StartupProfiler.instance;
  final bootStateNotifier = ref.read(bootStateProvider.notifier);
  bootStateNotifier.setLoading();

  final bootstrapWatchdog = Timer(const Duration(seconds: 10), () {
    if (bootStateNotifier.isLoadingState) {
      bootStateNotifier.setFailed();
      startup.markBootstrapResolved(
        resolution: BootstrapResolution.failed,
        detail: 'reason=bootstrap_timeout',
      );
      developer.log(
        'BOOTSTRAP TIMEOUT: exceeded 10s while still loading',
        name: 'appBootstrapProvider',
      );
    }
  });

  var hasDegradedDependency = false;

  try {
    final hasInjectedEnv = AppEnv.isConfigured;

    if (kIsWeb && hasInjectedEnv) {
      developer.log('ENV: Using injected environment variables (dart-define)',
          name: 'appBootstrapProvider');
    }

    try {
      await dotenv.load(fileName: '.env').timeout(const Duration(seconds: 10));
    } catch (error) {
      developer.log('ENV LOAD FAILED (primary): $error',
          name: 'appBootstrapProvider');
      try {
        await dotenv
            .load(fileName: 'assets/.env')
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        if (!hasInjectedEnv) {
          hasDegradedDependency = true;
        }
      }
    }

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: kIsWeb ? 30 : 10));
      } catch (e) {
        developer.log('FIREBASE INITIALIZE FAILED: $e',
            name: 'appBootstrapProvider');
        bootStateNotifier.setFailed();
        startup.markFirebaseReady(success: false, error: e);
        startup.markBootstrapResolved(
          resolution: BootstrapResolution.failed,
          detail: 'reason=firebase_init_failed_internal',
        );
        return;
      }
    }

    // 3. Configure Firestore settings - SIMPLIFIED for compatibility
    if (Firebase.apps.isNotEmpty) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        developer.log('FIRESTORE SETTINGS FAILED: $e',
            name: 'appBootstrapProvider');
      }
    }

    // 4. Initialize optional services
    try {
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
      }

      PushMessagingService.instance.setNavigatorKey(rootNavigatorKey);
      await PushMessagingService.instance.initialize().timeout(
            const Duration(seconds: 5),
          );
    } catch (error) {
      developer.log('PUSH INIT FAILED: $error', name: 'appBootstrapProvider');
      hasDegradedDependency = true;
    }

    try {
      if (!kIsWeb && const bool.fromEnvironment('dart.vm.product')) {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(
              true,
            )
            .timeout(const Duration(seconds: 2));
      }
    } catch (error) {
      developer.log('CRASHLYTICS INIT FAILED: $error',
          name: 'appBootstrapProvider');
      hasDegradedDependency = true;
    }

    if (bootStateNotifier.isLoadingState) {
      bootStateNotifier.setReady();
      if (hasDegradedDependency) {
        bootStateNotifier.setDegraded();
      }
    }

    startup.markFirebaseReady(success: true);
    startup.markBootstrapResolved(
      resolution: hasDegradedDependency
          ? BootstrapResolution.degraded
          : BootstrapResolution.ready,
      detail: hasDegradedDependency
          ? 'firebase_initialized_optional_dependency_failed'
          : 'firebase_initialized',
    );
  } catch (error, stackTrace) {
    bootStateNotifier.setFailed();
    developer.log(
      'FIREBASE INIT FAILED: $error',
      error: error,
      stackTrace: stackTrace,
      name: 'appBootstrapProvider',
    );
    startup.markFirebaseReady(
      success: false,
      error: error,
      stackTrace: stackTrace,
    );
    startup.markBootstrapResolved(
      resolution: BootstrapResolution.failed,
      detail: 'reason=firebase_init_failed',
    );
  } finally {
    bootstrapWatchdog.cancel();
  }
});

// ... [The rest of your MixVyApp class remains unchanged below]
