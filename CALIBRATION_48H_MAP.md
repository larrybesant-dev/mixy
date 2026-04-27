# MixVy 48-Hour Calibration Map

Date: 2026-04-26
Scope: Post-launch calibration for the closed-loop control system.

This plan tunes behavior, not architecture.
No new control subsystems should be added during this window.

## 1) Starting Baseline (Hour 0)

Use the current production defaults as the baseline:

1. Weighted risk model
- auth failure weight: 5
- messaging failure weight: 3
- room join failure weight: 3
- routing/degraded entry noise weight: 1

2. Messaging mode thresholds
- degrade when risk score >= 15
- disable when risk score >= 24
- disabled -> degraded recovery when risk score <= 7 and stable
- degraded -> full recovery when risk score <= 2 and stable

3. Rooms mode thresholds
- degrade when risk score >= 18
- disable when risk score >= 30
- disabled -> degraded recovery when risk score <= 8 and stable
- degraded -> full recovery when risk score <= 3 and stable

4. Temporal guards
- mode change cooldown: 2 minutes
- recovery stability window: 8 minutes

5. Auth guard
- auth recovery recommendation when auth failures in 5m >= 6

## 2) Hourly Observation Loop (Hours 1-48)

Run this every hour. Record every decision.

1. Check false-positive degradations
- Count mode shifts with no visible user impact incident.
- Target: <= 1 false-positive shift per 6 hours.

2. Check true-positive containment
- For each real incident, confirm containment happened before broad user breakage.
- Target: containment starts within 2 minutes of clear failure burst.

3. Check recovery quality
- Verify recovery returns progressively (`disabled -> degraded -> full`).
- Target: no flapping (more than 2 mode flips for same feature in 15 minutes).

4. Check operator conflict
- Verify no auto mode change is applied while operator override is active.
- Target: 0 override conflicts.

5. Check telemetry clarity
- Every mode shift must have one clear cause in telemetry.
- Target: 100 percent of shifts mapped to one `kill_switch_trigger_event` with trigger and score.

## 3) What To Watch (Only 3 Core Signals)

1. Messaging reliability
- Message send failures in 5m
- Effective messaging mode

2. Room join reliability
- Room join failures in 5m
- Effective rooms mode

3. Over-control signal
- `degraded_entry_event` bursts without corresponding backend incident

If over-control rises, tune weights/thresholds first, not architecture.

## 4) Tuning Decision Table

Apply changes only every 4 hours unless there is a severe incident.

1. If false-positive degradations are high
- Increase degrade thresholds by +2 score points
- Or lower routing noise weight from 1 to 0 (if mostly UI-triggered noise)

2. If degradation happens too late
- Decrease degrade thresholds by -2 score points
- Or increase auth failure weight from 5 to 6 when auth instability dominates

3. If recovery is too fast/flappy
- Increase recovery stability window from 8m to 10m
- Keep cooldown >= 2m

4. If recovery is too slow
- Decrease recovery stability window by 1-2m (never below 5m in first 48h)

5. If operator workload is too high
- Widen thresholds slightly (+2) before adding manual playbook complexity

## 5) Hard Guardrails (Do Not Violate)

1. Do not change more than 2 parameters in one 4-hour block.
2. Do not tune during an active unresolved P1.
3. Do not disable operator precedence.
4. Do not remove cooldown or hysteresis.

## 6) Data Capture Template (Per Hour)

1. Time block
2. Messaging failures (5m peak)
3. Room join failures (5m peak)
4. Auth failures (5m peak)
5. Mode transitions observed (with timestamps)
6. False-positive count
7. Parameter adjustments made (if any)
8. Expected outcome for next block

## 7) End-of-Window Exit Criteria (Hour 48)

Calibration window passes when all are true for the final 12 hours:

1. No unresolved P1 incidents
2. False-positive degradations <= 1 per 6h
3. No flapping incidents
4. Every mode shift is telemetry-explained
5. Operator override conflicts = 0

If any criterion fails, extend calibration by 24 hours.
