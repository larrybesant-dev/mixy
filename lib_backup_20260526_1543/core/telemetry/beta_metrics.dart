import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_telemetry.dart';

class BetaMetricsState {
  final int activeUsersFeed;
  final int activeUsersRooms;
  final int activeUsersChat;
  final int matchSuccessCount;
  final int matchFailureCount;
  final double avgRoomDurationMinutes;
  final double retentionRate24h;

  BetaMetricsState({
    this.activeUsersFeed = 0,
    this.activeUsersRooms = 0,
    this.activeUsersChat = 0,
    this.matchSuccessCount = 0,
    this.matchFailureCount = 0,
    this.avgRoomDurationMinutes = 0.0,
    this.retentionRate24h = 0.0,
  });

  BetaMetricsState copyWith({
    int? activeUsersFeed,
    int? activeUsersRooms,
    int? activeUsersChat,
    int? matchSuccessCount,
    int? matchFailureCount,
    double? avgRoomDurationMinutes,
    double? retentionRate24h,
  }) {
    return BetaMetricsState(
      activeUsersFeed: activeUsersFeed ?? this.activeUsersFeed,
      activeUsersRooms: activeUsersRooms ?? this.activeUsersRooms,
      activeUsersChat: activeUsersChat ?? this.activeUsersChat,
      matchSuccessCount: matchSuccessCount ?? this.matchSuccessCount,
      matchFailureCount: matchFailureCount ?? this.matchFailureCount,
      avgRoomDurationMinutes:
          avgRoomDurationMinutes ?? this.avgRoomDurationMinutes,
      retentionRate24h: retentionRate24h ?? this.retentionRate24h,
    );
  }
}

class BetaMetricsController extends StateNotifier<BetaMetricsState> {
  BetaMetricsController() : super(BetaMetricsState());

  void refreshFromTelemetry(AppTelemetryState telemetry) {
    final events = telemetry.recentEvents;

    // Simple count based on recent events (10m window)
    final now = DateTime.now();
    final window = const Duration(minutes: 10);

    int feedCount = 0;
    int roomCount = 0;
    int chatCount = 0;
    int matchSuccess = 0;
    final int matchFail = 0;
    final List<int> roomDurations = [];

    for (final event in events) {
      if (now.difference(event.timestamp) > window) continue;

      if (event.domain == 'routing' && event.action == 'navigate') {
        final path = event.metadata['path'] as String? ?? '';
        if (path.contains('home')) feedCount++;
        if (path.contains('room')) roomCount++;
        if (path.contains('chat')) chatCount++;
      }

      if (event.domain == 'speed_dating' && event.action == 'match_success') {
        matchSuccess++;
      }

      if (event.domain == 'room' && event.action == 'drop_off') {
        final duration = event.metadata['durationSeconds'] as int? ?? 0;
        if (duration > 0) roomDurations.add(duration);
      }
    }

    final avgDuration = roomDurations.isEmpty
        ? 0.0
        : roomDurations.reduce((a, b) => a + b) / roomDurations.length / 60.0;

    state = state.copyWith(
      activeUsersFeed: feedCount,
      activeUsersRooms: roomCount,
      activeUsersChat: chatCount,
      matchSuccessCount: matchSuccess,
      matchFailureCount: matchFail,
      avgRoomDurationMinutes: avgDuration,
    );
  }
}

final betaMetricsProvider =
    StateNotifierProvider<BetaMetricsController, BetaMetricsState>((ref) {
  return BetaMetricsController();
});
