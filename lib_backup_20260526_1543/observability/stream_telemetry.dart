import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/telemetry/telemetry_config.dart';
import 'production_alerts.dart';
import 'runtime_telemetry.dart';

/// Stream lifecycle and emit-frequency telemetry.
///
/// Wraps any [Stream] to track:
/// * Active subscription count (duplicate-subscription detection)
/// * Emit frequency (burst detection — catches reconnect storms)
/// * Total lifetime emits per key
///
/// ### Usage
/// ```dart
/// // Wrap at the source:
/// final tracked = StreamTelemetry.wrap(
///   key: 'room_participants',
///   stream: firestoreStream,
/// );
/// final sub = tracked.listen(onData);
/// ```
///
/// All tracking is no-op in release mode.
abstract final class StreamTelemetry {
  /// Active subscription counts per key.
  static final Map<String, int> _subscriptions = {};

  /// Total emit counts per key.
  static final Map<String, int> _emits = {};

  /// Per-key burst window state (for emit spike detection).
  static final Map<String, _BurstState> _burstWindows = {};

  /// Total stream traces recorded this session (across all keys).
  static int _sessionTraceCount = 0;

  /// Emits per key per [_burstWindowSeconds] that trigger a WARNING.
  static const int _emitWarnThreshold = 40;

  /// Emits per key per [_burstWindowSeconds] that trigger a CRITICAL alert.
  static const int _emitCriticalThreshold = 100;

  static const int _burstWindowSeconds = 5;

  /// Maximum total stream emit traces tracked per session.
  /// Individual burst detection continues above this cap; only the raw counter
  /// is frozen to prevent unbounded memory growth.
  static const int _maxTracesPerSession = 500;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Wraps [stream] with telemetry under [key].
  ///
  /// Each subscriber registers itself; each emitted event is counted.
  /// Use the same [key] for logically equivalent streams (e.g.
  /// `'room_$roomId/participants'`).
  static Stream<T> wrap<T>({required String key, required Stream<T> stream}) {
    if (!TelemetryConfig.isActive) return stream;
    return _TrackedStreamWrapper<T>(key: key, source: stream).asStream();
  }

  /// Immutable snapshot of active subscription counts.
  static Map<String, int> snapshotSubscriptions() =>
      Map.unmodifiable(_subscriptions);

  /// Immutable snapshot of total emit counts.
  static Map<String, int> snapshotEmits() => Map.unmodifiable(_emits);

  /// Resets all counters (e.g. when a room session ends).
  static void reset() {
    _subscriptions.clear();
    _emits.clear();
    _burstWindows.clear();
    _sessionTraceCount = 0;
  }

  // ─── Internal callbacks ────────────────────────────────────────────────────

  static void _onSubscribe(String key) {
    _subscriptions[key] = (_subscriptions[key] ?? 0) + 1;
    RuntimeTelemetry.registerListener('stream:$key');
    final count = _subscriptions[key]!;
    if (count > 3) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'stream_dupe_$key',
        message: 'Duplicate subscriptions [$key]: $count active',
        level: count > 5 ? AlertLevel.critical : AlertLevel.warning,
      );
      if (TelemetryConfig.allows(LogTier.debug)) {
        debugPrint('[StreamTelemetry] 🟡 DUPLICATE SUBSCRIBERS [$key]: $count');
      }
    }
  }

  static void _onCancel(String key) {
    final remaining = (_subscriptions[key] ?? 1) - 1;
    if (remaining <= 0) {
      _subscriptions.remove(key);
    } else {
      _subscriptions[key] = remaining;
    }
    RuntimeTelemetry.unregisterListener('stream:$key');
  }

  static void _onEmit(String key) {
    if (_sessionTraceCount < _maxTracesPerSession) {
      _emits[key] = (_emits[key] ?? 0) + 1;
      _sessionTraceCount++;
    }
    _checkBurst(key);
  }

  static void _checkBurst(String key) {
    final now = DateTime.now();
    final burst = _burstWindows[key];

    if (burst == null ||
        now.difference(burst.windowStart).inSeconds >= _burstWindowSeconds) {
      _burstWindows[key] = _BurstState(windowStart: now, count: 1);
      return;
    }

    burst.count++;
    if (burst.count == _emitCriticalThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'stream_burst_critical_$key',
        message:
            'Stream burst [$key]: ${burst.count} emits/${_burstWindowSeconds}s',
        level: AlertLevel.critical,
      );
      if (TelemetryConfig.allows(LogTier.operational)) {
        debugPrint(
          '[StreamTelemetry] 🔴 EMIT STORM [$key]: ${burst.count} emits/${_burstWindowSeconds}s',
        );
      }
    } else if (burst.count == _emitWarnThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'stream_burst_warn_$key',
        message:
            'Stream spike [$key]: ${burst.count} emits/${_burstWindowSeconds}s',
        level: AlertLevel.warning,
      );
      if (TelemetryConfig.allows(LogTier.operational)) {
        debugPrint(
          '[StreamTelemetry] 🟡 EMIT SPIKE [$key]: ${burst.count} emits/${_burstWindowSeconds}s',
        );
      }
    }
  }
}

// ─── Internal wrapper ──────────────────────────────────────────────────────

class _BurstState {
  _BurstState({required this.windowStart, required this.count});
  final DateTime windowStart;
  int count;
}

class _TrackedStreamWrapper<T> {
  _TrackedStreamWrapper({required this.key, required this.source});

  final String key;
  final Stream<T> source;

  Stream<T> asStream() {
    // Use a StreamController to intercept subscribe/cancel/data.
    late StreamController<T> controller;
    StreamSubscription<T>? upstream;

    controller = StreamController<T>(
      onListen: () {
        StreamTelemetry._onSubscribe(key);
        upstream = source.listen(
          (event) {
            StreamTelemetry._onEmit(key);
            controller.add(event);
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        StreamTelemetry._onCancel(key);
        upstream?.cancel();
        upstream = null;
      },
      // Broadcast if the source is a broadcast stream so multiple listeners
      // can subscribe without a StateError.
      sync: false,
    );

    // Match broadcast semantics of the source.
    if (source.isBroadcast) {
      return controller.stream.asBroadcastStream();
    }
    return controller.stream;
  }
}
