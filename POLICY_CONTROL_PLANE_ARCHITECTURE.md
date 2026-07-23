# Policy Control Plane Architecture

This document codifies the separation of responsibilities for adaptive release governance.

## Plane Separation

1. Execution Plane
- Authoritative release decision runtime.
- Includes RC burn-in, release verdict, and enforced governor decision.
- Files: `tools/build_release_verdict.ps1`, `tools/evaluate_release_governor.ps1`, `.github/workflows/ci.yaml`.

2. Observation Plane
- Builds longitudinal telemetry and trend artifacts.
- Includes confidence drift dashboard and derived trend metrics.
- Files: `tools/build_confidence_drift_dashboard.ps1`, `tools/reports/confidence_drift_dashboard.json`.

3. Control Proposal Plane
- Non-authoritative policy recommendation system.
- Includes tuner proposals, policy snapshots, approval requests, and promotion receipts.
- Files: `tools/build_policy_tuner_snapshot.ps1`, `tools/approve_policy_proposal.ps1`.

## Contract Boundary

- Required contract file: `tools/policy_drift_contract.schema.json`.
- Validator: `tools/validate_policy_drift_contract.ps1`.
- CI must always emit and validate these artifacts:
  - `tools/reports/proposed_thresholds.json`
  - `tools/reports/rc_policy_snapshot_v1.json`
  - `tools/reports/policy_approval_request.json`
  - `tools/reports/policy_tuner_status.json`

## Safety Rules

1. Control Proposal Plane cannot directly mutate execution decisions.
2. Safety floors are immutable lower bounds for threshold tuning.
3. Approval remains human-in-the-loop for policy promotion.
4. Tuner failures must emit fallback artifacts with `policyAction = hold`.
