# MixVy First 10 Users Signal Checklist

Date: 2026-04-26
Scope: Hour-by-hour signals for the first real cohort.

This checklist is for observation only.
Do not tune thresholds in the first 2 hours unless a P1 is active.

## 1) Core Rule

Every state change must be explainable in one line:

1. Trigger event
2. Risk score / count
3. Mode transition

If a transition cannot be explained quickly, treat it as a control-plane defect.

## 2) Watch Windows

1. Hour 0-2: warm-up observation
- No threshold changes unless unresolved P1.

2. Hour 2-6: early stability
- Track false positives and containment timing.

3. Hour 6-12: confidence window
- Validate recovery quality and no flapping.

## 3) Signals To Watch Every 30 Minutes

1. Messaging reliability
- `send_message` failures in rolling 5 minutes
- Current messaging mode (`full`, `degraded`, `disabled`)

2. Room reliability
- room `join` failures in rolling 5 minutes
- Current rooms mode (`full`, `degraded`, `disabled`)

3. Auth reliability
- auth error burst count
- session recovery recommendations

4. Control-plane telemetry health
- `feature_redirect_event`
- `degraded_entry_event`
- `kill_switch_trigger_event`

5. Mode transition quality
- count of transitions per feature per hour
- any oscillation pattern (`full -> degraded -> full` repeatedly)

## 4) Fast Triage Rubric

1. If failures spike and mode changes once with stable recovery:
- likely healthy containment behavior.

2. If failures are low but mode changes repeatedly:
- likely over-control / false-positive trigger.

3. If failures are high and no mode change occurs:
- likely under-sensitive thresholds.

4. If operator override and auto-response compete:
- lock operator override, pause auto tuning decisions for that feature.

## 5) Red Flags (Immediate Escalation)

1. Same feature changes mode more than 2 times in 15 minutes.
2. Mode shifts without matching trigger event.
3. Prolonged `disabled` mode without active incident evidence.
4. Auth recovery recommendation remains active for > 30 minutes.

## 6) Minimal Log Template (Per 30 Minutes)

1. Window start/end
2. Messaging failures (peak 5m)
3. Rooms failures (peak 5m)
4. Auth failures (peak 5m)
5. Mode transitions
6. False-positive count
7. Operator actions (if any)
8. Decision: observe / hold / escalate

## 7) Exit Condition For First 10 Users

You may proceed to expansion only if all hold for at least 4 continuous hours:

1. No unresolved P1
2. No control-loop oscillation
3. All mode transitions telemetry-explained
4. No unexplained user-facing degraded states
