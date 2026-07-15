# Alert Latency Monitoring & Email Verification Guide

**Goal:** Verify that alerts are being triggered promptly and emails are being delivered without throttling.

---

## 📊 Understanding the Alert Pipeline

When you trigger a log in your app, here's what happens:

```
TIME ELAPSED | COMPONENT             | STATUS
─────────────┼───────────────────────┼──────────────────────────
0s           | Log generated         | LogWarning() called
0-2s         | Crashlytics ingestion | Firebase receives log
2-5s         | Cloud Logging sync    | Log appears in Logs Explorer
5-10s        | Alert policy query    | Policy evaluates condition
10-30s       | Threshold reached     | Alert fires
30-60s       | Notification sent     | Email queued
60-120s      | Email delivered       | Email arrives in Gmail
```

**Total time: 1-2 minutes from log to email**

---

## 🔍 Step 1: Verify Alert Was Triggered

### In Google Cloud Console

1. **Open Cloud Alerting:** https://console.cloud.google.com/monitoring/alerting/policies?project=mixvy-v2

2. **Look at your three alert policies:**
   - MixVy Production - CRITICAL Network Recovery Failure
   - MixVy Production - ERROR Reconnection Failures
   - MixVy Production - WARNING Connection Health Degrading

3. **For each alert, look at:**
   - **Status:** Should be "Enabled" (green checkmark)
   - **Active Incidents:** Shows current firing incidents
   - **Recent Activity:** Timeline of past incidents

4. **Click on "Recent Activity" tab** to see:
   ```
   Timestamp          | Alert Name                    | Status
   2026-07-15 14:23:45| WARNING Connection Health     | Firing (1 incident open)
   2026-07-15 14:22:30| ERROR Reconnection Failures   | Resolved (incident closed)
   2026-07-15 14:15:12| CRITICAL Network Recovery    | Firing (incident open)
   ```

### Dashboard Indicators

You should see:
- ✅ Alert policies: 3
- ✅ Firing incidents: 0 (if no current issues) or > 0 (if testing)
- ✅ Notification channels: 1 (Email - larrybesant@gmail.com)

---

## ⏱️ Step 2: Monitor Alert Latency

### View the Alert Detail Page

1. **Click on one of your alert policies** (e.g., "WARNING Connection Health Degrading")

2. **You'll see a detail page with:**

```
┌─────────────────────────────────────────────────────┐
│ Alert Policy: MixVy Production - WARNING Connection│
│ Status: Enabled                                     │
├─────────────────────────────────────────────────────┤
│ Notifications sent: 2                               │
│ Last notification: 2026-07-15 14:23:45 UTC          │
│ Recent incidents:                                   │
│                                                      │
│ Timestamp              │ Duration     │ Status       │
│ ────────────────────────┼──────────────┼─────────────│
│ 14:23:15 - 14:25:30   │ 2 min 15 sec │ Resolved    │
│ 13:45:00 - 13:47:22   │ 2 min 22 sec │ Resolved    │
│ 12:10:30 - 12:13:15   │ 2 min 45 sec │ Resolved    │
└─────────────────────────────────────────────────────┘
```

**What you're looking for:**
- **Status: Enabled** ✅
- **Notifications sent > 0** ✅
- **Last notification is recent** ✅

### Check Incident Details

Click on any incident to see:

```
INCIDENT TIMELINE:

Time      | Event
──────────┼─────────────────────────────────────────────
14:22:30  | Condition triggered (log matched query)
14:22:45  | Threshold met (evaluated alert policy)
14:23:15  | Incident opened (user notification would fire)
14:23:45  | Notification sent to email channel
14:25:30  | Condition resolved (no more matching logs)
14:25:30  | Incident automatically closed
```

**Latency Breakdown:**
- Condition → Threshold: **~15 seconds** (alert policy evaluation)
- Threshold → Notification Sent: **~30 seconds** (notification processing)
- **Total:** ~45 seconds (well within your 1-hour rate limit)

---

## 📧 Step 3: Verify Email Delivery

### Check Gmail Inbox

1. **Open Gmail:** https://gmail.com

2. **Search for GCP alerts:**
   - Search box: `from:noreply-gcp@google.com`
   - Or: `subject:"Incident opened for MixVy"`

3. **Expected email structure:**

```
FROM:    Google Cloud Platform <noreply-gcp@google.com>
TO:      larrybesant@gmail.com
SUBJECT: Incident opened for MixVy Production - WARNING Connection Health Degrading
DATE:    Tue, Jul 15, 2026 14:23:45 GMT

BODY:
──────────────────────────────────────────────────────
Incident opened for:
  MixVy Production - WARNING Connection Health Degrading

Time: 2026-07-15 14:23:45 UTC

Log Entry:
  [MIXVY_DEBUG:LiveRoomScreen][WARN] Test Warning Triggered

View Details: [Link to Cloud Console]
Acknowledge: [Button]
──────────────────────────────────────────────────────
```

### Check Spam Folder

If you don't see emails:

1. **Check Gmail Spam folder:** Search `in:spam` for GCP emails
2. **Mark as "Not Spam"** if found
3. **Add to contacts:** `noreply-gcp@google.com`

### Troubleshooting Missing Emails

**Problem: No email received after 5 minutes**

1. **Verify alert was triggered:**
   - Go to Cloud Alerting dashboard
   - Is there a recent incident?
   - Does it show "Notification sent"?

2. **If alert shows "Notification sent" but no email:**
   - ✅ Alert is working
   - ❌ Email delivery is failing
   - Check: Did you list the correct email in the notification channel?

3. **Fix the notification channel:**
   - Open alert policy
   - Click "Edit"
   - Check email in notification channel
   - Update if wrong
   - Re-run test

4. **Check Gmail filters:**
   - Settings → Filters and Blocked Addresses
   - Make sure GCP emails aren't auto-archived
   - Create filter: `from:noreply-gcp@google.com` → Apply label "GCP Alerts"

---

## 🎬 Step 4: Full Incident Monitoring Flow

### Complete Walkthrough

**Time: 14:20:00 - Start test**

1. Open your MixVy app
2. Click the "Test WARNING" button (or call logWarning() in code)
3. Snackbar shows: "✓ WARNING logged to Crashlytics"

**Time: 14:20:05 - Check Crashlytics**

1. Open: https://console.firebase.google.com/project/mixvy-v2/crashlytics
2. Look for your new log entry
3. You should see: `[MIXVY_DEBUG] Test Warning Triggered`

**Time: 14:20:30 - Check Cloud Logging**

1. Open: https://console.cloud.google.com/logs/query?project=mixvy-v2
2. Search: `severity="WARNING"`
3. You should see your test log appear
4. Verify the exact log message

**Time: 14:21:00 - Check Alert Policy**

1. Open: https://console.cloud.google.com/monitoring/alerting/policies?project=mixvy-v2
2. Click on "WARNING Connection Health Degrading" alert
3. Look for a new incident in "Recent Activity"
4. You should see:
   - **Status:** Firing
   - **Incident opened:** ~30-40 seconds ago
   - **Notifications sent:** 1

**Time: 14:21:30 - Check Email**

1. Open Gmail: https://gmail.com
2. Search: `from:noreply-gcp@google.com`
3. You should see email with subject: "Incident opened for MixVy Production - WARNING..."
4. Email timestamp should be ~1-2 minutes after you clicked the button

**Time: 14:22:00 - Acknowledge Incident (Optional)**

1. In alert policy detail page, click "Acknowledge"
2. Or in email, click the "Acknowledge" button
3. Incident status changes to "Acknowledged"

**Time: 14:25:00 - Incident Resolves (Automatic)**

1. After ~5 minutes with no new matching logs
2. Incident automatically closes
3. Alert policy shows "Status: Resolved"
4. You might receive a second email: "Incident resolved for MixVy Production - WARNING..."

---

## 📈 Monitoring Dashboard

### Create a Dashboard for Quick Monitoring

1. **Go to:** https://console.cloud.google.com/monitoring/dashboards?project=mixvy-v2

2. **Click:** "Create Dashboard"

3. **Add Widgets:**
   - **Widget 1: Alert Summary**
     - Metric: `monitoring.googleapis.com/uptime_check/check_passed`
     - Display: Last firing incident count
   
   - **Widget 2: Recent Incidents**
     - Type: Scorecard
     - Show: Number of incidents in last 24 hours
   
   - **Widget 3: Notification Latency**
     - Type: Line chart
     - Metric: Time from alert fire to notification sent

**This gives you a single view of your alert health.**

---

## 🔔 Step 5: Verify Email Not Throttled

### Check Throttling Status

Email throttling happens when Google Cloud detects too many repeated alerts. It's usually safe to ignore, but here's how to verify:

1. **Open Alert Policy:** Click on your WARNING alert policy

2. **Look for notification rate limit:**
   ```
   Notification Rate Limit: 1 per 1 hour
   ```

3. **This means:**
   - ✅ Even if condition fires 100 times/minute
   - ✅ You only get 1 email per hour
   - ✅ Additional notifications are queued or dropped
   - ✅ This prevents email spam

4. **To test throttling:**
   - Trigger WARNING 3 times in 1 minute
   - You should only get 1 email
   - After 1 hour, next WARNING will email again

---

## ✅ Verification Checklist

Use this checklist to verify everything is working:

### Alert Configuration
- ✅ Alert policy exists in Alerting console
- ✅ Alert policy shows "Enabled"
- ✅ Notification channel is set to email
- ✅ Email address is correct (larrybesant@gmail.com)
- ✅ All three alerts (CRITICAL/ERROR/WARNING) exist

### Alert Triggering
- ✅ Log entry appears in Crashlytics (within 5 seconds)
- ✅ Log entry appears in Cloud Logging query results (within 10 seconds)
- ✅ Incident appears in alert policy's recent activity (within 30 seconds)
- ✅ Incident shows "Status: Firing" (not "Acknowledged" or "Resolved")

### Email Delivery
- ✅ Email received in Gmail inbox (within 2 minutes)
- ✅ Email is from `noreply-gcp@google.com`
- ✅ Email subject contains alert name
- ✅ Email body shows the actual log entry
- ✅ Email is not in Spam folder

### Latency Metrics
- ✅ Log generation to Crashlytics: < 5 seconds
- ✅ Crashlytics to Cloud Logging: < 10 seconds
- ✅ Cloud Logging to alert policy: < 30 seconds
- ✅ Alert policy to email notification: < 1 minute
- ✅ Email notification to Gmail receipt: < 2 minutes

---

## 🚨 Troubleshooting Table

| Problem | Symptom | Check |
|---------|---------|-------|
| **Alert not firing** | No incident in dashboard | Is alert policy "Enabled"? Is query syntax correct? |
| **Email not received** | Incident firing but no email | Check Gmail spam. Verify email address in notification channel. |
| **Email delayed** | Email arrives after 5+ minutes | Check Cloud Logging latency. Check Gmail spam filters. |
| **Email throttled** | Only 1 email despite multiple triggers | This is expected! Check rate limit settings. |
| **Incident won't close** | Status stays "Firing" forever | Add condition to auto-resolve incident (default: 7 days) |
| **Too many emails** | Getting emails for every log | Increase rate limit (change from 1 hour to 6 hours) |

---

## 📚 Reference Links

- **Cloud Alerting Dashboard:** https://console.cloud.google.com/monitoring/alerting/policies?project=mixvy-v2
- **Crashlytics Dashboard:** https://console.firebase.google.com/project/mixvy-v2/crashlytics
- **Cloud Logging Query:** https://console.cloud.google.com/logs/query?project=mixvy-v2
- **Gmail:** https://gmail.com

---

## 🎓 Pro Tips

**Tip 1: Create Gmail Label for GCP Alerts**
```
Gmail Settings → Filters
Create filter:
  From: noreply-gcp@google.com
  Label: "GCP Alerts"
```
All GCP emails will automatically go to this label.

**Tip 2: Set Up Gmail Notification**
- Customize Label notification settings
- Set to "All mail" so you see GCP alerts in real-time

**Tip 3: Monitor Multiple Alerts in Spreadsheet**
- Create a Google Sheet
- Log each test trigger
- Record timestamps from app, Crashlytics, Cloud Logging, email
- Calculate actual latency times

**Tip 4: Set Calendar Reminders**
- Schedule daily checks of alert dashboard
- Verify no unexpected incidents firing
- Check incident count is within expected range

---

## ✨ Success Indicators

When everything is working correctly, you'll see:

1. **You trigger a test warning in your app**
2. **Within 30 seconds**: Incident appears in Cloud Alerting dashboard
3. **Within 1-2 minutes**: Email arrives in your Gmail inbox
4. **Within 5 minutes**: Incident automatically resolves
5. **You get visibility** into production health in near real-time

**This is production-grade monitoring.** You're now catching issues before users report them. 🚀
