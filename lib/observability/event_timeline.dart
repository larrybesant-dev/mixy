import 'package:flutter/foundation.dart';
import 'runtime_telemetry.dart';
import 'system_event_bus.dart';

class EventTimeline {
  final List<Map<String, dynamic>> _events = [];

  void record(String type, String source, SimulationContext ctx) {
    _events.add({
      "type": type,
      "source": source,
      "phase": ctx.phase,
      "time": DateTime.now().millisecondsSinceEpoch,
    });
    SystemEventBus.instance.emit(
      SystemEvent(
        type: type,
        timestamp: DateTime.now(),
        meta: <String, dynamic>{'source': source, 'phase': ctx.phase},
      ),
    );
    debugPrint("[${ctx.phase}] Event recorded: type=$type, source=$source");
  }

  List<Map<String, dynamic>> get events => List.unmodifiable(_events);

  void clear() => _events.clear();
}



