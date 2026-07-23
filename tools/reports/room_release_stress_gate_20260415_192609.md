# Room Release Stress Gate

- GeneratedAtUtc: 2026-04-16T00:26:09.3420440Z
- ValidationMode: enforce
- Verdict: FAIL
- TotalRuns: 7
- PassedRuns: 6
- FailedRuns: 1

| Case | Category | Result | DurationMs | Failure Class |
| --- | --- | --- | ---: | --- |
| RS-1 | System Stability | PASS | 6109 | ghost_leave|duplicate_join|reconnect_loop |
| RS-2 | Infrastructure Health | PASS | 5110 | listener_leak|duplicate_streams |
| RS-3 | Authority Correctness | PASS | 4133 | split_brain|host_missing |
| RS-4 | Realtime Consistency | PASS | 7683 | mic_desync|speaker_overflow |
| RS-5 | Realtime Consistency | PASS | 15849 | late_join_sync|ui_desync |
| RS-6 | Observability | PASS | 4615 | false_positive|silent_failure|bad_alerting |
| RS-7 | Recovery Validation | FAIL | 68919 | build_regression|residual_state_contamination |

## Gate Rule

- PASS when every deterministic room case exits cleanly and produces expected signals.
- FAIL when any room chaos, authority, telemetry, or recovery case fails.
