# MixVy

MixVy is a Flutter social/live-room app with Firebase, Riverpod, payments, moderation, and web support.

## Prerequisites
- Flutter SDK (stable)
- Dart SDK (bundled with Flutter)
- Firebase project configured for Auth, Firestore, Functions, Storage
- Node.js 22 (for Firebase Functions)
- Java 21+ (required for Firebase Firestore emulator and `npm --prefix functions run test:rules`)

## Local Setup
1. Install dependencies:
	- flutter pub get
2. Install function dependencies:
	- cd functions && npm install
3. Align the local Functions runtime version before using npm or Firebase Functions commands:
	- use Node 22 in `functions/` (`.nvmrc` and `.node-version` are provided)
4. Ensure required environment values are available for runtime:
	- FIREBASE_API_KEY_WEB
	- FIREBASE_API_KEY_WINDOWS
	- AGORA_APP_ID (if using live A/V)
	- STRIPE keys and function env vars for payment features

## Running the App
- Mobile/Desktop:
  - flutter run
- Web (Chrome):
  - flutter run -d chrome

## Web Build and Deploy Workflow
1. Build release web:
	- flutter build web --release --base-href "/"
2. Build release web with explicit version tag (recommended for production traceability):
	- flutter build web --release --base-href "/" --dart-define=APP_VERSION=1.0.0+001
3. Optional runtime compatibility patch:
	- powershell -ExecutionPolicy Bypass -File tools/patch_flutter_web_runtime.ps1
4. Deploy hosting:
	- firebase deploy --only hosting

## Launch Monitoring Checklist (First 24 Hours)
- Keep one terminal on web/runtime logs for the first 2 hours after deploy.
- Watch for repeated routing, auth persistence, and connection errors.
- Spot-check every few hours for recurring stack traces and error spikes.
- If an issue spikes, pause rollout expansion and triage by app version from startup logs.

## Remote Kill Switches
- `enable_live_rooms` (default `true`)
- `enable_messaging` (default `true`)

Behavior:
- Local defaults are `true` so development remains fully enabled.
- Remote Config can override both flags at runtime.
- Feature gating is applied at route entry points for graceful shutdown (`/room/*`, `/live`, `/rooms`, `/create-room`, `/messages*`, `/friends`, `/whisper`).

## Operational Smoke Checks
- Toggle `enable_live_rooms=false` remotely and verify `/room/:id` and `/live` redirect safely.
- Toggle `enable_messaging=false` remotely and verify `/messages` redirects safely.
- Trigger 5 identical errors within 10 minutes and verify one escalation event is logged.
- Open hidden operational overlay (top-left long press or 6 taps within 3 seconds) and confirm version/environment/user/last-error values.

## Web Stability Notes
- Hosting rewrites are configured in firebase.json to route all paths to /index.html.
- Entry boot script is now stable and no longer force-clears browser caches every load.
- Cache-control headers are configured for index/bootstrap/service worker in firebase.json.

## Tests
Run focused tests:
- flutter test test/app_router_redirect_test.dart
- flutter test test/room_service_test.dart

Run Firestore rules verification:
- npm --prefix functions run test:rules
- pwsh -File tools/run_firestore_rules_tests.ps1

Run launch load harness (room + payment replay/idempotency):
- pwsh -File tools/run_launch_load_harness.ps1 -Cycles 3 -PressureRepeatsPerCycle 1 -Shuffle
- pwsh -File tools/run_launch_load_harness.ps1 -Cycles 2 -PressureRepeatsPerCycle 1 -IncludeRulesValidation

CI launch gate profiles:
- PR/Push: blocking lightweight profile (`Cycles=1`, `PressureRepeatsPerCycle=0`)
- Nightly/manual: deeper pressure profile with rules validation (`Cycles=3`, `PressureRepeatsPerCycle=1`, `-IncludeRulesValidation`)

Run full suite:
- flutter test

## Key Project Docs
- MIXVY_PRODUCT_AUDIT_2026-03-29.md
- MIXVY_AUDIT_SUMMARY.md
- ONBOARDING.md

## Current Product Audit Direction
- Apple Sign In is intentionally deferred until web behavior is validated and stable in production.
- Current priority is web reliability, safety hardening, and account-control completion.
