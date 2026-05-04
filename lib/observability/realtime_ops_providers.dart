import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';

class RealtimeOpsSnapshot {
  const RealtimeOpsSnapshot({
    required this.firestoreOnlineUsers,
    required this.activeListenerCount,
    required this.duplicateListenerCount,
    required this.parityMismatchCount,
    required this.zombieListenerCount,
    required this.discoverableCount,
    required this.warmCount,
    required this.coldCount,
    required this.invalidCount,
    required this.coldFallbackActive,
    required this.feedHealthState,
    required this.invariantIssueCount,
    required this.reconnectBurstCount,
    required this.hostConflict,
    required this.hostMissing,
    required this.warningAlertCount,
    required this.criticalAlertCount,
    required this.duplicateJoinCount,
    required this.orphanParticipantCount,
    required this.ownershipTransferCount,
    required this.moderatorPromotionCount,
    required this.hiddenPendingDirectCallCount,
  });

  final int firestoreOnlineUsers;
  final int activeListenerCount;
  final int duplicateListenerCount;
  final int parityMismatchCount;
  final int zombieListenerCount;
  final int discoverableCount;
  final int warmCount;
  final int coldCount;
  final int invalidCount;
  final bool coldFallbackActive;
  final FeedHealthState feedHealthState;
  final int invariantIssueCount;
  final int reconnectBurstCount;
  final bool hostConflict;
  final bool hostMissing;
  final int warningAlertCount;
  final int criticalAlertCount;
  final int duplicateJoinCount;
  final int orphanParticipantCount;
  final int ownershipTransferCount;
  final int moderatorPromotionCount;
  final int hiddenPendingDirectCallCount;
}

final appTelemetryStateProvider = Provider<AppTelemetryState>((ref) {
  return AppTelemetry.state;
});

final realtimeOpsSnapshotProvider =
    Provider.autoDispose<AsyncValue<RealtimeOpsSnapshot>>((ref) {
      final onlineUsersAsync = ref.watch(onlineUsersCountProvider);
      final feedHealthAsync = ref.watch(feedHealthProvider);
      final telemetry = ref.watch(appTelemetryStateProvider);

      if (onlineUsersAsync.isLoading || feedHealthAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (onlineUsersAsync.hasError) {
        return AsyncValue.error(
          onlineUsersAsync.error!,
          onlineUsersAsync.stackTrace ?? StackTrace.current,
        );
      }

      if (feedHealthAsync.hasError) {
        return AsyncValue.error(
          feedHealthAsync.error!,
          feedHealthAsync.stackTrace ?? StackTrace.current,
        );
      }

      final feedHealth = feedHealthAsync.requireValue;
      final telemetryState = telemetry;
      final parityMismatchCount = [
        telemetryState.presenceMismatch,
        telemetryState.cameraMismatch,
        telemetryState.micMismatch,
      ].where((value) => value).length;
      final invariantIssueCount = telemetryState.recentEvents
          .where((event) => event.action == 'invariant_broken')
          .length;
      final ownershipTransferCount = telemetryState.recentEvents
          .where((event) => event.action == 'host_transfer')
          .length;
      final moderatorPromotionCount = telemetryState.recentEvents
          .where((event) => event.action == 'promote_moderator')
          .length;
        final hiddenPendingDirectCallCount = telemetryState.recentEvents
          .where((event) => event.action == 'pending_direct_call_hidden')
          .length;

      return AsyncValue.data(
        RealtimeOpsSnapshot(
          firestoreOnlineUsers: onlineUsersAsync.requireValue,
          activeListenerCount: telemetryState.activeListenerCount,
          duplicateListenerCount: telemetryState.duplicateListenerKeys.length,
          parityMismatchCount: parityMismatchCount,
          zombieListenerCount: telemetryState.duplicateListenerKeys.length,
          discoverableCount: feedHealth.sections.discoverable.length,
          warmCount: feedHealth.sections.warm.length,
          coldCount: feedHealth.sections.cold.length,
          invalidCount: feedHealth.sections.invalid.length,
          coldFallbackActive: feedHealth.usingColdFallback,
          feedHealthState: feedHealth.state,
          invariantIssueCount: invariantIssueCount,
          reconnectBurstCount: telemetryState.roomHealth.reconnectBurstCount,
          hostConflict: telemetryState.hostConflict,
          hostMissing: telemetryState.hostMissing,
          warningAlertCount: telemetryState.roomHealth.warningAlertCount,
          criticalAlertCount: telemetryState.roomHealth.criticalAlertCount,
          duplicateJoinCount: telemetryState.roomHealth.duplicateJoinCount,
          orphanParticipantCount: telemetryState.staleParticipantIds.length,
          ownershipTransferCount: ownershipTransferCount,
          moderatorPromotionCount: moderatorPromotionCount,
          hiddenPendingDirectCallCount: hiddenPendingDirectCallCount,
        ),
      );
    });