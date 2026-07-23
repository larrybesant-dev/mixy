# MixVy Startup Production Readiness Gate

Date: 2026-04-23
Scope: Startup behavior validation for web release decisions.

This gate is a binary ship decision layer for startup reliability.
Observability is considered complete; this document defines production thresholds and failure-path expectations.

## Release Rule

- PASS: all mandatory startup checks pass
- FAIL: any mandatory startup check fails

Startup gate must PASS in addition to existing release validation requirements.

## Canonical Timeline Signals

Use only the canonical startup checkpoints emitted by `startup_timing`:

- `startup.mainStart`
- `startup.bindingReady`
- `startup.firebaseReady`
- `startup.bootstrapResolved`
- `startup.firstFrameRendered`

## Derived Metrics (Required)

Compute and compare these deltas for every run:

1. `binding_to_firebase = firebaseReady - bindingReady`
2. `firebase_to_bootstrap = bootstrapResolved - firebaseReady`
3. `bootstrap_to_firstFrame = firstFrameRendered - bootstrapResolved`
4. `main_to_firstFrame = firstFrameRendered - mainStart`

## Startup SLA Thresholds

### Profile A: Normal Network (desktop Chrome, cold cache)

- `main_to_firstFrame`: p95 <= 2500ms
- `binding_to_firebase`: p95 <= 1500ms
- `firebase_to_bootstrap`: p95 <= 1200ms
- `bootstrap_to_firstFrame`: p95 <= 800ms
- Hard rule: no stuck startup (missing `firstFrameRendered`) in any run

### Profile B: Throttled Network (Chrome Fast 3G)

- `main_to_firstFrame`: p95 <= 6000ms
- `binding_to_firebase`: p95 <= 4000ms
- `firebase_to_bootstrap`: p95 <= 2500ms
- `bootstrap_to_firstFrame`: p95 <= 1200ms
- Hard rule: no indefinite spinner state; startup must resolve to either ready/degraded/failed path

## Failure-Path UX Expectations (Mandatory)

1. Firebase init failure:
- Expected: blocking failed startup message appears
- Prohibited: blank screen, route flicker, infinite loading

2. Bootstrap degradation path:
- Expected: app becomes usable with degraded indicator
- Prohibited: silent failure with no visible state change

3. Offline cold launch:
- Expected: deterministic startup resolution (failed or degraded/ready path), no stuck loading
- Prohibited: unresolved startup state

4. Service worker update cycle:
- Expected: one clean reload path, no endless reload loop
- Prohibited: repeated automatic reload or mixed-version broken shell

## Test Matrix (Required Before Ship)

Run all scenarios and capture startup logs for each:

1. Cold start (fresh tab + cache cleared)
2. Warm start (tab refresh without cache clear)
3. SW cached reload after new deployment
4. Offline launch
5. Throttled network launch (Fast 3G)

Minimum run count:

- Profile A: 10 runs per scenario
- Profile B: 10 runs per scenario

## Pass/Fail Decision

Ship startup gate is PASS only if:

1. All required scenarios executed
2. All four derived metrics meet p95 thresholds in both profiles
3. No stuck startup runs
4. Failure-path UX expectations pass in all failure scenarios
5. No service worker reload loop observed

Otherwise startup gate is FAIL.

## Evidence Package (Attach to Release PR)

1. Scenario run sheet with environment notes
2. Raw startup checkpoint logs for every run
3. Calculated p50/p95 for the four derived metrics
4. Explicit PASS/FAIL verdict for each scenario
5. Final startup gate verdict

## Notes

- This document does not change architecture, routing, or boot-state logic.
- This gate is about production behavior under realistic startup conditions.
