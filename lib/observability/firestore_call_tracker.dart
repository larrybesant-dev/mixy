import 'package:flutter/foundation.dart';

import '../core/telemetry/telemetry_config.dart';
import 'production_alerts.dart';

/// Lightweight debug-only counter for Firestore read and write operations.
///
/// Designed to be called from service/repository layer call sites.
/// All methods are no-ops in release mode — zero production overhead.
///
/// ### Usage
/// ```dart
/// // In a service that performs a Firestore read:
/// FirestoreCallTracker.trackRead('rooms/$roomId');
/// await _firestore.collection('rooms').doc(roomId).get();
/// ```
abstract final class FirestoreCallTracker {
  /// Per-path-prefix read counts since last [reset].
  static final Map<String, int> _reads = {};

  /// Per-path-prefix write counts since last [reset].
  static final Map<String, int> _writes = {};

  /// Total reads recorded this session.
  static int _totalReads = 0;

  /// Total writes recorded this session.
  static int _totalWrites = 0;

  // ─── Thresholds ────────────────────────────────────────────────────────────

  /// Reads per path prefix that triggers a WARNING.
  static const int _readWarnThreshold = 100;

  /// Reads per path prefix that triggers a CRITICAL alert.
  static const int _readCriticalThreshold = 300;

  /// Writes per path prefix that triggers a WARNING.
  static const int _writeWarnThreshold = 50;

  /// Writes per path prefix that triggers a CRITICAL alert.
  static const int _writeCriticalThreshold = 150;

  /// Maximum combined read + write events tracked per session.
  /// Prevents memory growth during very long debug sessions.
  static const int _maxEventsPerSession = 2000;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Record a Firestore document/collection read at [path].
  ///
  /// [path] should be the Firestore path, e.g. `rooms/abc123`.
  /// It is bucketed to the top-level collection for easier analysis.
  static void trackRead(String path) {
    if (!TelemetryConfig.isActive) return;
    if (_totalReads + _totalWrites >= _maxEventsPerSession) return;
    final bucket = _bucket(path);
    _reads[bucket] = (_reads[bucket] ?? 0) + 1;
    _totalReads++;
    _checkReadThreshold(bucket);
  }

  /// Record a Firestore document write (set / update / delete) at [path].
  static void trackWrite(String path) {
    if (!TelemetryConfig.isActive) return;
    if (_totalReads + _totalWrites >= _maxEventsPerSession) return;
    final bucket = _bucket(path);
    _writes[bucket] = (_writes[bucket] ?? 0) + 1;
    _totalWrites++;
    _checkWriteThreshold(bucket);
  }

  /// Immutable snapshot of current read counts by collection bucket.
  static Map<String, int> snapshotReads() => Map.unmodifiable(_reads);

  /// Immutable snapshot of current write counts by collection bucket.
  static Map<String, int> snapshotWrites() => Map.unmodifiable(_writes);

  /// Total reads recorded since last [reset].
  static int get totalReads => _totalReads;

  /// Total writes recorded since last [reset].
  static int get totalWrites => _totalWrites;

  /// Resets all counters (useful when a room session ends).
  static void reset() {
    _reads.clear();
    _writes.clear();
    _totalReads = 0;
    _totalWrites = 0;
  }

  // ─── Internals ─────────────────────────────────────────────────────────────

  /// Returns the top-level collection name as the bucket key.
  /// e.g. `rooms/abc123/participants` → `rooms`.
  static String _bucket(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.first : path;
  }

  static void _checkReadThreshold(String bucket) {
    final count = _reads[bucket] ?? 0;
    if (count == _readCriticalThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'firestore_read_critical_$bucket',
        message: 'Firestore reads critical on [$bucket]: $count reads',
        level: AlertLevel.critical,
      );
      if (TelemetryConfig.allows(LogTier.operational)) {
        debugPrint(
          '[FirestoreTracker] 🔴 READ BURST [$bucket]: $count total reads',
        );
      }
    } else if (count == _readWarnThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'firestore_read_warn_$bucket',
        message: 'High Firestore reads on [$bucket]: $count reads',
        level: AlertLevel.warning,
      );
      if (TelemetryConfig.allows(LogTier.operational)) {
        debugPrint(
          '[FirestoreTracker] 🟡 READ SPIKE [$bucket]: $count total reads',
        );
      }
    }
  }

  static void _checkWriteThreshold(String bucket) {
    final count = _writes[bucket] ?? 0;
    if (count == _writeCriticalThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'firestore_write_critical_$bucket',
        message: 'Firestore writes critical on [$bucket]: $count writes',
        level: AlertLevel.critical,
      );
      if (TelemetryConfig.allows(LogTier.operational)) {
        debugPrint(
          '[FirestoreTracker] 🔴 WRITE BURST [$bucket]: $count total writes',
        );
      }
    } else if (count == _writeWarnThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'firestore_write_warn_$bucket',
        message: 'High Firestore writes on [$bucket]: $count writes',
        level: AlertLevel.warning,
      );
      if (TelemetryConfig.allows(LogTier.operational)) {
        debugPrint(
          '[FirestoreTracker] 🟡 WRITE SPIKE [$bucket]: $count total writes',
        );
      }
    }
  }
}



