# MixVy Crashlytics Alerts - Quick Setup (Copy-Paste Ready)

**Status:** ✅ Ready for 5-Minute Manual Setup  
**Deployed:** July 14, 2026  
**System:** Firebase Crashlytics + DiagnosticLogger  

---

## Quick Access Links

Open these in your browser (logged in as larrybesant@gmail.com):

1. **Crashlytics Settings:**  
   https://console.firebase.google.com/project/mixvy-v2/monitoring/crashlytics

2. **Create New Alert (Direct):**  
   https://console.firebase.google.com/project/mixvy-v2/monitoring/crashlytics/alerts

3. **Email Settings:**  
   https://console.firebase.google.com/u/0/project/mixvy-v2/settings/notifications

---

## Alert Configuration Reference

All three alerts automatically route to **larrybesant@gmail.com** via email.

### ALERT #1: CRITICAL - Max Retries

| Field | Value |
|-------|-------|
| Alert Name | `MixVy Production - CRITICAL Network Recovery Failure` |
| Display Name | `CRITICAL - Max Retries` |
| Type | Crashlytics |
| Condition | `Issue severity is FATAL` |
| Email | `larrybesant@gmail.com` |
| Trigger Prefix | `[MIXVY_DEBUG:ConnectionRecoveryHandler][CRIT]` |

**What Triggers It:**
- User experiences >14 seconds offline
- Recovery exhausts all 3 reconnection attempts
- Message: "Max retries exceeded"

**Response Time:** ⏱️ IMMEDIATE (user impact critical)

---

### ALERT #2: ERROR - Reconnection Failures

| Field | Value |
|-------|-------|
| Alert Name | `MixVy Production - ERROR Reconnection Failures (5+ in 5min)` |
| Display Name | `ERROR - Reconnect Failures` |
| Type | Crashlytics |
| Condition | `Issue count > 5 in 5 minutes` |
| Filter | Custom key `diagnostic_severity` = `ERROR` |
| Email | `larrybesant@gmail.com` |
| Trigger Prefix | `[MIXVY_DEBUG][ERR]` |

**What Triggers It:**
- 5 or more ERROR-level issues detected within 5 minutes
- Indicates repeated connection problems
- Examples: "Reconnection attempt failed", "Connection lost"

**Response Time:** ⏱️ 5 MINUTES (investigate pattern)

---

### ALERT #3: WARNING - Health Degrading

| Field | Value |
|-------|-------|
| Alert Name | `MixVy Production - WARNING Connection Health Degrading` |
| Display Name | `WARNING - Health Degrading` |
| Type | Crashlytics |
| Condition | `Issue count > 3 in 5 minutes` |
| Filter | Custom key `diagnostic_severity` = `WARN` |
| Email | `larrybesant@gmail.com` |
| Trigger Prefix | `[MIXVY_DEBUG][WARN]` |

**What Triggers It:**
- 3+ WARNING-level issues in 5 minutes
- Proactive indicator before failures escalate
- Examples: "Latency >1s", "Health degrading"

**Response Time:** ⏱️ 15 MINUTES (monitor for escalation)

---

## Step-by-Step Setup (Manual)

### Prerequisites
- ✅ Logged into Firebase Console as larrybesant@gmail.com
- ✅ At project: `mixvy-v2` (Blaze plan)
- ✅ App: `mixvy (android)`

### Creating Each Alert

**For Each Alert Below:**

1. Go to: https://console.firebase.google.com/project/mixvy-v2/monitoring/crashlytics
2. Click the **gear icon** (⚙️) in top-right
3. Click **"Create alert"** or **"New alert"** button
4. Fill in the fields from the table above
5. Click **"Save"**
6. Verify email notification received

---

## Alert Configuration JSON (Reference)

If you can access Firebase APIs, here's the equivalent JSON configuration:

```json
{
  "alerts": [
    {
      "displayName": "CRITICAL - Max Retries",
      "conditions": [{
        "displayName": "Issue severity is FATAL",
        "conditionThreshold": {
          "filter": "severity = FATAL",
          "comparison": "COMPARISON_GT",
          "thresholdValue": 0,
          "duration": "0s"
        }
      }],
      "notificationChannels": [
        "projects/mixvy-v2/notificationChannels/email-larrybesant@gmail.com"
      ],
      "alertStrategy": {
        "autoClose": "2592000s"
      }
    },
    {
      "displayName": "ERROR - Reconnect Failures",
      "conditions": [{
        "displayName": "Issue count > 5 in 5 minutes",
        "conditionThreshold": {
          "filter": "diagnostic_severity = ERROR",
          "comparison": "COMPARISON_GT",
          "thresholdValue": 5,
          "duration": "300s"
        }
      }],
      "notificationChannels": [
        "projects/mixvy-v2/notificationChannels/email-larrybesant@gmail.com"
      ]
    },
    {
      "displayName": "WARNING - Health Degrading",
      "conditions": [{
        "displayName": "Issue count > 3 in 5 minutes",
        "conditionThreshold": {
          "filter": "diagnostic_severity = WARN",
          "comparison": "COMPARISON_GT",
          "thresholdValue": 3,
          "duration": "300s"
        }
      }],
      "notificationChannels": [
        "projects/mixvy-v2/notificationChannels/email-larrybesant@gmail.com"
      ]
    }
  ]
}
```

---

## Testing Alerts (Optional)

### Quick Test: Verify Email Delivery

1. Create **WARNING alert** first (easiest to test)
2. Simulate degraded connection:
   - Open https://mixvy-v2.web.app
   - Join any live room
   - DevTools → Network → Throttling: "Slow 3G"
   - Wait 5 minutes
3. Check email for alert notification
4. Repeat for other alerts

### Full Test: Trigger CRITICAL

1. Join live room at https://mixvy-v2.web.app
2. DevTools → Network → Offline
3. Wait 14+ seconds
4. Watch for "Connection failed" message
5. Check console logs for `[MIXVY_DEBUG:ConnectionRecoveryHandler][CRIT]`
6. Verify CRITICAL alert email arrives

---

## Monitoring Dashboard

After alerts are created, check Crashlytics dashboard daily:

**URL:** https://console.firebase.google.com/project/mixvy-v2/crashlytics

**Review:**
- [ ] Total issues by severity (CRITICAL, ERROR, WARNING)
- [ ] Most common [MIXVY_DEBUG] messages
- [ ] Affected users (sessions with crashes)
- [ ] Trends (improving or worsening?)

---

## Troubleshooting

### ❌ "No option to create alert"
- Ensure you're on Blaze plan (required for custom alerts)
- Check: https://console.firebase.google.com/project/mixvy-v2/settings/usage
- Should show "Blaze plan"

### ❌ "Alert created but no email"
- Verify email address on notifications:
  - https://console.firebase.google.com/u/0/project/mixvy-v2/settings/notifications
- Add `larrybesant@gmail.com` if missing
- Test with project-level alert first (Billing alert)

### ❌ "Can't find Crashlytics in sidebar"
- Refresh page: F5
- Make sure you're in mixvy-v2 project (top-left dropdown)
- Check mobile/web app is registered in Crashlytics

### ❌ "Filter by custom key not working"
- Firebase requires custom keys to be set first (already done in code)
- Verify `diagnostic_severity` key is in main.dart lines 87-103
- Try creating alert without custom key filter first, add filter later

---

## Integration Summary

**All parts of the monitoring system are now deployed:**

| Component | Status | Details |
|-----------|--------|---------|
| DiagnosticLogger | ✅ Deployed | All services logging with [MIXVY_DEBUG] prefix |
| Firestore Rules | ✅ Deployed | Permission checks enforced |
| Connection Recovery | ✅ Deployed | 3x retries with exponential backoff |
| Health Check Service | ✅ Deployed | 5-second ping cycle, latency tracking |
| Production Handler | ✅ Deployed | Routes to Firebase Crashlytics |
| Custom Metadata | ✅ Deployed | diagnostic_severity, diagnostic_category keys |
| **Alerts Configuration** | ⏳ MANUAL | 3 alerts awaiting creation (5 min setup) |

---

## Next Steps

1. ✅ **TODAY:** Create 3 alerts (5 minutes)
2. ✅ **TODAY:** Test alert delivery (optional, 5 minutes)
3. 📊 **DAILY:** Review Crashlytics dashboard
4. 📧 **ONGOING:** Receive alerts via email for critical issues
5. 📝 **AS NEEDED:** Adjust alert thresholds based on production patterns

---

## Support References

- **Crashlytics Docs:** https://firebase.google.com/docs/crashlytics
- **DiagnosticLogger Code:** [lib/services/diagnostic_logger.dart](../lib/services/diagnostic_logger.dart)
- **Production Config:** [lib/main.dart#L87-L103](../lib/main.dart#L87-L103)
- **Health Check Service:** [lib/services/connection_health_check.dart](../lib/services/connection_health_check.dart)

---

**Status:** ✅ Production Ready  
**Last Updated:** July 14, 2026  
**Estimated Setup Time:** 5 minutes
