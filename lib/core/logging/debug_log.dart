import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Production-safe logging utilities
///
/// Replaces all debugPrint() calls with conditional logging:
/// - Debug mode: logs to console via developer.log()
/// - Production mode: silent (no console spam)
class DebugLog {
  /// Log at INFO level (basic information)
  /// Only logs in debug mode
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        message,
        level: 800,
        name: tag ?? 'MixMingle',
      );
    }
  }

  /// Log at DEBUG level (detailed debugging info)
  /// Only logs in debug mode
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        message,
        level: 500,
        name: '${tag ?? "MixMingle"}.Debug',
      );
    }
  }

  /// Log at WARNING level
  /// Only logs in debug mode
  static void warn(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        message,
        level: 900,
        name: '${tag ?? "MixMingle"}.Warn',
      );
    }
  }

  /// Log at ERROR level
  /// Logs in all modes (errors are important for production)
  static void error(String message, {String? tag}) {
    developer.log(
      message,
      level: 1000,
      name: '${tag ?? "MixMingle"}.Error',
    );
  }

  /// Whether logging is enabled (depends on debug mode)
  static bool get isEnabled => kDebugMode;
}
