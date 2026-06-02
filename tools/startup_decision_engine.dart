import 'startup_pipeline_models.dart';

class StartupDecisionEngine {
  const StartupDecisionEngine({
    required this.sla,
    required this.weights,
    required this.passThreshold,
    required this.warnThreshold,
  });

  final Map<StartupCheckpoint, int> sla;
  final Map<StartupCheckpoint, double> weights;
  final double passThreshold;
  final double warnThreshold;

  double computeScore({
    required Map<StartupCheckpoint, CheckpointStats> stats,
    required Map<StartupCheckpoint, int> baseline,
  }) {
    double score = 0;

    for (final StartupCheckpoint checkpoint in gateCheckpoints) {
      final CheckpointStats? cpStats = stats[checkpoint];
      final int? slaLimit = sla[checkpoint];
      final double? weight = weights[checkpoint];
      if (cpStats == null ||
          slaLimit == null ||
          weight == null ||
          slaLimit == 0) {
        continue;
      }

      final int reference = baseline[checkpoint] ?? slaLimit;
      final double referenceCeiling = (reference * 1.2).toDouble();
      final double normalized = cpStats.p95 / referenceCeiling;
      score += (weight * normalized);
    }

    return score;
  }

  GateDecision decide({required double score, required List<String> failures}) {
    if (failures.isNotEmpty) {
      return GateDecision.fail;
    }

    if (score <= passThreshold) {
      return GateDecision.pass;
    }
    if (score <= warnThreshold) {
      return GateDecision.warn;
    }
    return GateDecision.fail;
  }
}
