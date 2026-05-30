# Room Release Stress Gate

- GeneratedAtUtc: 2026-05-14T11:10:04.7817477Z
- ValidationMode: enforce
- Verdict: PASS
- TotalRuns: 6
- PassedRuns: 6
- FailedRuns: 0
- PrimaryFailureBucket: NONE
- ROOM FAILURE: 0
- PAYMENT FAILURE: 0
- RULES FAILURE: 0
- TIMEOUT / INFRA FAILURE: 0

| Case | Category | Result | DurationMs | Failure Class |
| --- | --- | --- | ---: | --- |
| RS-1 | System Stability | PASS | 5228 | ghost_leave|duplicate_join|reconnect_loop |
| RS-2 | Infrastructure Health | PASS | 6148 | listener_leak|duplicate_streams |
| RS-3 | Authority Correctness | PASS | 4243 | split_brain|host_missing |
| RS-4 | Realtime Consistency | PASS | 9968 | mic_desync|speaker_overflow |
| RS-5 | Realtime Consistency | PASS | 5911 | late_join_sync|ui_desync |
| RS-6 | Observability | PASS | 4539 | false_positive|silent_failure|bad_alerting |

## Gate Rule

- PASS when every deterministic room case exits cleanly and produces expected signals.
- FAIL when any room chaos, authority, telemetry, or recovery case fails.
