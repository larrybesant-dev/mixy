# MixVy Presence Chaos Test Script

Date: 2026-04-12
Owner: QA / Engineering
Scope: Validate real-time presence truth after session-based RTDB + Firestore bridge changes.

## Goal

Prove that online/offline, room presence, and cam/mic status are correct under hard failure conditions.

A release is blocked if any Critical test fails.

## Required Setup

1. Deploy latest backend changes before running tests:
- Cloud Functions (including RTDB -> Firestore presence sync trigger)
- Realtime Database rules
- Firestore rules

2. Use at least two clients:
- Device A (web or mobile)
- Device B (web or mobile)

3. Enable observability while testing:
- Firestore document: presence/<userId>
- RTDB node: status/<userId>/sessions
- Room participant docs: rooms/<roomId>/participants/<userId>

4. Test account:
- One shared test user for multi-device checks
- Optional second user for observer checks

## Pass/Fail Policy

- Critical tests: 1, 2, 3, 5
- Non-critical test: 4
- Full pass requires:
  - 0 Critical failures
  - <= 1 Non-critical failure with mitigation issue logged

## Test 1: Hard Kill (Critical)

Purpose: Verify abrupt app termination resolves presence quickly.

Steps:
1. On Device A, sign in and join a room.
2. Turn cam ON and mic ON.
3. Force-kill app/browser tab (no logout).
4. Observe RTDB + Firestore for up to 60 seconds.

Expected:
- Within 30-60 seconds:
  - Firestore presence/<userId>.isOnline = false
  - Firestore presence/<userId>.inRoom = null
  - Firestore presence/<userId>.camOn = false
  - Firestore presence/<userId>.micOn = false
- RTDB session node for killed device is removed or offline with null room and media off.

Fail if:
- User remains online beyond 60 seconds
- camOn or micOn remains true after disconnect
- inRoom remains set after disconnect

## Test 2: Multi-Device Session Integrity (Critical)

Purpose: Verify one dead session does not drop all sessions.

Steps:
1. Sign in same user on Device A and Device B.
2. On Device A, ensure active heartbeat and cam ON.
3. Force-kill Device B only.
4. Observe state for 60 seconds.

Expected:
- User remains online because Device A is still active.
- Active RTDB session count decreases by one, not to zero.
- Firestore presence stays online while A remains alive.
- cam/mic truth reflects live state from active session(s).

Fail if:
- Killing B marks user offline while A is alive
- Session count is incorrect
- Firestore presence flips incorrectly

## Test 3: Network Drop / Airplane Mode (Critical)

Purpose: Verify disconnect behavior when connection drops unexpectedly.

Steps:
1. On Device A, sign in and join room.
2. Turn cam ON.
3. Disable network (airplane mode / disconnect Wi-Fi).
4. Observe RTDB + Firestore for up to 60 seconds.

Expected:
- onDisconnect path executes.
- User transitions offline in Firestore within 30-60 seconds.
- inRoom cleared; camOn/micOn cleared.

Fail if:
- User remains online > 60 seconds after network loss
- Room/media fields remain active after disconnect

## Test 4: Rapid Cam/Mic Toggle (Non-Critical)

Purpose: Detect race conditions and state desync.

Steps:
1. Join room on Device A.
2. Rapidly toggle cam ON/OFF 10 times.
3. Rapidly toggle mic ON/OFF 10 times.
4. Observe on Device B and backend state.

Expected:
- No stuck camOn/micOn ghost state.
- Final backend state equals final UI state.
- No repeated errors or permanent mismatch.

Fail if:
- Final backend state differs from UI
- cam/mic becomes stuck after toggles
- Presence stream stops updating

## Test 5: Room Exit via Crash (Critical)

Purpose: Verify room participant cleanup under crash conditions.

Steps:
1. Join room on Device A.
2. Confirm participant exists in rooms/<roomId>/participants/<userId>.
3. Force-kill app.
4. Observe room participant list and global presence.

Expected:
- User no longer appears as active room participant after staleness window.
- Global presence reflects offline or out-of-room state.
- No ghost user in room roster UI.

Fail if:
- Participant remains active past expected staleness window
- UI roster shows ghost user

## Failure Signatures To Track

- User stuck online after kill
- Cam stuck ON after disconnect
- Duplicate sessions never cleaned
- Firestore/UI disagree on status
- State transition latency > 60 seconds

## Evidence Capture (Per Test)

Capture all of the following:
- Timestamped screenshots or console snapshots:
  - RTDB status/<userId>/sessions
  - Firestore presence/<userId>
  - Room participants snapshot (if applicable)
- Client logs (A and B)
- Exact transition latency (seconds)

## Results Matrix

| Test | Priority | Result (Pass/Fail) | Latency (s) | Notes | Ticket |
|---|---|---|---:|---|---|
| 1 Hard Kill | Critical |  |  |  |  |
| 2 Multi-Device | Critical |  |  |  |  |
| 3 Network Drop | Critical |  |  |  |  |
| 4 Rapid Toggle | Non-Critical |  |  |  |  |
| 5 Room Exit Crash | Critical |  |  |  |  |

## Exit Criteria

Release-ready presence requires all of the following:
1. All Critical tests pass.
2. No ghost online/cam/room states observed.
3. No state mismatch between RTDB aggregate truth and Firestore/UI.
4. Worst-case transition latency <= 60 seconds.

## Recommended Immediate Follow-up

1. Run this script in staging.
2. Fix any failure before broader rollout.
3. Repeat full script after each presence-related code change.
