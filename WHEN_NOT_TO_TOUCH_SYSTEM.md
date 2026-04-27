# MixVy When Not To Touch The System

Date: 2026-04-26
Scope: Anti-overfitting rules for calibration and rollout windows.

Purpose: prevent human-driven instability from threshold thrash.

## 1) Do Not Tune During These Conditions

1. During an active unresolved P1
2. Within 30 minutes after a mode transition
3. Within 2 hours of initial cohort start
4. When telemetry pipeline is degraded or incomplete

If any condition is true: observe only, do not adjust parameters.

## 2) Anti-Overfitting Rules

1. Never change more than 2 parameters per 4-hour block.
2. Never apply opposite-direction tuning inside the same block.
3. Require at least 3 repeated windows showing same pattern before tuning.
4. Use trend, not single incident snapshots.

## 3) Parameter Change Discipline

1. Make small moves only
- score thresholds: +/- 2 at a time
- weights: +/- 1 at a time
- stability window: +/- 1-2 minutes at a time

2. One-feature focus
- adjust messaging and rooms separately when possible

3. Record hypothesis before change
- expected effect
- expected observation window

## 4) No-Touch Scenarios

1. A single short burst resolves with one clean degrade and one clean recovery.
2. Transition cause is clear and user impact is contained.
3. Metrics return to baseline without flapping.

In these cases, tuning is more likely to hurt than help.

## 5) Operator Bias Guards

1. Never tune based only on anecdotal user report without matching telemetry.
2. Never tune during emotional pressure windows.
3. Require one reviewer confirmation for non-emergency tuning.

## 6) Override Handling

1. If operator override is active:
- freeze auto-threshold tuning decisions for that feature.

2. Before clearing override:
- verify stability window has passed
- verify no immediate retrigger pattern

## 7) Escalation Over Tuning

If system behavior is ambiguous, escalate and continue observing.
Ambiguity is not a tuning signal.
