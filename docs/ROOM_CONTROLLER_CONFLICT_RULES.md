# RoomController — Conflict Resolution Rules

> **One rule governs everything:** `RoomController` is the single authority for
> all room state. Firestore and RTC are *inputs*, never decision-makers.
> `RoomState` is an immutable output snapshot. The UI is a pure renderer.

---

## System model

```
RTC / Firestore streams
        ↓
[ Stale Filter Layer ]          ← _lastActiveAtByUser high-water marks
        ↓
RoomController (brain)          ← _pendingRoleByUser optimistic intent
        ↓
RoomState (immutable snapshot)
        ↓
UI (read-only renderer)
```

---

## Rule 1 — Event ordering (stale filter)

**Implementation:** `_lastActiveAtByUser : Map<String, DateTime>`

Every Firestore participant doc carries a `lastActiveAt` server timestamp.
The controller tracks the highest timestamp seen per user. Any incoming doc
with an *older* `lastActiveAt` is rejected — the previously accepted role and
snapshot are preserved unchanged.

**Implication for writes:** Every Firestore write that mutates a participant
doc (role change, heartbeat, presence) must touch `lastActiveAt` on the
server side so that when it echoes back, the `lastActiveAt` is equal-or-newer
and the filter passes.

---

## Rule 2 — Merge precedence (pending intent wins the confirmation window)

**Implementation:** `_pendingRoleByUser : Map<String, String>`

When a controller method promotes or demotes a user, it writes the intended
role into `_pendingRoleByUser[userId]` *before* awaiting the Firestore call.
During the gap between "write issued" and "Firestore echo received," every
`build()` cycle uses the pending role instead of the stale stream doc.

The pending entry is cleared only when a fresh Firestore doc arrives that
already carries the matching role — proving the write was confirmed.

**Every role-mutating method must follow this pattern:**
```dart
_pendingRoleByUser[userId] = targetRole;   // optimistic intent
await _firestoreWrite(userId, targetRole); // remote write
// echo arrival in _resolveParticipantRoles() clears the entry
```

---

## Rule 3 — Session isolation (full reset on leave)

**Implementation:** `leaveRoom()` clears both maps plus all session state.

`_lastActiveAtByUser` and `_pendingRoleByUser` are session-scoped. They must
be cleared in `leaveRoom()` before the controller returns to idle. Failure
to clear them would cause the watermarks from session N to reject valid
initial docs from session N+1, producing an empty roster on rejoin.

**No other path may clear these maps.**

---

## Authority hierarchy

| Tier | Role(s) | Can do |
|------|---------|--------|
| 1 | `host` | everything |
| 2 | `cohost`, `moderator` | stage management, participant management |
| 3 | `stage` | request/release mic |
| 4 | `audience` | read only |

Every public mutation method must call exactly one authority guard
(`_requireHostAuthority`, `_requireStageAuthority`, `_requireModerationAuthority`)
before writing. Guards are not optional and must not be bypassed.

---

## What future code must NEVER do

1. **Write `state = ...` directly** outside of `_emitState()`.
   `_emitState()` owns the equality guard and the lifecycle resolver.
   Bypassing it causes rebuild storms and lifecycle desync.

2. **Compute role or speaker authority in the UI layer.**
   Use `state.roleFor(userId)`, `state.isSpeaker(userId)`,
   `state.isOnMicByAuthority(userId)`. Never check raw Firestore role strings
   from outside the controller.

3. **Add a second source of speaker truth.**
   `RoomController._resolveSpeakerIds()` is the only place that derives the
   speaker list. Parallel providers that compute speaker lists independently
   will diverge under network lag.

4. **Mutate `_lastActiveAtByUser` or `_pendingRoleByUser` outside the
   resolution layer and `leaveRoom()`.**
   These maps have exactly two writers each. Adding new writers breaks the
   merge contract.

5. **Call `build()` side-effects.**
   `build()` must remain a pure projection. Never assign to a field or call
   an async method from inside `build()`. Use `_emitState()` from async paths
   instead.

---

## Clock assumption note

`lastActiveAt` is a Firestore server timestamp — not a monotonic clock.
Two rapid mutations within the same server millisecond will produce equal
timestamps. When `incomingAt == knownAt`, the filter passes (not stale) and
the Firestore doc is accepted. This means a very fast promote/demote sequence
can produce a single-build-cycle role bounce. The window is sub-millisecond
and bounded by Firestore write coalescing; it is not worth adding a sequence
counter unless profiling shows it as a real-world issue.
