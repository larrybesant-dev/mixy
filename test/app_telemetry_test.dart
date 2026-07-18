import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';

void main() {
  setUp(() {
    AppTelemetry.reset();
  });

  test('tracks listener counts, mismatch flags, and room health', () {
    AppTelemetry.listenerStarted(
      key: 'participants/room-a',
      query: 'rooms/room-a/participants',
      roomId: 'room-a',
      userId: 'user-1',
    );
    AppTelemetry.listenerStarted(
      key: 'participants/room-a',
      query: 'rooms/room-a/participants',
      roomId: 'room-a',
      userId: 'user-1',
    );

    AppTelemetry.updateRoomState(
      roomId: 'room-a',
      joinedUserId: 'user-1',
      roomPhase: 'joined',
      participantCount: 3,
      cameraMismatch: true,
      micMismatch: true,
      presenceMismatch: true,
      hostConflict: true,
      staleParticipantIds: const <String>{'ghost-user'},
    );

    final state = AppTelemetry.state;
    expect(state.activeListenerCount, 2);
    expect(state.duplicateListenerKeys, contains('participants/room-a'));
    expect(state.cameraMismatch, isTrue);
    expect(state.micMismatch, isTrue);
    expect(state.presenceMismatch, isTrue);
    expect(state.hostConflict, isTrue);
    expect(state.staleParticipantIds, contains('ghost-user'));
    expect(state.recentEvents, isNotEmpty);
    expect(state.roomHealth.severity, RoomHealthSeverity.critical);
    expect(
      state.roomHealth.alerts.map((alert) => alert.code),
      contains('host_split_brain'),
    );

    AppTelemetry.listenerStopped(
      key: 'participants/room-a',
      query: 'rooms/room-a/participants',
      roomId: 'room-a',
      userId: 'user-1',
    );
    AppTelemetry.listenerStopped(
      key: 'participants/room-a',
      query: 'rooms/room-a/participants',
      roomId: 'room-a',
      userId: 'user-1',
    );

    expect(AppTelemetry.state.activeListenerCount, 0);
    expect(AppTelemetry.state.duplicateListenerKeys, isEmpty);
  });

  test(
    'detects duplicate joins and reconnect thrash from telemetry events',
    () {
      AppTelemetry.updateRoomState(
        roomId: 'room-a',
        joinedUserId: 'user-1',
        roomPhase: 'joined',
      );

      AppTelemetry.logAction(
        domain: 'room',
        action: 'join',
        message: 'Attempting room join.',
        roomId: 'room-a',
        userId: 'user-1',
        result: 'start',
      );
      AppTelemetry.logAction(
        domain: 'room',
        action: 'join',
        message: 'Attempting room join.',
        roomId: 'room-a',
        userId: 'user-1',
        result: 'start',
      );

      for (var attempt = 1; attempt <= 3; attempt++) {
        AppTelemetry.logAction(
          domain: 'room',
          action: 'live_trace',
          message:
              'connection_lost: reconnect attempt=$attempt delay=${attempt}s',
          roomId: 'room-a',
          userId: 'user-1',
          result: 'ok',
        );
      }

      final state = AppTelemetry.state;
      final alertCodes = state.roomHealth.alerts.map((alert) => alert.code);

      expect(state.roomHealth.duplicateJoinCount, 2);
      expect(state.roomHealth.reconnectBurstCount, 3);
      expect(alertCodes, contains('duplicate_join_storm'));
      expect(alertCodes, contains('reconnect_loop_thrash'));
    },
  );

  test('suppresses transient drift alerts during reconnect recovery', () {
    AppTelemetry.updateRoomState(
      roomId: 'room-a',
      joinedUserId: 'user-1',
      roomPhase: 'joined',
    );

    AppTelemetry.logAction(
      domain: 'room',
      action: 'live_trace',
      message: 'connection_lost: reconnect attempt=1 delay=1s',
      roomId: 'room-a',
      userId: 'user-1',
      result: 'ok',
    );

    AppTelemetry.updateRoomState(
      roomId: 'room-a',
      joinedUserId: 'user-1',
      roomPhase: 'joined',
      micMismatch: true,
      presenceMismatch: true,
    );

    final state = AppTelemetry.state;
    final alertCodes = state.roomHealth.alerts.map((alert) => alert.code);

    expect(state.roomHealth.suppressedAlertCount, greaterThan(0));
    expect(alertCodes, isNot(contains('ghost_leave_risk')));
    expect(alertCodes, isNot(contains('mic_desync')));
  });

  test('records room stability history for the session trend', () {
    AppTelemetry.updateRoomState(
      roomId: 'room-a',
      joinedUserId: 'user-1',
      roomPhase: 'joined',
      participantCount: 2,
    );
    AppTelemetry.updateRoomState(
      roomId: 'room-a',
      joinedUserId: 'user-1',
      roomPhase: 'joined',
      participantCount: 2,
      hostMissing: true,
    );

    final history = AppTelemetry.state.roomHealth.recentScores;
    expect(history.length, greaterThanOrEqualTo(2));
    expect(history.last, lessThan(history.first));
  });
}
