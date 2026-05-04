# Realtime Operational Certification

Date: 2026-05-03
Status: Active Gate
Scope: Closed beta and pre-production realtime readiness

## Purpose

This gate exists to stop MixVy from treating realtime correctness as a secondary concern.
From this point forward, major feature work does not outrank operational proof.

The blocking question is no longer:
- does the code compile?

The blocking question is:
- does realtime state remain correct during churn, reconnects, race conditions, outages, and multi-device conflict?

## Certification Rule

MixVy is not operationally certified until all of the following are true:

1. Staging environment is deployed with current functions, rules, and app build.
2. The staging chaos runbook is executed end-to-end.
3. Evidence is recorded in the operational gate template.
4. Any inconsistency fails the gate immediately.
5. Only proven failures are fixed.
6. The full run is repeated until stable.

Primary execution documents:
- `docs/STAGING_REALTIME_CHAOS_RUNBOOK.md`
- `tools/reports/staging_operational_gate_template.md`
- `docs/REALTIME_STATE_OWNERSHIP.md`
- `tools/reports/production_verification_matrix_2026-05-03.md`

## Blocking Risk Domains

### 1. Presence truth drift
Authority chain:
RTDB session -> Firestore projection -> providers -> UI

Certification fails if any of the following are observed:
- ghost online users
- zombie participants
- stale in-room presence after disconnect window
- Firestore projection disagreeing with RTDB session truth beyond allowed convergence

### 2. Ownership transfer races
Certification fails if:
- two hosts coexist for one active room
- host authority disappears without deterministic room end or transfer
- reconnect churn causes split-brain host authority

### 3. Multi-device consistency
Certification fails if:
- one dead client drops a still-live user offline
- duplicate sessions persist incorrectly
- the same user acquires conflicting room authority from separate clients

### 4. Cold fallback masking failures
Certification fails if:
- fallback activates repeatedly without explicit degraded visibility
- operators cannot distinguish healthy cold content from upstream failure
- fallback hides a broken primary live tier during testing

### 5. Backend cleanup timing
Certification fails if:
- participant cleanup lags beyond expected windows under reconnect churn
- ended rooms keep active participants
- retries create orphan or resurrected state

## Permanent Operational Principles

### Principle 1: One truth source per domain
- RTDB owns session truth
- Firestore owns indexed/query projection truth
- Room visibility contract owns feed truth
- UI never invents state

### Principle 2: Every derived state must be rebuildable
The following must always be reproducible from canonical truth:
- presence summaries
- room counts
- visibility tiers
- feed health states
- room occupancy projections

If a state cannot be rebuilt, it is not trustworthy.

### Principle 3: Every failure must become observable
A failure is not operationally controlled unless it is visible in at least one of:
- structured logs
- overlay/debug diagnostics
- validator output
- gate report evidence

## Exit Criteria

Realtime operational certification is granted only when:
- presence chaos passes repeatedly in staging
- room churn converges deterministically
- feed fallback remains visible and honest under degradation
- no silent classification imbalance is observed
- no critical parity mismatch persists
- no critical cleanup/orphan behavior survives the churn window

## Release Discipline Rule

Until certification is granted:
- do not prioritize major new realtime features over churn validation
- do not treat UX polish as evidence of correctness
- do not call the system production-ready based on static checks alone

## Current Assessment

Frontend architecture:
- approaching production quality

Realtime operational model:
- promising but not proven

Observability:
- meaningful enough to support certification work

Closed beta readiness:
- possible if the chaos matrix passes repeatedly

Public-scale readiness:
- blocked on operational proof
