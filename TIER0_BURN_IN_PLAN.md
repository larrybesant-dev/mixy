# Tier 0 Burn-In Plan

Date: 2026-04-13
Scope: MC-1..MC-4 and PS-1..PS-4
Objective: detect flakiness under repetition and ordering variation.

## Execution Profile

1. Run 10 cycles minimum.
2. Enable randomized case order each cycle.
3. Apply pressure repeats to MC-2 and PS-3 each cycle.
4. Treat any non-zero exit as a cycle failure signal.

## Command

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tier0_burn_in.ps1 -Cycles 10 -PressureRepeatsPerCycle 2 -Shuffle
```

## Burn-In Gate Conditions

1. Hard pass:
- 0 failed runs across all cycles.
- 100% pass rate for MC-1..MC-4 and PS-1..PS-4.

2. Soft warning (requires triage before Tier 1 signoff):
- Any single intermittent failure, even if rerun passes.
- Large duration variance on MC-2 or PS-3 compared to baseline.

3. Hard fail:
- Any repeated failure in the same case ID.
- Any failure in pressure repeats for MC-2 or PS-3.

## Triage Loop

1. Capture failing case ID and cycle from JSON report in `tools/reports/`.
2. Re-run failing case in isolation.
3. Fix behavioral issue (not test-only masking).
4. Re-run full burn-in profile from cycle 1.

## Exit To Tier 1

Proceed to Tier 1 validation only when burn-in gate is hard pass.