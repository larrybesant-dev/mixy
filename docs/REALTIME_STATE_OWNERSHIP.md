# Realtime State Ownership

Date: 2026-05-03
Status: Active
Scope: Canonical authority boundaries for presence, room lifecycle, visibility, and UI rendering.

## Purpose

This document defines which subsystem owns each piece of realtime truth.
If two layers disagree, the higher-authority layer wins and the lower layer must reconcile.

## Ownership Map

### 1. Presence Truth

Authority chain:

RTDB session state
-> Cloud Function projection
-> Firestore presence document
-> Riverpod presence providers
-> UI badges and room roster rendering

Rules:
- RTDB session data is the only live transport truth for online/offline, in-room, cam, and mic state.
- Firestore `presence/{userId}` is a queryable projection, not the source authority.
- UI must never infer online truth by itself when authoritative presence data exists.
- Client code must not write top-level Firestore presence documents directly.

Canonical owners:
- RTDB writes: `lib/services/rtdb_presence_service.dart`
- Controller orchestration: `lib/services/presence_controller.dart`
- RTDB -> Firestore bridge: `functions/index.js` export `syncPresenceFromRtdbSessions`
- UI parity diagnostics: `lib/shared/widgets/app_debug_overlay.dart`

### 2. Room Lifecycle Truth

Authority chain:

RoomController state machine
-> RoomRepository / RoomSessionService writes
-> Firestore room + participant docs
-> Room health monitor
-> UI room surfaces

Rules:
- `RoomController` owns authoritative room lifecycle transitions for join, leave, reconnect, and role resolution.
- Firestore room documents are persistence/query state, not independent authority.
- A room may only have one host-like authority at a time.
- Host transfer and room end must converge to one deterministic result.

Canonical owners:
- Room controller: `lib/features/room/room_controller.dart`
- Room state contract: `docs/ROOM_STATE_CONTRACT.md`
- Room session writes: `lib/features/room/services/room_session_service.dart`
- Room health monitor: `docs/ROOM_HEALTH_MONITOR_SPEC.md`

### 3. Visibility Truth

Authority chain:

RoomVisibilityContract
-> RoomService classification
-> Feed section providers
-> UI tier rendering and counters

Rules:
- Visibility tiering is only computed by `RoomVisibilityContract` through `RoomService`.
- Screens must not re-implement `isLive` filtering semantics.
- Feed counts must derive from classified outputs, not raw room collection queries.
- The invariant `discoverable + warm + cold + invalid == total classified` must always hold.

Canonical owners:
- Contract: `lib/features/room/contracts/room_visibility_contract.dart`
- Policy state: `lib/features/room/providers/room_visibility_windows_provider.dart`
- Classification engine: `lib/services/room_service.dart`
- Feed health: `lib/features/feed/providers/feed_providers.dart`

### 4. Rendering Truth

Authority chain:

Classified provider outputs
-> screen-specific section mapping
-> widgets

Rules:
- UI is responsible only for presentation grouping and degraded-state disclosure.
- UI must not promote or suppress rooms beyond the upstream classified result.
- Cold fallback is allowed only when feed health explicitly indicates fallback-active behavior.

Canonical owners:
- Section provider: `lib/features/feed/providers/feed_providers.dart`
- LiveFloor rendering: `lib/features/social/screens/live_floor_screen.dart`
- Debug disclosure: `lib/shared/widgets/operational_debug_overlay.dart`

## Transition Ownership

### Presence transitions
- online -> away -> offline: owned by RTDB session heartbeat + lifecycle signals
- inRoom set/clear: initiated by client controller, confirmed by RTDB and bridged projection
- camOn/micOn: transport truth in RTDB, projected to Firestore

### Room lifecycle transitions
- created -> active -> ended: owned by room session and room controller orchestration
- host transfer: owned by room authority layer, never by passive UI reads
- participant cleanup after crash: owned by backend cleanup + session reconciliation

### Visibility transitions
- discoverable -> warm -> cold -> invalid: owned by contract evaluation plus hysteresis stabilization
- policy windows: owned by Remote Config policy state with last-known-good caching and invariants

## Write Authority Boundaries

Allowed write paths:
- Presence session mutations through `RtdbPresenceService`
- Room lifecycle/session writes through room controller/session/repository layer
- Visibility policy updates through Remote Config only

Forbidden write patterns:
- direct screen/widget writes to `rooms` for lifecycle state
- ad hoc writes to top-level `presence/{userId}` from client UI code
- screen-level recomputation of visibility truth from raw Firestore fields

## Release Rule

A release is blocked if any of the following are true:
- two layers claim the same authority domain
- presence parity is not demonstrably stable under churn
- visibility rendering bypasses the classification pipeline
- room lifecycle ownership is ambiguous during reconnect or host transfer
