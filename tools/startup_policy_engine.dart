import 'startup_pipeline_models.dart';

class StartupPolicyEngine {
  const StartupPolicyEngine({required this.sla});

  final Map<StartupCheckpoint, int> sla;

  List<PolicyViolation> evaluateViolations({
    required List<String> parseFailures,
    required Map<StartupCheckpoint, CheckpointStats> stats,
    required Map<StartupCheckpoint, int> baseline,
    required TrendAnalysis trend,
    required Map<StartupCheckpoint, double> weights,
  }) {
    final List<PolicyViolation> violations = <PolicyViolation>[];

    for (final String parseFailure in parseFailures) {
      violations.add(
        PolicyViolation(
          ruleId: 'RULE_PARSE_VALIDATION',
          checkpoint: 'input',
          message: parseFailure,
        ),
      );
    }

    final CheckpointStats? firstFrame =
        stats[StartupCheckpoint.firstFrameRendered];
    final int? firstFrameLimit = sla[StartupCheckpoint.firstFrameRendered];
    if (firstFrame != null &&
        firstFrameLimit != null &&
        firstFrame.worst > firstFrameLimit) {
      violations.add(
        PolicyViolation(
          ruleId: 'RULE_FIRST_FRAME_HARD_LIMIT',
          checkpoint: StartupCheckpoint.firstFrameRendered.name,
          message:
              'firstFrameRendered: ${firstFrame.worst}ms (limit ${firstFrameLimit}ms)',
          triggerValue: firstFrame.worst.toDouble(),
          thresholdValue: firstFrameLimit.toDouble(),
          delta: (firstFrame.worst - firstFrameLimit).toDouble(),
          contributionWeight:
              weights[StartupCheckpoint.firstFrameRendered] ?? 0,
        ),
      );
    }

    for (final StartupCheckpoint checkpoint in gateCheckpoints) {
      final CheckpointStats? cpStats = stats[checkpoint];
      final int? limit = sla[checkpoint];
      if (cpStats == null || limit == null) continue;

      final int p95Ceiling = (limit * 1.2).ceil();
      if (cpStats.p95 > p95Ceiling) {
        violations.add(
          PolicyViolation(
            ruleId: 'RULE_P95_OVER_SLA_CEILING',
            checkpoint: checkpoint.name,
            message:
                'p95 regression ${checkpoint.name}: ${cpStats.p95}ms (20% ceiling ${p95Ceiling}ms)',
            triggerValue: cpStats.p95.toDouble(),
            thresholdValue: p95Ceiling.toDouble(),
            delta: (cpStats.p95 - p95Ceiling).toDouble(),
            contributionWeight: weights[checkpoint] ?? 0,
          ),
        );
      }

      final int? baselineP95 = baseline[checkpoint];
      if (baselineP95 != null) {
        final int baselineCeiling = (baselineP95 * 1.2).ceil();
        if (cpStats.p95 > baselineCeiling) {
          violations.add(
            PolicyViolation(
              ruleId: 'RULE_BASELINE_REGRESSION',
              checkpoint: checkpoint.name,
              message:
                  'baseline regression ${checkpoint.name}: ${cpStats.p95}ms (baseline p95 ${baselineP95}ms, +20% ceiling ${baselineCeiling}ms)',
              triggerValue: cpStats.p95.toDouble(),
              thresholdValue: baselineCeiling.toDouble(),
              delta: (cpStats.p95 - baselineCeiling).toDouble(),
              contributionWeight: weights[checkpoint] ?? 0,
            ),
          );
        }
      }
    }

    if (trend.status == TrendStatus.regressing) {
      violations.add(
        PolicyViolation(
          ruleId: 'RULE_TREND_REGRESSING',
          checkpoint: 'trend',
          message:
              'trend regression detected: slope ${(trend.slopePct * 100).toStringAsFixed(2)}% over ${trend.sampleCount} runs',
          triggerValue: trend.slopePct,
          thresholdValue: 0.05,
          delta: trend.slopePct - 0.05,
        ),
      );
    }

    return violations;
  }
}
