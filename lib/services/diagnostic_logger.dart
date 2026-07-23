import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Diagnostic logger mixin for consistent, monitored logging across MixVy.
///
/// **Features:**
/// - Consistent `[MIXVY_DEBUG:<category>]` prefix for all logs
/// - Development mode: Console logging via `developer.log()`
/// - Production mode: Routes to Firebase Crashlytics or Sentry (configure via `onProductionLog` callback)
/// - Severity levels: info, warning, error, critical
///
/// **Usage:**
/// ```dart
/// class MyService with DiagnosticLogger {
///   void initExample() {
///     logInfo('Service initialized', metadata: {'version': '1.0'});
///     logWarning('Low memory detected');
///     logError('Connection failed', error: Exception('timeout'));
///   }
/// }
/// ```
mixin DiagnosticLogger {
  /// Callback for production log routing. Override via [DiagnosticLogger.setProductionHandler].
  static LogProductionHandler? _productionHandler;

  /// Configure remote logging for production builds.
  ///
  /// **Example with Firebase Crashlytics:**
  /// ```dart
  /// DiagnosticLogger.setProductionHandler((log) {
  ///   FirebaseCrashlytics.instance.recordError(
  ///     log.message,
  ///     StackTrace.current,
  ///     reason: log.category,
  ///     printDetails: true,
  ///   );
  /// });
  /// ```
  static void setProductionHandler(LogProductionHandler handler) {
    _productionHandler = handler;
  }

  /// Extract category name from `runtimeType` (e.g., `AgoraService` → `AgoraService`).
  String get _logCategory => runtimeType.toString();

  /// Format log prefix: `[MIXVY_DEBUG:CategoryName]`
  String _formatPrefix(String severity) => '[MIXVY_DEBUG:$_logCategory][$severity]';

  /// Core logging logic. Routes to console in dev mode, production handler in release mode.
  void _log(String severity, String message, {Map<String, dynamic>? metadata, Object? error}) {
    final prefix = _formatPrefix(severity);
    final fullMessage = metadata != null
        ? '$prefix $message | metadata=$metadata'
        : '$prefix $message';

    if (kDebugMode) {
      // Development: Output to IDE console via developer.log()
      developer.log(fullMessage, name: _logCategory, error: error);
    } else {
      // Production: Route to remote logging service (Sentry, Firebase Crashlytics, etc.)
      if (_productionHandler != null) {
        _productionHandler!(
          DiagnosticLog(
            severity: severity,
            category: _logCategory,
            message: message,
            metadata: metadata,
            error: error,
            timestamp: DateTime.now(),
          ),
        );
      }
    }
  }

  /// Log informational messages.
  void logInfo(String message, {Map<String, dynamic>? metadata}) {
    _log('INFO', message, metadata: metadata);
  }

  /// Log warning messages (non-blocking issues).
  void logWarning(String message, {Map<String, dynamic>? metadata}) {
    _log('WARN', message, metadata: metadata);
  }

  /// Log error messages with optional exception object.
  void logError(String message, {Object? error, Map<String, dynamic>? metadata}) {
    _log('ERROR', message, error: error, metadata: metadata);
  }

  /// Log critical errors (unrecoverable failures, circuit breaker triggers).
  void logCritical(String message, {Object? error, Map<String, dynamic>? metadata}) {
    _log('CRIT', message, error: error, metadata: metadata);
  }
}

/// Structured log entry for production remote logging.
class DiagnosticLog {
  final String severity;
  final String category;
  final String message;
  final Map<String, dynamic>? metadata;
  final Object? error;
  final DateTime timestamp;

  DiagnosticLog({
    required this.severity,
    required this.category,
    required this.message,
    this.metadata,
    this.error,
    required this.timestamp,
  });

  /// Convert to JSON-serializable map for remote logging service APIs.
  Map<String, dynamic> toJson() => {
    'severity': severity,
    'category': category,
    'message': message,
    'metadata': metadata,
    'error': error.toString(),
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Callback signature for routing logs to production services.
typedef LogProductionHandler = void Function(DiagnosticLog log);
