# MixVy E2E Testing Suite

Automated end-to-end testing for the MixVy production app at `https://mixvy-v2.web.app` using Playwright.

## Overview

This suite provides **comprehensive production validation** with:
- ✅ 4 critical test scenarios (auth, room join, resilience, error tracking)
- ✅ Global error tracking (console errors, JS exceptions)
- ✅ Automatic diagnostics (videos, traces, screenshots on failure)
- ✅ CI/CD ready (GitHub Actions workflow included)
- ✅ Interactive UI mode for visual debugging

## Quick Start

### 1. Setup Test Credentials

Create `.env.local` in the project root:

```bash
cp .env.example .env.local
```

Edit `.env.local` and add your test account credentials:

```env
TEST_EMAIL=test-account@gmail.com
TEST_PASSWORD=your-secure-password
```

⚠️ **Important**: Create a dedicated test account. Do NOT use your personal account, as failed tests may alter test state.

### 2. Install Dependencies

```bash
npm install
```

### 3. Run Tests

#### **Interactive UI Mode (Best for First Run)**

```bash
npm run test:e2e:ui
```

This opens an interactive browser where you can:
- Watch tests execute in real-time
- Step through individual tests
- Inspect DOM snapshots
- See network activity and console logs

#### **Headless Mode (For CI/CD)**

```bash
npm run test:e2e
```

Tests run without a visible browser, suitable for automated pipelines.

#### **Visible Browser (Debugging)**

```bash
npm run test:e2e:headed
```

Run tests with a visible browser window for manual observation.

#### **Debug Mode (Step-Through)**

```bash
npm run test:e2e:debug
```

Step through tests one action at a time using the Playwright debugger.

### 4. View Results

```bash
npm run report:e2e
```

Opens an interactive HTML report showing all test results, failures, videos, and traces.

## Test Scenarios

### Test 1: Setup Navigation
**File:** `tests/e2e_production.spec.ts` - `01-Setup-Navigation`

Validates:
- Login with test credentials
- Navigation to home page
- Room list renders
- At least one room card is visible

**Why it matters**: Confirms basic authentication and page rendering work.

---

### Test 2: Room Join Flow (Most Critical)
**File:** `tests/e2e_production.spec.ts` - `02-Feature-Join`

Validates:
- Click room card → Navigate to room page
- URL changes correctly
- Video player element appears
- Connection health badge shows "Healthy"

**Why it matters**: This is the primary user journey. If it fails, users can't join rooms.

---

### Test 3: Connection Resilience
**File:** `tests/e2e_production.spec.ts` - `03-Resilience`

Validates:
- 10-second network activity monitoring
- No request failures during monitoring window
- App remains responsive

**Why it matters**: Catches network stability issues and connection drops.

---

### Test 4: Error Tracking
**File:** `tests/e2e_production.spec.ts` - `04-Error-Tracking`

Validates:
- `[MIXVY_DEBUG]` diagnostic logs are captured
- DiagnosticLogger integration is active
- Console logging is functioning

**Why it matters**: Confirms that your monitoring infrastructure (Crashlytics integration) is working.

## Understanding Test Failures

When a test fails, Playwright automatically saves diagnostics:

### Trace Files (Most Useful)

Located in `test-results/artifacts/*.trace`

**View in Trace Viewer:**

```bash
npx playwright show-trace test-results/artifacts/02-Feature-Join-chromium.trace
```

Or drag the `.trace` file to https://trace.playwright.dev/

**What you'll see:**
- 🎬 Full timeline of all browser actions
- 🔍 DOM snapshots at each step
- 📡 Network requests and responses
- 📋 Console logs and errors
- ⏱️ Exact timing of each action

### Video Recordings

Located in `test-results/artifacts/*.webm`

Visual record of test execution. Shows exactly where the test stopped and what the screen looked like.

### Screenshots

Located in `test-results/artifacts/*.png`

Snapshot of the page at the moment of failure.

## Global Error Tracking

Tests automatically fail if any of these occur:

```typescript
❌ console.error() is logged
❌ Uncaught JavaScript exception
❌ Network request fails
❌ Navigation timeout (30s)
❌ Action timeout (15s)
```

This means **invisible bugs won't hide**. If your app "feels broken" to a user but looks okay on initial load, the tests will catch it.

## Customizing Selectors

The tests use flexible selectors to adapt to your UI:

```typescript
const roomCards = page.locator('[class*="room" i], [class*="card" i]');
const videoPlayer = page.locator('[class*="video" i], [class*="player" i], video');
const connectionBadge = page.locator('[class*="health" i], [class*="connection" i]');
```

If selectors don't match your actual HTML:

1. Open `tests/e2e_production.spec.ts`
2. Find the failing selector
3. Update to match your actual class names or data attributes
4. Re-run tests: `npm run test:e2e:ui`

## CI/CD Integration

### GitHub Actions Workflow

The project includes `.github/workflows/e2e-tests.yml` which automatically:

1. ✅ Runs tests on every push to `main` and `develop`
2. ✅ Runs tests on every pull request
3. ✅ Runs daily health check at 9 AM UTC
4. ✅ Uploads test reports and artifacts
5. ✅ Comments on PR with test status

### Setup Instructions

1. **Add Repository Secrets**
   - Go to: Settings → Secrets and variables → Actions
   - Add `TEST_EMAIL` and `TEST_PASSWORD`
   - These values will be used by GitHub Actions

2. **Commit Workflow**
   ```bash
   git add .github/workflows/e2e-tests.yml
   git commit -m "ci: Add E2E test automation workflow"
   git push origin main
   ```

3. **Watch It Run**
   - Go to: Actions tab on GitHub
   - Tests will run automatically on next push

### Expected GitHub Actions Output

**On Success:**
```
✓ 01-Setup-Navigation: Login and view Live Rooms (3.2s)
✓ 02-Feature-Join: Click room, verify URL, check player... (5.8s)
✓ 03-Resilience: Connection state monitoring (11.2s)
✓ 04-Error-Tracking: Verify DiagnosticLogger integration (2.5s)

4 passed (22.7s)
```

**On Failure:**
```
✗ 02-Feature-Join: Click room, verify URL, check player...
   Error: Connection health "Healthy" badge not found within 15 seconds
   
   📊 Artifacts:
   - test-results/artifacts/02-Feature-Join-chromium.trace
   - test-results/artifacts/02-Feature-Join-chromium.webm
   - test-results/artifacts/02-Feature-Join-chromium.png
```

## Best Practices

### 1. Run Locally Before Pushing

```bash
npm run test:e2e
```

Catch issues locally before they reach CI/CD.

### 2. Review Failures Carefully

If a test fails:
1. Open the trace file in Trace Viewer
2. Check the exact step where it failed
3. Look at network requests (was API call blocked?)
4. Check console logs (any errors?)

### 3. Keep Test Account in Good State

- Keep test account logged in
- Ensure test account has basic profile (avatar, username)
- Ensure at least 1 room exists for room join tests

### 4. Monitor CI/CD Results

Check GitHub Actions regularly:
- ✅ All tests passing = app is healthy
- ❌ Some tests failing = investigate immediately
- ⚠️ Flaky tests (sometimes pass/fail) = check network/timing

## Troubleshooting

### Tests timeout waiting for login

**Problem:** `Error: Timeout waiting for selector 'input[type="email"]'`

**Solution:**
- Check if login page structure changed
- Update email input selector in test file
- Verify test account exists and is accessible

### Video player not found

**Problem:** `Error: Video player element is visible` fails

**Solution:**
- Check if your video player uses different HTML structure
- Update selector: `page.locator('[class*="video" i]')`
- Look at actual page HTML using browser dev tools

### Connection health badge not found

**Problem:** `Warning: Connection health "Healthy" badge not found`

**Solution:**
- Check if health badge uses different naming
- Update selector: `page.locator('[class*="health" i]')`
- Verify connection logic is implemented in your app

### Tests fail only in CI/CD but pass locally

**Problem:** `Tests pass locally but fail in GitHub Actions`

**Solution:**
- Check if test credentials are correct (update secrets)
- Add `--headed` flag to see what's happening
- Upload artifacts to debug: artifacts are saved automatically
- Check timezone or time-based conditions

## File Structure

```
.github/workflows/
├── e2e-tests.yml          # GitHub Actions workflow

tests/
├── e2e_production.spec.ts # Main test suite

playwright.config.ts        # Configuration
package.json               # Test scripts
.env.example              # Credentials template
```

## Advanced Usage

### Run Specific Test

```bash
npm run test:e2e -- --grep "Room Join"
```

### Run with Custom Config

```bash
npm run test:e2e -- --project chromium --workers 4
```

### Generate Trace Report

```bash
npm run test:e2e -- --trace on
```

### Verbose Logging

```bash
DEBUG=pw:api npm run test:e2e
```

## Monitoring Your Production App

The E2E tests are your **automated health monitor**:

- **Weekly runs** catch regressions early
- **Trace files** provide forensic evidence of failures
- **Global error tracking** catches invisible bugs
- **Connection resilience tests** verify network stability
- **Diagnostic logging** confirms monitoring infrastructure

## Next Steps

1. ✅ Run tests locally: `npm run test:e2e:ui`
2. ✅ Review test report: `npm run report:e2e`
3. ✅ Add secrets to GitHub
4. ✅ Push to main branch
5. ✅ Watch CI/CD run automatically

Your production app is now **professionally tested** and **continuously validated**. 🚀
