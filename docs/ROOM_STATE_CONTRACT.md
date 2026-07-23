# Room State Contract

**Version:** 1.0.0  
**Effective:** 2026-04-16  
**Owner:** `lib/features/room/room_controller.dart`  
**Enforcement:** `lib/features/room/room_state_contract.dart`

---

## Purpose

This document is the single authoritative specification for what constitutes
valid room state. Every invariant listed here is enforced at runtime (debug)
via `RoomStateContract.assertValid()` in `_emitState()` and verifiable in tests
via `RoomStateContract.validate()`.

If logic elsewhere in the codebase ever conflicts with a rule in this document,
the document wins — the code is wrong.

---

## 1. Role Hierarchy

Roles are ordered by descending authority. A role higher in the list is a
strict superset of the permissions of all roles below it.

| Tier | Role(s) | Stored as | Authority |
|------|---------|-----------|-----------|
| 0 | `host`, `owner` | `roomRoleHost`, `roomRoleOwner` | Full room control; only one per room |
| 1 | `cohost` | `roomRoleCohost` | Stage management + moderation |
| 2 | `moderator` | `roomRoleModerator` | Moderation only; cannot manage stage |
| 3 | `trusted_speaker` | `roomRoleTrustedSpeaker` | Can grab mic without approval when a slot is free; no moderation rights |
| 4 | `stage` | `roomRoleStage` | On-mic (mic seat holder); no management rights |
| 5 | `audience` | `roomRoleAudience` | Read + chat; no media publishing |

**Rules:**
- `owner` is a legacy alias for `host`. On each join, `owner` is migrated to
  `host` in Firestore. Both are accepted as host-like for role checks.
- There is exactly **one** host per room at any instant. A second user with a
  host-like role is a conflict (`hostConflict = true`).
- A user cannot hold two roles simultaneously. The controller maintains a
  single authoritative role per user in `participantRolesByUser`.
- No code path outside `RoomController` may determine or assign a role.

---

## 2. Speaker Resolution

### 2.1 Mode Selection

The controller selects one of two resolution paths based on the room document:

**Mode A — Speaker Documents** (preferred, used when present):  
Condition: `roomDoc['speakerSyncVersion'] is num || roomDoc['maxSpeakers'] is num`  
Source: `rooms/{roomId}/speakers` subcollection (via `roomSpeakerUserIdsProvider`)  
Authority: Speaker-doc list is authoritative. Participant role `stage` has no
effect on mic presence in this mode.

**Mode B — Legacy Role-Based** (fallback):  
Condition: neither `speakerSyncVersion` nor `maxSpeakers` present in room doc  
Source: participant docs with role `host`, `owner`, `cohost`, or `stage`  
Authority: Participant role determines mic presence.

### 2.2 Speaker Ordering

Within either mode, speakers are sorted by:
1. Rank ascending: `host/owner` = 0, `cohost` = 1, `stage` = 2, others = 3
2. `joinedAt` ascending (first to join is first in list)

### 2.3 Speaker Ceiling

`speakerIds.length <= RoomState.maxSpeakers` (currently 4) is a **hard
invariant**. It is enforced by `_resolveSpeakerIds` via `.take(maxSpeakers)` and
re-checked by `RoomStateContract.assertValid()`.

### 2.4 Ghost Speakers

A ghost speaker is a userId present in `speakerIds` that is absent from both
`userIds` and `hostId`. This is a normal timing condition (speaker-doc arrives
before participant-doc) — not a bug. The self-heal layer prunes ghost speakers
each build cycle. Once the participant doc arrives, the speaker reappears.

**Rule:** Ghost speakers after self-healing are a hard invariant violation.
If `assertValid()` fires for this condition post-heal, it is a programming bug
in `_resolveSpeakerIds`, not a timing issue.

---

## 3. User Membership Resolution

User IDs are derived from two sources merged by union:
1. `participantsStreamProvider(roomId)` — Firestore participants subcollection
2. `roomMemberUserIdsProvider(roomId)` — Firestore members subcollection

Additionally, the local user (`currentUserId`) is always added to the merged
set regardless of stream state, while the controller is in `joined` phase.

**Rule:** A user in `speakerIds` must be in `userIds` or be `hostId`. This is
enforced post-heal. If it still fires, it is a programming bug.

---

## 4. Stale-Event Protection

The controller maintains a per-user high-water mark `_lastActiveAtByUser` keyed
by the `lastActiveAt` field of each participant document.

**Rule:**  
If an incoming participant doc has `lastActiveAt < _lastActiveAtByUser[userId]`,
the doc is stale. The controller carries forward the previously accepted role and
discards the stale doc's role field.

**Consequence:** Role regressions from out-of-order Firestore delivery are
prevented. The high-water mark only moves forward.

---

## 5. Pending-Role Precedence

When the controller writes a role change (promote, demote, join) to Firestore,
the change is immediately placed into `_pendingRoleByUser[userId]` with a
timestamp in `_pendingRoleSetAtByUser[userId]`.

**Precedence rule:** While a pending role exists, `_resolveParticipantRoles`
uses the pending role instead of the Firestore-streamed role.

**Confirmation:** The pending entry is cleared when an incoming participant doc
has `role == pendingRole` (Firestore has echoed back the write).

**TTL expiry:** If `DateTime.now() - _pendingRoleSetAtByUser[userId] > 8s`
and Firestore has not confirmed the write, the pending role is expired and the
Firestore doc wins. This prevents a stuck pending role if the write silently
failed.

**Rule:** Pending role TTL is `_kPendingRoleTtl = 8s`. This value must never be
made adaptive (it would break the deterministic merge contract).

---

## 6. Forbidden States (Hard Invariants)

These states **must never exist** in any emitted `RoomState`. If they are
detected post-self-heal, it is a programming bug in the resolution layer.

| # | Invariant | Assertion MessageModel prefix |
|---|-----------|--------------------------|
| I-1 | `speakerIds.length <= maxSpeakers` | `"speakerIds.length exceeds maxSpeakers"` |
| I-2 | Every id in `speakerIds` is in `userIds` or equals `hostId` | `"speakerIds contains an id not in userIds or hostId"` |
| I-3 | If `phase == joined` and `currentUserId` is non-empty, then `currentUserId` is in `userIds` | `"phase=joined but currentUserId not in userIds"` |
| I-4 | If `hostId` is non-empty and has an entry in `participantRolesByUser`, that entry must be a host-like role | `"hostId has a non-host role in participantRolesByUser"` |

All four are checked in `RoomStateContract.assertValid()` and evaluated after
every `_selfHeal()` call inside `_emitState()`.

---

## 7. Recoverable Inconsistencies (Self-Heal Targets)

These are **normal timing conditions** caused by Firestore's independent
document delivery. They are repaired by `_selfHeal()` before assertions run.
Each repair is logged to `AppTelemetry`.

| # | Condition | Cause | Repair |
|---|-----------|-------|--------|
| H-1 | Ghost speaker in `speakerIds` | Speaker-doc arrived before participant-doc | Prune from `speakerIds` until participant-doc arrives |
| H-2 | `participantRolesByUser[hostId]` is a non-host role | Room doc and participant doc arrived in opposite order | Overwrite to `'host'` |

**Rule:** Self-healing is always idempotent. Running it twice produces the same
result as running it once.

**Rule:** Log every repair. Frequent repairs (≥ 3 in 60s) trigger a
`self_heal_spike` alert in `RoomHealthSnapshot`. Do not suppress or throttle
heal logs — they are the early warning signal.

---

## 8. Build Pipeline Order

The following sequence must be preserved within `build()` and never reordered:

```
1. _resolveParticipantRoles()   — stale-filter + pending-role merge
2. _resolveSpeakerIds()         — speaker-doc vs legacy path, ceiling applied
3. _selfHeal(candidate)         — timing repairs (ghost pruning, host alignment)
4. RoomStateContract.assertValid()  — hard invariant checks (post-heal)
5. equality guard               — prevent rebuild storms
6. state = healed               — emit
```

Steps 4–6 occur inside `_emitState()`.

**Rule:** `build()` is a pure projection. It must not mutate any field or launch
async operations. The only allowed mutable side effects in the resolution layer
are:
- Advancing `_lastActiveAtByUser[userId]` (high-water mark)
- Removing a confirmed entry from `_pendingRoleByUser` / `_pendingRoleSetAtByUser`

---

## 9. Action Gating

Privileged actions (stage management, mic grant, moderation, camera ACL) must
only execute when the controller lifecycle is `RoomLifecycleState.active`.

Actions gated on lifecycle:
- `grabMic` / `requestMic` / `releaseMic`
- `promoteToModerator` / `promoteToCohost` / `demoteToAudience`
- `inviteToMic` / `forceReleaseMic`
- Camera viewer ACL updates

The controller returns silently (no-op) or throws `StateError` when a gated
action is attempted outside `active` lifecycle. Callers must check
`state.lifecycleState == RoomLifecycleState.active` before showing action UI.

---

## 10. What Must Never Happen

The following are **absolute prohibitions**. Any code that does these is wrong:

| # | Prohibition |
|---|-------------|
| P-1 | Any widget or provider reads `participant.role` to make an **authority** decision (who can speak, who is host, is this user on mic). Use `state.participantRolesByUser[userId]` or `state.speakerIds` from `liveRoomControllerProvider`. |
| P-2 | Any code path writes `state = ...` directly on `RoomController` outside `_emitState()`. |
| P-3 | `_kPendingRoleTtl` is made adaptive, dynamic, or tuned based on network conditions. |
| P-4 | `_selfHeal` is given a circuit breaker that suppresses it. Heals are idempotent — suppression only hides bugs. |
| P-5 | A second user is allowed to hold a host-like role while another host is already in the room without setting `hostConflict = true`. |
| P-6 | `speakerIds` is populated via `micOn` flag from participant docs. `micOn` is a UI hint, not an authority signal. |
| P-7 | `build()` launches async operations or mutates controller fields other than the two listed in §8. |

---

## 11. Role Change Authority Matrix

Who can perform each action (actor role → allowed targets):

| Action | host/owner | cohost | moderator | trusted_speaker | stage | audience |
|--------|-----------|--------|-----------|-----------------|-------|----------|
| Promote to cohost | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Promote to moderator | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Promote to trusted_speaker | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Invite to mic (stage) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Demote to audience | ✅ | ✅ | ✅ (non-cohost) | self only | self only | self only |
| Force release mic | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Grab mic (self) | ✅ | ✅ | ❌ | ✅ (slot open) | ❌ | via request |
| End room | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Lock/unlock room | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Update room info | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Set mic timer | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage cam ACL | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

Implementors: check `canManageStageRole(role)`, `canModerateRole(role)`,
`isHostLikeRole(role)` from `room_state.dart` rather than inline string
comparisons.

---

## 12. Invariant Drift Signals

The following telemetry events are early warnings that an invariant is under
stress. Investigate the cause; do not tune thresholds to silence them.

| Event | Alert level | What it signals |
|-------|------------|-----------------|
| `self_heal_ghost_speakers` | warning | Speaker-doc / participant-doc delivery skew is high |
| `self_heal_host_role` | warning | Room-doc / participant-doc delivery skew around host field |
| `pending_role_expired` | warning | Firestore write failed silently; role was never confirmed |
| `self_heal_spike` (≥3/60s) | warning | Persistent inconsistency upstream — investigate Firestore timing |
| `self_heal_spike` (≥6/60s) | critical | System stability compromised — escalate |
| `host_conflict` | critical | Two users simultaneously hold host-like roles |
| `host_missing` | warning | No host-like user in the room; room is effectively leaderless |
