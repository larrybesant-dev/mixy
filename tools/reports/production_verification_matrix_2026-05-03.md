# Production Verification Matrix - 2026-05-03

## Scope
This run validates architecture and backend readiness using deterministic scripts and static contract audits in the current workspace.

## Phase 1 - Truth Validation
Status: PARTIAL PASS

Checks executed:
- Firestore truth validator: `functions/scripts/validate-firestore-truth.js --sample 200`
- Feed-tier partition invariant logging added in app runtime.
- Static scan for room-feed bypasses and direct `isLive` filtering in UI screens.

Evidence:
- `validate-firestore-truth`: PASSED
  - total scanned: 178
  - total violations: 0
  - report: `tools/reports/firestore_truth_validation.json`
- UI screen scan: no direct `isLive` filtering found under `lib/features/**/screens/**`.
- Feed invariant now enforced in `lib/features/feed/providers/feed_providers.dart`:
  - discoverable + warm + cold + invalid == classified total
  - logs `ROOM_VISIBILITY_INVARIANT_BROKEN` if drift occurs.

Residual findings:
- Non-feed direct-call flow uses `.where('isLive', isEqualTo: true)` in `lib/features/room/providers/message_providers.dart` for incoming direct calls.

## Phase 2 - Runtime Stability (Presence)
Status: ARCHITECTURE PASS, EXECUTION PENDING

Architecture path verified:
- RTDB truth writer in client: `lib/services/rtdb_presence_service.dart`
- Controller mediation: `lib/services/presence_controller.dart`
- Backend RTDB -> Firestore bridge: `functions/index.js` export `syncPresenceFromRtdbSessions`
- UI parity diagnostics: `lib/shared/widgets/app_debug_overlay.dart`

Residual risk:
- Runtime force-close/background/reconnect/dual-device scenarios were not executed in this run.

## Phase 3 - Data Contract Validation
Status: PASS (sample-based)

Checks executed:
- `validate-firestore-truth.js` covers conversations, messages, rooms, participants, follows symmetry.

Result:
- PASS with zero violations in sample run.

## Phase 4 - UI Contract Testing
Status: PARTIAL PASS

Implemented verification support:
- Explicit Discoverable/Warm/Cold rendering in LiveFloor.
- Feed health state and fallback visibility surfaced via operational overlay.

Pending manual walkthroughs:
- After Dark, Explore, Room Browser, Dashboard, Quick Join, Notifications, Profile indicators under empty/warm/cold/reconnect churn scenarios.

## Phase 5 - Room Lifecycle Stress Tests
Status: PENDING

Available harness:
- `functions/scripts/stress-test-harness.js` (writes real data; staging/dev only).

Not executed in this run:
- host leave transfer/end, simultaneous joins, rapid room churn, reconnect-mid-room deterministic checks.

## Phase 6 - Functions & Backend Integrity
Status: PASS WITH 1 WARNING

Check executed:
- `functions/scripts/ship-checklist.js`

Result:
- PASS (no failures), 1 warning:
  - raw `FirebaseFirestore.instance` usage in UI layer reported by architecture guard.
- report: `tools/reports/ship_checklist.json`

Note:
- Ship-checklist false-positive secret check was corrected to ignore generated firebase options files.

## Phase 7 - Performance & Scale
Status: PENDING

No 10/100/1000 room benchmark execution in this run.

## Phase 8 - Failure Injection
Status: PENDING

No controlled outages injected in this run.

## Phase 9 - Observability
Status: PASS (instrumentation)

Added/verified:
- visibility decision reason/tier telemetry
- feed health state enum and rates
- fallback active detection
- policy source/validity and active windows
- overlay exposure for operational triage

## Phase 10 - Production Gate
Status: PARTIAL PASS

Backend gate:
- PASS in current sampled checks.

Frontend gate:
- `flutter analyze` has no errors.
- remaining infos/warnings exist (deprecated provider `.stream` usage and lint-style issues).

Product/ops gate:
- Empty primary feed fallback implemented and visible.
- Runtime resilience improved with policy cache + invariants + hysteresis.

Final gate recommendation:
- Do not mark full production-ready until Phases 2, 5, 7, 8 are executed in staging with scripted evidence capture.
