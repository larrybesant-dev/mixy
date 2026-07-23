# Staging Realtime Chaos Runbook

Date: 2026-05-03
Status: Ready to Execute
Environment: Staging only

## Goal

Prove operational resilience for presence, room lifecycle, feed visibility, and degraded-state behavior before production release.

## Preconditions

1. Deploy latest staging rules and functions.
2. Confirm RTDB presence sync is enabled in staging.
3. Confirm Remote Config contains sane visibility windows.
4. Enable debug overlays and capture logs/screenshots.
5. Prepare at least two clients and preferably three:
- Device A
- Device B
- Observer client

## Evidence Required

For every scenario capture:
- wall-clock start and end time
- environment and app version
- RTDB session snapshot
- Firestore presence snapshot
- room participant snapshot if room-related
- feed health overlay or logs if feed-related
- PASS or FAIL with exact failure signature

Use: `tools/reports/staging_operational_gate_template.md`

## Phase A - Presence Churn

### A1. Hard kill
Expected:
- offline within 60s
- `inRoom` cleared
- cam/mic cleared
- no ghost roster user

### A2. Dual-device integrity
Expected:
- killing one device does not drop the other
- session count decreases but user remains online
- Firestore projection remains truthful

### A3. Airplane mode / network drop
Expected:
- RTDB disconnect path resolves offline within 60s
- no stuck in-room or media flags

### A4. Wifi <-> LTE switching
Expected:
- no duplicate online sessions beyond transient reconnect window
- no permanent parity mismatch between RTDB, Firestore, and UI

### A5. Reconnect spam
Action:
- disconnect and reconnect repeatedly for 2 minutes
Expected:
- no zombie sessions
- no duplicate participant state
- parity diagnostics return to green

## Phase B - Room Churn

### B1. 100 rapid room creates
Expected:
- no orphan room docs
- no malformed room visibility classification
- no ended rooms resurrected as discoverable

### B2. Rapid joins/leaves
Expected:
- participant docs converge
- member counts remain stable
- no orphan participants remain after cleanup window

### B3. Host disconnect mid-stream
Expected:
- deterministic transfer or deterministic end
- never two active hosts
- no split-brain authority alerts

### B4. Mass reconnect
Expected:
- room remains queryable
- health monitor may warn transiently but must converge
- no permanent duplicate listeners

## Phase C - Feed Collapse Simulation

### C1. Discoverable exhaustion
Action:
- age or mark active rooms so none remain discoverable
Expected:
- warm tier fills primary list if available
- fallback disclosure visible when primary is empty

### C2. Warm exhaustion
Action:
- push all rooms beyond warm window while preserving cold eligibility
Expected:
- cold fallback visible
- feed does not white-screen or spin indefinitely

### C3. Remote Config fetch unavailable
Expected:
- last-known-good cached policy applies immediately
- defaults only used if no valid cached config exists
- no crash and no broken ordering

### C4. Malformed timestamps
Action:
- inject staging-only invalid timestamp variants
Expected:
- invalid rooms get reason-coded suppression
- invariant remains intact
- feed stays populated if any visible rooms remain

## Phase D - Backend Failure Injection

### D1. Firestore denied
Expected:
- user sees graceful error state
- no infinite spinner
- telemetry indicates failure

### D2. RTDB unavailable
Expected:
- presence becomes degraded, not corrupted
- feed and room surfaces remain usable where possible
- parity monitor shows mismatch explicitly

### D3. Callable timeout
Expected:
- retry or clean error state
- no duplicate side effects

### D4. Delayed bridge sync
Expected:
- presence desync detected and exposed
- system converges when bridge resumes

## Phase E - Scale Probe

### E1. 10 rooms
Measure:
- snapshot latency
- rebuild count
- section stability

### E2. 100 rooms
Measure:
- classification throughput
- sorting overhead
- frame stability

### E3. 1000 rooms
Measure:
- listener pressure
- memory churn
- feed health behavior under heavy stale/cold populations

## Exit Criteria

Release is blocked if any of the following occur:
- ghost user persists after disconnect window
- split-brain host authority persists
- room disappears without reason-coded classification
- feed collapses without fallback disclosure
- invalid Remote Config breaks ordering
- degraded backend state causes white screen or infinite spinner

Release may proceed only if:
- all critical presence tests pass
- room churn converges deterministically
- fallback behavior remains visible and honest
- scale probe shows no catastrophic rebuild or memory storm
