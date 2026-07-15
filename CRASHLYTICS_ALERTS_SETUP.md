# Firebase Crashlytics Alerts Setup Guide

## 🎯 Overview

This guide walks you through setting up automated email alerts for production recovery events in your MixVy app. When users experience network failures and max retries are exceeded, you'll get an instant notification.

---

## 📊 Alert Types to Configure

### Alert 1: Recovery Failure (Critical)
**When:** User loses connection for >14 seconds (max retries exceeded)  
**Severity:** 🔴 CRITICAL  
**Action:** Immediate investigation required

### Alert 2: Connection Degradation (Warning)
**When:** Latency > 1500ms detected  
**Severity:** 🟡 WARNING  
**Action:** Monitor trend, may need infrastructure investigation

### Alert 3: Health Check Failures (Info)
**When:** 5+ consecutive health check pings fail  
**Severity:** 🔵 INFO  
**Action:** Diagnostic only, watch for patterns

---

## 🔧 Step-by-Step Setup

### STEP 1: Open Firebase Crashlytics Console

**URL:** https://console.firebase.google.com/project/mixvy-v2/crashlytics

**Expected View:**
```
Crashlytics Dashboard
├─ Issues (sorted by severity & frequency)
├─ [MIXVY_DEBUG:AgoraService][ERROR]
├─ [MIXVY_DEBUG:ConnectionHealthCheckService][WARN]
└─ [MIXVY_DEBUG:AgoraService][CRIT]
```

---

### STEP 2: Create Alert #1 - Recovery Failure (CRITICAL)

**Goal:** Get notified immediately when max retries exceeded

**Steps:**

1. Click on issue: `[MIXVY_DEBUG:AgoraService][CRIT]`
2. Click **⋮ (three-dot menu)** → **Create Alert**
3. Configure:
   ```
   Alert Name:           "MixVy: Max Retries Exceeded (CRITICAL)"
   Alert Type:           Issues
   Issue Type:           Select this specific issue
   Condition:            Any new issue
   Threshold:            1 occurrence
   Time Window:          1 minute
   ```
4. Add Notification:
   - Click **+ Add notification channel**
   - Choose: **Email**
   - Enter: your-email@example.com
   - Label: "MixVy Critical Alerts"
5. Click **Save**

**What You'll Receive:**
```
From: Firebase Alerts <noreply@firebase.google.com>
Subject: Alert: MixVy: Max Retries Exceeded (CRITICAL)

Issue: [MIXVY_DEBUG:AgoraService][CRIT] Max retries exceeded
Severity: CRITICAL
Occurrences: 1 in last 1 min
User Affected: 1
Device: iOS / Android / Web
Error Details: 
  - channelName: room-456
  - totalDuration: 14000ms
  - attemptCount: 3

Impact: Users cannot connect to live rooms
Action: Check network/server status immediately
```

---

### STEP 3: Create Alert #2 - Reconnection Failure (ERROR)

**Goal:** Track when reconnection attempts fail (before max retries)

**Steps:**

1. Click on issue: `[MIXVY_DEBUG:AgoraService][ERROR]`
2. Click **⋮** → **Create Alert**
3. Configure:
   ```
   Alert Name:           "MixVy: Connection Recovery Failure"
   Condition:            > 3 occurrences
   Time Window:          10 minutes
   ```
4. Add Email Notification
5. Click **Save**

**What You'll Receive:**
```
Alert: MixVy: Connection Recovery Failure
Occurrences: 5 in last 10 minutes
Devices Affected: 2 users
Pattern: [MIXVY_DEBUG:AgoraService][ERROR]
```

---

### STEP 4: Create Alert #3 - Health Degradation (WARNING)

**Goal:** Early warning before connection fails

**Steps:**

1. Click on issue: `[MIXVY_DEBUG:ConnectionHealthCheckService][WARN]`
2. Click **⋮** → **Create Alert**
3. Configure:
   ```
   Alert Name:           "MixVy: Connection Degrading"
   Condition:            > 5 occurrences
   Time Window:          5 minutes
   ```
4. Add Email Notification
5. Click **Save**

**What You'll Receive:**
```
Alert: MixVy: Connection Degrading
Occurrences: 8 in last 5 minutes
Average Latency: 1850ms
Trend: Increasing
```

---

## 📧 Email Alert Examples

### Example 1: CRITICAL Alert (Instant)
```
🚨 CRITICAL: Max Retries Exceeded

Issue:    [MIXVY_DEBUG:AgoraService][CRIT]
Time:     2026-07-14 21:47:30 UTC
Duration: 14 seconds
Users:    1 affected

Details:
  channelName: room-789
  failureCount: 3
  metadata: {'attemptNumber': 3, 'reason': 'connection_timeout'}

Action Required: YES - User cannot access live room

View in Crashlytics: [LINK]
```

### Example 2: ERROR Alert (Trend Warning)
```
⚠️ WARNING: Connection Recovery Failures

Issue:    [MIXVY_DEBUG:AgoraService][ERROR]
Count:    5 occurrences in 10 minutes
Pattern:  Reconnection attempt failed

Details:
  Affected Users: 2
  Affected Rooms: room-456, room-789
  Timestamp: Last 5 minutes

Correlation: May indicate network instability

View in Crashlytics: [LINK]
```

### Example 3: WARN Alert (Proactive)
```
ℹ️ INFO: Connection Health Degrading

Issue:    [MIXVY_DEBUG:ConnectionHealthCheckService][WARN]
Count:    8 occurrences in 5 minutes
Average:  1850ms latency

Details:
  Threshold: > 1000ms
  Trend: Increasing
  Users: Multiple

Action: Monitor - may lead to recovery events

View in Crashlytics: [LINK]
```

---

## 🎯 Recommended Alert Configuration

| Alert | Condition | Threshold | Action |
|-------|-----------|-----------|--------|
| **CRIT** | Max retries exceeded | 1 occurrence / 1 min | ⏰ Urgent (email + SMS?) |
| **ERROR** | Reconnection failed | >3 in 10 min | 📧 Standard (email) |
| **WARN** | Health degrading | >5 in 5 min | 📋 Info only (no alert) |

---

## 🔍 How to View Alerts in Crashlytics

After alerts are created, monitor them:

1. **Crashlytics Dashboard → Issues**
   - Sorted by: Severity (CRIT → ERROR → WARN)
   - Sorted by: Frequency (most recent first)
   - Filter by: [MIXVY_DEBUG]

2. **Click any issue to see:**
   - Stack trace
   - Custom keys (diagnostic_severity, diagnostic_category, diagnostic_metadata)
   - Affected users/devices
   - Timeline of occurrences

3. **Check your email:**
   - Alerts arrive within 1-2 minutes of occurrence
   - Include link to Crashlytics dashboard
   - Show affected users and device info

---

## 📊 Production Monitoring Workflow

```
USER EXPERIENCE
│
├─ User joins live room ✅
│  └─ Logs: [MIXVY_DEBUG:ConnectionHealthCheckService][INFO]
│
├─ Network drops (user goes offline)
│  └─ Logs: [MIXVY_DEBUG:AgoraService][WARN] Connection lost
│  └─ Recovery attempts: 1/3 (2s), 2/3 (4s), 3/3 (8s)
│
├─ Max retries exceeded (14s elapsed)
│  └─ Logs: [MIXVY_DEBUG:AgoraService][CRIT]
│  └─ ALERT: Email arrives in dashboard
│
└─ YOU get notified within 1-2 minutes
   └─ User's connection issue is visible in Crashlytics
   └─ You can correlate with backend logs/metrics
```

---

## 🚀 Advanced: Custom Dashboards (Optional)

After alerts are created, create a custom dashboard:

1. **Firebase Console → Custom Dashboards**
2. **Add Metric:**
   - Name: "Recovery Events Per Hour"
   - Filter: `[MIXVY_DEBUG:AgoraService][CRIT]`
   - Aggregation: Count per hour
   - Alert if: > 5

3. **Add Metric:**
   - Name: "Average Connection Latency"
   - Filter: `[MIXVY_DEBUG:ConnectionHealthCheckService]`
   - Field: `diagnostic_metadata` (extract latencyMs)
   - Alert if: > 2000ms

---

## ✅ Verification Checklist

After setting up alerts:

- [ ] Alert #1 (CRITICAL) configured
- [ ] Alert #2 (ERROR) configured
- [ ] Alert #3 (WARNING) configured (optional)
- [ ] Email notifications enabled
- [ ] Test alert (trigger manually if possible)
- [ ] Verify email received

---

## 🧪 Test Your Alerts (Optional)

To verify alerts work before production issues occur:

1. **Simulate offline mode** in your app
2. **Wait for recovery** (or max retries)
3. **Watch Crashlytics** for [MIXVY_DEBUG] logs
4. **Check email** for alert notification
5. **Verify timing** (should arrive within 1-2 minutes)

---

## 📞 Support & Troubleshooting

**Alert not arriving?**
- Check email spam folder
- Verify notification channel is enabled
- Check Firebase Console for alert delivery logs

**Too many alerts?**
- Increase threshold (e.g., >5 instead of >1)
- Increase time window (e.g., 10 min instead of 5 min)
- Add filters to exclude non-critical issues

**Want to modify?**
- Click alert → Edit
- Change threshold/time window
- Save

---

## 🎉 You're Now Production-Ready

With alerts configured, your production system is:
- ✅ **Deployed** (live on Firebase Hosting)
- ✅ **Monitored** (Crashlytics dashboard active)
- ✅ **Alerted** (email notifications on critical events)
- ✅ **Observable** (structured [MIXVY_DEBUG] logs)

**Next time a user experiences a connection issue, you'll know about it before they do.** 📡

---

## 📚 References

- [Firebase Crashlytics Documentation](https://firebase.google.com/docs/crashlytics)
- [Custom Keys & Filtering](https://firebase.google.com/docs/crashlytics/customize-crash-reports)
- [Alerts Configuration](https://firebase.google.com/docs/crashlytics/alerts)
