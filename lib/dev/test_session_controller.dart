import 'package:flutter/foundation.dart';
import '../observability/runtime_telemetry.dart';
import '../observability/production_alerts.dart';
import '../observability/event_timeline.dart';

class TestSessionController {
  static String? _activeSession;
  static SimulationContext? _context;
  static final EventTimeline _timeline = EventTimeline();

  static EventTimeline get timeline => _timeline;

  static void startSession(String name) {
    _activeSession = name;
    _context = SimulationContext(name);

    RuntimeTelemetry.reset();
    ProductionAlertSystem.reset();
    _timeline.clear();

    debugPrint("🧪 TEST SESSION STARTED: $name");
  }

  static void endSession() {
    debugPrint("🧪 TEST SESSION COMPLETE");

    debugPrint("📊 FINAL METRICS:");
    debugPrint("Listeners: ${RuntimeTelemetry.listeners}");
    debugPrint("Rebuilds: ${RuntimeTelemetry.rebuilds}");
    debugPrint("Alerts: ${ProductionAlertSystem.alerts.length}");

    debugPrint("📊 EVENT TIMELINE:");
    for (final e in _timeline.events) {
      debugPrint(
        "${e['time']} | ${e['type']} | ${e['source']} | Phase: ${e['phase']}",
      );
    }

    _activeSession = null;
    _context = null;
  }

  static SimulationContext? get context => _context;
  static String? get session => _activeSession;
}



