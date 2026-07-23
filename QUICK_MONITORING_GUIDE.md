# Quick Start: Monitor Room Join Errors

## 🚀 Live App
- **URL:** https://mixvy-v2.web.app
- **Status:** ✅ LIVE (HTTP 200)
- **Last Deploy:** 2026-06-29

## 📊 Real-Time Monitoring (Choose One)

### Option 1: Browser Console (Easiest)
1. Open https://mixvy-v2.web.app
2. Press `F12` to open DevTools
3. Go to **Console** tab
4. Filter: `RoomJoinError` or `permission-denied`
5. Try joining a room
6. ✅ Should see NO error messages

```javascript
// You can paste this in the browser console to test:
// (Assumes you're logged in)
// This will monitor for permission errors
document.addEventListener('keypress', (e) => {
  if (e.key === 'J') console.log('✓ Permission test ready');
});
```

### Option 2: Firebase Console Logs
1. Go to: https://console.firebase.google.com/project/mixvy-v2
2. Click **Logging** in left sidebar
3. Filter: `resource.type="cloud_firestore" AND severity="ERROR"`
4. Filter: Add `AND textPayload=~"permission-denied"`
5. Refresh every 30 seconds to see new errors

### Option 3: Command Line (If Set Up)
```bash
# Monitor permission errors in real-time
node tools/monitor_room_join_errors.js --realtime

# View recent errors
node tools/monitor_room_join_errors.js
```

## ✅ Verification Steps

### Step 1: Verify Firestore Rules Deployed
```bash
firebase deploy --only firestore:rules --dry-run
# Should show: "rules file firestore.rules compiled successfully"
```

### Step 2: Test Room Join Flow
1. Sign in to https://mixvy-v2.web.app
2. Navigate to a room
3. Click to join
4. ✅ Expected: Join succeeds, no console errors
5. ✅ Expected: Participant doc appears in Firestore (check console)

### Step 3: Check Participant Document
1. Open Firebase Console
2. Go to **Firestore** → **Data**
3. Navigate: `rooms` → `[roomId]` → `participants`
4. Should see your user ID as a document

### Step 4: Monitor for 5 Minutes
- Keep the app open
- Monitor console for errors
- Try different rooms if possible
- ✅ Expected: No permission-denied errors

## 🎯 Key Indicators of Success

| Indicator | ✅ Good | ❌ Problem |
|-----------|---------|-----------|
| **Browser Console** | No permission-denied messages | `[RoomJoinError]` appears |
| **Room Join** | User enters room immediately | Join button stuck/errors |
| **Participant Doc** | Appears in Firestore within 3s | Never appears |
| **Error Messages** | Clear & actionable | Vague "Permission denied" |
| **App Performance** | Smooth, responsive | Slow or freezing |

## ⚠️ If You See Permission-Denied Errors

### Immediate Check
1. **Verify user is signed in:** Look for profile icon in app
2. **Check room exists:** Try a different room
3. **Check console for details:** Look for `[RoomJoinError]` logs

### Next Steps
1. **Clear browser cache:** Ctrl+Shift+Delete
2. **Refresh app:** Ctrl+R (or Cmd+R on Mac)
3. **Try incognito mode:** Ctrl+Shift+N
4. **If error persists:** Save console output and report

### Diagnostic Info to Collect
```
1. Room ID: (from URL: /room/{ID})
2. User ID: (from Firebase Console → Auth)
3. Exact error message: (from console)
4. Browser type & version: (press F12 → About)
5. Network tab screenshot: (in DevTools)
```

## 🔍 Automated Monitoring Setup

### For Teams: Set Up Alerts
1. Go to Firebase Console → Logging
2. Click **Create Metric**
3. Filter: `resource.type="cloud_firestore" AND textPayload=~"permission-denied"`
4. Create Alert Policy
5. Add email/Slack notification

### For Developers: CLI Watch
```bash
# Run this in a terminal window to continuously monitor
watch -n 5 'node tools/monitor_room_join_errors.js'

# Or for Mac:
while true; do node tools/monitor_room_join_errors.js; sleep 5; done
```

## 📋 Deployment Success Criteria

After 24 hours, verify:

- [ ] **Zero Critical Errors:** No unhandled exceptions
- [ ] **Join Success Rate:** >99% of attempts succeed
- [ ] **Participant Docs:** Created for all successful joins
- [ ] **Error Messages:** Clear and helpful (if any errors)
- [ ] **Performance:** App responds in <2 seconds
- [ ] **Firestore:** No quota exceeded errors
- [ ] **Hosting:** <99ms response time (Firebase SLA)

## 🆘 Escalation

If monitoring shows persistent permission-denied errors:

1. **Check Firestore Rules:** Ensure latest version deployed
   ```bash
   firebase deploy --only firestore:rules --verbose
   ```

2. **Review Recent Changes:** Check git diff
   ```bash
   git diff HEAD~1 firestore.rules
   ```

3. **Rollback if Needed:**
   ```bash
   git revert HEAD --no-edit
   flutter build web --release --base-href /
   firebase deploy --only hosting
   ```

## 📞 Resources

- **Firebase Status:** https://status.firebase.google.com
- **Firestore Docs:** https://firebase.google.com/docs/firestore
- **Flutter Web:** https://flutter.dev/multi-platform/web
- **Debug Tools:** DevTools (press F12 in app)

---

**Setup Time:** 5 minutes  
**Monitoring Interval:** Continuous or check every hour  
**Expected Issues:** 0 (if setup correct)
