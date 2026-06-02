enum StartupCheckpoint {
  mainStart,
  bindingReady,
  firebaseReady,
  bootstrapResolved,
  firstFrameRendered,
}

const String startupPipelineVersion = '1.0.0';

const List<StartupCheckpoint> requiredCheckpoints = <StartupCheckpoint>[
  StartupCheckpoint.mainStart,
  StartupCheckpoint.bindingReady,
  StartupCheckpoint.firebaseReady,
  StartupCheckpoint.bootstrapResolved,
  StartupCheckpoint.firstFrameRendered,
];

const List<StartupCheckpoint> gateCheckpoints = <StartupCheckpoint>[
  StartupCheckpoint.bindingReady,
  StartupCheckpoint.firebaseReady,
  StartupCheckpoint.bootstrapResolved,
  StartupCheckpoint.firstFrameRendered,
];

StartupCheckpoint? startupCheckpointFromName(String name) {
  for (final StartupCheckpoint cp in StartupCheckpoint.values) {
    if (cp.name == name) return cp;
  }
  return null;
}

class RunSample {
  RunSample(this.id);

  final int id;
  final Map<StartupCheckpoint, int> values = <StartupCheckpoint, int>{};
}

class CheckpointStats {
  const CheckpointStats({
    required this.p50,
    required this.p95,
    required this.worst,
  });

  final int p50;
  final int p95;
  final int worst;
}

class WeightsConfig {
  const WeightsConfig({
    required this.weights,
    required this.passThreshold,
    required this.warnThreshold,
  });

  final Map<StartupCheckpoint, double> weights;
  final double passThreshold;
  final double warnThreshold;
}

class GatePolicyConfig {
  const GatePolicyConfig({
    required this.pipelineVersion,
    required this.blockOnWarn,
    required this.policyMode,
  });

  final String pipelineVersion;
  final bool blockOnWarn;
  final String policyMode;
}

enum TrendStatus { stable, degrading, regressing }

class TrendAnalysis {
  const TrendAnalysis({
    required this.status,
    required this.slopePct,
    required this.driftPct,
    required this.variance,
    required this.sampleCount,
  });

  final TrendStatus status;
  final double slopePct;
  final double driftPct;
  final double variance;
  final int sampleCount;
}

enum GateDecision { pass, warn, fail }

class ParseResult {
  const ParseResult({required this.runs, required this.failures});

  final List<RunSample> runs;
  final List<String> failures;
}

class ScoringResult {
  const ScoringResult({
    required this.decision,
    required this.score,
    required this.failures,
    required this.violations,
    required this.statsByCheckpoint,
    required this.startupStats,
  });

  final GateDecision decision;
  final double score;
  final List<String> failures;
  final List<PolicyViolation> violations;
  final Map<StartupCheckpoint, CheckpointStats> statsByCheckpoint;
  final CheckpointStats startupStats;
}

class PolicyViolation {
  const PolicyViolation({
    required this.ruleId,
    required this.checkpoint,
    required this.message,
    this.triggerValue,
    this.thresholdValue,
    this.delta,
    this.contributionWeight,
  });

  final String ruleId;
  final String checkpoint;
  final String message;
  final double? triggerValue;
  final double? thresholdValue;
  final double? delta;
  final double? contributionWeight;

  Map<String, Object?> toJson() => <String, Object?>{
        'rule_id': ruleId,
        'checkpoint': checkpoint,
        'message': message,
        'trigger_value': triggerValue,
        'threshold_value': thresholdValue,
        'delta': delta,
        'contribution_weight': contributionWeight,
      };
}
