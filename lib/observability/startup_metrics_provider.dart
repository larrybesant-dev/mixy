import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'startup_timeline.dart';

/// Read-only snapshot of recorded startup timing marks (ms since app launch).
/// Safe to watch from any widget, overlay, or analytics hook.
/// Values update lazily — re-read after first-interactive is confirmed.
final startupMetricsProvider = Provider<Map<String, int>>((ref) {
  return StartupMetrics.dump();
});

/// True when cold-start interactive latency is within the 3 s target.
final coldStartOnTargetProvider = Provider<bool>((ref) {
  return StartupMetrics.coldStartOnTarget;
});

/// True when warm-start latency is within the 1.5 s target.
final warmStartOnTargetProvider = Provider<bool>((ref) {
  return StartupMetrics.warmStartOnTarget;
});

/// Gap in ms between system-interactive-ready and the first recorded user action.
/// Reads null until the user has performed their first deliberate gesture.
final perceivedLatencyProvider = Provider<int?>((ref) {
  return StartupMetrics.perceivedLatencyMs;
});



