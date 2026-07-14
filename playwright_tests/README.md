# MIXVY Phase 2 Playwright Test Automation
## E2E Testing & Performance Tracing Guide

---

## 📋 **OVERVIEW**

This Playwright test suite automates validation of the Phase 2 "Luxury Lounge" animations:

✅ **OnMicPanel** component visibility and state changes  
✅ **Host Gold Shimmer** 3-second animation cycle  
✅ **Speaker Wine-Red Glow** 600ms pulse animations  
✅ **Spotlight Ambient Glow** enhanced rendering  
✅ **Cross-browser** animation consistency (Chrome, Firefox, Safari)  
✅ **Performance metrics** baseline recording  
✅ **Trace files** for Playwright Trace Viewer analysis  

---

## 🚀 **QUICK START**

### **1. Install Playwright & Dependencies**

```powershell
# Navigate to test directory
cd c:\Users\LARRY\MIXVY\playwright_tests

# Install Node dependencies
npm install

# Install Playwright browsers (run once)
npx playwright install
```

### **2. Configure Test Credentials** (IMPORTANT)

Before running tests, update `helpers/auth-helpers.ts` with your test account credentials:

```typescript
export const TEST_CREDENTIALS = {
  host: {
    email: 'your-host-email@mixvy-qa.local',
    password: 'YourSecurePassword123!',
  },
  // ... other accounts
};
```

**Best Practice**: Store credentials in environment variables instead of code:

```powershell
# Set environment variables (PowerShell)
$env:MIXVY_TEST_HOST_EMAIL = "test-host@mixvy-qa.local"
$env:MIXVY_TEST_HOST_PASSWORD = "TestPassword123!"
```

Then update helpers to read from environment:

```typescript
export const TEST_CREDENTIALS = {
  host: {
    email: process.env['MIXVY_TEST_HOST_EMAIL'] || 'test-host@mixvy-qa.local',
    password: process.env['MIXVY_TEST_HOST_PASSWORD'] || 'TestPassword123!',
  },
};
```

---

## 🎮 **RUNNING TESTS**

### **Option 1: Run All Tests**

```powershell
# Navigate to test directory
cd c:\Users\LARRY\MIXVY\playwright_tests

# Run all tests with tracing enabled
npm test

# Output: test-results/ folder with HTML report + trace files
```

### **Option 2: Run Phase 2 Animation Tests Only**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Run specific test file
npm run test:phase2

# Equivalent to:
# npx playwright test tests/phase2-luxury-animations.spec.ts
```

### **Option 3: Run Tests in Headed Mode** (see browser)

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

npm run test:headed

# Browser window opens showing test execution
# Useful for visual validation during development
```

### **Option 4: Run Tests in Debug Mode**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

npm run test:debug

# Opens Playwright Inspector
# Step through tests, inspect elements, modify selectors
```

### **Option 5: Run Tests on Specific Browser**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Chrome only
npm run test:chrome

# Equivalent commands:
# npx playwright test --project=chromium
# npx playwright test --project=firefox
# npx playwright test --project=webkit
```

### **Option 6: Run from Project Root** (Recommended for CI)

```powershell
# From C:\Users\LARRY\MIXVY directory
cd c:\Users\LARRY\MIXVY

# Run Playwright tests from root
npm --prefix playwright_tests test

# Or create a PowerShell function for convenience:
function Run-PlaywrightTests {
    param([string]$suite = "phase2")
    cd c:\Users\LARRY\MIXVY\playwright_tests
    npm run "test:$suite"
    cd ..
}

# Usage:
Run-PlaywrightTests -suite phase2
```

---

## 📊 **VIEWING TEST RESULTS**

### **HTML Test Report**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Open HTML report in browser
npx playwright show-report

# Report includes:
# - Test status (PASSED / FAILED)
# - Screenshots on failure
# - Video recordings
# - Detailed logs
```

### **Trace Files** (Performance Analysis)

Playwright generates `.zip` trace files in `test-results/`:

```
test-results/
├── setup-trace.zip
├── onmic-panel-trace.zip
├── host-shimmer-trace.zip
├── speaker-glow-trace.zip
├── spotlight-glow-trace.zip
├── responsiveness-trace.zip
├── multi-participant-trace.zip
├── cross-browser-chromium-trace.zip
├── color-accuracy-trace.zip
└── performance-baseline-trace.zip
```

**View trace file:**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# View specific trace
npm run trace:view -- test-results/host-shimmer-trace.zip

# Or directly:
npx playwright show-trace test-results/host-shimmer-trace.zip
```

**Trace viewer shows:**
- Screenshot timeline of test execution
- Network requests
- DOM snapshots
- Action replay
- Performance metrics

---

## 🔍 **DEBUGGING FAILED TESTS**

### **Common Issues & Solutions**

#### **Issue: "Sign-in failed - element not found"**

```powershell
# Run in debug/headed mode to see UI
npm run test:debug

# In Playwright Inspector:
# 1. Inspect auth page
# 2. Verify email/password input selectors
# 3. Update selectors in auth-helpers.ts if needed
```

#### **Issue: "Room join timeout"**

```powershell
# Increase timeout in playwright.config.ts
use: {
  navigationTimeout: 60000,  // Increase from 30000
}

# Or run specific test with verbose logging:
npx playwright test --debug tests/phase2-luxury-animations.spec.ts
```

#### **Issue: "Animation not detected"**

```powershell
# Run in headed mode to visually inspect
npm run test:headed

# Check if:
# 1. Animation controller is active
# 2. AnimatedBuilder is rendering
# 3. FPS is 60 (not throttled)
```

#### **Issue: Tests passing locally but failing in CI**

```powershell
# Add trace recording (already enabled by default)
# Traces capture full test execution for debugging

# Use screenshot on failure to see state at error:
use: {
  screenshot: 'only-on-failure',
  video: 'retain-on-failure',
}
```

---

## 📈 **PERFORMANCE ANALYSIS WORKFLOW**

### **Step 1: Run Performance Baseline Test**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Run only performance test
npx playwright test --grep "Performance"

# Generates: test-results/performance-baseline-trace.zip
```

### **Step 2: Open Trace File**

```powershell
npx playwright show-trace test-results/performance-baseline-trace.zip
```

### **Step 3: Analyze Timeline**

In Playwright Trace Viewer:
1. **Network tab** - Check Agora RTC token requests
2. **Timeline** - Observe animation frames
3. **Snapshots** - View DOM at each animation frame
4. **Actions** - Replay user interactions

### **Step 4: Export Data**

```powershell
# Convert trace to JSON for analysis
npx playwright show-trace test-results/performance-baseline-trace.zip --json
```

---

## 🎯 **TEST SCENARIOS COVERED**

| Test | Validates | Duration | Pass Criteria |
|------|-----------|----------|---------------|
| **OnMicPanel** | Component visibility | 5s | Element visible |
| **Host Shimmer** | 3s gold animation cycle | 10s | Animation detected |
| **Speaker Glow** | 600ms wine-red pulse | 5s | Animation detected |
| **Spotlight** | Enhanced ambient glow | 5s | Component visible |
| **Responsiveness** | State change animations | 10s | Status updates |
| **Multi-Participant** | 10+ participants, smooth animations | 20s | FPS stable |
| **Cross-Browser** | Chrome/Firefox/Safari consistency | 15s | Render consistent |
| **Colors** | Brand color accuracy | 5s | Colors present |
| **Performance** | Baseline metrics | 10s | TTI < 10s |

**Total runtime:** ~90 seconds (single browser)

---

## 🔧 **ADVANCED USAGE**

### **Run Tests with Custom Configuration**

```powershell
# Run with specific project (browser)
npx playwright test --project=firefox

# Run with custom trace output
npx playwright test --trace=on

# Run with workers (parallel execution - not recommended for this suite)
npx playwright test --workers=4

# Run with reporter (JSON output)
npx playwright test --reporter=json > test-results.json
```

### **Filter Tests by Name**

```powershell
# Run only animation-related tests
npx playwright test --grep "Animation"

# Run only multi-participant tests
npx playwright test --grep "Multi-Participant"

# Run everything except setup
npx playwright test --grep-invert "Setup"
```

### **Run with Environment Variables**

```powershell
# Set test credentials
$env:MIXVY_TEST_HOST_EMAIL = "host@mixvy-qa.local"
$env:MIXVY_TEST_HOST_PASSWORD = "password123"

# Run tests
npx playwright test
```

---

## 📋 **TEST MAINTENANCE**

### **Update Selectors When UI Changes**

If animations change UI structure, update selectors in `helpers/auth-helpers.ts`:

```typescript
// Old selector (broken)
const onMicPanel = page.locator('[data-testid="on-mic-panel"]');

// New selector (if data-testid changed)
const onMicPanel = page.locator('text=ON STAGE').locator('..');
```

### **Add New Tests**

Create new test files in `tests/` directory:

```typescript
import { test, expect } from '@playwright/test';

test('New Phase 2 animation test', async ({ page, context }) => {
  await context.tracing.start({ screenshots: true });
  
  // Test implementation
  
  await context.tracing.stop({ path: 'test-results/new-test-trace.zip' });
});
```

### **Update Test Data**

Modify test credentials in `helpers/auth-helpers.ts`:

```typescript
export const TEST_CREDENTIALS = {
  // Add new test account
  newRole: {
    email: 'test-newrole@mixvy-qa.local',
    password: 'TestPassword123!',
  },
};
```

---

## 📊 **INTEGRATION WITH CI/CD**

### **GitHub Actions Example**

```yaml
# .github/workflows/playwright-tests.yml
name: Playwright Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - name: Install dependencies
        run: npm install
        working-directory: playwright_tests
      
      - name: Install Playwright browsers
        run: npx playwright install --with-deps
        working-directory: playwright_tests
      
      - name: Run tests
        run: npm test
        working-directory: playwright_tests
        env:
          MIXVY_TEST_HOST_EMAIL: ${{ secrets.MIXVY_TEST_HOST_EMAIL }}
          MIXVY_TEST_HOST_PASSWORD: ${{ secrets.MIXVY_TEST_HOST_PASSWORD }}
      
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright_tests/test-results/
```

---

## 🎤 **QUICK REFERENCE COMMANDS**

```powershell
# Setup (one-time)
npm install
npx playwright install

# Run tests
npm test                           # All tests
npm run test:phase2                # Phase 2 only
npm run test:headed                # See browser
npm run test:debug                 # Debug mode
npm run test:chrome                # Chrome only

# View results
npm run trace:view                 # HTML report + traces
npx playwright show-report         # HTML report only

# Cleanup
rm -r test-results                 # Delete old results
rm -r node_modules                 # Reinstall deps if issues
```

---

## ✅ **BEST PRACTICES**

1. **Always use trace files** for debugging - they're invaluable
2. **Run headed mode** when adding new tests
3. **Update selectors** before running if UI changes
4. **Set credentials via environment variables** (never hardcode in prod)
5. **Run cross-browser tests** before Phase 3 deployment
6. **Archive traces** from successful test runs for comparison
7. **Run locally first** before pushing to CI/CD

---

## 📞 **TROUBLESHOOTING MATRIX**

| Symptom | Cause | Solution |
|---------|-------|----------|
| Tests hang on auth page | Selector mismatch | Run debug mode, inspect elements |
| "Timeout waiting for element" | Element not in DOM | Increase timeout, check selectors |
| Animation not detected | Animation disabled or not triggering | Run headed mode, verify FPS |
| Tests pass locally, fail in CI | Environment difference | Add environment variable setup in CI |
| Trace viewer won't open | Trace file corrupted | Re-run test to generate new trace |

---

**Ready to run automated QA? Execute: `npm --prefix playwright_tests test`** 🎤✨
