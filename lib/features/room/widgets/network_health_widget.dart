import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/webrtc_latency_provider.dart';
export '../providers/webrtc_latency_provider.dart' show HealthStatus;

/// **NetworkHealthWidget**
///
/// Real-time network health indicator that consumes WebRTC latency telemetry.
/// Shows connection quality via visual indicator and optional text label.
///
/// States:
/// 🟢 Green (latency < 1000ms): Excellent connection
/// 🟡 Yellow (1000-2000ms): Noticeable lag, connection struggling
/// 🔴 Red (≥2000ms): Poor connection
class NetworkHealthWidget extends ConsumerStatefulWidget {
  /// Optional: Additional padding around the widget (default: all sides 8.0)
  final EdgeInsetsGeometry? padding;

  /// Optional: Show text label next to indicator (default: false)
  final bool showLabel;

  /// Optional: Callback when connection becomes critical
  final VoidCallback? onCritical;

  /// Optional: Callback when connection recovers
  final VoidCallback? onRecovered;

  const NetworkHealthWidget({
    super.key,
    this.padding,
    this.showLabel = false,
    this.onCritical,
    this.onRecovered,
  });

  @override
  ConsumerState<NetworkHealthWidget> createState() =>
      _NetworkHealthWidgetState();
}

class _NetworkHealthWidgetState extends ConsumerState<NetworkHealthWidget> {
  bool _wasCritical = false;

  @override
  Widget build(BuildContext context) {
    // Watch the reactive health status stream
    final healthStatus = ref.watch(networkHealthStatusProvider);

    return healthStatus.when(
      data: (status) {
        // Determine visual state based on health status
        final color = _getColorForStatus(status.status);
        final label = widget.showLabel ? _getLabelForStatus(status.status) : null;

        // Trigger callbacks on status changes
        if (status.status == HealthStatus.critical && !_wasCritical) {
          _wasCritical = true;
          widget.onCritical?.call();
        } else if (status.status != HealthStatus.critical && _wasCritical) {
          _wasCritical = false;
          widget.onRecovered?.call();
        }

        return Padding(
          padding: widget.padding ?? const EdgeInsets.all(8.0),
          child: Tooltip(
            message:
                'Network: ${status.latencyMs}ms (${_getLabelForStatus(status.status)})',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicator dot with glow
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () {
        // Show neutral state while loading
        return Padding(
          padding: widget.padding ?? const EdgeInsets.all(8.0),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade400,
            ),
          ),
        );
      },
      error: (error, stack) {
        // Show error state gracefully
        debugPrint('NetworkHealthWidget error: $error');
        return Padding(
          padding: widget.padding ?? const EdgeInsets.all(8.0),
          child: Tooltip(
            message: 'Network status unavailable',
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getColorForStatus(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return Colors.green;
      case HealthStatus.warning:
        return Colors.amber;
      case HealthStatus.critical:
        return Colors.red;
    }
  }

  String _getLabelForStatus(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return 'Excellent';
      case HealthStatus.warning:
        return 'Connecting...';
      case HealthStatus.critical:
        return 'Poor';
    }
  }
}

/// **Usage Example:**
///
/// ```dart
/// // In your LiveRoomScreen build method:
/// Positioned(
///   top: 16,
///   right: 70,  // Adjust based on other icons
///   child: NetworkHealthWidget(
///     showLabel: true,
///     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
///     onCritical: () {
///       ScaffoldMessenger.of(context).showSnackBar(
///         const SnackBar(content: Text('Connection quality degraded')),
///       );
///     },
///   ),
/// )
/// ```
