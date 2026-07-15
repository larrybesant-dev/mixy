# 🔔 CREATE 3 CRASHLYTICS MONITORING ALERTS - STEP-BY-STEP GUIDE

**Target**: Firebase Console - Monitoring → Alert Policies  
**Project**: mixvy-v2  
**Time Required**: 10-15 minutes total (5 minutes per alert)  
**Complexity**: Simple (copy-paste values)

---

## 🚀 Quick Start

### Step 0: Navigate to Alert Policies
1. Open: https://console.firebase.google.com/project/mixvy-v2/overview
2. In left sidebar, find **"Crashlytics"** section
3. Click **"Crashlytics"** link
4. Once inside Crashlytics, look for **"Alerts"** or **"Monitoring"** tab
5. Click **"Create Policy"** or **"Create Alert"** button

### Quick Links (Direct Access)
- **Firebase Project**: https://console.firebase.google.com/project/mixvy-v2/overview
- **Crashlytics Dashboard**: https://console.firebase.google.com/project/mixvy-v2/crashlytics
- **Alert Policies**: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies

---

## 🔔 ALERT 1: CRITICAL - Max Retries Exceeded

### Configuration Details
```
Display Name:  MixVy Production - CRITICAL Network Recovery Failure
Severity:      FATAL
Condition:     Issue severity is FATAL
Notification:  Email - larrybesant@gmail.com
```

### Step-by-Step Creation

**Step 1: Start New Alert**
- Click: **"Create Policy"** button
- Select: **"Crashlytics"** as the service

**Step 2: Configure Display Name**
- Field: Display Name
- Value: `MixVy Production - CRITICAL Network Recovery Failure`
- Copy-paste: MixVy Production - CRITICAL Network Recovery Failure

**Step 3: Set Alert Condition**
- Click: **"Condition"** dropdown
- Select: **"Issue severity"**
- In severity selector, choose: **"FATAL"**

**Step 4: Duration** (Optional)
- Leave as default: **1 minute**

**Step 5: Add Notification Channel**
- Click: **"Notification Channels"**
- Select: **"Email - larrybesant@gmail.com"**
- If not available, create email channel first (see below)

**Step 6: Save Alert**
- Click: **"Create Policy"** button
- Wait for confirmation

### Expected Result
✅ Alert created with name: "MixVy Production - CRITICAL Network Recovery Failure"  
✅ Status: Enabled  
✅ Triggers on: FATAL severity errors

---

## 🔴 ALERT 2: ERROR - Repeated Reconnection Failures

### Configuration Details
```
Display Name:  MixVy Production - ERROR Reconnection Failures (5+ in 5min)
Condition:     Issue count > 5 in 5 minutes
Filter:        Custom key diagnostic_severity = ERROR
Notification:  Email - larrybesant@gmail.com
```

### Step-by-Step Creation

**Step 1: Start New Alert**
- Click: **"Create Policy"** button (again)
- Select: **"Crashlytics"**

**Step 2: Configure Display Name**
- Field: Display Name
- Value: `MixVy Production - ERROR Reconnection Failures (5+ in 5min)`
- Copy-paste: MixVy Production - ERROR Reconnection Failures (5+ in 5min)

**Step 3: Set Alert Condition**
- Click: **"Condition"** dropdown
- Select: **"Issue count"**
- Threshold: Enter **5**
- Time window: Select **5 minutes**

**Step 4: Add Custom Key Filter** (IMPORTANT!)
- Click: **"Add Filter"** or **"Advanced Filtering"**
- Filter Type: **"Custom Key"**
- Key Name: `diagnostic_severity`
- Operator: **"equals"** or **"="**
- Value: `ERROR`

**Step 5: Add Notification Channel**
- Select: **"Email - larrybesant@gmail.com"**

**Step 6: Save Alert**
- Click: **"Create Policy"** button
- Wait for confirmation

### Expected Result
✅ Alert created with name: "MixVy Production - ERROR Reconnection Failures"  
✅ Status: Enabled  
✅ Triggers on: 5+ errors in 5-minute window  
✅ Filter: diagnostic_severity = ERROR

---

## 🟡 ALERT 3: WARNING - Connection Health Degrading

### Configuration Details
```
Display Name:  MixVy Production - WARNING Connection Health Degrading (3+ in 5min)
Condition:     Issue count > 3 in 5 minutes
Filter:        Custom key diagnostic_severity = WARN
Notification:  Email - larrybesant@gmail.com
```

### Step-by-Step Creation

**Step 1: Start New Alert**
- Click: **"Create Policy"** button (again)
- Select: **"Crashlytics"**

**Step 2: Configure Display Name**
- Field: Display Name
- Value: `MixVy Production - WARNING Connection Health Degrading (3+ in 5min)`
- Copy-paste: MixVy Production - WARNING Connection Health Degrading (3+ in 5min)

**Step 3: Set Alert Condition**
- Click: **"Condition"** dropdown
- Select: **"Issue count"**
- Threshold: Enter **3**
- Time window: Select **5 minutes**

**Step 4: Add Custom Key Filter** (IMPORTANT!)
- Click: **"Add Filter"** or **"Advanced Filtering"**
- Filter Type: **"Custom Key"**
- Key Name: `diagnostic_severity`
- Operator: **"equals"** or **"="**
- Value: `WARN`

**Step 5: Add Notification Channel**
- Select: **"Email - larrybesant@gmail.com"**

**Step 6: Save Alert**
- Click: **"Create Policy"** button
- Wait for confirmation

### Expected Result
✅ Alert created with name: "MixVy Production - WARNING Connection Health Degrading"  
✅ Status: Enabled  
✅ Triggers on: 3+ warnings in 5-minute window  
✅ Filter: diagnostic_severity = WARN

---

## 📧 Create Email Notification Channel (If Needed)

If you don't see "Email - larrybesant@gmail.com" in the notification channels:

**Step 1: Add Notification Channel**
- Click: **"Add Notification Channel"** or **"Create Channel"**

**Step 2: Select Email**
- Channel Type: **"Email"**

**Step 3: Enter Email Address**
- Email: `larrybesant@gmail.com`
- Copy-paste: larrybesant@gmail.com

**Step 4: Create**
- Click: **"Create"** or **"Save"**
- You'll receive a verification email
- Click the verification link (required to activate)

---

## ✅ Verification Checklist

After creating all 3 alerts:

### In Firebase Console
- [ ] Alert 1: "MixVy Production - CRITICAL Network Recovery Failure" - Status: **Enabled**
- [ ] Alert 2: "MixVy Production - ERROR Reconnection Failures (5+ in 5min)" - Status: **Enabled**
- [ ] Alert 3: "MixVy Production - WARNING Connection Health Degrading (3+ in 5min)" - Status: **Enabled**

### In Your Email
- [ ] Received verification email from Firebase
- [ ] Clicked verification link
- [ ] Received confirmation that channel is active

### Test Alert Creation (Optional)
- [ ] Trigger test alert by simulating error
- [ ] Verify email is received
- [ ] Check alert dashboard shows the alert

---

## 🔍 Where to View Created Alerts

### Option 1: Firebase Console UI
1. Go: https://console.firebase.google.com/project/mixvy-v2/overview
2. Left sidebar → **Crashlytics**
3. Look for **"Monitoring"** or **"Alerts"** section
4. View all 3 alerts listed and enabled

### Option 2: View Active Alerts
- Navigate: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies
- Should show:
  - CRITICAL - Max Retries
  - ERROR - Repeated Failures
  - WARNING - Health Degrading

---

## 📋 Copy-Paste Reference Guide

### Alert 1 Values
```
Name:        MixVy Production - CRITICAL Network Recovery Failure
Severity:    FATAL
Threshold:   (N/A - severity based)
Duration:    1 minute
Email:       larrybesant@gmail.com
```

### Alert 2 Values
```
Name:        MixVy Production - ERROR Reconnection Failures (5+ in 5min)
Count:       5
Duration:    5 minutes
Filter Key:  diagnostic_severity
Filter Op:   equals
Filter Val:  ERROR
Email:       larrybesant@gmail.com
```

### Alert 3 Values
```
Name:        MixVy Production - WARNING Connection Health Degrading (3+ in 5min)
Count:       3
Duration:    5 minutes
Filter Key:  diagnostic_severity
Filter Op:   equals
Filter Val:  WARN
Email:       larrybesant@gmail.com
```

---

## 🎯 Alert Trigger Scenarios

### CRITICAL Alert Triggers When:
- User experiences maximum reconnection retries exceeded
- `DiagnosticLogger` logs severity level = "CRIT"
- Firestore connection permanently fails after 3 retries
- **Response**: Email received immediately (within 1 minute)

### ERROR Alert Triggers When:
- 5 or more ERROR events occur within 5 minutes
- `diagnostic_severity` custom key = "ERROR"
- Reconnection failures repeated multiple times
- **Response**: Email received with error summary

### WARNING Alert Triggers When:
- 3 or more WARN events occur within 5 minutes
- `diagnostic_severity` custom key = "WARN"
- Connection health degrading (high latency, packet loss)
- **Response**: Email received with proactive alert

---

## 🧪 Testing Alert Delivery (Optional)

Once alerts are created, you can test:

1. **Access Live Room**: https://mixvy-v2.web.app
2. **Disable Network**: DevTools → Network → Offline
3. **Watch Connection Fail**: Health badge shows "Reconnecting..."
4. **Max Retries Exceeded**: After 14s (2s + 4s + 8s), should trigger CRITICAL
5. **Check Email**: Should receive alert notification within 5 minutes

---

## ⚠️ Troubleshooting

### If Email Channel Not Available
**Solution**: Create email channel first (see "Create Email Notification Channel" section)

### If Alert Doesn't Save
**Solution**: 
- Ensure all required fields filled
- Email must be verified
- Try refreshing page and retry

### If Filter Not Appearing
**Solution**:
- May need to use "Advanced Filtering" or "Custom Key" option
- Filter becomes available after selecting "Issue count" condition

### If Alerts Don't Trigger
**Solution**:
- Ensure errors are being logged to Crashlytics
- Check that custom keys are attached correctly
- Wait up to 5 minutes for event aggregation

---

## 📞 Support

For questions or issues:
1. Check Firebase Crashlytics docs: https://firebase.google.com/docs/crashlytics/alerts
2. Review alert policies: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies
3. Check email notifications settings
4. Verify custom keys in Crashlytics events

---

## ✨ Next Steps After Alert Creation

1. ✅ **Create alerts** (this guide)
2. ✅ **Verify email** (click verification link)
3. ⏳ **Monitor alerts**: Check daily for first week
4. ⏳ **Test delivery**: Optional live room test
5. ⏳ **Establish routine**: Daily/weekly review

---

**Status**: Ready to Create  
**Estimated Time**: 10-15 minutes  
**Difficulty**: Easy (copy-paste)  
**Next**: Follow steps above to create all 3 alerts!
