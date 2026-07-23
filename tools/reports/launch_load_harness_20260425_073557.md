# Launch Load Harness Report

- GeneratedAtUtc: 2026-04-25T12:35:57.5006291Z
- Harness: launch_load_harness_v1
- ValidationMode: observe
- Cycles: 1
- PressureRepeatsPerCycle: 0
- IncludeRulesValidation: False
- Verdict: FAIL
- TotalRuns: 5
- PassedRuns: 2
- FailedRuns: 3

| Case | Category | Pressure | Result | DurationMs | Failure Class |
| --- | --- | --- | --- | ---: | --- |
| LH-RM-1 | Room Concurrency | no | PASS | 6746 | duplicate_join|presence_drift|participant_desync |
| LH-RM-2 | Room Concurrency | no | PASS | 6666 | host_split_brain|duplicate_controller_state |
| LH-PY-1 | Payment Concurrency | no | FAIL | 1266 | double_debit|double_credit|idempotency_regression |
| LH-PY-2 | Room Concurrency | no | FAIL | 1429 | unauthorized_stage|mic_limit_regression|stale_stage_not_demoted |
| LH-PY-3 | Payment Concurrency | no | FAIL | 1321 | bad_signature_accepted|missing_error_log |

## Gate Rule

- PASS when every selected room and payment pressure case exits cleanly with expected positive signals.
- FAIL when any deterministic replay/authority/concurrency case fails.
