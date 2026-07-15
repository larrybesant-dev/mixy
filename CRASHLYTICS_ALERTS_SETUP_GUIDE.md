# Crashlytics Alerts Setup Guide - MixVy Production Monitoring

**Status:** ✅ Ready for Configuration  
**Date:** July 14, 2026  
**System:** Firebase Crashlytics + Diagnostic Logger Integration  

---

## Overview

Your MixVy app now logs all diagnostic events with standardized `[MIXVY_DEBUG:ServiceName][SEVERITY]` prefixes to Firebase Crashlytics. This guide shows you how to set up 3 automated alerts to monitor critical issues in production.

**What's Already Done:**
- ✅ DiagnosticLogger mixin deployed across all services (AgoraService, WebRtcRoomService, ConnectionHealthCheckService)
- ✅ Production handler configured in `lib/main.dart` (lines 87-103)
- ✅ Firestore security rules deployed (handles permission-denied errors)
- ✅ Firebase Crashlytics configured with custom metadata keys

---

## 3 Recommended Alerts

### Alert 1: CRITICAL - Max Reconnection Retries Exceeded

**Triggers When:** Network recovery fails after 3 attempts (14 seconds offline)  
**Severity Level:** FATAL  
**Response Time Target:** Immediate (user experience severely impacted)

### Alert 2: ERROR - Repeated Reconnection Failures

**Triggers When:** 5+ reconnection failures within 5 minutes  
**Severity Level:** ERROR  
**Response Time Target:** 5 minutes (passive monitoring)

### Alert 3: WARNING - Health Status Degrading

**Triggers When:** Latency >1s OR trending upward OR 3+ connection failures  
**Severity Level:** WARNING  
**Response Time Target:** 15 minutes (proactive monitoring)

---

## Step-by-Step Setup Instructions

### Part 1: Open Firebase Console

1. Go to: https://console.firebase.google.com/project/mixvy-v2/monitoring/alerts
2. Sign in with: **larrybesant@gmail.com**
3. Verify you're in project: **mixvy-v2** (Blaze plan)

---

### Part 2: Create Alert #1 - CRITICAL Severity

#### Step 1: Click "Create Alert" button

![Location: Top-right of Alerts page]

#### Step 2: Select Alert Type

```
Alert type: Crashlytics
Condition: By issue
```

#### Step 3: Configure Condition

```
Condition: Issue severity is
Value: FATAL
```

*This catches all FATAL errors including:*
- `[MIXVY_DEBUG:ConnectionRecoveryHandler][CRIT] Max retries exceeded`
- Recovery badges showing "Max retries (3/3)"
- Connection failed overlay appears

#### Step 4: Set Notification Channel

```
Notification method: Email
Recipients: larrybesant@gmail.com
```

#### Step 5: Alert Details

```
Alert name: "MixVy Production - CRITICAL Network Recovery Failure"
Display name: "CRITICAL - Max Retries"
```

#### Step 6: Save

Click "Save" button

---

### Part 3: Create Alert #2 - ERROR Severity

#### Step 1: Click "Create Alert" button

#### Step 2: Select Alert Type

```
Alert type: Crashlytics
Condition: By issue count
```

#### Step 3: Configure Condition

```
Condition: Number of issues is greater than
Value: 5
Time window: 5 minutes
```

#### Step 4: Filter by Custom Key (Optional but Recommended)

```
Custom key: diagnostic_severity
Value: ERROR
```

*This catches:*
- `[MIXVY_DEBUG:ConnectionRecoveryHandler][ERR] Reconnection attempt failed`
- `[MIXVY_DEBUG:AgoraService][ERR] Connection lost`
- Service-level failures that need attention

#### Step 5: Set Notification Channel

```
Notification method: Email
Recipients: larrybesant@gmail.com
```

#### Step 6: Alert Details

```
Alert name: "MixVy Production - ERROR Reconnection Failures (5+ in 5min)"
Display name: "ERROR - Reconnect Failures"
```

#### Step 7: Save

---

### Part 4: Create Alert #3 - WARNING Severity (Health Degrading)

#### Step 1: Click "Create Alert" button

#### Step 2: Select Alert Type

```
Alert type: Crashlytics
Condition: By issue count
```

#### Step 3: Configure Condition

```
Condition: Number of issues is greater than
Value: 3
Time window: 5 minutes
```

#### Step 4: Filter by Custom Key

```
Custom key: diagnostic_severity
Value: WARN
```

*This catches:*
- `[MIXVY_DEBUG:ConnectionHealthCheckService][WARN] Health degrading (latency >1s)`
- `[MIXVY_DEBUG:WebRtcRoomService][WARN] Connection unstable`
- Proactive monitoring before failures escalate

#### Step 5: Set Notification Channel

```
Notification method: Email
Recipients: larrybesant@gmail.com
```

#### Step 6: Alert Details

```
Alert name: "MixVy Production - WARNING Connection Health Degrading"
Display name: "WARNING - Health Degrading"
```

#### Step 7: Save

---

## Verification Checklist

After creating all 3 alerts, verify they're active:

- [ ] **Alert 1 (CRITICAL)** shows in the alerts list
- [ ] **Alert 2 (ERROR)** shows in the alerts list  
- [ ] **Alert 3 (WARNING)** shows in the alerts list
- [ ] Each alert has Email notification enabled
- [ ] Recipient is: `larrybesant@gmail.com`

---

## Testing the Alert System

### Quick Test: Trigger WARNING Alert

**Scenario:** Simulate degraded connection health

1. Open MixVy: https://mixvy-v2.web.app
2. Join any live room
3. Open browser DevTools → Network tab
4. Set throttling to "Slow 3G"
5. Observe:
   - Console shows: `[MIXVY_DEBUG:ConnectionHealthCheckService][WARN]`
   - Latency indicator shows degrading
   - Within minutes, you should receive WARNING email alert

### Full Test: Trigger CRITICAL Alert (Advanced)

**Scenario:** Simulate complete network failure with max retries

1. Join a live room
2. Open browser DevTools → Network tab → Offline
3. Observe:
   - Recovery badge appears: "Reconnecting... (1/3)"
   - Attempts 2/3, 3/3 over 14 seconds
   - Console shows: `[MIXVY_DEBUG:ConnectionRecoveryHandler][CRIT] Max retries exceeded`
   - Connection failed overlay appears
   - You should receive CRITICAL email alert within 1-2 minutes

---

## Production Monitoring Workflow

### Daily Monitoring (Part of Ops)

1. **Morning Check:** Review Crashlytics dashboard for overnight issues
   - Look for new [MIXVY_DEBUG] logs
   - Check ERROR and CRITICAL issue count
   
2. **Email Alerts:** Read incoming alerts (auto-sent when conditions triggered)
   - CRITICAL: immediate response needed
   - ERROR: investigate within 5 minutes
   - WARNING: proactive monitoring, no immediate action

3. **Weekly Report:** Aggregate metrics
   - Total reconnection attempts
   - Success rate of auto-recovery
   - Most common failure patterns

### When Alerts Fire

**CRITICAL Alert Received:**
- ✅ User experienced complete network loss for >14 seconds
- ✅ Auto-recovery exhausted 3 attempts
- 📋 Action: Contact user if available, monitor Firestore for updates
- 📊 Metric: Track frequency (should be rare in stable network)

**ERROR Alert Received:**
- ⚠️ Multiple reconnection failures detected
- ✅ Could be temporary network glitch OR persistent issue
- 📋 Action: Check Firestore real-time database for room health
- 📊 Metric: If recurring from same user, investigate their connection

**WARNING Alert Received:**
- 🟡 System approaching performance threshold
- ✅ Not yet a failure, but trending toward one
- 📋 Action: Monitor next 5 minutes for escalation to ERROR/CRITICAL
- 📊 Metric: High latency periods correlate with time-of-day (peak hours?)

---

## Dashboard Setup (Optional)

Create a custom Crashlytics dashboard to visualize diagnostics:

1. Go to: Crashlytics → Custom Dashboard
2. Add widgets:
   - **Crash-free sessions:** Should be >99%
   - **Issues by severity:** CRITICAL, ERROR, WARNING breakdown
   - **Top issues:** Filter by `[MIXVY_DEBUG]` prefix
   - **Affected sessions:** Users impacted by each issue

---

## Troubleshooting

### Alerts Not Firing?

**Check:**
1. Email notifications enabled on your account:
   - https://console.firebase.google.com/project/mixvy-v2/settings/notifications
2. Crashlytics events reaching Firebase:
   - Verify from app console logs: `[Firebase] Firestore initialized successfully`
3. Custom keys being set:
   - Check DiagnosticLogger.setProductionHandler() is called (lib/main.dart line 87)

### Too Many Alerts?

**Adjust thresholds:**
- ERROR alert: Increase from 5 to 10 issues in 5min
- WARNING alert: Increase from 3 to 7 issues in 5min
- CRITICAL: Cannot be tuned (all FATAL = critical)

### Alert Wrong Recipient?

**Update:**
1. Go to: Crashlytics → Alert settings
2. Find the alert → Edit
3. Change "Recipients" email address
4. Save

---

## Integration with Diagnostic Logger

When you see these log messages in production, they automatically trigger the corresponding alerts:

```dart
// Files: lib/services/*.dart with DiagnosticLogger mixin

// CRITICAL - Triggers "Max Retries" alert
logCritical('Max retries exceeded', metadata: {
  'reason': 'connection_lost',
  'maxRetries': 3,
  'baseDelayMs': 2000,
});

// ERROR - Accumulates toward "ERROR Failures" alert
logError('Reconnection attempt failed', metadata: {
  'attempt': 2,
  'elapsedMs': 4200,
  'error': 'timeout'
});

// WARNING - Accumulates toward "Health Degrading" alert
logWarning('Connection health degrading', metadata: {
  'averageLatency': 1250,
  'lastPingTime': 1100,
});
```

---

## Next Steps

1. ✅ **Create 3 alerts** (follow steps above)
2. ✅ **Verify notifications** sent to your email
3. ✅ **Test the system** (optional, see Testing section)
4. 📊 **Monitor production** (daily Crashlytics review)
5. 📝 **Document incidents** (create post-mortems for any CRITICAL alerts)

---

## Support

For issues or questions:
- Crashlytics docs: https://firebase.google.com/docs/crashlytics/
- Custom logging: See [lib/services/diagnostic_logger.dart](lib/services/diagnostic_logger.dart)
- Production config: See [lib/main.dart lines 87-103](lib/main.dart#L87-L103)

---

**Last Updated:** July 14, 2026  
**System Status:** ✅ Production Ready  
**Alerts:** Pending Manual Configuration
