import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Performance baseline metrics for E2E testing.
/// Tracks: cold start, room join latency, profile load time, WebRTC connection.
class PerformanceMetrics {
  final DateTime timestamp = DateTime.now();
  final Map<String, MetricEntry> entries = {};

  /// Record a metric with start and end times.
  /// Returns the duration in milliseconds.
  int recordMetric(String name, int startTime, int endTime) {
    final duration = endTime - startTime;
    entries[name] = MetricEntry(
      name: name,
      durationMs: duration,
      timestamp: timestamp,
    );
    debugPrint('[METRICS] $name: ${duration}ms');
    return duration;
  }

  /// Mark the start of a timed operation.
  /// Return the start time (microseconds since epoch).
  int startTimer() => DateTime.now().microsecondsSinceEpoch;

  /// Complete a timed operation using the start time.
  int endTimer(String name, int startTime) {
    final endTime = DateTime.now().microsecondsSinceEpoch;
    return recordMetric(name, startTime, endTime);
  }

  /// Get specific metric by name.
  MetricEntry? getMetric(String name) => entries[name];

  /// Get all metrics.
  Map<String, MetricEntry> getAllMetrics() => Map.unmodifiable(entries);

  /// Export metrics as JSON.
  String exportJson() {
    final jsonMap = {
      'timestamp': timestamp.toIso8601String(),
      'metrics': {
        for (final entry in entries.values)
          entry.name: {
            'durationMs': entry.durationMs,
            'timestamp': entry.timestamp.toIso8601String(),
          },
      },
    };
    return jsonEncode(jsonMap);
  }

  /// Reset all metrics.
  void reset() {
    entries.clear();
  }

  /// Print summary report.
  void printSummary() {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('  PERFORMANCE METRICS SUMMARY');
    debugPrint('═══════════════════════════════════════════════');
    for (final entry in entries.values) {
      debugPrint('  ${entry.name.padRight(30)}: ${entry.durationMs.toString().padLeft(6)}ms');
    }
    debugPrint('═══════════════════════════════════════════════');

    // Analysis
    final coldStart = getMetric('cold_start');
    final roomJoin = getMetric('room_join_latency');
    final profileLoad = getMetric('profile_load_time');
    final webrtcConn = getMetric('webrtc_connection_establishment');

    debugPrint('');
    debugPrint('  PERFORMANCE TARGETS');
    debugPrint('  ───────────────────────────────────────────────');
    if (coldStart != null) {
      final status = coldStart.durationMs < 5000 ? '✓ PASS' : '✗ FAIL';
      debugPrint('  Cold Start (<5000ms)        : ${coldStart.durationMs}ms $status');
    }
    if (roomJoin != null) {
      final status = roomJoin.durationMs < 3000 ? '✓ PASS' : '✗ FAIL';
      debugPrint('  Room Join (<3000ms)         : ${roomJoin.durationMs}ms $status');
    }
    if (profileLoad != null) {
      final status = profileLoad.durationMs < 2000 ? '✓ PASS' : '✗ FAIL';
      debugPrint('  Profile Load (<2000ms)      : ${profileLoad.durationMs}ms $status');
    }
    if (webrtcConn != null) {
      final status = webrtcConn.durationMs < 1500 ? '✓ PASS' : '✗ FAIL';
      debugPrint('  WebRTC Connection (<1500ms) : ${webrtcConn.durationMs}ms $status');
    }
    debugPrint('  ───────────────────────────────────────────────');
  }
}

class MetricEntry {
  final String name;
  final int durationMs;
  final DateTime timestamp;

  MetricEntry({
    required this.name,
    required this.durationMs,
    required this.timestamp,
  });
}

/// Global metrics instance for use throughout the app during testing.
final performanceMetrics = PerformanceMetrics();
