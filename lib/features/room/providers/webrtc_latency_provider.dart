import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/observability/webrtc_latency_tracker.dart';

/// Global provider for WebRTC latency tracking across all peer connections.
/// 
/// This provider maintains a single [WebRtcLatencyTracker] instance that monitors
/// signaling latency from offer/answer creation through ICE connection establishment.
final webrtcLatencyTrackerProvider = Provider<WebRtcLatencyTracker>((ref) {
  return WebRtcLatencyTracker();
});

/// Reactive health status provider for UI consumption.
/// 
/// Emits [NetworkHealthStatus] updates based on current WebRTC latency.
/// Used by [NetworkHealthWidget] to display real-time connection quality.
final networkHealthStatusProvider =
    StreamProvider<NetworkHealthStatus>((ref) async* {
  final tracker = ref.watch(webrtcLatencyTrackerProvider);

  // Poll tracker state every 500ms to emit health updates
  while (true) {
    final latency = tracker.getLatestLatencyMs();

    yield NetworkHealthStatus(
      latencyMs: latency,
      status: _getStatusFromLatency(latency),
      timestamp: DateTime.now(),
    );

    // Wait before polling again
    await Future.delayed(const Duration(milliseconds: 500));
  }
});

/// Determine health status from latency
HealthStatus _getStatusFromLatency(int latencyMs) {
  if (latencyMs < 1000) {
    return HealthStatus.excellent;
  } else if (latencyMs < 2000) {
    return HealthStatus.warning;
  } else {
    return HealthStatus.critical;
  }
}

/// Network health status model
class NetworkHealthStatus {
  final int latencyMs;
  final HealthStatus status;
  final DateTime timestamp;

  NetworkHealthStatus({
    required this.latencyMs,
    required this.status,
    required this.timestamp,
  });
}

/// Health status enum for network connection quality
enum HealthStatus { excellent, warning, critical }
