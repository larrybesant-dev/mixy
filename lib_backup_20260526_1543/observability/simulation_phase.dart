import 'package:flutter/foundation.dart';

class SimulationPhase {
  final String phase;

  SimulationPhase(this.phase);

  void start() {
    debugPrint("🧪 PHASE START: $phase");
  }

  void end() {
    debugPrint("🧪 PHASE END: $phase");
  }
}
