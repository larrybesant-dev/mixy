# 🚀 MixVy Production Monitoring - Controlled Failure Test Playbook

**Date:** July 15, 2026  
**Status:** Ready to Execute  
**Estimated Duration:** 15 minutes

---

## 📋 What You'll Do Today

You're going to **verify your entire monitoring system works end-to-end** by deliberately triggering test alerts. This is called a "controlled failure test" and it's essential for production systems.

Think of it like a **fire drill for your monitoring**:
- You test the alert system WITHOUT breaking the real app
- You verify emails are being delivered
- You practice using the debugging tools
- Everything is documented for future reference

---

## ⏱️ Timeline: What Happens in Real Time

```
TIME    | YOU DO                          | SYSTEM DOES
────────┼─────────────────────────────────┼─────────────────────────────
T+0s    | Click "Test WARNING" button     | App logs to DiagnosticLogger
T+1s    | App shows snackbar              | Log sent to Crashlytics
T+5s    | Wait...                         | Log appears in Cloud Logging
T+30s   | Check Cloud Alerting            | Alert policy evaluates log
T+45s   | Still waiting...                | Incident created (status: Firing)
T+60s   | Check Gmail                     | Email notification sent
T+120s  | Receive email                   | ✓ Alert pipeline verified!
T+300s  | (5 minutes later)               | Incident auto-resolves
```

---

## 🎯 Three-Part Test Plan

### Part 1: Trigger Diagnostic Alerts (5 minutes)

**Objective:** Verify logs flow from app → Crashlytics → Cloud Logging → Alerts → Email

**What you'll do:**
1. Add test code to your LiveRoomScreen
2. Run the app: `flutter run -d chrome`
3. Click test buttons: WARNING → ERROR → CRITICAL
4. Watch the pipeline in real-time

**What you'll verify:**
- ✅ App captures log correctly
- ✅ Crashlytics shows the log entry
- ✅ Cloud Logging displays the severity tag
- ✅ Email arrives in Gmail

**Files to Reference:**
- `CONTROLLED_FAILURE_TEST.md` ← Start here!

---

### Part 2: Run E2E Tests Locally (10 minutes)

**Objective:** Verify Playwright tests run correctly and produce valid diagnostic artifacts

**What you'll do:**
1. Run: `npm run test:e2e:ui`
2. Watch the interactive test runner
3. See all 4 tests execute
4. View the HTML report

**What you'll verify:**
- ✅ Tests run against production app (mixvy-v2.web.app)
- ✅ All 4 test scenarios pass (or fail with clear diagnostics)
- ✅ Videos/traces saved on failure
- ✅ Test pipeline works before GitHub Actions runs it

**Files to Reference:**
- `tests/README.md` ← Testing guide
- `E2E_TRACE_VIEWER_GUIDE.md` ← Debugging guide

---

### Part 3: Monitor Alert Latency (5 minutes)

**Objective:** Verify email notification channel is working and not throttled

**What you'll do:**
1. Watch the incident go from "Firing" → "Resolved"
2. Note the exact timestamps
3. Calculate end-to-end latency
4. Verify email wasn't throttled or blocked

**What you'll verify:**
- ✅ Alert fires within 30 seconds of log
- ✅ Email sent within 1-2 minutes
- ✅ Email appears in inbox (not spam)
- ✅ Incident auto-resolves after 5 minutes
- ✅ Rate limiting working correctly (1 email per hour)

**Files to Reference:**
- `ALERT_LATENCY_MONITORING.md` ← Monitoring guide

---

## 🔥 START HERE: Part 1 - Trigger Diagnostic Alerts

### Step 1: Prepare Your Code

Open `CONTROLLED_FAILURE_TEST.md` (in your project root)

This file contains:
- ✅ Code Block 1: How to add DiagnosticLogger mixin
- ✅ Code Block 2: How to add UI buttons for testing
- ✅ Code Block 3: Programmatic trigger alternative
- ✅ Verification checklist

### Step 2: Add DiagnosticLogger Mixin

**File:** `lib/features/room/presentation/live_room_screen.dart`

**Change this line:**
```dart
class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
    with WidgetsBindingObserver {
```

**To this:**
```dart
class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
    with WidgetsBindingObserver, DiagnosticLogger {
```

**Add import at top:**
```dart
import 'package:mixvy/services/diagnostic_logger.dart';
```

### Step 3: Add Test Buttons

**Location:** In the `build()` method, add this Positioned widget with test buttons.

Copy from **Code Block 2** in `CONTROLLED_FAILURE_TEST.md`

It will add three floating buttons:
- 🟡 Test WARNING (orange)
- 🔴 Test ERROR (red)
- 🚨 Test CRITICAL (bright red)

### Step 4: Run the App

```bash
flutter run -d chrome
```

### Step 5: Test the Alert Pipeline

**WARNING Test (safest to start with):**

1. Navigate to a live room (must be in LiveRoomScreen)
2. Click the orange **"⚠️ Test WARNING"** button
3. See snackbar: "✓ WARNING logged to Crashlytics"
4. Immediate action: Open https://console.firebase.google.com/project/mixvy-v2/crashlytics
5. You should see your test log appear within 2-5 seconds
6. Look for: `[MIXVY_DEBUG] Test Warning Triggered`

**Then check each stage:**

| Stage | Location | What to Look For | Time |
|-------|----------|-----------------|------|
| **1** | Crashlytics Dashboard | Test log entry appears | 2-5s |
| **2** | Cloud Logging Query | Log with severity=WARNING | 5-10s |
| **3** | Alerting Dashboard | New incident (Firing) | 30-45s |
| **4** | Gmail | Email notification | 60-120s |

### Step 6: Verify Email Delivery

**Open Gmail:**
```
https://gmail.com
```

**Search for:**
```
from:noreply-gcp@google.com
```

**Expected email:**
- **From:** Google Cloud Platform
- **Subject:** "Incident opened for MixVy Production - WARNING Connection Health Degrading"
- **Body:** Shows your test log entry with timestamp
- **Time received:** 1-2 minutes after you clicked button

### Step 7: Repeat for ERROR and CRITICAL

1. Click **"🔴 Test ERROR"** button
2. Follow same verification steps (stages 1-4)
3. Click **"🚨 Test CRITICAL"** button
4. Follow same verification steps (stages 1-4)

### Expected Results

**All three alerts should work identically:**
- ✅ Log appears in Crashlytics within 5 seconds
- ✅ Incident fires in Alerting dashboard within 45 seconds
- ✅ Email arrives in Gmail within 2 minutes
- ✅ Incident auto-resolves within 5 minutes

---

## 📊 Real-Time Monitoring Checklist

As you run the test, keep this checklist handy:

**⏱️ T+2-5 seconds (Crashlytics)**
- [ ] Crashlytics dashboard shows new log entry
- [ ] Log message visible: "Test [WARNING/ERROR/CRITICAL] Triggered"
- [ ] Timestamp matches your test time
- [ ] Severity tag shows: WARN / ERROR / CRIT

**⏱️ T+5-10 seconds (Cloud Logging)**
- [ ] Open Logs Explorer query
- [ ] Run: `severity="WARNING"` (or ERROR/EMERGENCY)
- [ ] Your test log appears in results
- [ ] Timestamp matches Crashlytics timestamp

**⏱️ T+30-45 seconds (Alerting)**
- [ ] Open Alerting dashboard
- [ ] Click the matching alert policy
- [ ] "Recent Activity" shows new incident
- [ ] Incident status: "Firing"
- [ ] Incident timestamp: ~30-45 seconds after test

**⏱️ T+1-2 minutes (Email)**
- [ ] Open Gmail
- [ ] Search: `from:noreply-gcp@google.com`
- [ ] New email from GCP
- [ ] Subject mentions your alert name
- [ ] Body shows the exact log message
- [ ] Timestamp: 1-2 minutes after test

**⏱️ T+5 minutes (Resolution)**
- [ ] Refresh Alerting dashboard
- [ ] Incident status: "Resolved" (auto-close after 7 days)
- [ ] You might receive "Incident resolved" email
- [ ] Check incident duration: should be ~5 minutes

---

## 🚀 Part 2: Run E2E Tests

**Once alert test is complete:**

```bash
npm run test:e2e:ui
```

This opens an interactive Playwright test runner. You'll see:
- 4 tests execute one by one
- Real-time browser window showing each action
- Pass/fail indicators
- Detailed timeline for each test

**Expected output (all pass):**
```
✓ 01-Setup-Navigation: Login and view Live Rooms (3.2s)
✓ 02-Feature-Join: Click room, verify URL, check player... (5.8s)
✓ 03-Resilience: Connection state monitoring (11.2s)
✓ 04-Error-Tracking: Verify DiagnosticLogger integration (2.5s)

4 passed (22.7s)
```

**View results:**
```bash
npm run report:e2e
```

---

## 📖 Next Steps: Cleanup & Commit

### Before You Commit

**Remove all test code from LiveRoomScreen:**

1. Remove the DiagnosticLogger mixin (or keep it if useful)
2. Remove the three test buttons
3. Remove the DiagnosticLogger import (if not used elsewhere)
4. Verify: `git diff` shows only your actual changes

**Do NOT commit test button code!**

### After Verification

Once you've verified everything works:

```bash
git add CONTROLLED_FAILURE_TEST.md E2E_TRACE_VIEWER_GUIDE.md ALERT_LATENCY_MONITORING.md
git commit -m "docs: Verified production monitoring system - all tests passing"
git push origin main
```

---

## 🎓 What You've Accomplished

After completing this test, you'll have:

1. ✅ **Verified the entire alert pipeline** (log → alert → email)
2. ✅ **Confirmed email delivery** is working without throttling
3. ✅ **Tested E2E suite locally** before GitHub Actions runs it
4. ✅ **Practiced debugging** with Trace Viewer
5. ✅ **Documented the latency** (expected 1-2 minutes)
6. ✅ **Built confidence** in your production monitoring

**Your system is now proven to work in production.** 🎉

---

## 📞 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| Test buttons not appearing | Check DiagnosticLogger mixin added correctly |
| Snackbar shows but no log | Check Crashlytics project ID in main.dart |
| Log in Crashlytics but no email | Check notification channel email address |
| Email in spam | Mark as "Not Spam" and add GCP to contacts |
| Test runs but all tests fail | Check test credentials in .env.local |
| No video/trace files | Trace only saved on failure; success tests don't generate artifacts |

**For detailed troubleshooting:**
- Alert issues: `ALERT_LATENCY_MONITORING.md`
- E2E issues: `E2E_TRACE_VIEWER_GUIDE.md`
- Test code issues: `CONTROLLED_FAILURE_TEST.md`

---

## ✨ Final Confidence Check

After running this playbook, you should feel confident that:

- 🟢 **Monitoring works:** Real-time alerts in your inbox
- 🟢 **Testing works:** E2E tests validate every deployment
- 🟢 **Latency is acceptable:** 1-2 minutes from error to notification
- 🟢 **No hidden failures:** Global error tracking catches invisible bugs
- 🟢 **Recovery is traceable:** Trace Viewer shows exactly what happened

**You're ready to push to production with confidence.** 🚀

---

**Questions? Check:**
- `CONTROLLED_FAILURE_TEST.md` - Code and setup
- `E2E_TRACE_VIEWER_GUIDE.md` - Debugging tests
- `ALERT_LATENCY_MONITORING.md` - Monitoring alerts
- `PRODUCTION_SETUP_COMPLETE.md` - Full system overview

**All systems ready. Let's verify them!** 🎯
