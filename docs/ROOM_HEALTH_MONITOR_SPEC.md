# MixVy Room Health Monitor Spec

Date: 2026-04-15
Status: Active

## Goal

Surface live-room instability before users feel it.

The monitor treats the room authority layer as the source of truth and turns runtime drift into visible health signals, structured logs, and release-facing alerts.

## Health States

- Healthy: score 85-100, no active unsuppressed alerts
- Warning: score 50-84, drift detected but the room is still recovering or usable
- Critical: score 0-49, authority or session stability is at risk

## Production Alert Model

The room monitor now uses thresholded production alerts instead of reacting to every raw signal.

### Severity groups
- Warning: degraded but recoverable issues
- Critical: likely user-facing instability or authority failure

### Recovery suppression
During reconnect and short recovery windows, transient drift signals are suppressed instead of escalated immediately.

This currently suppresses noisy alerts for:
- ghost_leave_risk
- mic_desync
- stale_presence

### Stability trend
The monitor keeps a rolling per-session score history so the debug dashboard can show whether the room is stabilizing or trending toward failure.

## Production Failure Modes

### 1. Ghost Leave / Phantom Ejection
- Trigger: stale leave replay after reconnect
- Detection:
  - presence mismatch while room phase is joined
  - room mismatch between authority state and presence state
- Alert code: ghost_leave_risk

### 2. Duplicate Room Join Storm
- Trigger: repeated join calls without an intervening leave
- Detection:
  - 2 or more join start events for the same user in 15 seconds
- Alert code: duplicate_join_storm

### 3. Firestore Stream Reset Loop
- Trigger: listener failures or WebChannel churn
- Detection:
  - 3 or more Firestore listener errors in 30 seconds
- Alert code: stream_reset_loop

### 4. Mic Desync
- Trigger: local UI mic state drifts from authority state
- Detection:
  - UI mic state differs from participant authority state
- Alert code: mic_desync

### 5. Host Migration Split-Brain
- Trigger: old and new hosts both retain host authority
- Detection:
  - multiple host claims for one active room
  - active room with no authoritative host
- Alert codes:
  - host_split_brain
  - host_missing

### 6. Zombie Listeners
- Trigger: listener not disposed after room churn or reconnect
- Detection:
  - duplicate active listener keys for one room client
- Alert code: zombie_listeners

### 7. Reconnect Loop Thrash
- Trigger: repeated reconnect attempts in a tight window
- Detection:
  - 3 or more reconnect attempts in 15 seconds
- Alert code: reconnect_loop_thrash

### 8. Stale Presence Drift
- Trigger: participant heartbeats stop updating on time
- Detection:
  - stale participant set is non-empty
- Alert code: stale_presence

## Logging Contract

All room-health events must emit structured telemetry through the shared telemetry layer.

Required event patterns:

- room.join with result=start for room entry attempts
- room.join_guard_triggered when duplicate joins are ignored
- room.multiple_hosts_detected for split-brain authority
- room.no_active_host when host authority is missing
- room.mic_state_mismatch for mic drift
- presence.presence_mismatch for room/presence conflicts
- firestore.listener_error for stream reset loops
- firestore.listener_start and firestore.listener_stop for listener lifecycle
- room.live_trace containing reconnect attempt counters

## Dashboard Contract

The debug dashboard must show:

- room health severity and score
- join burst count
- reconnect burst count
- Firestore error burst count
- active alert list
- listener count and duplicate listener keys
- presence mismatch and stale participant signals

## Release Use

Before public release, a room session is only considered stable if:

- room health remains Healthy during normal join, leave, reconnect, and host transfer flows
- no Critical alert persists for more than one monitor cycle
- host transfer converges to one authoritative host
- duplicate listener count returns to zero after room exit
