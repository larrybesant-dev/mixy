import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart'; // ADDED THIS
import 'firebase_options.dart'; // ADDED THIS
import 'observability/provider_observer.dart';
import 'observability/startup_timeline.dart';
import 'app/app.dart';
import 'app/boot_state.dart';
import 'app/boot_state_notifier.dart';
import 'core/logger.dart';

const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev-local',
);

// Disabled to prevent the UI thread from locking up during web startup.
// SemanticsHandle? _webSemanticsHandle;

Future<void> main() async {
  final startup = StartupProfiler.instance;
  startup.markAppStartTime();
  startup.markMainStart();

  WidgetsFlutterBinding.ensureInitialized();
  startup.markBindingReady();
  
  // THIS IS THE FIX: Initialize Firebase right here before the app runs
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // TelemetryConfig.initialize(); // standard in debug, off in release
  Logger.info('App startup version=$_appVersion');

  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());

    // WARNING: Eager semantics generation builds a massive parallel HTML DOM tree 
    // before the first frame paints, causing extreme lag on complex initial routes.
    // Commented out to resolve the 196-second startup hang.
    // _webSemanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
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

  // Dev-only: scan for stream architecture violations in the background.
  // Never blocks startup; zero cost in release builds.
  // StreamLinterHook.scheduleOnce();
}