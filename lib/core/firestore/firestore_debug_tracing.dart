import 'dart:async';

import '../telemetry/app_telemetry.dart';

// Firestore WebChannel streams can drop transiently during reconnects. Writes
// that fail with these codes are safe to retry — they are either not-yet-
// committed or idempotent (set/merge semantics).
//
// UNAVAILABLE (code 14): server stream closed — SDK will retry internally but
//   the Future itself throws, so we must retry at the application layer too.
// ABORTED (code 10): contention on a non-transactional write — safe to retry.
const _kRetryableCodes = {'unavailable', 'aborted', 'internal'};

bool _isRetryable(Object error) {
  final msg = error.toString().toLowerCase();
  return _kRetryableCodes.any(msg.contains);
}

typedef FirestoreItemCount<T> = int Function(T value);

Stream<T> traceFirestoreStream<T>({
  required String key,
  required String query,
  required Stream<T> stream,
  required FirestoreItemCount<T> itemCount,
  String? roomId,
  String? userId,
}) {
  return Stream<T>.multi((controller) {
    AppTelemetry.listenerStarted(
      key: key,
      query: query,
      roomId: roomId,
      userId: userId,
    );

    final subscription = stream.listen(
      (value) {
        AppTelemetry.recordFirestoreSnapshot(
          key: key,
          query: query,
          count: itemCount(value),
          roomId: roomId,
          userId: userId,
        );
        controller.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        AppTelemetry.recordFirestoreError(
          key: key,
          query: query,
          error: error,
          stackTrace: stackTrace,
          roomId: roomId,
          userId: userId,
        );
        controller.addError(error, stackTrace);
      },
      onDone: controller.close,
    );

    controller.onCancel = () async {
      await subscription.cancel();
      AppTelemetry.listenerStopped(
        key: key,
        query: query,
        roomId: roomId,
        userId: userId,
      );
    };
  });
}

Future<T> traceFirestoreRead<T>({
  required String path,
  required String operation,
  required Future<T> Function() action,
  String? roomId,
  String? userId,
}) async {
  AppTelemetry.recordFirestoreRead(
    path: path,
    operation: operation,
    roomId: roomId,
    userId: userId,
  );
  try {
    return await action();
  } catch (error, stackTrace) {
    AppTelemetry.logAction(
      level: 'error',
      domain: 'firestore',
      action: operation,
      message: 'Firestore read failed.',
      roomId: roomId,
      userId: userId,
      result: 'error',
      metadata: <String, Object?>{'path': path},
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<T> traceFirestoreWrite<T>({
  required String path,
  required String operation,
  required Future<T> Function() action,
  String? roomId,
  String? userId,
  Map<String, Object?> metadata = const <String, Object?>{},
  // Number of additional attempts after the first failure. Keep low to avoid
  // flooding the write stream during an extended outage.
  int maxRetries = 2,
}) async {
  AppTelemetry.recordFirestoreWrite(
    path: path,
    operation: operation,
    roomId: roomId,
    userId: userId,
    metadata: metadata,
  );

  Object? lastError;
  StackTrace? lastStack;

  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      // Exponential back-off: 400ms, 800ms. Caps at 800ms for 2 retries.
      final delay = Duration(milliseconds: 400 * attempt);
      await Future<void>.delayed(delay);
      AppTelemetry.logAction(
        level: 'warn',
        domain: 'firestore',
        action: operation,
        message: 'Retrying Firestore write (attempt $attempt/$maxRetries).',
        roomId: roomId,
        userId: userId,
        metadata: <String, Object?>{'path': path, 'attempt': attempt},
      );
    }

    try {
      return await action();
    } catch (error, stackTrace) {
      lastError = error;
      lastStack = stackTrace;
      if (!_isRetryable(error) || attempt == maxRetries) break;
    }
  }

  // All attempts exhausted — log and rethrow.
  AppTelemetry.logAction(
    level: 'error',
    domain: 'firestore',
    action: operation,
    message: 'Firestore write failed after ${maxRetries + 1} attempt(s).',
    roomId: roomId,
    userId: userId,
    result: 'error',
    metadata: <String, Object?>{'path': path, ...metadata},
    error: lastError,
    stackTrace: lastStack,
  );
  if (lastError != null && lastStack != null) {
    Error.throwWithStackTrace(lastError, lastStack);
  }
  throw StateError(
    'Firestore write failed without captured error state for $operation at $path',
  );
}
