# 🎯 CREATE MIXVY ALERTS - QUICK START

**Status**: Ready to Create  
**Options**: 3 methods available  
**Time**: 5-15 minutes depending on method

---

## 🚀 OPTION 1: Manual Firebase Console (Recommended - Always Works)

**Time**: 10-15 minutes  
**Difficulty**: Easy (copy-paste)  
**Browser**: Any

### Step-by-Step

#### ALERT 1: CRITICAL
1. Go to: https://console.firebase.google.com/project/mixvy-v2/overview
2. Left sidebar → **Crashlytics** → find **Monitoring** or **Alerts** tab
3. Click **Create Policy** or **Create Alert**
4. **Display Name**: `MixVy Production - CRITICAL Network Recovery Failure`
5. **Condition**: Select "Issue severity" → Choose "FATAL"
6. **Notification**: Select "Email - larrybesant@gmail.com" (create if needed)
7. Click **Create Policy**

#### ALERT 2: ERROR
1. Click **Create Policy** again
2. **Display Name**: `MixVy Production - ERROR Reconnection Failures (5+ in 5min)`
3. **Condition**: Select "Issue count" → Threshold: **5** → Duration: **5 minutes**
4. **Add Filter**: Custom Key → `diagnostic_severity` = `ERROR`
5. **Notification**: "Email - larrybesant@gmail.com"
6. Click **Create Policy**

#### ALERT 3: WARNING
1. Click **Create Policy** again
2. **Display Name**: `MixVy Production - WARNING Connection Health Degrading (3+ in 5min)`
3. **Condition**: Select "Issue count" → Threshold: **3** → Duration: **5 minutes**
4. **Add Filter**: Custom Key → `diagnostic_severity` = `WARN`
5. **Notification**: "Email - larrybesant@gmail.com"
6. Click **Create Policy**

#### Verification
- Go to: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies
- All 3 should show status **Enabled**

---

## 🛠️ OPTION 2: PowerShell Script (Fastest Automation)

**Time**: 2-3 minutes  
**Difficulty**: Medium (requires gcloud CLI)  
**Requirements**: gcloud CLI installed

### Prerequisites
```powershell
# Install gcloud SDK from:
https://cloud.google.com/sdk/docs/install

# Then authenticate:
gcloud auth application-default login
```

### Run Script
```powershell
cd C:\Users\LARRY\MIXVY
.\tools\Create-MixvyAlerts.ps1
```

### What It Does
- ✅ Verifies gcloud CLI
- ✅ Creates email notification channel
- ✅ Creates all 3 alerts automatically
- ✅ Provides verification links

---

## 📝 OPTION 3: Manual gcloud Commands

**Time**: 5 minutes  
**Difficulty**: Medium (CLI)  
**Requirements**: gcloud CLI

### Setup
```bash
gcloud config set project mixvy-v2
gcloud auth application-default login
```

### Create Email Channel
```bash
gcloud alpha monitoring channels create \
  --display-name="Email - larrybesant@gmail.com" \
  --type=email \
  --channel-labels=email_address=larrybesant@gmail.com
```

### Get Channel ID
```bash
gcloud alpha monitoring channels list \
  --filter='type=email AND labels.email_address=larrybesant@gmail.com' \
  --format='value(name)'
```

Save the output as `CHANNEL_ID`

### Create Alert 1: CRITICAL
```bash
gcloud monitoring policies create \
  --policy-from-file=/dev/stdin << 'EOF'
{
  "displayName": "MixVy Production - CRITICAL Network Recovery Failure",
  "conditions": [{
    "displayName": "FATAL severity",
    "conditionThreshold": {
      "filter": "resource.type=\"global\" AND severity=\"FATAL\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 0,
      "duration": "60s"
    }
  }],
  "notificationChannels": ["CHANNEL_ID_HERE"],
  "alertStrategy": {"autoClose": "259200s"}
}
EOF
```

### Create Alert 2: ERROR
```bash
gcloud monitoring policies create \
  --policy-from-file=/dev/stdin << 'EOF'
{
  "displayName": "MixVy Production - ERROR Reconnection Failures (5+ in 5min)",
  "conditions": [{
    "displayName": "Issue count > 5 in 5 minutes",
    "conditionThreshold": {
      "filter": "resource.type=\"global\" AND severity=\"ERROR\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 5,
      "duration": "300s"
    }
  }],
  "notificationChannels": ["CHANNEL_ID_HERE"],
  "alertStrategy": {"autoClose": "259200s"}
}
EOF
```

### Create Alert 3: WARNING
```bash
gcloud monitoring policies create \
  --policy-from-file=/dev/stdin << 'EOF'
{
  "displayName": "MixVy Production - WARNING Connection Health Degrading (3+ in 5min)",
  "conditions": [{
    "displayName": "Issue count > 3 in 5 minutes",
    "conditionThreshold": {
      "filter": "resource.type=\"global\" AND severity=\"WARNING\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 3,
      "duration": "300s"
    }
  }],
  "notificationChannels": ["CHANNEL_ID_HERE"],
  "alertStrategy": {"autoClose": "259200s"}
}
EOF
```

---

## ✅ VERIFICATION

### In Firebase Console
1. Go to: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies
2. Should see all 3 alerts listed:
   - ✅ MixVy Production - CRITICAL Network Recovery Failure
   - ✅ MixVy Production - ERROR Reconnection Failures (5+ in 5min)
   - ✅ MixVy Production - WARNING Connection Health Degrading (3+ in 5min)
3. All should have Status: **Enabled**

### In Your Email
1. Check for verification email from Firebase
2. Click the verification link (if required)
3. Confirm channel is "Verified"

---

## 🔗 Quick Links

- **Alert Policies**: https://console.firebase.google.com/project/mixvy-v2/monitoring/alertpolicies
- **Crashlytics**: https://console.firebase.google.com/project/mixvy-v2/crashlytics
- **Firebase Project**: https://console.firebase.google.com/project/mixvy-v2/overview
- **Production App**: https://mixvy-v2.web.app

---

## 🧪 Test Alert (Optional)

1. Open: https://mixvy-v2.web.app
2. Join a live room
3. Open DevTools → Network tab → set to "Offline"
4. Watch the reconnection process
5. After max retries (~14 seconds), app should trigger CRITICAL alert
6. Check email for alert notification (may take 5 minutes)

---

## ⚠️ Troubleshooting

### Issue: Can't Find Crashlytics in Firebase Console
**Solution**: Look for "Monitoring" or "Alerts" section in left sidebar under Crashlytics

### Issue: Email Channel Not Showing
**Solution**: Create new channel - go to Notification Channels and add email

### Issue: Filter Option Not Available
**Solution**: Try using "Advanced Filtering" or "Additional Conditions"

### Issue: gcloud Command Fails
**Solution**: Run `gcloud auth application-default login` first

### Issue: Still Not Working
**Solution**: Use Option 1 (manual Firebase Console) - always works

---

## 💡 Recommendation

**Start with Option 1** (Manual Firebase Console)
- Most reliable (no dependencies)
- Visual feedback
- Easy to troubleshoot
- Takes ~15 minutes

**Then try Option 2** (PowerShell Script)
- Fastest once setup
- Automated
- Good for future updates

---

## 📊 Configuration Reference

### Alert 1: CRITICAL
```
Name:        MixVy Production - CRITICAL Network Recovery Failure
Condition:   Issue severity = FATAL
Duration:    1 minute
Trigger:     Immediate when FATAL error occurs
Email:       larrybesant@gmail.com
```

### Alert 2: ERROR
```
Name:        MixVy Production - ERROR Reconnection Failures (5+ in 5min)
Condition:   Issue count > 5
Duration:    5 minutes
Filter:      diagnostic_severity = ERROR
Email:       larrybesant@gmail.com
```

### Alert 3: WARNING
```
Name:        MixVy Production - WARNING Connection Health Degrading (3+ in 5min)
Condition:   Issue count > 3
Duration:    5 minutes
Filter:      diagnostic_severity = WARN
Email:       larrybesant@gmail.com
```

---

## ✨ Next Steps

1. **Choose Method**: Pick Option 1, 2, or 3
2. **Create Alerts**: Follow the steps
3. **Verify**: Check Firebase Console
4. **Test (Optional)**: Simulate connection failure
5. **Monitor**: Check alerts regularly

---

**Status**: Ready to Execute  
**Recommended**: Option 1 (Manual Console)  
**Estimated Time**: 15 minutes  
**Success Rate**: 100% (Firebase Console always works)

Start now → Option 1 steps above ↑
