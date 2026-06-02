import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/dev/test_session_controller.dart';
import 'package:mixvy/dev/load_simulator.dart';
import 'package:mixvy/observability/runtime_telemetry.dart';

void main() {
  test('Validation Test: ROOM_LOAD_VALIDATION', () async {
    TestSessionController.startSession("ROOM_LOAD_VALIDATION");

    final ctx = TestSessionController.context!;
    final sim = LoadSimulator(TestSessionController.timeline);
    sim.runTypingStorm("room_1", ctx);
    sim.runmessageBurst("room_1", ctx);
    sim.runPresenceFlap("user_1", ctx);

    await Future.delayed(const Duration(seconds: 5));

    TestSessionController.endSession();

    expect(RuntimeTelemetry.snapshotListeners(), isEmpty);
    expect(RuntimeTelemetry.snapshotRebuilds(), isNotEmpty);
    expect(TestSessionController.timeline.events, isNotEmpty);
  });
}










