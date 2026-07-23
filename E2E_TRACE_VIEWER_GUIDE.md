# E2E Test Debugging: Trace Viewer Guide

**Purpose:** When a test fails, Playwright captures a `.trace` file with full forensic data. This guide teaches you how to use it.

---

## 📋 Quick Reference: What Each Test Does

| Test | Duration | What It Tests | Common Failures |
|------|----------|----------------|-----------------|
| **01-Setup-Navigation** | 3-5s | Auth + room list load | Login selector wrong, page doesn't render |
| **02-Feature-Join** | 5-10s | Room join flow + player | Video player not found, URL doesn't change |
| **03-Resilience** | 10s | Network stability | Network errors during monitoring, requests timeout |
| **04-Error-Tracking** | 2-3s | Diagnostic logs | [MIXVY_DEBUG] logs not appearing |

---

## 🎬 How to Read a Trace File

### Step 1: Locate Your Trace File

After a test fails, you'll find traces here:

```
test-results/
├── artifacts/
│   ├── 01-Setup-Navigation-chromium.trace
│   ├── 02-Feature-Join-chromium.trace
│   ├── 03-Resilience-chromium.trace
│   └── 04-Error-Tracking-chromium.trace
│   
├── videos/
│   └── [test-name].webm (video recording)
│   
└── screenshots/
    └── [test-name].png (final state)
```

### Step 2: Open in Trace Viewer

**Option A: Online (Easiest)**

1. Go to: https://trace.playwright.dev/
2. Drag-and-drop your `.trace` file
3. Loads in browser instantly

**Option B: Command Line**

```bash
npx playwright show-trace test-results/artifacts/03-Resilience-chromium.trace
```

### Step 3: Read the Timeline

The trace viewer shows a timeline like this:

```
┌─────────────────────────────────────────────────────┐
│ Timeline View                                       │
├─────────────────────────────────────────────────────┤
│ 0ms    | goto('/')                                  │
│ 450ms  | waitForURL                                 │
│ 500ms  | locator('input[type="email"]').fill()     │
│ 800ms  | locator('button').click()                 │
│ 2300ms | waitForURL('/home')                        │
│ 2350ms | locator('[class*="room"]').click()        │
│ 3200ms | waitForURL('/room/...')                   │
│ 3250ms | locator('[class*="video"]').isVisible()   │
│ 8500ms | ❌ TIMEOUT - connection health badge not found
└─────────────────────────────────────────────────────┘
```

**What you're looking for:**
- ✅ Green checkmarks = successful actions
- ⏱️ Times show how long each action took
- ❌ Red X = where the test failed (usually the last line)

---

## 🔍 Understanding Failures: Common Scenarios

### Scenario 1: "Timeout waiting for selector"

**Example Error:**
```
Timeout 10000ms exceeded waiting for locator('input[type="email"]')
```

**Trace Timeline Shows:**
```
0ms   | goto('/')
450ms | ❌ Timeout waiting for element to appear
```

**What Happened:**
The login page didn't load or the element wasn't where expected.

**Debugging in Trace Viewer:**
1. Click the "Screenshots" tab
2. Look at the snapshots taken during navigation
3. Does the login form appear?
4. If not visible, the selector might be wrong
5. Update the selector in the test and re-run

**Fix:**
```typescript
// Current (broken):
const emailInput = page.locator('input[type="email"]');

// Updated (if wrong class):
const emailInput = page.locator('input[placeholder*="email"]');
```

---

### Scenario 2: "Test fails during Network Resilience (Test 03)"

**Example Error:**
```
Error: Test failed due to 1 console errors and 0 exceptions.
Check trace file for details.
```

**Trace Timeline Shows:**
```
0ms      | navigate to /home
1200ms   | start network monitoring
5300ms   | ⚠️ [CONSOLE ERROR] Failed to connect to WebSocket
7800ms   | request failed: GET /api/connection/health
10000ms  | ❌ Test ends - console error detected
```

**What Happened:**
During the 10-second monitoring window, a network request failed OR a console error occurred. This could be:
- Network connection dropped
- API timeout
- Browser security error
- CORS issue

**Debugging in Trace Viewer:**
1. Click the "Network" tab
2. Look for failed requests (red X)
3. What URL failed? Is it a real error or test environment issue?
4. Click "Console" tab
5. Search for error messages

**What to Look For:**
```
✅ GOOD - Expected network request succeeded:
  GET https://mixvy-v2.web.app/api/connection/health → 200 OK

❌ BAD - Unexpected failure:
  GET https://mixvy-v2.web.app/api/connection/health → 500 Server Error
  
❌ BAD - Console error:
  [Error] Connection timeout after 30s
```

**Fix Options:**
- If timeout: Increase action timeout in playwright.config.ts
- If API error: Check backend logs
- If CORS: Update app's CORS configuration
- If transient: Re-run the test (sometimes network is just slow)

---

### Scenario 3: "Video player not found"

**Example Error:**
```
Timeout 5000ms exceeded waiting for locator('[class*="video"]')
```

**Trace Timeline Shows:**
```
0ms    | navigate to /room/123
500ms  | room page loaded
800ms  | ✅ URL changed correctly
1200ms  | ✅ room data loaded
1500ms  | ❌ Timeout looking for video player element
```

**What Happened:**
The room page loaded, but the video player element wasn't visible within 5 seconds. Could be:
- Video player rendering is delayed
- Video player uses different class name
- Player failed to initialize
- Browser doesn't support WebRTC

**Debugging in Trace Viewer:**
1. Click "DOM Snapshots" tab
2. Look at the HTML structure when player lookup failed
3. Search for "video" or "player" in the DOM
4. What class names do you see?

**Example DOM Snapshot:**
```html
<div class="video-container">
  <div class="webrtc-local-video">
    <!-- Video element here -->
  </div>
</div>
```

**Fix:**
Update the selector in the test:
```typescript
// Original (didn't work):
const videoPlayer = page.locator('[class*="video"]');

// Updated (based on DOM):
const videoPlayer = page.locator('[class*="webrtc"]');
```

---

### Scenario 4: "Connection health badge not found"

**Example Error:**
```
Warning: Connection health "Healthy" badge not found within 15 seconds
```

**Trace Timeline Shows:**
```
0ms     | navigate to /room/123
5000ms  | ✅ player visible
5100ms  | start checking for connection badge
5200ms  | look for [class*="health"]
9800ms  | ❌ badge never appears after 15s
```

**What Happened:**
The health badge element doesn't exist yet, or uses a different name. This is often **not a test failure** – it just means the badge loads very slowly or has a different class name.

**Debugging in Trace Viewer:**
1. Click "DOM Snapshots" tab
2. Search for keywords: "health", "connection", "status"
3. What elements exist in the actual DOM?

**Example DOM Snapshot:**
```html
<div class="connection-indicator">
  <span class="status-badge">Connecting...</span>
</div>
```

**Fix:**
Update the selector in the test:
```typescript
// Original (didn't work):
const connectionBadge = page.locator('[class*="health"]');

// Updated (based on actual DOM):
const connectionBadge = page.locator('[class*="connection"]');
```

---

## 🎥 Using Videos to Debug

When you see a video file (`test-results/artifacts/*.webm`):

1. **Open the video** in your media player
2. **Play from the beginning** to see the full flow
3. **Watch where it stops** - that's where the test failed
4. **Pause and rewind** to see what was on screen

**What to Look For:**
- ✅ Page loaded and rendered correctly
- ✅ Buttons clicked, forms filled
- ✅ Navigation worked
- ❌ Page stayed blank (loading issue)
- ❌ Clicked wrong element
- ❌ Connection attempt failed

---

## 📊 Console & Network Tabs

### Console Tab

**Shows all browser output:**
```
[MIXVY_DEBUG:AgoraService][WARN] Connection lost, starting recovery
[MIXVY_DEBUG:ConnectionHealthCheckService][ERROR] Health check failed
```

**Look for:**
- 🔴 Red errors (unexpected)
- 🟡 Yellow warnings (expected from your app)
- 🔵 Blue info (development logging)

### Network Tab

**Shows all HTTP/WebSocket requests:**

```
GET /api/rooms              200 OK        145ms
GET /api/connection/health  200 OK        89ms
GET /api/connection/health  200 OK        92ms
POST /api/connection/ping   200 OK        156ms
GET /assets/player.js       200 OK        234ms
GET /api/connection/health  500 ERROR     3000ms ← FAILURE
```

**Look for:**
- ✅ Green 2xx status codes (successful)
- 🔴 Red 4xx/5xx status codes (failures)
- ⏱️ Times - are they unusually slow?

---

## 🚀 Pro Tips

### Tip 1: Compare with Video + Trace

**Best practice:** Open video in one window, trace viewer in another
- Video shows what you see
- Trace shows technical details (network, DOM)
- Together they tell the full story

### Tip 2: Check the Metadata

Each action in trace has metadata:

```
Action: click button "Sign In"
Selector: button:has-text("SIGN IN")
Duration: 45ms
Position: (640, 450) on screen
Visibility: visible
Enabled: true
```

**Useful for debugging:**
- Is element in the right position?
- Is it actually visible?
- Is it enabled (clickable)?

### Tip 3: Take Screenshots

Click the "Screenshots" tab to see snapshots taken throughout:
- Before navigation
- After navigation
- Before click
- After click
- At time of failure

This gives a visual walkthrough of test execution.

### Tip 4: Use DevTools

In Trace Viewer, you can actually **inspect the DOM** at any point:
1. Click a step in the timeline
2. Click "Inspect"
3. See the HTML at that moment
4. Useful for finding the right selector

---

## 📝 Troubleshooting Decision Tree

```
Test Failed
    │
    ├─→ Test is still running?
    │   └─→ Wait for it to complete (tests take 20-25s)
    │
    ├─→ Can't find trace file?
    │   └─→ Check: test-results/artifacts/
    │       └─→ Trace only saved on failure
    │       └─→ Success tests don't generate traces
    │
    ├─→ Opening trace fails?
    │   └─→ Try: npx playwright show-trace [file]
    │       └─→ Or upload to https://trace.playwright.dev/
    │
    ├─→ Can't understand the failure?
    │   └─→ Watch the video first
    │       └─→ Then correlate to trace timeline
    │       └─→ Check DOM snapshots
    │
    └─→ Still confused?
        └─→ Check console for [MIXVY_DEBUG] logs
            └─→ Check network requests for failures
                └─→ Run test again (might be transient)
```

---

## 🎓 Real Example: Test 03 Resilience Failure

**Scenario:** Test 03 fails with "console errors detected"

**Your Process:**

1. **Get the trace file:**
   ```bash
   ls test-results/artifacts/ | grep Resilience
   # Output: 03-Resilience-chromium.trace
   ```

2. **Open in Trace Viewer:**
   ```bash
   npx playwright show-trace test-results/artifacts/03-Resilience-chromium.trace
   ```

3. **Look at Timeline:**
   - See that test ran 0-10 seconds
   - Last action: "monitoring network activity"
   - About 7 seconds in: A request failed

4. **Click Network Tab:**
   - Find the failed request: `GET /api/connection/health → 500 Server Error`
   - This is what triggered the test failure

5. **Check Console Tab:**
   - See: `[MIXVY_DEBUG:ConnectionHealthCheckService][ERROR] Health check failed`
   - This is the ERROR-level log that was captured

6. **Decision:**
   - Is this expected? (App normally recovers from transient errors)
   - Or unexpected? (Backend issue)
   - Re-run test to see if it's transient or consistent

7. **Action:**
   - If transient: Increase timeout in playwright.config.ts
   - If consistent: Check backend logs
   - If app issue: Fix the app and re-run

---

## ✅ Next Steps

1. **Run a test locally:** `npm run test:e2e:headed`
2. **Intentionally break something** (comment out an assert)
3. **Observe the failure:** What does it look like?
4. **Open the trace:** What technical details do you see?
5. **Read the video:** Does it match your expectations?
6. **Fix the test:** Re-enable the assert and re-run

**By doing this once manually, you'll understand all future traces!**
