import 'package:mixvy/dev/load_simulator.dart';
import 'package:mixvy/dev/test_session_controller.dart';
import 'package:mixvy/observability/event_timeline.dart';
import 'package:mixvy/observability/simulation_phase.dart';

void main() {
  TestSessionController.startSession("ROOM_LOAD_VALIDATION");

  final ctx = TestSessionController.context!;
  final sim = LoadSimulator(EventTimeline());

  final typingStormPhase = SimulationPhase("typing_storm");
  typingStormPhase.start();
  sim.runTypingStorm("room_1", ctx);
  typingStormPhase.end();

  final messageBurstPhase = SimulationPhase("message_burst");
  messageBurstPhase.start();
  sim.runmessageBurst("room_1", ctx);
  messageBurstPhase.end();

  final presenceFlapPhase = SimulationPhase("presence_flap");
  presenceFlapPhase.start();
  sim.runPresenceFlap("user_1", ctx);
  presenceFlapPhase.end();

  Future.delayed(const Duration(seconds: 5), () {
    TestSessionController.endSession();
  });
}
