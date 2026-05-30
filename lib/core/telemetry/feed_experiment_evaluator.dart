import 'dart:collection';

import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/core/telemetry/feed_experiment_contract.dart';

class FeedExperimentSnapshot {
  const FeedExperimentSnapshot({
    required this.impressions,
    required this.baselineCtr,
    required this.observedCtr,
    required this.averageDwellMs,
    required this.baselineScrollDepth,
    required this.observedScrollDepth,
    required this.baselineParticipationRate,
    required this.observedParticipationRate,
  });

  final int impressions;
  final double baselineCtr;
  final double observedCtr;
  final int averageDwellMs;
  final double baselineScrollDepth;
  final double observedScrollDepth;
  final double baselineParticipationRate;
  final double observedParticipationRate;

  FeedExperimentEvaluation evaluate() {
    return FeedAttentionExperiment.evaluate(
      impressions: impressions,
      baselineCtr: baselineCtr,
      observedCtr: observedCtr,
      averageDwellMs: averageDwellMs,
      baselineScrollDepth: baselineScrollDepth,
      observedScrollDepth: observedScrollDepth,
      baselineParticipationRate: baselineParticipationRate,
      observedParticipationRate: observedParticipationRate,
    );
  }

  Map<String, Object> toMetadata() => <String, Object>{
    'impressions': impressions,
    'baseline_ctr_pct': (baselineCtr * 100).toStringAsFixed(2),
    'observed_ctr_pct': (observedCtr * 100).toStringAsFixed(2),
    'avg_dwell_ms': averageDwellMs,
    'baseline_scroll_pct': (baselineScrollDepth * 100).toStringAsFixed(2),
    'observed_scroll_pct': (observedScrollDepth * 100).toStringAsFixed(2),
    'baseline_participation_pct': (baselineParticipationRate * 100)
        .toStringAsFixed(2),
    'observed_participation_pct': (observedParticipationRate * 100)
        .toStringAsFixed(2),
  };
}

class FeedExperimentDecisionSnapshot {
  const FeedExperimentDecisionSnapshot({
    required this.timestamp,
    required this.source,
    required this.rolloutPercent,
    required this.pendingAction,
    required this.metrics,
    required this.evaluation,
  });

  final DateTime timestamp;
  final String source;
  final double rolloutPercent;
  final String pendingAction;
  final FeedExperimentSnapshot metrics;
  final FeedExperimentEvaluation evaluation;

  Map<String, Object> toMetadata() => <String, Object>{
    'snapshot_at': timestamp.toIso8601String(),
    'source': source,
    'rollout_pct': rolloutPercent.toStringAsFixed(1),
    'pending_action': pendingAction,
    'summary': evaluation.summary,
    'top_drivers': evaluation.reasons.take(3).join(' || '),
    ...metrics.toMetadata(),
    ...evaluation.toMetadata(),
  };
}

class FeedExperimentEvaluator {
  FeedExperimentEvaluator._();

  static const int _maxSnapshots = 25;
  static final List<FeedExperimentDecisionSnapshot> _history =
      <FeedExperimentDecisionSnapshot>[];

  static UnmodifiableListView<FeedExperimentDecisionSnapshot> get history =>
      UnmodifiableListView<FeedExperimentDecisionSnapshot>(_history);

  static FeedExperimentDecisionSnapshot? get latestSnapshot =>
      _history.isEmpty ? null : _history.first;

  static void reset() {
    _history.clear();
  }

  static FeedExperimentEvaluation evaluateAndPublish(
    FeedExperimentSnapshot snapshot, {
    String source = 'runtime',
    double rolloutPercent = 0,
    String pendingAction = 'hold',
  }) {
    final evaluation = snapshot.evaluate();
    final decisionSnapshot = FeedExperimentDecisionSnapshot(
      timestamp: DateTime.now(),
      source: source,
      rolloutPercent: rolloutPercent,
      pendingAction: pendingAction,
      metrics: snapshot,
      evaluation: evaluation,
    );

    _history.insert(0, decisionSnapshot);
    if (_history.length > _maxSnapshots) {
      _history.removeRange(_maxSnapshots, _history.length);
    }

    AppTelemetry.logAction(
      domain: 'room',
      action: 'feed_experiment_snapshot',
      message: 'Captured experiment state before rollout action.',
      result: pendingAction,
      metadata: <String, Object?>{
        ...FeedAttentionExperiment.telemetryMetadata(),
        ...decisionSnapshot.toMetadata(),
      },
    );

    AppTelemetry.logAction(
      domain: 'room',
      action: 'feed_experiment_decision',
      message: evaluation.summary,
      result: evaluation.decision.name,
      metadata: <String, Object?>{
        ...FeedAttentionExperiment.telemetryMetadata(),
        ...decisionSnapshot.toMetadata(),
        'should_promote': evaluation.shouldPromote,
        'should_rollback': evaluation.shouldRollback,
      },
    );

    return evaluation;
  }
}



