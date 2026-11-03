# MixVy Production Readiness Audit

## Executive decision

**Status: Conditional no-go for a broad production launch.**

Core Flutter domain tests and Cloud Functions tests are healthy, the authenticated latency journey passes, stale-room recovery is implemented, and Playwright workers use isolated Firebase identities. The final fresh-account browser matrix completed with zero failures. Broad-launch confidence is still limited by skipped WebKit authentication-dependent gift cases, an undeployed operational-signal callable, and the absence of physical-device WebRTC network-transition evidence.

A small monitored canary is reasonable only after the P0 release gates below are completed.

## Evidence collected

| Surface | Result | Interpretation |
| --- | --- | --- |
| Flutter analyzer | 95 informational findings; no errors or warnings | Compiles cleanly, but deprecated APIs and dynamic calls create migration debt |
| Focused Flutter domain tests | 39/39 passed | Auth, routing, rooms, RTC plugin failure, chat, and payments have useful lower-level coverage |
| Cloud Functions tests | 21/21 passed | Stripe entitlement, moderation, calls, mic-grab, and operational-signal handlers passed |
| Authenticated latency journey | Passed at 600 ms backend delay | Sign-in, Rooms, Messages, and search remain usable under latency |
| Resilience stress suite | 2 deterministic checks passed; 1 expected WebRTC probe failure | Validation and route/offline recovery work; browser offline cannot deterministically prove RTC recovery |
| Final fresh-account Playwright matrix | 212 passed, 28 skipped, 0 failed | Core matrix is failure-free; Chromium-only semantic contracts and WebKit gift authentication account for skips |
| Stale-room focused Flutter tests | 22/22 passed | Deleted rooms are revalidated before entry and the destination provides Retry and Back to Rooms recovery |
| Launch alert policies | 6 enabled policies created | Policies exist, but cannot receive client signals until the callable deployment passes the production truth gate |
| Physical-device RTC recovery | Blocked | Device discovery found Windows, Chrome, and Edge only; no Android/iOS radio transition was available |

## Confirmed findings

### P0 - Production messaging stream can silently terminate (resolved)

`rawConversationsStreamProvider` applies a three-second production timeout and closes the sink on timeout. An idle Firestore stream is normal; closing it silently can freeze the inbox until provider recreation, without an error or reconnect signal.

**Location:** `lib/features/messaging/providers/messaging_provider.dart:62-95`

**Resolution:** The release-only timeout and sink closure were removed. Provider coverage now remains idle beyond three seconds, writes a conversation, and verifies delivery; an architecture guard forbids timeout/close logic in the canonical provider.

### P0 - Payment E2E suite does not prove named behavior (resolved)

The Stripe suite globally disables later tests after one authentication failure and contains assertions that only prove JavaScript types or tautologies, such as `typeof ... === 'number'`, `typeof ... === 'boolean'`, and `count >= 0`. These tests can pass without a checkout call, validation message, redirect, or entitlement mutation.

**Location:** `e2e/03-stripe-payment-integration.spec.ts:4-189`

**Resolution:** The placeholder suite was replaced with authenticated contract tests that verify the `premium_access` callable payload, returned Stripe URL launch, one-request pending state, visible failure, and retry. Webhook entitlement behavior remains covered by the Cloud Functions suite. The global `authUnavailable` state was removed.

### P0 - CI can report browsers as passed without reading outcomes (resolved)

The E2E publication job constructs a table that labels each browser `Passed` rather than deriving status from downloaded Playwright blob/JUnit reports. This can present a green summary after failures or skipped shards.

**Location:** `.github/workflows/e2e-tests.yml:245`

**Resolution:** PR summaries now use the actual core and advisory job conclusions instead of hard-coded browser results.

### P1 - Post-deploy critical-flow suite is advisory (resolved)

The production-suite job uses `continue-on-error: true`, allowing a release workflow to remain green when critical post-deploy behavior fails.

**Location:** `.github/workflows/tests-e2e.yml:93`

**Resolution:** The production suite now runs only after a successful smoke gate, and its Playwright command no longer suppresses failures.

### P1 - Parallel E2E authentication is nondeterministic (resolved)

The representative browser run failed the authenticated journey while the same test passed serially. Multiple workers reuse one Firebase identity, creating session/rate contention and causing downstream skips.

**Resolution:** The provisioner now creates a versioned account pool outside Playwright-cleaned output. Credentials are activated inside each worker, CI matrix jobs receive explicit account indices, and a fresh three-account run completed with 212 passed, 28 skipped, and zero failures. Scheduled account cleanup remains operational hygiene rather than a matrix blocker.

### P1 - Room feed can expose stale room entries (resolved)

The live-room stress probe clicked a real `Enter Room` control and navigated to a concrete room URL, but the destination rendered `Room not found` in one run. This confirms that a discovery entry can outlive its room document or become stale between listing and navigation.

**Resolution:** Room cards are revalidated at click time. Missing or inactive rooms emit a bounded monitoring signal, refresh discovery, and do not navigate. A room that disappears after navigation renders Retry and Back to Rooms actions instead of a dead end. Focused room tests pass 22/22.

### P1 - WebRTC recovery is not deterministically testable end to end

An active room did not expose `Reconnecting` or `Connection failed` after Playwright browser-offline emulation. This is not sufficient to prove a product defect because Chromium offline mode does not guarantee selective UDP/WebRTC transport loss.

**Location:** `e2e/08-resilience-stress.spec.ts:65-95`

**Required fix:** Add an injectable RTC transport/fault controller behind `RtcRoomService`, then drive `degraded`, `reconnecting`, `failed`, and recovered states in Flutter integration tests. Keep a device-level network-condition test for final validation.

**Current evidence:** Browser offline recovery remains an expected limitation because it does not reliably interrupt WebRTC transport. Device discovery on September 2, 2026 found no connected Android or iOS hardware, so Wi-Fi/cellular loss and reconnection were not executed and must remain a release gate before broad rollout.

### P0 - Launch signal ingestion is not deployed

Six native Cloud Monitoring log-match policies are enabled for authentication failures, stale-room navigation, messaging freshness, RTC reconnect exhaustion, payment entitlement mismatch, and uncaught web errors. The rate-limited `recordOperationalSignal` callable and its metadata sanitization pass Functions tests.

Deployment is blocked by the production truth predeploy gate: two legacy documents under `rooms/2cWvKUNPgXTuBZr4zxBg/messages` lack `conversationId`. The callable does not currently exist in `us-central1`, so the policies cannot receive client-originated structured signals until those records are repaired through the audited data-repair workflow and the callable is deployed.

### P2 - Room transaction null-safety is brittle

Room transactions check document existence and then force-unwrap snapshot data multiple times. This is currently guarded, but it violates the repository null-safety rule and duplicates mutable snapshot access.

**Location:** `lib/features/room/services/room_session_service.dart:335-386,493`

**Required fix:** Read each snapshot once into a nullable local, validate it, and return a domain error before field access. Add deletion-during-transaction and malformed-document tests.

### P2 - Analyzer debt masks future signal

The analyzer reports 95 informational findings, including deprecated Riverpod stream access, deprecated Flutter APIs, `dart:html`, dynamic calls, and diagnostic `print` usage.

**Required fix:** Establish a zero-new-infos baseline, migrate web code to `package:web`, replace deprecated APIs, and promote high-risk dynamic-call rules to warnings after cleanup.

## Expanded stress coverage added

`e2e/08-resilience-stress.spec.ts` now verifies:

- malformed email plus empty password are rejected in the Flutter UI without a Firebase sign-in request;
- ten rapid Rooms/Messages transitions converge on `/messages` without uncaught page errors;
- an HTTP offline/online cycle leaves the app rendered and restores navigation;
- a live-room browser-offline probe executes as an expected failure until RTC transport faults are deterministic;
- stale room fixtures are identified explicitly rather than reported as RTC failures.

`e2e/utils/credentials.ts` centralizes secure environment/local credential loading. `npm run test:e2e:stress` runs authenticated stress cases serially.

## Production-readiness roadmap

### Phase 0 - Release blockers (24-48 hours)

1. Completed: remove the three-second conversation-stream closure and add idle-then-update regression coverage.
2. Completed: replace Stripe tautologies with request, redirect, loading-state, and retry assertions; retain backend entitlement coverage.
3. Completed: give each Playwright worker an isolated Firebase account and fixture namespace.
4. Completed: generate CI summaries from actual job conclusions and make critical post-deploy smoke checks blocking.
5. Completed: filter stale room discovery records at entry and add refresh/back recovery paths.
6. Repair the two production message-schema violations and deploy `recordOperationalSignal` without bypassing the truth gate.

**Exit criteria:** No silent stream termination; payment happy/failure paths prove state changes; browser matrix is deterministic across three consecutive runs; CI cannot publish a false green status.

### Phase 1 - Resilience and UX (3-5 days)

1. Add injectable RTC fault states and integration tests for reconnect, exhaustion, retry, and leave.
2. Test malformed Firestore room/member documents and deletion races.
3. Add user-visible offline/retrying states to data surfaces that currently remain rendered with stale content.
4. Add latency budgets for authentication, first room list, inbox, and message-send acknowledgement.
5. Validate keyboard, screen-reader labels, focus order, and narrow mobile overflow on core routes.

**Exit criteria:** Every critical flow has loading, empty, error, offline, and recovery assertions; RTC recovery tests are deterministic; no dead-end room screen.

### Phase 2 - Security and performance (1-2 weeks)

1. Verify Firestore, Storage, and callable authorization with emulator-based allow/deny tests for owner, stranger, moderator, and admin roles.
2. Add App Check enforcement canaries and rate-limit abuse tests for auth, messaging, room joins, and payment functions.
3. Profile feed, room, and inbox rebuilds; cap unbounded listeners and paginate large collections.
4. Define Crashlytics/Analytics redaction tests so credentials, message bodies, and payment secrets never enter telemetry.
5. Rotate and centrally manage E2E identities and remove orphaned test accounts on a schedule.

**Exit criteria:** Authorization matrix is green; abuse controls are measurable; p95 interaction and backend latency budgets are enforced; sensitive-data telemetry tests pass.

### Phase 3 - Refactoring and governance

1. Replace transaction force unwraps with validated domain parsing.
2. Consolidate duplicated/legacy room routes on `/rooms/room/:id` and test redirects.
3. Reduce analyzer debt to zero or a documented expiring baseline.
4. Assign ownership and expiry dates to every `continue-on-error`, skip, expected failure, and quarantine.
5. Run a nightly full browser/device matrix while keeping PR gates focused and deterministic.

**Exit criteria:** No unexplained skips or advisory critical gates; route and service contracts are explicit; analyzer baseline trends downward each release.

## Launch recommendation

Do not treat the current suite as a broad-launch certification. A restricted canary is reasonable only after repairing the two production message-schema violations and deploying/verifying `recordOperationalSignal`. Before broad rollout, complete a real Android/iOS Wi-Fi-to-cellular RTC recovery test and remove or explicitly accept the remaining browser-matrix skips. The final fresh-account matrix is failure-free, but one green matrix is not the previously defined three-consecutive-run exit criterion.
