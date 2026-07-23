import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/core/telemetry/feed_experiment_contract.dart';
import 'package:mixvy/core/telemetry/feed_experiment_evaluator.dart';

void main() {
  test('experiment stays pending before the sample threshold', () {
    final evaluation = FeedAttentionExperiment.evaluate(
      impressions: 40,
      baselineCtr: 0.10,
      observedCtr: 0.14,
      averageDwellMs: 1800,
      baselineScrollDepth: 0.60,
      observedScrollDepth: 0.58,
      baselineParticipationRate: 0.30,
      observedParticipationRate: 0.31,
    );

    expect(evaluation.status, FeedExperimentStatus.pending);
    expect(evaluation.decision, FeedExperimentDecision.inconclusive);
    expect(evaluation.isInconclusive, isTrue);
    expect(evaluation.explanation, contains('Sample pending'));
  });

  test('experiment is healthy when all guardrails are met', () {
    final evaluation = FeedAttentionExperiment.evaluate(
      impressions: 400,
      baselineCtr: 0.10,
      observedCtr: 0.125,
      averageDwellMs: 2200,
      baselineScrollDepth: 0.60,
      observedScrollDepth: 0.57,
      baselineParticipationRate: 0.30,
      observedParticipationRate: 0.295,
    );

    expect(evaluation.status, FeedExperimentStatus.healthy);
    expect(evaluation.decision, FeedExperimentDecision.pass);
    expect(evaluation.shouldPromote, isTrue);
    expect(evaluation.explanation, contains('CTR met'));
    expect(evaluation.explanation, contains('Dwell met'));
    expect(evaluation.riskLevel, 'none');
  });

  test('experiment fails when featured attention harms the feed', () {
    final evaluation = FeedAttentionExperiment.evaluate(
      impressions: 400,
      baselineCtr: 0.10,
      observedCtr: 0.08,
      averageDwellMs: 4200,
      baselineScrollDepth: 0.60,
      observedScrollDepth: 0.45,
      baselineParticipationRate: 0.30,
      observedParticipationRate: 0.25,
    );

    expect(evaluation.status, FeedExperimentStatus.fail);
    expect(evaluation.decision, FeedExperimentDecision.fail);
    expect(evaluation.shouldRollback, isTrue);
    expect(evaluation.explanation, contains('safety guardrails'));
    expect(evaluation.riskLevel, 'high');
  });

  test('central evaluator snapshots state before publishing a decision', () {
    AppTelemetry.reset();
    FeedExperimentEvaluator.reset();

    final evaluation = FeedExperimentEvaluator.evaluateAndPublish(
      const FeedExperimentSnapshot(
        impressions: 400,
        baselineCtr: 0.10,
        observedCtr: 0.125,
        averageDwellMs: 2200,
        baselineScrollDepth: 0.60,
        observedScrollDepth: 0.57,
        baselineParticipationRate: 0.30,
        observedParticipationRate: 0.295,
      ),
      source: 'test',
      rolloutPercent: 25,
      pendingAction: 'expand',
    );

    expect(evaluation.decision, FeedExperimentDecision.pass);
    expect(FeedExperimentEvaluator.latestSnapshot, isNotNull);
    expect(FeedExperimentEvaluator.latestSnapshot!.pendingAction, 'expand');
    expect(FeedExperimentEvaluator.latestSnapshot!.rolloutPercent, 25);
    expect(AppTelemetry.state.recentEvents, isNotEmpty);
    expect(
      AppTelemetry.state.recentEvents.first.action,
      'feed_experiment_decision',
    );
    expect(AppTelemetry.state.recentEvents.first.result, 'pass');
    expect(
      AppTelemetry.state.recentEvents.first.metadata['explanation'],
      isA<String>(),
    );
    expect(
      AppTelemetry.state.recentEvents.first.metadata['risk_level'],
      'none',
    );
    expect(
      AppTelemetry.state.recentEvents[1].action,
      'feed_experiment_snapshot',
    );
    expect(AppTelemetry.state.recentEvents[1].result, 'expand');
    expect(AppTelemetry.state.recentEvents[1].metadata['rollout_pct'], '25.0');
  });
}
