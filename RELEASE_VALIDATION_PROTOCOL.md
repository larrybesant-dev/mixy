# MIXVY - MVP Pre-Launch Runbook (24-Hour Ship Plan)

Use this runbook in exact order. Do not skip gates.

## Phase 0 - Freeze (Non-Negotiable)

### 0.1 Create release branch

```bash
git checkout -b release/mvp-v1
git tag mvp-stable-prelaunch
```

### 0.2 Freeze scope (7 day rule)

- No new features
- No refactors
- No schema changes
- Only bug fixes

## Phase 1 - Build Verification

### 1.1 Clean build

```bash
flutter clean
flutter pub get
flutter build web --release
```

Pass condition:

- Build completes with no errors
- No missing assets
- No runtime console crash on load

### 1.2 Smoke test built artifact

Open build/web/index.html and verify:

- App loads
- Firebase initializes
- No blank screen
- Router resolves correctly

Fail condition: stop release immediately.

## Phase 2 - Core System Tests (Hard Gates)

Run critical test suite:

```bash
flutter test
```

Must pass:

- Auth: sign in, sign out, session restore
- Onboarding: new user flow and completion redirect to /app
- Messaging: create conversation, send message, receive UI update, lastMessage updates correctly
- Rooms: join, leave, reconnect, state recovery

Pass rule: 100 percent pass or release is blocked.

## Phase 3 - Firebase Deployment Validation

Use staging project first. Never deploy straight to production.

Deploy order:

1. Firestore rules
2. Cloud Functions
3. App build test against staging

### 3.1 Rules validation checklist

Verify:

- messages collection readable and writable where expected
- conversations update allowed for lastMessage fields
- rooms/{id} access works
- beta_feedback accepts message field

### 3.2 Functions validation checklist

Verify:

- message creation behavior works as expected
- lastMessage updates are correct
- room lifecycle events operate correctly

## Phase 4 - Auth Flow End-to-End

Manual checks:

- Sign in via supported provider
- Sign out fully clears session
- Refresh browser restores session correctly
- Incomplete user routes to onboarding
- Completed user enters /app

## Phase 5 - Messaging Validation (Critical)

Validate full loop:

1. Create conversation
2. Send message
3. Verify Firestore write
4. Verify UI update
5. Verify lastMessage fields update

Pass criteria:

- No silent failure
- No rules rejection
- No schema mismatch

## Phase 6 - Room System Test (Real Device Required)

Test both mobile browser and desktop browser.

Flow:

1. Enter room
2. Send message
3. Leave room
4. Rejoin room
5. Verify state recovery

Pass criteria:

- No duplicate state
- No stuck listeners
- No null crashes

## Phase 7 - Observability (MVP Metrics Only)

Track only these three metrics:

- login_success_rate
- message_send_success_rate
- room_join_success_rate

Alert thresholds:

- login success below 95 percent
- message send failures above 2 percent
- room join failures above 3 percent

## Phase 8 - Dogfood Window (24 to 72 Hours)

Internal testers only, real usage only.

Collect:

- Top 10 errors by frequency
- Crash logs
- Firestore errors
- Routing issues

## Phase 9 - Patch Cycle

Fix only:

- P0: app broken or unusable
- P1: key feature unusable

Do not do polish work in this cycle.

## Phase 10 - MVP Release

After all gates pass:

```bash
git tag mvp-v1-release
```

Deploy production.

## Rollback Plan

If production fails:

```bash
git checkout mvp-stable-prelaunch
flutter build web --release
```

Redeploy immediately from the rollback tag.

## Evidence Checklist (Required)

Store release evidence in one place before final go decision:

- Build log
- Test run summary
- Staging rules and functions validation notes
- Manual auth and messaging validation notes
- Room validation notes from mobile and desktop
- Metrics dashboard screenshot or export
