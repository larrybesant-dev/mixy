# MixVy Post-Launch Control System

Date: 2026-04-26
Scope: First 100 users and early production hardening.

This document defines the operational layer that runs after release gates pass.
It extends `RELEASE_VALIDATION_PROTOCOL.md` with real-world monitoring, alerting, and containment.

## 1) Objectives

1. Detect real-user degradation quickly.
2. Convert raw errors into actionable failure clusters.
3. Enforce first-100-users stability before scale expansion.
4. Provide feature-level containment before full rollback.

## 2) Control Window

- Phase A: first 24 hours after release
- Phase B: 24 to 48 hours after release
- Scale expansion is blocked until all Phase B guardrails pass.

## 3) Core Metrics (Source of Truth)

Track these as release-level KPIs by app version, platform, and environment.

1. `login_success_rate`
- Definition: successful login completions / login attempts
- Healthy target: `>= 97%`
- Alert threshold: `< 95%` for 5 minutes

2. `message_send_success_rate`
- Definition: successful message commits / message send attempts
- Healthy target: `>= 99%`
- Alert threshold: `< 98%` for 5 minutes

3. `room_join_success_rate`
- Definition: successful room joins / room join attempts
- Healthy target: `>= 98%`
- Alert threshold: `< 97%` for 5 minutes

4. `crash_free_session_rate` (mandatory)
- Definition: `1 - (sessions_with_fatal_error / total_sessions)`
- Healthy target: `>= 99.5%`
- Alert threshold: `< 99.0%` for 10 minutes

## 4) Dashboard Specification

Minimum dashboard panels:

1. KPI strip
- `login_success_rate`
- `message_send_success_rate`
- `room_join_success_rate`
- `crash_free_session_rate`

2. Version split
- KPI trends by `app_version`

3. Funnel checks
- login attempt -> login success
- room enter tap -> room join success
- message send tap -> message commit success

4. Error cluster heatmap
- clusters (section 5) by frequency over last 15m/1h/24h

5. Environment and platform split
- web/mobile split
- staging/production split

Required dimensions on all events:

- `app_version`
- `platform`
- `environment`
- `route`
- `uid_hash` (non-PII hash)
- `session_id`
- `timestamp`

## 5) Error Clustering Map (Required)

All runtime errors must be assigned to exactly one primary cluster:

1. `auth_failures`
- Examples: token refresh failure, unauthorized route after login, session restore failure

2. `firestore_permission_failures`
- Examples: permission denied, rules reject writes/reads, index-required read failures

3. `routing_dead_ends`
- Examples: unresolved routes, redirect loops, guarded route hard stops

4. `message_delivery_failures`
- Examples: send acknowledged in UI but missing in backend, stale `lastMessage`, listener desync

5. `room_lifecycle_failures`
- Examples: join timeout, reconnect loop, leave cleanup failure, duplicate presence state

Cluster assignment fields:

- `error_cluster`
- `error_code`
- `error_source` (client, firestore, functions, router)
- `is_fatal` (true/false)

## 6) Alert Rules

Severity levels:

- P1: immediate action required (user-facing outage/high risk)
- P2: degraded behavior with workaround
- P3: warning trend requiring investigation

Rules:

1. P1
- `crash_free_session_rate < 99.0%` for 10m
- `message_send_success_rate < 97%` for 5m
- `room_join_success_rate < 95%` for 5m

2. P2
- `login_success_rate < 95%` for 5m
- `message_send_success_rate < 98%` for 5m
- `room_join_success_rate < 97%` for 5m

3. P3
- Any error cluster increases > 2x versus previous 60m baseline

Notification routing:

- P1: page on-call + incident channel
- P2: incident channel
- P3: ops backlog + next triage window

## 6.1) Telemetry Binding (Closed-Loop Events)

The runtime now emits control-plane events that bind user impact to containment behavior:

1. `feature_redirect_event`
- Emitted when routing is redirected due to feature policy (`full/degraded/disabled` context included).

2. `degraded_entry_event`
- Emitted when users enter degraded or disabled fallback surfaces.

3. `kill_switch_trigger_event`
- Emitted when auto-response changes feature mode or recommends session recovery.

Required fields:

- `feature`
- `route`
- `mode` (`full`, `degraded`, `disabled`)
- `trigger`
- `count_5m`
- `window_minutes`

These events are forwarded through app telemetry/analytics for operator correlation.

## 6.2) Auto-Response Rules (Lightweight)

Window: 5 minutes rolling.

1. Messaging
- `>= 5` failures: set messaging mode to `degraded`
- `>= 8` failures: set messaging mode to `disabled`

2. Rooms
- `>= 7` room join failures: set rooms mode to `degraded`
- `>= 10` room join failures: set rooms mode to `disabled`

3. Auth
- `>= 6` auth failures: emit session recovery recommendation (`kill_switch_trigger_event`)

Current policy is intentionally conservative and local-first to prevent broad false positives.

## 6.3) Governance Safety Layer

The control plane now applies governance guards to avoid self-induced outages.

1. Confidence weighting
- Auth failures: high weight
- Messaging/room failures: medium weight
- Routing/UI degraded-entry noise: low weight

2. Cooldown and hysteresis
- Mode changes are cooldown-limited
- Recovery requires a sustained stability window before stepping back up
- Recovery is progressive (`disabled -> degraded -> full`)

3. Override hierarchy
- Operator override > auto-response > remote config
- Auto-response will not override an active operator mode

## 7) First 100 Users Stability Gate

Do not increase launch cohort until all conditions pass for a continuous 24 to 48 hours:

1. `message_send_success_rate >= 99%`
2. `room_join_success_rate >= 98%`
3. `crash_free_session_rate >= 99.5%`
4. No unresolved P1 incidents
5. No repeating P2 incident in the same cluster for 12h

If any condition fails, freeze cohort expansion and execute containment.

## 8) Containment and Kill-Switch Playbook

Use feature-level containment before full rollback when possible.

Available remote switches (already defined in project docs):

- `enable_messaging`
- `enable_live_rooms`

Containment matrix:

1. Messaging degradation (`message_delivery_failures` spike)
- Action: set `enable_messaging=false`
- Expected behavior: message routes/features redirect safely
- Follow-up: validate auth and room KPIs are stable

2. Room degradation (`room_lifecycle_failures` spike)
- Action: set `enable_live_rooms=false`
- Expected behavior: room/live routes redirect safely
- Follow-up: validate messaging and auth KPIs are stable

3. Firestore permission misfire (`firestore_permission_failures` spike)
- Action: disable affected feature via remote switches
- Action: validate staged rules fix before production redeploy
- Escalation: rollback to stable tag if both core features are impacted

4. Cross-system instability (multiple P1 signals)
- Action: execute rollback in `RELEASE_VALIDATION_PROTOCOL.md`

## 9) Incident Evidence Requirements

For each P1/P2 incident, capture:

1. Start/end timestamps
2. Affected app version(s)
3. Cluster and error codes
4. Blast radius estimate (sessions/users impacted)
5. Mitigation action (switch/rollback/hotfix)
6. Recovery verification screenshots or metric exports

Store in release evidence artifacts before declaring closure.

## 10) Daily Operating Rhythm (First 7 Days)

1. Triage windows: every 4 hours
2. Daily incident summary: top clusters, trend delta, unresolved risks
3. Release decision checkpoint: continue, freeze, or roll back

This control loop is mandatory for post-launch hardening.