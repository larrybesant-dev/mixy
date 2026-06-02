enum FeedExperimentStatus { pending, healthy, caution, fail }

enum FeedExperimentDecision { pass, fail, inconclusive }

class FeedExperimentEvaluation {
  const FeedExperimentEvaluation({
    required this.status,
    required this.summary,
    required this.ctrLift,
    required this.scrollDepthDelta,
    required this.participationRetention,
    required this.averageDwellMs,
    required this.ctrPassed,
    required this.dwellPassed,
    required this.scrollPassed,
    required this.participationPassed,
    required this.riskLevel,
    required this.reasons,
  });

  final FeedExperimentStatus status;
  final String summary;
  final double ctrLift;
  final double scrollDepthDelta;
  final double participationRetention;
  final int averageDwellMs;
  final bool ctrPassed;
  final bool dwellPassed;
  final bool scrollPassed;
  final bool participationPassed;
  final String riskLevel;
  final List<String> reasons;

  FeedExperimentDecision get decision {
    switch (status) {
      case FeedExperimentStatus.healthy:
        return FeedExperimentDecision.pass;
      case FeedExperimentStatus.fail:
        return FeedExperimentDecision.fail;
      case FeedExperimentStatus.pending:
      case FeedExperimentStatus.caution:
        return FeedExperimentDecision.inconclusive;
    }
  }

  bool get shouldPromote => decision == FeedExperimentDecision.pass;
  bool get shouldRollback => decision == FeedExperimentDecision.fail;
  bool get isInconclusive => decision == FeedExperimentDecision.inconclusive;
  String get explanation => reasons.join(' | ');

  Map<String, Object> toMetadata() => <String, Object>{
        'status': status.name,
        'decision': decision.name,
        'risk_level': riskLevel,
        'explanation': explanation,
        'ctr_lift_pct': (ctrLift * 100).toStringAsFixed(2),
        'scroll_depth_delta_pct': (scrollDepthDelta * 100).toStringAsFixed(2),
        'participation_retention_pct':
            (participationRetention * 100).toStringAsFixed(2),
        'average_dwell_ms': averageDwellMs,
        'ctr_passed': ctrPassed,
        'dwell_passed': dwellPassed,
        'scroll_passed': scrollPassed,
        'participation_passed': participationPassed,
      };
}

class FeedAttentionExperiment {
  FeedAttentionExperiment._();

  static const String id = 'home_featured_attention_v1';
  static const int minimumImpressions = 250;
  static const double minimumCtrLift = 0.12;
  static const int targetEntryDwellMs = 3000;
  static const double maxScrollDepthDrop = 0.10;
  static const double minimumParticipationRetention = 0.97;

  static Map<String, Object> telemetryMetadata() => <String, Object>{
        'experiment_id': id,
        'min_impressions': minimumImpressions,
        'ctr_lift_target_pct': (minimumCtrLift * 100).round(),
        'entry_dwell_target_ms': targetEntryDwellMs,
        'scroll_drop_limit_pct': (maxScrollDepthDrop * 100).round(),
        'participation_floor_pct':
            (minimumParticipationRetention * 100).round(),
      };

  static FeedExperimentEvaluation evaluate({
    required int impressions,
    required double baselineCtr,
    required double observedCtr,
    required int averageDwellMs,
    required double baselineScrollDepth,
    required double observedScrollDepth,
    required double baselineParticipationRate,
    required double observedParticipationRate,
  }) {
    final ctrLift =
        baselineCtr <= 0 ? 0.0 : (observedCtr - baselineCtr) / baselineCtr;
    final scrollDepthDelta = baselineScrollDepth <= 0
        ? 0.0
        : (observedScrollDepth - baselineScrollDepth) / baselineScrollDepth;
    final participationRetention = baselineParticipationRate <= 0
        ? 1.0
        : observedParticipationRate / baselineParticipationRate;

    final meetsCtr = ctrLift >= minimumCtrLift;
    final meetsDwell = averageDwellMs <= targetEntryDwellMs;
    final meetsScroll = scrollDepthDelta >= -maxScrollDepthDrop;
    final meetsParticipation =
        participationRetention >= minimumParticipationRetention;

    final metricReasons = <String>[
      'CTR ${meetsCtr ? 'met' : 'missed'}: ${_formatSignedPercent(ctrLift)} vs target +${(minimumCtrLift * 100).toStringAsFixed(1)}%',
      'Dwell ${meetsDwell ? 'met' : 'missed'}: ${averageDwellMs}ms vs target <= ${targetEntryDwellMs}ms',
      'Scroll ${meetsScroll ? 'met' : 'missed'}: ${_formatSignedPercent(scrollDepthDelta)} vs guardrail -${(maxScrollDepthDrop * 100).toStringAsFixed(1)}%',
      'Participation ${meetsParticipation ? 'met' : 'missed'}: ${(participationRetention * 100).toStringAsFixed(1)}% vs floor ${(minimumParticipationRetention * 100).toStringAsFixed(1)}%',
    ];

    if (impressions < minimumImpressions) {
      return FeedExperimentEvaluation(
        status: FeedExperimentStatus.pending,
        summary: 'Collect more sample before deciding.',
        ctrLift: ctrLift,
        scrollDepthDelta: scrollDepthDelta,
        participationRetention: participationRetention,
        averageDwellMs: averageDwellMs,
        ctrPassed: meetsCtr,
        dwellPassed: meetsDwell,
        scrollPassed: meetsScroll,
        participationPassed: meetsParticipation,
        riskLevel: 'low_sample',
        reasons: <String>[
          'Sample pending: $impressions of $minimumImpressions impressions collected',
          ...metricReasons,
        ],
      );
    }

    if (meetsCtr && meetsDwell && meetsScroll && meetsParticipation) {
      return FeedExperimentEvaluation(
        status: FeedExperimentStatus.healthy,
        summary: 'Featured attention cue is outperforming baseline safely.',
        ctrLift: ctrLift,
        scrollDepthDelta: scrollDepthDelta,
        participationRetention: participationRetention,
        averageDwellMs: averageDwellMs,
        ctrPassed: true,
        dwellPassed: true,
        scrollPassed: true,
        participationPassed: true,
        riskLevel: 'none',
        reasons: <String>[
          'All rollout guardrails are passing',
          ...metricReasons,
        ],
      );
    }

    if (ctrLift < 0 ||
        scrollDepthDelta < -(maxScrollDepthDrop * 1.5) ||
        participationRetention < 0.90) {
      return FeedExperimentEvaluation(
        status: FeedExperimentStatus.fail,
        summary: 'Attention cue is hurting the feed and should be rolled back.',
        ctrLift: ctrLift,
        scrollDepthDelta: scrollDepthDelta,
        participationRetention: participationRetention,
        averageDwellMs: averageDwellMs,
        ctrPassed: meetsCtr,
        dwellPassed: meetsDwell,
        scrollPassed: meetsScroll,
        participationPassed: meetsParticipation,
        riskLevel: 'high',
        reasons: <String>[
          'One or more safety guardrails are failing materially',
          ...metricReasons,
        ],
      );
    }

    return FeedExperimentEvaluation(
      status: FeedExperimentStatus.caution,
      summary: 'Monitor the feed cue before promoting it wider.',
      ctrLift: ctrLift,
      scrollDepthDelta: scrollDepthDelta,
      participationRetention: participationRetention,
      averageDwellMs: averageDwellMs,
      ctrPassed: meetsCtr,
      dwellPassed: meetsDwell,
      scrollPassed: meetsScroll,
      participationPassed: meetsParticipation,
      riskLevel: 'watch',
      reasons: <String>[
        'The experiment is directionally useful but not fully proven yet',
        ...metricReasons,
      ],
    );
  }

  static String _formatSignedPercent(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${(value * 100).toStringAsFixed(1)}%';
  }
}
