import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'observability/provider_observer.dart';
import 'observability/startup_timeline.dart';
import 'app/app.dart';
import 'app/boot_state.dart';
import 'app/boot_state_notifier.dart';
import 'core/logger.dart';
import 'router/app_router.dart';
import 'services/push_messaging_service.dart';
import 'firebase_options.dart';

const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev-local',
);

SemanticsHandle? _webSemanticsHandle;

Future<void> main() async {
  final startup = StartupProfiler.instance;
  startup.markAppStartTime();
  startup.markMainStart();

  WidgetsFlutterBinding.ensureInitialized();
  startup.markBindingReady();
  // TelemetryConfig.initialize(); // standard in debug, off in release
  Logger.info('App startup version=$_appVersion');

  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
    _webSemanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
  }

  BootState initialBootState = BootState.loading;

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

  try {
    await dotenv.load(fileName: 'assets/.env');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Enable Firestore offline persistence so cached data is served when the
    // network is unavailable. On web this uses IndexedDB; on mobile it uses
    // SQLite. Streams return stale cached docs instead of erroring on network
    // loss, which prevents blank dashboards and infinite loaders.
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    PushMessagingService.instance.setNavigatorKey(rootNavigatorKey);
    await PushMessagingService.instance.initialize();
    initialBootState = BootState.loading;
    startup.markFirebaseReady(success: true);
  } catch (error, stackTrace) {
    initialBootState = BootState.failed;
    developer.log(
      'FIREBASE INIT FAILED: $error',
      error: error,
      stackTrace: stackTrace,
      name: 'main',
    );
    startup.markFirebaseReady(
      success: false,
      error: error,
      stackTrace: stackTrace,
    );
  }

  runApp(
    ProviderScope(
      observers: [MixvyProviderObserver()],
      overrides: [
        bootStateProvider.overrideWith(
          (ref) => BootStateNotifier(initialState: initialBootState),
        ),
      ],
      child: const MixVyApp(),
    ),
  );

  // Dev-only: scan for stream architecture violations in the background.
  // Never blocks startup; zero cost in release builds.
  // StreamLinterHook.scheduleOnce();
}
