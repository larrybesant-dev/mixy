# Room Release Stress Gate

- GeneratedAtUtc: 2026-05-14T11:07:53.9632525Z
- ValidationMode: enforce
- Verdict: FAIL
- TotalRuns: 6
- PassedRuns: 5
- FailedRuns: 1
- PrimaryFailureBucket: TIMEOUT / INFRA FAILURE
- ROOM FAILURE: 0
- PAYMENT FAILURE: 0
- RULES FAILURE: 0
- TIMEOUT / INFRA FAILURE: 1

| Case | Category | Result | DurationMs | Failure Class |
| --- | --- | --- | ---: | --- |
| RS-1 | System Stability | PASS | 6215 | ghost_leave|duplicate_join|reconnect_loop |
| RS-2 | Infrastructure Health | FAIL | 6249 | listener_leak|duplicate_streams |
| RS-3 | Authority Correctness | PASS | 4310 | split_brain|host_missing |
| RS-4 | Realtime Consistency | PASS | 9722 | mic_desync|speaker_overflow |
| RS-5 | Realtime Consistency | PASS | 5804 | late_join_sync|ui_desync |
| RS-6 | Observability | PASS | 4517 | false_positive|silent_failure|bad_alerting |

## Gate Rule

- PASS when every deterministic room case exits cleanly and produces expected signals.
- FAIL when any room chaos, authority, telemetry, or recovery case fails.
