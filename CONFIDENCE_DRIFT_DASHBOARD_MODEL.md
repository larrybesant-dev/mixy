# Confidence Drift Dashboard Model

This model tracks release-confidence behavior across RC cycles.

## Purpose

- Detect confidence-score instability over time.
- Surface gate reliability regressions early.
- Separate single-run pass/fail from trend quality.

## Inputs

- Verdict artifacts matching `tools/reports/release_candidate_verdict*.json`.
- Per-run fields:
  - `releaseCandidateVerdict`
  - `releaseConfidenceScore`
  - `releaseConfidenceBand`
  - `gates` (tier pass/fail)
  - `gateScores[].drift.averageVariabilityRatio`

## Outputs

- `tools/reports/confidence_drift_dashboard.json`
- `tools/reports/confidence_drift_dashboard.md`

## Core Metrics

- `latestScore`: most recent RC score.
- `scoreDeltaFromPrevious`: short-term movement signal.
- `averageScore`, `minScore`, `maxScore`: baseline operating range.
- `scoreStdDev`: confidence volatility indicator.
- `trendSlopePerRun`: directional trend across RCs.
- `failedTier0Runs`, `failedTier1Runs`: hard gate reliability.
- `confidenceBandDistribution`: quality distribution by band.

## Volatility Bands

- `stable`: stddev <= 3
- `moderate`: stddev <= 8
- `volatile`: stddev > 8

## Interpretation Rules

- Healthy trajectory:
  - Tier 0 and Tier 1 failures remain at 0.
  - Trend slope is flat-to-positive.
  - Volatility stays `stable`.
- Early warning trajectory:
  - Negative slope across consecutive RCs.
  - Rising stddev with unchanged feature load.
  - Repeated drops from `very_high/high` to `moderate/low`.

## Legacy Data Caveat

Older verdict-linked case summaries may not include min/avg duration fields.
For those records, the current model applies a compatibility fallback.
Trend precision increases as richer burn-in metrics accumulate.

## Usage

Run:

```powershell
./tools/build_confidence_drift_dashboard.ps1
```

Optional custom output:

```powershell
./tools/build_confidence_drift_dashboard.ps1 `
  -ReportsDir tools/reports `
  -VerdictPattern release_candidate_verdict*.json `
  -OutputJson tools/reports/confidence_drift_dashboard.json `
  -OutputMarkdown tools/reports/confidence_drift_dashboard.md
```