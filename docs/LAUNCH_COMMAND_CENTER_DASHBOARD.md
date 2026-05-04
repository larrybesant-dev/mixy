# MixVy Launch Command Center Dashboard

Date: 2026-05-03
Scope: Controlled beta operations (10-50 users), 24x7 monitoring readiness
Owner: Release commander + on-call operator

## Purpose

This dashboard is the real-time control surface for beta operations.
It is designed to answer one question fast:

- Is the system stable enough to continue current wave, or should we contain now?

## Operating Mode

- Phase 1 (Freeze + Instrument): dashboard validates that safety controls are wired and visible.
- Phase 2 (Controlled beta): dashboard drives go/hold/contain decisions each hour.
- Phase 3 (Kill-switch readiness): dashboard verifies switches work during live rehearsals.

## Single-Page Layout

### Panel A: Release Health Strip (top row)

Show last 5m, 15m, and 60m values with trend arrows:

1. `crash_free_session_rate`
- Healthy: >= 99.5%
- P1 threshold: < 99.0% for 10m

2. `room_join_success_rate`
- Healthy: >= 98%
- P1 threshold: < 95% for 5m
- P2 threshold: < 97% for 5m

3. `message_send_success_rate`
- Healthy: >= 99%
- P1 threshold: < 97% for 5m
- P2 threshold: < 98% for 5m

4. `push_delivery_success_rate`
- Healthy: >= 95% per app state
- P1 threshold: < 90% in any app state for 10m

5. `login_success_rate`
- Healthy: >= 97%
- P2 threshold: < 95% for 5m

### Panel B: User Impact and Wave Guardrails

- Active users now (total)
- Active users by area: feed, rooms, chat
- Current wave cap (must remain <= 50)
- Sessions with severe error (last 15m)
- New severe errors by app version

Hard guardrail:
- If active cohort exceeds wave cap, block invites and hold expansion.

### Panel C: Push Reliability Matrix

Break down delivery and open behavior by app state:

- Foreground delivery success
- Background delivery success
- Terminated delivery success
- Tap-open route success

Track separately for Android and iOS when available.

### Panel D: Room Stability and Reconnect Stress

- Join attempts vs successful joins
- Reconnect attempts per session
- Duplicate join suppressions
- Ghost participant detections
- Listener health anomalies

Alert mapping:
- `duplicate_join_storm`
- `reconnect_loop_thrash`
- `ghost_leave_risk`
- `zombie_listeners`

### Panel E: Chat and Media Real-Network Health

- DM send latency p50/p95
- Room chat send latency p50/p95
- Media state desync warnings
- Mic/camera recoveries after reconnect
- Failed message commit count

### Panel F: Payments Safety (Sandbox + Edge Cases)

- Payment attempts (sandbox)
- Payment declines/errors by cause
- Duplicate-submit blocked count
- Pending payments age distribution

Stop condition:
- Any duplicate charge signal or unresolved stuck pending state.

### Panel G: Cost and Load Exposure

- Firestore reads/min
- Firestore writes/min
- Functions invocations/min
- Functions error rate
- Budget threshold status

Alert levels:
- Warning when slope accelerates unexpectedly (>2x previous 60m baseline)
- Critical when budget threshold or predefined spend trigger is hit

### Panel H: Kill-Switch State and Governance

Display effective mode and source for:

- `enable_live_rooms`
- `enable_messaging`
- `enable_speed_dating`
- `enable_push_notifications`

Also show:
- `source` (remote/local/operator/auto)
- `last_update`
- `operator_override_active`
- `last_auto_action`

## Required Alert Routing

- P1: page on-call + incident channel immediately
- P2: incident channel and assign owner in <= 10 minutes
- P3: backlog with next triage checkpoint

## Decision Rules (Go / Hold / Contain)

### Continue wave

All true for previous 60 minutes:

- Crash-free sessions healthy
- Room/chat/push metrics above thresholds
- No active unresolved P1
- Cost slope stable

### Hold wave

Any true:

- Repeated P2 in same cluster within 60 minutes
- Push delivery unstable in one app state
- Room or chat degradation trend without clear stabilization

### Contain now (trigger switch)

1. Push collapse:
- Action: set `enable_push_notifications=false`

2. Room instability or join failures:
- Action: set `enable_live_rooms=false`

3. Chat failure storm:
- Action: set `enable_messaging=false`

4. Broad unknown degradation:
- Action: disable affected feature, freeze invites, begin rollback decision

## Command Center Roles (minimum)

1. Release commander
- Owns go/hold/contain decisions.

2. On-call operator
- Executes kill switches and confirms effect.

3. Incident scribe
- Records timeline, triggers, mitigations, and outcome.

## Rehearsal Checklist (must pass before scaling)

Run while users are active in beta:

1. Toggle push off and verify:
- No new push opens are processed.
- Token unregister flow completes.

2. Toggle rooms off and verify:
- New room join/create attempts are rejected with maintenance messaging.

3. Re-enable switches and verify recovery:
- No crash loops
- No stuck disabled state
- Metrics return to normal window

## Minimum Event Dimensions (every dashboard event)

- `app_version`
- `platform`
- `environment`
- `route`
- `session_id`
- `timestamp`
- `error_cluster` (if applicable)
- `is_fatal` (if applicable)

## Shift Handoff Template

- Current wave size:
- Active incidents:
- Any kill-switch active:
- Top 3 metric risks:
- Decision at handoff (`continue`, `hold`, `contain`):
- Owner for next 60 minutes:
