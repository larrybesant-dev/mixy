# MixVy First 25 Users Launch Playbook

Date: 2026-04-26
Scope: Safe real-user rollout with active control-system observation.

Goal: prove stability under real entropy before broad exposure.

## 1) Rollout Phases

1. Phase A: 10 users (first 8 hours)
- Activate invite-only cohort of 10 users.
- Keep operator available for immediate overrides.

2. Phase B: 15 users total (next 8-12 hours)
- Add 5 users only if Phase A promotion criteria pass.

3. Phase C: 25 users total (remaining window)
- Add 10 users only if Phase B criteria pass.

No phase expansion if unresolved P1 exists.

## 2) Promotion Criteria Between Phases

All must be true for the previous phase window:

1. No unresolved P1 incidents
2. Messaging reliability stable (no sustained failure burst)
3. Room join reliability stable (no sustained join failure burst)
4. No mode flapping in either feature
5. All mode changes explainable in telemetry

If any fail: hold phase, tune thresholds, continue observing.

## 3) Live Monitoring Checklist (Every 60 Minutes)

1. Feature modes
- messaging mode
- rooms mode
- operator override status

2. Event stream sanity
- `feature_redirect_event`
- `degraded_entry_event`
- `kill_switch_trigger_event`

3. User-impact checks
- message send success behavior
- room join/rejoin behavior
- auth/session continuity

4. Control-loop quality
- false-positive degradations
- containment latency
- recovery behavior

## 4) Incident Response Rules

1. Messaging instability
- If repeated send failures: allow auto-response first.
- If blast radius grows: operator forces messaging `degraded` or `disabled`.

2. Rooms instability
- If join/reconnect failures spike: allow auto-response first.
- If user churn rises: operator forces rooms `degraded` or `disabled`.

3. Auth instability
- If auth failures spike and recovery recommendation is active:
  use operator guidance for controlled user messaging and retry flow.

4. Cross-feature instability
- Trigger release rollback protocol if both messaging and rooms become unstable with unresolved P1.

## 5) Trust Protection Rules

1. Never leave users in unexplained degraded state.
2. Every feature mode shift must have a clear telemetry reason.
3. Use consistent in-app language for temporary unavailability.
4. Prefer graceful degradation over silent failure.

## 6) Operator Command Policy

1. Precedence is fixed:
- operator override > auto-response > remote config

2. Operator actions must be logged with:
- reason
- expected duration
- recovery condition

3. Operator clears override only after:
- stability window is met
- no unresolved P1
- no immediate re-trigger pattern

## 7) Exit Criteria (Ready for 50+ Users)

Launch playbook passes when all are true for at least 12 consecutive hours at 25 users:

1. No unresolved P1
2. No uncontrolled mode flapping
3. False-positive degradations within tolerance
4. Messaging and rooms behavior meet reliability expectations
5. Operator interventions are decreasing, not increasing

If not met, keep cohort capped at 25 and continue calibration.
