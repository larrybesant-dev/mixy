import 'package:flutter/foundation.dart';

/// Mix & Mingle App Logger
/// Debug-only logging utility for tracking errors and unexpected states
class AppLogger {
  static const String _prefix = 'ðŸŽµ Mix&Mingle';

  /// Log an error with optional stack trace
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('$_prefix âŒ ERROR: $message');
      if (error != null) {
        debugPrint('  Error: $error');
      }
      if (stackTrace != null) {
        debugPrint(
            '  Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      }
    }
  }

  /// Log a warning
  static void warning(String message, [Object? details]) {
    if (kDebugMode) {
      debugPrint('$_prefix âš ï¸  WARNING: $message');
      if (details != null) {
        debugPrint('  Details: $details');
      }
    }
  }

  /// Log info message
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('$_prefix â„¹ï¸  INFO: $message');
    }
  }

  /// Log unexpected null value
  static void nullWarning(String fieldName, String context) {
    warning('Unexpected null value for $fieldName in $context');
  }

  /// Log provider failure
  static void providerError(String providerName, Object error,
      [StackTrace? stackTrace]) {
    AppLogger.error('Provider $providerName failed', error, stackTrace);
  }

  /// Log navigation error
  static void navigationError(String route, Object error) {
    AppLogger.error('Navigation to $route failed', error);
  }

  /// Log Firestore operation error
  static void firestoreError(String operation, Object error,
      [StackTrace? stackTrace]) {
    AppLogger.error('Firestore $operation failed', error, stackTrace);
  }

  /// Log network error
  static void networkError(String operation, Object error) {
    AppLogger.error('Network $operation failed', error);
  }

  /// Log unexpected state
  static void unexpectedState(String state, String context) {
    warning('Unexpected state "$state" in $context');
  }
}
