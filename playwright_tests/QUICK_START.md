# MIXVY Phase 2 Playwright Test Quick Start
## PowerShell Commands & Usage Examples

---

## 🚀 **IMMEDIATE NEXT STEPS**

### **1. Install & Setup** (Do this once)

```powershell
# Navigate to test directory
cd c:\Users\LARRY\MIXVY\playwright_tests

# Install dependencies
npm install

# Install Playwright browsers
npx playwright install

# Verify installation
npx playwright --version
```

**Expected output:**
```
Version 1.46.0 (or similar)
```

---

## 🎮 **RUN TESTS FROM POWERSHELL**

### **Command 1: Run All Tests (Recommended for first-time)**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests
npm test
```

**Output:**
- Runs 9 test scenarios
- Duration: ~90 seconds
- Generates test-results/ folder with HTML report + trace files

### **Command 2: Run Phase 2 Tests Only**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests
npm run test:phase2
```

**Equivalent to:**
```powershell
npx playwright test tests/phase2-luxury-animations.spec.ts
```

### **Command 3: Run in Headed Mode** (watch test execute)

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests
npm run test:headed
```

Browser window opens showing:
- Login
- Room navigation
- Animation elements
- Test assertions

### **Command 4: Run in Debug Mode** (step through)

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests
npm run test:debug
```

Opens Playwright Inspector:
- Step through actions
- Inspect elements
- Modify selectors in real-time
- See performance data

### **Command 5: Run on Specific Browser**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Chrome (fastest)
npm run test:chrome

# Firefox
npx playwright test --project=firefox

# Safari (macOS only)
npx playwright test --project=webkit
```

### **Command 6: View Test Results**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Open HTML report + traces
npm run trace:view

# Opens browser showing:
# - Test status
# - Screenshots
# - Video recordings
# - Trace files for each test
```

### **Command 7: View Specific Trace File**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Open trace viewer for performance metrics
npx playwright show-trace test-results/performance-baseline-trace.zip

# Open trace for host shimmer animation
npx playwright show-trace test-results/host-shimmer-trace.zip
```

---

## 📊 **EXPECTED TEST FLOW**

When you run `npm test`, here's what happens:

```
1. Setup: Create and join live room
   └─ Creates test room (5s)
   └─ Generates: setup-trace.zip

2. OnMicPanel: Component visibility
   └─ Verifies "ON STAGE" header (5s)
   └─ Generates: onmic-panel-trace.zip

3. Host Gold Shimmer: 3s animation
   └─ Records host frame animation (10s)
   └─ Generates: host-shimmer-trace.zip

4. Speaker Wine Glow: 600ms pulse
   └─ Records speaker glow animation (5s)
   └─ Generates: speaker-glow-trace.zip

5. Spotlight: Enhanced glow
   └─ Verifies spotlight visible (5s)
   └─ Generates: spotlight-glow-trace.zip

6. Responsiveness: State changes
   └─ Tests animation reactions (10s)
   └─ Generates: responsiveness-trace.zip

7. Multi-Participant: 10+ users
   └─ Simulates multiple users (20s)
   └─ Generates: multi-participant-trace.zip

8. Cross-Browser: Chrome/Firefox/Safari
   └─ Tests consistency (15s)
   └─ Generates: cross-browser-*-trace.zip files

9. Colors: Brand accuracy
   └─ Validates #D4AF37 and #9B2535 (5s)
   └─ Generates: color-accuracy-trace.zip

10. Performance: Baseline metrics
    └─ Records performance data (10s)
    └─ Generates: performance-baseline-trace.zip

Total Duration: ~90-120 seconds
Output: test-results/ folder with HTML report + 10 trace files
```

---

## 🔧 **CUSTOMIZING FROM POWERSHELL**

### **Run Specific Test by Name**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Run only animation tests
npx playwright test --grep "Animation"

# Run only multi-participant test
npx playwright test --grep "Multi-Participant"

# Run everything except setup
npx playwright test --grep-invert "Setup"
```

### **Run with Verbose Logging**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Enable debug logging
$env:DEBUG = "pw:api"
npm test

# Clear environment after
Remove-Item Env:\DEBUG
```

### **Run Tests with Custom Timeout**

Edit `playwright.config.ts` and change:
```typescript
use: {
  actionTimeout: 30000,      // Increase from 15000
  navigationTimeout: 60000,  // Increase from 30000
}
```

Then:
```powershell
npm test
```

---

## 📈 **ANALYZING RESULTS**

### **1. Check Test Status**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# View test results file
cat test-results\test-results.json | Select-Object -First 50
```

### **2. Open HTML Report**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Opens detailed report in browser
npm run trace:view
```

Report shows:
- ✅ PASSED / ❌ FAILED status
- Screenshots of each test
- Video recordings (if enabled)
- Detailed logs

### **3. Analyze Performance Trace**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# View performance baseline trace
npx playwright show-trace test-results\performance-baseline-trace.zip
```

Trace Viewer shows:
- Network timeline
- DOM snapshots
- Animation frames
- Performance metrics

---

## 🐛 **TROUBLESHOOTING FROM POWERSHELL**

### **Issue: "npm: command not found"**

```powershell
# Check if Node is installed
node --version

# If not installed:
# Download from https://nodejs.org
# Install Node.js (includes npm)
# Restart PowerShell
```

### **Issue: "Cannot find module @playwright/test"**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Reinstall dependencies
rm -r node_modules
npm install

# Then run tests
npm test
```

### **Issue: "Playwright browsers not found"**

```powershell
cd c:\Users\LARRY\MIXVY\playwright_tests

# Install browsers
npx playwright install

# Verify installation
npx playwright install --with-deps
```

### **Issue: "Timeout waiting for element"**

```powershell
# Run in debug mode to inspect
npm run test:debug

# Or run headed to see browser
npm run test:headed
```

---

## 🎯 **INTEGRATION WITH YOUR WORKFLOW**

### **Add PowerShell Function for Easy Execution**

```powershell
# Add to your PowerShell profile
function Invoke-PlaywrightTests {
    param(
        [ValidateSet('all', 'phase2', 'headed', 'debug', 'chrome')]
        [string]$Mode = 'all'
    )
    
    Push-Location c:\Users\LARRY\MIXVY\playwright_tests
    
    switch ($Mode) {
        'all' { npm test }
        'phase2' { npm run test:phase2 }
        'headed' { npm run test:headed }
        'debug' { npm run test:debug }
        'chrome' { npm run test:chrome }
    }
    
    Pop-Location
}

# Usage:
Invoke-PlaywrightTests -Mode headed
```

### **Create CI/CD-Ready Script**

```powershell
# File: C:\Users\LARRY\MIXVY\run-qa-tests.ps1
param(
    [string]$Environment = "production",
    [string]$BrowserProject = "chromium"
)

Write-Host "🎯 Starting Phase 2 Playwright QA Tests"
Write-Host "Environment: $Environment"
Write-Host "Browser: $BrowserProject"

Set-Location c:\Users\LARRY\MIXVY\playwright_tests

# Install dependencies
npm install --silent

# Install browsers
npx playwright install --with-deps

# Run tests
if ($BrowserProject -eq "all") {
    npm test
} else {
    npx playwright test --project=$BrowserProject
}

# Save results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item -Path "test-results" -Destination "test-results_$timestamp" -Recurse

Write-Host "✅ Tests complete. Results saved to: test-results/"
Write-Host "📊 View report: npm run trace:view"

Set-Location c:\Users\LARRY\MIXVY
```

**Usage:**
```powershell
# Run tests
.\run-qa-tests.ps1

# Run tests on Firefox
.\run-qa-tests.ps1 -BrowserProject firefox

# Run all browsers
.\run-qa-tests.ps1 -BrowserProject all
```

---

## 📋 **QUICK REFERENCE COMMAND LIST**

```powershell
# Setup (one-time)
cd c:\Users\LARRY\MIXVY\playwright_tests
npm install
npx playwright install

# Run tests
npm test                                    # All tests (recommended)
npm run test:phase2                         # Phase 2 only
npm run test:headed                         # Watch in browser
npm run test:debug                          # Debug/step-through
npm run test:chrome                         # Chrome only

# View results
npm run trace:view                          # View all results
npx playwright show-trace test-results\*.zip # View specific trace

# Cleanup
rm -r test-results                          # Delete results
rm -r node_modules                          # Reinstall if corrupted
```

---

## ✅ **SUCCESS CHECKLIST**

After running tests, verify:

- [ ] All tests completed without hanging
- [ ] test-results/ folder created
- [ ] HTML report opens without errors
- [ ] Trace files can be viewed
- [ ] Performance metrics recorded
- [ ] Cross-browser tests passed
- [ ] Animation elements detected
- [ ] No console errors in traces

---

## 🎤 **NOW YOU'RE READY!**

Choose your command and run it:

```powershell
# Most common - run all tests and see results
cd c:\Users\LARRY\MIXVY\playwright_tests
npm test
npm run trace:view
```

**Questions during execution? Paste any error messages here, and I'll help troubleshoot.** 🎤✨
