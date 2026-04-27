import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/environment.dart';
import '../../core/logger.dart';
import '../../core/services/auto_response_service.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../core/telemetry/beta_metrics.dart';

const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev-local',
);

class OperationalDebugOverlay extends ConsumerStatefulWidget {
  const OperationalDebugOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OperationalDebugOverlay> createState() =>
      _OperationalDebugOverlayState();
}

class _OperationalDebugOverlayState
    extends ConsumerState<OperationalDebugOverlay> {
  static const int _tapThreshold = 6;
  int _tapCount = 0;
  DateTime? _firstTapAt;
  bool _visible = false;

  void _registerTap() {
    final now = DateTime.now();
    if (_firstTapAt == null || now.difference(_firstTapAt!) > const Duration(seconds: 3)) {
      _firstTapAt = now;
      _tapCount = 0;
    }

    _tapCount += 1;
    if (_tapCount >= _tapThreshold) {
      _tapCount = 0;
      _firstTapAt = null;
      setState(() => _visible = !_visible);
    }
  }

  String _maskedUserId(String? uid) {
    if (uid == null || uid.isEmpty) {
      return 'anonymous';
    }
    if (uid.length <= 10) {
      return uid;
    }
    return '${uid.substring(0, 6)}...${uid.substring(uid.length - 4)}';
  }

  String _environmentLabel() {
    return switch (currentEnv) {
      Environment.dev => 'development',
      Environment.prod => 'production',
    };
  }

  ({Color color, String label}) _healthSummary({
    required FeatureGateState gates,
    required LoggerErrorSnapshot? lastError,
  }) {
    final now = DateTime.now();
    final lastUpdatedAt = gates.lastUpdatedAt;
    final updateAge = lastUpdatedAt == null
        ? const Duration(days: 999)
        : now.difference(lastUpdatedAt);

    final hasRecentError =
        lastError != null && now.difference(lastError.occurredAt) < const Duration(minutes: 5);
    final staleConfig = updateAge > const Duration(minutes: 5);
    final limitedMode = !gates.enableLiveRooms || !gates.enableMessaging;

    if (hasRecentError) {
      return (color: const Color(0xFF9B2535), label: 'Health: Incident Watch');
    }
    if (staleConfig) {
      return (color: const Color(0xFFB37A2A), label: 'Health: Config Stale');
    }
    if (limitedMode) {
      return (color: const Color(0xFFB37A2A), label: 'Health: Limited Mode');
    }
    return (color: const Color(0xFF2E7D32), label: 'Health: Normal');
  }

  String _formatRelative(DateTime? value) {
    if (value == null) {
      return 'never';
    }
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }

  String? _safeCurrentUserId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gates = ref.watch(featureGateControllerProvider);
    final autoResponse = ref.watch(autoResponseControllerProvider);
    final betaMetrics = ref.watch(betaMetricsProvider);
    final telemetry = AppTelemetry.state;
    final userId = _safeCurrentUserId();

    // Trigger beta metrics update on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(betaMetricsProvider.notifier).refreshFromTelemetry(telemetry);
    });

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: SizedBox(
              width: 34,
              height: 34,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _registerTap,
                onLongPress: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
        ),
        if (_visible)
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xEE0B0B0B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ValueListenableBuilder<LoggerErrorSnapshot?>(
                      valueListenable: Logger.lastCapturedErrorNotifier,
                      builder: (context, snapshot, _) {
                        final health = _healthSummary(
                          gates: gates,
                          lastError: snapshot,
                        );
                        final lastErrorLabel = snapshot == null
                            ? 'none'
                            : '${snapshot.message} (${snapshot.errorType ?? 'error'})';

                        return DefaultTextStyle(
                          style: const TextStyle(color: Color(0xFFF7EDE2), fontSize: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Operational Debug',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: health.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: health.color.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.monitor_heart_outlined,
                                        size: 14,
                                        color: health.color,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        health.label,
                                        style: TextStyle(
                                          color: health.color,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Version: $_appVersion'),
                              Text('Environment: ${_environmentLabel()}${kReleaseMode ? ' (release)' : ''}'),
                              Text('User: ${_maskedUserId(userId)}'),
                              const SizedBox(height: 6),
                              const Text(
                                'Remote Config',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('enable_live_rooms: ${gates.enableLiveRooms}'),
                              Text('enable_messaging: ${gates.enableMessaging}'),
                              Text('enable_speed_dating: ${gates.enableSpeedDating}'),
                              Text('feed_refresh_rate: ${gates.feedRefreshRateSeconds}s'),
                              Text('rooms_mode: ${gates.liveRoomsMode.name}'),
                              Text('messaging_mode: ${gates.messagingMode.name}'),
                              Text('config_source: ${gates.source}'),
                              Text('remote_live_rooms: ${gates.remoteEnableLiveRooms}'),
                              Text('remote_messaging: ${gates.remoteEnableMessaging}'),
                              Text('local_override_source: ${gates.localOverrideSource ?? 'none'}'),
                              Text('local_override_at: ${_formatRelative(gates.localOverrideUpdatedAt)}'),
                              Text('operator_override_active: ${gates.hasOperatorOverrides}'),
                              Text('operator_override_source: ${gates.operatorOverrideSource ?? 'none'}'),
                              Text('operator_override_at: ${_formatRelative(gates.operatorOverrideUpdatedAt)}'),
                              Text('last_update: ${_formatRelative(gates.lastUpdatedAt)}'),
                              const SizedBox(height: 6),
                              const Text(
                                'Auto Response',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('messaging_failures_5m: ${autoResponse.messagingFailures5m}'),
                              Text('room_join_failures_5m: ${autoResponse.roomJoinFailures5m}'),
                              Text('auth_failures_5m: ${autoResponse.authFailures5m}'),
                              Text('auto_messaging_mode: ${autoResponse.messagingMode.name}'),
                              Text('auto_rooms_mode: ${autoResponse.roomsMode.name}'),
                              Text('auth_recovery_recommended: ${autoResponse.authRecoveryRecommended}'),
                              Text('last_auto_action: ${autoResponse.lastAction ?? 'none'}'),
                              Text('last_auto_action_at: ${_formatRelative(autoResponse.lastActionAt)}'),
                              const SizedBox(height: 6),
                              const Text(
                                'Beta Observability',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('active_feed: ${betaMetrics.activeUsersFeed}'),
                              Text('active_rooms: ${betaMetrics.activeUsersRooms}'),
                              Text('active_chat: ${betaMetrics.activeUsersChat}'),
                              Text('match_success: ${betaMetrics.matchSuccessCount}'),
                              Text('avg_room_mins: ${betaMetrics.avgRoomDurationMinutes.toStringAsFixed(1)}'),
                              const SizedBox(height: 6),
                              const Text(
                                'Last Error',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                lastErrorLabel,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
