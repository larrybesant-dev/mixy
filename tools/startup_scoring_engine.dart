import 'startup_pipeline_models.dart';
import 'startup_metric_engine.dart';
import 'startup_policy_engine.dart';
import 'startup_decision_engine.dart';

class StartupScoringEngine {
  StartupScoringEngine({
    required this.sla,
    required this.weights,
    required this.passThreshold,
    required this.warnThreshold,
  });

  final Map<StartupCheckpoint, int> sla;
  final Map<StartupCheckpoint, double> weights;
  final double passThreshold;
  final double warnThreshold;

  final StartupMetricEngine _metricEngine = const StartupMetricEngine();

  ScoringResult evaluate({
    required ParseResult parsed,
    required Map<StartupCheckpoint, int> baseline,
    required TrendAnalysis trend,
  }) {
    final Map<StartupCheckpoint, CheckpointStats> stats = _metricEngine
        .computeStats(parsed.runs);

    final StartupPolicyEngine policyEngine = StartupPolicyEngine(sla: sla);
    final List<PolicyViolation> violations = policyEngine.evaluateViolations(
      parseFailures: parsed.failures,
      stats: stats,
      baseline: baseline,
      trend: trend,
      weights: weights,
    );
    final List<String> failures = violations
        .map((PolicyViolation violation) => violation.message)
        .toList();

    final StartupDecisionEngine decisionEngine = StartupDecisionEngine(
      sla: sla,
      weights: weights,
      passThreshold: passThreshold,
      warnThreshold: warnThreshold,
    );

    final CheckpointStats startupStats =
        stats[StartupCheckpoint.firstFrameRendered] ??
        const CheckpointStats(p50: 0, p95: 0, worst: 0);

    final double score = decisionEngine.computeScore(
      stats: stats,
      baseline: baseline,
    );
    final GateDecision decision = decisionEngine.decide(
      score: score,
      failures: failures,
    );

    return ScoringResult(
      decision: decision,
      score: score,
      failures: failures,
      violations: violations,
      statsByCheckpoint: stats,
      startupStats: startupStats,
    );
  }

  ParseResult parseRuns(String input) => _metricEngine.parseRuns(input);

  Map<StartupCheckpoint, CheckpointStats> computeStats(List<RunSample> runs) =>
      _metricEngine.computeStats(runs);
}



