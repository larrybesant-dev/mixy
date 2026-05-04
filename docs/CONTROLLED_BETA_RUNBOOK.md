# MixVy Controlled Beta Runbook

Date: 2026-05-03
Status: Stabilization complete, controlled-launch mode

## Baseline Gate (must stay true)
- Full tests: 458 passed, 0 failed
- Chat pane tests: passing
- Event pipeline tests: passing
- Presence guardrails: passing
- Verification policy tests: passing

If this baseline drops, pause rollout and fix before continuing.

## Phase 1: Feature Freeze (Immediate)
Do not merge:
- New screens
- UI redesigns
- Provider/state rewrites
- Architecture changes
- New experimental systems

Allowed changes:
- Test fixes
- Runtime bug fixes
- Monitoring and alerting
- Security/policy hardening

## Phase 2: Controlled Beta Runtime Validation (next 3-7 days)
Hard cap during this phase:
- 10-50 real users total
- No public rollout links
- No feature expansion while validation is in progress

### 1) Real device push validation (Android physical device)
Run matrix:
- App foreground
- App background
- App terminated
- Tap routing from notification
- Permission denied path
- Token refresh path
- Reinstall path

Exit criteria:
- Notification delivery success >= 95% in all app states
- Correct deep-link routing from tap-open
- No crashes in push handlers

### 2) Room joins under load
Run controlled load sessions with real users:
- 10 users in one room
- 25 users in one room
- 50 users split across 2-3 rooms
- churn scenario: repeated join/leave every 30-90 seconds

Track and review:
- Join success rate
- Duplicate join suppression behavior
- Presence cleanup time after leave
- Reconnect spikes and listener health alerts

Exit criteria:
- Join success >= 98%
- No persistent ghost participants
- No critical room-health alerts sustained > 1 monitor cycle

### 3) Chat + media validation on real networks
Run validation across mixed network conditions:
- Stable Wi-Fi
- Weak Wi-Fi
- Mobile hotspot/cellular

Validate:
- DM send/receive latency
- Room chat send/receive latency
- Mic/camera state transitions
- Reconnect recovery after network blips

Exit criteria:
- No message-loss regressions
- Media state converges after reconnect
- No crash loops during network handoffs

### 4) Payment attempts (sandbox + real edge cases)
Test flows:
- Sandbox success payment
- Sandbox decline/insufficient funds
- Retry after failed payment
- Duplicate-tap submit protection
- Auth/session expiration during payment attempt

Exit criteria:
- Correct success/failure states
- No duplicate charge writes
- No stuck "pending" state without recoverable UX

### 5) Crash telemetry verification
Trigger and verify:
- Handled exception
- Unhandled exception
- Async exception

Exit criteria:
- Crash reports visible in Crashlytics
- Stack traces include actionable frames
- User/session metadata present

### 6) Cost protection verification
Enable and validate:
- Firestore usage alerts
- Cloud Functions usage alerts
- Budget alerts and threshold notifications

Exit criteria:
- Alerts trigger at configured thresholds
- On-call/owner notification path works

## Phase 3: Kill-Switch Readiness (must be complete before widening beta)
### Kill-switch and rollback controls
1. Feature flags
- Verify runtime gates are visible in Operational Debug overlay.
- Required active flags:
	- `enable_live_rooms`
	- `enable_messaging`
	- `enable_speed_dating`
	- `enable_push_notifications`

2. Crash rollback ability
- Keep previous stable build artifact available.
- Define rollback owner and rollback trigger threshold before each beta wave.
- Trigger condition: crash-free sessions drop below threshold or critical startup crash appears.

3. Firestore cost alarms
- Configure budget alerts and notification recipients.
- Verify alert path by test threshold and on-call acknowledgment.

4. Push disable switch
- Use `enable_push_notifications = false` to stop push token usage and push navigation handling.
- Verify token unregister behavior and no new push opens are processed while disabled.

5. Room shutdown switch
- Use `enable_live_rooms = false` to block new room joins/creation during incidents.
- Verify users receive maintenance messaging and join attempts are rejected.

## Phase 4: Controlled Beta Rollout
Rollout steps:
- Wave 1: 10 users
- Wave 2: 25 users
- Wave 3: 50 users

Do not advance wave unless previous wave gate passes.

Wave gate checks:
- Crash-free sessions healthy and stable
- Room join/leave stability acceptable
- Messaging latency acceptable
- Push delivery acceptable
- Moderation load manageable
- Firestore/Functions cost trend acceptable

## Phase 5: Operational Review Cadence
Daily review dashboard:
- Crash rate
- Push delivery success by state
- Room errors and reconnect spikes
- Messaging send failure rate
- Moderation queue volume
- Firestore reads/writes trend
- Cloud Function invocations/errors
- Onboarding conversion

## Phase 6: Product Focus Rule
After first 7-14 days of beta data:
- Keep only heavily used systems
- Deprioritize low-use/high-cost systems
- Do not add net-new complexity until retention trend is clear

## Incident Rule
If any of the following occurs, freeze rollout immediately:
- Material crash spike
- Push delivery collapse
- Room stability regression
- Cost anomaly outside expected bounds

Then:
1. Stop next beta wave
2. Patch and verify in staging
3. Rerun full test suite
4. Resume rollout only after baseline recovers

## Release Discipline Rule
Every release candidate requires:
- Full test suite green (458/458 or current target)
- No high-severity runtime regressions
- Monitoring checks green
- Rollback plan documented
