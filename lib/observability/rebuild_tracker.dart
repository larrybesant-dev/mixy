import 'package:flutter/widgets.dart';
import 'runtime_telemetry.dart';

class RebuildTracker extends StatelessWidget {
  final String name;
  final Widget child;

  const RebuildTracker({super.key, required this.name, required this.child});

  @override
  Widget build(BuildContext context) {
    RuntimeTelemetry.recordRebuild(name);
    return child;
  }
}



