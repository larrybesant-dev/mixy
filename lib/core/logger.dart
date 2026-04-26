import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

@immutable
class LoggerErrorSnapshot {
  const LoggerErrorSnapshot({
    required this.message,
    required this.errorType,
    required this.occurredAt,
  });

  final String message;
  final String? errorType;
  final DateTime occurredAt;
}

class Logger {
  Logger._();

  static bool _enabled = true;
  static const Duration _repeatWindow = Duration(minutes: 10);
  static const int _repeatThreshold = 5;
  static final Map<String, List<DateTime>> _errorTimeline =
      <String, List<DateTime>>{};
  static final Map<String, DateTime> _lastEscalationBySignature =
      <String, DateTime>{};
  static int _escalationCount = 0;

  static final ValueNotifier<LoggerErrorSnapshot?>
  lastCapturedErrorNotifier = ValueNotifier<LoggerErrorSnapshot?>(null);

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  // Backward-compatible entrypoint used across the codebase.
  static void log(String message, {Object? error, StackTrace? stackTrace}) {
    info(message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _write('INFO', message, error: error, stackTrace: stackTrace);
    _recordToCrashlytics(message);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _write('WARN', message, error: error, stackTrace: stackTrace);
    _captureLastError(message, error: error);
    _recordToCrashlytics(message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, bool fatal = false}) {
    _write('ERROR', message, error: error, stackTrace: stackTrace);
    _captureLastError(message, error: error);
    _recordToCrashlytics(
      message,
      error: error,
      stackTrace: stackTrace,
      fatal: fatal,
    );
    _maybeEscalateRepeatedError(
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _write(String level, String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enabled) {
      return;
    }

    developer.log(
      '[$level] $message',
      name: 'MixVy',
      error: error,
      stackTrace: stackTrace,
    );

    // Keep human-readable output during development only.
    if (!kReleaseMode) {
      debugPrint('[MixVy][$level] $message${error != null ? ' | $error' : ''}');
    }
  }

  static bool get _crashlyticsSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static String _redactMessage(String input) {
    final compact = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 180) {
      return compact;
    }
    return '${compact.substring(0, 180)}...';
  }

  static void _captureLastError(String message, {Object? error}) {
    lastCapturedErrorNotifier.value = LoggerErrorSnapshot(
      message: _redactMessage(message),
      errorType: error?.runtimeType.toString(),
      occurredAt: DateTime.now(),
    );
  }

  static String _signatureFor(String message, Object? error) {
    final type = error?.runtimeType.toString() ?? 'none';
    final errorText = error?.toString() ?? '';
    return '${_redactMessage(message)}|$type|${_redactMessage(errorText)}';
  }

  static void _maybeEscalateRepeatedError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final now = DateTime.now();
    final signature = _signatureFor(message, error);
    final points = _errorTimeline.putIfAbsent(signature, () => <DateTime>[]);

    if (_errorTimeline.length > 250) {
      _errorTimeline.removeWhere((_, samples) {
        if (samples.isEmpty) {
          return true;
        }
        final latest = samples.reduce(
          (a, b) => a.isAfter(b) ? a : b,
        );
        return now.difference(latest) > _repeatWindow;
      });
    }

    points.removeWhere((time) => now.difference(time) > _repeatWindow);
    points.add(now);

    if (points.length < _repeatThreshold) {
      return;
    }

    final lastEscalation = _lastEscalationBySignature[signature];
    if (lastEscalation != null &&
        now.difference(lastEscalation) <= _repeatWindow) {
      return;
    }

    _lastEscalationBySignature[signature] = now;
    _escalationCount += 1;

    final escalationMessage =
        'Repeated error escalation: ${points.length} hits in ${_repeatWindow.inMinutes}m';

    _write('FATAL', escalationMessage, error: error, stackTrace: stackTrace);
    _recordToCrashlytics(
      escalationMessage,
      error: error,
      stackTrace: stackTrace,
      fatal: true,
    );
    _forwardEscalationToAnalytics(
      signature: signature,
      hitCount: points.length,
      windowMinutes: _repeatWindow.inMinutes,
    );
  }

  static void _forwardEscalationToAnalytics({
    required String signature,
    required int hitCount,
    required int windowMinutes,
  }) {
    try {
      unawaited(
        FirebaseAnalytics.instance.logEvent(
          name: 'error_burst_escalation',
          parameters: <String, Object>{
            'hit_count': hitCount,
            'window_minutes': windowMinutes,
            'signature': signature.length > 96
                ? signature.substring(0, 96)
                : signature,
          },
        ),
      );
    } catch (_) {
      // Escalation telemetry must never impact runtime behavior.
    }
  }

  static void _recordToCrashlytics(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    if (!_crashlyticsSupported) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      crashlytics.log(message);

      if (error != null) {
        crashlytics.recordError(
          error,
          stackTrace,
          reason: message,
          fatal: fatal,
        );
      }
    } catch (_) {
      // Ignore logging transport failures to avoid cascading runtime issues.
    }
  }

  @visibleForTesting
  static void resetForTests() {
    _errorTimeline.clear();
    _lastEscalationBySignature.clear();
    _escalationCount = 0;
    lastCapturedErrorNotifier.value = null;
  }

  @visibleForTesting
  static int get escalationCountForTests => _escalationCount;
}
