# MixVy Stability Scorecard 4H Dashboard

Date: 2026-04-26
Scope: Mechanical SCALE/HOLD decision framework for post-25-user operations.

This checklist converts stability signals into repeatable decisions.
Run once every 4 hours.

## 1) Scoring Model

Score each category from 0 to 2 points.

1. Repeatability
2. Variance Control
3. Recovery Determinism
4. Control-Loop Calmness
5. Cross-Signal Alignment

Total possible score per 4-hour window: 10.

## 2) Category Rules

### A) Repeatability (0-2)

2 points:
- Stable behavior observed in this window and replicated in at least 2 prior independent windows
- Evidence includes at least 2 load states (low + moderate)

1 point:
- Stable in current window but replicated only under low load

0 points:
- Stability breaks when interaction bursts begin

### B) Variance Control (0-2)

2 points:
- Failure rates remain within expected narrow band
- No outlier spike beyond defined control threshold

1 point:
- Average looks stable but one brief spike crosses warning threshold

0 points:
- Sharp spikes or repeated bursty outliers

### C) Recovery Determinism (0-2)

2 points:
- Same failure class leads to same containment and similar recovery time (small tolerance)

1 point:
- Recovery succeeds but timing varies materially

0 points:
- Recovery path is inconsistent by load/time/state

### D) Control-Loop Calmness (0-2)

2 points:
- Auto-response triggers are flat or decreasing
- No mode flapping in window

1 point:
- One noisy retrigger but no sustained oscillation

0 points:
- Repeated mode flips (full/degraded/disabled churn)

### E) Cross-Signal Alignment (0-2)

2 points:
- Telemetry, logs, and user-reported behavior agree directionally

1 point:
- Minor mismatch with clear root cause and quick correction

0 points:
- Material mismatch between system indicators and user reality

## 3) Window Verdict (Per 4 Hours)

1. 9-10 points: SCALE CANDIDATE
2. 7-8 points: HOLD + OBSERVE
3. 0-6 points: DO NOT SCALE

## 4) Global Guardrail (Critical)

Use worst-case window gating.

Rules:

1. Do not average away bad windows.
2. Any 4-hour window with score <= 6 blocks scale progression.
3. Two consecutive windows <= 8 force HOLD until recalibration evidence is collected.

## 5) Mandatory Blockers (Override Score)

Any blocker below forces HOLD regardless of points:

1. Unresolved P1 incident
2. Unexplained mode transition
3. Telemetry blind spot in control events
4. Operator override conflict

## 6) Operator Checklist (Every 4 Hours)

1. Record current cohort size
2. Score all 5 categories (0-2 each)
3. Record total score
4. Check blockers
5. Apply verdict (SCALE CANDIDATE / HOLD / DO NOT SCALE)
6. Record decision and rationale in one line

## 7) Decision Log Template

1. Window: [start-end]
2. Cohort size: [count]
3. Repeatability: [0-2]
4. Variance Control: [0-2]
5. Recovery Determinism: [0-2]
6. Control-Loop Calmness: [0-2]
7. Cross-Signal Alignment: [0-2]
8. Total: [0-10]
9. Blockers present: [yes/no + which]
10. Verdict: [SCALE CANDIDATE / HOLD / DO NOT SCALE]
11. One-line rationale: [text]

## 8) Scale Progression Rule

Promotion beyond the current cohort requires:

1. Three consecutive 4-hour windows scored >= 9
2. No blocker in any of those windows
3. No flapping pattern in the same period

If these are not met, maintain cohort and continue observation.
