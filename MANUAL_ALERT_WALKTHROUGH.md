# 🎯 MANUAL ALERT CREATION WALKTHROUGH

**Status**: Ready to create (Email channel verified ✅)  
**Time Needed**: 5-10 minutes total  
**Difficulty**: Very Easy - Copy/Paste Values

---

## 📌 Quick Reference

| Alert | Name | Condition | Threshold | Duration | Filter |
|-------|------|-----------|-----------|----------|--------|
| 1 | CRITICAL Network Recovery Failure | Severity = FATAL | Immediate | 1 min | (none - use severity) |
| 2 | ERROR Reconnection Failures | Count > 5 | 5 errors | 5 min | diagnostic_severity = ERROR |
| 3 | WARNING Connection Degrading | Count > 3 | 3 warnings | 5 min | diagnostic_severity = WARN |

**Notification Channel ID** (for all 3 alerts):
```
projects/mixvy-v2/notificationChannels/5103384296039862868
```

---

## 📍 WHERE TO CREATE ALERTS

In Firebase Console:
1. Look for "Settings" gear icon in left sidebar
2. Click Settings
3. Look for "Alerts" or "Notifications" tab
4. OR navigate directly to:
   ```
   https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies
   ```

---

## 🚀 ALERT 1: CRITICAL (5 minutes)

### Click "Create Policy" or "Create Alert"

### Step 1a: Fill Display Name
```
Display Name:    MixVy Production - CRITICAL Network Recovery Failure
```

### Step 1b: Set Condition Type
- Look for a dropdown that says "Condition Type" or similar
- Select: **"Severity"** or **"Issue severity"**
- Select: **"FATAL"** or **"CRITICAL"**

### Step 1c: Set Duration
- Duration: **1 minute** (default is often 5 min)
- Change to 1 minute if available

### Step 1d: Add Notification
- Click "Add notification channel" or "Notifications"
- Select: **Email - larrybesant@gmail.com**
- (Or select the channel ID: projects/mixvy-v2/notificationChannels/5103384296039862868)

### Step 1e: Create
- Click **"Create Policy"** or **"Save"**

✅ **Alert 1 Created!**

---

## 🚀 ALERT 2: ERROR (5 minutes)

### Click "Create Policy" again

### Step 2a: Fill Display Name
```
Display Name:    MixVy Production - ERROR Reconnection Failures
```

### Step 2b: Set Condition Type
- Select: **"Issue count"** (not severity)
- Threshold: **5** (5 errors)
- Duration: **5 minutes**

### Step 2c: Add Custom Filter
- Look for "Add Filter", "Custom Filter", or "Advanced Filtering"
- Click it
- **Filter Type**: Select **"Custom Key"** or **"Metadata"**
- **Key Name**: `diagnostic_severity`
- **Operator**: **"equals"** or **"="**
- **Value**: `ERROR`

### Step 2d: Add Notification
- Select: **Email - larrybesant@gmail.com**

### Step 2e: Create
- Click **"Create Policy"**

✅ **Alert 2 Created!**

---

## 🚀 ALERT 3: WARNING (5 minutes)

### Click "Create Policy" again

### Step 3a: Fill Display Name
```
Display Name:    MixVy Production - WARNING Connection Health Degrading
```

### Step 3b: Set Condition Type
- Select: **"Issue count"**
- Threshold: **3** (3 warnings)
- Duration: **5 minutes**

### Step 3c: Add Custom Filter
- Click "Add Filter" / "Custom Filter" / "Advanced Filtering"
- **Filter Type**: **"Custom Key"** or **"Metadata"**
- **Key Name**: `diagnostic_severity`
- **Operator**: **"equals"** or **"="**
- **Value**: `WARN`

### Step 3d: Add Notification
- Select: **Email - larrybesant@gmail.com**

### Step 3e: Create
- Click **"Create Policy"**

✅ **Alert 3 Created!**

---

## ✅ VERIFY ALL 3 ALERTS CREATED

After creating all 3 alerts:

1. Go to Firebase Console Alert Policies:
   ```
   https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies
   ```

2. You should see all 3 alerts listed:
   - [ ] MixVy Production - CRITICAL Network Recovery Failure  
   - [ ] MixVy Production - ERROR Reconnection Failures  
   - [ ] MixVy Production - WARNING Connection Health Degrading

3. Check that each shows:
   - **Status**: Enabled ✅
   - **Notification**: Email (larrybesant@gmail.com)

---

## 🔍 TROUBLESHOOTING

### Q: Can't find "Create Alert" button?
**A**: Try going to Settings > Alerts tab, or search for "Create Policy" button

### Q: Don't see "Add Filter" button?
**A**: Sometimes it's under "Advanced Filtering" or only appears after selecting condition type

### Q: "Custom Key" option not available?
**A**: Try "Metadata" instead, or look for "Custom Conditions"

### Q: Filter doesn't seem to work?
**A**: Try a simpler filter first. Some Firebase UIs require specific syntax. Alternative:
- Leave filter empty for now
- Focus on Severity (FATAL) and Count (5+, 3+)
- We can add custom filters later

### Q: Can't save the alert?
**A**: Common issues:
- Notification channel not selected
- Duration or threshold not filled in
- Filter syntax error (try removing special characters)

---

## 📊 WHAT THE ALERTS DO

**Alert 1 - CRITICAL**
- ⚡ Triggers IMMEDIATELY when a FATAL error occurs
- 🎯 Catches: "Max retries exceeded" errors from recovery handler
- 📧 Sends: Email notification within 1-5 minutes

**Alert 2 - ERROR**
- 📈 Triggers when 5+ ERROR-level logs occur in 5 minutes
- 🎯 Catches: Multiple reconnection failures in short window
- 📧 Sends: Email notification within 5-10 minutes

**Alert 3 - WARNING**
- ⚠️ Triggers when 3+ WARNING-level logs occur in 5 minutes
- 🎯 Catches: Connection health degrading (proactive alert)
- 📧 Sends: Email notification within 5-10 minutes

---

## 📝 WHAT TO DO AFTER CREATION

1. **Wait 5 minutes** for alerts to stabilize in Firebase
2. **Check your email** for any verification links
3. **(Optional) Test alert**: 
   - Open https://mixvy-v2.web.app
   - Go offline in browser DevTools
   - Wait ~14 seconds for max retries
   - Watch for CRITICAL alert email
4. **Monitor Crashlytics**: https://console.firebase.google.com/project/mixvy-v2/crashlytics
   - Look for custom metadata keys being logged
   - Verify alerts are triggering correctly

---

## 🎯 SUCCESS CRITERIA

✅ All 3 alerts visible in Firebase Console  
✅ All 3 alerts show "Enabled" status  
✅ All 3 alerts have email notifications attached  
✅ Email channel verified (check spam folder if needed)  

---

## 📞 STUCK?

If you're stuck at any step:
1. Take a screenshot
2. Share what you see
3. Share what step you're on (1a, 2c, etc.)
4. I can help diagnose the issue

---

## ⏱️ TIMELINE

| Time | Action |
|------|--------|
| Now | Start creating Alert 1 |
| +2 min | Alert 1 created, start Alert 2 |
| +4 min | Alert 2 created, start Alert 3 |
| +6 min | Alert 3 created |
| +7 min | Verify all 3 in Firebase Console |
| +12 min | ✅ ALL DONE! |

---

**Ready? Open Firebase Console and start with Alert 1! 🚀**
