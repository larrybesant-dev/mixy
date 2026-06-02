import 'dart:async';
import 'package:flutter/foundation.dart';
import '../observability/runtime_telemetry.dart';
import '../observability/event_timeline.dart';

class LoadSimulator {
  final EventTimeline timeline;

  LoadSimulator(this.timeline);

  void runTypingStorm(String roomId, SimulationContext ctx) {
    debugPrint("[${ctx.phase}] Running typing storm for room: $roomId");
    for (int i = 0; i < 20; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        timeline.record("SIM_EVENT", "typing:$roomId", ctx);
        RuntimeTelemetry.recordRebuild("SIM:typing:$roomId", ctx);
      });
    }
  }

  void runmessageBurst(String roomId, SimulationContext ctx) {
    debugPrint("[${ctx.phase}] Running message burst for room: $roomId");
    for (int i = 0; i < 30; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        timeline.record("SIM_EVENT", "message:$roomId", ctx);
        RuntimeTelemetry.recordRebuild("SIM:message:$roomId", ctx);
      });
    }
  }

  void runPresenceFlap(String userId, SimulationContext ctx) {
    debugPrint("[${ctx.phase}] Running presence flap for user: $userId");
    for (int i = 0; i < 10; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
        timeline.record("SIM_EVENT", "presence:$userId", ctx);
        RuntimeTelemetry.recordRebuild("SIM:presence:$userId", ctx);
      });
    }
  }
}
