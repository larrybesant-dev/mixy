# Presence Chaos Run Log (2026-04-12)

Use this with PRESENCE_CHAOS_TEST_SCRIPT.md.
Record evidence from the debug panel Copy Snapshot button + timestamps.

## Environment
- Build: local debug
- Device A:
- Device B:
- Test user:
- Start time:

## Test 1: Hard Kill (Critical)
- Start timestamp:
- Action timestamp:
- Snapshot before:
- Snapshot after:
- Offline transition latency (s):
- Result: Pass / Fail
- Notes:

## Test 2: Multi-Device Session Integrity (Critical)
- Start timestamp:
- Action timestamp:
- Session count before/after:
- Snapshot A:
- Snapshot B:
- Result: Pass / Fail
- Notes:

## Test 3: Network Drop / Airplane Mode (Critical)
- Start timestamp:
- Action timestamp:
- Snapshot before:
- Snapshot after:
- Offline transition latency (s):
- Result: Pass / Fail
- Notes:

## Test 4: Rapid Cam/Mic Toggle (Non-Critical)
- Start timestamp:
- Action timestamp:
- Final RTDB state:
- Final Firestore state:
- Final UI state:
- Mismatch observed: Yes / No
- Result: Pass / Fail
- Notes:

## Test 5: Room Exit via Crash (Critical)
- Start timestamp:
- Action timestamp:
- Participant doc state after crash:
- Global presence state after crash:
- Ghost observed: Yes / No
- Result: Pass / Fail
- Notes:

## Summary
- Critical failures count:
- Non-critical failures count:
- Release recommendation: Hold / Staged rollout / Proceed
- Owner sign-off:
