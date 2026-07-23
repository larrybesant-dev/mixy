# Release Candidate Verdict

- GeneratedAtUtc: 2026-04-25T13:55:53.3153700Z
- GitRef: 
- GitSha: 
- Verdict: PASS
- ConfidenceScore: 100
- ConfidenceBand: very_high

## Gate Summary

| Gate | Pass | TotalRuns | PassedRuns | FailedRuns | Score | DriftScore | AvgVariability | MaxVariability | SourceReport |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| tier0 | True | 60 | 60 | 0 | 100 | 100 | 0 | 0 | tier0_burn_in_20260413_070720.json |
| tier1 | True | 14 | 14 | 0 | 100 | 100 | 0 | 0 | tier1_burn_in_20260413_073342.json |
| room | True | 7 | 7 | 0 | 100 | 100 | 0 | 0 | room_release_stress_gate_20260415_192941.json |

## Failure Classification

- PrimaryFailureBucket: NONE
- ROOM FAILURE: 0
- PAYMENT FAILURE: 0
- RULES FAILURE: 0
- TIMEOUT / INFRA FAILURE: 0

## Regression Comparison

- ComparedRunCount: 4
- ExecutionTimeDriftPercent: 0
- FailureFrequencyDrift: 0
- RetryRateDrift: 0

## Pre-Launch Score

- StabilityScore: 100
- ScoreBand: launch_ready
- CyclePassRate: 100
- StressResilience: 100

## Top Drift Cases

### Tier 0
| Case | MinMs | AvgMs | MaxMs | Variability |
|---|---:|---:|---:|---:|
| PS-4 | 12881 | 12881 | 12881 | 0 |
| MC-3 | 4794 | 4794 | 4794 | 0 |
| PS-3 | 4862 | 4862 | 4862 | 0 |

### Tier 1
| Case | MinMs | AvgMs | MaxMs | Variability |
|---|---:|---:|---:|---:|
| NR-3 | 6386 | 6386 | 6386 | 0 |
| NR-4 | 5748 | 5748 | 5748 | 0 |
| NR-1 | 4641 | 4641 | 4641 | 0 |

### Room Gate
| Case | MinMs | AvgMs | MaxMs | Variability |
|---|---:|---:|---:|---:|
| RS-1 | 5204 | 5204 | 5204 | 0 |
| RS-2 | 5331 | 5331 | 5331 | 0 |
| RS-3 | 4055 | 4055 | 4055 | 0 |

## Notes
- Decision policy: releaseCandidateVerdict must be PASS to release.
- Confidence policy: tier0, tier1, and room stability all contribute to the score.
- Classification: failure_classification_v1
- Regression: run_regression_v1
- PreLaunch: pre_launch_score_v1
- Model: rc_confidence_v3
