# MixVy Scale Past 25 Users Gate

Date: 2026-04-26
Scope: Expansion decision criteria from 25 users to broader rollout.

This is a binary gate: PASS or HOLD.

## 1) Gate Rule

Scale beyond 25 users only if all mandatory checks pass for a continuous 12-hour window.

## 2) Mandatory Checks

1. Incident status
- No unresolved P1
- No repeating P2 in the same failure cluster within 12 hours

2. Control-loop stability
- No feature mode flapping (no more than 2 flips in 15 minutes)
- All mode shifts are telemetry-explained
- Operator override conflicts: 0

3. Messaging reliability
- No sustained send failure burst requiring repeated disable cycles
- Recovery path returns to stable mode without immediate retrigger

4. Room reliability
- No sustained join failure burst requiring repeated disable cycles
- Rejoin/recovery behavior remains stable during real usage

5. User experience continuity
- No unexplained degraded screens
- No dead-end navigation caused by containment logic

## 3) Hold Conditions (Automatic)

Do not scale if any condition below is true:

1. Any unresolved P1
2. Any unexplained mode transition
3. Any control-loop oscillation incident
4. Any telemetry blind spot during the decision window

## 4) Promotion Steps After PASS

1. Move 25 -> 50 users
2. Hold and observe at least 8 hours
3. Re-run this gate before next expansion

Do not jump from 25 directly to broad public rollout.

## 5) Decision Log Template

1. Window evaluated
2. PASS/HOLD verdict
3. Failed checks (if HOLD)
4. Planned corrective actions
5. Next review time
