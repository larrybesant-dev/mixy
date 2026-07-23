// ...existing code...
// Error reporting stub. Replace with Crashlytics, Sentry, or custom logic as needed.
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

final _logger = Logger('ErrorReporting');

bool get _crashlyticsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

void reportError(dynamic error, StackTrace stack) {
  _logger.severe('Error: $error', error, stack);
  // Report to Crashlytics only on supported platforms
  if (_crashlyticsSupported) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  }
}



