import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'observability/startup_timeline.dart';
import 'app/app.dart';
import 'app/boot_state.dart';
import 'app/boot_state_notifier.dart';
import 'core/logger.dart';
import 'firebase_options.dart';

const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev-local',
);

Future<void> main() async {
  final startup = StartupProfiler.instance;
  startup.markMainStart();

  WidgetsFlutterBinding.ensureInitialized();
  startup.markBindingReady();
  Logger.info('App startup version=$_appVersion');

  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }

  var initialBootState = BootState.loading;

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
      overrides: [
        bootStateProvider.overrideWith(
          (ref) => BootStateNotifier(initialState: initialBootState),
        ),
      ],
      child: const MixVyApp(),
    ),
  );
}
